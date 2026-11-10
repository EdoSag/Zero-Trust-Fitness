import 'package:flutter_test/flutter_test.dart';
import 'package:zerotrust_fitness/features/wear/wear_companion.dart';

void main() {
  test('today on the watch: rounded numbers, goals and glass size', () {
    final t = WearCompanion.todayFrom(
      {'steps': 8123.6, 'heart_points': 17, 'water_l': 1.25},
      stepsGoal: 8000,
      heartPointsGoal: null,
      waterGoalLiters: 2.5,
      now: DateTime(2026, 11, 10, 9),
    );
    expect(t.day, '2026-11-10');
    expect(t.steps, 8124);
    expect(t.stepsGoal, 8000);
    expect(t.heartPoints, 17);
    expect(t.heartPointsGoal, 21);
    expect(t.waterMl, 1250);
    expect(t.waterGoalMl, 2500);
    expect(t.glassMl, 250);
    expect(t.imperial, isFalse);
  });

  test('the same numbers are equal, so nothing is re-sent', () {
    WearToday make() => WearCompanion.todayFrom(
      {'steps': 1},
      stepsGoal: null,
      heartPointsGoal: null,
      waterGoalLiters: null,
      now: DateTime(2026, 11, 10),
    );
    expect(make(), make());
    expect(make().hashCode, make().hashCode);
  });
}
