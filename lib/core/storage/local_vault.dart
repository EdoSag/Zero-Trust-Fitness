import 'dart:io';
import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:nowa_runtime/nowa_runtime.dart';
import 'package:path_provider/path_provider.dart';

@NowaGenerated()
class LocalVault {
  factory LocalVault() => _instance;

  LocalVault._();

  static final LocalVault _instance = LocalVault._();
  QueryExecutor? _executor;
  String? _activeKeyFingerprint;

  Future<String> _buildKeyFingerprint(SecretKey secretKey) async {
    final keyBytes = await secretKey.extractBytes();
    final digest = await Sha256().hash(keyBytes);
    return base64Url.encode(digest.bytes);
  }

  Future<void> _openWithKey(SecretKey secretKey) async {
    final keyFingerprint = await _buildKeyFingerprint(secretKey);
    if (_executor != null && _activeKeyFingerprint == keyFingerprint) {
      return;
    }

    if (_executor != null && _activeKeyFingerprint != keyFingerprint) {
      await close();
    }

    final keyBytes = await secretKey.extractBytes();
    final dbKeyHex = keyBytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();

    final appDir = await getApplicationDocumentsDirectory();
    final file = File('${appDir.path}/vault.sqlite');

    _executor = NativeDatabase(
      file,
      setup: (database) {
        database.execute("PRAGMA key = \"x'$dbKeyHex'\";");
        database.execute('PRAGMA cipher_memory_security = ON;');
        final cipherVersion = database.select('PRAGMA cipher_version;');
        if (cipherVersion.isEmpty || cipherVersion.first.values.isEmpty) {
          throw StateError(
            'SQLCipher is not active. Refusing to open local vault without encryption.',
          );
        }
        database.execute('PRAGMA foreign_keys = ON;');
        database.execute(
          'CREATE TABLE IF NOT EXISTS workouts ('
          'id INTEGER PRIMARY KEY AUTOINCREMENT,'
          'encrypted_data TEXT NOT NULL,'
          'created_at TEXT NOT NULL'
          ');',
        );
      },
    );
    _activeKeyFingerprint = keyFingerprint;
  }

  Future<void> saveWorkout(String encryptedData, SecretKey secretKey) async {
    await _openWithKey(secretKey);
    await _executor!.runInsert(
      'INSERT INTO workouts (encrypted_data, created_at) VALUES (?, ?)',
      [encryptedData, DateTime.now().toUtc().toIso8601String()],
    );
  }

  Future<List<String>> fetchWorkouts(SecretKey secretKey) async {
    await _openWithKey(secretKey);
    final rows = await _executor!.runSelect(
      'SELECT encrypted_data FROM workouts ORDER BY id DESC',
      const [],
    );
    return rows
        .map((row) => row['encrypted_data'])
        .whereType<String>()
        .toList(growable: false);
  }

  Future<void> close() async {
    await _executor?.close();
    _executor = null;
    _activeKeyFingerprint = null;
  }
}
