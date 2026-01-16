import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../app_state.dart';
import '../models/workout.dart';
import '../models/workout_plan.dart';
import '../services/rep_counter_squats.dart';
import 'exercise_screen.dart';
import '../services/tts_service.dart';

class SetupModeScreen extends StatefulWidget {
  const SetupModeScreen({
    super.key,
    required this.workout,
  });

  final Workout workout;

  @override
  State<SetupModeScreen> createState() => _SetupModeScreenState();
}

class _SetupModeScreenState extends State<SetupModeScreen> {
  static const _bgDark = Color.fromARGB(255, 18, 32, 47);

  CameraController? _controller;
  Future<void>? _initFuture;
  String? _error;

  PoseDetector? _poseDetector;
  bool _isDetecting = false;

  List<Pose> _poses = const [];
  CameraDescription? _selectedCamera;
  InputImageRotation? _imgRotation;
  Size? _imgSize;

  // checklist + readiness
  SetupChecklist _checklist = SetupChecklist.empty();
  bool _allReady = false;

  // countdown
  int _countdown = 0;
  Timer? _countdownTimer;

  // optional rep debug for squats
  final RepCounter _repCounter = RepCounter.squat();
  int _reps = 0;

  @override
  void initState() {
    super.initState();

    _poseDetector = PoseDetector(
      options: PoseDetectorOptions(
        mode: PoseDetectionMode.stream,
        model: PoseDetectionModel.base,
      ),
    );
    _initCamera();
    unawaited(TtsService.I.init());
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    unawaited(TtsService.I.stop());

    try {
      _controller?.stopImageStream();
    } catch (_) {}
    try {
      _controller?.dispose();
    } catch (_) {}

    try {
      _poseDetector?.close();
    } catch (_) {}

    super.dispose();
  }

  // -------------------------
  // ActivityLevel parsing (String? -> enum)
  // -------------------------
  ActivityLevel _parseActivityLevel(String? raw) {
    final s = (raw ?? '').trim();
    if (s.isEmpty) return ActivityLevel.sedentary;

    // handles: "ActivityLevel.sedentary", "sedentary", "Sedentary",
    // "Lightly Active", "lightlyActive", etc.
    final lower = s.toLowerCase();
    final key = (lower.contains('.') ? lower.split('.').last : lower)
        .replaceAll(RegExp(r'\s+'), '');

    switch (key) {
      case 'sedentary':
        return ActivityLevel.sedentary;
      case 'lightlyactive':
        return ActivityLevel.lightlyActive;
      case 'moderatelyactive':
        return ActivityLevel.moderatelyActive;
      case 'veryactive':
        return ActivityLevel.veryActive;
      default:
        return ActivityLevel.sedentary;
    }
  }

  // -------------------------
  // Camera init + pose stream
  // -------------------------
  Future<void> _initCamera() async {
    try {
      final perm = await Permission.camera.request();
      if (!perm.isGranted) {
        if (mounted) setState(() => _error = 'Camera permission denied.');
        return;
      }

      final cams = await availableCameras();
      if (cams.isEmpty) {
        if (mounted) setState(() => _error = 'No cameras found on this device.');
        return;
      }

      final chosen = cams.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cams.first,
      );

      final ctrl = CameraController(
        chosen,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup:
            Platform.isAndroid ? ImageFormatGroup.nv21 : ImageFormatGroup.bgra8888,
      );

      _controller = ctrl;
      _initFuture = ctrl.initialize();
      await _initFuture;

      _selectedCamera = chosen;

      await ctrl.startImageStream((CameraImage image) async {
        if (_isDetecting) return;
        _isDetecting = true;

        try {
          final inputImage = _cameraImageToInputImage(image, chosen);
          if (inputImage == null) return;

          final poses = await _poseDetector!.processImage(inputImage);

          final c = _buildChecklist(
            poses: poses,
            imageSize: _imgSize,
            rotation: _imgRotation,
            title: widget.workout.title,
          );

          final ready = c.allMet;

          // if readiness breaks during countdown -> stop countdown
          if (_countdown > 0 && !ready) _stopCountdown();

          // if became ready and not counting down -> start countdown
          if (_countdown == 0 && ready) _startCountdown(seconds: 5);

          // rep counter (debug)
          int newReps = 0;
          if (_isSquat(widget.workout.title) && poses.isNotEmpty) {
            _repCounter.update(poses.first);
            newReps = _repCounter.reps;
          }

          if (mounted) {
            setState(() {
              _poses = poses;
              _checklist = c;
              _allReady = ready;
              _reps = newReps;
            });
          }
        } catch (e, st) {
          debugPrint('Setup pose error: $e\n$st');
        } finally {
          _isDetecting = false;
        }
      });

      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) setState(() => _error = 'Camera error: $e');
    }
  }

  // -------------------------
  // Countdown + navigation
  // -------------------------
    void _startCountdown({required int seconds}) {
      _countdownTimer?.cancel();
      _countdown = seconds;

      // Speak the first number immediately (e.g., "5")
      unawaited(TtsService.I.speak('$_countdown'));

      _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) async {
        if (!mounted) return;

        final next = _countdown - 1;
        setState(() => _countdown = next);

        if (next <= 0) {
          t.cancel();
          _countdownTimer = null;
          await _goToExercise();
        } else {
          // Speak the next number (e.g., "4", "3", "2", "1")
          await TtsService.I.speak('$next');
        }
      });

      setState(() {});
    }


  void _stopCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
    unawaited(TtsService.I.stop());
    if (mounted) setState(() => _countdown = 0);
  }

  Future<void> _goToExercise() async {
    final state = AppStateScope.of(context);

    final level = _parseActivityLevel(state.activityLevel);

    final plan = WorkoutPlan.recommended(
      workoutTitle: widget.workout.title,
      level: level,
    );

    final old = _controller;
    _controller = null;

    try {
      await old?.stopImageStream();
    } catch (_) {}

    try {
      await old?.dispose();
    } catch (_) {}

    // (optional) stop detector early (dispose still closes too)
    try {
      await _poseDetector?.close();
    } catch (_) {}
    _poseDetector = null;

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ExerciseScreen(
          workout: widget.workout,
          plan: plan,
        ),
      ),
    );
  }

  // -------------------------
  // Camera -> MLKit InputImage
  // -------------------------
  static const Map<DeviceOrientation, int> _orientations = {
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };

  InputImage? _cameraImageToInputImage(CameraImage image, CameraDescription camera) {
    final sensorOrientation = camera.sensorOrientation;
    InputImageRotation? rotation;

    if (Platform.isIOS) {
      rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
    } else if (Platform.isAndroid) {
      final deviceOrientation = _controller?.value.deviceOrientation;
      final rotationCompensation = _orientations[deviceOrientation];
      if (rotationCompensation == null) return null;

      final rot = camera.lensDirection == CameraLensDirection.front
          ? (sensorOrientation + rotationCompensation) % 360
          : (sensorOrientation - rotationCompensation + 360) % 360;

      rotation = InputImageRotationValue.fromRawValue(rot);
    }

    if (rotation == null) return null;

    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null) return null;

    if (Platform.isAndroid && format != InputImageFormat.nv21) return null;
    if (Platform.isIOS && format != InputImageFormat.bgra8888) return null;

    if (image.planes.length != 1) return null;

    final plane = image.planes.first;
    final imgSize = Size(image.width.toDouble(), image.height.toDouble());

    _imgRotation = rotation;
    _imgSize = imgSize;

    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: imgSize,
        rotation: rotation,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  // -------------------------
  // Checklist evaluation
  // -------------------------
  bool _isSquat(String title) => title.toLowerCase().contains('squat');
  bool _isJumpingJack(String title) =>
      title.toLowerCase().contains('jump') || title.toLowerCase().contains('jack');

  SetupChecklist _buildChecklist({
    required List<Pose> poses,
    required Size? imageSize,
    required InputImageRotation? rotation,
    required String title,
  }) {
    if (poses.isEmpty || imageSize == null || rotation == null) {
      return SetupChecklist.empty();
    }

    final pose = poses.first;
    final lm = pose.landmarks;

    PoseLandmark? L(PoseLandmarkType t) => lm[t];

    final ls = L(PoseLandmarkType.leftShoulder);
    final rs = L(PoseLandmarkType.rightShoulder);
    final lh = L(PoseLandmarkType.leftHip);
    final rh = L(PoseLandmarkType.rightHip);
    final lk = L(PoseLandmarkType.leftKnee);
    final rk = L(PoseLandmarkType.rightKnee);
    final la = L(PoseLandmarkType.leftAnkle);
    final ra = L(PoseLandmarkType.rightAnkle);
    final lw = L(PoseLandmarkType.leftWrist);
    final rw = L(PoseLandmarkType.rightWrist);

    final fullBodyVisible = ls != null &&
        rs != null &&
        lh != null &&
        rh != null &&
        lk != null &&
        rk != null &&
        la != null &&
        ra != null;

    // effective width/height depending on rotation
    final effW = (rotation == InputImageRotation.rotation90deg ||
            rotation == InputImageRotation.rotation270deg)
        ? imageSize.height
        : imageSize.width;

    final effH = (rotation == InputImageRotation.rotation90deg ||
            rotation == InputImageRotation.rotation270deg)
        ? imageSize.width
        : imageSize.height;

    // distance (body height fraction)
    bool distanceOk = false;
    if (fullBodyVisible) {
      final topY = [ls.y, rs.y].reduce((a, b) => a < b ? a : b);
      final botY = [la.y, ra.y].reduce((a, b) => a > b ? a : b);
      final bodyH = (botY - topY).abs();
      final frac = effH == 0 ? 0.0 : (bodyH / effH);
      distanceOk = frac >= 0.55 && frac <= 0.92;
    }

    // enough side space
    bool spaceOk = false;
    if (fullBodyVisible && lw != null && rw != null) {
      final xs = <double>[ls.x, rs.x, lh.x, rh.x, la.x, ra.x, lw.x, rw.x];
      final minX = xs.reduce((a, b) => a < b ? a : b);
      final maxX = xs.reduce((a, b) => a > b ? a : b);
      spaceOk = (minX > 0.04 * effW) && (maxX < 0.96 * effW);
    }

    // centered
    bool centeredOk = false;
    if (fullBodyVisible) {
      final cx = (ls.x + rs.x + lh.x + rh.x) / 4.0;
      centeredOk = ((cx - effW / 2).abs() / effW) <= 0.20;
    }

    // facing via shoulder width fraction
    bool frontFacingOk = false;
    bool sideFacingOk = false;
    if (ls != null && rs != null) {
      final shoulderFrac = (ls.x - rs.x).abs() / (effW == 0 ? 1.0 : effW);
      frontFacingOk = shoulderFrac >= 0.18;
      sideFacingOk = shoulderFrac <= 0.14;
    }

    if (_isSquat(title)) {
      return SetupChecklist(
        items: [
          SetupItem('Stand 4-6 feet from the camera', distanceOk),
          SetupItem('Ensure that the full body is visible', fullBodyVisible),
          SetupItem('Position yourself side-facing to the camera', sideFacingOk),
          SetupItem('Keep enough space for your arms and legs', spaceOk),
        ],
      );
    }

    if (_isJumpingJack(title)) {
      return SetupChecklist(
        items: [
          SetupItem('Stand 4-6 feet from the camera', distanceOk),
          SetupItem('Ensure that the full body is visible', fullBodyVisible),
          SetupItem('Face the camera directly', frontFacingOk),
          SetupItem(
            'Keep your body centered, with extra space on the sides',
            centeredOk && spaceOk,
          ),
        ],
      );
    }

    return SetupChecklist(
      items: [
        SetupItem('Stand 4–6 feet from the camera', distanceOk),
        SetupItem('Ensure that the full body is visible', fullBodyVisible),
        SetupItem('Keep enough space for your arms and legs', spaceOk),
      ],
    );
  }


 Widget _buildCameraWithOverlay() {
  final controller = _controller;
  if (controller == null || !controller.value.isInitialized) {
    return const Center(child: CircularProgressIndicator());
  }

  return LayoutBuilder(
    builder: (context, constraints) {
      final screenAspect = constraints.maxWidth / constraints.maxHeight;
      final previewAspect = controller.value.aspectRatio;

      final portraitPreviewAspect = 1 / previewAspect;
      
      final rawScale = math.max(
        screenAspect / portraitPreviewAspect,
        portraitPreviewAspect / screenAspect,
      );

      // keep it from over-zooming on weird aspect ratios
      final scale = rawScale.clamp(1.0, 1.6);

      return ClipRect(
        child: Transform.scale(
          scale: scale,
          alignment: Alignment.center,
          child: Center(
            child: AspectRatio(
              aspectRatio: portraitPreviewAspect,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CameraPreview(controller),
                  if (_imgSize != null && _imgRotation != null && _selectedCamera != null)
                    IgnorePointer(
                      child: CustomPaint(
                        painter: _PosePainter(
                          poses: _poses,
                          imageSize: _imgSize!,
                          rotation: _imgRotation!,
                          isFrontCamera: _selectedCamera!.lensDirection == CameraLensDirection.front,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final s = size.width / 375.0;

    final topInset = MediaQuery.of(context).padding.top;
    final appBarH = 44 * s;

    return Scaffold(
      backgroundColor: _bgDark,
      body: SafeArea(
        top: true,
        bottom: false,
        child: Stack(
          children: [
            Positioned.fill(
              child: _error != null
                  ? Container(
                      color: const Color(0xFF0F1A28),
                      alignment: Alignment.center,
                      padding: EdgeInsets.all(18 * s),
                      child: Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.92)),
                      ),
                    )
                  : (_initFuture == null || _controller == null)
                      ? Container(
                          color: const Color(0xFF0F1A28),
                          alignment: Alignment.center,
                          child: const CircularProgressIndicator(),
                        )
                      : _buildCameraWithOverlay(),
            ),

            // top fade
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: IgnorePointer(
                child: Container(
                  height: topInset + appBarH,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.65),
                        Colors.black.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // top bar
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(12 * s, 10 * s, 12 * s, 0),
                  child: Row(
                    children: [
                      InkWell(
                        onTap: () => Navigator.pop(context),
                        child: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                      ),
                      SizedBox(width: 12 * s),
                      Text(
                        'Setup Mode',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.95),
                          fontSize: 14 * s,
                          fontWeight: FontWeight.w600,
                          shadows: const [Shadow(blurRadius: 8, color: Colors.black)],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Big checklist (glass popup)
            if (_countdown == 0)
              Positioned(
                left: 14 * s,
                right: 14 * s,
                top: 64 * s,
                child: _ChecklistCard(
                  s: s,
                  title: widget.workout.title.toUpperCase(),
                  subtitle: _allReady ? 'All set! Starting soon…' : 'Fix the RED items to start.',
                  checklist: _checklist,
                ),
              ),

            // Countdown overlay (5..1)
            if (_countdown > 0)
              Positioned.fill(
                child: IgnorePointer(
                  child: Center(
                    child: Container(
                      width: 160 * s,
                      height: 160 * s,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.35),
                          width: 2,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '$_countdown',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 64 * s,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// -------------------------
// Checklist models + UI
// -------------------------
class SetupChecklist {
  const SetupChecklist({required this.items});
  final List<SetupItem> items;

  factory SetupChecklist.empty() => const SetupChecklist(items: []);

  bool get allMet => items.isNotEmpty && items.every((e) => e.ok);
}

class SetupItem {
  const SetupItem(this.text, this.ok);
  final String text;
  final bool ok;
}

class _ChecklistCard extends StatelessWidget {
  const _ChecklistCard({
    required this.s,
    required this.title,
    required this.subtitle,
    required this.checklist,
  });

  final double s;
  final String title;
  final String subtitle;
  final SetupChecklist checklist;

  @override
  Widget build(BuildContext context) {
    final items = checklist.items;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16 * s),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: EdgeInsets.all(16 * s),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(16 * s),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.18),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.30),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 18 * s,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  shadows: const [Shadow(blurRadius: 8, color: Colors.black)],
                ),
              ),
              SizedBox(height: 6 * s),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 13 * s,
                  fontWeight: FontWeight.w800,
                  color: Colors.white.withValues(alpha: 0.85),
                  height: 1.25,
                ),
              ),
              SizedBox(height: 12 * s),
              if (items.isEmpty)
                Text(
                  'Detecting your pose…',
                  style: TextStyle(
                    fontSize: 14 * s,
                    fontWeight: FontWeight.w800,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                )
              else
                Column(
                  children: [
                    for (final it in items)
                      Padding(
                        padding: EdgeInsets.only(bottom: 10 * s),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 28 * s,
                              height: 28 * s,
                              decoration: BoxDecoration(
                                color: it.ok
                                    ? const Color(0xFF00C951)
                                    : const Color(0xFFE53935),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                it.ok ? Icons.check_rounded : Icons.close_rounded,
                                color: Colors.white,
                                size: 18 * s,
                              ),
                            ),
                            SizedBox(width: 12 * s),
                            Expanded(
                              child: Text(
                                it.text,
                                style: TextStyle(
                                  fontSize: 15 * s,
                                  fontWeight: FontWeight.w900,
                                  height: 1.25,
                                  color: Colors.white.withValues(alpha: 0.92),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// -------------------------
// Pose painter (white dots/lines)
// -------------------------
class _PosePainter extends CustomPainter {
  _PosePainter({
    required this.poses,
    required this.imageSize,
    required this.rotation,
    required this.isFrontCamera,
  });

  final List<Pose> poses;
  final Size imageSize;
  final InputImageRotation rotation;
  final bool isFrontCamera;

  @override
  void paint(Canvas canvas, Size size) {
    final dot = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.white;

    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: 0.9);

    double tx(double x) {
      double mapped;
      switch (rotation) {
        case InputImageRotation.rotation90deg:
          mapped = x * size.width / imageSize.height;
          break;
        case InputImageRotation.rotation270deg:
          mapped = size.width - (x * size.width / imageSize.height);
          break;
        default:
          mapped = x * size.width / imageSize.width;
      }
      return mapped;
    }

    double ty(double y) {
      switch (rotation) {
        case InputImageRotation.rotation90deg:
        case InputImageRotation.rotation270deg:
          return y * size.height / imageSize.width;
        default:
          return y * size.height / imageSize.height;
      }
    }

    Offset t(double x, double y) => Offset(tx(x), ty(y));

    for (final pose in poses) {
      final lm = pose.landmarks;

      void connect(PoseLandmarkType a, PoseLandmarkType b) {
        final pa = lm[a];
        final pb = lm[b];
        if (pa == null || pb == null) return;
        canvas.drawLine(t(pa.x, pa.y), t(pb.x, pb.y), line);
      }

      connect(PoseLandmarkType.leftShoulder, PoseLandmarkType.rightShoulder);

      connect(PoseLandmarkType.leftShoulder, PoseLandmarkType.leftElbow);
      connect(PoseLandmarkType.leftElbow, PoseLandmarkType.leftWrist);

      connect(PoseLandmarkType.rightShoulder, PoseLandmarkType.rightElbow);
      connect(PoseLandmarkType.rightElbow, PoseLandmarkType.rightWrist);

      connect(PoseLandmarkType.leftShoulder, PoseLandmarkType.leftHip);
      connect(PoseLandmarkType.rightShoulder, PoseLandmarkType.rightHip);
      connect(PoseLandmarkType.leftHip, PoseLandmarkType.rightHip);

      connect(PoseLandmarkType.leftHip, PoseLandmarkType.leftKnee);
      connect(PoseLandmarkType.leftKnee, PoseLandmarkType.leftAnkle);

      connect(PoseLandmarkType.rightHip, PoseLandmarkType.rightKnee);
      connect(PoseLandmarkType.rightKnee, PoseLandmarkType.rightAnkle);

      for (final landmark in lm.values) {
        canvas.drawCircle(t(landmark.x, landmark.y), 4, dot);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PosePainter old) =>
      old.poses != poses ||
      old.imageSize != imageSize ||
      old.rotation != rotation ||
      old.isFrontCamera != isFrontCamera;
}
