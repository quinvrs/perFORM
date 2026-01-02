// lib/screens/exercise_screen.dart
import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../models/workout.dart';
import '../models/workout_plan.dart';
import '../app_state.dart';
import '../services/rep_counter_squats.dart';

enum _Phase { active, rest, continueNext, finished }

class ExerciseScreen extends StatefulWidget {
  const ExerciseScreen({
    super.key,
    required this.workout,
    required this.plan,
  });

  final Workout workout;
  final WorkoutPlan plan;

  @override
  State<ExerciseScreen> createState() => _ExerciseScreenState();
}

class _ExerciseScreenState extends State<ExerciseScreen> {
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

  // session timer (top-right)
  int _elapsed = 0;
  Timer? _elapsedTimer;

  // exercise flow
  _Phase _phase = _Phase.active;
  int _setIndex = 1; // 1..sets

  // reps (for non-timed)
  RepCounter _repCounter = RepCounter.squat();
  int _reps = 0;

  // timed-set support
  Timer? _setTimer;
  int _setRemaining = 0;

  // rest
  static const int _restSecondsDefault = 30;
  Timer? _restTimer;
  int _restRemaining = _restSecondsDefault;

  @override
  void initState() {
    super.initState();

    _poseDetector = PoseDetector(
      options: PoseDetectorOptions(
        mode: PoseDetectionMode.stream,
        model: PoseDetectionModel.base,
      ),
    );

    _startElapsedTimer();
    _startSetIfTimed();
    _initCamera();
  }

  @override
  void dispose() {
    _elapsedTimer?.cancel();
    _setTimer?.cancel();
    _restTimer?.cancel();

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

  void _startElapsedTimer() {
    _elapsedTimer?.cancel();
    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _elapsed++);
    });
  }

  void _startSetIfTimed() {
    if (!widget.plan.isTimed) return;

    _setTimer?.cancel();
    _setRemaining = _secondsFromTimerLabel(widget.plan.timerLabel);

    _setTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => _setRemaining--);

      if (_setRemaining <= 0) {
        t.cancel();
        _setTimer = null;
        _completeSet();
      }
    });
  }

  void _resetForNextSet() {
    _reps = 0;
    _repCounter = RepCounter.squat();
    if (widget.plan.isTimed) _startSetIfTimed();
  }

  void _completeSet() {
    if (_phase != _Phase.active) return;

    if (_setIndex >= widget.plan.sets) {
      setState(() => _phase = _Phase.finished);
      return;
    }

    _setTimer?.cancel();
    _setTimer = null;

    _restRemaining = _restSecondsDefault;
    setState(() => _phase = _Phase.rest);

    _restTimer?.cancel();
    _restTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => _restRemaining--);

      if (_restRemaining <= 0) {
        t.cancel();
        _restTimer = null;
        if (mounted) setState(() => _phase = _Phase.continueNext);
      }
    });
  }

  void _skipRest() {
    _restTimer?.cancel();
    _restTimer = null;
    setState(() {
      _restRemaining = 0;
      _phase = _Phase.continueNext;
    });
  }

  void _continueNextSet() {
    setState(() {
      _setIndex++;
      _phase = _Phase.active;
    });
    _resetForNextSet();
  }

  Future<void> _viewExerciseSummary() async {
    final state = AppStateScope.of(context);
    await Future.sync(() => state.setWorkoutDay(DateTime.now(), true));

    // Clean up camera immediately before summary (prevents black preview issues on some devices)
    final old = _controller;
    _controller = null;

    try {
      await old?.stopImageStream();
    } catch (_) {}
    try {
      await old?.dispose();
    } catch (_) {}

    try {
      await _poseDetector?.close();
    } catch (_) {}
    _poseDetector = null;

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => ExerciseSummaryScreen(
          workout: widget.workout,
          plan: widget.plan,
          elapsedSeconds: _elapsed,
          repsLastSet: _reps,
        ),
      ),
    );
  }

  // -------------------------
  // Camera init + pose stream
  // -------------------------
  Future<void> _initCamera() async {
    try {
      await Future.delayed(const Duration(milliseconds: 200));

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
        imageFormatGroup: Platform.isAndroid ? ImageFormatGroup.yuv420 : ImageFormatGroup.bgra8888,
      );

      _controller = ctrl;
      _initFuture = ctrl.initialize();
      await _initFuture;

      _selectedCamera = chosen;

      await ctrl.startImageStream((CameraImage image) async {
        if (_isDetecting) return;
        _isDetecting = true;

        try {
          final detector = _poseDetector;
          if (detector == null) return;

          final inputImage = _cameraImageToInputImage(image, chosen);
          if (inputImage == null) return;

          final poses = await detector.processImage(inputImage);

          if (mounted) setState(() => _poses = poses);

          // count reps only during active + non-timed
          if (_phase == _Phase.active && !widget.plan.isTimed && poses.isNotEmpty) {
            final hadRep = _repCounter.update(poses.first);
            if (hadRep) {
              final newReps = _repCounter.reps;
              if (mounted) setState(() => _reps = newReps);

              if (_reps >= widget.plan.reps) {
                _completeSet();
              }
            }
          }
        } catch (e, st) {
          debugPrint('Exercise pose error: $e\n$st');
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
  // Camera -> MLKit InputImage
  // -------------------------
  static const _orientations = <DeviceOrientation, int>{
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
      final controller = _controller;
      if (controller == null) return null;

      final deviceOrientation = controller.value.deviceOrientation;
      final rotationCompensation = _orientations[deviceOrientation] ?? 0;

      final rot = camera.lensDirection == CameraLensDirection.front
          ? (sensorOrientation + rotationCompensation) % 360
          : (sensorOrientation - rotationCompensation + 360) % 360;

      rotation = InputImageRotationValue.fromRawValue(rot);
    }

    if (rotation == null) return null;

    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null) return null;

    if (Platform.isAndroid) {
      final ok = format == InputImageFormat.nv21 || format == InputImageFormat.yuv420;
      if (!ok) return null;
    }
    if (Platform.isIOS && format != InputImageFormat.bgra8888) return null;

    final bytes = _bytesFromPlanes(image.planes);

    final imgSize = Size(image.width.toDouble(), image.height.toDouble());
    _imgRotation = rotation;
    _imgSize = imgSize;

    return InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size: imgSize,
        rotation: rotation,
        format: format,
        bytesPerRow: image.planes.first.bytesPerRow,
      ),
    );
  }

  Uint8List _bytesFromPlanes(List<Plane> planes) {
    final allBytes = WriteBuffer();
    for (final plane in planes) {
      allBytes.putUint8List(plane.bytes);
    }
    return allBytes.done().buffer.asUint8List();
  }

  // -------------------------
  // UI
  // -------------------------
  Widget _buildCameraWithOverlay() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final previewSize = controller.value.previewSize!;
        final screenW = constraints.maxWidth;
        final screenH = constraints.maxHeight;

        final previewW = previewSize.height;
        final previewH = previewSize.width;

        final scaleW = screenW / previewW;
        final scaleH = screenH / previewH;
        final scale = scaleW > scaleH ? scaleW : scaleH;

        return ClipRect(
          child: Center(
            child: Transform.scale(
              scale: scale,
              alignment: Alignment.center,
              child: SizedBox(
                width: previewW,
                height: previewH,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CameraPreview(controller),
                    if (_imgSize != null && _imgRotation != null && _selectedCamera != null)
                      IgnorePointer(
                        child: RepaintBoundary(
                          child: CustomPaint(
                            painter: _PosePainter(
                              poses: _poses,
                              imageSize: _imgSize!,
                              rotation: _imgRotation!,
                              isFrontCamera: _selectedCamera!.lensDirection == CameraLensDirection.front,
                            ),
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

    final title = widget.workout.title.toUpperCase();

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
                      SizedBox(width: 10 * s),
                      Text(
                        'Workout',
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

            // bottom control card
            Positioned(
              left: 14 * s,
              right: 14 * s,
              bottom: 14 * s,
              child: SafeArea(
                top: false,
                bottom: true,
                child: _BottomWorkoutCard(
                  s: s,
                  title: title,
                  elapsed: _fmt(_elapsed),
                  phase: _phase,
                  setIndex: _setIndex,
                  setsTotal: widget.plan.sets,
                  repsDone: _reps,
                  repsTarget: widget.plan.reps,
                  isTimed: widget.plan.isTimed,
                  setRemaining: _setRemaining,
                  restRemaining: _restRemaining,
                  onSkipRest: _skipRest,
                  onContinue: _continueNextSet,
                  onViewSummary: _viewExerciseSummary, // ✅ new
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomWorkoutCard extends StatelessWidget {
  const _BottomWorkoutCard({
    required this.s,
    required this.title,
    required this.elapsed,
    required this.phase,
    required this.setIndex,
    required this.setsTotal,
    required this.repsDone,
    required this.repsTarget,
    required this.isTimed,
    required this.setRemaining,
    required this.restRemaining,
    required this.onSkipRest,
    required this.onContinue,
    required this.onViewSummary, // ✅ new
  });

  final double s;
  final String title;
  final String elapsed;
  final _Phase phase;

  final int setIndex;
  final int setsTotal;

  final int repsDone;
  final int repsTarget;

  final bool isTimed;
  final int setRemaining;

  final int restRemaining;

  final VoidCallback onSkipRest;
  final VoidCallback onContinue;
  final VoidCallback onViewSummary;

  static const _cardBg = Color(0xFFEFEFF3);
  static const _ink = Color(0xFF051328);

  @override
  Widget build(BuildContext context) {
    final border = (phase == _Phase.continueNext || phase == _Phase.finished)
        ? Border.all(color: const Color(0xFF22C55E), width: 3)
        : null;

    return Container(
      padding: EdgeInsets.fromLTRB(14 * s, 12 * s, 14 * s, 14 * s),
      decoration: BoxDecoration(
        color: _cardBg.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(18 * s),
        border: border,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // top row
          Row(
            children: [
              Text(
                title,
                style: TextStyle(
                  color: _ink,
                  fontSize: 12 * s,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.2,
                ),
              ),
              const Spacer(),
              Text(
                elapsed,
                style: TextStyle(
                  color: _ink.withValues(alpha: 0.85),
                  fontSize: 12 * s,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),

          SizedBox(height: 10 * s),

          if (phase == _Phase.active) ...[
            Text(
              isTimed ? _fmt(setRemaining) : '$repsDone/$repsTarget',
              style: TextStyle(
                color: _ink,
                fontSize: 30 * s,
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(height: 2 * s),
            Text(
              'SET $setIndex/$setsTotal',
              style: TextStyle(
                color: _ink.withValues(alpha: 0.75),
                fontSize: 12 * s,
                fontWeight: FontWeight.w800,
              ),
            ),
          ] else if (phase == _Phase.rest) ...[
            Text(
              _fmt(restRemaining),
              style: TextStyle(
                color: _ink,
                fontSize: 30 * s,
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(height: 2 * s),
            Text(
              'REST',
              style: TextStyle(
                color: _ink.withValues(alpha: 0.75),
                fontSize: 12 * s,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 10 * s),
            _DarkButton(s: s, label: 'Skip', onTap: onSkipRest),
          ] else if (phase == _Phase.continueNext) ...[
            SizedBox(height: 4 * s),
            _PrimaryYellowButton(
              s: s,
              label: 'Continue',
              onTap: onContinue,
            ),
            SizedBox(height: 10 * s),
            Text(
              'Set ${setIndex + 1}/$setsTotal',
              style: TextStyle(
                color: _ink.withValues(alpha: 0.8),
                fontSize: 12 * s,
                fontWeight: FontWeight.w800,
              ),
            ),
          ] else ...[
            // ✅ FINISHED
            Text(
              'FINISH', // ✅ was DONE
              style: TextStyle(
                color: _ink,
                fontSize: 26 * s,
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(height: 10 * s),
            // ✅ button identical to Continue, yellow + ink
            _PrimaryYellowButton(
              s: s,
              label: 'View Exercise Summary',
              onTap: onViewSummary,
            ),
          ],
        ],
      ),
    );
  }
}

class _DarkButton extends StatelessWidget {
  const _DarkButton({
    required this.s,
    required this.label,
    required this.onTap,
  });

  final double s;
  final String label;
  final VoidCallback onTap;

  static const _ink = Color(0xFF051328);
  static const _yellow = Color(0xFFFEF9C2);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14 * s),
      child: Container(
        height: 46 * s,
        width: double.infinity,
        decoration: BoxDecoration(
          color: _ink,
          borderRadius: BorderRadius.circular(14 * s),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: _yellow,
            fontSize: 14 * s,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _PrimaryYellowButton extends StatelessWidget {
  const _PrimaryYellowButton({
    required this.s,
    required this.label,
    required this.onTap,
  });

  final double s;
  final String label;
  final VoidCallback onTap;

  static const _ink = Color(0xFF051328);
  static const _yellow = Color(0xFFFEF9C2);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16 * s),
      child: Container(
        height: 52 * s,
        width: double.infinity,
        decoration: BoxDecoration(
          color: _yellow,
          borderRadius: BorderRadius.circular(16 * s),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _ink,
            fontSize: 16 * s,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------
// Pose overlay painter (white dots + lines)
// ---------------------------------------
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
      return isFrontCamera ? size.width - mapped : mapped;
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

// ============================
// Exercise Summary Screen (NEW)
// ============================
class ExerciseSummaryScreen extends StatelessWidget {
  const ExerciseSummaryScreen({
    super.key,
    required this.workout,
    required this.plan,
    required this.elapsedSeconds,
    required this.repsLastSet,
  });

  final Workout workout;
  final WorkoutPlan plan;
  final int elapsedSeconds;
  final int repsLastSet;

  static const _ink = Color(0xFF051328);
  static const _yellow = Color(0xFFFEF9C2);

  @override
  Widget build(BuildContext context) {
    final s = MediaQuery.sizeOf(context).width / 375.0;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            // background (optional)
            Positioned.fill(
              child: Image.asset(
                'assets/summary_bg.jpg',
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFF0F1A28), Color(0xFF1F2B3C)],
                    ),
                  ),
                ),
              ),
            ),

            // dark overlay for readability
            Positioned.fill(
              child: Container(color: Colors.black.withValues(alpha: 0.30)),
            ),

            // content
            SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(18 * s, 12 * s, 18 * s, 18 * s),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // back
                  InkWell(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 40 * s,
                      height: 40 * s,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.35),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                    ),
                  ),

                  SizedBox(height: 20 * s),

                  Text(
                    "Nice, you've\ncompleted the\nexercise!",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28 * s,
                      fontWeight: FontWeight.w900,
                      height: 1.05,
                    ),
                  ),

                  SizedBox(height: 14 * s),

                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 14 * s, vertical: 10 * s),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.88),
                      borderRadius: BorderRadius.circular(10 * s),
                    ),
                    child: Text(
                      workout.title,
                      style: TextStyle(
                        color: _ink,
                        fontSize: 14 * s,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),

                  SizedBox(height: 18 * s),

                  // stats card
                  Container(
                    padding: EdgeInsets.all(14 * s),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.94),
                      borderRadius: BorderRadius.circular(14 * s),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _StatBox(
                            s: s,
                            label: 'Repetitions',
                            value: plan.isTimed ? '-' : '$repsLastSet',
                          ),
                        ),
                        SizedBox(width: 10 * s),
                        Expanded(
                          child: _StatBox(
                            s: s,
                            label: 'Sets',
                            value: '${plan.sets}',
                          ),
                        ),
                        SizedBox(width: 10 * s),
                        Expanded(
                          child: _StatBox(
                            s: s,
                            label: 'Time',
                            value: _fmt(elapsedSeconds),
                            valueColor: _ink
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 14 * s),

                  // placeholder area like your screenshot
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(16 * s),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.90),
                      borderRadius: BorderRadius.circular(14 * s),
                    ),
                    child: Text(
                      'Exercise Summary\n\n'
                      '• Form score (coming soon)\n'
                      '• Accuracy / depth / tempo metrics (optional)\n'
                      '• Tips based on common mistakes',
                      style: TextStyle(
                        color: Colors.black.withValues(alpha: 0.75),
                        fontSize: 13 * s,
                        height: 1.35,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),

                  SizedBox(height: 18 * s),

                  // Next button
                  InkWell(
                    onTap: () => Navigator.pushNamedAndRemoveUntil(context, '/home', (_) => false),
                    borderRadius: BorderRadius.circular(16 * s),
                    child: Container(
                      height: 54 * s,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: _yellow,
                        borderRadius: BorderRadius.circular(16 * s),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Next',
                        style: TextStyle(
                          color: _ink,
                          fontSize: 16 * s,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  const _StatBox({
    required this.s,
    required this.label,
    required this.value,
    this.valueColor,
  });

  final double s;
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10 * s, vertical: 10 * s),
      decoration: BoxDecoration(
        color: const Color(0xFFEFEFF3),
        borderRadius: BorderRadius.circular(10 * s),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.black.withValues(alpha: 0.55),
              fontSize: 11 * s,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 6 * s),
          Text(
            value,
            style: TextStyle(
              color: valueColor ?? Colors.black,
              fontSize: 18 * s,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

// -------------------------
// small helpers
// -------------------------
int _secondsFromTimerLabel(String label) {
  final t = label.trim().toLowerCase();
  if (t.contains(':')) {
    final parts = t.split(':');
    if (parts.length == 2) {
      final m = int.tryParse(parts[0]) ?? 0;
      final s = int.tryParse(parts[1]) ?? 0;
      return (m * 60) + s;
    }
  }
  final stripped = t.endsWith('s') ? t.substring(0, t.length - 1) : t;
  return int.tryParse(stripped) ?? 30;
}

String _fmt(int seconds) {
  if (seconds < 0) seconds = 0;
  final h = seconds ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  final s = seconds % 60;

  if (h > 0) {
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
  return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
}
