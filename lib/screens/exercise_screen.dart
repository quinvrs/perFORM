import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../models/workout.dart';
import '../models/workout_plan.dart';
import '../app_state.dart';
import '../services/rep_counter_squats.dart';
import '../services/rep_counter_jumping_jacks.dart';
import '../services/tts_service.dart';

enum _Phase { setup, active, rest, continueNext, finished }

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
  Size? _canvasSize;

  // session timer (top-right)
  int _elapsed = 0;
  Timer? _elapsedTimer;
  bool _elapsedFrozen = false;

  // exercise flow
  _Phase _phase = _Phase.active;
  int _setIndex = 1; // 1..sets

  // reps
  RepCounter _repCounter = RepCounter.squat();
  final JumpingJacksRepCounter _jjCounter = JumpingJacksRepCounter();
  int _reps = 0; // reps for current set
  int _totalReps = 0; // total reps across sets
  bool _setCommitted = false;

  // timed-set support
  Timer? _setTimer;
  int _setRemaining = 0;

  // rest
  late final int _restSecondsDefault;
  Timer? _restTimer;
  late int _restRemaining;

  SetupChecklist _checklist = SetupChecklist.empty();
  bool _allReady = false;
  int _countdown = 0;
  Timer? _countdownTimer;
  static const int _setupCountdownSeconds = 5;

  bool get _isJumpingJacks =>
      widget.workout.title.toLowerCase().contains('jump') ||
      widget.workout.title.toLowerCase().contains('jack');

  bool _isSquat(String title) => title.toLowerCase().contains('squat');
  bool _isJumpingJack(String title) =>
      title.toLowerCase().contains('jump') || title.toLowerCase().contains('jack');

  @override
  void initState() {
    super.initState();

    _restSecondsDefault = widget.plan.restSeconds;
    _restRemaining = _restSecondsDefault;

    _poseDetector = PoseDetector(
      options: PoseDetectorOptions(
        mode: PoseDetectionMode.stream,
        model: PoseDetectionModel.base,
      ),
    );

    _startElapsedTimer();
    _startSetIfTimed();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initCamera();
    });
  }

  @override
  void dispose() {
    _elapsedTimer?.cancel();
    _setTimer?.cancel();
    _restTimer?.cancel();
    _countdownTimer?.cancel();

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
  // Timers
  // -------------------------

  void _freezeElapsedTimer() {
    _elapsedFrozen = true;
  }

  void _startElapsedTimer() {
    _elapsedTimer?.cancel();
    _elapsedFrozen = false;

    _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_elapsedFrozen) return;
      setState(() => _elapsed++);
    });
  }

  void _startSetIfTimed() {
    if (!widget.plan.isTimed) return;

    _setTimer?.cancel();
    _setRemaining = _secondsFromTimerLabel(widget.plan.timerLabel);

    _setTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_phase != _Phase.active) return; // freeze during rest/setup/continue
      setState(() => _setRemaining--);

      if (_setRemaining <= 0) {
        t.cancel();
        _setTimer = null;
        _completeSet();
      }
    });
  }

  void _resetForNextSet({bool startTimedTimer = false}) {
    _reps = 0;
    _setCommitted = false;

    if (_isJumpingJacks) {
      _jjCounter.reset();
    } else {
      _repCounter = RepCounter.squat();
    }

    // prepare set timer value (but don't start unless requested)
    if (widget.plan.isTimed) {
      _setRemaining = _secondsFromTimerLabel(widget.plan.timerLabel);
      if (startTimedTimer) _startSetIfTimed();
    }
  }

  void _commitSetRepsOnce() {
    if (_setCommitted) return;
    _totalReps += _reps;
    _setCommitted = true;
  }

  void _completeSet() {
    if (_phase != _Phase.active) return;
    _commitSetRepsOnce();

    if (_setIndex >= widget.plan.sets) {
      _setTimer?.cancel();
      _setTimer = null;
      _restTimer?.cancel();
      _restTimer = null;
      _countdownTimer?.cancel();
      _countdownTimer = null;

      _freezeElapsedTimer();
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

        _freezeElapsedTimer();
        if (mounted) setState(() => _phase = _Phase.continueNext);
      }
    });
  }

  void _skipRest() {
    _restTimer?.cancel();
    _restTimer = null;

    _freezeElapsedTimer();

    setState(() {
      _restRemaining = 0;
      _phase = _Phase.continueNext;
    });
  }

  void _continueNextSet() {
    if (_phase != _Phase.continueNext) return;

    // freeze session timer while in setup (like you wanted)
    _freezeElapsedTimer();

    // stop any leftover countdown
    _stopCountdown();

    // reset checklist UI
    _checklist = SetupChecklist.empty();
    _allReady = false;

    // reset reps now so next set starts clean
    _resetForNextSet(startTimedTimer: false);

    setState(() => _phase = _Phase.setup);
  }

  // -------------------------
  // Setup-mode replication
  // -------------------------

  void _startCountdown({required int seconds}) {
    _countdownTimer?.cancel();
    _countdown = seconds;

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => _countdown--);

      if (_countdown <= 0) {
        t.cancel();
        _countdownTimer = null;
        _beginNextSetAfterSetup();
      }
    });

    if (mounted) setState(() {});
  }

  void _stopCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
    if (mounted) setState(() => _countdown = 0);
  }

  void _beginNextSetAfterSetup() {
    if (_setIndex >= widget.plan.sets) {
      _freezeElapsedTimer();
      setState(() => _phase = _Phase.finished);
      return;
    }

    // Start timers again
    _startElapsedTimer();

    setState(() {
      _setIndex++;
      _phase = _Phase.active;
    });

    // start timed set timer only when active
    if (widget.plan.isTimed) _startSetIfTimed();
  }

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
          SetupItem('Stand 6–8 feet from the camera', distanceOk),
          SetupItem('Ensure that the full body is visible', fullBodyVisible),
          SetupItem('Position yourself side-facing to the camera', sideFacingOk),
          SetupItem('Keep enough space for your arms and legs', spaceOk),
        ],
      );
    }

    if (_isJumpingJack(title)) {
      return SetupChecklist(
        items: [
          SetupItem('Stand 6–8 feet from the camera', distanceOk),
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
        SetupItem('Stand 6–8 feet from the camera', distanceOk),
        SetupItem('Ensure that the full body is visible', fullBodyVisible),
        SetupItem('Keep enough space for your arms and legs', spaceOk),
      ],
    );
  }

  // -------------------------
  // Camera init + pose stream
  // -------------------------

  Future<void> _initCamera() async {
    try {
      await Future.delayed(const Duration(milliseconds: 300));

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

      CameraController? ctrl;
      try {
        ctrl = CameraController(
          chosen,
          ResolutionPreset.medium,
          enableAudio: false,
          imageFormatGroup: Platform.isAndroid ? ImageFormatGroup.nv21 : ImageFormatGroup.bgra8888,
        );
        _controller = ctrl;
        _initFuture = ctrl.initialize();
        await _initFuture;
      } catch (_) {
        try {
          await ctrl?.dispose();
        } catch (_) {}

        ctrl = CameraController(
          chosen,
          ResolutionPreset.medium,
          enableAudio: false,
          imageFormatGroup: Platform.isAndroid ? ImageFormatGroup.yuv420 : ImageFormatGroup.bgra8888,
        );
        _controller = ctrl;
        _initFuture = ctrl.initialize();
        await _initFuture;
      }

      _selectedCamera = chosen;

      await _controller!.startImageStream((CameraImage image) async {
        if (_isDetecting) return;
        _isDetecting = true;

        try {
          final detector = _poseDetector;
          if (detector == null) return;

          final inputImage = _cameraImageToInputImage(image, chosen);
          if (inputImage == null) return;

          final poses = await detector.processImage(inputImage);
          if (mounted) setState(() => _poses = poses);

          if (_phase == _Phase.setup) {
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
            if (_countdown == 0 && ready) _startCountdown(seconds: _setupCountdownSeconds);

            if (mounted) {
              setState(() {
                _checklist = c;
                _allReady = ready;
              });
            }
            return;
          }

          if (_phase != _Phase.active) return;
          if (poses.isEmpty) return;

          // Jumping Jacks: count reps even if timed
          if (_isJumpingJacks) {
            // Need camera + mapping context for robust detection
            if (_imgSize == null || _imgRotation == null || _selectedCamera == null) return;

          final canvasSize = _canvasSize ??
              (() {
                final previewSize = _controller?.value.previewSize;
                if (previewSize == null) return null;
                return Size(previewSize.height, previewSize.width);
              })();

          if (canvasSize == null) return;

            final had = _jjCounter.update(
              pose: poses.first,
              canvasSize: canvasSize,
              imageSize: _imgSize!,
              rotation: _imgRotation!,
              lensDirection: _selectedCamera!.lensDirection,
            );

            if (had || _jjCounter.reps != _reps) {
              if (mounted) setState(() => _reps = _jjCounter.reps);
            }
            return;
          }

// Squats: reps-based only
            final hadRep = _repCounter.update(poses.first);
            if (hadRep) {
              final newReps = _repCounter.reps;
              if (mounted) setState(() => _reps = newReps);

              if (_reps >= widget.plan.reps) {
                _completeSet();
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
    final b = BytesBuilder(copy: false);
    for (final p in planes) {
      b.add(p.bytes);
    }
    return b.toBytes();
  }

  // -------------------------
  // Summary nav
  // -------------------------
  Future<void> _viewExerciseSummary() async {
    _freezeElapsedTimer();

    final state = AppStateScope.of(context);
    await Future.sync(() => state.setWorkoutDay(DateTime.now(), true));

    _commitSetRepsOnce();

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
          totalReps: _totalReps,
        ),
      ),
    );
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
      final screenAspect = constraints.maxWidth / constraints.maxHeight;

      // camera plugin gives landscape-ish aspect for portrait preview
      final previewAspect = controller.value.aspectRatio;
      final portraitPreviewAspect = 1 / previewAspect;

      // cover scale, clamped (same as your SetupModeScreen fix)
      final rawScale = math.max(
        screenAspect / portraitPreviewAspect,
        portraitPreviewAspect / screenAspect,
      );
      final scale = rawScale.clamp(1.0, 1.6);

      // compute the actual on-screen size of the AspectRatio box (before scaling)
      final boxW = constraints.maxWidth;
      final boxH = constraints.maxHeight;

      double paintW, paintH;
      if (boxW / boxH > portraitPreviewAspect) {
        // screen is wider → height matches, width follows aspect
        paintH = boxH;
        paintW = boxH * portraitPreviewAspect;
      } else {
        // screen is narrower → width matches, height follows aspect
        paintW = boxW;
        paintH = boxW / portraitPreviewAspect;
      }
      _canvasSize = Size(paintW, paintH);

      return ClipRect(
        child: Transform.scale(
          scale: scale.toDouble(),
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
                      child: RepaintBoundary(
                        child: CustomPaint(
                          painter: _PosePainter(
                            poses: _poses,
                            imageSize: _imgSize!,
                            rotation: _imgRotation!,
                            isFrontCamera:
                                _selectedCamera!.lensDirection == CameraLensDirection.front,
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

            if (_phase == _Phase.setup && _countdown == 0)
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

            if (_phase == _Phase.setup && _countdown > 0)
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

            // bottom card
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
                  onViewSummary: _viewExerciseSummary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomWorkoutCard extends StatefulWidget {
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
    required this.onViewSummary,
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
  State<_BottomWorkoutCard> createState() => _BottomWorkoutCardState();
}

class _BottomWorkoutCardState extends State<_BottomWorkoutCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _plusCtrl;
  late final Animation<double> _plusOpacity;
  late final Animation<double> _plusScale;
  late final Animation<Offset> _plusSlide;

  int _prevReps = 0;
  String _plusText = '+1';

  @override
  void initState() {
    super.initState();
    _prevReps = widget.repsDone;

    _plusCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );

    _plusCtrl.value = 1.0;

    _plusOpacity = CurvedAnimation(
      parent: _plusCtrl,
      curve: Curves.easeOut,
    );

    _plusScale = Tween<double>(begin: 0.85, end: 1.12).animate(
      CurvedAnimation(parent: _plusCtrl, curve: Curves.elasticOut),
    );

    _plusSlide = Tween<Offset>(
      begin: const Offset(0, 0.25),
      end: const Offset(0, -0.85),
    ).animate(
      CurvedAnimation(parent: _plusCtrl, curve: Curves.easeOut),
    );
  }

  @override
  void didUpdateWidget(covariant _BottomWorkoutCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    final inc = widget.repsDone - _prevReps;
    if (inc > 0) {
      _plusText = inc == 1 ? '+1' : '+$inc';
      _plusCtrl.forward(from: 0);
    }

    _prevReps = widget.repsDone;
  }

  @override
  void dispose() {
    _plusCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;

    final timerStyle = TextStyle(
      color: _BottomWorkoutCard._ink,
      fontSize: 30 * s,
      fontWeight: FontWeight.w900,
    );

    final repsStyle = TextStyle(
      color: _BottomWorkoutCard._ink.withValues(alpha: 0.80),
      fontSize: 20 * s,
      fontWeight: FontWeight.w800,
    );

    final border = (widget.phase == _Phase.continueNext ||
            widget.phase == _Phase.finished ||
            widget.phase == _Phase.setup)
        ? Border.all(color: const Color(0xFF22C55E), width: 3)
        : null;

    return Container(
      padding: EdgeInsets.fromLTRB(14 * s, 12 * s, 14 * s, 14 * s),
      decoration: BoxDecoration(
        color: _BottomWorkoutCard._cardBg.withValues(alpha: 0.92),
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
          Row(
            children: [
              Text(
                widget.title,
                style: TextStyle(
                  color: _BottomWorkoutCard._ink,
                  fontSize: 12 * s,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.2,
                ),
              ),
              const Spacer(),
              Text(
                widget.elapsed,
                style: TextStyle(
                  color: _BottomWorkoutCard._ink.withValues(alpha: 0.85),
                  fontSize: 12 * s,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          SizedBox(height: 10 * s),

          if (widget.phase == _Phase.active) ...[
            if (widget.isTimed)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(_fmt(widget.setRemaining), style: timerStyle),
                  SizedBox(width: 26 * s),
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 14 * s, vertical: 10 * s),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF9C2).withValues(alpha: 0.60),
                          borderRadius: BorderRadius.circular(14 * s),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.10),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Text('REPS: ${widget.repsDone}', style: repsStyle),
                      ),
                      Positioned(
                        right: 2 * s,
                        top: -18 * s,
                        child: FadeTransition(
                          opacity: Tween<double>(begin: 1, end: 0).animate(_plusOpacity),
                          child: SlideTransition(
                            position: _plusSlide,
                            child: ScaleTransition(
                              scale: _plusScale,
                              child: Text(
                                _plusText,
                                style: TextStyle(
                                  color: const Color(0xFF22C55E),
                                  fontSize: 18 * s,
                                  fontWeight: FontWeight.w900,
                                  shadows: const [Shadow(blurRadius: 10, color: Colors.black)],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              )
            else
              Text('${widget.repsDone}/${widget.repsTarget}', style: timerStyle),
            SizedBox(height: 6 * s),
            Text(
              'SET ${widget.setIndex}/${widget.setsTotal}',
              style: TextStyle(
                color: _BottomWorkoutCard._ink.withValues(alpha: 0.75),
                fontSize: 12 * s,
                fontWeight: FontWeight.w800,
              ),
            ),
          ] else if (widget.phase == _Phase.rest) ...[
            Text(_fmt(widget.restRemaining), style: timerStyle),
            SizedBox(height: 2 * s),
            Text(
              'REST',
              style: TextStyle(
                color: _BottomWorkoutCard._ink.withValues(alpha: 0.75),
                fontSize: 12 * s,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 10 * s),
            _DarkButton(s: s, label: 'Skip', onTap: widget.onSkipRest),
          ] else if (widget.phase == _Phase.setup) ...[
            Text(
              'SETUP MODE',
              style: TextStyle(
                color: _BottomWorkoutCard._ink,
                fontSize: 18 * s,
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(height: 6 * s),
            Text(
              'Fix the checklist above.\nCountdown starts automatically.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _BottomWorkoutCard._ink.withValues(alpha: 0.75),
                fontSize: 12 * s,
                fontWeight: FontWeight.w800,
                height: 1.25,
              ),
            ),
            SizedBox(height: 10 * s),
            Text(
              'Next: SET ${widget.setIndex + 1}/${widget.setsTotal}',
              style: TextStyle(
                color: _BottomWorkoutCard._ink.withValues(alpha: 0.8),
                fontSize: 12 * s,
                fontWeight: FontWeight.w800,
              ),
            ),
          ] else if (widget.phase == _Phase.continueNext) ...[
            SizedBox(height: 4 * s),
            _PrimaryYellowButton(s: s, label: 'Continue', onTap: widget.onContinue),
            SizedBox(height: 10 * s),
            _DarkButton(s: s, label: 'Mark workout done', onTap: widget.onViewSummary),
            SizedBox(height: 10 * s),
            Text(
              'Set ${widget.setIndex + 1}/${widget.setsTotal}',
              style: TextStyle(
                color: _BottomWorkoutCard._ink.withValues(alpha: 0.8),
                fontSize: 12 * s,
                fontWeight: FontWeight.w800,
              ),
            ),
          ] else ...[
            Text(
              'Workout Complete!',
              style: TextStyle(
                color: _BottomWorkoutCard._ink,
                fontSize: 26 * s,
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(height: 10 * s),
            _DarkButton(s: s, label: 'View Exercise Summary', onTap: widget.onViewSummary),
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
            color: Colors.white,
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
// Checklist models + UI (same feel as SetupModeScreen)
// ---------------------------------------
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

// ============================
// Exercise Summary Screen
// ============================
class ExerciseSummaryScreen extends StatelessWidget {
  const ExerciseSummaryScreen({
    super.key,
    required this.workout,
    required this.plan,
    required this.elapsedSeconds,
    required this.totalReps,
  });

  final Workout workout;
  final WorkoutPlan plan;
  final int elapsedSeconds;
  final int totalReps;

  static const _ink = Color(0xFF051328);
  static const _yellow = Color(0xFFFEF9C2);

  @override
  Widget build(BuildContext context) {
    final s = MediaQuery.sizeOf(context).width / 375.0;

    return Scaffold(
      backgroundColor: const Color(0xFF0F1A28),
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF0F1A28), Color(0xFF1F2B3C)],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: Container(color: Colors.black.withValues(alpha: 0.25)),
          ),
          SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(18 * s, 12 * s, 18 * s, 18 * s),
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          InkWell(
                            onTap: () => Navigator.pop(context),
                            borderRadius: BorderRadius.circular(999),
                            child: Container(
                              width: 42 * s,
                              height: 42 * s,
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.35),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.15),
                                ),
                              ),
                              child: const Icon(
                                Icons.arrow_back_rounded,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          SizedBox(height: 18 * s),
                          Text(
                            "Nice, you've\ncompleted the\nexercise!",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 30 * s,
                              fontWeight: FontWeight.w900,
                              height: 1.05,
                            ),
                          ),
                          SizedBox(height: 12 * s),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 14 * s,
                              vertical: 10 * s,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(14 * s),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.15),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.fitness_center_rounded,
                                  color: Colors.white.withValues(alpha: 0.9),
                                  size: 18 * s,
                                ),
                                SizedBox(width: 10 * s),
                                Expanded(
                                  child: Text(
                                    workout.title,
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.95),
                                      fontSize: 14 * s,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: 16 * s),
                          Container(
                            padding: EdgeInsets.all(14 * s),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.92),
                              borderRadius: BorderRadius.circular(16 * s),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.25),
                                  blurRadius: 16,
                                  offset: const Offset(0, 8),
                                )
                              ],
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: _StatBox(
                                    s: s,
                                    label: 'Repetitions',
                                    value: '$totalReps',
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
                                    valueColor: _ink,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: 14 * s),
                          Container(
                            width: double.infinity,
                            padding: EdgeInsets.all(16 * s),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.90),
                              borderRadius: BorderRadius.circular(16 * s),
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
                        ],
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: () => Navigator.popUntil(context, (r) => r.isFirst),
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
          ),
        ],
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
// helpers
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
