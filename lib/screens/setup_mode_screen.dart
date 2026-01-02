import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';

import '../services/camera_setup_checker.dart';
import '../services/rep_counter_squats.dart';
import '../app_state.dart';

//import for pose detection
import 'dart:io';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

class SetupModeScreen extends StatefulWidget {
  const SetupModeScreen({super.key});

  @override
  State<SetupModeScreen> createState() => _SetupModeScreenState();
}

class _SetupModeScreenState extends State<SetupModeScreen> {
  static const _bgDark = Color.fromARGB(255, 18, 32, 47);

  CameraController? _controller;
  Future<void>? _initFuture;
  String? _error;

  //Add pose detector
  PoseDetector? _poseDetector;
  bool _isDetecting = false;

  List<Pose> _poses = const [];
  Size? _lastImageSize; // used for overlay scaling
  CameraDescription? _selectedCamera;
  InputImageRotation? _imgRotation;
  Size? _imgSize;

  final _checker = CameraSetupChecker();
  bool _setupReady = false;

  //add squat rep counter 
  late final RepCounter _repCounter = RepCounter.squat();
  int _reps = 0;

  @override
  void initState() {
    super.initState();

    //Initialize pose detector
    _poseDetector = PoseDetector(
    options: PoseDetectorOptions(
    mode: PoseDetectionMode.stream,
    model: PoseDetectionModel.base,
      ),
    );

    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final perm = await Permission.camera.request();
      if (!perm.isGranted) {
        if (mounted) setState(() => _error = 'Camera permission denied.');
        return;
      }

      final cams = await availableCameras();
      if (cams.isEmpty) {
        if (mounted) {
          setState(() => _error = 'No cameras found on this device/emulator.');
        }
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
        imageFormatGroup: Platform.isAndroid
        ? ImageFormatGroup.nv21
        : ImageFormatGroup.bgra8888,
      );

      _controller = ctrl;
      _initFuture = ctrl.initialize();
      await _initFuture;

      _selectedCamera = chosen;

      await ctrl.startImageStream((CameraImage image) async {
        if (_isDetecting) return;
        _isDetecting = true;

        try {
          final inputImage = _cameraImageToInputImage(image, _selectedCamera!);
          if (inputImage == null) {
            _isDetecting = false;
            return;
          }
          final poses = await _poseDetector!.processImage(inputImage);

            bool readyNow = _setupReady;

            if (_imgSize != null && _imgRotation != null && _selectedCamera != null) {
              final pSize = _controller!.value.previewSize!;
              final canvas = Size(pSize.height, pSize.width); // portrait canvas

              readyNow = _checker.update(
                poses: poses,
                canvasSize: canvas,
                imageSize: _imgSize!,
                rotation: _imgRotation!,
                lensDirection: _selectedCamera!.lensDirection,
              );
            }

          if (mounted) {
            final changedReady = readyNow != _setupReady;

            setState(() {
              _poses = poses;
              if (changedReady) _setupReady = readyNow;
            });
          }
        if (/*_setupReady && */_poses.isNotEmpty) {
          final hadRep = _repCounter.update(_poses.first);

          if (hadRep) {
            setState(() {
              _reps = _repCounter.reps;
            });
          }
        }

        } catch (e,st) {
          debugPrint('Pose error. $e');
          debugPrint('Pose error. $st'); //try if di maidentify
        } finally {
          _isDetecting = false;
        }
      });

      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) setState(() => _error = 'Camera error: $e');
    }
  }

  @override
  void dispose() {
    _controller?.stopImageStream();
    _controller?.dispose();
    _poseDetector?.close();
    super.dispose();
  }

static const _orientations = <DeviceOrientation, int>{
  DeviceOrientation.portraitUp: 0,
  DeviceOrientation.landscapeLeft: 90,
  DeviceOrientation.portraitDown: 180,
  DeviceOrientation.landscapeRight: 270,
};

InputImage? _cameraImageToInputImage(CameraImage image, CameraDescription camera) {
  // rotation
  final sensorOrientation = camera.sensorOrientation;
  InputImageRotation? rotation;

  if (Platform.isIOS) {
    rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
  } else if (Platform.isAndroid) {
    final rotationCompensation = _orientations[_controller!.value.deviceOrientation];
    if (rotationCompensation == null) return null;

    final rot = camera.lensDirection == CameraLensDirection.front
        ? (sensorOrientation + rotationCompensation) % 360
        : (sensorOrientation - rotationCompensation + 360) % 360;

    rotation = InputImageRotationValue.fromRawValue(rot);
  }

  if (rotation == null) return null;

  // format
  final format = InputImageFormatValue.fromRawValue(image.format.raw);
  if (format == null) return null;

  if (Platform.isAndroid && format != InputImageFormat.nv21) return null;
  if (Platform.isIOS && format != InputImageFormat.bgra8888) return null;

  if (image.planes.length != 1) return null;

  final plane = image.planes.first;

  final imgSize = Size(image.width.toDouble(), image.height.toDouble());

  // Save these for your painter overlay
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

//camera fix 
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

      // previewSize is landscape; in portrait we treat it as rotated
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
    final state = AppStateScope.of(context);

    // ✅ full-screen scale (design width = 375)
    final size = MediaQuery.sizeOf(context);
    final s = size.width / 375.0;

    final topInset = MediaQuery.of(context).padding.top;
    final appBarH = 44 * s; // tweak if you want taller top fade


    return Scaffold(
      backgroundColor: _bgDark,
      body: SafeArea(
        top: true,
        bottom: false,
        child: Stack(
          children: [
            // ✅ FULL SCREEN CAMERA PREVIEW (no centered phone card)
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
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(12 * s, 10 * s, 12 * s, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                      // Top bar
                      Row(
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
                              shadows: const [
                              Shadow(blurRadius: 8, color: Colors.black),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // instruction card
            if (!_setupReady)
                Positioned(
                left: 18 * s,
                right: 18 * s,
                top: 40 * s,
                child: Container(
                  padding: EdgeInsets.all(14 * s),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10 * s),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF000000).withValues(alpha: 0.35),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 34 * s,
                        height: 34 * s,
                        decoration: const BoxDecoration(
                          color: Color(0xFF00C951),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.camera_alt_rounded,
                          color: Colors.white,
                          size: 20 * s,
                        ),
                      ),
                      SizedBox(width: 12 * s),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Camera Setup',
                              style: TextStyle(
                                color: Colors.black,
                                fontSize: 16 * s,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            SizedBox(height: 6 * s),
                            Text(
                              'Position yourself within the frame\n'
                              '• Stand 6–8 feet from camera\n'
                              '• Ensure full body is visible\n'
                              '• Face the camera directly\n'
                              '• Good lighting recommended',
                              style: TextStyle(
                                color: const Color(0xFF797B7F),
                                fontSize: 11 * s,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Done button
            Positioned(
              left: 18 * s,
              right: 18 * s,
              bottom: 14 * s,
              child: SafeArea(
                top: false,
                bottom: true,
                child: InkWell(
                  onTap: () {
                    state.setWorkoutDay(DateTime.now(), true);
                    Navigator.pop(context, true);
                  },
                  child: Container(
                    height: 56 * s,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFF051328),
                      borderRadius: BorderRadius.circular(14 * s),
                    ),
                    child: Text(
                      'Mark Workout Done',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16 * s,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            //just to check if the pose detection is working [pose counter]
            Positioned(
              left: 16 * s,
              bottom: 90 * s, // above your button
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 10 * s, vertical: 6 * s),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(8 * s),
                ),
                  child: Text(
                    'counter: $_reps | ready: $_setupReady | ${_checker.lastReason}',
                    style: TextStyle(color: Colors.white, fontSize: 12 * s),
                  ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

//White node pose detection in the camera
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

        // Helper to safely draw a line between 2 landmarks
        void connect(PoseLandmarkType a, PoseLandmarkType b) {
          final pa = lm[a];
          final pb = lm[b];
          if (pa == null || pb == null) return;

          canvas.drawLine(t(pa.x, pa.y), t(pb.x, pb.y), line);
        }

        // ---- Skeleton connections ----

        // Face / head (simple)
        connect(PoseLandmarkType.leftShoulder, PoseLandmarkType.rightShoulder);

        // Left arm
        connect(PoseLandmarkType.leftShoulder, PoseLandmarkType.leftElbow);
        connect(PoseLandmarkType.leftElbow, PoseLandmarkType.leftWrist);

        // Right arm
        connect(PoseLandmarkType.rightShoulder, PoseLandmarkType.rightElbow);
        connect(PoseLandmarkType.rightElbow, PoseLandmarkType.rightWrist);

        // Torso
        connect(PoseLandmarkType.leftShoulder, PoseLandmarkType.leftHip);
        connect(PoseLandmarkType.rightShoulder, PoseLandmarkType.rightHip);
        connect(PoseLandmarkType.leftHip, PoseLandmarkType.rightHip);

        // Left leg
        connect(PoseLandmarkType.leftHip, PoseLandmarkType.leftKnee);
        connect(PoseLandmarkType.leftKnee, PoseLandmarkType.leftAnkle);

        // Right leg
        connect(PoseLandmarkType.rightHip, PoseLandmarkType.rightKnee);
        connect(PoseLandmarkType.rightKnee, PoseLandmarkType.rightAnkle);

        // ---- Dots on top ----
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

