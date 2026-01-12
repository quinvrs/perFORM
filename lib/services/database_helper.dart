import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
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
    // 1. Profile Table
    await db.execute('''
      CREATE TABLE profile (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT,
        gender TEXT,
        height REAL,
        weight REAL
      )
    ''');

    // 2. History Table (Updated with metrics)
    await db.execute('''
      CREATE TABLE history (
        dateKey TEXT PRIMARY KEY,
        type TEXT,
        reps INTEGER,
        sets INTEGER,
        duration TEXT,
        formScore REAL
      )
    ''');
  }

  // --- CRUD OPERATIONS ---

  Future<void> saveProfile(Map<String, dynamic> row) async {
    final db = await instance.database;
    final existing = await db.query('profile', where: 'id = ?', whereArgs: [1]);

    if (existing.isNotEmpty) {
      await db.update('profile', row, where: 'id = ?', whereArgs: [1]);
    } else {
      row['id'] = 1;
      await db.insert('profile', row);
    }
  }

  Future<Map<String, dynamic>?> getProfile() async {
    final db = await instance.database;
    final maps = await db.query('profile', where: 'id = ?', whereArgs: [1]);
    if (maps.isNotEmpty) return maps.first;
    return null;
  }

  // Insert with ALL Metrics
  Future<void> insertWorkout({
    required String dateKey,
    required String type,
    required int reps,
    required int sets,
    required String duration,
    required double formScore,
  }) async {
    final db = await instance.database;
    await db.insert('history', {
      'dateKey': dateKey,
      'type': type,
      'reps': reps,
      'sets': sets,
      'duration': duration,
      'formScore': formScore,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  // Delete specific entry
  Future<void> deleteWorkout(String dateKey) async {
    final db = await instance.database;
    await db.delete('history', where: 'dateKey = ?', whereArgs: [dateKey]);
  }

  // Get All
  Future<List<Map<String, dynamic>>> getAllWorkouts() async {
    final db = await instance.database;
    return await db.query('history');
  }

  Future<void> clearHistory() async {
    final db = await instance.database;
    await db.delete('history'); // Deletes all rows in the history table
  }
  
  Future<void> deleteEverything() async {
    final db = await instance.database;
    // Transaction ensures both delete or neither does (safety)
    await db.transaction((txn) async {
      await txn.delete('profile');
      await txn.delete('history');
    });
  }
}
