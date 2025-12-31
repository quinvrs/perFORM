import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';

import '../app_state.dart';

//import for pose detection
import 'dart:io';
import 'dart:typed_data';
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
        ResolutionPreset.high,
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
          _lastImageSize = Size(image.width.toDouble(), image.height.toDouble());

          final inputImage = _cameraImageToInputImage(image, _selectedCamera!);
          if (inputImage == null) {
            _isDetecting = false;
            return;
          }
          final poses = await _poseDetector!.processImage(inputImage);

          if (mounted) setState(() => _poses = poses);
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

    int rot;
    if (camera.lensDirection == CameraLensDirection.front) {
      rot = (sensorOrientation + rotationCompensation) % 360;
    } else {
      rot = (sensorOrientation - rotationCompensation + 360) % 360;
    }
    rotation = InputImageRotationValue.fromRawValue(rot);
  }

  if (rotation == null) return null;

  // format
  final format = InputImageFormatValue.fromRawValue(image.format.raw);
  if (format == null) return null;

  // only supported formats for this pipeline:
  // Android: nv21 (1 plane)
  // iOS: bgra8888 (1 plane)
  if (Platform.isAndroid && format != InputImageFormat.nv21) return null;
  if (Platform.isIOS && format != InputImageFormat.bgra8888) return null;

  if (image.planes.length != 1) return null;

  final plane = image.planes.first;

  return InputImage.fromBytes(
    bytes: plane.bytes,
    metadata: InputImageMetadata(
      size: Size(image.width.toDouble(), image.height.toDouble()),
      rotation: rotation,
      format: format,
      bytesPerRow: plane.bytesPerRow,
    ),
  );
}

  @override
  Widget build(BuildContext context) {
    final state = AppStateScope.of(context);

    // ✅ full-screen scale (design width = 375)
    final size = MediaQuery.sizeOf(context);
    final s = size.width / 375.0;

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
                      : FittedBox(
                          fit: BoxFit.cover,
                          child: SizedBox(
                            width: _controller!.value.previewSize!.height,
                            height: _controller!.value.previewSize!.width,
                            child: CameraPreview(_controller!),
                          ),
                        ),
            ),

            // top bar
            Positioned(
              left: 16 * s,
              top: 12 * s,
              child: SafeArea(
                child: InkWell(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                ),
              ),
            ),
            Positioned(
              left: 56 * s,
              top: 14 * s,
              right: 16 * s,
              child: SafeArea(
                child: Text(
                  'Setup Mode',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.92),
                    fontSize: 14 * s,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),

            // instruction card
            Positioned(
              left: 18 * s,
              right: 18 * s,
              top: 86 * s,
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
            
            //just to check if the pose detection is working
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
                  'poses: ${_poses.length}',
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

