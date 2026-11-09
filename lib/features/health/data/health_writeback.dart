import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:health/health.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zerotrust_fitness/core/storage/fitness_vault.dart';

/// The calls write-back makes to Health Connect / Apple Health, so tests can
/// stand in for them.
abstract interface class HealthWorkoutSink {
  Future<bool> requestWriteAccess();
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
}

class PluginHealthWorkoutSink implements HealthWorkoutSink {
  PluginHealthWorkoutSink([Health? health]) : _health = health ?? Health();
  final Health _health;

  bool get _android => defaultTargetPlatform == TargetPlatform.android;

  @override
  Future<bool> requestWriteAccess() async {
    final types = [
      HealthDataType.WORKOUT,
      if (_android) HealthDataType.DISTANCE_DELTA,
    ];
    return _health.requestAuthorization(
      types,
      permissions: [for (final _ in types) HealthDataAccess.READ_WRITE],
    );
  }

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

/// Copies workouts logged in this app (manual and GPS) to Health Connect on
/// Android or Apple Health on iOS, so other apps see them. Off until the
/// person turns it on in Settings.
///
/// Which workouts this phone wrote, and when they ran, is kept on this phone
/// only (Health Connect is per phone, and the list says nothing the server
/// should know). Editing a workout rewrites its record; deleting it removes
/// the record.
class HealthWriteback {
  HealthWriteback({HealthWorkoutSink? sink, Future<SharedPreferences>? prefs})
      : _sink = sink ?? PluginHealthWorkoutSink(),
        _prefs = prefs ?? SharedPreferences.getInstance();

  static HealthWriteback instance = HealthWriteback();

  final HealthWorkoutSink _sink;
  final Future<SharedPreferences> _prefs;

  static const enabledKey = 'health_writeback_enabled';
  static const writtenKey = 'health_writeback_written';

  Future<bool> get isEnabled async =>
      (await _prefs).getBool(enabledKey) ?? false;

  /// Asks for write access and turns write-back on. False when access was
  /// refused.
  Future<bool> enable() async {
    final granted = await _sink.requestWriteAccess();
    if (granted) await (await _prefs).setBool(enabledKey, true);
    return granted;
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

  /// Writes (or, after an edit, rewrites) one workout. Does nothing while
  /// write-back is off. Never throws: Health Connect being unavailable must
  /// not stop a workout from saving.
  Future<bool> sync(String id, Map<String, dynamic> data) async {
    try {
      if (!await isEnabled || !isWritable(data)) return false;
      final written = await _written();
      if (written[id] case [final s, final e]) {
        await _sink.delete(start: DateTime.parse(s), end: DateTime.parse(e));
      }
      final start = DateTime.parse(data['timestamp'].toString());
      final end = start.add(Duration(minutes: (data['duration'] as num).toInt()));
      final ok = await _sink.write(
        type: data['type']?.toString() ?? 'Other',
        start: start,
        end: end,
        distanceMeters: (data['distance_m'] as num?)?.toDouble(),
      );
      if (ok) {
        written[id] = [start.toUtc().toIso8601String(), end.toUtc().toIso8601String()];
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
  Future<void> remove(String id) async {
    try {
      final written = await _written();
      final range = written.remove(id);
      if (range == null) return;
      await _sink.delete(
          start: DateTime.parse(range[0]), end: DateTime.parse(range[1]));
      await _save(written);
    } on Object catch (e) {
      debugPrint('Health write-back delete failed: $e');
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
}
