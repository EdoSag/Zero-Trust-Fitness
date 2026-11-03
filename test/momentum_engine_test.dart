import 'package:flutter_test/flutter_test.dart';
import 'package:zerotrust_fitness/features/health/domain/momentum_engine.dart';

void main() {
  final today = DateTime(2026, 11, 3, 15, 30);
  DateTime daysAgo(int n) => DateTime(2026, 11, 3 - n);

  MomentumResult run(Map<int, int> pointsByDaysAgo, {int todayPoints = 0}) =>
      MomentumEngine.calculate(
        history: {
          for (final e in pointsByDaysAgo.entries) daysAgo(e.key): e.value,
        },
        today: today,
        todayPoints: todayPoints,
      );

  test('new user starts at the default target', () {
    final r = run({}, todayPoints: 11);
    expect(r.target, MomentumEngine.defaultTarget);
    expect(r.daysTracked, 1);
    expect(r.momentum, 50); // 11 / 22
    expect(r.gainedToday, 50);
  });

  test('hitting the target makes it grow 5% per day', () {
    // Comfortably above every target along the way.
    final r = run({for (var i = 1; i <= 3; i++) i: 200});
    // 22 -> 23.1 -> 24.255 -> 25.47
    expect(r.target, 25);
  });

  test('big misses ease the target, near misses hold it', () {
    expect(run({1: 5}).target, 21); // 22 * 0.97 = 21.34
    expect(run({1: 15}).target, 22); // between 50% and 100%: hold
  });

  test('target growth is gradual and floors at the minimum', () {
    final high = run({for (var i = 1; i <= 28; i++) i: 1000});
    expect(high.target, 86); // 22 * 1.05^28, still under the 120 cap
    final low = run({for (var i = 1; i <= 28; i++) i: 0});
    expect(low.target, MomentumEngine.minTarget);
  });

  test('missing days after the first record count as zero', () {
    // Recorded 3 days ago, nothing since.
    final r = run({3: 22});
    // Day -3 effort 1.0 (w=.421875); -2, -1 are 0; today 0 (doesn't lower).
    // Yesterday's momentum: (0*1 + 0*.75 + 1*.5625) / (1+.75+.5625) = 0.243
    expect(r.momentum, 24);
    expect(r.gainedToday, 0);
  });

  test('a slow morning never lowers Momentum', () {
    final week = {for (var i = 1; i <= 6; i++) i: 30};
    final morning = run(week, todayPoints: 0);
    final evening = run(week, todayPoints: 30);
    expect(morning.momentum, 100);
    expect(evening.momentum, 100);
  });

  test('today raises Momentum and reports the gain', () {
    final week = {for (var i = 1; i <= 6; i++) i: 0};
    final r = run(week, todayPoints: 22);
    expect(r.momentum, greaterThan(0));
    expect(r.gainedToday, r.momentum);
    expect(r.targetHit, isTrue);
    expect(r.todayProgress, 1.0);
  });

  test('one missed day fades Momentum instead of resetting it', () {
    // Six strong days, then yesterday nothing.
    final r = run({for (var i = 2; i <= 7; i++) i: 100, 1: 0});
    expect(r.momentum, inInclusiveRange(60, 80));
  });

  test('history entries for today are ignored in favour of todayPoints', () {
    final r = MomentumEngine.calculate(
      history: {DateTime(2026, 11, 3): 999},
      today: today,
      todayPoints: 0,
    );
    expect(r.todayPoints, 0);
    expect(r.momentum, 0);
  });

  test('labels by score', () {
    expect(run({}, todayPoints: 0).label, 'Getting started');
    expect(run({}, todayPoints: 22).label, 'Unstoppable');
  });
}
