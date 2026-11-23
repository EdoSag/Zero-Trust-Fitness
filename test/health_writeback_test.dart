import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zerotrust_fitness/features/health/data/health_writeback.dart';

import 'support.dart';

class FakeSink implements HealthWorkoutSink {
  final writes = <(String, DateTime, DateTime, double?)>[];
  final deletes = <(DateTime, DateTime)>[];
  final waterWrites = <(double, DateTime, DateTime)>[];
  final waterDeletes = <(DateTime, DateTime)>[];
  bool grant = true;
  bool deleteWorks = true;
  bool workoutAccess = false;
  bool waterAccess = false;
  bool waterWriteWorks = true;

  /// Runs during a workout write (something else saving meanwhile).
  Future<void> Function()? onWrite;

  /// Water this app holds in "Health Connect": what other apps would read.
  double get waterHeld => waterWrites.fold(0, (sum, w) => sum + w.$1);

  @override
  Future<bool> available() async => true;

  @override
  Future<bool> requestWriteAccess() async {
    if (grant) workoutAccess = waterAccess = true;
    return grant;
  }

  @override
  Future<bool> hasWorkoutAccess() async => workoutAccess;

  @override
  Future<bool> hasWaterAccess() async => waterAccess;

  @override
  Future<bool> writeWater({
    required double liters,
    required DateTime start,
    required DateTime end,
  }) async {
    if (!waterWriteWorks) return false;
    waterWrites.add((liters, start, end));
    return true;
  }

  @override
  Future<bool> deleteWater({
    required DateTime start,
    required DateTime end,
  }) async {
    waterDeletes.add((start, end));
    if (!deleteWorks) return false;
    waterWrites.removeWhere((w) => !w.$2.isBefore(start) && !w.$3.isAfter(end));
    return true;
  }

  @override
  Future<bool> write({
    required String type,
    required DateTime start,
    required DateTime end,
    double? distanceMeters,
  }) async {
    writes.add((type, start, end, distanceMeters));
    final run = onWrite;
    onWrite = null;
    await run?.call();
    return true;
  }

  @override
  Future<bool> delete({required DateTime start, required DateTime end}) async {
    deletes.add((start, end));
    return deleteWorks;
  }
}

void main() {
  late FakeSink sink;
  late HealthWriteback wb;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    sink = FakeSink();
    wb = HealthWriteback(sink: sink);
  });

  final run = {
    'type': 'Running',
    'duration': 30,
    'intensity': 7,
    'timestamp': '2026-11-09T07:00:00.000Z',
    'distance_m': 5000.0,
  };

  test('does nothing until turned on', () async {
    expect(await wb.sync('a', run), isFalse);
    expect(sink.writes, isEmpty);
  });

  test('refused access leaves it off', () async {
    sink.grant = false;
    expect(await wb.enable(), isFalse);
    expect(await wb.isEnabled, isFalse);
  });

  test('writes, rewrites after an edit, and removes on delete', () async {
    await wb.enable();
    expect(await wb.sync('a', run), isTrue);
    expect(sink.writes.single.$1, 'Running');
    expect(sink.writes.single.$3,
        DateTime.parse('2026-11-09T07:30:00.000Z'));
    expect(sink.writes.single.$4, 5000.0);

    await wb.sync('a', {...run, 'duration': 40});
    expect(sink.deletes, hasLength(1), reason: 'old record replaced');
    expect(sink.writes, hasLength(2));

    await wb.remove('a');
    expect(sink.deletes, hasLength(2));
    await wb.remove('a');
    expect(sink.deletes, hasLength(2), reason: 'nothing left to remove');
  });

  test('a failed delete keeps the record tracked and writes no duplicate',
      () async {
    await wb.enable();
    await wb.sync('a', run);
    sink.deleteWorks = false;
    expect(await wb.sync('a', {...run, 'duration': 40}), isFalse);
    expect(sink.writes, hasLength(1));
    await wb.remove('a');
    sink.deleteWorks = true;
    await wb.remove('a');
    expect(sink.deletes, hasLength(3), reason: 'still removable later');
  });

  test('backfill copies logged workouts once, skipping imported ones',
      () async {
    final v = testVault();
    await v.saveWorkout(run, id: 'run');
    await v.saveWorkout({...run, 'source': 'google_fit'}, id: 'fit');
    await v.saveWorkout(
        {'type': 'HealthDataType.STEPS', 'value': 100, 'timestamp': run['timestamp']},
        id: 'hc');
    await wb.enable();
    expect(await wb.backfill(v), 1);
    expect(await wb.backfill(v), 0);
    expect(sink.writes, hasLength(1));
  });

  group('water', () {
    final now = DateTime(2026, 11, 20, 14, 5);
    const today = '2026-11-20';

    test('does nothing until turned on', () async {
      expect(await wb.syncWater(today, 0.25, now: now), isFalse);
      expect(sink.waterWrites, isEmpty);
    });

    test('each glass logged today is written when it was drunk', () async {
      await wb.enable();
      expect(await wb.syncWater(today, 0.25, now: now), isTrue);
      final later = now.add(const Duration(hours: 1));
      expect(await wb.syncWater(today, 0.75, now: later), isTrue);
      expect(sink.waterWrites, hasLength(2));
      expect(sink.waterWrites.first.$1, 0.25);
      expect(sink.waterWrites.first.$3, now);
      expect(sink.waterWrites.first.$2.isBefore(now), isTrue);
      expect(sink.waterWrites.last.$1, 0.5);
      expect(sink.waterWrites.last.$3, later);
      expect(sink.waterDeletes, isEmpty);
      expect(sink.waterHeld, 0.75);
    });

    test('the same total again writes nothing', () async {
      await wb.enable();
      await wb.syncWater(today, 0.5, now: now);
      await wb.syncWater(today, 0.5, now: now.add(const Duration(minutes: 5)));
      expect(sink.waterWrites, hasLength(1));
    });

    test('taking a glass off replaces the day with the new total', () async {
      await wb.enable();
      await wb.syncWater(today, 0.25, now: now);
      await wb.syncWater(today, 0.75, now: now.add(const Duration(minutes: 5)));
      expect(
        await wb.syncWater(today, 0.5, now: now.add(const Duration(minutes: 9))),
        isTrue,
      );
      expect(sink.waterDeletes, hasLength(1));
      expect(sink.waterHeld, 0.5);
      expect(sink.waterWrites, hasLength(1));

      await wb.syncWater(today, 0, now: now.add(const Duration(minutes: 10)));
      expect(sink.waterHeld, 0);
    });

    test('a failed delete keeps the day tracked and writes no duplicate',
        () async {
      await wb.enable();
      await wb.syncWater(today, 0.75, now: now);
      sink.deleteWorks = false;
      expect(await wb.syncWater(today, 0.25, now: now), isFalse);
      expect(sink.waterHeld, 0.75);
      sink.deleteWorks = true;
      expect(await wb.syncWater(today, 0.25, now: now), isTrue);
      expect(sink.waterHeld, 0.25);
    });

    test('a failed write is tried again', () async {
      await wb.enable();
      sink.waterWriteWorks = false;
      expect(await wb.syncWater(today, 0.25, now: now), isFalse);
      sink.waterWriteWorks = true;
      expect(await wb.syncWater(today, 0.25, now: now), isTrue);
      expect(sink.waterHeld, 0.25);
    });

    test('an older day gets one record inside that day', () async {
      await wb.enable();
      expect(await wb.syncWater('2026-11-18', 1.5, now: now), isTrue);
      expect(sink.waterWrites.single.$1, 1.5);
      expect(sink.waterWrites.single.$2.day, 18);
      expect(sink.waterWrites.single.$3.day, 18);
      // More on that day replaces the record instead of adding one, so two
      // records never share the same minute.
      await wb.syncWater('2026-11-18', 2.0, now: now);
      expect(sink.waterWrites.single.$1, 2.0);
    });

    test('just after midnight the record stays inside the new day', () async {
      await wb.enable();
      final midnight = DateTime(2026, 11, 20, 0, 0, 20);
      await wb.syncWater(today, 0.25, now: midnight);
      final w = sink.waterWrites.single;
      expect(w.$2, DateTime(2026, 11, 20));
      expect(w.$3.isAfter(w.$2), isTrue);
    });

    test('write-back turned on before water was covered waits for access',
        () async {
      // Workouts only, as granted by an older version.
      SharedPreferences.setMockInitialValues({HealthWriteback.enabledKey: true});
      sink.workoutAccess = true;
      wb = HealthWriteback(sink: sink);
      expect(await wb.savesWater, isFalse);
      expect(await wb.syncWater(today, 0.25, now: now), isFalse);
      expect(sink.waterWrites, isEmpty);

      await wb.enable();
      expect(await wb.savesWater, isTrue);
      expect(await wb.syncWater(today, 0.25, now: now), isTrue);
    });

    test('allowing workouts but not water still turns on workouts', () async {
      sink.grant = false;
      sink.workoutAccess = true;
      expect(await wb.enable(), isTrue);
      expect(await wb.isEnabled, isTrue);
      expect(await wb.savesWater, isFalse);
      expect(await wb.sync('a', run), isTrue);
    });

    test('allowing water but not workouts still saves water', () async {
      sink.grant = false;
      sink.waterAccess = true;
      expect(await wb.enable(), isTrue);
      expect(await wb.savesWater, isTrue);
      expect(await wb.syncWater(today, 0.25, now: now), isTrue);
      expect(sink.waterHeld, 0.25);
    });

    test('an older day with no note left is cleared when its water is taken '
        'off', () async {
      await wb.enable();
      await wb.syncWater('2026-11-18', 1.5, now: now);
      // The phone's note of that day is gone (dropped as too old).
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(HealthWriteback.waterKey);

      expect(await wb.syncWater('2026-11-18', 0, now: now), isTrue);
      expect(sink.waterHeld, 0, reason: 'the old record is removed');
      final clears = sink.waterDeletes.length;
      // Checking the empty day again doesn't clear it again.
      await wb.syncWater('2026-11-18', 0, now: now);
      expect(sink.waterDeletes, hasLength(clears));
      // And water added to it later is written once.
      await wb.syncWater('2026-11-18', 0.5, now: now);
      expect(sink.waterHeld, 0.5);
    });

    test('today and yesterday follow the vault, Health Connect water aside',
        () async {
      final v = testVault();
      await v.addWater(today, 0.5);
      await v.addWater('2026-11-19', 1.0);
      await v.addWater('2026-11-10', 2.0);
      // Water another app recorded is not written back.
      await v.syncFromHealthConnect(dateKey: today, hcMetrics: {'water_l': 0.3});
      await wb.enable();
      await wb.syncRecentWater(v, now: now);
      expect(sink.waterHeld, 1.5);
      await wb.syncRecentWater(v, now: now);
      expect(sink.waterWrites, hasLength(2), reason: 'nothing new to write');

      await v.addWater(today, 0.25);
      await wb.syncRecentWater(v, now: now.add(const Duration(minutes: 3)));
      expect(sink.waterHeld, 1.75);
    });
  });

  group('workouts other apps read today', () {
    // Local times, as the phone logs them.
    final now = DateTime(2026, 11, 20, 18, 0);
    Map<String, dynamic> workout(DateTime at, {int minutes = 30}) => {
          'type': 'Running',
          'duration': minutes,
          'intensity': 6,
          'timestamp': at.toIso8601String(),
        };

    test('one logged right after it ended is recorded as ending then',
        () async {
      await wb.enable();
      // Logged at 18:00 with the time left at "now": 17:30 to 18:00.
      expect(await wb.sync('a', workout(now), now: now), isTrue);
      expect(sink.writes.single.$2, DateTime(2026, 11, 20, 17, 30));
      expect(sink.writes.single.$3, now);

      // One whose start was picked is left as it was.
      await wb.sync('b', workout(DateTime(2026, 11, 20, 7)), now: now);
      expect(sink.writes.last.$2, DateTime(2026, 11, 20, 7));
      expect(sink.writes.last.$3, DateTime(2026, 11, 20, 7, 30));

      // A GPS run saved right after stopping keeps its real start, even
      // when its duration was rounded up past now.
      final started = now.subtract(const Duration(minutes: 10, seconds: 31));
      await wb.sync(
          'gps',
          {
            ...workout(started, minutes: 11),
            'distance_m': 2000.0,
            'route': <Object>[],
          },
          now: now);
      expect(sink.writes.last.$2, started);

      // Started 10 minutes ago and 30 long: ended when it was logged.
      await wb.sync('c', workout(now.subtract(const Duration(minutes: 10))),
          now: now);
      expect(sink.writes.last.$3, DateTime(2026, 11, 20, 17, 50));
    });

    test('an edit that leaves the time alone keeps the range written',
        () async {
      await wb.enable();
      // Logged at 18:00 right after it ended: 17:30 to 18:00.
      await wb.sync('a', workout(now), now: now);
      // The distance is added at 19:00; the time wasn't touched.
      await wb.sync('a', {...workout(now), 'distance_m': 5000.0},
          now: now.add(const Duration(hours: 1)));
      expect(sink.writes.last.$2, DateTime(2026, 11, 20, 17, 30));
      expect(sink.writes.last.$3, now);
      expect(sink.writes.last.$4, 5000.0);

      // Changing the length moves it, as it should.
      await wb.sync('a', {...workout(now, minutes: 45), 'distance_m': 5000.0},
          now: now.add(const Duration(hours: 1)));
      expect(sink.writes.last.$3.difference(sink.writes.last.$2),
          const Duration(minutes: 45));
    });

    test('watch and other-device workouts from today and yesterday are '
        'written, changed ones rewritten, deleted ones removed', () async {
      final v = testVault();
      await wb.enable();
      final prefs = await SharedPreferences.getInstance();
      // Turned on long ago.
      await prefs.remove(HealthWriteback.sinceKey);

      await v.saveWorkout(workout(DateTime(2026, 11, 20, 7)), id: 'today');
      await v.saveWorkout(workout(DateTime(2026, 11, 19, 7)), id: 'yday');
      await v.saveWorkout(workout(DateTime(2026, 11, 10, 7)), id: 'old');
      await v.saveWorkout(
          {...workout(DateTime(2026, 11, 20, 9)), 'source': 'health_connect'},
          id: 'hc');
      await wb.syncRecentWorkouts(v, now: now);
      expect(sink.writes, hasLength(2));
      await wb.syncRecentWorkouts(v, now: now);
      expect(sink.writes, hasLength(2), reason: 'nothing new to write');

      // Made longer on another phone: the record is replaced.
      await v.saveWorkout(workout(DateTime(2026, 11, 20, 7), minutes: 45),
          id: 'today');
      await wb.syncRecentWorkouts(v, now: now);
      expect(sink.deletes, hasLength(1));
      expect(sink.writes.last.$3, DateTime(2026, 11, 20, 7, 45));

      // Deleted on another phone: its record goes too.
      await v.deleteWorkout('yday');
      await wb.syncRecentWorkouts(v, now: now);
      expect(sink.deletes, hasLength(2));
      expect(sink.deletes.last.$1.isAtSameMomentAs(DateTime(2026, 11, 19, 7)),
          isTrue);
    });

    test('"only new ones" leaves out workouts over before it was turned on',
        () async {
      final v = testVault();
      await v.saveWorkout(workout(DateTime(2026, 11, 20, 7)), id: 'before');
      await wb.enable();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(HealthWriteback.sinceKey,
          DateTime(2026, 11, 20, 12).toUtc().toIso8601String());
      await v.saveWorkout(workout(DateTime(2026, 11, 20, 16)), id: 'after');
      await wb.syncRecentWorkouts(v, now: now);
      expect(sink.writes.single.$2, DateTime(2026, 11, 20, 16));
    });

    test('nothing is written while write-back is off', () async {
      final v = testVault();
      await v.saveWorkout(workout(DateTime(2026, 11, 20, 7)), id: 'today');
      await wb.syncRecentWorkouts(v, now: now);
      expect(sink.writes, isEmpty);
    });

    test('records written before changes were tracked are kept as they are',
        () async {
      final v = testVault();
      await wb.enable();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(HealthWriteback.sinceKey);
      final at = DateTime(2026, 11, 20, 7);
      await prefs.setString(
          HealthWriteback.writtenKey,
          '{"today": ["${at.toUtc().toIso8601String()}", '
          '"${at.add(const Duration(minutes: 30)).toUtc().toIso8601String()}"]}');
      await v.saveWorkout(workout(at), id: 'today');
      await wb.syncRecentWorkouts(v, now: now);
      expect(sink.writes, isEmpty);
      // And an edit still replaces the old record.
      await wb.sync('today', workout(at, minutes: 40), now: now);
      expect(sink.deletes.single.$1, at.toUtc());
      expect(sink.writes, hasLength(1));
    });
  
    test('a workout saved while a pass is writing keeps its record',
        () async {
      final v = testVault();
      await wb.enable();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(HealthWriteback.sinceKey);
      await v.saveWorkout(workout(DateTime(2026, 11, 20, 7)), id: 'first');
      await v.saveWorkout(workout(DateTime(2026, 11, 20, 8)), id: 'second');
      // While "first" is written, another workout is saved and written
      // (the shell's own write-back), after the pass listed the vault.
      sink.onWrite = () async {
        final late = workout(DateTime(2026, 11, 20, 9));
        await v.saveWorkout(late, id: 'late');
        unawaited(wb.sync('late', late, now: now));
      };
      await wb.syncRecentWorkouts(v, now: now);
      await wb.sync('noop', const {}, now: now);
      expect(sink.writes, hasLength(3));
      expect(sink.deletes, isEmpty);
    });
  });
}
