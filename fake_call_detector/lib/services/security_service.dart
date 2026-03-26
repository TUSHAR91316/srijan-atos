import 'dart:convert';
import 'dart:math';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecurityService {
  SecurityService._();

  static final SecurityService instance = SecurityService._();

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static const _dbKeyName = 'db_encryption_key_v1';
  static const _sessionKey = 'user_session_active';
  static const _userEmailKey = 'logged_in_user_email';

  Future<String> getOrCreateDatabaseKey() async {
    final existing = await _storage.read(key: _dbKeyName);
    if (existing != null && existing.isNotEmpty) {
      return existing;
    }

    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    final generated = base64UrlEncode(bytes);
    await _storage.write(key: _dbKeyName, value: generated);
    return generated;
  }

  Future<void> saveSession(String email) async {
    await _storage.write(key: _sessionKey, value: 'true');
    await _storage.write(key: _userEmailKey, value: email);
  }

  Future<String?> getSessionUser() async {
    final active = await _storage.read(key: _sessionKey);
    if (active == 'true') {
      return await _storage.read(key: _userEmailKey);
    }
    return null;
  }

  Future<void> clearSession() async {
    await _storage.delete(key: _sessionKey);
    await _storage.delete(key: _userEmailKey);
  }
}
