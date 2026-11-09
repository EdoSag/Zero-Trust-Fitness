import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zero_trust_core/zero_trust_core.dart';
import 'package:zerotrust_fitness/core/storage/fitness_vault.dart';

/// Fitness data as versions before the core kept it, already decrypted.
class LegacyFitnessData {
  final List<Map<String, dynamic>> workouts = [];

  /// Date key (`2026-11-09`) to that day's metrics.
  final Map<String, Map<String, num>> days = {};

  /// Achievement id to unlock time.
  final Map<String, DateTime> achievements = {};
  final List<({String metricKey, num targetValue, String period})> goals = [];
  final List<
      ({
        String name,
        String activityType,
        Map<String, dynamic> data,
        DateTime createdAt
      })> templates = [];

  bool get isEmpty =>
      workouts.isEmpty &&
      days.isEmpty &&
      achievements.isEmpty &&
      goals.isEmpty &&
      templates.isEmpty;
}

/// The old cloud backup failed to decrypt with the account's key.
class LegacyBackupUnreadable implements Exception {
  const LegacyBackupUnreadable(this.source);
  final String source;
  @override
  String toString() => 'LegacyBackupUnreadable($source)';
}

/// AES-256-GCM as earlier versions wrote it: base64url of
/// nonce (12) | ciphertext | MAC (16), under the PBKDF2 key of the password.
abstract final class LegacyCipher {
  static final _aes = AesGcm.with256bits();

  static Future<String> decrypt(String encrypted, List<int> key) async {
    final box = SecretBox.fromConcatenation(
      ZtBase64.decode(encrypted),
      nonceLength: _aes.nonceLength,
      macLength: _aes.macAlgorithm.macLength,
    );
    final clear = await _aes.decrypt(box, secretKey: SecretKey(key));
    return utf8.decode(clear);
  }

  /// For tests: what earlier versions' `EncryptionService.encryptString` did.
  static Future<String> encrypt(String clear, List<int> key) async {
    final box = await _aes.encrypt(utf8.encode(clear),
        secretKey: SecretKey(key), nonce: _aes.newNonce());
    return base64Url.encode(box.concatenation());
  }
}

/// Reads the single encrypted backup earlier versions kept in Supabase
/// (`encrypted_vault.data_blob`).
abstract interface class LegacyCloudBackup {
  Future<String?> fetch();
}

class SupabaseLegacyCloudBackup implements LegacyCloudBackup {
  @override
  Future<String?> fetch() async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) throw StateError('Not signed in');
    final rows = await client
        .from('encrypted_vault')
        .select('data_blob, updated_at')
        .eq('user_id', user.id)
        .order('updated_at', ascending: false)
        .limit(1);
    if (rows.isEmpty) return null;
    final blob = rows.first['data_blob'];
    return blob is String && blob.isNotEmpty ? blob : null;
  }
}

/// Parses the decrypted cloud backup (payload version 1 or 2).
LegacyFitnessData parseLegacyCloudPayload(Map<String, dynamic> payload) {
  final data = LegacyFitnessData();

  final workoutsRaw = payload['workouts'];
  if (workoutsRaw is List) {
    for (final w in workoutsRaw) {
      if (w is Map) data.workouts.add(w.map((k, v) => MapEntry('$k', v)));
    }
  }

  final mapRaw = payload['daily_metric_map'];
  if (mapRaw is Map) {
    mapRaw.forEach((key, value) {
      final metrics = FitnessVault.parseMetrics(value);
      if ('$key'.isNotEmpty && metrics.isNotEmpty) data.days['$key'] = metrics;
    });
  }
  final dailyRaw = payload['daily_metrics'];
  if (dailyRaw is List) {
    for (final row in dailyRaw) {
      if (row is! Map) continue;
      final dateKey = row['date_key']?.toString();
      if (dateKey == null || dateKey.isEmpty) continue;
      var metrics = FitnessVault.parseMetrics(row['metrics']);
      if (metrics.isEmpty) {
        metrics = {
          'steps': (row['steps'] as num?) ?? 0,
          'heart_points': (row['heart_points'] as num?) ?? 0,
        };
      }
      data.days[dateKey] = metrics;
    }
  }

  // Version 1 backups had raw step and heart records instead of days.
  if (data.days.isEmpty) {
    void add(Object? timestamp, String key, num value) {
      final at = DateTime.tryParse('${timestamp ?? ''}');
      if (at == null) return;
      final day = data.days.putIfAbsent(
          _dateKey(at), () => <String, num>{'steps': 0, 'heart_points': 0});
      day[key] = (day[key] ?? 0) + value;
    }

    final steps = payload['steps'];
    if (steps is List) {
      for (final r in steps) {
        if (r is Map) add(r['timestamp'], 'steps', (r['value'] as num?) ?? 0);
      }
    }
    final heart = payload['heart_points'];
    final records = heart is Map ? heart['records'] : null;
    if (records is List) {
      for (final r in records) {
        if (r is! Map) continue;
        final points = switch (r['metric']) {
          'exercise_time_min' => (r['value'] as num?)?.toInt() ?? 0,
          'heart_rate_bpm' => (r['derived_points'] as num?)?.toInt() ?? 0,
          _ => 0,
        };
        add(r['timestamp'], 'heart_points', points);
      }
    }
  }

  final achievementsRaw = payload['achievements'];
  if (achievementsRaw is List) {
    for (final a in achievementsRaw) {
      if (a is! Map) continue;
      final id = a['id']?.toString();
      if (id == null || id.isEmpty) continue;
      data.achievements[id] =
          DateTime.tryParse('${a['unlocked_at']}')?.toUtc() ?? DateTime.utc(2000);
    }
  }
  return data;
}

/// Decrypts and parses the cloud backup. Earlier versions fell back to
/// reading an unencrypted payload, so this does too.
Future<LegacyFitnessData> readLegacyCloudBackup(
  String blob,
  List<List<int>> keys,
) async {
  for (final key in keys) {
    try {
      return _decodePayload(await LegacyCipher.decrypt(blob, key));
    } on Object {
      continue;
    }
  }
  try {
    return _decodePayload(blob);
  } on Object {
    throw const LegacyBackupUnreadable('cloud');
  }
}

LegacyFitnessData _decodePayload(String json) {
  final decoded = jsonDecode(json);
  if (decoded is! Map) throw const FormatException('Not a backup payload');
  return parseLegacyCloudPayload(decoded.map((k, v) => MapEntry('$k', v)));
}

/// Reads the SQLCipher database earlier versions kept on the phone
/// (`vault.sqlite`, keyed with the raw PBKDF2 key). SQLite3 Multiple Ciphers
/// opens it in SQLCipher 4 mode, so the old SQLCipher build isn't needed.
///
/// Returns null when [path] doesn't exist, or none of [keys] opens it.
Future<LegacyFitnessData?> readLegacyLocalVault(
  String path,
  List<List<int>> keys,
) async {
  if (!File(path).existsSync()) return null;
  for (final key in keys) {
    final db = sqlite3.open(path);
    try {
      db.execute("pragma cipher = 'sqlcipher'");
      db.execute('pragma legacy = 4');
      db.execute('pragma key = "x\'${_hex(key)}\'"');
      try {
        db.select('select count(*) from sqlite_master');
      } on SqliteException {
        continue; // not this key
      }
      return await _readLocalTables(db, key);
    } finally {
      db.close();
    }
  }
  return null;
}

Future<LegacyFitnessData> _readLocalTables(Database db, List<int> key) async {
  final data = LegacyFitnessData();
  bool has(String table) => db.select(
      "select 1 from sqlite_master where type = 'table' and name = ?",
      [table]).isNotEmpty;

  if (has('workouts')) {
    for (final row in db.select('select encrypted_data from workouts')) {
      try {
        final decoded =
            jsonDecode(await LegacyCipher.decrypt(row['encrypted_data'], key));
        if (decoded is Map) {
          data.workouts.add(decoded.map((k, v) => MapEntry('$k', v)));
        }
      } on Object {
        // An entry that never decrypted didn't show in the old app either.
      }
    }
  }

  if (has('daily_metrics')) {
    final cols = db
        .select("pragma table_info('daily_metrics')")
        .map((r) => r['name'] as String)
        .toSet();
    if (cols.contains('metrics_json')) {
      for (final row in db.select('select date_key, metrics_json from daily_metrics')) {
        final metrics = FitnessVault.parseMetrics(row['metrics_json']);
        if (metrics.isNotEmpty) data.days['${row['date_key']}'] = metrics;
      }
    } else if (cols.contains('steps')) {
      // The first schema, before the metrics map.
      for (final row
          in db.select('select date_key, steps, heart_points from daily_metrics')) {
        data.days['${row['date_key']}'] = {
          'steps': (row['steps'] as num?) ?? 0,
          'heart_points': (row['heart_points'] as num?) ?? 0,
        };
      }
    }
  }

  if (has('achievements')) {
    for (final row in db.select('select id, unlocked_at from achievements')) {
      data.achievements['${row['id']}'] =
          DateTime.tryParse('${row['unlocked_at']}')?.toUtc() ?? DateTime.utc(2000);
    }
  }

  if (has('user_goals')) {
    for (final row
        in db.select('select metric_key, target_value, period from user_goals')) {
      data.goals.add((
        metricKey: '${row['metric_key']}',
        targetValue: (row['target_value'] as num?) ?? 0,
        period: '${row['period'] ?? 'daily'}',
      ));
    }
  }

  if (has('workout_templates')) {
    for (final row in db.select(
        'select name, activity_type, encrypted_data, created_at from workout_templates')) {
      Map<String, dynamic> fields = {};
      try {
        final decoded =
            jsonDecode(await LegacyCipher.decrypt(row['encrypted_data'], key));
        if (decoded is Map) fields = decoded.map((k, v) => MapEntry('$k', v));
      } on Object {
        // Keep the name and type even if the details don't decrypt.
      }
      data.templates.add((
        name: '${row['name']}',
        activityType: '${row['activity_type']}',
        data: fields,
        createdAt:
            DateTime.tryParse('${row['created_at']}')?.toUtc() ?? DateTime.utc(2000),
      ));
    }
  }
  return data;
}

/// Turns [data] into items with stable ids, so the same record imported on
/// two devices, or from both the phone and the cloud backup, is one item.
Future<List<LegacyRecord>> legacyRecordsFor(
  LegacyFitnessData data,
  FitnessVault vault,
) async {
  final records = <LegacyRecord>[];
  for (final w in data.workouts) {
    final id = await vault.legacyWorkoutId(w);
    records.add(LegacyRecord(
        itemId: id,
        json: FitnessVault.workouts.encode(FitnessWorkout(id: id, data: w))));
  }
  for (final e in data.days.entries) {
    records.add(LegacyRecord(
      itemId: await vault.idFor('day:${e.key}'),
      json: {
        'date': e.key,
        'metrics': e.value,
        ZtCollection.kindKey: 'day',
        ZtCollection.versionKey: 1,
      },
    ));
  }
  for (final e in data.achievements.entries) {
    records.add(LegacyRecord(
      itemId: await vault.idFor('achievement:${e.key}'),
      json: {
        'achievementId': e.key,
        'unlockedAt': e.value.toUtc().toIso8601String(),
        ZtCollection.kindKey: 'achievement',
        ZtCollection.versionKey: 1,
      },
    ));
  }
  for (final g in data.goals) {
    records.add(LegacyRecord(
      itemId: await vault.idFor('goal:${g.metricKey}'),
      json: {
        'metricKey': g.metricKey,
        'targetValue': g.targetValue,
        'period': g.period,
        ZtCollection.kindKey: 'goal',
        ZtCollection.versionKey: 1,
      },
    ));
  }
  for (final t in data.templates) {
    final id = await vault.idFor(
        'template:${t.name}|${t.createdAt.toUtc().toIso8601String()}');
    records.add(LegacyRecord(
      itemId: id,
      json: FitnessVault.templates.encode(FitnessTemplate(
        id: id,
        name: t.name,
        activityType: t.activityType,
        data: t.data,
        createdAt: t.createdAt,
      )),
    ));
  }
  return records;
}

/// What earlier versions left in secure storage. `encrypted_db_key` is the
/// raw key their local database was opened with: tried when the account's
/// key doesn't open it, then deleted with the rest once the import is done.
abstract interface class LegacySecureStorage {
  Future<List<int>?> storedDatabaseKey();
  Future<void> deleteLeftovers();
}

class FlutterLegacySecureStorage implements LegacySecureStorage {
  const FlutterLegacySecureStorage();
  static const _storage = FlutterSecureStorage();

  static const leftoverKeys = [
    'encrypted_db_key',
    'vault_passphrase',
    'vault_pbkdf2_salt',
    'vault_remote_blob',
    'vault_locked',
    'biometric_enabled',
    'user_sync_private_key',
    'sync_device_id',
  ];

  @override
  Future<List<int>?> storedDatabaseKey() async {
    try {
      final hex = await _storage.read(key: 'encrypted_db_key');
      if (hex == null || hex.length != 64) return null;
      return [
        for (var i = 0; i < hex.length; i += 2)
          int.parse(hex.substring(i, i + 2), radix: 16),
      ];
    } on Object {
      return null;
    }
  }

  @override
  Future<void> deleteLeftovers() async {
    for (final key in leftoverKeys) {
      try {
        await _storage.delete(key: key);
      } on Object {
        // Best effort.
      }
    }
  }
}

/// Where earlier versions kept the local database.
Future<String> legacyLocalVaultPath() async {
  final dir = await getApplicationDocumentsDirectory();
  return '${dir.path}/vault.sqlite';
}

/// The two imports, phone first: its copy can hold entries that never
/// reached the cloud backup, and the importer skips anything already there.
List<LegacyImporter> fitnessLegacyImporters({
  required FitnessVault vault,
  required LegacyCloudBackup cloud,
  required LegacySecureStorage secureStorage,
  required Future<String> Function() localPath,
}) {
  Future<List<List<int>>> keys(Uint8List legacyKey) async {
    final stored = await secureStorage.storedDatabaseKey();
    return [
      legacyKey,
      if (stored != null && !_sameBytes(stored, legacyKey)) stored,
    ];
  }

  return [
    LegacyImporter(
      source: 'fitness-local-v1',
      read: (legacyKey) async {
        final data =
            await readLegacyLocalVault(await localPath(), await keys(legacyKey));
        return data == null ? const [] : legacyRecordsFor(data, vault);
      },
    ),
    LegacyImporter(
      source: 'fitness-cloud-v1',
      read: (legacyKey) async {
        final blob = await cloud.fetch();
        if (blob == null) return const [];
        final data = await readLegacyCloudBackup(blob, await keys(legacyKey));
        return legacyRecordsFor(data, vault);
      },
    ),
  ];
}

bool _sameBytes(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

String _dateKey(DateTime date) {
  final l = date.toLocal();
  return '${l.year.toString().padLeft(4, '0')}-'
      '${l.month.toString().padLeft(2, '0')}-'
      '${l.day.toString().padLeft(2, '0')}';
}

String _hex(List<int> bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
