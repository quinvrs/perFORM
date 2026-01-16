import 'dart:math' as math;
import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

/// Simple accumulator for "form score" as a ratio of good frames / evaluated frames.
/// - Returns null for frames we choose NOT to score (missing landmarks / transition frames).
class FormScoreTracker {
  int totalFrames = 0;
  int goodFrames = 0;

  // Optional: useful for debugging / future TTS cues
  String lastReason = '';

  // Jumping Jacks smoothing (matches JJ rep counter idea)
  double? _emaAnkleRatio;
  double? _emaLeftSide;
  double? _emaRightSide;

  // --- NEW: Jumping Jacks checkpoint scoring (stable OPEN/CLOSED) ---
  int _jjOpenStable = 0;
  int _jjCloseStable = 0;
  bool _jjOpenScored = false;
  bool _jjCloseScored = false;

  // How many consecutive frames to consider a state "stable"
  final int _jjStableNeed = 2; // try 2 or 3

  // --- NEW: Squat scoring state (tracks one "rep attempt") ---
  bool _sqInRep = false;
  double _sqMinAngle = 999;

  void reset() {
    totalFrames = 0;
    goodFrames = 0;
    lastReason = '';
    _emaAnkleRatio = null;
    _emaLeftSide = null;
    _emaRightSide = null;

    // reset JJ checkpoint tracking
    _jjOpenStable = 0;
    _jjCloseStable = 0;
    _jjOpenScored = false;
    _jjCloseScored = false;

    // reset squat tracking
    _sqInRep = false;
    _sqMinAngle = 999;
  }

  double get percent {
    if (totalFrames <= 0) return 0.0;
    return (goodFrames / totalFrames) * 100.0;
  }

  /// Call this once per frame during ACTIVE phase.
  /// - null -> frame ignored
  /// - true/false -> frame counted as good/bad
  bool? updateJumpingJacksFrame({
    required Pose pose,
    required Size canvasSize,
    required Size imageSize,
    required InputImageRotation rotation,
    required CameraLensDirection lensDirection,

    // Tunings (keep in sync with your JJ rep counter values)
    double minLikelihood = 0.55,
    double emaAlpha = 0.45,
    double openRatio = 1.10,
    double closeRatio = 0.78,
    double openSideRatio = 0.35,
    double closeSideRatio = 0.24,
  }) {
    bool okLm(PoseLandmark? p) => p != null && p.likelihood >= minLikelihood;

    // Required: ankles + shoulders + hips
    const required = <PoseLandmarkType>[
      PoseLandmarkType.leftAnkle,
      PoseLandmarkType.rightAnkle,
      PoseLandmarkType.leftShoulder,
      PoseLandmarkType.rightShoulder,
      PoseLandmarkType.leftHip,
      PoseLandmarkType.rightHip,
    ];
    for (final t in required) {
      if (!okLm(pose.landmarks[t])) {
        lastReason = 'JJ: missing/low $t';
        return null;
      }
    }

    // Arms: prefer wrists; fallback to elbows if wrists are cropped
    final lWr = pose.landmarks[PoseLandmarkType.leftWrist];
    final rWr = pose.landmarks[PoseLandmarkType.rightWrist];
    final lEl = pose.landmarks[PoseLandmarkType.leftElbow];
    final rEl = pose.landmarks[PoseLandmarkType.rightElbow];

    final lArm = okLm(lWr) ? lWr : (okLm(lEl) ? lEl : null);
    final rArm = okLm(rWr) ? rWr : (okLm(rEl) ? rEl : null);

    if (lArm == null || rArm == null) {
      lastReason = 'JJ: arms missing';
      return null;
    }

    Offset map(PoseLandmark p) => _map(
          p.x,
          p.y,
          canvasSize,
          imageSize,
          rotation,
          lensDirection,
        );

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

    // Symmetry: each ankle should move away/towards body center together
    final centerX = (lHip.dx + rHip.dx) / 2.0;
    final leftSide = (centerX - lAnk.dx).abs() / shoulderWidth;
    final rightSide = (rAnk.dx - centerX).abs() / shoulderWidth;

    // Torso reference
    final avgShoulderY = (lSh.dy + rSh.dy) / 2.0;
    final avgHipY = (lHip.dy + rHip.dy) / 2.0;
    final torsoH = (avgHipY - avgShoulderY).abs().clamp(1.0, 1e9);

    // Head reference for "arms up"
    double headY = avgShoulderY - 0.45 * torsoH; // fallback
    final nose = pose.landmarks[PoseLandmarkType.nose];
    final lEye = pose.landmarks[PoseLandmarkType.leftEye];
    final rEye = pose.landmarks[PoseLandmarkType.rightEye];
    if (okLm(nose)) {
      headY = map(nose!).dy;
    } else if (okLm(lEye) && okLm(rEye)) {
      headY = (map(lEye!).dy + map(rEye!).dy) / 2.0;
    }

    // Overhead check:
    // - wrists: slightly above head
    // - elbows (fallback): require higher so "in front of face" won't pass
    final usingLeftWrist = okLm(lWr);
    final usingRightWrist = okLm(rWr);

    final leftThresh =
        headY - (usingLeftWrist ? 0.06 * torsoH : 0.12 * torsoH);
    final rightThresh =
        headY - (usingRightWrist ? 0.06 * torsoH : 0.12 * torsoH);

    final armsUp = (lArmPt.dy < leftThresh) && (rArmPt.dy < rightThresh);

    // Arms down: below shoulders
    final avgArmY = (lArmPt.dy + rArmPt.dy) / 2.0;
    final armsDown = avgArmY > (avgShoulderY + 0.05 * torsoH);

    // EMA smoothing
    _emaAnkleRatio = _ema(_emaAnkleRatio, ankleRatio, emaAlpha);
    _emaLeftSide = _ema(_emaLeftSide, leftSide, emaAlpha);
    _emaRightSide = _ema(_emaRightSide, rightSide, emaAlpha);

    final r = _emaAnkleRatio!;
    final ls = _emaLeftSide!;
    final rs = _emaRightSide!;

    final legsOpenSym = (ls >= openSideRatio && rs >= openSideRatio);
    final legsCloseSym = (ls <= closeSideRatio && rs <= closeSideRatio);

    // "Intent" checkpoints (stable states only)
    final legsOpenIntent = (r >= openRatio) && legsOpenSym;
    final legsCloseIntent = (r <= closeRatio) && legsCloseSym;

    final armsUpIntent = armsUp;
    final armsDownIntent = armsDown;

    // --- NEW: Score only stable OPEN/CLOSED checkpoints ---
    if (legsOpenIntent) {
      _jjOpenStable++;
      _jjCloseStable = 0;

      if (_jjOpenStable >= _jjStableNeed && !_jjOpenScored) {
        final ok = armsUpIntent;
        lastReason = ok ? 'JJ: OPEN ok' : 'JJ: OPEN bad (arms not overhead)';
        _accumulate(ok);
        _jjOpenScored = true;
        _jjCloseScored = false;
        return ok;
      }

      lastReason = 'JJ: open stabilizing';
      return null;
    }

    if (legsCloseIntent) {
      _jjCloseStable++;
      _jjOpenStable = 0;

      if (_jjCloseStable >= _jjStableNeed && !_jjCloseScored) {
        final ok = armsDownIntent;
        lastReason = ok ? 'JJ: CLOSED ok' : 'JJ: CLOSED bad (arms not down)';
        _accumulate(ok);
        _jjCloseScored = true;
        _jjOpenScored = false;
        return ok;
      }

      lastReason = 'JJ: close stabilizing';
      return null;
    }

    // Transition/noise: ignore
    _jjOpenStable = 0;
    _jjCloseStable = 0;
    lastReason = 'JJ: transition';
    return null;
  }

  /// Squat form score (rep-attempt based, graded):
  /// - Track the minimum knee angle during a rep attempt
  /// - Score ONCE when returning to standing
  /// - Use points so shallow squats don't get high scores
  bool? updateSquatFrame({
    required Pose pose,
    double minLikelihood = 0.55,
    double downAngleDeg = 110,
    double upAngleDeg = 168,
    double depthToleranceDeg = 9,
  }) {
    final left = _Side(
      hip: PoseLandmarkType.leftHip,
      knee: PoseLandmarkType.leftKnee,
      ankle: PoseLandmarkType.leftAnkle,
    );
    final right = _Side(
      hip: PoseLandmarkType.rightHip,
      knee: PoseLandmarkType.rightKnee,
      ankle: PoseLandmarkType.rightAnkle,
    );

    final lOk = _hasAll(pose, left, minLikelihood);
    final rOk = _hasAll(pose, right, minLikelihood);

    if (!lOk && !rOk) {
      lastReason = 'SQ: missing hip/knee/ankle';
      return null;
    }

    final side = rOk ? right : left;
    final hip = pose.landmarks[side.hip]!;
    final knee = pose.landmarks[side.knee]!;
    final ankle = pose.landmarks[side.ankle]!;

    final ang = _angleDeg(hip, knee, ankle);

    // Define when a "rep attempt" starts/ends
    final startAttempt = ang < 160; // leaving full standing
    final endAttempt = ang > upAngleDeg; // back to standing (hysteresis)

    // Start tracking rep
    if (!_sqInRep && startAttempt) {
      _sqInRep = true;
      _sqMinAngle = ang;
      lastReason = 'SQ: start tracking';
      return null;
    }

    if (_sqInRep) {
      if (ang < _sqMinAngle) _sqMinAngle = ang;

      if (endAttempt) {
        _sqInRep = false;

        // --- NEW: graded scoring per rep (points) ---
        final minA = _sqMinAngle;

        int pts;
        if (minA <= (downAngleDeg + depthToleranceDeg)) {
          pts = 10; // great depth
        } else if (minA <= (downAngleDeg + depthToleranceDeg + 8)) {
          pts = 7; // decent
        } else if (minA <= (downAngleDeg + depthToleranceDeg + 16)) {
          pts = 4; // shallow
        } else {
          pts = 1; // very shallow
        }

        _accumulatePoints(pts, 10);
        lastReason = 'SQ: rep min=${minA.toStringAsFixed(0)} pts=$pts/10';

        // Return true/false only for debug convenience
        return pts >= 7;
      }

      lastReason = 'SQ: tracking (min=${_sqMinAngle.toStringAsFixed(0)})';
      return null;
    }

    lastReason = 'SQ: idle';
    return null;
  }

  void _accumulate(bool ok) {
    totalFrames += 1;
    if (ok) goodFrames += 1;
  }

  void _accumulatePoints(int good, int total) {
    totalFrames += total;
    goodFrames += good;
  }

  double _ema(double? prev, double next, double a) {
    if (prev == null) return next;
    return prev + a * (next - prev);
  }

  static double _angleDeg(PoseLandmark a, PoseLandmark b, PoseLandmark c) {
    final abx = a.x - b.x;
    final aby = a.y - b.y;
    final cbx = c.x - b.x;
    final cby = c.y - b.y;

    final dot = abx * cbx + aby * cby;
    final mag1 = math.sqrt(abx * abx + aby * aby);
    final mag2 = math.sqrt(cbx * cbx + cby * cby);

    if (mag1 == 0 || mag2 == 0) return 180;
    final cos = (dot / (mag1 * mag2)).clamp(-1.0, 1.0);
    return math.acos(cos) * 180 / math.pi;
  }

  static bool _hasAll(Pose pose, _Side s, double minL) {
    final hip = pose.landmarks[s.hip];
    final knee = pose.landmarks[s.knee];
    final ankle = pose.landmarks[s.ankle];
    return hip != null &&
        knee != null &&
        ankle != null &&
        hip.likelihood >= minL &&
        knee.likelihood >= minL &&
        ankle.likelihood >= minL;
  }

  static Offset _map(
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

class _Side {
  const _Side({required this.hip, required this.knee, required this.ankle});
  final PoseLandmarkType hip;
  final PoseLandmarkType knee;
  final PoseLandmarkType ankle;
}
