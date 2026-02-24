import 'dart:io';
import 'dart:convert';
import 'package:sqlcipher_flutter_libs/sqlcipher_flutter_libs.dart';
import 'package:cryptography/cryptography.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:nowa_runtime/nowa_runtime.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/open.dart' as sqlite_open;

@NowaGenerated()
class LocalVault {
  factory LocalVault() => _instance;

  LocalVault._();

  static final LocalVault _instance = LocalVault._();
  static const _vaultExecutorUser = _VaultExecutorUser();
  QueryExecutor? _executor;
  String? _activeKeyFingerprint;

  Future<String> _buildKeyFingerprint(SecretKey secretKey) async {
    final keyBytes = await secretKey.extractBytes();
    final digest = await Sha256().hash(keyBytes);
    return base64Url.encode(digest.bytes);
  }

void setupSqlCipher() {
  // Using the aliased import avoids the property/variable confusion
  sqlite_open.open.overrideFor(
    sqlite_open.OperatingSystem.android, 
    openCipherOnAndroid,
  );
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
        database.execute(
          'CREATE TABLE IF NOT EXISTS daily_metrics ('
          'date_key TEXT PRIMARY KEY,'
          'steps INTEGER NOT NULL,'
          'heart_points INTEGER NOT NULL,'
          'updated_at TEXT NOT NULL'
          ');',
        );
      },
    );
    await _executor!.ensureOpen(_vaultExecutorUser);
    _activeKeyFingerprint = keyFingerprint;
  }

  Future<void> open(SecretKey secretKey) async {
    // We simply call your existing robust private method
    await _openWithKey(secretKey);
    print("Zero-Trust Vault: Connection decrypted and open.");
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

  Future<void> replaceWorkouts(
    List<String> encryptedRows,
    SecretKey secretKey,
  ) async {
    await _openWithKey(secretKey);
    await _executor!.runUpdate('DELETE FROM workouts', const []);

    final insertedAt = DateTime.now().toUtc().toIso8601String();
    for (final row in encryptedRows) {
      await _executor!.runInsert(
        'INSERT INTO workouts (encrypted_data, created_at) VALUES (?, ?)',
        [row, insertedAt],
      );
    }
  }

  Future<void> clearWorkouts(SecretKey secretKey) async {
    await _openWithKey(secretKey);
    await _executor!.runUpdate('DELETE FROM workouts', const []);
    await _executor!.runUpdate('DELETE FROM daily_metrics', const []);
  }

  Future<void> upsertDailyMetrics({
    required String dateKey,
    required int steps,
    required int heartPoints,
    required SecretKey secretKey,
  }) async {
    await _openWithKey(secretKey);
    await _executor!.runInsert(
      'INSERT OR REPLACE INTO daily_metrics (date_key, steps, heart_points, updated_at)'
      ' VALUES (?, ?, ?, ?)',
      [dateKey, steps, heartPoints, DateTime.now().toUtc().toIso8601String()],
    );
  }

  Future<List<Map<String, dynamic>>> fetchDailyMetrics(SecretKey secretKey) async {
    await _openWithKey(secretKey);
    final rows = await _executor!.runSelect(
      'SELECT date_key, steps, heart_points, updated_at '
      'FROM daily_metrics ORDER BY date_key DESC',
      const [],
    );
    return rows
        .map((row) => {
              'date_key': row['date_key'],
              'steps': row['steps'],
              'heart_points': row['heart_points'],
              'updated_at': row['updated_at'],
            })
        .toList(growable: false);
  }

  Future<void> replaceDailyMetrics(
    List<Map<String, dynamic>> metrics,
    SecretKey secretKey,
  ) async {
    await _openWithKey(secretKey);
    await _executor!.runUpdate('DELETE FROM daily_metrics', const []);
    for (final metric in metrics) {
      final dateKey = metric['date_key']?.toString();
      if (dateKey == null || dateKey.isEmpty) continue;
      final steps = (metric['steps'] as num?)?.toInt() ?? 0;
      final heartPoints = (metric['heart_points'] as num?)?.toInt() ?? 0;
      final updatedAt = metric['updated_at']?.toString() ??
          DateTime.now().toUtc().toIso8601String();
      await _executor!.runInsert(
        'INSERT OR REPLACE INTO daily_metrics (date_key, steps, heart_points, updated_at)'
        ' VALUES (?, ?, ?, ?)',
        [dateKey, steps, heartPoints, updatedAt],
      );
    }
  }

  Future<void> close() async {
    await _executor?.close();
    _executor = null;
    _activeKeyFingerprint = null;
  }
}

class _VaultExecutorUser implements QueryExecutorUser {
  const _VaultExecutorUser();

  @override
  int get schemaVersion => 1;

  @override
  Future<void> beforeOpen(QueryExecutor executor, OpeningDetails details) async {}
}
