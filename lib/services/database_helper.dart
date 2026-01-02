import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  // Singleton pattern (isa lang dapat ang database instance)
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('corerect.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future<void> _createDB(Database db, int version) async {
    // 1. Table para sa User Profile
    await db.execute('''
      CREATE TABLE profile (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT,
        gender TEXT,
        height REAL,
        weight REAL
      )
    ''');

    // 2. Table para sa Workout History (Dates lang ang kailangan natin ngayon)
    await db.execute('''
      CREATE TABLE history (
        dateKey TEXT PRIMARY KEY
      )
    ''');
  }

  // --- CRUD OPERATIONS ---

  // Save Profile (Update if exists, Insert if not)
  Future<void> saveProfile(Map<String, dynamic> row) async {
    final db = await instance.database;
    // Check if profile exists (id = 1)
    final existing = await db.query('profile', where: 'id = ?', whereArgs: [1]);

    if (existing.isNotEmpty) {
      await db.update('profile', row, where: 'id = ?', whereArgs: [1]);
    } else {
      row['id'] = 1; // Force ID 1 since single user lang tayo
      await db.insert('profile', row);
    }
  }

  // Get Profile
  Future<Map<String, dynamic>?> getProfile() async {
    final db = await instance.database;
    final maps = await db.query('profile', where: 'id = ?', whereArgs: [1]);
    if (maps.isNotEmpty) return maps.first;
    return null;
  }

  // Add Workout Date
  Future<void> insertWorkoutDate(String dateKey) async {
    final db = await instance.database;
    await db.insert(
      'history',
      {'dateKey': dateKey},
      conflictAlgorithm: ConflictAlgorithm.ignore, // Ignore if already saved
    );
  }

  // Remove Workout Date
  Future<void> deleteWorkoutDate(String dateKey) async {
    final db = await instance.database;
    await db.delete('history', where: 'dateKey = ?', whereArgs: [dateKey]);
  }

  // Get All Workout Dates
  Future<List<String>> getAllWorkoutDates() async {
    final db = await instance.database;
    final result = await db.query('history');
    return result.map((json) => json['dateKey'] as String).toList();
  }
}
