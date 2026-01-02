import 'package:flutter/material.dart';
import 'services/database_helper.dart';

enum Gender { male, female }

/// Holds global app data (profile + workouts).
class AppState extends ChangeNotifier {
  // ----------------------------
  // Profile (private backing fields)
  // ----------------------------
  String _name = '';
  Gender? _gender;
  double _heightCm = 180;
  double _weightKg = 80;

  // Optional profile fields
  String? _avatarPath;
  String? _mainGoal;
  String? _activityLevel;

  // ----------------------------
  // Workouts
  // ----------------------------
  /// Store workout days as "YYYY-MM-DD" strings (timezone-safe)
  final Set<String> _workoutDayKeys = {};

  AppState() {
    _loadData(); // fire and forget
  }

  // ----------------------------
  // Profile getters
  // ----------------------------
  String get name => _name;
  Gender? get gender => _gender;
  double get heightCm => _heightCm;
  double get weightKg => _weightKg;

  String? get avatarPath => _avatarPath;
  String? get mainGoal => _mainGoal;
  String? get activityLevel => _activityLevel;

  // Optional: single-field updaters
  void setAvatarPath(String? path) {
    _avatarPath = path;
    notifyListeners();
  }

  void setMainGoal(String? v) {
    _mainGoal = v;
    notifyListeners();
  }

  void setActivityLevel(String? v) {
    _activityLevel = v;
    notifyListeners();
  }

  // ----------------------------
  // Load from DB
  // ----------------------------
  Future<void> _loadData() async {
    try {
      // 1) Load Profile
      final profileData = await DatabaseHelper.instance.getProfile();
      if (profileData != null) {
        _name = (profileData['name'] ?? '').toString();

        final gString = profileData['gender']?.toString();
        if (gString == 'male') _gender = Gender.male;
        if (gString == 'female') _gender = Gender.female;

        final h = profileData['height'];
        final w = profileData['weight'];

        if (h is num) _heightCm = h.toDouble();
        if (w is num) _weightKg = w.toDouble();

        // These will just stay null if your DB doesn't store them yet
        _mainGoal = profileData['mainGoal']?.toString();
        _activityLevel = profileData['activityLevel']?.toString();
        _avatarPath = profileData['avatarPath']?.toString();
      }

      // 2) Load Workout History
      final dates = await DatabaseHelper.instance.getAllWorkoutDates();
      _workoutDayKeys
        ..clear()
        ..addAll(dates);
    } catch (_) {
      // keep app running even if DB fails
    }

    notifyListeners();
  }

  // ----------------------------
  // Save profile (used by Profile Setup)
  // ----------------------------
  Future<void> saveProfile({
    required String newName,
    required Gender? newGender,
    required double newHeightCm,
    required double newWeightKg,
    String? newMainGoal,
    String? newActivityLevel,
    String? newAvatarPath,
  }) async {
    // Update in-memory state
    _name = newName;
    _gender = newGender;
    _heightCm = newHeightCm;
    _weightKg = newWeightKg;

    if (newMainGoal != null) _mainGoal = newMainGoal;
    if (newActivityLevel != null) _activityLevel = newActivityLevel;
    if (newAvatarPath != null) _avatarPath = newAvatarPath;

    notifyListeners();

    // Persist required fields only (safe if your DB table has only these columns)
    final genderStr = (newGender == null)
        ? null
        : (newGender == Gender.male ? 'male' : 'female');

    await DatabaseHelper.instance.saveProfile({
      'name': newName,
      'gender': genderStr,
      'height': newHeightCm,
      'weight': newWeightKg,
      // If your DB supports these columns, uncomment:
      // 'mainGoal': _mainGoal,
      // 'activityLevel': _activityLevel,
      // 'avatarPath': _avatarPath,
    });
  }

  /// Convenience updater for edit screen (so you don't have to pass everything).
  Future<void> updateProfile({
    String? name,
    Gender? gender,
    double? heightCm,
    double? weightKg,
    String? mainGoal,
    String? activityLevel,
    String? avatarPath,
  }) {
    return saveProfile(
      newName: name ?? _name,
      newGender: gender ?? _gender,
      newHeightCm: heightCm ?? _heightCm,
      newWeightKg: weightKg ?? _weightKg,
      newMainGoal: mainGoal ?? _mainGoal,
      newActivityLevel: activityLevel ?? _activityLevel,
      newAvatarPath: avatarPath ?? _avatarPath,
    );
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

  Future<void> toggleWorkoutDay(DateTime d) async {
    final k = _keyOf(d);
    if (_workoutDayKeys.contains(k)) {
      _workoutDayKeys.remove(k);
      await DatabaseHelper.instance.deleteWorkoutDate(k);
    } else {
      _workoutDayKeys.add(k);
      await DatabaseHelper.instance.insertWorkoutDate(k);
    }
    notifyListeners();
  }

  Future<void> setWorkoutDay(DateTime d, bool done) async {
    final k = _keyOf(d);
    if (done) {
      _workoutDayKeys.add(k);
      await DatabaseHelper.instance.insertWorkoutDate(k);
    } else {
      _workoutDayKeys.remove(k);
      await DatabaseHelper.instance.deleteWorkoutDate(k);
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
    assert(scope != null, 'AppStateScope not found. Wrap MaterialApp with AppStateScope.');
    return scope!.notifier!;
  }
}
