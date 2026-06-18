import 'dart:ui';
import 'package:camera/camera.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

class CameraSetupChecker {
  String lastReason = '';

  CameraSetupChecker({
    this.marginRatio = 0.02, // Loosened slightly to prevent accidental edge cutoffs
    this.centerTolRatio = 0.25, // Adjusted tolerance for better indoor room placement
    this.minHeightRatio = 0.35,
    this.maxHeightRatio = 0.98,
    this.requiredGoodFrames = 1,
  });

  final double marginRatio;
  final double centerTolRatio;
  final double minHeightRatio;
  final double maxHeightRatio;
  final int requiredGoodFrames;

  int _streak = 0;

  /// Updates the setup checker. Pass [isJumpingJacks] as true for jumping jacks 
  /// to enforce strict full-body leg visibility, or false for squats.
  bool update({
    required List<Pose> poses,
    required Size canvasSize, // preview canvas size (portrait)
    required Size imageSize,
    required InputImageRotation rotation,
    required CameraLensDirection lensDirection,
    bool isJumpingJacks = false, 
  }) {
    final ok = _isOk(
      poses: poses,
      canvasSize: canvasSize,
      imageSize: imageSize,
      rotation: rotation,
      lensDirection: lensDirection,
      isJumpingJacks: isJumpingJacks,
    );

    _streak = ok ? _streak + 1 : 0;
    return _streak >= requiredGoodFrames;
  }

  bool _isOk({
    required List<Pose> poses,
    required Size canvasSize,
    required Size imageSize,
    required InputImageRotation rotation,
    required CameraLensDirection lensDirection,
    required bool isJumpingJacks,
  }) {
    if (poses.isEmpty) {
      lastReason = 'no pose';
      return false;
    }

    final pose = poses.first;
    final lm = pose.landmarks;

    // 🧠 Dynamic Landmark Requirement:
    // Squat: Only requires shoulders, hips, and knees. Feet can be off-screen.
    // Jumping Jacks: Must see all joints down to the ankles.
    final required = <PoseLandmarkType>[
      PoseLandmarkType.leftShoulder,
      PoseLandmarkType.rightShoulder,
      PoseLandmarkType.leftHip,
      PoseLandmarkType.rightHip,
      PoseLandmarkType.leftKnee,
      PoseLandmarkType.rightKnee,
      if (isJumpingJacks) ...[
        PoseLandmarkType.leftAnkle,
        PoseLandmarkType.rightAnkle,
      ],
    ];

    final points = <Offset>[];
    final missing = <PoseLandmarkType>[];

    for (final t in required) {
      final p = lm[t];
      // Check likelihood threshold (0.55 standard)
      if (p == null || p.likelihood < 0.55) missing.add(t);
    }

    if (missing.isNotEmpty) {
      lastReason = 'missing: ${missing.map((e) => e.name).join(", ")}';
      return false;
    }

    for (final t in required) {
      final p = lm[t]!;
      points.add(_map(p.x, p.y, canvasSize, imageSize, rotation, lensDirection));
    }

    double minX = points.first.dx, maxX = points.first.dx;
    double minY = points.first.dy, maxY = points.first.dy;
    for (final pt in points) {
      if (pt.dx < minX) minX = pt.dx;
      if (pt.dx > maxX) maxX = pt.dx;
      if (pt.dy < minY) minY = pt.dy;
      if (pt.dy > maxY) maxY = pt.dy;
    }

    final boxH = maxY - minY;
    final cx = (minX + maxX) / 2;
    final cy = (minY + maxY) / 2;

    final mx = canvasSize.width * marginRatio;
    final my = canvasSize.height * marginRatio;

    // Not cut off bounds validation
    if (minX < mx || maxX > canvasSize.width - mx) {
      lastReason = 'cut off (X)';
      return false;
    }
    
    // For squats, don't flag the bottom edge as "cut off" if the ankles are missing
    if (minY < my || (isJumpingJacks && maxY > canvasSize.height - my)) {
      lastReason = 'cut off (Y)';
      return false;
    }

    // Centered rules
    if ((cx - canvasSize.width / 2).abs() > canvasSize.width * centerTolRatio) {
      lastReason = 'not centered (X)';
      return false;
    }
    if ((cy - canvasSize.height / 2).abs() > canvasSize.height * centerTolRatio) {
      lastReason = 'not centered (Y)';
      return false;
    }

    // 🧠 Dynamic Distance Calibration:
    // Since squat tracking drops the ankles, the tracking box height ratio (boxH) 
    // will naturally be shorter. We compensate by lowering the min threshold for squats 
    // so you can stand closer (2 meters) instead of 4-5 meters back.
    final hRatio = boxH / canvasSize.height;
    final targetMinRatio = isJumpingJacks ? minHeightRatio : (minHeightRatio * 0.72);

    if (hRatio < targetMinRatio) {
      lastReason = 'too far';
      return false;
    }
    if (hRatio > maxHeightRatio) {
      lastReason = 'too close';
      return false;
    }

    lastReason = 'ok';
    return true;
  }

  Offset _map(
    double x,
    double y,
    Size canvas,
    Size img,
    InputImageRotation rot,
    CameraLensDirection lens,
  ) {
    double tx;
    switch (rot) {
      case InputImageRotation.rotation90deg:
        tx = x * canvas.width / img.height;
        break;
      case InputImageRotation.rotation270deg:
        tx = canvas.width - (x * canvas.width / img.height);
        break;
      default:
        tx = x * canvas.width / img.width;
    }

    if (lens == CameraLensDirection.front) {
      tx = canvas.width - tx;
    }

    double ty;
    switch (rot) {
      case InputImageRotation.rotation90deg:
      case InputImageRotation.rotation270deg:
        ty = y * canvas.height / img.width;
        break;
      default:
        ty = y * canvas.height / img.height;
    }

    return Offset(tx, ty);
  }
}