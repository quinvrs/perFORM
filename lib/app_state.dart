import 'package:flutter/material.dart';
import 'services/database_helper.dart';

enum Gender { male, female }

class WorkoutRecord {
  final String dateKey;
  final String type;
  final int reps;
  final int sets;
  final String duration;
  final double formScore;

  WorkoutRecord({
    required this.dateKey,
    required this.type,
    required this.reps,
    required this.sets,
    required this.duration,
    required this.formScore,
  });

  DateTime get dateTime => DateTime.parse(dateKey);
}

class AppState extends ChangeNotifier {
  bool _isLoading = true;

  // Profile Data
  String _name = '';
  Gender? _gender;
  double _heightCm = 180;
  double _weightKg = 80;

  String? _avatarPath;
  String? _mainGoal;
  String? _activityLevel;

  // Workouts History
  final List<WorkoutRecord> _workoutRecords = [];

  AppState() {
    _loadData();
  }

  // Getters
  bool get isLoading => _isLoading;
  bool get hasProfile => _name.isNotEmpty;

  String get name => _name;
  Gender? get gender => _gender;
  double get heightCm => _heightCm;
  double get weightKg => _weightKg;
  String? get avatarPath => _avatarPath;
  String? get mainGoal => _mainGoal;
  String? get activityLevel => _activityLevel;

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

  Future<void> _loadData() async {
    try {
      // 1. Load Profile
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

        _mainGoal = profileData['mainGoal']?.toString();
        _activityLevel = profileData['activityLevel']?.toString();
        _avatarPath = profileData['avatarPath']?.toString();
      }

      // 2. Load History
      final data = await DatabaseHelper.instance.getAllWorkouts();
      _workoutRecords.clear();
      for (final row in data) {
        _workoutRecords.add(
          WorkoutRecord(
            dateKey: row['dateKey'] as String,
            type: (row['type'] ?? 'Workout').toString(),
            reps: (row['reps'] as num?)?.toInt() ?? 0,
            sets: (row['sets'] as num?)?.toInt() ?? 0,
            duration: (row['duration'] ?? '0m').toString(),
            formScore: (row['formScore'] as num?)?.toDouble() ?? 0.0,
          ),
        );
      }
    } catch (_) {
      // Error handling
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ----------------------------
  // Profile Saving
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
    _name = newName;
    _gender = newGender;
    _heightCm = newHeightCm;
    _weightKg = newWeightKg;

    if (newMainGoal != null) _mainGoal = newMainGoal;
    if (newActivityLevel != null) _activityLevel = newActivityLevel;
    if (newAvatarPath != null) _avatarPath = newAvatarPath;

    notifyListeners();

    final genderStr = (newGender == null)
        ? null
        : (newGender == Gender.male ? 'male' : 'female');

    // ✅ FIX: Included mainGoal, activityLevel, and avatarPath in the DB update
    await DatabaseHelper.instance.saveProfile({
      'name': newName,
      'gender': genderStr,
      'height': newHeightCm,
      'weight': newWeightKg,
      'mainGoal': _mainGoal,
      'activityLevel': _activityLevel,
      'avatarPath': _avatarPath,
    });
  }

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

  // --- WORKOUT LOGIC (Unchanged) ---

  String _datePart(DateTime d) {
    return d.toIso8601String().substring(0, 10);
  }

  bool isWorkoutDay(DateTime d) {
    final target = _datePart(d);
    return _workoutRecords.any((r) => r.dateKey.startsWith(target));
  }

  List<WorkoutRecord> get historyRecordsSorted {
    final list = List<WorkoutRecord>.from(_workoutRecords);
    list.sort((a, b) => b.dateKey.compareTo(a.dateKey));
    return list;
  }

  Future<void> toggleWorkoutDay(DateTime d) async {
    if (isWorkoutDay(d)) {
      await setWorkoutDay(d, false);
    } else {
      await setWorkoutDay(
        d,
        true,
        type: 'Manual',
        reps: 0,
        sets: 0,
        duration: '0m',
        formScore: 0.0,
      );
    }
  }

  List<String> get workoutDayKeys {
    final set = <String>{};
    for (final r in _workoutRecords) {
      final k = r.dateKey;
      if (k.length >= 10) set.add(k.substring(0, 10));
    }
    final list = set.toList();
    list.sort();
    return list;
  }

  Future<void> setWorkoutDay(
    DateTime d,
    bool done, {
    String type = 'Workout',
    int reps = 0,
    int sets = 0,
    String duration = '0m',
    double formScore = 0.0,
  }) async {
    if (done) {
      final timestamp = d.toIso8601String();
      final newRecord = WorkoutRecord(
        dateKey: timestamp,
        type: type,
        reps: reps,
        sets: sets,
        duration: duration,
        formScore: formScore,
      );

      _workoutRecords.add(newRecord);
      await DatabaseHelper.instance.insertWorkout(
        dateKey: timestamp,
        type: type,
        reps: reps,
        sets: sets,
        duration: duration,
        formScore: formScore,
      );
    } else {
      final target = _datePart(d);
      final toRemove = _workoutRecords
          .where((r) => r.dateKey.startsWith(target))
          .toList();

      for (final r in toRemove) {
        _workoutRecords.remove(r);
        await DatabaseHelper.instance.deleteWorkout(r.dateKey);
      }
    }
    notifyListeners();
  }

  int weeklySessions() {
    final now = DateTime.now();
    final dist = now.weekday % 7;
    final startOfWeek = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: dist));
    final endOfWeek = startOfWeek.add(const Duration(days: 7));

    int count = 0;
    for (final r in _workoutRecords) {
      final d = r.dateTime;
      if (d.isAfter(startOfWeek.subtract(const Duration(seconds: 1))) &&
          d.isBefore(endOfWeek)) {
        count++;
      }
    }
    return count;
  }

  int get currentStreak {
    final uniqueDays = <String>{};
    for (final r in _workoutRecords) {
      final k = r.dateKey;
      if (k.length >= 10) uniqueDays.add(k.substring(0, 10));
    }

    final now = DateTime.now();
    var checkDate = DateTime(now.year, now.month, now.day);
    var key = _datePart(checkDate);

    if (!uniqueDays.contains(key)) {
      checkDate = checkDate.subtract(const Duration(days: 1));
      key = _datePart(checkDate);
      if (!uniqueDays.contains(key)) return 0;
    }

    var streak = 0;
    while (uniqueDays.contains(key)) {
      streak++;
      checkDate = checkDate.subtract(const Duration(days: 1));
      key = _datePart(checkDate);
    }
    return streak;
  }

  Future<void> clearAllWorkouts() async {
    _workoutRecords.clear();
    await DatabaseHelper.instance.clearHistory();
    notifyListeners();
  }

  Future<void> deleteProfile() async {
    await DatabaseHelper.instance.deleteEverything();
    _name = '';
    _gender = null;
    _heightCm = 180;
    _weightKg = 80;
    _avatarPath = null;
    _mainGoal = null;
    _activityLevel = null;
    _workoutRecords.clear();
    notifyListeners();
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
