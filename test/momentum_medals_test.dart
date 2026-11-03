import 'package:flutter_test/flutter_test.dart';
import 'package:zerotrust_fitness/features/achievements/domain/momentum_medals.dart';
import 'package:zerotrust_fitness/features/health/domain/momentum_engine.dart';

void main() {
  final today = DateTime(2026, 11, 3, 15);
  DateTime daysAgo(int n) => DateTime(2026, 11, 3 - n);

  List<MomentumDay> timeline(
    Map<int, int> pointsByDaysAgo, {
    int todayPoints = 0,
  }) => MomentumEngine.timeline(
    history: {for (final e in pointsByDaysAgo.entries) daysAgo(e.key): e.value},
    today: today,
    todayPoints: todayPoints,
  );

  Set<String> medals(Map<int, int> pointsByDaysAgo, {int todayPoints = 0}) =>
      MomentumMedals.earned(
        timeline(pointsByDaysAgo, todayPoints: todayPoints),
      );

  group('timeline', () {
    test('runs from the first recorded day through today', () {
      final days = timeline({3: 10, 1: 30}, todayPoints: 5);
      expect(days.length, 4);
      expect(days.first.date, daysAgo(3));
      expect(days.last.date, DateTime(2026, 11, 3));
      expect(days.last.isComplete, isFalse);
      expect(days.first.isComplete, isTrue);
      expect(days.map((d) => d.points), [10, 0, 30, 5]);
    });

    test(
      'completed days use face-value Momentum, today uses the live rule',
      () {
        final days = timeline({1: 22}, todayPoints: 0);
        expect(days[0].momentum, 100); // yesterday: hit target
        expect(days[1].momentum, 100); // today: can't drop below yesterday yet
        final ended = MomentumEngine.calculate(
          history: {daysAgo(1): 22},
          today: today,
          todayPoints: 0,
          dayComplete: true,
        );
        expect(ended.momentum, 43); // 0.75 / 1.75 once the zero day is final
      },
    );

    test('targets per day match the replay rules', () {
      final days = timeline({2: 100, 1: 100});
      expect(days.map((d) => d.target), [22, 23, 24]);
    });
  });

  group('medals', () {
    test('nothing earned without activity', () {
      expect(medals({}), isEmpty);
    });

    test('first hit earns On Target', () {
      expect(medals({}, todayPoints: 22), contains(MomentumMedals.onTarget));
    });

    test('streaks of 3 and 7 hits', () {
      final three = medals({2: 100, 1: 100}, todayPoints: 100);
      expect(three, contains(MomentumMedals.hatTrick));
      expect(three, isNot(contains(MomentumMedals.lockedIn)));
      final seven = medals({
        for (var i = 1; i <= 6; i++) i: 100,
      }, todayPoints: 100);
      expect(seven, contains(MomentumMedals.lockedIn));
    });

    test('an unfinished today does not break a streak', () {
      final m = medals({3: 100, 2: 100, 1: 100}, todayPoints: 0);
      expect(m, contains(MomentumMedals.hatTrick));
    });

    test('Comeback after 3 missed days', () {
      expect(
        medals({4: 0, 3: 0, 2: 0, 1: 100}),
        contains(MomentumMedals.comeback),
      );
      expect(
        medals({3: 0, 2: 0, 1: 100}),
        isNot(contains(MomentumMedals.comeback)),
      );
    });

    test('Raising the Bar when the target reaches 40', () {
      // 22 * 1.05^n >= 39.5 needs 12 straight hits.
      final m = medals({for (var i = 1; i <= 12; i++) i: 1000});
      expect(m, contains(MomentumMedals.raisingTheBar));
      final short = medals({for (var i = 1; i <= 11; i++) i: 1000});
      expect(short, isNot(contains(MomentumMedals.raisingTheBar)));
    });

    test('Momentum thresholds', () {
      final m = medals({}, todayPoints: 17); // 17/22 = 77
      expect(
        m,
        containsAll([MomentumMedals.steady, MomentumMedals.unstoppable]),
      );
      expect(medals({}, todayPoints: 12), {MomentumMedals.steady}); // 55
    });

    test('Perpetual Motion needs 7 completed days at 75+', () {
      final week = {for (var i = 1; i <= 7; i++) i: 1000};
      expect(medals(week), contains(MomentumMedals.perpetualMotion));
      final six = {for (var i = 1; i <= 6; i++) i: 1000};
      // Today is still live, so it can't complete the run.
      expect(
        medals(six, todayPoints: 1000),
        isNot(contains(MomentumMedals.perpetualMotion)),
      );
    });

    test('every medal rule has a matching id list entry', () {
      expect(MomentumMedals.all.toSet().length, MomentumMedals.all.length);
    });
  });
}
