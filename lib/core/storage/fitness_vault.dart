import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:zero_trust_core/zero_trust_core.dart';

/// Writes an item so it is synced to the account's other devices. In the app
/// this is the core's [SyncController]; tests write straight to a store.
abstract interface class FitnessItemWriter {
  Future<void> save(String itemId, Map<String, Object?> json);
  Future<void> delete(String itemId);
}

class SyncControllerWriter implements FitnessItemWriter {
  const SyncControllerWriter(this._sync);
  final SyncController _sync;

  @override
  Future<void> save(String itemId, Map<String, Object?> json) =>
      _sync.save(itemId, json);

  @override
  Future<void> delete(String itemId) => _sync.delete(itemId);
}

/// A logged workout: manual, GPS, or (from older versions) a Health Connect
/// record. [data] keeps the same fields earlier versions stored (`type`,
/// `duration`, `intensity`, `timestamp`, `distance_m`, `route`, ...).
class FitnessWorkout {
  const FitnessWorkout({required this.id, required this.data});
  final String id;
  final Map<String, dynamic> data;
}

class FitnessTemplate {
  const FitnessTemplate({
    required this.id,
    required this.name,
    required this.activityType,
    required this.data,
    required this.createdAt,
  });
  final String id;
  final String name;
  final String activityType;
  final Map<String, dynamic> data;
  final DateTime createdAt;
}

class _Day {
  const _Day(this.dateKey, this.metrics, this.updatedAt);
  final String dateKey;
  final Map<String, num> metrics;
  final DateTime updatedAt;
}

class _Achievement {
  const _Achievement(this.achievementId, this.unlockedAt);
  final String achievementId;
  final DateTime unlockedAt;
}

class _Goal {
  const _Goal(this.metricKey, this.targetValue, this.period, this.updatedAt);
  final String metricKey;
  final num targetValue;
  final String period;
  final DateTime updatedAt;
}

/// Everything Fitness keeps, as items in the core's encrypted local store,
/// each synced on its own to the account's other devices (`vault_items`).
///
/// Item kinds: `workout`, `day` (one per calendar day: the metrics map with
/// its Health Connect / manual split), `achievement`, `goal`, `template`.
///
/// Item ids are visible to the server, so ids that would say something
/// (a date, a goal's metric, a medal) are an HMAC of that name under a key
/// derived from the app key: the same on every device of the account, and
/// meaningless to anyone else.
class FitnessVault {
  FitnessVault({
    required this.store,
    required FitnessItemWriter writer,
    required List<int> idKey,
  })  : _writer = writer,
        _idKey = SecretKey(List<int>.of(idKey));

  final LocalItemStore store;
  final FitnessItemWriter _writer;
  final SecretKey _idKey;

  static const String idKeyInfo = 'zt/fitness/item-id/v1';

  /// The id key for an unlocked vault's app key.
  static Future<Uint8List> deriveIdKey(List<int> appKey) =>
      Kdf.hkdf(appKey, idKeyInfo);

  /// Changes from this device or from sync, when the store reports them.
  Stream<Set<String>> get changes => switch (store) {
        final ZtLocalStore s => s.changes,
        _ => const Stream.empty(),
      };

  // Metrics that accumulate across sources (HC total + manual additions).
  static const _sumAdditiveKeys = <String>{
    'steps',
    'heart_points',
    'water_l',
    'nutrition_entries',
  };

  // Sleep metrics: per-night, so we take max(HC, manual) to avoid double-count.
  static const _sleepKeys = <String>{
    'sleep_asleep_min',
    'sleep_light_min',
    'sleep_deep_min',
    'sleep_rem_min',
  };

  // ---------------------------------------------------------------------------
  // Collections
  // ---------------------------------------------------------------------------

  static final workouts = ZtCollection<FitnessWorkout>(
    kind: 'workout',
    fromJson: (id, json, _) => FitnessWorkout(
      id: id,
      data: {
        for (final e in json.entries)
          if (e.key != ZtCollection.kindKey && e.key != ZtCollection.versionKey)
            e.key: e.value,
      },
    ),
    toJson: (w) => {...w.data},
    idOf: (w) => w.id,
  );

  static final _days = ZtCollection<_Day>(
    kind: 'day',
    fromJson: (id, json, updatedAt) => _Day(
      json['date'] as String,
      parseMetrics(json['metrics']),
      updatedAt,
    ),
    toJson: (d) => {'date': d.dateKey, 'metrics': d.metrics},
    idOf: (d) => throw UnsupportedError('day ids are derived'),
  );

  static final _achievements = ZtCollection<_Achievement>(
    kind: 'achievement',
    fromJson: (id, json, _) => _Achievement(
      json['achievementId'] as String,
      DateTime.tryParse(json['unlockedAt'] as String? ?? '')?.toUtc() ??
          DateTime.utc(2000),
    ),
    toJson: (a) => {
      'achievementId': a.achievementId,
      'unlockedAt': a.unlockedAt.toUtc().toIso8601String(),
    },
    idOf: (a) => throw UnsupportedError('achievement ids are derived'),
  );

  static final _goals = ZtCollection<_Goal>(
    kind: 'goal',
    fromJson: (id, json, updatedAt) => _Goal(
      json['metricKey'] as String,
      (json['targetValue'] as num?) ?? 0,
      json['period'] as String? ?? 'daily',
      updatedAt,
    ),
    toJson: (g) => {
      'metricKey': g.metricKey,
      'targetValue': g.targetValue,
      'period': g.period,
    },
    idOf: (g) => throw UnsupportedError('goal ids are derived'),
  );

  static final templates = ZtCollection<FitnessTemplate>(
    kind: 'template',
    fromJson: (id, json, _) => FitnessTemplate(
      id: id,
      name: json['name'] as String? ?? '',
      activityType: json['activityType'] as String? ?? '',
      data: _asStringMap(json['data']),
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '')?.toUtc() ??
              DateTime.utc(2000),
    ),
    toJson: (t) => {
      'name': t.name,
      'activityType': t.activityType,
      'data': t.data,
      'createdAt': t.createdAt.toUtc().toIso8601String(),
    },
    idOf: (t) => t.id,
  );

  /// Saves [value] in [collection] under [id], keeping fields a newer app
  /// version added, and refusing to overwrite an item a newer version wrote.
  Future<void> _put<T>(ZtCollection<T> collection, String id, T value) async {
    final previous = (await store.get(id))?.json;
    final owned = previous != null && collection.owns(previous);
    if (owned) {
      final v = ZtCollection.versionOf(previous);
      if (v > collection.version) throw ItemFromNewerVersion(id, v);
    }
    await _writer.save(
        id, collection.encode(value, previous: owned ? previous : null));
  }

  // ---------------------------------------------------------------------------
  // Ids
  // ---------------------------------------------------------------------------

  /// The opaque item id for a [name] such as `day:2026-11-09`.
  Future<String> idFor(String name) async {
    final mac =
        await Hmac.sha256().calculateMac(utf8.encode(name), secretKey: _idKey);
    return _hex(mac.bytes.sublist(0, 16));
  }

  /// A fresh random id, for items with no natural name.
  static String newId() => _hex(Kdf.randomBytes(16));

  /// The id a workout imported from an earlier version gets: the same on
  /// every device for the same workout, so two devices importing it (or the
  /// cloud backup and the phone's own copy) don't make two.
  Future<String> legacyWorkoutId(Map<String, dynamic> data) {
    final type = data['type']?.toString() ?? '';
    final at = (data['timestamp'] ?? data['date'] ?? '').toString();
    // Old Health Connect records have no duration and can share a start
    // time, so their value is part of what makes them distinct.
    final value = data.containsKey('duration') ? '' : '${data['value']}';
    return idFor('workout:$type|$at|$value');
  }

  // ---------------------------------------------------------------------------
  // Workouts
  // ---------------------------------------------------------------------------

  /// Newest first.
  Future<List<FitnessWorkout>> fetchWorkouts() async {
    final list = await workouts.list(store);
    list.sort((a, b) => _workoutTime(b).compareTo(_workoutTime(a)));
    return list;
  }

  static DateTime _workoutTime(FitnessWorkout w) =>
      DateTime.tryParse((w.data['timestamp'] ?? w.data['date'] ?? '').toString())
          ?.toUtc() ??
      DateTime.utc(1970);

  /// Saves a new workout, or replaces the one with [id].
  Future<String> saveWorkout(Map<String, dynamic> data, {String? id}) async {
    final itemId = id ?? newId();
    await _put(workouts, itemId, FitnessWorkout(id: itemId, data: data));
    return itemId;
  }

  Future<void> deleteWorkout(String id) => _writer.delete(id);

  // ---------------------------------------------------------------------------
  // Daily metrics
  // ---------------------------------------------------------------------------

  Future<_Day?> _getDay(String dateKey) async {
    final item = await store.get(await idFor('day:$dateKey'));
    return item == null ? null : _days.decode(item);
  }

  Future<Map<String, num>> _metricsFor(String dateKey) async =>
      (await _getDay(dateKey))?.metrics ?? <String, num>{};

  /// Saves the day only when its metrics changed, so a Health Connect
  /// refresh that found nothing new doesn't sync a new version.
  Future<void> _putDay(String dateKey, Map<String, num> metrics) async {
    final normalized = _normalizeMetrics(metrics);
    final existing = await _getDay(dateKey);
    if (existing != null && _sameMetrics(existing.metrics, normalized)) return;
    await _put(_days, await idFor('day:$dateKey'),
        _Day(dateKey, normalized, DateTime.now().toUtc()));
  }

  /// One row per day, newest first, in the shape screens used before:
  /// `date_key`, `metrics`, `steps`, `heart_points`, `updated_at`.
  Future<List<Map<String, dynamic>>> fetchDailyMetrics() async {
    final days = await _days.list(store);
    days.sort((a, b) => b.dateKey.compareTo(a.dateKey));
    return [
      for (final d in days)
        <String, dynamic>{
          'date_key': d.dateKey,
          'metrics': d.metrics,
          'steps': _metricAsInt(d.metrics, 'steps'),
          'heart_points': _metricAsInt(d.metrics, 'heart_points'),
          'updated_at': d.updatedAt.toIso8601String(),
        },
    ];
  }

  Future<void> upsertDailyMetrics({
    required String dateKey,
    required Map<String, num> metrics,
  }) =>
      _putDay(dateKey, metrics);

  /// Merges manually-entered values into a day.
  /// Uses shadow keys (`_hc` / `_manual`) so that a subsequent
  /// [syncFromHealthConnect] call can preserve manual additions.
  Future<void> mergeDailyMetrics({
    required String dateKey,
    required Map<String, num> incoming,
  }) async {
    final existing = await _metricsFor(dateKey);
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

    await _putDay(dateKey, merged);
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
  }) async {
    final existing = await _metricsFor(dateKey);
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

    await _putDay(dateKey, merged);
  }

  /// Raises the Health Connect share of sum-additive metrics (steps, heart
  /// points, ...) for a past day that was recomputed from a later fetch.
  ///
  /// Unlike [syncFromHealthConnect] this touches only the keys in [hcMetrics],
  /// keeps manual contributions, and never lowers a stored value, so a partial
  /// fetch or revoked permission can't wipe history.
  Future<void> raiseHealthConnectTotals({
    required String dateKey,
    required Map<String, num> hcMetrics,
  }) async {
    final existing = await _metricsFor(dateKey);
    final merged = Map<String, num>.from(existing);
    var changed = false;
    for (final entry in hcMetrics.entries) {
      final key = entry.key;
      if (!_sumAdditiveKeys.contains(key)) continue;
      final manual = existing['${key}_manual'] ?? 0;
      // Rows written before the hc/manual split hold only a display value.
      final storedHc = existing['${key}_hc'] ?? ((existing[key] ?? 0) - manual);
      if (entry.value <= storedHc) continue;
      merged['${key}_hc'] = entry.value;
      merged['${key}_manual'] = manual;
      merged[key] = entry.value + manual;
      changed = true;
    }
    if (!changed) return;
    await _putDay(dateKey, merged);
  }

  /// Replaces the manual contribution for a single metric key on a given day
  /// and recomputes the combined display value using the same merge rules as
  /// [mergeDailyMetrics] / [syncFromHealthConnect].
  Future<void> setManualMetricValue({
    required String dateKey,
    required String metricKey,
    required num value,
  }) async {
    final existing = await _metricsFor(dateKey);
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

    await _putDay(dateKey, merged);
  }

  // ---------------------------------------------------------------------------
  // Achievements
  // ---------------------------------------------------------------------------

  /// `id` and `unlocked_at` (ISO 8601), as before.
  Future<List<Map<String, dynamic>>> fetchAchievements() async => [
        for (final a in await _achievements.list(store))
          <String, dynamic>{
            'id': a.achievementId,
            'unlocked_at': a.unlockedAt.toIso8601String(),
          },
      ];

  Future<bool> hasAchievement(String id) async {
    final item = await store.get(await idFor('achievement:$id'));
    return item != null && _achievements.decode(item) != null;
  }

  Future<void> insertAchievementIfAbsent(String id, DateTime unlockedAt) async {
    if (await hasAchievement(id)) return;
    await _put(_achievements, await idFor('achievement:$id'),
        _Achievement(id, unlockedAt.toUtc()));
  }

  // ---------------------------------------------------------------------------
  // Goals
  // ---------------------------------------------------------------------------

  Future<void> upsertGoal({
    required String metricKey,
    required num targetValue,
    required String period,
  }) async =>
      _put(_goals, await idFor('goal:$metricKey'),
          _Goal(metricKey, targetValue, period, DateTime.now().toUtc()));

  /// `metric_key`, `target_value`, `period`, `updated_at`, as before.
  Future<List<Map<String, dynamic>>> fetchGoals() async => [
        for (final g in await _goals.list(store))
          <String, dynamic>{
            'metric_key': g.metricKey,
            'target_value': g.targetValue,
            'period': g.period,
            'updated_at': g.updatedAt.toIso8601String(),
          },
      ];

  Future<void> deleteGoal(String metricKey) async =>
      _writer.delete(await idFor('goal:$metricKey'));

  // ---------------------------------------------------------------------------
  // Templates
  // ---------------------------------------------------------------------------

  /// Newest first.
  Future<List<FitnessTemplate>> fetchTemplates() async {
    final list = await templates.list(store);
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  Future<String> saveTemplate({
    String? id,
    required String name,
    required String activityType,
    required Map<String, dynamic> data,
    DateTime? createdAt,
  }) async {
    final itemId = id ?? newId();
    final existing = id == null ? null : await templates.get(store, id);
    await _put(
      templates,
      itemId,
      FitnessTemplate(
        id: itemId,
        name: name,
        activityType: activityType,
        data: data,
        createdAt:
            createdAt ?? existing?.createdAt ?? DateTime.now().toUtc(),
      ),
    );
    return itemId;
  }

  Future<void> deleteTemplate(String id) => _writer.delete(id);

  // ---------------------------------------------------------------------------
  // Whole-vault operations
  // ---------------------------------------------------------------------------

  /// Item counts per kind, for the privacy dashboard.
  Future<Map<String, int>> countsByKind() async {
    final counts = <String, int>{
      'workout': 0,
      'day': 0,
      'achievement': 0,
      'goal': 0,
      'template': 0,
    };
    for (final item in await store.all()) {
      if (item.deleted) continue;
      final kind = item.json?[ZtCollection.kindKey];
      if (kind is String) counts[kind] = (counts[kind] ?? 0) + 1;
    }
    return counts;
  }

  /// Deletes workouts, days and medals on every device (goals and templates
  /// are settings, and stay).
  Future<void> clearActivityData() async {
    for (final item in await store.all()) {
      if (item.deleted) continue;
      final kind = item.json?[ZtCollection.kindKey];
      if (kind == 'workout' || kind == 'day' || kind == 'achievement') {
        await _writer.delete(item.itemId);
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  static Map<String, num> parseMetrics(Object? raw) {
    if (raw is String) {
      try {
        raw = jsonDecode(raw);
      } catch (_) {
        return <String, num>{};
      }
    }
    if (raw is! Map) return <String, num>{};
    final metrics = <String, num>{};
    raw.forEach((key, value) {
      final parsed = _parseNum(value);
      if (parsed != null) metrics[key.toString()] = parsed;
    });
    return metrics;
  }

  static num? _parseNum(dynamic value) {
    if (value is num) return value;
    if (value is String) return num.tryParse(value);
    return null;
  }

  static Map<String, num> _normalizeMetrics(Map<String, num> metrics) {
    final normalized = <String, num>{};
    metrics.forEach((key, value) {
      if (!value.isFinite) return;
      final intValue = value.toInt();
      normalized[key] = value == intValue ? intValue : value.toDouble();
    });
    return normalized;
  }

  static bool _sameMetrics(Map<String, num> a, Map<String, num> b) {
    if (a.length != b.length) return false;
    for (final e in a.entries) {
      if (b[e.key] != e.value) return false;
    }
    return true;
  }

  static int _metricAsInt(Map<String, num> metrics, String key) =>
      metrics[key]?.toInt() ?? 0;

  static Map<String, dynamic> _asStringMap(Object? raw) => raw is Map
      ? raw.map((k, v) => MapEntry(k.toString(), v))
      : <String, dynamic>{};

  static String _hex(List<int> bytes) =>
      bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}
