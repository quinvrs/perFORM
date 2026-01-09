import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

enum _JJPhase { unknown, closed, open }

/// Jumping Jacks repetition counter.
///
/// Rep definition:
/// CLOSED (feet together + arms down) -> OPEN (feet apart + arms up) -> CLOSED = +1 rep
///
/// Robustness:
/// - Requires landmark likelihood >= [minLikelihood]
/// - Uses debounce via [confirmFrames]
/// - Uses cooldown via [minRepInterval]
/// - Uses normalized thresholds based on shoulder width / torso height
class JumpingJacksRepCounter {
  JumpingJacksRepCounter({
    this.minLikelihood = 0.55,
    this.confirmFrames = 3,
    this.minRepInterval = const Duration(milliseconds: 300),

    /// Feet distance normalized by shoulder width.
    this.feetCloseRatio = 0.60,
    this.feetOpenRatio = 1.05,

    /// Arms up/down thresholds use torso height (shoulder->hip distance).
    this.armsUpMarginTorsoRatio = 0.12,
    this.armsDownMarginTorsoRatio = 0.10,
  });

  int reps = 0;
  String debug = '';

  final double minLikelihood;
  final int confirmFrames;
  final Duration minRepInterval;

  final double feetCloseRatio;
  final double feetOpenRatio;

  final double armsUpMarginTorsoRatio;
  final double armsDownMarginTorsoRatio;

  _JJPhase _phase = _JJPhase.unknown;
  int _openHits = 0;
  int _closedHits = 0;
  DateTime _lastRepTime = DateTime.fromMillisecondsSinceEpoch(0);

  void reset() {
    reps = 0;
    debug = '';
    _phase = _JJPhase.unknown;
    _openHits = 0;
    _closedHits = 0;
    _lastRepTime = DateTime.fromMillisecondsSinceEpoch(0);
  }

  bool update({
    required Pose pose,
    required Size canvasSize,
    required Size imageSize,
    required InputImageRotation rotation,
    required CameraLensDirection lensDirection,
  }) {
    // Required landmarks
    final required = <PoseLandmarkType>[
      PoseLandmarkType.leftAnkle,
      PoseLandmarkType.rightAnkle,
      PoseLandmarkType.leftWrist,
      PoseLandmarkType.rightWrist,
      PoseLandmarkType.leftShoulder,
      PoseLandmarkType.rightShoulder,
      PoseLandmarkType.leftHip,
      PoseLandmarkType.rightHip,
    ];

    for (final t in required) {
      final lm = pose.landmarks[t];
      if (lm == null) {
        debug = 'missing: $t';
        _resetHits();
        return false;
      }
      if (lm.likelihood < minLikelihood) {
        debug = 'low conf: $t (${lm.likelihood.toStringAsFixed(2)})';
        _resetHits();
        return false;
      }
    }

    Offset pt(PoseLandmark lm) => _map(
          lm.x,
          lm.y,
          canvasSize,
          imageSize,
          rotation,
          lensDirection,
        );

    final lAnk = pt(pose.landmarks[PoseLandmarkType.leftAnkle]!);
    final rAnk = pt(pose.landmarks[PoseLandmarkType.rightAnkle]!);
    final lWr = pt(pose.landmarks[PoseLandmarkType.leftWrist]!);
    final rWr = pt(pose.landmarks[PoseLandmarkType.rightWrist]!);
    final lSh = pt(pose.landmarks[PoseLandmarkType.leftShoulder]!);
    final rSh = pt(pose.landmarks[PoseLandmarkType.rightShoulder]!);
    final lHip = pt(pose.landmarks[PoseLandmarkType.leftHip]!);
    final rHip = pt(pose.landmarks[PoseLandmarkType.rightHip]!);

    final shoulderWidth = (lSh - rSh).distance.clamp(1.0, 1e9);
    final ankleDist = (lAnk - rAnk).distance;
    final ankleRatio = ankleDist / shoulderWidth;

    final avgShoulderY = (lSh.dy + rSh.dy) / 2.0;
    final avgHipY = (lHip.dy + rHip.dy) / 2.0;
    final torsoH = (avgHipY - avgShoulderY).abs().clamp(1.0, 1e9);
    final avgWristY = (lWr.dy + rWr.dy) / 2.0;

    // Note: y increases downward in canvas coordinates
    final armsUp = avgWristY < (avgShoulderY - armsUpMarginTorsoRatio * torsoH);
    final armsDown = avgWristY > (avgHipY - armsDownMarginTorsoRatio * torsoH);

    final feetClose = ankleRatio <= feetCloseRatio;
    final feetOpen = ankleRatio >= feetOpenRatio;

    final isOpen = feetOpen && armsUp;
    final isClosed = feetClose && armsDown;

    debug =
        'jj phase=$_phase reps=$reps ratio=${ankleRatio.toStringAsFixed(2)} open=${isOpen ? 1 : 0} closed=${isClosed ? 1 : 0}';

    if (isOpen) {
      _openHits++;
      _closedHits = 0;
      if (_openHits >= confirmFrames) _phase = _JJPhase.open;
      return false;
    }

    if (isClosed) {
      _closedHits++;
      _openHits = 0;

      if (_closedHits >= confirmFrames) {
        if (_phase == _JJPhase.open) {
          final now = DateTime.now();
          if (now.difference(_lastRepTime) >= minRepInterval) {
            reps += 1;
            _lastRepTime = now;
            _phase = _JJPhase.closed;
            debug += ' ✅';
            return true;
          }
        }
        _phase = _JJPhase.closed;
      }
      return false;
    }

    _resetHits();
    return false;
  }

  void _resetHits() {
    _openHits = 0;
    _closedHits = 0;
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
