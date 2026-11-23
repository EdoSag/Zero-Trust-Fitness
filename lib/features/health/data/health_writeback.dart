import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:health/health.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zerotrust_fitness/core/storage/fitness_vault.dart';
import 'package:zerotrust_fitness/features/health/data/health_service.dart';

/// The calls write-back makes to Health Connect / Apple Health, so tests can
/// stand in for them.
abstract interface class HealthWorkoutSink {
  /// Whether Health Connect / Apple Health is there to write to.
  Future<bool> available();

  /// Asks to write workouts and water. False when either was refused.
  Future<bool> requestWriteAccess();

  /// Whether workouts may be written (the person can allow them alone).
  Future<bool> hasWorkoutAccess();

  /// Whether water may be written.
  Future<bool> hasWaterAccess();

  Future<bool> write({
    required String type,
    required DateTime start,
    required DateTime end,
    double? distanceMeters,
  });

  /// Removes what this app wrote between [start] and [end]. Health Connect
  /// and HealthKit only let an app delete its own records, so other apps'
  /// workouts in that window are never touched.
  Future<bool> delete({required DateTime start, required DateTime end});

  /// Writes [liters] of water drunk between [start] and [end].
  Future<bool> writeWater({
    required double liters,
    required DateTime start,
    required DateTime end,
  });

  /// Removes the water this app wrote between [start] and [end]; like
  /// [delete], it cannot touch what other apps recorded.
  Future<bool> deleteWater({required DateTime start, required DateTime end});
}

class PluginHealthWorkoutSink implements HealthWorkoutSink {
  PluginHealthWorkoutSink([Health? health]) : _health = health ?? Health();
  final Health _health;

  bool get _android => defaultTargetPlatform == TargetPlatform.android;

  @override
  Future<bool> available() => HealthService().isHealthConnectAvailable();

  @override
  Future<bool> requestWriteAccess() async {
    final types = [
      HealthDataType.WORKOUT,
      if (_android) HealthDataType.DISTANCE_DELTA,
      HealthDataType.WATER,
    ];
    return _health.requestAuthorization(
      types,
      permissions: [for (final _ in types) HealthDataAccess.READ_WRITE],
    );
  }

  Future<bool> _mayWrite(HealthDataType type) async =>
      await _health.hasPermissions(
        [type],
        permissions: const [HealthDataAccess.WRITE],
      ) ==
      true;

  @override
  Future<bool> hasWorkoutAccess() => _mayWrite(HealthDataType.WORKOUT);

  @override
  Future<bool> hasWaterAccess() => _mayWrite(HealthDataType.WATER);

  @override
  Future<bool> write({
    required String type,
    required DateTime start,
    required DateTime end,
    double? distanceMeters,
  }) =>
      _health.writeWorkoutData(
        activityType: activityTypeFor(type, android: _android),
        start: start,
        end: end,
        totalDistance:
            distanceMeters == null || distanceMeters <= 0 ? null : distanceMeters.round(),
        title: type,
        recordingMethod: RecordingMethod.manual,
      );

  @override
  Future<bool> delete({required DateTime start, required DateTime end}) =>
      _health.delete(type: HealthDataType.WORKOUT, startTime: start, endTime: end);

  @override
  Future<bool> writeWater({
    required double liters,
    required DateTime start,
    required DateTime end,
  }) =>
      _health.writeHealthData(
        value: liters,
        type: HealthDataType.WATER,
        unit: HealthDataUnit.LITER,
        startTime: start,
        endTime: end,
        recordingMethod: RecordingMethod.manual,
      );

  @override
  Future<bool> deleteWater({required DateTime start, required DateTime end}) =>
      _health.delete(type: HealthDataType.WATER, startTime: start, endTime: end);

  static HealthWorkoutActivityType activityTypeFor(String type,
          {required bool android}) =>
      switch (type) {
        'Running' => HealthWorkoutActivityType.RUNNING,
        'Walking' => HealthWorkoutActivityType.WALKING,
        'Hiking' => HealthWorkoutActivityType.HIKING,
        'Cycling' => HealthWorkoutActivityType.BIKING,
        'Swimming' => HealthWorkoutActivityType.SWIMMING,
        'Strength Training' => android
            ? HealthWorkoutActivityType.STRENGTH_TRAINING
            : HealthWorkoutActivityType.TRADITIONAL_STRENGTH_TRAINING,
        'HIIT' => HealthWorkoutActivityType.HIGH_INTENSITY_INTERVAL_TRAINING,
        'Yoga/Stretching' => HealthWorkoutActivityType.YOGA,
        _ => HealthWorkoutActivityType.OTHER,
      };
}

/// Copies workouts (manual and GPS) and water logged in this app to Health
/// Connect on Android or Apple Health on iOS, so other apps see them: ZT
/// Quests counts the water toward its water quests. Off until the person
/// turns it on in Settings or on the Water page.
///
/// Which workouts and how much water this phone wrote, and when, is kept on
/// this phone only (Health Connect is per phone, and the list says nothing
/// the server should know). Editing a workout rewrites its record; deleting
/// it removes the record. Water follows the day's logged total.
class HealthWriteback {
  HealthWriteback({HealthWorkoutSink? sink, Future<SharedPreferences>? prefs})
      : _sink = sink ?? PluginHealthWorkoutSink(),
        _prefs = prefs ?? SharedPreferences.getInstance();

  static HealthWriteback instance = HealthWriteback();

  final HealthWorkoutSink _sink;
  final Future<SharedPreferences> _prefs;

  static const enabledKey = 'health_writeback_enabled';
  static const writtenKey = 'health_writeback_written';
  static const waterKey = 'health_writeback_water';

  /// When write-back was last turned on. Workouts that ended before then
  /// are only copied when the person asks for past ones ([backfill]).
  static const sinceKey = 'health_writeback_since';

  Future<bool> get isEnabled async =>
      (await _prefs).getBool(enabledKey) ?? false;

  /// Asks for write access and turns write-back on. False when access was
  /// refused. Allowing only workouts or only water still turns it on, for
  /// that part: each write needs its own permission anyway.
  Future<bool> enable() async {
    var granted = await _sink.requestWriteAccess();
    if (!granted) {
      try {
        granted =
            await _sink.hasWorkoutAccess() || await _sink.hasWaterAccess();
      } on Object {
        granted = false;
      }
    }
    if (granted) {
      final prefs = await _prefs;
      await prefs.setBool(enabledKey, true);
      await prefs.setString(
          sinceKey, DateTime.now().toUtc().toIso8601String());
    }
    return granted;
  }

  /// Whether Health Connect / Apple Health is on this phone at all.
  Future<bool> get isAvailable async {
    try {
      return await _sink.available();
    } on Object {
      return false;
    }
  }

  /// Whether logged water reaches Health Connect: write-back is on and
  /// water may be written (people who turned write-back on before it
  /// covered water haven't been asked for that yet).
  Future<bool> get savesWater async {
    try {
      return await isEnabled && await _sink.hasWaterAccess();
    } on Object {
      return false;
    }
  }

  Future<void> disable() async =>
      (await _prefs).setBool(enabledKey, false);

  Future<Map<String, List<String>>> _written() async {
    final raw = (await _prefs).getString(writtenKey);
    if (raw == null) return {};
    try {
      return (jsonDecode(raw) as Map).map((k, v) =>
          MapEntry(k as String, [for (final s in v as List) s as String]));
    } on Object {
      return {};
    }
  }

  Future<void> _save(Map<String, List<String>> written) async =>
      (await _prefs).setString(writtenKey, jsonEncode(written));

  /// Whether a workout can go to Health Connect: one with a duration that
  /// didn't come from there (or from Google Fit, which already wrote it).
  static bool isWritable(Map<String, dynamic> data) =>
      data['source'] == null &&
      data['duration'] is num &&
      (data['duration'] as num) > 0 &&
      DateTime.tryParse(data['timestamp']?.toString() ?? '') != null;

  /// When a workout's record goes in Health Connect. The time saved with a
  /// workout is when it started, but one logged by hand right after it
  /// ended carries the time it was logged: a record from then on would sit
  /// in the future, where apps reading "today so far" (ZT Quests) miss it.
  /// Such a workout is taken to have ended when it was logged.
  ///
  /// GPS workouts (and GPX imports) keep their real start: they carry a
  /// route. Their duration is rounded to the minute, so one saved right
  /// after stopping may end up to half a minute ahead; anything within a
  /// minute of now is left as it is for the same reason.
  static (DateTime, DateTime) recordRange(Map<String, dynamic> data,
      {DateTime? now}) {
    final logged = DateTime.parse(data['timestamp'].toString());
    final length = Duration(minutes: (data['duration'] as num).toInt());
    final at = now ?? DateTime.now();
    if (data['route'] is List ||
        !logged.add(length).isAfter(at.add(const Duration(minutes: 1)))) {
      return (logged, logged.add(length));
    }
    final end = logged.isAfter(at) ? at : logged;
    return (end.subtract(length), end);
  }

  /// What a written record was made from, so a change made on another
  /// device (or the watch) can be noticed and written again.
  static String fingerprint(Map<String, dynamic> data) => [
        data['type'],
        data['duration'],
        data['timestamp'],
        data['distance_m'],
      ].join('|');

  /// Writes (or, after an edit, rewrites) one workout. Does nothing while
  /// write-back is off. Never throws: Health Connect being unavailable must
  /// not stop a workout from saving.
  Future<bool> sync(String id, Map<String, dynamic> data, {DateTime? now}) {
    final done = _workoutQueue.then((_) => _sync(id, data, now));
    _workoutQueue = done.then((_) {}, onError: (_) {});
    return done;
  }

  Future<void> _workoutQueue = Future.value();

  Future<bool> _sync(String id, Map<String, dynamic> data, DateTime? now) async {
    try {
      if (!await isEnabled || !isWritable(data)) return false;
      final written = await _written();
      if (written[id] case [final s, final e, ...]) {
        // Writing the edit before the old record is gone would leave two;
        // keep the old range so a later try can still remove it.
        final removed = await _sink.delete(
            start: DateTime.parse(s), end: DateTime.parse(e));
        if (!removed) return false;
        written.remove(id);
        await _save(written);
      }
      final (start, end) = recordRange(data, now: now);
      final ok = await _sink.write(
        type: data['type']?.toString() ?? 'Other',
        start: start,
        end: end,
        distanceMeters: (data['distance_m'] as num?)?.toDouble(),
      );
      if (ok) {
        written[id] = [
          start.toUtc().toIso8601String(),
          end.toUtc().toIso8601String(),
          fingerprint(data),
        ];
      } else {
        written.remove(id);
      }
      await _save(written);
      return ok;
    } on Object catch (e) {
      debugPrint('Health write-back failed: $e');
      return false;
    }
  }

  /// Removes a deleted workout's record, if this phone wrote one.
  Future<void> remove(String id) {
    final done = _workoutQueue.then((_) => _remove(id));
    _workoutQueue = done.then((_) {}, onError: (_) {});
    return done;
  }

  Future<void> _remove(String id) async {
    try {
      final written = await _written();
      final range = written[id];
      if (range == null || range.length < 2) return;
      final removed = await _sink.delete(
          start: DateTime.parse(range[0]), end: DateTime.parse(range[1]));
      // On failure the range is kept, so the record can still be removed.
      if (!removed) return;
      written.remove(id);
      await _save(written);
    } on Object catch (e) {
      debugPrint('Health write-back delete failed: $e');
    }
  }

  /// Brings today's and yesterday's workouts in line with the vault: the
  /// days other apps still read (ZT Quests counts them toward its workout
  /// and run quests). Covers workouts from the watch, from another device
  /// and from a restored backup, changes made there, and ones deleted
  /// there. Never throws.
  Future<void> syncRecentWorkouts(FitnessVault vault, {DateTime? now}) async {
    try {
      if (!await isEnabled) return;
      final at = now ?? DateTime.now();
      final since = DateTime(at.year, at.month, at.day - 1);
      bool recent(DateTime t) => !t.isBefore(since);
      final on = DateTime.tryParse((await _prefs).getString(sinceKey) ?? '');
      final kept = <String>{};
      for (final w in await vault.fetchWorkouts()) {
        kept.add(w.id);
        if (!isWritable(w.data)) continue;
        if (!recent(DateTime.parse(w.data['timestamp'].toString()).toLocal())) {
          continue;
        }
        // "Only new ones": not a workout that was over before it was on.
        if (on != null && recordRange(w.data, now: at).$2.isBefore(on)) {
          continue;
        }
        final note = (await _written())[w.id];
        // Old notes (no fingerprint) are taken as up to date.
        if (note != null && (note.length < 3 || note[2] == fingerprint(w.data))) {
          continue;
        }
        await sync(w.id, w.data, now: now);
      }
      for (final e in (await _written()).entries.toList()) {
        if (kept.contains(e.key) || e.value.length < 2) continue;
        final end = DateTime.tryParse(e.value[1]);
        if (end == null || !recent(end.toLocal())) continue;
        // Saved while this pass was writing: not deleted after all.
        if (await vault.getWorkout(e.key) != null) continue;
        await remove(e.key);
      }
    } on Object catch (e) {
      debugPrint('Health workout write-back failed: $e');
    }
  }

  /// Writes every logged workout this phone hasn't written yet (for turning
  /// write-back on with history already in the vault). Returns how many
  /// were written.
  Future<int> backfill(FitnessVault vault) async {
    if (!await isEnabled) return 0;
    final written = await _written();
    var count = 0;
    for (final w in await vault.fetchWorkouts()) {
      if (written.containsKey(w.id) || !isWritable(w.data)) continue;
      if (await sync(w.id, w.data)) count++;
    }
    return count;
  }

  // ---------------------------------------------------------------------------
  // Water
  // ---------------------------------------------------------------------------

  /// Water is kept per day as one total, so write-back follows that total:
  /// what this phone wrote for a day is remembered as
  /// `[liters, first record start, last record end]`.
  Future<Map<String, List<Object?>>> _waterWritten() async {
    final raw = (await _prefs).getString(waterKey);
    if (raw == null) return {};
    try {
      return (jsonDecode(raw) as Map)
          .map((k, v) => MapEntry(k as String, List<Object?>.from(v as List)));
    } on Object {
      return {};
    }
  }

  Future<void> _saveWater(Map<String, List<Object?>> written) async {
    // Old days are never read again by other apps; a later edit to one
    // clears that day in Health Connect before writing it (see [syncWater]).
    if (written.length > _waterDaysKept) {
      final keys = written.keys.toList()..sort();
      for (final k in keys.take(keys.length - _waterDaysKept)) {
        written.remove(k);
      }
    }
    await (await _prefs).setString(waterKey, jsonEncode(written));
  }

  static const _waterDaysKept = 60;

  /// Health Connect stores millilitres; smaller differences are rounding.
  static const _waterTolerance = 0.0005;

  Future<void> _waterQueue = Future.value();

  /// Makes Health Connect hold [loggedLiters] of water from this app for
  /// [dateKey] (the part logged here, not what Health Connect reported).
  ///
  /// More water on today's date adds a record at the time it was logged;
  /// anything else (water taken off, an older day) replaces the day's
  /// records with one for the new total. Does nothing while write-back is
  /// off or water isn't allowed. Never throws.
  Future<bool> syncWater(String dateKey, num loggedLiters, {DateTime? now}) {
    final done = _waterQueue.then((_) => _syncWater(dateKey, loggedLiters, now));
    _waterQueue = done.then((_) {}, onError: (_) {});
    return done;
  }

  Future<bool> _syncWater(String dateKey, num loggedLiters, DateTime? at) async {
    try {
      final day = DateTime.tryParse(dateKey);
      if (day == null || !await savesWater) return false;
      final target = loggedLiters < 0 ? 0.0 : loggedLiters.toDouble();
      final written = await _waterWritten();
      final entry = written[dateKey];
      final have = entry == null ? 0.0 : (entry[0] as num).toDouble();
      final now = at ?? DateTime.now();
      final dayStart = DateTime(day.year, day.month, day.day);
      final dayEnd = DateTime(day.year, day.month, day.day + 1);
      final isToday = !now.isBefore(dayStart) && now.isBefore(dayEnd);
      // A day with no note of what was written is only known to be in step
      // when it is today (nothing written yet). An older one may still hold
      // records whose note was dropped, so it is cleared below even when
      // the new total is zero.
      if ((target - have).abs() < _waterTolerance &&
          (entry != null || isToday)) {
        return true;
      }

      // When the glass was drunk: just now for today, midday otherwise.
      var end = isToday ? now : dayStart.add(const Duration(hours: 12, minutes: 1));
      var start = end.subtract(const Duration(minutes: 1));
      if (start.isBefore(dayStart)) {
        start = dayStart;
        if (!end.isAfter(start)) end = start.add(const Duration(seconds: 1));
      }

      if (isToday && entry != null && target > have) {
        final ok = await _sink.writeWater(
            liters: target - have, start: start, end: end);
        if (!ok) return false;
        written[dateKey] = [target, entry[1], end.toUtc().toIso8601String()];
        await _saveWater(written);
        return true;
      }

      if (entry != null || !isToday) {
        // Replace what the day holds. Without a note of what was written
        // (an old day, or this phone's list was cleared), the whole day is
        // cleared: only this app's own records can be removed.
        var from = dayStart;
        var to = dayEnd;
        if (entry != null) {
          final s = DateTime.parse(entry[1] as String);
          final e = DateTime.parse(entry[2] as String);
          if (s.isBefore(from)) from = s;
          if (e.isAfter(to)) to = e;
        }
        final removed = await _sink.deleteWater(
            start: from, end: to.add(const Duration(seconds: 1)));
        // Kept on failure, so a later try can still remove the records.
        // (With nothing noted there may be nothing to remove, which Apple
        // Health reports as a failure.)
        if (!removed && entry != null) return false;
        written.remove(dateKey);
        if (target < _waterTolerance) {
          // Noted as empty, so the day isn't cleared again on every check.
          written[dateKey] = [
            0,
            dayStart.toUtc().toIso8601String(),
            dayEnd.toUtc().toIso8601String(),
          ];
        }
        await _saveWater(written);
      }
      if (target < _waterTolerance) return true;
      final ok = await _sink.writeWater(liters: target, start: start, end: end);
      if (!ok) return false;
      written[dateKey] = [
        target,
        start.toUtc().toIso8601String(),
        end.toUtc().toIso8601String(),
      ];
      await _saveWater(written);
      return true;
    } on Object catch (e) {
      debugPrint('Health water write-back failed: $e');
      return false;
    }
  }

  /// Brings today and yesterday in line with the vault: the days other
  /// apps still read. Covers water from the watch, from another device and
  /// from a restored backup, and the moment write-back is turned on.
  Future<void> syncRecentWater(FitnessVault vault, {DateTime? now}) async {
    try {
      if (!await savesWater) return;
      final today = now ?? DateTime.now();
      for (final day in [
        DateTime(today.year, today.month, today.day - 1),
        today,
      ]) {
        final key = FitnessVault.dateKeyOf(day);
        await syncWater(key, (await vault.waterFor(key)).logged, now: now);
      }
    } on Object catch (e) {
      debugPrint('Health water write-back failed: $e');
    }
  }
}
