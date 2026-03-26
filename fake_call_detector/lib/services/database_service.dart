import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:path/path.dart';
import 'dart:convert';
import '../models/call_event.dart';
import 'security_service.dart';

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
    final dbKey = await SecurityService.instance.getOrCreateDatabaseKey();

    return await openDatabase(
      path,
      version: 6,
      password: dbKey,
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
        if (oldVersion < 3) {
          await db.execute('''
            CREATE TABLE users (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              email TEXT UNIQUE,
              password TEXT
            )
          ''');
        }
        if (oldVersion < 4) {
          await db.execute('ALTER TABLE users ADD COLUMN password_hash TEXT');
          await db.execute('ALTER TABLE users ADD COLUMN salt TEXT');
          await db.execute('ALTER TABLE users ADD COLUMN iterations INTEGER DEFAULT 120000');
          await db.execute('ALTER TABLE users ADD COLUMN created_at TEXT');
          await db.execute('ALTER TABLE users ADD COLUMN failed_attempts INTEGER DEFAULT 0');
          await db.execute('ALTER TABLE users ADD COLUMN lock_until INTEGER');
        }
        if (oldVersion < 5) {
          await db.execute('ALTER TABLE call_logs ADD COLUMN risk_probability REAL DEFAULT 0');
          await db.execute('ALTER TABLE call_logs ADD COLUMN risk_reasons_json TEXT');
          await db.execute('ALTER TABLE call_logs ADD COLUMN signal_breakdown_json TEXT');
          await db.execute('ALTER TABLE call_logs ADD COLUMN voice_similarity REAL');
          await db.execute('ALTER TABLE call_logs ADD COLUMN duration_seconds INTEGER');
          await db.execute('''
            CREATE TABLE IF NOT EXISTS voice_embeddings (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              phone_number TEXT UNIQUE,
              embedding TEXT,
              updated_at TEXT
            )
          ''');
        }
        if (oldVersion < 6) {
          await db.execute('''
            CREATE TABLE IF NOT EXISTS voice_embedding_samples (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              phone_number TEXT,
              embedding_json TEXT,
              quality REAL,
              created_at TEXT
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
            is_scam INTEGER DEFAULT 0,
            risk_probability REAL DEFAULT 0,
            risk_reasons_json TEXT,
            signal_breakdown_json TEXT,
            voice_similarity REAL,
            duration_seconds INTEGER
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
        await db.execute('''
          CREATE TABLE users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            email TEXT UNIQUE,
            password TEXT,
            password_hash TEXT,
            salt TEXT,
            iterations INTEGER DEFAULT 120000,
            created_at TEXT,
            failed_attempts INTEGER DEFAULT 0,
            lock_until INTEGER
          )
        ''');
        await db.execute('''
          CREATE TABLE voice_embeddings (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            phone_number TEXT UNIQUE,
            embedding TEXT,
            updated_at TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE voice_embedding_samples (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            phone_number TEXT,
            embedding_json TEXT,
            quality REAL,
            created_at TEXT
          )
        ''');
      },
    );
  }

  // --- User Auth Methods ---
  Future<int> registerUser(
    String email,
    String passwordHash,
    String salt,
    int iterations,
  ) async {
    final db = await database;
    return await db.insert('users', {
      'email': email,
      'password_hash': passwordHash,
      'salt': salt,
      'iterations': iterations,
      'created_at': DateTime.now().toIso8601String(),
      'failed_attempts': 0,
      'lock_until': null,
    });
  }

  Future<Map<String, dynamic>?> getUser(String email) async {
    final db = await database;
    final results = await db.query(
      'users',
      where: 'email = ?',
      whereArgs: [email],
    );
    return results.isNotEmpty ? results.first : null;
  }

  Future<void> setUserSecurity(
    int id,
    String passwordHash,
    String salt,
    int iterations,
  ) async {
    final db = await database;
    await db.update(
      'users',
      {
        'password_hash': passwordHash,
        'salt': salt,
        'iterations': iterations,
        'password': null,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> updateLoginProtection(String email, int failedAttempts, int? lockUntilEpochMs) async {
    final db = await database;
    await db.update(
      'users',
      {
        'failed_attempts': failedAttempts,
        'lock_until': lockUntilEpochMs,
      },
      where: 'email = ?',
      whereArgs: [email],
    );
  }

  // --- Existing Methods ---
  Future<int> insertCallLog(CallEvent event, int score, List<String> reasons) async {
    final db = await database;
    return await db.insert('call_logs', {
      'phone_number': event.phoneNumber,
      'event_name': event.eventName,
      'timestamp': event.timestamp.toIso8601String(),
      'threat_score': score,
      'reasons': reasons.join(', '),
      'is_scam': 0,
      'risk_probability': score / 100,
      'risk_reasons_json': null,
      'signal_breakdown_json': null,
      'voice_similarity': null,
      'duration_seconds': null,
    });
  }

  Future<int> insertRiskLog({
    required CallEvent event,
    required int score,
    required double probability,
    required String reasons,
    required String signalBreakdown,
    required double? voiceSimilarity,
    required int? durationSeconds,
  }) async {
    final db = await database;
    return await db.insert('call_logs', {
      'phone_number': event.phoneNumber,
      'event_name': event.eventName,
      'timestamp': event.timestamp.toIso8601String(),
      'threat_score': score,
      'reasons': reasons,
      'is_scam': 0,
      'risk_probability': probability,
      'risk_reasons_json': reasons,
      'signal_breakdown_json': signalBreakdown,
      'voice_similarity': voiceSimilarity,
      'duration_seconds': durationSeconds,
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

  Future<void> upsertVoiceEmbedding(String phoneNumber, String embedding) async {
    final db = await database;
    await db.insert(
      'voice_embeddings',
      {
        'phone_number': phoneNumber,
        'embedding': embedding,
        'updated_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<String?> getVoiceEmbedding(String phoneNumber) async {
    final db = await database;
    final rows = await db.query(
      'voice_embeddings',
      columns: ['embedding'],
      where: 'phone_number = ?',
      whereArgs: [phoneNumber],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['embedding'] as String?;
  }

  Future<void> addVoiceEmbeddingSample(
    String phoneNumber,
    List<double> embedding,
    double quality, {
    int maxSamples = 8,
  }) async {
    final db = await database;
    await db.insert(
      'voice_embedding_samples',
      {
        'phone_number': phoneNumber,
        'embedding_json': jsonEncode(embedding),
        'quality': quality,
        'created_at': DateTime.now().toIso8601String(),
      },
    );

    final rows = await db.query(
      'voice_embedding_samples',
      columns: ['id'],
      where: 'phone_number = ?',
      whereArgs: [phoneNumber],
      orderBy: 'quality DESC, created_at DESC',
    );

    if (rows.length > maxSamples) {
      final toDelete = rows.skip(maxSamples).map((row) => row['id']).toList(growable: false);
      if (toDelete.isNotEmpty) {
        final placeholders = List.filled(toDelete.length, '?').join(',');
        await db.rawDelete(
          'DELETE FROM voice_embedding_samples WHERE id IN ($placeholders)',
          toDelete,
        );
      }
    }
  }

  Future<List<List<double>>> getVoiceEmbeddingSamples(String phoneNumber) async {
    final db = await database;
    final rows = await db.query(
      'voice_embedding_samples',
      columns: ['embedding_json'],
      where: 'phone_number = ?',
      whereArgs: [phoneNumber],
      orderBy: 'quality DESC, created_at DESC',
    );

    return rows
        .map((row) => row['embedding_json'])
        .whereType<String>()
        .map((jsonStr) {
          final decoded = jsonDecode(jsonStr);
          if (decoded is! List) return <double>[];
          return decoded
              .map((e) => e is num ? e.toDouble() : double.tryParse(e.toString()) ?? 0.0)
              .toList(growable: false);
        })
        .where((e) => e.isNotEmpty)
        .toList(growable: false);
  }

  Future<int> getRecentCallCount(String phoneNumber, Duration window) async {
    final db = await database;
    final since = DateTime.now().subtract(window).toIso8601String();
    final result = await db.rawQuery(
      'SELECT COUNT(*) AS cnt FROM call_logs WHERE phone_number = ? AND timestamp >= ?',
      [phoneNumber, since],
    );
    return (result.first['cnt'] as int?) ?? 0;
  }

  Future<List<Map<String, dynamic>>> getRecentCallsForNumber(String phoneNumber, int limit) async {
    final db = await database;
    return db.query(
      'call_logs',
      where: 'phone_number = ?',
      whereArgs: [phoneNumber],
      orderBy: 'timestamp DESC',
      limit: limit,
    );
  }
}
