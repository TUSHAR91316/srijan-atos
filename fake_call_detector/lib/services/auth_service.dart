import 'dart:convert';
import 'dart:math';
import 'package:collection/collection.dart';
import 'package:cryptography/cryptography.dart';
import 'database_service.dart';

class AuthResult {
  const AuthResult({required this.success, required this.message});

  final bool success;
  final String message;
}

class AuthService {
  AuthService({DatabaseService? databaseService})
      : _databaseService = databaseService ?? DatabaseService();

  final DatabaseService _databaseService;

  static const int _pbkdf2Iterations = 120000;
  static const int _maxAttempts = 5;
  static const Duration _lockDuration = Duration(minutes: 5);

  Future<AuthResult> register(String email, String password) async {
    final existing = await _databaseService.getUser(email);
    if (existing != null) {
      return const AuthResult(success: false, message: 'User already exists');
    }

    final salt = _randomBytes(16);
    final hash = await _deriveHash(password, salt, _pbkdf2Iterations);

    await _databaseService.registerUser(
      email,
      base64Encode(hash),
      base64Encode(salt),
      _pbkdf2Iterations,
    );

    return const AuthResult(success: true, message: 'Registration successful');
  }

  Future<AuthResult> login(String email, String password) async {
    final user = await _databaseService.getUser(email);
    if (user == null) {
      return const AuthResult(success: false, message: 'Invalid email or password');
    }

    final nowEpoch = DateTime.now().millisecondsSinceEpoch;
    final lockUntil = user['lock_until'] as int?;
    if (lockUntil != null && lockUntil > nowEpoch) {
      final remainingSeconds = ((lockUntil - nowEpoch) / 1000).ceil();
      return AuthResult(
        success: false,
        message: 'Too many attempts. Try again in ${remainingSeconds}s',
      );
    }

    final storedHash = user['password_hash'] as String?;
    final storedSalt = user['salt'] as String?;
    final iterations = (user['iterations'] as int?) ?? _pbkdf2Iterations;

    var isValid = false;

    if (storedHash != null && storedSalt != null) {
      final computed = await _deriveHash(
        password,
        base64Decode(storedSalt),
        iterations,
      );
      isValid = const ListEquality<int>().equals(computed, base64Decode(storedHash));
    } else {
      final legacyPassword = user['password'] as String?;
      if (legacyPassword != null && legacyPassword == password) {
        isValid = true;

        final salt = _randomBytes(16);
        final hash = await _deriveHash(password, salt, _pbkdf2Iterations);
        await _databaseService.setUserSecurity(
          user['id'] as int,
          base64Encode(hash),
          base64Encode(salt),
          _pbkdf2Iterations,
        );
      }
    }

    if (isValid) {
      await _databaseService.updateLoginProtection(email, 0, null);
      return const AuthResult(success: true, message: 'Login successful');
    }

    final failedAttempts = ((user['failed_attempts'] as int?) ?? 0) + 1;
    final shouldLock = failedAttempts >= _maxAttempts;
    final lockEpoch = shouldLock
        ? DateTime.now().add(_lockDuration).millisecondsSinceEpoch
        : null;

    await _databaseService.updateLoginProtection(
      email,
      shouldLock ? 0 : failedAttempts,
      lockEpoch,
    );

    if (shouldLock) {
      return const AuthResult(
        success: false,
        message: 'Too many attempts. Account is temporarily locked',
      );
    }

    return const AuthResult(success: false, message: 'Invalid email or password');
  }

  Future<List<int>> _deriveHash(String password, List<int> salt, int iterations) async {
    final key = await Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: iterations,
      bits: 256,
    ).deriveKey(
      secretKey: SecretKey(utf8.encode(password)),
      nonce: salt,
    );
    return key.extractBytes();
  }

  List<int> _randomBytes(int length) {
    final random = Random.secure();
    return List<int>.generate(length, (_) => random.nextInt(256));
  }
}
