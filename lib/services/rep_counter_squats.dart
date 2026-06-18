import 'dart:math' as math;
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

enum ExerciseType { squat }

enum _SquatPhase { unknown, standing, bottom }

class RepCounter {
  final ExerciseType type;

  int reps = 0;
  String debug = '';

  // --- Squat tuning (good starting values for side view)
  final double downAngleDeg; 
  final double upAngleDeg; 
  final int confirmFrames; 
  final Duration minRepInterval; 

  // --- Anti false reps (single-leg raise)
  /// Require hips to drop by this fraction of torso height before accepting 
  final double minHipDropTorso;
  final double hipBaseEmaAlpha;
  // for when a foot is lifted OR when ankles are missing/low-confidence.
  final bool strictFeetOnRep;
  final double strictFootMinLikelihood;
  final double strictFeetLevelTolTorso;

  _SquatPhase _phase = _SquatPhase.unknown;
  int _downHits = 0;
  int _upHits = 0;
  DateTime _lastRepTime = DateTime.fromMillisecondsSinceEpoch(0);

  // Standing baseline hip Y (EMA)
  double? _baseHipY;

  RepCounter.squat({
    this.downAngleDeg = 110,
    this.upAngleDeg = 160,
    this.confirmFrames = 2,
    this.minRepInterval = const Duration(milliseconds: 450),
    this.minHipDropTorso = 0.14,
    this.hipBaseEmaAlpha = 0.15,
    this.strictFeetOnRep = false,
    this.strictFootMinLikelihood = 0.50,
    this.strictFeetLevelTolTorso = 0.12,
  }) : type = ExerciseType.squat;

  void reset() {
    reps = 0;
    debug = '';
    _phase = _SquatPhase.unknown;
    _downHits = 0;
    _upHits = 0;
    _lastRepTime = DateTime.fromMillisecondsSinceEpoch(0);
    _baseHipY = null;
  }

  /// Call this per detected pose frame.
  /// Returns true ONLY when a rep is counted.
  bool update(Pose pose) {
    switch (type) {
      case ExerciseType.squat:
        return _updateSquat(pose);
    }
  }

  // Squat logic
  bool _updateSquat(Pose pose) {
    final side = _bestSide(pose);

    final hip = pose.landmarks[side.hip];
    final knee = pose.landmarks[side.knee];
    final ankle = pose.landmarks[side.ankle];

    if (hip == null || knee == null || ankle == null) {
      debug = 'Missing landmarks (hip/knee/ankle).';
      return false;
    }

    final kneeAngle = _angleDeg(hip, knee, ankle);
    final torsoH = _torsoH(pose, hip, knee);

    // Update standing hip baseline when clearly upright.
    // y grows downward, so a "drop" means hip.y becomes larger.
    if (kneeAngle >= upAngleDeg) {
      _baseHipY = _emaD(_baseHipY, hip.y, hipBaseEmaAlpha);
    }

    final hipDropped = _baseHipY == null
        ? true
        : (hip.y >= _baseHipY! + (minHipDropTorso * torsoH));

    debug =
        'knee=${kneeAngle.toStringAsFixed(1)} '
        'hipY=${hip.y.toStringAsFixed(1)} baseHip=${_baseHipY?.toStringAsFixed(1) ?? "na"} '
        'drop=${hipDropped ? "Y" : "N"} '
        'phase=$_phase reps=$reps '
        '(down<$downAngleDeg up>$upAngleDeg)';

    // DOWN condition (deep squat)
    if (kneeAngle <= downAngleDeg) {
      if (!hipDropped) {
        _downHits = 0;
        _upHits = 0;
        if (_phase == _SquatPhase.unknown) _phase = _SquatPhase.standing;
        debug += ' | blocked: no hip drop';
        return false;
      }

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
          if (strictFeetOnRep) {
            final reason = _strictFeetGate(pose, torsoH);
            if (reason != null) {
              debug += ' | blocked: $reason';
              return false; 
            }
          }

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
    _downHits = 0;
    _upHits = 0;

    if (_phase == _SquatPhase.unknown) _phase = _SquatPhase.standing;
    return false;
  }

  // Helpers
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

  double _emaD(double? prev, double next, double alpha) {
    final a = alpha.clamp(0.0, 1.0);
    return prev == null ? next : (prev * (1.0 - a)) + (next * a);
  }

  double _torsoH(Pose pose, PoseLandmark hip, PoseLandmark knee) {
    final lSh = pose.landmarks[PoseLandmarkType.leftShoulder];
    final rSh = pose.landmarks[PoseLandmarkType.rightShoulder];
    final lHip = pose.landmarks[PoseLandmarkType.leftHip];
    final rHip = pose.landmarks[PoseLandmarkType.rightHip];

    if (lSh != null && rSh != null && lHip != null && rHip != null) {
      final avgShoulderY = (lSh.y + rSh.y) / 2.0;
      final avgHipY = (lHip.y + rHip.y) / 2.0;
      return (avgHipY - avgShoulderY).abs().clamp(1.0, 1e9);
    }

    return ((hip.y - knee.y).abs() * 2.0).clamp(1.0, 1e9);
  }

  String? _strictFeetGate(Pose pose, double torsoH) {
    final lA = pose.landmarks[PoseLandmarkType.leftAnkle];
    final rA = pose.landmarks[PoseLandmarkType.rightAnkle];
    if (lA == null || rA == null) return 'Missing ankles';

    final lLik = lA.likelihood;
    final rLik = rA.likelihood;
    if (lLik < strictFootMinLikelihood || rLik < strictFootMinLikelihood) {
      return 'Low ankle confidence';
    }

    final dy = (lA.y - rA.y).abs();
    final maxDy = strictFeetLevelTolTorso * torsoH;
    if (dy > maxDy) return 'Feet not level (dy=${dy.toStringAsFixed(1)})';

    return null;
  }

  _Side _bestSide(Pose pose) {
    // since its sideways, one leg is usually clearer. so pick a side with higher landmark likelihood.
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
