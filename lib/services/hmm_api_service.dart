import 'dart:convert';
import 'dart:math' as math;

import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:http/http.dart' as http;

class HmmResult {
  final String state;
  final String observation;
  final int reps;
  final bool isCorrect;
  final int score;
  final String feedback;

  HmmResult({
    required this.state,
    required this.observation,
    required this.reps,
    required this.isCorrect,
    required this.score,
    required this.feedback,
  });

  factory HmmResult.fromJson(Map<String, dynamic> json) {
    return HmmResult(
      state: json['state']?.toString() ?? 'unknown',
      observation: json['observation']?.toString() ?? 'unknown',
      reps: json['reps'] is int ? json['reps'] : 0,
      isCorrect: json['is_correct'] == true,
      score: json['score'] is int ? json['score'] : 0,
      feedback: json['feedback']?.toString() ?? '',
    );
  }
}

class HmmApiService {
  /// Android emulator:
  /// http://10.0.2.2:8000
  ///
  /// Physical phone:
  /// replace this with your laptop IP address, example:
  /// http://192.168.1.10:8000
  final String baseUrl;

  const HmmApiService({
    this.baseUrl = 'http://192.168.100.96:8000',
  });

  Future<HmmResult?> analyzeSquatPose({
    required Pose pose,
    String sessionId = 'default',
  }) async {
    final features = _extractSquatFeatures(pose);

    if (features == null) {
      return null;
    }

    final url = Uri.parse('$baseUrl/analyze');

    final body = {
      'session_id': sessionId,
      'exercise': 'squat',
      'knee_angle': features.kneeAngle,
      'hip_knee_gap_torso': features.hipKneeGapTorso,
    };

    try {
      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(milliseconds: 700));

      if (response.statusCode != 200) {
        return null;
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      return HmmResult.fromJson(decoded);
    } catch (_) {
      return null;
    }
  }

  Future<void> resetSession({
    String sessionId = 'default',
  }) async {
    final url = Uri.parse('$baseUrl/reset/$sessionId');

    try {
      await http.post(url).timeout(const Duration(milliseconds: 700));
    } catch (_) {
      // Ignore connection errors for prototype.
    }
  }

  _SquatFeatures? _extractSquatFeatures(Pose pose) {
    final side = _bestSide(pose);

    if (side == null) return null;

    final hip = pose.landmarks[side.hip];
    final knee = pose.landmarks[side.knee];
    final ankle = pose.landmarks[side.ankle];

    final leftShoulder = pose.landmarks[PoseLandmarkType.leftShoulder];
    final rightShoulder = pose.landmarks[PoseLandmarkType.rightShoulder];
    final leftHip = pose.landmarks[PoseLandmarkType.leftHip];
    final rightHip = pose.landmarks[PoseLandmarkType.rightHip];

    if (hip == null ||
        knee == null ||
        ankle == null ||
        leftShoulder == null ||
        rightShoulder == null ||
        leftHip == null ||
        rightHip == null) {
      return null;
    }

    final kneeAngle = _angleDeg(hip, knee, ankle);

    final avgShoulderY = (leftShoulder.y + rightShoulder.y) / 2.0;
    final avgHipY = (leftHip.y + rightHip.y) / 2.0;

    final torsoHeight = (avgHipY - avgShoulderY).abs().clamp(1.0, 999999.0);

    final hipKneeGapPx = (knee.y - hip.y).abs();
    final hipKneeGapTorso = (hipKneeGapPx / torsoHeight).clamp(0.0, 2.0);

    return _SquatFeatures(
      kneeAngle: kneeAngle,
      hipKneeGapTorso: hipKneeGapTorso,
    );
  }

  _Side? _bestSide(Pose pose) {
    double score(
      PoseLandmarkType hip,
      PoseLandmarkType knee,
      PoseLandmarkType ankle,
    ) {
      double likelihood(PoseLandmarkType type) {
        return pose.landmarks[type]?.likelihood ?? 0.0;
      }

      return likelihood(hip) + likelihood(knee) + likelihood(ankle);
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

    if (leftScore <= 0 && rightScore <= 0) {
      return null;
    }

    if (rightScore > leftScore) {
      return const _Side(
        hip: PoseLandmarkType.rightHip,
        knee: PoseLandmarkType.rightKnee,
        ankle: PoseLandmarkType.rightAnkle,
      );
    }

    return const _Side(
      hip: PoseLandmarkType.leftHip,
      knee: PoseLandmarkType.leftKnee,
      ankle: PoseLandmarkType.leftAnkle,
    );
  }

  double _angleDeg(
    PoseLandmark a,
    PoseLandmark b,
    PoseLandmark c,
  ) {
    final abx = a.x - b.x;
    final aby = a.y - b.y;
    final cbx = c.x - b.x;
    final cby = c.y - b.y;

    final dot = abx * cbx + aby * cby;
    final mag1 = math.sqrt(abx * abx + aby * aby);
    final mag2 = math.sqrt(cbx * cbx + cby * cby);

    if (mag1 == 0 || mag2 == 0) {
      return 180.0;
    }

    final cosValue = (dot / (mag1 * mag2)).clamp(-1.0, 1.0);
    return math.acos(cosValue) * 180 / math.pi;
  }
}

class _SquatFeatures {
  final double kneeAngle;
  final double hipKneeGapTorso;

  const _SquatFeatures({
    required this.kneeAngle,
    required this.hipKneeGapTorso,
  });
}

class _Side {
  final PoseLandmarkType hip;
  final PoseLandmarkType knee;
  final PoseLandmarkType ankle;

  const _Side({
    required this.hip,
    required this.knee,
    required this.ankle,
  });
}