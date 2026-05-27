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
    // Using the aliased import avoids the property/variable confusion.
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
    final dbKeyHex =
        keyBytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();

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
          'metrics_json TEXT NOT NULL,'
          'updated_at TEXT NOT NULL'
          ');',
        );
        database.execute(
          'CREATE TABLE IF NOT EXISTS achievements ('
          'id TEXT PRIMARY KEY,'
          'unlocked_at TEXT NOT NULL,'
          "metadata_json TEXT NOT NULL DEFAULT '{}'"
          ');',
        );
        _migrateLegacyDailyMetrics(database);
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
    await _executor!.runUpdate('DELETE FROM achievements', const []);
  }

  Future<void> insertAchievementIfAbsent(
    String id,
    DateTime unlockedAt,
    SecretKey secretKey,
  ) async {
    await _openWithKey(secretKey);
    await _executor!.runInsert(
      'INSERT OR IGNORE INTO achievements (id, unlocked_at, metadata_json) VALUES (?, ?, ?)',
      [id, unlockedAt.toUtc().toIso8601String(), '{}'],
    );
  }

  Future<List<Map<String, dynamic>>> fetchAchievements(
    SecretKey secretKey,
  ) async {
    await _openWithKey(secretKey);
    final rows = await _executor!.runSelect(
      'SELECT id, unlocked_at FROM achievements',
      const [],
    );
    return rows
        .map((r) => <String, dynamic>{
              'id': r['id'],
              'unlocked_at': r['unlocked_at'],
            })
        .toList(growable: false);
  }

  Future<bool> hasAchievement(String id, SecretKey secretKey) async {
    await _openWithKey(secretKey);
    final rows = await _executor!.runSelect(
      'SELECT 1 FROM achievements WHERE id = ? LIMIT 1',
      [id],
    );
    return rows.isNotEmpty;
  }

  Future<void> upsertDailyMetrics({
    required String dateKey,
    int? steps,
    int? heartPoints,
    Map<String, num>? metrics,
    required SecretKey secretKey,
  }) async {
    await _openWithKey(secretKey);
    final payloadMetrics = _normalizeMetrics(
      metrics ??
          <String, num>{
            'steps': (steps ?? 0),
            'heart_points': (heartPoints ?? 0),
          },
    );
    await _executor!.runInsert(
      'INSERT OR REPLACE INTO daily_metrics (date_key, metrics_json, updated_at)'
      ' VALUES (?, ?, ?)',
      [
        dateKey,
        jsonEncode(payloadMetrics),
        DateTime.now().toUtc().toIso8601String(),
      ],
    );
  }

  Future<List<Map<String, dynamic>>> fetchDailyMetrics(
      SecretKey secretKey) async {
    await _openWithKey(secretKey);
    final rows = await _executor!.runSelect(
      'SELECT date_key, metrics_json, updated_at '
      'FROM daily_metrics ORDER BY date_key DESC',
      const [],
    );
    return rows.map((row) {
      final decoded = _parseMetricsJson(row['metrics_json']?.toString());
      return <String, dynamic>{
        'date_key': row['date_key'],
        'metrics': decoded,
        // Backward-compatible aliases still used in chart/sync paths.
        'steps': _metricAsInt(decoded, 'steps'),
        'heart_points': _metricAsInt(decoded, 'heart_points'),
        'updated_at': row['updated_at'],
      };
    }).toList(growable: false);
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
      final normalizedMetrics = _metricsFromIncoming(metric);
      final updatedAt = metric['updated_at']?.toString() ??
          DateTime.now().toUtc().toIso8601String();
      await _executor!.runInsert(
        'INSERT OR REPLACE INTO daily_metrics (date_key, metrics_json, updated_at)'
        ' VALUES (?, ?, ?)',
        [dateKey, jsonEncode(normalizedMetrics), updatedAt],
      );
    }
  }

  void _migrateLegacyDailyMetrics(dynamic database) {
    final tableInfo = database.select("PRAGMA table_info('daily_metrics');");
    if (tableInfo.isEmpty) {
      return;
    }

    final hasMetricsJson =
        tableInfo.any((row) => row['name'] == 'metrics_json');
    if (hasMetricsJson) {
      return;
    }

    database
        .execute('ALTER TABLE daily_metrics RENAME TO daily_metrics_legacy;');
    database.execute(
      'CREATE TABLE IF NOT EXISTS daily_metrics ('
      'date_key TEXT PRIMARY KEY,'
      'metrics_json TEXT NOT NULL,'
      'updated_at TEXT NOT NULL'
      ');',
    );

    final legacyRows = database.select(
      'SELECT date_key, steps, heart_points, updated_at FROM daily_metrics_legacy',
    );
    for (final row in legacyRows) {
      final metrics = _normalizeMetrics(<String, num>{
        'steps': (row['steps'] as num?) ?? 0,
        'heart_points': (row['heart_points'] as num?) ?? 0,
      });
      database.execute(
        'INSERT OR REPLACE INTO daily_metrics (date_key, metrics_json, updated_at)'
        " VALUES (?, ?, ?)",
        [
          row['date_key'],
          jsonEncode(metrics),
          row['updated_at']?.toString() ??
              DateTime.now().toUtc().toIso8601String(),
        ],
      );
    }
    database.execute('DROP TABLE daily_metrics_legacy;');
  }

  Map<String, num> _metricsFromIncoming(Map<String, dynamic> row) {
    final rawMetrics = row['metrics'];
    if (rawMetrics is Map) {
      final converted = <String, num>{};
      rawMetrics.forEach((key, value) {
        final parsed = _parseNum(value);
        if (parsed != null) {
          converted[key.toString()] = parsed;
        }
      });
      if (converted.isNotEmpty) {
        return _normalizeMetrics(converted);
      }
    }

    // Legacy payload compatibility.
    return _normalizeMetrics(<String, num>{
      'steps': (row['steps'] as num?) ?? 0,
      'heart_points': (row['heart_points'] as num?) ?? 0,
    });
  }

  Map<String, num> _parseMetricsJson(String? raw) {
    if (raw == null || raw.isEmpty) return const <String, num>{};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return const <String, num>{};
      final metrics = <String, num>{};
      decoded.forEach((key, value) {
        final parsed = _parseNum(value);
        if (parsed != null) {
          metrics[key.toString()] = parsed;
        }
      });
      return metrics;
    } catch (_) {
      return const <String, num>{};
    }
  }

  num? _parseNum(dynamic value) {
    if (value is num) return value;
    if (value is String) return num.tryParse(value);
    return null;
  }

  Map<String, num> _normalizeMetrics(Map<String, num> metrics) {
    final normalized = <String, num>{};
    metrics.forEach((key, value) {
      if (!value.isFinite) return;
      final rounded = value;
      final intValue = rounded.toInt();
      if (rounded == intValue) {
        normalized[key] = intValue;
      } else {
        normalized[key] = rounded.toDouble();
      }
    });
    return normalized;
  }

  int _metricAsInt(Map<String, num> metrics, String key) {
    final value = metrics[key];
    if (value == null) return 0;
    return value.toInt();
  }

  Future<void> mergeDailyMetrics({
    required String dateKey,
    required Map<String, num> incoming,
    required SecretKey secretKey,
  }) async {
    await _openWithKey(secretKey);

    final rows = await _executor!.runSelect(
      'SELECT metrics_json FROM daily_metrics WHERE date_key = ?',
      [dateKey],
    );
    final existing = rows.isEmpty
        ? <String, num>{}
        : _parseMetricsJson(rows.first['metrics_json']?.toString());

    const additiveKeys = {
      'steps',
      'heart_points',
      'sleep_asleep_min',
      'sleep_light_min',
      'sleep_deep_min',
      'sleep_rem_min',
      'water_l',
      'nutrition_entries',
    };

    final merged = Map<String, num>.from(existing);
    for (final entry in incoming.entries) {
      if (additiveKeys.contains(entry.key)) {
        merged[entry.key] = (merged[entry.key] ?? 0) + entry.value;
      } else if (entry.value != 0) {
        merged[entry.key] = entry.value;
      }
    }

    final normalized = _normalizeMetrics(merged);
    await _executor!.runInsert(
      'INSERT OR REPLACE INTO daily_metrics (date_key, metrics_json, updated_at)'
      ' VALUES (?, ?, ?)',
      [
        dateKey,
        jsonEncode(normalized),
        DateTime.now().toUtc().toIso8601String(),
      ],
    );
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
  int get schemaVersion => 2;

  @override
  Future<void> beforeOpen(
      QueryExecutor executor, OpeningDetails details) async {}
}
