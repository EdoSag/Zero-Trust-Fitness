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
      DateTime createdAt,
    })
  >
  templates = [];

  bool get isEmpty =>
      workouts.isEmpty &&
      days.isEmpty &&
      achievements.isEmpty &&
      goals.isEmpty &&
      templates.isEmpty;
}

/// Old data (the phone's database, `phone`, or the cloud backup, `cloud`)
/// that none of the keys tried opens. Usually it was written under a key
/// the account's no longer matches; the old password, typed once, can
/// unlock it (see [legacyKeysFromPassword]). Never treated as "no data".
class LegacyBackupUnreadable implements Exception {
  const LegacyBackupUnreadable(this.source);

  /// `phone` or `cloud`.
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
    final box = await _aes.encrypt(
      utf8.encode(clear),
      secretKey: SecretKey(key),
      nonce: _aes.newNonce(),
    );
    return base64Url.encode(box.concatenation());
  }
}

/// Reads the encrypted backups earlier versions kept in Supabase
/// (`encrypted_vault.data_blob`), and the account's old key salt.
abstract interface class LegacyCloudBackup {
  /// Every backup row, newest first. Usually one, but the live table never
  /// had a unique constraint, so a device could leave more than one.
  Future<List<String>> fetchAll();

  /// `profiles.salt` as stored: the salt earlier versions derived their key
  /// from, in whatever base64 dialect the app that wrote it used.
  Future<String?> legacySalt();
}

class SupabaseLegacyCloudBackup implements LegacyCloudBackup {
  @override
  Future<List<String>> fetchAll() async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) throw StateError('Not signed in');
    final List<Map<String, dynamic>> rows;
    try {
      rows = await client
          .from('encrypted_vault')
          .select('data_blob, updated_at')
          .eq('user_id', user.id)
          .order('updated_at', ascending: false)
          .limit(20);
    } on PostgrestException catch (e) {
      if (isMissingLegacyTable(e)) return const [];
      rethrow;
    }
    return [
      for (final row in rows)
        if (row['data_blob'] case final String blob when blob.isNotEmpty) blob,
    ];
  }

  @override
  Future<String?> legacySalt() async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) throw StateError('Not signed in');
    final row = await client
        .from('profiles')
        .select('salt')
        .eq('id', user.id)
        .maybeSingle();
    final salt = row?['salt'];
    return salt is String && salt.isNotEmpty ? salt : null;
  }
}

/// Parses the decrypted cloud backup (payload version 1 or 2).
///
/// Each section is read on its own, so one odd field (a backup from an
/// older build) costs that section's bad entries, never the whole backup.
LegacyFitnessData parseLegacyCloudPayload(Map<String, dynamic> payload) {
  final data = LegacyFitnessData();
  void section(void Function() read) {
    try {
      read();
    } on Object {
      // See above.
    }
  }

  section(() {
    final workoutsRaw = payload['workouts'];
    if (workoutsRaw is List) {
      for (final w in workoutsRaw) {
        if (w is Map) data.workouts.add(w.map((k, v) => MapEntry('$k', v)));
      }
    }
  });

  section(() {
    final mapRaw = payload['daily_metric_map'];
    if (mapRaw is Map) {
      mapRaw.forEach((key, value) {
        final metrics = FitnessVault.parseMetrics(value);
        if ('$key'.isNotEmpty && metrics.isNotEmpty)
          data.days['$key'] = metrics;
      });
    }
  });
  section(() {
    final dailyRaw = payload['daily_metrics'];
    if (dailyRaw is! List) return;
    for (final row in dailyRaw) {
      if (row is! Map) continue;
      final dateKey = row['date_key']?.toString();
      if (dateKey == null || dateKey.isEmpty) continue;
      var metrics = FitnessVault.parseMetrics(row['metrics']);
      if (metrics.isEmpty) {
        metrics = {
          'steps': _num(row['steps']),
          'heart_points': _num(row['heart_points']),
        };
      }
      data.days[dateKey] = metrics;
    }
  });

  // Version 1 backups had raw step and heart records instead of days.
  if (data.days.isEmpty) {
    void add(Object? timestamp, String key, num value) {
      final at = DateTime.tryParse('${timestamp ?? ''}');
      if (at == null) return;
      final day = data.days.putIfAbsent(
        _dateKey(at),
        () => <String, num>{'steps': 0, 'heart_points': 0},
      );
      day[key] = (day[key] ?? 0) + value;
    }

    section(() {
      final steps = payload['steps'];
      if (steps is List) {
        for (final r in steps) {
          if (r is Map) add(r['timestamp'], 'steps', _num(r['value']));
        }
      }
    });
    section(() {
      final heart = payload['heart_points'];
      final records = heart is Map ? heart['records'] : null;
      if (records is! List) return;
      for (final r in records) {
        if (r is! Map) continue;
        final points = switch (r['metric']) {
          'exercise_time_min' => _num(r['value']).toInt(),
          'heart_rate_bpm' => _num(r['derived_points']).toInt(),
          _ => 0,
        };
        add(r['timestamp'], 'heart_points', points);
      }
    });
  }

  section(() {
    final achievementsRaw = payload['achievements'];
    if (achievementsRaw is! List) return;
    for (final a in achievementsRaw) {
      if (a is! Map) continue;
      final id = a['id']?.toString();
      if (id == null || id.isEmpty) continue;
      data.achievements[id] =
          DateTime.tryParse('${a['unlocked_at']}')?.toUtc() ??
          DateTime.utc(2000);
    }
  });
  return data;
}

/// A number, or a number written as text, else 0.
num _num(Object? value) => switch (value) {
  final num n => n,
  final String s => num.tryParse(s) ?? 0,
  _ => 0,
};

/// Decrypts and parses the cloud backup. Earlier versions fell back to
/// reading an unencrypted payload, so this does too.
///
/// Throws [LegacyBackupUnreadable] when no key opens it. A key that opens
/// it but finds something other than a backup inside throws
/// [FormatException]: that's a bug to fix, not a wrong key.
Future<LegacyFitnessData> readLegacyCloudBackup(
  String blob,
  List<List<int>> keys,
) async {
  for (final key in keys) {
    final String clear;
    try {
      clear = await LegacyCipher.decrypt(blob, key);
    } on Object {
      continue; // not this key
    }
    return _decodePayload(clear);
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

/// The newest of [blobs] that one of [keys] opens. Older rows only matter
/// when the newest can't be read.
Future<LegacyFitnessData?> readLegacyCloudBackups(
  List<String> blobs,
  List<List<int>> keys,
) async {
  if (blobs.isEmpty) return null;
  for (final blob in blobs) {
    try {
      return await readLegacyCloudBackup(blob, keys);
    } on LegacyBackupUnreadable {
      continue;
    }
  }
  throw const LegacyBackupUnreadable('cloud');
}

/// Reads the SQLCipher database earlier versions kept on the phone
/// (`vault.sqlite`, keyed with the raw PBKDF2 key). SQLite3 Multiple Ciphers
/// opens it in SQLCipher 4 mode, so the old SQLCipher build isn't needed.
///
/// Returns null when [path] doesn't exist. Throws [LegacyBackupUnreadable]
/// when it does but none of [keys] opens it: that is old data still to
/// bring over, never "nothing to import".
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
  throw const LegacyBackupUnreadable('phone');
}

Future<LegacyFitnessData> _readLocalTables(Database db, List<int> key) async {
  final data = LegacyFitnessData();
  bool has(String table) => db.select(
    "select 1 from sqlite_master where type = 'table' and name = ?",
    [table],
  ).isNotEmpty;

  if (has('workouts')) {
    for (final row in db.select('select encrypted_data from workouts')) {
      try {
        final decoded = jsonDecode(
          await LegacyCipher.decrypt(row['encrypted_data'], key),
        );
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
      for (final row in db.select(
        'select date_key, metrics_json from daily_metrics',
      )) {
        final metrics = FitnessVault.parseMetrics(row['metrics_json']);
        if (metrics.isNotEmpty) data.days['${row['date_key']}'] = metrics;
      }
    } else if (cols.contains('steps')) {
      // The first schema, before the metrics map.
      for (final row in db.select(
        'select date_key, steps, heart_points from daily_metrics',
      )) {
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
          DateTime.tryParse('${row['unlocked_at']}')?.toUtc() ??
          DateTime.utc(2000);
    }
  }

  if (has('user_goals')) {
    for (final row in db.select(
      'select metric_key, target_value, period from user_goals',
    )) {
      data.goals.add((
        metricKey: '${row['metric_key']}',
        targetValue: (row['target_value'] as num?) ?? 0,
        period: '${row['period'] ?? 'daily'}',
      ));
    }
  }

  if (has('workout_templates')) {
    for (final row in db.select(
      'select name, activity_type, encrypted_data, created_at from workout_templates',
    )) {
      Map<String, dynamic> fields = {};
      try {
        final decoded = jsonDecode(
          await LegacyCipher.decrypt(row['encrypted_data'], key),
        );
        if (decoded is Map) fields = decoded.map((k, v) => MapEntry('$k', v));
      } on Object {
        // Keep the name and type even if the details don't decrypt.
      }
      data.templates.add((
        name: '${row['name']}',
        activityType: '${row['activity_type']}',
        data: fields,
        createdAt:
            DateTime.tryParse('${row['created_at']}')?.toUtc() ??
            DateTime.utc(2000),
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
    records.add(
      LegacyRecord(
        itemId: id,
        json: FitnessVault.workouts.encode(FitnessWorkout(id: id, data: w)),
      ),
    );
  }
  for (final e in data.days.entries) {
    records.add(
      LegacyRecord(
        itemId: await vault.idFor('day:${e.key}'),
        json: {
          'date': e.key,
          'metrics': e.value,
          ZtCollection.kindKey: 'day',
          ZtCollection.versionKey: 1,
        },
      ),
    );
  }
  for (final e in data.achievements.entries) {
    records.add(
      LegacyRecord(
        itemId: await vault.idFor('achievement:${e.key}'),
        json: {
          'achievementId': e.key,
          'unlockedAt': e.value.toUtc().toIso8601String(),
          ZtCollection.kindKey: 'achievement',
          ZtCollection.versionKey: 1,
        },
      ),
    );
  }
  for (final g in data.goals) {
    records.add(
      LegacyRecord(
        itemId: await vault.idFor('goal:${g.metricKey}'),
        json: {
          'metricKey': g.metricKey,
          'targetValue': g.targetValue,
          'period': g.period,
          ZtCollection.kindKey: 'goal',
          ZtCollection.versionKey: 1,
        },
      ),
    );
  }
  for (final t in data.templates) {
    final id = await vault.idFor(
      'template:${t.name}|${t.createdAt.toUtc().toIso8601String()}',
    );
    records.add(
      LegacyRecord(
        itemId: id,
        json: FitnessVault.templates.encode(
          FitnessTemplate(
            id: id,
            name: t.name,
            activityType: t.activityType,
            data: t.data,
            createdAt: t.createdAt,
          ),
        ),
      ),
    );
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

/// Ledger names of the two imports. The phone's is `v2`: up to 0.4.1 a
/// database no key opened was recorded as imported with nothing in it, so
/// every device reads its old file once more (item ids are stable, so what
/// was already brought over isn't copied twice).
const legacyPhoneSource = 'fitness-local-v2';
const legacyCloudSource = 'fitness-cloud-v1';

/// The ledger name for a [LegacyBackupUnreadable.source].
String legacySourceFor(String unreadable) =>
    unreadable == 'phone' ? legacyPhoneSource : legacyCloudSource;

/// The two imports, phone first: its copy can hold entries that never
/// reached the cloud backup, and the importer skips anything already there.
///
/// Keys tried, in order: the account's legacy key, the old app's database
/// key if secure storage still has it, then [extraKeys] (from the old
/// password, see [legacyKeysFromPassword]).
List<LegacyImporter> fitnessLegacyImporters({
  required FitnessVault vault,
  required LegacyCloudBackup cloud,
  required LegacySecureStorage secureStorage,
  required Future<String> Function() localPath,
  List<List<int>> extraKeys = const [],
}) {
  Future<List<List<int>>> keys(Uint8List legacyKey) async {
    final stored = await secureStorage.storedDatabaseKey();
    final all = <List<int>>[];
    for (final key in [legacyKey, ?stored, ...extraKeys]) {
      if (!all.any((k) => _sameBytes(k, key))) all.add(key);
    }
    return all;
  }

  return [
    LegacyImporter(
      source: legacyPhoneSource,
      read: (legacyKey) async {
        final data = await readLegacyLocalVault(
          await localPath(),
          await keys(legacyKey),
        );
        return data == null ? const [] : _recordsFor(data, vault);
      },
    ),
    LegacyImporter(
      source: legacyCloudSource,
      read: (legacyKey) async {
        final data = await readLegacyCloudBackups(
          await cloud.fetchAll(),
          await keys(legacyKey),
        );
        return data == null ? const [] : _recordsFor(data, vault);
      },
    ),
  ];
}

/// The keys earlier versions could have derived from [password]: PBKDF2
/// (600k rounds, SHA-256) over the account's old salt, read the way each
/// app read it. Apps disagreed on the salt's base64 dialect, and one stored
/// it as text, so both the decoded bytes and the text's own bytes are
/// tried. Same derivation as the core's, so it is fast and off the UI
/// thread.
Future<List<Uint8List>> legacyKeysFromPassword(
  String password,
  String salt,
) async {
  final salts = <List<int>>[];
  void add(List<int> candidate) {
    if (candidate.isNotEmpty && !salts.any((s) => _sameBytes(s, candidate))) {
      salts.add(candidate);
    }
  }

  try {
    add(ZtBase64.decode(salt.trim()));
  } on FormatException {
    // Not base64 at all; the text itself is tried below.
  }
  add(utf8.encode(salt));
  return [
    for (final s in salts)
      await Kdf.deriveMasterKey(password: password, salt: s),
  ];
}

/// [legacyRecordsFor], after merging old days into days already logged
/// here: the importer skips items that exist, so a day logged while the
/// import ran would otherwise hide that day's older metrics.
Future<List<LegacyRecord>> _recordsFor(
  LegacyFitnessData data,
  FitnessVault vault,
) async {
  for (final e in data.days.entries) {
    await vault.fillDayFromLegacy(e.key, e.value);
  }
  return legacyRecordsFor(data, vault);
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

/// The pre-core tables were dropped from the database on 2026-11-10. A
/// missing table means there is nothing left to import.
bool isMissingLegacyTable(PostgrestException e) =>
    e.code == 'PGRST205' || e.code == '42P01';
