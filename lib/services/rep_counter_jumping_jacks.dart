import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

enum _Phase { unknown, closed, open }

class JumpingJacksRepCounter {
  JumpingJacksRepCounter({
    // 🛠️ CALIBRATION 1: Relax the jump constraints. Lower the displacement 
    // threshold so it works seamlessly in compact indoor settings.
    this.requireJump = false, 
    this.minJumpTorso = 0.06,
    this.confirmJumpFrames = 2,
    this.bodyBaseEmaAlpha = 0.12,
    
    this.minLikelihood = 0.55,
    this.emaAlpha = 0.45,

    // 🛠️ CALIBRATION 2: Lower the required extension width from 1.30 to 1.10.
    // This allows the counter to advance even if your legs are partially off-screen.
    this.openRatio = 1.10,
    this.closeRatio = 0.85,

    // 🛠️ CALIBRATION 3: Reduce symmetry thresholds to handle frame-border clipping.
    this.openSideRatio = 0.35,
    this.closeSideRatio = 0.28,

    this.graceMissingFrames = 6, // Widen grace window to counter high-velocity motion blur
    this.minRepInterval = const Duration(milliseconds: 320),
  });

  int reps = 0;
  String debug = '';

  final bool requireJump;
  final double minJumpTorso;
  final int confirmJumpFrames;
  final double bodyBaseEmaAlpha;
  final double minLikelihood;
  final double emaAlpha;
  final double openRatio;
  final double closeRatio;
  final double openSideRatio;
  final double closeSideRatio;
  final int graceMissingFrames;
  final Duration minRepInterval;

  _Phase _phase = _Phase.unknown;
  bool _seenOpen = false;
  DateTime _lastRepTime = DateTime.fromMillisecondsSinceEpoch(0);

  double? _emaAnkleRatio;
  double? _emaLeftSide;
  double? _emaRightSide;

  double? _baseBodyY;
  double? _emaBodyY;
  int _jumpHits = 0;
  bool _seenJump = false;
  int _missingStreak = 0;

  void reset() {
    reps = 0;
    debug = '';
    _phase = _Phase.unknown;
    _seenOpen = false;
    _lastRepTime = DateTime.fromMillisecondsSinceEpoch(0);
    _emaAnkleRatio = null;
    _emaLeftSide = null;
    _emaRightSide = null;
    _missingStreak = 0;
    _baseBodyY = 0;
    _emaBodyY = 0;
    _jumpHits = 0;
    _seenJump = false;
  }

  bool update({
    required Pose pose,
    required Size canvasSize,
    required Size imageSize,
    required InputImageRotation rotation,
    required CameraLensDirection lensDirection,
  }) {
    bool okLm(PoseLandmark? p) => p != null && p.likelihood >= minLikelihood;

    const required = <PoseLandmarkType>[
      PoseLandmarkType.leftAnkle,
      PoseLandmarkType.rightAnkle,
      PoseLandmarkType.leftShoulder,
      PoseLandmarkType.rightShoulder,
      PoseLandmarkType.leftHip,
      PoseLandmarkType.rightHip,
    ];

    for (final t in required) {
      final lm = pose.landmarks[t];
      if (!okLm(lm)) return _handleMissing('missing limbs');
    }

    final lWr = pose.landmarks[PoseLandmarkType.leftWrist];
    final rWr = pose.landmarks[PoseLandmarkType.rightWrist];
    final lEl = pose.landmarks[PoseLandmarkType.leftElbow];
    final rEl = pose.landmarks[PoseLandmarkType.rightElbow];

    // 🛠️ CALIBRATION 4: Smart Fallback. If wrists go off-screen at the top, 
    // seamlessly use the elbows to calculate upper arm elevation!
    final lArm = okLm(lWr) ? lWr : okLm(lEl) ? lEl : null;
    final rArm = okLm(rWr) ? rWr : okLm(rEl) ? rEl : null;

    if (lArm == null || rArm == null) {
      return _handleMissing('arms missing');
    }

    _missingStreak = 0;

    Offset map(PoseLandmark p) => _map(p.x, p.y, canvasSize, imageSize, rotation, lensDirection);

    final lAnk = map(pose.landmarks[PoseLandmarkType.leftAnkle]!);
    final rAnk = map(pose.landmarks[PoseLandmarkType.rightAnkle]!);
    final lSh = map(pose.landmarks[PoseLandmarkType.leftShoulder]!);
    final rSh = map(pose.landmarks[PoseLandmarkType.rightShoulder]!);
    final lHip = map(pose.landmarks[PoseLandmarkType.leftHip]!);
    final rHip = map(pose.landmarks[PoseLandmarkType.rightHip]!);
    final lArmPt = map(lArm);
    final rArmPt = map(rArm);

    final shoulderWidth = (lSh - rSh).distance.clamp(1.0, 1e9);
    final ankleDist = (lAnk - rAnk).distance;
    final ankleRatio = ankleDist / shoulderWidth;

    final centerX = (lHip.dx + rHip.dx) / 2.0;
    final leftSide = (centerX - lAnk.dx).abs() / shoulderWidth;
    final rightSide = (rAnk.dx - centerX).abs() / shoulderWidth;

    final avgShoulderY = (lSh.dy + rSh.dy) / 2.0;
    final avgHipY = (lHip.dy + rHip.dy) / 2.0;
    final torsoH = (avgHipY - avgShoulderY).abs().clamp(1.0, 1e9);

    final rawBodyY = (avgShoulderY + avgHipY) / 2.0;
    _emaBodyY = _ema(_emaBodyY, rawBodyY, emaAlpha);
    final bodyY = _emaBodyY!;

    final bool jumpedNow = (_baseBodyY != null) && ((_baseBodyY! - bodyY) >= (minJumpTorso * torsoH));
    if (jumpedNow) {
      _jumpHits++;
    } else {
      _jumpHits = 0;
    }

    if (_jumpHits >= confirmJumpFrames) {
      _seenJump = true;
    }

    double headY = avgShoulderY - 0.45 * torsoH;
    final nose = pose.landmarks[PoseLandmarkType.nose];
    if (okLm(nose)) headY = map(nose!).dy;

    // Set clear clearance boundaries right around the upper head plane
    final leftThresh  = headY - 0.12 * torsoH;
    final rightThresh = headY - 0.12 * torsoH;

    final armsUp = (lArmPt.dy < leftThresh) && (rArmPt.dy < rightThresh);
    final avgArmY = (lArmPt.dy + rArmPt.dy) / 2.0;
    final armsDown = avgArmY > (avgShoulderY + 0.05 * torsoH);

    _emaAnkleRatio = _ema(_emaAnkleRatio, ankleRatio, emaAlpha);
    _emaLeftSide = _ema(_emaLeftSide, leftSide, emaAlpha);
    _emaRightSide = _ema(_emaRightSide, rightSide, emaAlpha);

    final r = _emaAnkleRatio!;
    final ls = _emaLeftSide!;
    final rs = _emaRightSide!;

    final legsOpenSym = (ls >= openSideRatio && rs >= openSideRatio);
    final legsCloseSym = (ls <= closeSideRatio && rs <= closeSideRatio);

    final legsOpen = (r >= openRatio) && legsOpenSym;
    final legsClosed = (r <= closeRatio) && legsCloseSym;

    final isOpen = legsOpen && armsUp && (!requireJump || _seenJump);
    final isClosed = legsClosed && armsDown;

    // 🧠 5. STATE OBSERVATION EMISSION & TTS COMMAND TRIGGER PIPELINE
    // We explicitly append 'ERR:' to the debug string so the exercise screen 
    // stream knows exactly when to play vocal alerts.
    if (legsOpen && !armsUp) {
      debug = 'ERR: Raise hands completely overhead';
    } else if (legsClosed && !armsDown) {
      debug = 'ERR: Drop arms down to your sides';
    } else {
      debug = 'ok';
    }

    if (isOpen) {
      _phase = _Phase.open;
      _seenOpen = true;
      return false;
    }

    if (isClosed) {
      if (!jumpedNow) {
        _baseBodyY = _ema(_baseBodyY, bodyY, bodyBaseEmaAlpha);
      }
      
      if (_phase == _Phase.open && _seenOpen){
        if (requireJump && !_seenJump){
          _phase = _Phase.closed;
          return false;
        }

        final now = DateTime.now();
        if (now.difference(_lastRepTime) >= minRepInterval) {
          reps += 1;
          _lastRepTime = now;
          _seenOpen = false;
          _phase = _Phase.closed;
          return true;
        }
      }
      if (_phase != _Phase.open) {
        _seenJump = false;
        _jumpHits = 0;
      }

      _phase = _Phase.closed;
      return false;
    }

    return false;
  }

  bool _handleMissing(String why) {
    _missingStreak++;
    if (_missingStreak > graceMissingFrames) {
      _phase = _Phase.unknown;
      _seenOpen = false;
      _emaAnkleRatio = null;
      _emaLeftSide = null;
      _emaRightSide = null;
      _seenJump = false;
      _emaBodyY = null;
      _baseBodyY = null;
    }
    return false;
  }

  double _ema(double? prev, double next, double a) {
    if (prev == null) return next;
    return prev + a * (next - prev);
  }

  Offset _map(double x, double y, Size canvas, Size img, InputImageRotation rot, CameraLensDirection lens) {
    double tx;
    switch (rot) {
      case InputImageRotation.rotation90deg: tx = x * canvas.width / img.height; break;
      case InputImageRotation.rotation270deg: tx = canvas.width - (x * canvas.width / img.height); break;
      default: tx = x * canvas.width / img.width;
    }
    if (lens == CameraLensDirection.front) tx = canvas.width - tx;
    double ty;
    switch (rot) {
      case InputImageRotation.rotation90deg:
      case InputImageRotation.rotation270deg: ty = y * canvas.height / img.width; break;
      default: ty = y * canvas.height / img.height;
    }
    return Offset(tx, ty);
  }
}