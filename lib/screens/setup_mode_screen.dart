import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';

import '../app_state.dart';

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

  @override
  void initState() {
    super.initState();
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
      );

      _controller = ctrl;
      _initFuture = ctrl.initialize();
      await _initFuture;

      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) setState(() => _error = 'Camera error: $e');
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
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
          ],
        ),
      ),
    );
  }
}
