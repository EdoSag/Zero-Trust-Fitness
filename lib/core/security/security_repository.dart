import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:nowa_runtime/nowa_runtime.dart';

@NowaGenerated()
class SecurityRepository {
  SecurityRepository._();

  factory SecurityRepository() => _instance;

  static final SecurityRepository _instance = SecurityRepository._();
  final FlutterSecureStorage _storage = FlutterSecureStorage();

  static const String _saltKey = 'vault_pbkdf2_salt';

  Future<List<int>> getOrCreateSalt() async {
    final existing = await _storage.read(key: _saltKey);
    if (existing != null && existing.isNotEmpty) {
      return base64Url.decode(existing);
    }

    final random = Random.secure();
    final salt = List<int>.generate(16, (_) => random.nextInt(256));
    await _storage.write(key: _saltKey, value: base64Url.encode(salt));
    return salt;
  }
}
