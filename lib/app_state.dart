import 'package:flutter/material.dart';
import 'services/database_helper.dart'; // <--- IDAGDAG ITO

enum Gender { male, female }

/// Holds global app data (profile + workouts).
class AppState extends ChangeNotifier {
  String _name = '';
  Gender? _gender;
  double _heightCm = 180;
  double _weightKg = 80;

  /// Store workout days as "YYYY-MM-DD" strings (timezone-safe)
  final Set<String> _workoutDayKeys = {};

  // --- IDAGDAG ITO ---
  AppState() {
    _loadData(); // Load DB data pagkabukas ng app
  }

  Future<void> _loadData() async {
    // 1. Load Profile
    final profileData = await DatabaseHelper.instance.getProfile();
    if (profileData != null) {
      _name = profileData['name'] ?? '';
      final gString = profileData['gender'];
      if (gString == 'male') _gender = Gender.male;
      if (gString == 'female') _gender = Gender.female;
      _heightCm = profileData['height'] ?? 180.0;
      _weightKg = profileData['weight'] ?? 80.0;
    }

    // 2. Load History
    final dates = await DatabaseHelper.instance.getAllWorkoutDates();
    _workoutDayKeys.addAll(dates);

    notifyListeners();
  }
  // -------------------

  // ----------------------------
  // Profile
  // ----------------------------
  String get name => _name;
  Gender? get gender => _gender;
  double get heightCm => _heightCm;
  double get weightKg => _weightKg;

  // --- PALITAN ANG saveProfile NITO ---
  Future<void> saveProfile({
    required String newName,
    required Gender? newGender,
    required double newHeightCm,
    required double newWeightKg,
  }) async {
    _name = newName;
    _gender = newGender;
    _heightCm = newHeightCm;
    _weightKg = newWeightKg;
    notifyListeners();

    // Save to DB
    await DatabaseHelper.instance.saveProfile({
      'name': newName,
      'gender': newGender == Gender.male ? 'male' : 'female',
      'height': newHeightCm,
      'weight': newWeightKg,
    });
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
    return DateTime(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
  }

  bool isWorkoutDay(DateTime d) => _workoutDayKeys.contains(_keyOf(d));

  // --- PALITAN ANG toggleWorkoutDay NITO ---
  Future<void> toggleWorkoutDay(DateTime d) async {
    final k = _keyOf(d);
    if (_workoutDayKeys.contains(k)) {
      _workoutDayKeys.remove(k);
      await DatabaseHelper.instance.deleteWorkoutDate(k); // Delete from DB
    } else {
      _workoutDayKeys.add(k);
      await DatabaseHelper.instance.insertWorkoutDate(k); // Add to DB
    }
    notifyListeners();
  }

  // --- PALITAN ANG setWorkoutDay NITO ---
  Future<void> setWorkoutDay(DateTime d, bool done) async {
    final k = _keyOf(d);
    if (done) {
      _workoutDayKeys.add(k);
      await DatabaseHelper.instance.insertWorkoutDate(k); // Add to DB
    } else {
      _workoutDayKeys.remove(k);
      await DatabaseHelper.instance.deleteWorkoutDate(k); // Delete from DB
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
    assert(
      scope != null,
      'AppStateScope not found. Wrap MaterialApp with AppStateScope.',
    );
    return scope!.notifier!;
  }
}
