import 'dart:math' as math;
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

enum ExerciseType { squat }

enum _SquatPhase { unknown, standing, bottom }

class RepCounter {
  final ExerciseType type;

  // Public outputs
  int reps = 0;
  String debug = '';

  // --- Squat tuning (good starting values for side view)
  final double downAngleDeg; // smaller = deeper squat
  final double upAngleDeg;   // larger = standing
  final int confirmFrames;   // requires N consistent frames to change state
  final Duration minRepInterval; // avoid fast double counts
  //revision one leg fix
  final bool requireBothFeetDown;
  final double minFootLikelihood;
  final double feetLevelToleranceTorso; // max ankle Y mismatch as fraction of torso height
  final double ankleAboveKneeTolTorso;

  _SquatPhase _phase = _SquatPhase.unknown;
  int _downHits = 0;
  int _upHits = 0;
  DateTime _lastRepTime = DateTime.fromMillisecondsSinceEpoch(0);

  RepCounter.squat({
    this.downAngleDeg = 110, // try 100–120
    this.upAngleDeg = 160,   // try 155–170
    this.confirmFrames = 3,
    this.minRepInterval = const Duration(milliseconds: 450),

    this.requireBothFeetDown = false,
    this.minFootLikelihood = 0.35,
    this.feetLevelToleranceTorso = 0.22, // 0.12 stricter, 0.22 looser
    this.ankleAboveKneeTolTorso = 0.06,
  }) : type = ExerciseType.squat;

  void reset() {
    reps = 0;
    debug = '';
    _phase = _SquatPhase.unknown;
    _downHits = 0;
    _upHits = 0;
    _lastRepTime = DateTime.fromMillisecondsSinceEpoch(0);
  }

  /// Call this per detected pose frame.
  /// Returns true ONLY when a rep is counted.
  bool update(Pose pose) {
    switch (type) {
      case ExerciseType.squat:
        return _updateSquat(pose);
    }
  }

  //Squat logic
  bool _updateSquat(Pose pose) {
    final side = _bestSide(pose);

    final hip = pose.landmarks[side.hip];
    final knee = pose.landmarks[side.knee];
    final ankle = pose.landmarks[side.ankle];

    if (hip == null || knee == null || ankle == null) {
      debug = 'Missing landmarks (hip/knee/ankle).';
      return false;
    }
    if (requireBothFeetDown) {
      final torsoH = _torsoHeight(pose, fallbackHip: hip, fallbackKnee: knee);
      final reason = _feetGateReason(pose, torsoH);
      if (reason != null) {
        // freeze the state machine on suspicious frames
        _downHits = 0;
        _upHits = 0;
        if (_phase == _SquatPhase.unknown) _phase = _SquatPhase.standing;

        debug = '$reason | phase=$_phase reps=$reps';
        return false;
      }
    }
    final kneeAngle = _angleDeg(hip, knee, ankle);
    debug =
        'knee=${kneeAngle.toStringAsFixed(1)} '
        'phase=$_phase reps=$reps '
        '(down<$downAngleDeg up>$upAngleDeg)';

    // DOWN condition (deep squat)
    if (kneeAngle <= downAngleDeg) {
      _downHits++;
      _upHits = 0;

      if (_downHits >= confirmFrames && _phase != _SquatPhase.bottom) {
        _phase = _SquatPhase.bottom;
      }
      return false;
    }

    // UP condition (standing)
    if (kneeAngle >= upAngleDeg) {
      _upHits++;
      _downHits = 0;

      if (_upHits >= confirmFrames) {
        // Count rep ONLY when we came from bottom -> standing
        if (_phase == _SquatPhase.bottom) {
          final now = DateTime.now();
          if (now.difference(_lastRepTime) >= minRepInterval) {
            reps++;
            _lastRepTime = now;
            _phase = _SquatPhase.standing;
            debug += ' ✅ REP!';
            return true;
          }
        } else {
          _phase = _SquatPhase.standing;
        }
      }
      return false;
    }

    // In-between (moving). Don’t change phase; just reset hit counters slowly.
    _downHits = 0;
    _upHits = 0;

    // If we have no phase yet, assume standing-ish after first valid frame.
    if (_phase == _SquatPhase.unknown) _phase = _SquatPhase.standing;

    return false;
  }

  // Helpers
  //one leg raise fix helpers
  double _torsoHeight(Pose pose, {PoseLandmark? fallbackHip, PoseLandmark? fallbackKnee}) {
    final lSh = pose.landmarks[PoseLandmarkType.leftShoulder];
    final rSh = pose.landmarks[PoseLandmarkType.rightShoulder];
    final lHip = pose.landmarks[PoseLandmarkType.leftHip];
    final rHip = pose.landmarks[PoseLandmarkType.rightHip];

    if (lSh != null && rSh != null && lHip != null && rHip != null) {
      final avgShoulderY = (lSh.y + rSh.y) / 2.0;
      final avgHipY = (lHip.y + rHip.y) / 2.0;
      return (avgHipY - avgShoulderY).abs().clamp(1.0, 1e9);
    }

    // fallback: use thigh length approx
    if (fallbackHip != null && fallbackKnee != null) {
      return ((fallbackHip.y - fallbackKnee.y).abs() * 2.0).clamp(1.0, 1e9);
    }

    return 200.0; // last-resort scale
  }

  /// Returns null if OK, else a short reason why we should IGNORE this frame for squats.
  String? _feetGateReason(Pose pose, double torsoH) {
    final lAnk = pose.landmarks[PoseLandmarkType.leftAnkle];
    final rAnk = pose.landmarks[PoseLandmarkType.rightAnkle];

    // If we can't see both ankles, don't block (to avoid killing reps on occlusion)
    if (lAnk == null || rAnk == null) return null;

    final lLik = lAnk.likelihood ?? 0.0;
    final rLik = rAnk.likelihood ?? 0.0;

    // If ankles are too low confidence, don't block (avoid false negatives)
    if (lLik < minFootLikelihood || rLik < minFootLikelihood) return null;

    final maxDY = feetLevelToleranceTorso * torsoH;
    final dy = (lAnk.y - rAnk.y).abs();

    // One foot lifted -> ankle Y differs a lot
    if (dy > maxDY) return 'Feet not level (dy=${dy.toStringAsFixed(1)} > ${maxDY.toStringAsFixed(1)})';

    // Optional extra: if ankle appears ABOVE knee by a lot, it’s almost surely a leg raise
    final lKnee = pose.landmarks[PoseLandmarkType.leftKnee];
    final rKnee = pose.landmarks[PoseLandmarkType.rightKnee];
    final tol = ankleAboveKneeTolTorso * torsoH;

    if (lKnee != null) {
      final kLik = lKnee.likelihood ?? 0.0;
      if (kLik >= minFootLikelihood && (lAnk.y + tol) < lKnee.y) {
        return 'Left ankle above left knee (leg raise)';
      }
    }
    if (rKnee != null) {
      final kLik = rKnee.likelihood ?? 0.0;
      if (kLik >= minFootLikelihood && (rAnk.y + tol) < rKnee.y) {
        return 'Right ankle above right knee (leg raise)';
      }
    }

    return null;
  }

  double _angleDeg(PoseLandmark a, PoseLandmark b, PoseLandmark c) {
    // Angle at point b formed by a-b-c
    final abx = a.x - b.x;
    final aby = a.y - b.y;
    final cbx = c.x - b.x;
    final cby = c.y - b.y;

    final dot = abx * cbx + aby * cby;
    final mag1 = math.sqrt(abx * abx + aby * aby);
    final mag2 = math.sqrt(cbx * cbx + cby * cby);
    if (mag1 == 0 || mag2 == 0) return 180;

    var cosv = dot / (mag1 * mag2);
    cosv = cosv.clamp(-1.0, 1.0);
    return math.acos(cosv) * 180 / math.pi;
  }

  _Side _bestSide(Pose pose) {
    // For sideways, one leg is usually clearer. Pick side with higher landmark likelihood.
    double score(PoseLandmarkType hip, PoseLandmarkType knee, PoseLandmarkType ankle) {
      double l(PoseLandmarkType t) => pose.landmarks[t]?.likelihood ?? 0.0;
      return l(hip) + l(knee) + l(ankle);
    }

    final leftScore = score(
      PoseLandmarkType.leftHip,
      PoseLandmarkType.leftKnee,
      PoseLandmarkType.leftAnkle,
    );
    final rightScore = score(
      PoseLandmarkType.rightHip,
      PoseLandmarkType.rightKnee,
      PoseLandmarkType.rightAnkle,
    );

    return (rightScore > leftScore) ? _Side.right() : _Side.left();
  }
}

class _Side {
  final PoseLandmarkType hip;
  final PoseLandmarkType knee;
  final PoseLandmarkType ankle;

  const _Side._(this.hip, this.knee, this.ankle);

  factory _Side.left() => const _Side._(
        PoseLandmarkType.leftHip,
        PoseLandmarkType.leftKnee,
        PoseLandmarkType.leftAnkle,
      );

  factory _Side.right() => const _Side._(
        PoseLandmarkType.rightHip,
        PoseLandmarkType.rightKnee,
        PoseLandmarkType.rightAnkle,
      );
}