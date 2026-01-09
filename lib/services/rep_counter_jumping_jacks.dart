import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

enum _Phase { unknown, closed, open }

class JumpingJacksRepCounter {
  JumpingJacksRepCounter({
    this.minLikelihood = 0.55,

    // Smoothing (helps fast reps + jitter)
    this.emaAlpha = 0.45, // 0.25–0.45 good range

    // Hysteresis thresholds (prevents state flip-flop)
    this.openRatio = 1.10,   // ankleDist/shoulderWidth -> OPEN
    this.closeRatio = 0.78,  // ankleDist/shoulderWidth -> CLOSED

    // Symmetry gate to prevent "one-leg" fake reps
    this.openSideRatio = 0.35,  // each ankle must be this far from body center (normalized)
    this.closeSideRatio = 0.24, // each ankle must be near center (normalized)

    // Arms: allow elbows when wrists are cropped
    this.armsUpMarginTorso = 0.10,   // how far above shoulders (fraction of torso height)
    this.armsDownMarginTorso = 0.08, // how close to hips for "down"

    // Robustness
    this.graceMissingFrames = 4, // allow this many missing frames before resetting
    this.minRepInterval = const Duration(milliseconds: 320), // min time between counted reps
  });

  // Output
  int reps = 0;
  String debug = '';

  // Tunables
  final double minLikelihood;
  final double emaAlpha;

  final double openRatio;
  final double closeRatio;

  final double openSideRatio;
  final double closeSideRatio;

  final double armsUpMarginTorso;
  final double armsDownMarginTorso;

  final int graceMissingFrames;
  final Duration minRepInterval;

  // Internal
  _Phase _phase = _Phase.unknown;
  bool _seenOpen = false;
  DateTime _lastRepTime = DateTime.fromMillisecondsSinceEpoch(0);

  double? _emaAnkleRatio;
  double? _emaLeftSide;
  double? _emaRightSide;

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
  }

  bool update({
    required Pose pose,
    required Size canvasSize,
    required Size imageSize,
    required InputImageRotation rotation,
    required CameraLensDirection lensDirection,
  }) {
    // Required lower-body + torso reference
    final required = <PoseLandmarkType>[
      PoseLandmarkType.leftAnkle,
      PoseLandmarkType.rightAnkle,
      PoseLandmarkType.leftShoulder,
      PoseLandmarkType.rightShoulder,
      PoseLandmarkType.leftHip,
      PoseLandmarkType.rightHip,
    ];

    for (final t in required) {
      final lm = pose.landmarks[t];
      if (lm == null || lm.likelihood < minLikelihood) {
        return _handleMissing('missing/low: $t');
      }
    }

    // Arms (prefer wrists, fallback to elbows if wrists cropped)
    final lWr = pose.landmarks[PoseLandmarkType.leftWrist];
    final rWr = pose.landmarks[PoseLandmarkType.rightWrist];
    final lEl = pose.landmarks[PoseLandmarkType.leftElbow];
    final rEl = pose.landmarks[PoseLandmarkType.rightElbow];

    // We'll accept wrists OR elbows if confident
    PoseLandmark? lArm = (lWr != null && lWr.likelihood >= minLikelihood) ? lWr
        : (lEl != null && lEl.likelihood >= minLikelihood) ? lEl
        : null;

    PoseLandmark? rArm = (rWr != null && rWr.likelihood >= minLikelihood) ? rWr
        : (rEl != null && rEl.likelihood >= minLikelihood) ? rEl
        : null;

    if (lArm == null || rArm == null) {
      // arms missing is common when cropped; allow a few frames grace
      return _handleMissing('arms missing');
    }

    // Reset missing streak on good frame
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

    final centerX = ((lHip.dx + rHip.dx) / 2.0);
    final leftSide = (centerX - lAnk.dx).abs() / shoulderWidth;  // how far left ankle from center
    final rightSide = (rAnk.dx - centerX).abs() / shoulderWidth; // how far right ankle from center

    final ankleRatio = ankleDist / shoulderWidth;

    // Torso height reference for arms up/down
    final avgShoulderY = (lSh.dy + rSh.dy) / 2.0;
    final avgHipY = (lHip.dy + rHip.dy) / 2.0;
    final torsoH = (avgHipY - avgShoulderY).abs().clamp(1.0, 1e9);

    final avgArmY = (lArmPt.dy + rArmPt.dy) / 2.0;

    // y grows downward: "up" means smaller y
    final armsUp = avgArmY < (avgShoulderY - armsUpMarginTorso * torsoH);
    // arms "down" for jumping jacks = below shoulders (not necessarily near hips)
    final armsDown = avgArmY > (avgShoulderY + 0.05 * torsoH);

    // EMA smoothing (helps fast motion + jitter)
    _emaAnkleRatio = _ema(_emaAnkleRatio, ankleRatio, emaAlpha);
    _emaLeftSide = _ema(_emaLeftSide, leftSide, emaAlpha);
    _emaRightSide = _ema(_emaRightSide, rightSide, emaAlpha);

    final r = _emaAnkleRatio!;
    final ls = _emaLeftSide!;
    final rs = _emaRightSide!;

    // Symmetry gate to avoid "one-leg" fake
    final legsOpenSym = (ls >= openSideRatio && rs >= openSideRatio);
    final legsCloseSym = (ls <= closeSideRatio && rs <= closeSideRatio);

    // OPEN/CLOSED with hysteresis
    final isOpen = (r >= openRatio) && legsOpenSym && armsUp;
    final isClosed = (r <= closeRatio) && legsCloseSym && armsDown;

    debug =
        'phase=$_phase reps=$reps r=${r.toStringAsFixed(2)} '
        'ls=${ls.toStringAsFixed(2)} rs=${rs.toStringAsFixed(2)} '
        'open=${isOpen ? 1 : 0} closed=${isClosed ? 1 : 0}';

    if (isOpen) {
      _phase = _Phase.open;
      _seenOpen = true;
      return false;
    }

    if (isClosed) {
      // Count only when returning CLOSED after being OPEN
      if (_phase == _Phase.open && _seenOpen) {
        final now = DateTime.now();
        if (now.difference(_lastRepTime) >= minRepInterval) {
          reps += 1;
          _lastRepTime = now;
          _seenOpen = false;
          _phase = _Phase.closed;
          debug += ' ✅ REP';
          return true;
        }
      }
      _phase = _Phase.closed;
      return false;
    }

    // Neutral zone: keep phase, do nothing
    return false;
  }

  bool _handleMissing(String why) {
    _missingStreak++;
    debug = '$why (grace $_missingStreak/$graceMissingFrames)';
    if (_missingStreak > graceMissingFrames) {
      // If missing too long, reset phase to avoid random counts later
      _phase = _Phase.unknown;
      _seenOpen = false;
      _emaAnkleRatio = null;
      _emaLeftSide = null;
      _emaRightSide = null;
    }
    return false;
  }

  double _ema(double? prev, double next, double a) {
    if (prev == null) return next;
    return prev + a * (next - prev);
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
