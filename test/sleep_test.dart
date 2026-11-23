import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zero_trust_core/zero_trust_core.dart';
import 'package:zerotrust_fitness/app/vault_providers.dart';
import 'package:zerotrust_fitness/core/storage/fitness_vault.dart';
import 'package:zerotrust_fitness/features/goals/goals_provider.dart';
import 'package:zerotrust_fitness/features/sleep/sleep_nights.dart';
import 'package:zerotrust_fitness/l10n/l10n.dart';
import 'package:zerotrust_fitness/pages/sleep_page.dart';

import 'phone_layout.dart';
import 'support.dart';

SleepSegment _seg(SleepStage stage, DateTime start, int minutes) =>
    SleepSegment(stage, start, start.add(Duration(minutes: minutes)));

void main() {
  final evening = DateTime(2026, 11, 20, 23, 0);

  group('nights', () {
    test('a staged night belongs to the morning it ends', () {
      final night = SleepNights.group([
        // The session around the stages must not count again.
        _seg(SleepStage.session, evening, 480),
        _seg(SleepStage.light, evening, 120),
        _seg(SleepStage.deep, evening.add(const Duration(hours: 2)), 90),
        _seg(SleepStage.awake, evening.add(const Duration(minutes: 210)), 30),
        _seg(SleepStage.rem, evening.add(const Duration(hours: 4)), 60),
        _seg(SleepStage.light, evening.add(const Duration(hours: 5)), 180),
      ]).single;
      expect(night.dateKey, '2026-11-21');
      expect(night.bedtime, evening);
      expect(night.wakeTime, DateTime(2026, 11, 21, 7));
      expect(night.lightMinutes, 300);
      expect(night.deepMinutes, 90);
      expect(night.remMinutes, 60);
      expect(night.awakeMinutes, 30);
      expect(night.asleepMinutes, 450);
      expect(night.otherAsleepMinutes, 0);
    });

    test('a session without stages counts as asleep, minus time awake', () {
      final night = SleepNights.group([
        _seg(SleepStage.session, evening, 420),
        _seg(SleepStage.awake, evening.add(const Duration(hours: 3)), 20),
      ]).single;
      expect(night.asleepMinutes, 400);
      expect(night.hasStages, isFalse);
      expect(night.otherAsleepMinutes, 400);
    });

    test('two apps reporting the same night count it once', () {
      final night = SleepNights.group([
        _seg(SleepStage.asleep, evening, 420), // phone app
        _seg(SleepStage.light, evening, 300), // watch
        _seg(SleepStage.deep, evening.add(const Duration(hours: 5)), 120),
      ]).single;
      expect(night.asleepMinutes, 420);
      expect(night.lightMinutes, 300);
      expect(night.deepMinutes, 120);
    });

    test('a nap is its own stretch; a day adds up both', () {
      final nights = SleepNights.group([
        _seg(SleepStage.asleep, evening, 420),
        // Up at 6:00, back to sleep at 8:00: still the same night.
        _seg(SleepStage.asleep, DateTime(2026, 11, 21, 8), 30),
        _seg(SleepStage.asleep, DateTime(2026, 11, 21, 15), 40),
      ]);
      expect(nights, hasLength(2));
      expect(nights.first.asleepMinutes, 450);
      final day = SleepNights.byDay(nights)['2026-11-21']!;
      expect(day.asleepMinutes, 490);
      // The longest stretch gives the times.
      expect(day.bedtime, evening);
      expect(day.wakeTime, DateTime(2026, 11, 21, 8, 30));
    });

    test('stored metrics read back as the same night', () {
      final night = SleepNights.group([
        _seg(SleepStage.light, evening, 300),
        _seg(SleepStage.rem, evening.add(const Duration(hours: 5)), 60),
      ]).single;
      final back = SleepNight.fromMetrics(night.dateKey, night.toMetrics())!;
      expect(back.asleepMinutes, 360);
      expect(back.remMinutes, 60);
      expect(back.bedtime, evening);
      expect(back.wakeTime, DateTime(2026, 11, 21, 5));
    });

    test('nights entered by hand: a total, or stages only', () {
      expect(
        SleepNight.fromMetrics('2026-11-21', {
          'sleep_asleep_min': 400,
        })!.asleepMinutes,
        400,
      );
      final staged = SleepNight.fromMetrics('2026-11-21', {
        'sleep_deep_min': 60,
        'sleep_light_min': 200,
      })!;
      expect(staged.asleepMinutes, 260);
      expect(staged.bedtime, isNull);
      expect(SleepNight.fromMetrics('2026-11-21', {'steps': 4000}), isNull);
    });

    test('bedtimes either side of midnight average around it', () {
      SleepNight n(DateTime bed, DateTime wake) => SleepNight(
        dateKey: FitnessVault.dateKeyOf(wake),
        asleepMinutes: wake.difference(bed).inMinutes,
        bedtime: bed,
        wakeTime: wake,
      );
      final stats = SleepStats([
        n(DateTime(2026, 11, 20, 23, 30), DateTime(2026, 11, 21, 7, 0)),
        n(DateTime(2026, 11, 22, 0, 30), DateTime(2026, 11, 22, 7, 30)),
        n(DateTime(2026, 11, 22, 23, 0), DateTime(2026, 11, 23, 6, 30)),
        n(DateTime(2026, 11, 24, 1, 0), DateTime(2026, 11, 24, 8, 0)),
      ]);
      // 23:30, 0:30, 23:00, 1:00 -> 0:00
      expect(stats.averageBedtime, 0);
      expect(stats.averageWakeTime, 7 * 60 + 15);
      // Off by 30, 30, 60 and 60 minutes.
      expect(stats.bedtimeSpread, 47);
      expect(stats.nightsReaching(450), 2);
    });
  });

  group('vault', () {
    test('a later read raises a past night, never lowers it', () async {
      final v = testVault();
      await v.mergeDailyMetrics(
        dateKey: '2026-11-21',
        incoming: {'sleep_asleep_min': 300},
      );
      final night = SleepNight(
        dateKey: '2026-11-21',
        asleepMinutes: 420,
        deepMinutes: 80,
        lightMinutes: 340,
        bedtime: evening,
        wakeTime: DateTime(2026, 11, 21, 6),
      );
      await v.raiseSleepFromHealth(
        dateKey: '2026-11-21',
        sleep: night.toMetrics(),
      );
      var m = (await v.fetchDailyMetrics()).single['metrics'] as Map;
      expect(m['sleep_asleep_min'], 420);
      expect(m['sleep_asleep_min_manual'], 300);
      expect(m['sleep_deep_min'], 80);
      expect(m['sleep_bed_at'], evening.millisecondsSinceEpoch ~/ 1000);

      // A shorter read (data deleted in Health Connect) changes nothing.
      await v.raiseSleepFromHealth(
        dateKey: '2026-11-21',
        sleep: {'sleep_asleep_min': 200, 'sleep_bed_at': 1},
      );
      m = (await v.fetchDailyMetrics()).single['metrics'] as Map;
      expect(m['sleep_asleep_min'], 420);
      expect(m['sleep_bed_at'], evening.millisecondsSinceEpoch ~/ 1000);
    });

    test('a night entered by hand as longer stays', () async {
      final v = testVault();
      await v.mergeDailyMetrics(
        dateKey: '2026-11-21',
        incoming: {'sleep_asleep_min': 500},
      );
      await v.raiseSleepFromHealth(
        dateKey: '2026-11-21',
        sleep: {'sleep_asleep_min': 420},
      );
      final m = (await v.fetchDailyMetrics()).single['metrics'] as Map;
      expect(m['sleep_asleep_min'], 500);
      expect(m['sleep_asleep_min_hc'], 420);
    });

    test(
      'today\'s sync keeps the night\'s times without shadow keys',
      () async {
        final v = testVault();
        await v.syncFromHealthConnect(
          dateKey: '2026-11-21',
          hcMetrics: {
            'sleep_asleep_min': 420,
            'sleep_awake_min': 12,
            'sleep_bed_at': 1795300000,
            'sleep_wake_at': 1795325200,
          },
        );
        final m = (await v.fetchDailyMetrics()).single['metrics'] as Map;
        expect(m['sleep_awake_min'], 12);
        expect(m['sleep_bed_at'], 1795300000);
        expect(m.containsKey('sleep_bed_at_hc'), isFalse);
        // A later sync with no night yet keeps them.
        await v.syncFromHealthConnect(
          dateKey: '2026-11-21',
          hcMetrics: {'sleep_asleep_min': 420},
        );
        final again = (await v.fetchDailyMetrics()).single['metrics'] as Map;
        expect(again['sleep_wake_at'], 1795325200);
      },
    );
  });

  group('sleep page', () {
    Future<FitnessVault> pump(
      WidgetTester tester, {
      Map<String, SleepNight> health = const {},
      FitnessVault? vault,
      Map<String, UserGoal> goals = const {},
    }) async {
      await usePhoneScreen(tester);
      final v = vault ?? testVault();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            openFitnessVaultProvider.overrideWithValue(v),
            goalsProvider.overrideWith(() => _Goals(goals)),
          ],
          child: MaterialApp(
            localizationsDelegates: const [
              AppL10n.delegate,
              ...ZtLanguages.delegates,
            ],
            supportedLocales: ZtLanguages.supported,
            theme: appTheme,
            home: SleepPage(vault: v, loadHealthSleep: () async => health),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return v;
    }

    DateTime day(int daysAgo) {
      final now = DateTime.now();
      return DateTime(now.year, now.month, now.day - daysAgo);
    }

    testWidgets('shows last night in stages, the week, and averages', (
      tester,
    ) async {
      final vault = testVault();
      // Earlier nights stored in the vault (another phone, older reads).
      for (var i = 1; i <= 6; i++) {
        await vault.mergeDailyMetrics(
          dateKey: FitnessVault.dateKeyOf(day(i)),
          incoming: {'sleep_asleep_min': 400 + i},
        );
      }
      final bed = day(1).add(const Duration(hours: 23));
      final today = FitnessVault.dateKeyOf(day(0));
      await pump(
        tester,
        vault: vault,
        goals: {
          'sleep_asleep_min': const UserGoal(
            metricKey: 'sleep_asleep_min',
            targetValue: 420,
            period: 'daily',
          ),
        },
        health: {
          today: SleepNight(
            dateKey: today,
            asleepMinutes: 452,
            deepMinutes: 72,
            remMinutes: 100,
            lightMinutes: 280,
            awakeMinutes: 18,
            bedtime: bed,
            wakeTime: bed.add(const Duration(minutes: 470)),
          ),
        },
      );

      expect(find.text('Last night'), findsOneWidget);
      expect(find.text('7 h 32 min'), findsOneWidget);
      expect(find.text('23:00 – 6:50'), findsOneWidget);
      expect(find.text('Sleep goal reached'), findsOneWidget);
      expect(find.text('Deep 1 h 12 min'), findsOneWidget);
      expect(find.text('Awake 18 min'), findsOneWidget);

      // Last night is at the top, full width; the chart under it.
      final card = tester.getRect(find.byKey(const ValueKey('last-night')));
      final chart = tester.getRect(find.byKey(const ValueKey('sleep-chart')));
      final width =
          tester.view.physicalSize.width / tester.view.devicePixelRatio;
      expect(card.top, lessThan(200));
      expect(card.width, greaterThan(width - 60));
      expect(chart.top, greaterThan(card.bottom));
      expect(chart.width, greaterThan(width - 60));

      expectTappableOnScreen(tester, find.text('Month'));
      // (452 + 401 + ... + 406) / 7 = 410.4
      expect(find.text('Average sleep'), findsOneWidget);
      expect(find.text('6 h 50 min'), findsOneWidget);
      expect(find.text('Nights with 7 h 0 min or more'), findsOneWidget);
      expect(find.text('1 of 7'), findsOneWidget);

      await tester.tap(find.text('Month'));
      await tester.pumpAndSettle();
      expect(find.text('6 h 50 min'), findsOneWidget);
      expect(find.text('Compared with the week before'), findsNothing);

      await tester.scrollUntilVisible(find.text('Average night by stage'), 200);
      expect(find.text('Average night by stage'), findsOneWidget);
    });

    testWidgets('with no sleep it says where sleep comes from', (tester) async {
      await pump(tester);
      expect(find.text('No sleep yet'), findsOneWidget);
      expect(find.byKey(const ValueKey('sleep-chart')), findsNothing);
    });
  });
}

class _Goals extends GoalsNotifier {
  _Goals(this.goals);
  final Map<String, UserGoal> goals;

  @override
  Future<GoalsState> build() async => GoalsState(goals: goals);
}
