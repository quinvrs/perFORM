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

  // --- Jumping Jacks checkpoint scoring (stable OPEN/CLOSED) ---
  int _jjOpenStable = 0;
  int _jjCloseStable = 0;
  bool _jjOpenScored = false;
  bool _jjCloseScored = false;

  // How many consecutive frames to consider a state "stable"
  final int _jjStableNeed = 2; // try 2 or 3

  // --- Squat scoring state (rep-attempt based) ---
  bool _sqInRep = false;

  // Deepest knee angle reached during rep (smaller angle = deeper)
  double _sqMinKneeAngle = 999;

  // Smallest hip-to-knee vertical gap observed during rep, normalized by torso height.
  // Deep squat => hip gets closer to knee => GAP gets smaller.
  double _sqMinHipKneeGapTorso = 999;

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
    _sqMinKneeAngle = 999;
    _sqMinHipKneeGapTorso = 999;
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

    // STRICT overhead check:
    // - wrists: must be WELL above head
    // - elbows fallback: require even higher (prevents forehead/face cheats)
    final usingLeftWrist = okLm(lWr);
    final usingRightWrist = okLm(rWr);

    final leftThresh = headY - (usingLeftWrist ? 0.14 * torsoH : 0.20 * torsoH);
    final rightThresh = headY - (usingRightWrist ? 0.14 * torsoH : 0.20 * torsoH);

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

    // Score only stable OPEN/CLOSED checkpoints
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

  /// ✅ NEW Squat scoring (redo):
  /// - Track one "rep attempt" (leave standing -> return to standing)
  /// - During the rep:
  ///   1) record deepest knee angle (min angle)
  ///   2) record minimum hip-to-knee vertical gap (hips closer to knee = deeper squat)
  /// - Score ONCE at the end of the rep attempt.
  ///
  /// Why this helps:
  /// - Knee angle alone can be noisy / overly optimistic.
  /// - Hip-to-knee gap is a strong “depth” signal that shallow squats fail.
  bool? updateSquatFrame({
    required Pose pose,
    double minLikelihood = 0.55,
    double downAngleDeg = 110,
    double upAngleDeg = 160,
  }) {
    bool okLm(PoseLandmark? p) => p != null && p.likelihood >= minLikelihood;

    // Need shoulders+hips for torso height, and a side hip/knee/ankle for angle.
    final lSh = pose.landmarks[PoseLandmarkType.leftShoulder];
    final rSh = pose.landmarks[PoseLandmarkType.rightShoulder];
    final lHip = pose.landmarks[PoseLandmarkType.leftHip];
    final rHip = pose.landmarks[PoseLandmarkType.rightHip];

    if (!okLm(lSh) || !okLm(rSh) || !okLm(lHip) || !okLm(rHip)) {
      lastReason = 'SQ: missing torso landmarks';
      return null;
    }

    // Choose a reliable side for knee angle (prefer right if valid)
    final rSideOk = okLm(pose.landmarks[PoseLandmarkType.rightHip]) &&
        okLm(pose.landmarks[PoseLandmarkType.rightKnee]) &&
        okLm(pose.landmarks[PoseLandmarkType.rightAnkle]);

    final lSideOk = okLm(pose.landmarks[PoseLandmarkType.leftHip]) &&
        okLm(pose.landmarks[PoseLandmarkType.leftKnee]) &&
        okLm(pose.landmarks[PoseLandmarkType.leftAnkle]);

    if (!rSideOk && !lSideOk) {
      lastReason = 'SQ: missing hip/knee/ankle';
      return null;
    }

    final hip = pose.landmarks[rSideOk ? PoseLandmarkType.rightHip : PoseLandmarkType.leftHip]!;
    final knee = pose.landmarks[rSideOk ? PoseLandmarkType.rightKnee : PoseLandmarkType.leftKnee]!;
    final ankle = pose.landmarks[rSideOk ? PoseLandmarkType.rightAnkle : PoseLandmarkType.leftAnkle]!;

    final ang = _angleDeg(hip, knee, ankle);

    final avgShoulderY = (lSh!.y + rSh!.y) / 2.0;
    final avgHipY = (lHip!.y + rHip!.y) / 2.0;
    final torsoH = (avgHipY - avgShoulderY).abs().clamp(1.0, 1e9);

    // Hip-to-knee gap: deep squat => hips go down closer to knee level => gap gets smaller.
    final hipKneeGapPx = (knee.y - hip.y).abs(); // always positive
    final hipKneeGapTorso = (hipKneeGapPx / torsoH).clamp(0.0, 2.0);

    // Rep attempt hysteresis
    final startAttempt = ang < 165; // leaving standing
    final endAttempt = ang > (upAngleDeg + 5); // must be clearly standing again

    // If we are idle/standing and not in a rep, do nothing.
    if (!_sqInRep && !startAttempt) {
      lastReason = 'SQ: idle/standing';
      return null;
    }

    // Start rep
    if (!_sqInRep && startAttempt) {
      _sqInRep = true;
      _sqMinKneeAngle = ang;
      _sqMinHipKneeGapTorso = hipKneeGapTorso;
      lastReason = 'SQ: start tracking';
      return null;
    }

    // Track rep
    if (_sqInRep) {
      if (ang < _sqMinKneeAngle) _sqMinKneeAngle = ang;
      if (hipKneeGapTorso < _sqMinHipKneeGapTorso) _sqMinHipKneeGapTorso = hipKneeGapTorso;

      // End rep -> score once
      if (endAttempt) {
        _sqInRep = false;

        final minA = _sqMinKneeAngle;
        final minGap = _sqMinHipKneeGapTorso;

        // Knee depth points
        int kneePts;
        if (minA <= (downAngleDeg + 5)) {
          kneePts = 10;
        } else if (minA <= (downAngleDeg + 15)) {
          kneePts = 7;
        } else if (minA <= (downAngleDeg + 25)) {
          kneePts = 4;
        } else {
          kneePts = 1;
        }

        // Hip-to-knee gap points (smaller gap = better depth)
        // Tune these if needed:
        // - <= 0.22 torso: deep (good)
        // - 0.23..0.30: ok
        // - 0.31..0.38: shallow
        // - > 0.38: very shallow
        int gapPts;
        if (minGap <= 0.22) {
          gapPts = 10;
        } else if (minGap <= 0.30) {
          gapPts = 7;
        } else if (minGap <= 0.38) {
          gapPts = 4;
        } else {
          gapPts = 1;
        }

        // Weight gap more than knee (gap is the depth guard)
        final pts = ((0.65 * gapPts) + (0.35 * kneePts)).round().clamp(0, 10);

        _accumulatePoints(pts, 10);

        lastReason =
            'SQ: minAngle=${minA.toStringAsFixed(0)} knee=$kneePts/10 minGap=${minGap.toStringAsFixed(2)} gap=$gapPts/10 -> pts=$pts/10';

        return pts >= 7;
      }

      lastReason =
          'SQ: tracking (minAngle=${_sqMinKneeAngle.toStringAsFixed(0)}, minGap=${_sqMinHipKneeGapTorso.toStringAsFixed(2)})';
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
