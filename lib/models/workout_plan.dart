class WorkoutPlan {
  final bool isTimed;          // true = timer-based, false = reps-based
  final int sets;              // number of sets
  final int reps;              // reps per set (if !isTimed)
  final Duration timerPerSet;  // seconds per set (if isTimed)

  const WorkoutPlan({
    required this.isTimed,
    required this.sets,
    required this.reps,
    required this.timerPerSet,
  });

  String get timerLabel => '${timerPerSet.inSeconds}s';

  static WorkoutPlan forWorkout({
    required String title,
    required String? activityLevel,
  }) {
    final mult = _multiplier(activityLevel);
    final setDelta = _setDelta(activityLevel);

    final t = title.toLowerCase();

    // Decide if timed or reps-based (extend this as you add workouts)
    final isTimed = t.contains('jump') || t.contains('plank') || t.contains('mountain');

    if (isTimed) {
      final baseSeconds = _baseSecondsFor(t); // e.g., 30s for squats demo? (change as you like)
      final seconds = _roundTo5((baseSeconds * mult).round()).clamp(10, 120);
      final sets = (_baseSetsForTimed(t) + setDelta).clamp(1, 6);

      return WorkoutPlan(
        isTimed: true,
        sets: sets,
        reps: 0,
        timerPerSet: Duration(seconds: seconds),
      );
    } else {
      final baseReps = _baseRepsFor(t); // e.g., 12 for squats
      final reps = (baseReps * mult).round().clamp(5, 30);
      final sets = (_baseSetsForReps(t) + setDelta).clamp(1, 6);

      return WorkoutPlan(
        isTimed: false,
        sets: sets,
        reps: reps,
        timerPerSet: Duration.zero,
      );
    }
  }

  // ---------------- helpers ----------------

  static double _multiplier(String? level) {
    final a = (level ?? '').toLowerCase();
    if (a.contains('sedentary')) return 0.85;
    if (a.contains('light')) return 1.00;
    if (a.contains('moderate')) return 1.15;
    if (a.contains('very')) return 1.30;
    return 1.00; // default
    }

  static int _setDelta(String? level) {
    final a = (level ?? '').toLowerCase();
    if (a.contains('sedentary')) return 0;
    if (a.contains('light')) return 0;
    if (a.contains('moderate')) return 1;
    if (a.contains('very')) return 1;
    return 0;
  }

  static int _roundTo5(int n) => ((n + 2) ~/ 5) * 5;

  static int _baseSecondsFor(String t) {
    if (t.contains('jump')) return 25;
    if (t.contains('plank')) return 20;
    if (t.contains('mountain')) return 20;
    return 20;
  }

  static int _baseRepsFor(String t) {
    if (t.contains('squat')) return 12;
    if (t.contains('push')) return 10;
    if (t.contains('lunge')) return 10;
    return 10;
  }

  static int _baseSetsForTimed(String t) => 3;
  static int _baseSetsForReps(String t) => 3;
}
