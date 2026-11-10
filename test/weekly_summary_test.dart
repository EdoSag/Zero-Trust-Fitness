import 'package:flutter_test/flutter_test.dart';
import 'package:zerotrust_fitness/features/summary/weekly_summary.dart';

Map<String, dynamic> day(String key, int hp, int steps) => {
  'date_key': key,
  'heart_points': hp,
  'steps': steps,
};

void main() {
  // Monday 2026-11-02 .. Sunday 2026-11-08, then Monday 2026-11-09 ..
  final rows = [
    day('2026-11-02', 20, 8000),
    day('2026-11-04', 30, 9000),
    day('2026-11-08', 0, 3000),
    day('2026-11-09', 25, 10000),
    day('2026-11-10', 35, 6000),
    day('2026-11-11', 0, 2000),
    day('2026-10-26', 99, 99999), // two weeks before the 9th: ignored there
  ];
  final workouts = [
    {
      'type': 'Running',
      'timestamp': DateTime(2026, 11, 10, 7).toIso8601String(),
    },
    {
      'type': 'Walking',
      'timestamp': DateTime(2026, 11, 3, 18).toIso8601String(),
    },
  ];

  test('next slot is the coming Monday 09:00, reporting the week before', () {
    final wed = nextWeeklySummarySlot(DateTime(2026, 11, 11, 15));
    expect(wed.at, DateTime(2026, 11, 16, 9));
    expect(WeeklySummary.mondayOf(wed.weekOf), DateTime(2026, 11, 9));

    final earlyMonday = nextWeeklySummarySlot(DateTime(2026, 11, 9, 8));
    expect(earlyMonday.at, DateTime(2026, 11, 9, 9));
    expect(WeeklySummary.mondayOf(earlyMonday.weekOf), DateTime(2026, 11, 2));

    final lateMonday = nextWeeklySummarySlot(DateTime(2026, 11, 9, 9, 1));
    expect(lateMonday.at, DateTime(2026, 11, 16, 9));
  });

  test('totals the week and compares with the week before', () {
    final s = WeeklySummary.compute(
      dailyRows: rows,
      workouts: workouts,
      weekOf: DateTime(2026, 11, 11),
      now: DateTime(2026, 11, 11, 20),
    );
    expect(s.weekStart, DateTime(2026, 11, 9));
    expect(s.daysCounted, 3);
    expect(s.week.heartPoints, 60);
    expect(s.week.steps, 18000);
    expect(s.week.workouts, 1);
    expect(s.week.activeDays, 2);
    expect(s.previous.heartPoints, 50);
    expect(s.previous.steps, 20000);
    expect(s.title, 'Your week: 2 active days');
    expect(
      s.body,
      '60 Heart Points (up 20%) · 18,000 steps (down 10%) · 1 workout (through Wednesday)',
    );
  });

  test('a finished week says nothing about which day it counts to', () {
    final s = WeeklySummary.compute(
      dailyRows: rows,
      workouts: workouts,
      weekOf: DateTime(2026, 11, 8),
      now: DateTime(2026, 11, 9, 8),
    );
    expect(s.isComplete, isTrue);
    expect(
      s.body,
      '50 Heart Points (down 49%) · 20,000 steps (down 80%) · 1 workout',
    );
  });

  test('an empty week gets a nudge instead of zeros', () {
    final s = WeeklySummary.compute(
      dailyRows: const [],
      workouts: const [],
      weekOf: DateTime(2026, 11, 11),
      now: DateTime(2026, 11, 11),
    );
    expect(s.title, 'Your week in Fitness');
    expect(s.body, contains('No activity'));
  });
}
