import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/call_event.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'fake_call_detector.db');

    return await openDatabase(
      path,
      version: 2,
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('ALTER TABLE call_logs ADD COLUMN is_scam INTEGER DEFAULT 0');
          await db.execute('''
            CREATE TABLE blocked_numbers (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              phone_number TEXT UNIQUE,
              reason TEXT
            )
          ''');
        }
      },
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE call_logs (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            phone_number TEXT,
            event_name TEXT,
            timestamp TEXT,
            threat_score INTEGER,
            reasons TEXT,
            is_scam INTEGER DEFAULT 0
          )
        ''');
        await db.execute('''
          CREATE TABLE trusted_numbers (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            phone_number TEXT UNIQUE
          )
        ''');
        await db.execute('''
          CREATE TABLE blocked_numbers (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            phone_number TEXT UNIQUE,
            reason TEXT
          )
        ''');
      },
    );
  }

  Future<int> insertCallLog(CallEvent event, int score, List<String> reasons) async {
    final db = await database;
    return await db.insert('call_logs', {
      'phone_number': event.phoneNumber,
      'event_name': event.eventName,
      'timestamp': event.timestamp.toIso8601String(),
      'threat_score': score,
      'reasons': reasons.join(', '),
      'is_scam': 0,
    });
  }

  Future<void> updateScamStatus(int id, bool isScam) async {
    final db = await database;
    await db.update(
      'call_logs',
      {'is_scam': isScam ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Map<String, dynamic>>> getCallLogs() async {
    final db = await database;
    return await db.query('call_logs', orderBy: 'timestamp DESC');
  }

  Future<void> addTrustedNumber(String number) async {
    final db = await database;
    await db.insert(
      'trusted_numbers',
      {'phone_number': number},
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<List<String>> getLocalTrustedNumbers() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('trusted_numbers');
    return List.generate(maps.length, (i) => maps[i]['phone_number'] as String);
  }

  Future<void> blockNumber(String number, String reason) async {
    final db = await database;
    await db.insert(
      'blocked_numbers',
      {'phone_number': number, 'reason': reason},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<bool> isNumberBlocked(String number) async {
    final db = await database;
    final maps = await db.query(
      'blocked_numbers',
      where: 'phone_number = ?',
      whereArgs: [number],
    );
    return maps.isNotEmpty;
  }
}
