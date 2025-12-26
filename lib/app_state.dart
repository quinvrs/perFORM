import 'package:flutter/material.dart';

enum Gender { male, female }

/// Holds global app data (profile + workouts).
class AppState extends ChangeNotifier {
  String _name = '';
  Gender? _gender;
  double _heightCm = 180;
  double _weightKg = 80;

  /// Store workout days as "YYYY-MM-DD" strings (timezone-safe)
  final Set<String> _workoutDayKeys = {};

  // ----------------------------
  // Profile
  // ----------------------------
  String get name => _name;
  Gender? get gender => _gender;
  double get heightCm => _heightCm;
  double get weightKg => _weightKg;

  void saveProfile({
    required String newName,
    required Gender? newGender,
    required double newHeightCm,
    required double newWeightKg,
  }) {
    _name = newName;
    _gender = newGender;
    _heightCm = newHeightCm;
    _weightKg = newWeightKg;
    notifyListeners();
  }

  // ----------------------------
  // Workout day helpers
  // ----------------------------
  String _keyOf(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  DateTime _dateFromKey(String k) {
    final parts = k.split('-');
    return DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
  }

  bool isWorkoutDay(DateTime d) => _workoutDayKeys.contains(_keyOf(d));

  void toggleWorkoutDay(DateTime d) {
    final k = _keyOf(d);
    if (_workoutDayKeys.contains(k)) {
      _workoutDayKeys.remove(k);
    } else {
      _workoutDayKeys.add(k);
    }
    notifyListeners();
  }

  void setWorkoutDay(DateTime d, bool done) {
    final k = _keyOf(d);
    if (done) {
      _workoutDayKeys.add(k);
    } else {
      _workoutDayKeys.remove(k);
    }
    notifyListeners();
  }

  List<DateTime> get workoutDaysSorted {
    final list = _workoutDayKeys.map(_dateFromKey).toList();
    list.sort((a, b) => b.compareTo(a));
    return list;
  }

  int weeklySessions() {
    final today = DateTime.now();
    final end = DateTime(today.year, today.month, today.day);
    final start = end.subtract(const Duration(days: 6));

    var count = 0;
    for (final k in _workoutDayKeys) {
      final d = _dateFromKey(k);
      if (!d.isBefore(start) && !d.isAfter(end)) count++;
    }
    return count;
  }

  /// ✅ GETTER (do NOT call like currentStreak())
  int get currentStreak {
    var streak = 0;
    var d = DateTime.now();
    d = DateTime(d.year, d.month, d.day);

    while (isWorkoutDay(d)) {
      streak++;
      d = d.subtract(const Duration(days: 1));
    }
    return streak;
  }
}

class AppStateScope extends InheritedNotifier<AppState> {
  const AppStateScope({
    super.key,
    required super.notifier,
    required super.child,
  });

  static AppState of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppStateScope>();
    assert(scope != null, 'AppStateScope not found. Wrap MaterialApp with AppStateScope.');
    return scope!.notifier!;
  }
}
