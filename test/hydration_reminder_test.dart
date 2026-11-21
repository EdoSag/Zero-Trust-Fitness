import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health/health.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zerotrust_fitness/core/services/reminder_service.dart';
import 'package:zerotrust_fitness/core/storage/fitness_vault.dart';
import 'package:zerotrust_fitness/features/health/data/health_service.dart';

import 'support.dart';

/// The hydration reminder's notification id.
const _id = 1002;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('dexterous.com/flutter/local_notifications');
  final calls = <MethodCall>[];
  final reminders = ReminderService();

  /// The hourly reminders scheduled so far: when each counts its hours
  /// from (the first one comes an hour later).
  List<DateTime> scheduled() => [
        for (final c in calls)
          if (c.method == 'periodicallyShow')
            DateTime.fromMillisecondsSinceEpoch(
                (c.arguments as Map)['calledAt'] as int),
      ];

  Future<DateTime?> countsFrom() async {
    final ms = (await SharedPreferences.getInstance())
        .getInt(kReminderHydrationCountFrom);
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  // What the generated plugin registrant does when the app starts on Android.
  setUpAll(AndroidFlutterLocalNotificationsPlugin.registerWith);

  setUp(() {
    calls.clear();
    reminders.forgetLoggedWater();
    SharedPreferences.setMockInitialValues({kReminderHydrationEnabled: true});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  final morning = DateTime(2026, 11, 21, 9);
  const day = '2026-11-21';

  test('turning it on counts the hour from then', () async {
    await reminders.scheduleHydrationReminder(now: morning);

    // A second early, so Android never takes it for "due now".
    expect(scheduled(), [morning.subtract(const Duration(seconds: 1))]);
    expect(await countsFrom(), morning);
    final show = calls.last.arguments as Map;
    expect(show['id'], _id);
    expect(show['repeatInterval'], RepeatInterval.hourly.index);
  });

  test('water logged restarts the hour from the moment it was logged',
      () async {
    await reminders.scheduleHydrationReminder(now: morning);
    calls.clear();

    // What the day already held when the app started is only noted.
    expect(await reminders.noteLoggedWater(day, 0.5, now: morning), isFalse);
    expect(calls, isEmpty);

    final drank = morning.add(const Duration(minutes: 20));
    expect(await reminders.noteLoggedWater(day, 0.75, now: drank), isTrue);

    // The showing reminder is cleared, then the hour starts again.
    expect([for (final c in calls) c.method], ['cancel', 'periodicallyShow']);
    expect((calls.first.arguments as Map)['id'], _id);
    expect(scheduled(), [drank.subtract(const Duration(seconds: 1))]);
    expect(await countsFrom(), drank);
  });

  test('the same amount again, or water taken off, changes nothing',
      () async {
    await reminders.scheduleHydrationReminder(now: morning);
    await reminders.noteLoggedWater(day, 0.75, now: morning);
    calls.clear();

    final later = morning.add(const Duration(minutes: 30));
    expect(await reminders.noteLoggedWater(day, 0.75, now: later), isFalse);
    expect(await reminders.noteLoggedWater(day, 0.5, now: later), isFalse);
    expect(calls, isEmpty);
    expect(await countsFrom(), morning);

    // A glass after the one taken off is new water again.
    final again = morning.add(const Duration(minutes: 40));
    expect(await reminders.noteLoggedWater(day, 0.75, now: again), isTrue);
    expect(await countsFrom(), again);
  });

  test('the first glass of a new day restarts it', () async {
    await reminders.noteLoggedWater(day, 1.5, now: morning);
    calls.clear();

    final nextMorning = DateTime(2026, 11, 22, 7, 30);
    expect(
      await reminders.noteLoggedWater('2026-11-22', 0.25, now: nextMorning),
      isTrue,
    );
    expect(await countsFrom(), nextMorning);
  });

  test('nothing is scheduled while the reminder is off', () async {
    SharedPreferences.setMockInitialValues({kReminderHydrationEnabled: false});
    await reminders.noteLoggedWater(day, 0.5, now: morning);
    expect(
      await reminders.noteLoggedWater(
          day, 1.0, now: morning.add(const Duration(minutes: 5))),
      isFalse,
    );
    expect(await reminders.restartHydrationReminder(now: morning), isFalse);
    expect(calls, isEmpty);
  });

  test('water from Health Connect counts from when it was drunk, once',
      () async {
    await reminders.scheduleHydrationReminder(now: morning);
    calls.clear();

    // Seen at noon, drunk at 10:10: reminders at 11:10, 12:10, ...
    final noon = DateTime(2026, 11, 21, 12);
    final drunk = DateTime(2026, 11, 21, 10, 10);
    expect(
        await reminders.restartHydrationReminder(at: drunk, now: noon), isTrue);
    expect(scheduled(), [drunk]);
    calls.clear();

    // The same record on the next refresh, or an older one, is not new.
    expect(
      await reminders.restartHydrationReminder(
          at: drunk, now: noon.add(const Duration(minutes: 5))),
      isFalse,
    );
    expect(
      await reminders.restartHydrationReminder(
          at: DateTime(2026, 11, 21, 8), now: noon),
      isFalse,
    );
    expect(calls, isEmpty);
    expect(await countsFrom(), drunk);
  });

  test('water dated ahead of the clock counts from now', () async {
    await reminders.scheduleHydrationReminder(now: morning);
    final now = morning.add(const Duration(minutes: 10));
    expect(
      await reminders.restartHydrationReminder(
          at: now.add(const Duration(hours: 3)), now: now),
      isTrue,
    );
    expect(await countsFrom(), now);
  });

  test('water seen in two places at once leaves the later one in charge',
      () async {
    await reminders.scheduleHydrationReminder(now: morning);
    final now = morning.add(const Duration(hours: 2));
    final earlier = morning.add(const Duration(minutes: 30));
    final results = await Future.wait([
      reminders.restartHydrationReminder(now: now),
      reminders.restartHydrationReminder(at: earlier, now: now),
    ]);
    expect(results, [true, false]);
    expect(await countsFrom(), now);

    final after = now.add(const Duration(minutes: 30));
    final swapped = await Future.wait([
      reminders.restartHydrationReminder(
          at: now.add(const Duration(minutes: 10)), now: after),
      reminders.restartHydrationReminder(now: after),
    ]);
    expect(swapped, [true, true]);
    expect(await countsFrom(), after);
  });

  test('scheduling again (another reminder, the language) keeps the count',
      () async {
    await reminders.scheduleHydrationReminder(now: morning);
    final drank = morning.add(const Duration(minutes: 20));
    await reminders.restartHydrationReminder(now: drank);
    calls.clear();

    await reminders.scheduleHydrationReminder(
        now: morning.add(const Duration(hours: 5)));
    expect(scheduled(), [drank]);
    expect(await countsFrom(), drank);
  });

  test('turning it off forgets the count', () async {
    await reminders.scheduleHydrationReminder(now: morning);
    await reminders.cancelHydrationReminder();
    expect(await countsFrom(), isNull);

    // On again later: the hour starts then, not at the old time.
    final evening = DateTime(2026, 11, 21, 18);
    calls.clear();
    await reminders.scheduleHydrationReminder(now: evening);
    expect(scheduled(), [evening.subtract(const Duration(seconds: 1))]);
  });

  test('a count saved ahead of the clock is ignored', () async {
    SharedPreferences.setMockInitialValues({
      kReminderHydrationEnabled: true,
      kReminderHydrationCountFrom:
          morning.add(const Duration(days: 1)).millisecondsSinceEpoch,
    });
    expect(await reminders.restartHydrationReminder(now: morning), isTrue);
    expect(await countsFrom(), morning);
  });

  test('glasses added to the vault are what the reminder sees', () async {
    final v = testVault();
    await v.syncFromHealthConnect(dateKey: day, hcMetrics: {'water_l': 0.5});
    await reminders.noteLoggedWater(day, (await v.waterFor(day)).logged,
        now: morning);
    calls.clear();

    // More water from Health Connect isn't a glass logged here.
    await v.syncFromHealthConnect(dateKey: day, hcMetrics: {'water_l': 0.9});
    expect(
      await reminders.noteLoggedWater(day, (await v.waterFor(day)).logged,
          now: morning.add(const Duration(minutes: 5))),
      isFalse,
    );

    // Water for another day doesn't touch today's.
    await v.addWater('2026-11-20', 0.25);
    expect(
      await reminders.noteLoggedWater(day, (await v.waterFor(day)).logged,
          now: morning.add(const Duration(minutes: 6))),
      isFalse,
    );

    final drank = morning.add(const Duration(minutes: 10));
    await v.addWater(FitnessVault.dateKeyOf(drank), 0.25);
    expect(
      await reminders.noteLoggedWater(day, (await v.waterFor(day)).logged,
          now: drank),
      isTrue,
    );
    expect(await countsFrom(), drank);
  });

  group('lastWaterAt', () {
    HealthDataPoint point(HealthDataType type, num value, DateTime end) =>
        HealthDataPoint(
          uuid: '${type.name}-${end.toIso8601String()}',
          value: NumericHealthValue(numericValue: value),
          type: type,
          unit: type == HealthDataType.WATER
              ? HealthDataUnit.LITER
              : HealthDataUnit.COUNT,
          dateFrom: end.subtract(const Duration(minutes: 1)),
          dateTo: end,
          sourcePlatform: HealthPlatformType.googleHealthConnect,
          sourceDeviceId: 'phone',
          sourceId: 'com.example.water',
          sourceName: 'Water app',
        );

    test('is the end of the latest water record', () {
      final last = DateTime(2026, 11, 21, 10, 10);
      expect(
        HealthService.lastWaterAt([
          point(HealthDataType.WATER, 0.25, DateTime(2026, 11, 21, 8)),
          point(HealthDataType.STEPS, 400, DateTime(2026, 11, 21, 11)),
          point(HealthDataType.WATER, 0.3, last),
          point(HealthDataType.WATER, 0, DateTime(2026, 11, 21, 11, 30)),
        ]),
        last,
      );
    });

    test('is null without water', () {
      expect(HealthService.lastWaterAt(const []), isNull);
      expect(
        HealthService.lastWaterAt(
            [point(HealthDataType.STEPS, 400, DateTime(2026, 11, 21, 11))]),
        isNull,
      );
    });
  });
}
