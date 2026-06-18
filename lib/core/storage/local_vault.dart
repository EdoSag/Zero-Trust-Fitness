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

  // Metrics that accumulate across sources (HC total + manual additions).
  static const _sumAdditiveKeys = <String>{
    'steps', 'heart_points', 'water_l', 'nutrition_entries',
  };

  // Sleep metrics: per-night, so we take max(HC, manual) to avoid double-count.
  static const _sleepKeys = <String>{
    'sleep_asleep_min', 'sleep_light_min', 'sleep_deep_min', 'sleep_rem_min',
  };

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
        database.execute(
          'CREATE TABLE IF NOT EXISTS user_goals ('
          'metric_key TEXT PRIMARY KEY,'
          'target_value REAL NOT NULL,'
          'period TEXT NOT NULL,'
          'updated_at TEXT NOT NULL'
          ');',
        );
        database.execute(
          'CREATE TABLE IF NOT EXISTS backup_history ('
          'id INTEGER PRIMARY KEY AUTOINCREMENT,'
          'backup_type TEXT NOT NULL,'
          'status TEXT NOT NULL,'
          'created_at TEXT NOT NULL,'
          'details TEXT'
          ');',
        );
        database.execute(
          'CREATE TABLE IF NOT EXISTS workout_templates ('
          'id INTEGER PRIMARY KEY AUTOINCREMENT,'
          'name TEXT NOT NULL,'
          'activity_type TEXT NOT NULL,'
          'encrypted_data TEXT NOT NULL,'
          'created_at TEXT NOT NULL'
          ');',
        );
        database.execute(
          'CREATE TABLE IF NOT EXISTS access_log ('
          'id INTEGER PRIMARY KEY AUTOINCREMENT,'
          'accessed_at TEXT NOT NULL'
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

  /// Merges manually-entered values into a daily_metrics row.
  /// Uses shadow keys (`_hc` / `_manual`) so that a subsequent
  /// [syncFromHealthConnect] call can preserve manual additions.
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

    final merged = Map<String, num>.from(existing);

    for (final entry in incoming.entries) {
      final key = entry.key;
      final value = entry.value;
      if (key.endsWith('_hc') || key.endsWith('_manual')) continue;

      if (_sumAdditiveKeys.contains(key)) {
        // Migration: if no shadow key yet, treat existing display value as HC base.
        final hcBase = existing.containsKey('${key}_hc')
            ? existing['${key}_hc'] ?? 0
            : existing[key] ?? 0;
        final prevManual = existing['${key}_manual'] ?? 0;
        merged['${key}_hc'] = hcBase;
        merged['${key}_manual'] = prevManual + value;
        merged[key] = hcBase + prevManual + value;
      } else if (_sleepKeys.contains(key)) {
        // Sleep is per-night: manual override replaces previous manual entry.
        final hcBase = existing.containsKey('${key}_hc')
            ? existing['${key}_hc'] ?? 0
            : existing[key] ?? 0;
        merged['${key}_hc'] = hcBase;
        merged['${key}_manual'] = value;
        // Display: take the larger value to avoid double-counting.
        merged[key] = hcBase >= value ? hcBase : value;
      } else {
        // Vitals / body: latest manual reading wins; HC reading takes priority
        // if available.
        if (value != 0) {
          merged['${key}_manual'] = value;
          final hcVal = existing['${key}_hc'] ?? 0;
          merged[key] = hcVal != 0 ? hcVal : value;
        }
      }
    }

    final normalized = _normalizeMetrics(merged);
    await _executor!.runInsert(
      'INSERT OR REPLACE INTO daily_metrics (date_key, metrics_json, updated_at)'
      ' VALUES (?, ?, ?)',
      [dateKey, jsonEncode(normalized), DateTime.now().toUtc().toIso8601String()],
    );
  }

  /// Syncs Health Connect data into the vault while preserving manual entries.
  ///
  /// For each metric key the vault stores three values:
  ///   `{key}`         – displayed combined value
  ///   `{key}_hc`      – last value reported by Health Connect
  ///   `{key}_manual`  – manually-entered contribution (never touched by HC)
  ///
  /// [manualContributions] lets the caller override specific manual values
  /// (e.g. after deduplicating heart points against HC workout timestamps).
  Future<void> syncFromHealthConnect({
    required String dateKey,
    required Map<String, num> hcMetrics,
    Map<String, num> manualContributions = const {},
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

    final merged = Map<String, num>.from(existing);

    // Sum-additive: display = HC + manual (manual offset never erased by HC).
    for (final key in _sumAdditiveKeys) {
      final hcValue = hcMetrics[key] ?? 0;
      final manualValue = manualContributions.containsKey(key)
          ? manualContributions[key]!
          : existing['${key}_manual'] ?? 0;
      merged['${key}_hc'] = hcValue;
      merged['${key}_manual'] = manualValue;
      merged[key] = hcValue + manualValue;
    }

    // Sleep: display = max(HC, manual) — same night, avoid double-count.
    for (final key in _sleepKeys) {
      final hcValue = hcMetrics[key] ?? 0;
      final manualValue = existing['${key}_manual'] ?? 0;
      merged['${key}_hc'] = hcValue;
      merged[key] = hcValue >= manualValue ? hcValue : manualValue;
    }

    // Vitals / body: HC wins if non-zero; otherwise preserve whatever is
    // already stored (previous HC reading or manual entry).
    for (final entry in hcMetrics.entries) {
      final key = entry.key;
      if (_sumAdditiveKeys.contains(key) || _sleepKeys.contains(key)) continue;
      if (key.endsWith('_hc') || key.endsWith('_manual')) continue;
      final hcValue = entry.value;
      merged['${key}_hc'] = hcValue;
      if (hcValue != 0) {
        merged[key] = hcValue;
      } else {
        // HC has nothing today. Keep existing non-zero display value (from a prior
        // HC sync or manual entry). Only apply manual fallback if display is empty.
        final existingDisplay = merged[key] ?? 0;
        if (existingDisplay == 0) {
          final manualFallback = existing['${key}_manual'] ?? 0;
          if (manualFallback != 0) merged[key] = manualFallback;
        }
      }
    }

    final normalized = _normalizeMetrics(merged);
    await _executor!.runInsert(
      'INSERT OR REPLACE INTO daily_metrics (date_key, metrics_json, updated_at)'
      ' VALUES (?, ?, ?)',
      [dateKey, jsonEncode(normalized), DateTime.now().toUtc().toIso8601String()],
    );
  }

  // ---------------------------------------------------------------------------
  // Workout CRUD with IDs (Phase 2 — edit / delete)
  // ---------------------------------------------------------------------------

  Future<List<({int id, String encryptedData})>> fetchWorkoutsWithIds(
    SecretKey secretKey,
  ) async {
    await _openWithKey(secretKey);
    final rows = await _executor!.runSelect(
      'SELECT id, encrypted_data FROM workouts ORDER BY id DESC',
      const [],
    );
    return rows.map((row) {
      final id = row['id'];
      final data = row['encrypted_data'];
      return (
        id: (id is int ? id : int.tryParse('$id') ?? 0),
        encryptedData: data?.toString() ?? '',
      );
    }).where((r) => r.encryptedData.isNotEmpty).toList(growable: false);
  }

  Future<void> updateWorkout(
    int id,
    String encryptedData,
    SecretKey secretKey,
  ) async {
    await _openWithKey(secretKey);
    await _executor!.runUpdate(
      'UPDATE workouts SET encrypted_data = ? WHERE id = ?',
      [encryptedData, id],
    );
  }

  Future<void> deleteWorkout(int id, SecretKey secretKey) async {
    await _openWithKey(secretKey);
    await _executor!.runUpdate(
      'DELETE FROM workouts WHERE id = ?',
      [id],
    );
  }

  // ---------------------------------------------------------------------------
  // Manual metric override (Phase 2 — edit manual metric entries)
  // ---------------------------------------------------------------------------

  /// Replaces the manual contribution for a single metric key on a given day
  /// and recomputes the combined display value using the same merge rules as
  /// [mergeDailyMetrics] / [syncFromHealthConnect].
  Future<void> setManualMetricValue({
    required String dateKey,
    required String metricKey,
    required num value,
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

    final merged = Map<String, num>.from(existing);

    if (_sumAdditiveKeys.contains(metricKey)) {
      final hcBase = existing.containsKey('${metricKey}_hc')
          ? existing['${metricKey}_hc'] ?? 0
          : existing[metricKey] ?? 0;
      merged['${metricKey}_hc'] = hcBase;
      merged['${metricKey}_manual'] = value;
      merged[metricKey] = hcBase + value;
    } else if (_sleepKeys.contains(metricKey)) {
      final hcBase = existing.containsKey('${metricKey}_hc')
          ? existing['${metricKey}_hc'] ?? 0
          : existing[metricKey] ?? 0;
      merged['${metricKey}_hc'] = hcBase;
      merged['${metricKey}_manual'] = value;
      merged[metricKey] = hcBase >= value ? hcBase : value;
    } else {
      merged['${metricKey}_manual'] = value;
      final hcVal = existing['${metricKey}_hc'] ?? 0;
      merged[metricKey] = hcVal != 0 ? hcVal : value;
    }

    final normalized = _normalizeMetrics(merged);
    await _executor!.runInsert(
      'INSERT OR REPLACE INTO daily_metrics (date_key, metrics_json, updated_at)'
      ' VALUES (?, ?, ?)',
      [dateKey, jsonEncode(normalized), DateTime.now().toUtc().toIso8601String()],
    );
  }

  // ---------------------------------------------------------------------------
  // Goals CRUD (Phase 2)
  // ---------------------------------------------------------------------------

  Future<void> upsertGoal({
    required String metricKey,
    required num targetValue,
    required String period,
    required SecretKey secretKey,
  }) async {
    await _openWithKey(secretKey);
    await _executor!.runInsert(
      'INSERT OR REPLACE INTO user_goals (metric_key, target_value, period, updated_at)'
      ' VALUES (?, ?, ?, ?)',
      [metricKey, targetValue, period, DateTime.now().toUtc().toIso8601String()],
    );
  }

  Future<List<Map<String, dynamic>>> fetchGoals(SecretKey secretKey) async {
    await _openWithKey(secretKey);
    final rows = await _executor!.runSelect(
      'SELECT metric_key, target_value, period, updated_at FROM user_goals',
      const [],
    );
    return rows
        .map((r) => <String, dynamic>{
              'metric_key': r['metric_key'],
              'target_value': r['target_value'],
              'period': r['period'],
              'updated_at': r['updated_at'],
            })
        .toList(growable: false);
  }

  Future<void> deleteGoal(String metricKey, SecretKey secretKey) async {
    await _openWithKey(secretKey);
    await _executor!.runUpdate(
      'DELETE FROM user_goals WHERE metric_key = ?',
      [metricKey],
    );
  }

  Future<void> insertBackupHistory({
    required String backupType,
    required String status,
    String? details,
    required SecretKey secretKey,
  }) async {
    await _openWithKey(secretKey);
    await _executor!.runInsert(
      'INSERT INTO backup_history (backup_type, status, created_at, details) VALUES (?, ?, ?, ?)',
      [
        backupType,
        status,
        DateTime.now().toUtc().toIso8601String(),
        details,
      ],
    );
  }

  Future<List<Map<String, dynamic>>> fetchBackupHistory(
      SecretKey secretKey) async {
    await _openWithKey(secretKey);
    final rows = await _executor!.runSelect(
      'SELECT * FROM backup_history ORDER BY id DESC LIMIT 50',
      const [],
    );
    return rows.map((r) => Map<String, dynamic>.from(r)).toList();
  }

  Future<Map<String, dynamic>?> fetchLatestBackup(
      SecretKey secretKey) async {
    await _openWithKey(secretKey);
    final rows = await _executor!.runSelect(
      "SELECT * FROM backup_history WHERE status = 'success' ORDER BY id DESC LIMIT 1",
      const [],
    );
    return rows.isEmpty ? null : Map<String, dynamic>.from(rows.first);
  }

  // ---------------------------------------------------------------------------
  // Workout templates
  // ---------------------------------------------------------------------------

  Future<void> saveTemplate({
    required String name,
    required String activityType,
    required String encryptedData,
    required SecretKey secretKey,
  }) async {
    await _openWithKey(secretKey);
    await _executor!.runInsert(
      'INSERT INTO workout_templates (name, activity_type, encrypted_data, created_at) VALUES (?, ?, ?, ?)',
      [name, activityType, encryptedData, DateTime.now().toUtc().toIso8601String()],
    );
  }

  Future<void> updateTemplate({
    required int id,
    required String name,
    required String activityType,
    required String encryptedData,
    required SecretKey secretKey,
  }) async {
    await _openWithKey(secretKey);
    await _executor!.runUpdate(
      'UPDATE workout_templates SET name = ?, activity_type = ?, encrypted_data = ? WHERE id = ?',
      [name, activityType, encryptedData, id],
    );
  }

  Future<void> deleteTemplate(int id, SecretKey secretKey) async {
    await _openWithKey(secretKey);
    await _executor!.runDelete(
      'DELETE FROM workout_templates WHERE id = ?',
      [id],
    );
  }

  Future<List<Map<String, dynamic>>> fetchTemplates(SecretKey secretKey) async {
    await _openWithKey(secretKey);
    final rows = await _executor!.runSelect(
      'SELECT id, name, activity_type, encrypted_data, created_at FROM workout_templates ORDER BY id DESC',
      const [],
    );
    return rows.map((r) => Map<String, dynamic>.from(r)).toList();
  }

  // ---------------------------------------------------------------------------
  // Access log (4.8)
  // ---------------------------------------------------------------------------

  Future<void> logAccess(SecretKey secretKey) async {
    await _openWithKey(secretKey);
    await _executor!.runInsert(
      'INSERT INTO access_log (accessed_at) VALUES (?)',
      [DateTime.now().toUtc().toIso8601String()],
    );
  }

  Future<List<Map<String, dynamic>>> fetchAccessLog(SecretKey secretKey) async {
    await _openWithKey(secretKey);
    final rows = await _executor!.runSelect(
      'SELECT accessed_at FROM access_log ORDER BY id DESC LIMIT 20',
      const [],
    );
    return rows.map((r) => Map<String, dynamic>.from(r)).toList();
  }

  Future<Map<String, int>> fetchTableRowCounts(SecretKey secretKey) async {
    await _openWithKey(secretKey);
    final tables = ['workouts', 'daily_metrics', 'achievements', 'user_goals',
        'backup_history', 'workout_templates', 'access_log'];
    final counts = <String, int>{};
    for (final t in tables) {
      final rows = await _executor!.runSelect('SELECT COUNT(*) AS c FROM $t', const []);
      counts[t] = (rows.first['c'] as int?) ?? 0;
    }
    return counts;
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
