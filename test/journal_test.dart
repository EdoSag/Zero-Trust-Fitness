import 'package:flutter_test/flutter_test.dart';
import 'package:zerotrust_fitness/core/storage/fitness_vault.dart';

import 'support.dart';

Future<Map<String, num>> _day(FitnessVault v, String key) async {
  for (final d in await v.fetchDailyMetrics()) {
    if (d['date_key'] == key) return d['metrics'] as Map<String, num>;
  }
  return const {};
}

void main() {
  // Local noon, so the day key doesn't depend on the test machine's zone.
  final monday = DateTime(2026, 11, 9, 12).toIso8601String();
  final tuesday = DateTime(2026, 11, 10, 12).toIso8601String();

  group('workouts and Heart Points', () {
    test('logging adds points; editing moves them instead of adding again',
        () async {
      final v = testVault();
      final id = await v.logWorkout({
        'type': 'Running',
        'duration': 30,
        'intensity': 8, // vigorous: 2 pts/min
        'timestamp': monday,
      });
      expect((await _day(v, '2026-11-09'))['heart_points'], 60);

      await v.logWorkout({'duration': 20}, id: id);
      expect((await _day(v, '2026-11-09'))['heart_points'], 40);

      await v.logWorkout({'timestamp': tuesday}, id: id);
      expect((await _day(v, '2026-11-09'))['heart_points'], 0);
      expect((await _day(v, '2026-11-10'))['heart_points'], 40);
      expect((await v.getWorkout(id))!.data['heart_points'], 40);
    });

    test('editing a GPS workout keeps its route and splits', () async {
      final v = testVault();
      final id = await v.logWorkout({
        'type': 'Running',
        'duration': 25,
        'intensity': 7,
        'timestamp': monday,
        'distance_m': 5000.0,
        'route': [
          {'lat': 1.0, 'lng': 2.0},
        ],
        'splits': [
          {'index': 1, 'seconds': 300},
        ],
      });
      await v.logWorkout({'type': 'Hiking', 'duration': 26}, id: id);
      final w = (await v.getWorkout(id))!.data;
      expect(w['type'], 'Hiking');
      expect(w['route'], hasLength(1));
      expect(w['splits'], hasLength(1));
      expect(w['distance_m'], 5000.0);
    });

    test('deleting takes the points back, also for workouts saved before '
        'points were recorded', () async {
      final v = testVault();
      // How older versions saved: points merged into the day, none on the
      // workout.
      final old = {
        'type': 'Walking',
        'duration': 30,
        'intensity': 5, // moderate: 1 pt/min
        'timestamp': monday,
      };
      final id = await v.saveWorkout(old);
      await v.mergeDailyMetrics(
          dateKey: '2026-11-09', incoming: {'heart_points': 30});
      await v.syncFromHealthConnect(
          dateKey: '2026-11-09', hcMetrics: {'heart_points': 12});
      expect((await _day(v, '2026-11-09'))['heart_points'], 42);

      await v.removeWorkout(id);
      final m = await _day(v, '2026-11-09');
      expect(m['heart_points'], 12, reason: 'Health Connect share stays');
      expect(await v.fetchWorkouts(), isEmpty);
    });

    test('imported and Health Connect workouts carry no points', () {
      expect(
          FitnessVault.workoutHeartPoints(
              {'duration': 30, 'intensity': 9, 'source': 'google_fit'}),
          0);
      expect(
          FitnessVault.workoutHeartPoints(
              {'type': 'HealthDataType.WORKOUT', 'value': 1}),
          0);
    });
  });

  group('manual entries', () {
    test('the journal lists typed-in metrics, not workout points', () async {
      final v = testVault();
      await v.syncFromHealthConnect(
          dateKey: '2026-11-09', hcMetrics: {'steps': 4000});
      await v.mergeDailyMetrics(
          dateKey: '2026-11-09', incoming: {'water_l': 0.5, 'weight_kg': 71.4});
      await v.mergeDailyMetrics(
          dateKey: '2026-11-09', incoming: {'water_l': 0.75});
      await v.logWorkout({
        'type': 'Running',
        'duration': 10,
        'intensity': 8,
        'timestamp': monday,
      });

      final entries = await v.fetchManualEntries();
      expect({for (final e in entries) e.metricKey: e.value},
          {'water_l': 1.25, 'weight_kg': 71.4});
    });

    test('editing and deleting an entry keeps Health Connect data', () async {
      final v = testVault();
      await v.syncFromHealthConnect(
          dateKey: '2026-11-09', hcMetrics: {'steps': 4000});
      await v.mergeDailyMetrics(
          dateKey: '2026-11-09', incoming: {'steps': 1000});
      var entry = (await v.fetchManualEntries()).single;

      await v.editManualEntry(entry, 1500);
      expect((await _day(v, '2026-11-09'))['steps'], 5500);

      entry = (await v.fetchManualEntries()).single;
      await v.deleteManualEntry(entry);
      expect((await _day(v, '2026-11-09'))['steps'], 4000);
      expect(await v.fetchManualEntries(), isEmpty);
    });

    test('hand-entered Heart Points can be edited without touching the '
        "workouts' share", () async {
      final v = testVault();
      await v.logWorkout({
        'type': 'Running',
        'duration': 10,
        'intensity': 8, // 20 pts
        'timestamp': monday,
      });
      await v.mergeDailyMetrics(
          dateKey: '2026-11-09', incoming: {'heart_points': 5});
      final entry = (await v.fetchManualEntries()).single;
      expect(entry.value, 5);

      await v.editManualEntry(entry, 8);
      expect((await _day(v, '2026-11-09'))['heart_points'], 28);
      await v.deleteManualEntry((await v.fetchManualEntries()).single);
      expect((await _day(v, '2026-11-09'))['heart_points'], 20);
    });
  });

  group('importDayTotals', () {
    test('an export total that includes hand-entered steps adds only the '
        'missing part', () async {
      final v = testVault();
      await v.mergeDailyMetrics(
          dateKey: '2026-11-07', incoming: {'steps': 5000});
      await v.importDayTotals('2026-11-07', {'steps': 5000});
      expect((await _day(v, '2026-11-07'))['steps'], 5000);
      await v.importDayTotals('2026-11-07', {'steps': 7000});
      final m = await _day(v, '2026-11-07');
      expect(m['steps'], 7000);
      expect(m['steps_manual'], 5000);
      expect(m['steps_hc'], 2000);
    });


    test('raises additive totals and fills missing readings only', () async {
      final v = testVault();
      await v.syncFromHealthConnect(
          dateKey: '2026-11-09', hcMetrics: {'steps': 9000, 'weight_kg': 70});
      await v.importDayTotals(
          '2026-11-09', {'steps': 7000, 'heart_points': 15, 'weight_kg': 72});
      await v.importDayTotals('2026-11-08', {'steps': 3000, 'weight_kg': 72});

      final mon = await _day(v, '2026-11-09');
      expect(mon['steps'], 9000);
      expect(mon['heart_points'], 15);
      expect(mon['weight_kg'], 70);
      final sun = await _day(v, '2026-11-08');
      expect(sun['steps'], 3000);
      expect(sun['weight_kg'], 72);
    });
  });
}
