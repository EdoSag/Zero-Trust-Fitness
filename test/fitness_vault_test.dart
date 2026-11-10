import 'package:flutter_test/flutter_test.dart';
import 'package:zero_trust_core/zero_trust_core.dart';
import 'package:zerotrust_fitness/core/storage/fitness_vault.dart';

import 'support.dart';

void main() {
  group('item ids', () {
    test('named ids are opaque, stable per account, different across accounts',
        () async {
      final a = testVault(idKey: List<int>.filled(32, 1));
      final a2 = testVault(idKey: List<int>.filled(32, 1));
      final b = testVault(idKey: List<int>.filled(32, 2));
      final id = await a.idFor('day:2026-11-09');
      expect(id, hasLength(32));
      expect(id, isNot(contains('2026')));
      expect(await a2.idFor('day:2026-11-09'), id);
      expect(await b.idFor('day:2026-11-09'), isNot(id));
    });

    test('a legacy workout gets the same id from any copy of it', () async {
      final v = testVault();
      final w = {'type': 'Running', 'duration': 30, 'timestamp': '2026-10-01T07:30:00.000'};
      expect(await v.legacyWorkoutId({...w, 'intensity': 9}),
          await v.legacyWorkoutId(w));
      expect(await v.legacyWorkoutId({...w, 'type': 'Walking'}),
          isNot(await v.legacyWorkoutId(w)));
    });
  });

  group('daily metrics', () {
    test('manual entries add on top of Health Connect, and survive a refresh',
        () async {
      final v = testVault();
      await v.syncFromHealthConnect(
          dateKey: '2026-11-09', hcMetrics: {'steps': 5000, 'heart_points': 10});
      await v.mergeDailyMetrics(
          dateKey: '2026-11-09', incoming: {'steps': 1200, 'weight_kg': 70.2});
      await v.syncFromHealthConnect(
          dateKey: '2026-11-09', hcMetrics: {'steps': 6000, 'heart_points': 12});

      final day = (await v.fetchDailyMetrics()).single;
      final m = day['metrics'] as Map<String, num>;
      expect(day['date_key'], '2026-11-09');
      expect(m['steps'], 7200);
      expect(m['steps_hc'], 6000);
      expect(m['steps_manual'], 1200);
      expect(m['weight_kg'], 70.2);
      expect(day['steps'], 7200);
      expect(day['heart_points'], 12);
    });

    test('sleep takes the larger of Health Connect and manual', () async {
      final v = testVault();
      await v.mergeDailyMetrics(
          dateKey: '2026-11-09', incoming: {'sleep_asleep_min': 420});
      await v.syncFromHealthConnect(
          dateKey: '2026-11-09', hcMetrics: {'sleep_asleep_min': 380});
      final m = (await v.fetchDailyMetrics()).single['metrics'] as Map;
      expect(m['sleep_asleep_min'], 420);
    });

    test('raiseHealthConnectTotals never lowers a day', () async {
      final v = testVault();
      await v.upsertDailyMetrics(
          dateKey: '2026-11-08', metrics: {'steps': 8000, 'heart_points': 20});
      await v.raiseHealthConnectTotals(
          dateKey: '2026-11-08', hcMetrics: {'steps': 3000, 'heart_points': 30});
      final m = (await v.fetchDailyMetrics()).single['metrics'] as Map;
      expect(m['steps'], 8000);
      expect(m['heart_points'], 30);
    });

    test('an unchanged refresh writes nothing, so nothing is synced',
        () async {
      final store = InMemoryItemStore();
      final writer = StoreWriter(store);
      final v = FitnessVault(
          store: store, writer: writer, idKey: List<int>.filled(32, 3));
      await v.syncFromHealthConnect(
          dateKey: '2026-11-09', hcMetrics: {'steps': 5000});
      await v.syncFromHealthConnect(
          dateKey: '2026-11-09', hcMetrics: {'steps': 5000});
      expect(writer.saved, hasLength(1));
    });

    test('days are newest first', () async {
      final v = testVault();
      for (final d in ['2026-11-01', '2026-11-03', '2026-11-02']) {
        await v.upsertDailyMetrics(dateKey: d, metrics: {'steps': 1});
      }
      expect([for (final r in await v.fetchDailyMetrics()) r['date_key']],
          ['2026-11-03', '2026-11-02', '2026-11-01']);
    });
  });

  group('workouts', () {
    test('save, edit in place, delete; newest first', () async {
      final v = testVault();
      final a = await v.saveWorkout(
          {'type': 'Running', 'duration': 30, 'timestamp': '2026-11-01T07:00:00Z'});
      await v.saveWorkout(
          {'type': 'Yoga', 'duration': 20, 'timestamp': '2026-11-02T07:00:00Z'});
      expect([for (final w in await v.fetchWorkouts()) w.data['type']],
          ['Yoga', 'Running']);

      await v.saveWorkout(
          {'type': 'Running', 'duration': 35, 'timestamp': '2026-11-01T07:00:00Z'},
          id: a);
      final edited = (await v.fetchWorkouts()).firstWhere((w) => w.id == a);
      expect(edited.data['duration'], 35);
      expect(edited.data.containsKey('kind'), isFalse);

      await v.deleteWorkout(a);
      expect(await v.fetchWorkouts(), hasLength(1));
    });

    test('keeps fields written by a newer version of the app', () async {
      final store = InMemoryItemStore();
      final v = testVault(store: store);
      final id = await v.saveWorkout({'type': 'Run', 'duration': 10});
      final item = await store.get(id);
      await store.put(LocalItem(
          itemId: id,
          updatedAt: item!.updatedAt,
          json: {...item.json!, 'heartRateZones': [1, 2]}));
      await v.saveWorkout({'type': 'Run', 'duration': 12}, id: id);
      expect((await store.get(id))!.json!['heartRateZones'], [1, 2]);
    });
  });

  test('achievements, goals and templates', () async {
    final v = testVault();
    await v.insertAchievementIfAbsent('first_workout', DateTime.utc(2026, 1, 1));
    await v.insertAchievementIfAbsent('first_workout', DateTime.utc(2026, 5, 5));
    final medals = await v.fetchAchievements();
    expect(medals.single['id'], 'first_workout');
    expect(medals.single['unlocked_at'], startsWith('2026-01-01'));
    expect(await v.hasAchievement('first_workout'), isTrue);

    await v.upsertGoal(metricKey: 'steps', targetValue: 8000, period: 'daily');
    await v.upsertGoal(metricKey: 'steps', targetValue: 10000, period: 'daily');
    expect((await v.fetchGoals()).single['target_value'], 10000);
    await v.deleteGoal('steps');
    expect(await v.fetchGoals(), isEmpty);

    final t = await v.saveTemplate(
        name: 'Run', activityType: 'Running', data: {'duration_minutes': 25});
    await v.saveTemplate(
        id: t, name: 'Long run', activityType: 'Running', data: {'duration_minutes': 60});
    final templates = await v.fetchTemplates();
    expect(templates.single.name, 'Long run');
    expect(templates.single.data['duration_minutes'], 60);
  });

  test('clearActivityData deletes activity, keeps goals and templates',
      () async {
    final v = testVault();
    await v.saveWorkout({'type': 'Run', 'duration': 10});
    await v.upsertDailyMetrics(dateKey: '2026-11-09', metrics: {'steps': 1});
    await v.insertAchievementIfAbsent('x', DateTime.utc(2026));
    await v.upsertGoal(metricKey: 'steps', targetValue: 1, period: 'daily');
    await v.saveTemplate(name: 'T', activityType: 'Run', data: const {});
    await v.logMeal(FitnessMeal(
        id: 'm', name: 'Soup', mealType: 'lunch', at: DateTime.utc(2026)));

    await v.clearActivityData();
    expect(await v.countsByKind(), {
      'workout': 0,
      'day': 0,
      'achievement': 0,
      'goal': 1,
      'template': 1,
      'meal': 0,
    });
  });
}
