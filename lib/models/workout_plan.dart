enum ActivityLevel {
  sedentary,
  lightlyActive,
  moderatelyActive,
  veryActive,
}

extension ActivityLevelLabel on ActivityLevel {
  String get label {
    switch (this) {
      case ActivityLevel.sedentary:
        return 'Sedentary';
      case ActivityLevel.lightlyActive:
        return 'Lightly Active';
      case ActivityLevel.moderatelyActive:
        return 'Moderately Active';
      case ActivityLevel.veryActive:
        return 'Very Active';
    }
  }
}

class WorkoutPlan {
  /// true = time-based per set (Jumping Jacks)
  /// false = reps-based per set (Squats)
  final bool isTimed;

  /// reps per set (reps-based)
  final int reps;

  /// total sets
  final int sets;

  /// seconds per set (time-based)
  final int timerPerSet;

  /// rest seconds between sets
  final int restSeconds;

  /// "00:30"
  final String timerLabel;

  final ActivityLevel level;

  WorkoutPlan({
    required this.isTimed,
    required this.reps,
    required this.sets,
    required this.restSeconds,
    this.level = ActivityLevel.sedentary,

    // support either name
    int? timerPerSet,
    int? timerSeconds,

    String? timerLabel,
  })  : timerPerSet = (timerPerSet ?? timerSeconds ?? 0),
        timerLabel =
            timerLabel ?? _formatMMSS((timerPerSet ?? timerSeconds ?? 0));

  /// Build from your provided recommendations
  static WorkoutPlan recommended({
    required String workoutTitle,
    required ActivityLevel level,
  }) {
    final t = workoutTitle.toLowerCase();
    final isJumpingJacks = t.contains('jump') || t.contains('jack');
    t.contains('squat');

    if (isJumpingJacks) {
      final rec = _jj[level]!;
      return WorkoutPlan(
        isTimed: true,
        reps: 0,
        sets: rec.sets,
        timerPerSet: rec.timeSeconds,
        restSeconds: rec.restSeconds,
        level: level,
      );
    }

    // squats OR fallback
    final rec = _squats[level]!;
    return WorkoutPlan(
      isTimed: false,
      reps: rec.reps,
      sets: rec.sets,
      timerPerSet: 0,
      restSeconds: rec.restSeconds,
      level: level,
    );
  }

  WorkoutPlan copyWith({
    bool? isTimed,
    int? reps,
    int? sets,
    int? timerPerSet,
    int? restSeconds,
    String? timerLabel,
    ActivityLevel? level,
  }) {
    final newTimer = timerPerSet ?? this.timerPerSet;
    return WorkoutPlan(
      isTimed: isTimed ?? this.isTimed,
      reps: reps ?? this.reps,
      sets: sets ?? this.sets,
      restSeconds: restSeconds ?? this.restSeconds,
      timerPerSet: newTimer,
      timerLabel: timerLabel ?? _formatMMSS(newTimer),
      level: level ?? this.level,
    );
  }

  // -------------------------
  // Tables (NOT const -> no invalid_constant)
  // -------------------------
  static final Map<ActivityLevel, _RepsRec> _squats = {
    ActivityLevel.sedentary: const _RepsRec(reps: 6, sets: 2, restSeconds: 90),
    ActivityLevel.lightlyActive: const _RepsRec(reps: 8, sets: 3, restSeconds: 75),
    ActivityLevel.moderatelyActive: const _RepsRec(reps: 10, sets: 3, restSeconds: 75),
    ActivityLevel.veryActive: const _RepsRec(reps: 12, sets: 4, restSeconds: 60),
  };

  static final Map<ActivityLevel, _TimedRec> _jj = {
    ActivityLevel.sedentary: const _TimedRec(timeSeconds: 30, sets: 2, restSeconds: 45),
    ActivityLevel.lightlyActive: const _TimedRec(timeSeconds: 45, sets: 3, restSeconds: 30),
    ActivityLevel.moderatelyActive: const _TimedRec(timeSeconds: 60, sets: 3, restSeconds: 30),
    ActivityLevel.veryActive: const _TimedRec(timeSeconds: 90, sets: 4, restSeconds: 30),
  };

  // -------------------------
  // Helper
  // -------------------------

  static String _formatMMSS(int seconds) {
    if (seconds < 0) seconds = 0;
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}

ActivityLevel parseActivityLevel(Object? raw) {
  if (raw is ActivityLevel) return raw;

  final s = (raw?.toString() ?? '').trim();
  if (s.isEmpty) return ActivityLevel.sedentary;

  // handles: "ActivityLevel.sedentary", "sedentary", "Sedentary",
  // "Lightly Active", "lightlyActive", etc.
  final lower = s.toLowerCase();
  final key = (lower.contains('.') ? lower.split('.').last : lower)
      .replaceAll(RegExp(r'\s+'), '');

  switch (key) {
    case 'sedentary':
      return ActivityLevel.sedentary;
    case 'lightlyactive':
      return ActivityLevel.lightlyActive;
    case 'moderatelyactive':
      return ActivityLevel.moderatelyActive;
    case 'veryactive':
      return ActivityLevel.veryActive;
    default:
      return ActivityLevel.sedentary;
  }
}

class _RepsRec {
  final int reps;
  final int sets;
  final int restSeconds;
  const _RepsRec({
    required this.reps,
    required this.sets,
    required this.restSeconds,
  });
}

class _TimedRec {
  final int timeSeconds;
  final int sets;
  final int restSeconds;
  const _TimedRec({
    required this.timeSeconds,
    required this.sets,
    required this.restSeconds,
  });
}
