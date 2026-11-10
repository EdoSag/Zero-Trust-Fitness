import 'package:intl/intl.dart';
import 'package:zerotrust_fitness/core/storage/fitness_vault.dart';

/// One week's totals.
class WeekTotals {
  const WeekTotals({
    required this.heartPoints,
    required this.steps,
    required this.workouts,
    required this.activeDays,
  });

  static const empty = WeekTotals(
    heartPoints: 0,
    steps: 0,
    workouts: 0,
    activeDays: 0,
  );

  final int heartPoints;
  final int steps;
  final int workouts;

  /// Days with any Heart Points.
  final int activeDays;

  bool get isEmpty => heartPoints == 0 && steps == 0 && workouts == 0;
}

/// A week (Monday to Sunday) next to the week before it: what the weekly
/// summary notification and the Trends card say.
class WeeklySummary {
  const WeeklySummary({
    required this.weekStart,
    required this.daysCounted,
    required this.week,
    required this.previous,
  });

  /// Local midnight of the week's Monday.
  final DateTime weekStart;

  /// 7 for a finished week; fewer while it is still going.
  final int daysCounted;
  final WeekTotals week;
  final WeekTotals previous;

  bool get isComplete => daysCounted >= 7;

  static DateTime mondayOf(DateTime at) {
    final d = DateTime(at.year, at.month, at.day);
    return d.subtract(Duration(days: d.weekday - DateTime.monday));
  }

  /// The week that holds [weekOf], from the rows of
  /// [FitnessVault.fetchDailyMetrics] and the workouts' data, counted up to
  /// [now].
  static WeeklySummary compute({
    required List<Map<String, dynamic>> dailyRows,
    required Iterable<Map<String, dynamic>> workouts,
    required DateTime weekOf,
    required DateTime now,
  }) {
    final start = mondayOf(weekOf);
    final previousStart = start.subtract(const Duration(days: 7));
    final today = DateTime(now.year, now.month, now.day);
    final elapsed = today.difference(start).inDays + 1;
    return WeeklySummary(
      weekStart: start,
      daysCounted: elapsed.clamp(0, 7),
      week: _totals(dailyRows, workouts, start),
      previous: _totals(dailyRows, workouts, previousStart),
    );
  }

  static WeekTotals _totals(
    List<Map<String, dynamic>> rows,
    Iterable<Map<String, dynamic>> workouts,
    DateTime start,
  ) {
    final keys = {
      for (var i = 0; i < 7; i++)
        FitnessVault.dateKeyOf(
          DateTime(start.year, start.month, start.day + i),
        ),
    };
    var hp = 0, steps = 0, active = 0, count = 0;
    for (final r in rows) {
      if (!keys.contains(r['date_key'])) continue;
      final dayHp = (r['heart_points'] as num?)?.toInt() ?? 0;
      hp += dayHp;
      steps += (r['steps'] as num?)?.toInt() ?? 0;
      if (dayHp > 0) active++;
    }
    for (final w in workouts) {
      if (keys.contains(FitnessVault.workoutDateKey(w))) count++;
    }
    return WeekTotals(
      heartPoints: hp,
      steps: steps,
      workouts: count,
      activeDays: active,
    );
  }

  /// Percent change from the week before, or null with nothing to compare.
  static int? change(num now, num before) =>
      before <= 0 ? null : (((now - before) / before) * 100).round();

  static String _delta(num now, num before) {
    final c = change(now, before);
    if (c == null) return '';
    if (c == 0) return ' (same as last week)';
    return c > 0 ? ' (up $c%)' : ' (down ${-c}%)';
  }

  String get title {
    if (week.isEmpty) return 'Your week in Fitness';
    final days = week.activeDays;
    return 'Your week: $days active ${days == 1 ? 'day' : 'days'}';
  }

  /// The notification text, such as "152 Heart Points (up 18%) · 54,210
  /// steps (down 4%) · 4 workouts".
  String get body {
    if (week.isEmpty) {
      return 'No activity logged this week. A short walk is a good start.';
    }
    final n = NumberFormat.decimalPattern();
    final parts = [
      '${n.format(week.heartPoints)} Heart Points'
          '${_delta(week.heartPoints, previous.heartPoints)}',
      '${n.format(week.steps)} steps${_delta(week.steps, previous.steps)}',
      if (week.workouts > 0)
        '${week.workouts} ${week.workouts == 1 ? 'workout' : 'workouts'}',
    ];
    final through = isComplete
        ? ''
        : ' (through ${DateFormat.EEEE().format(weekStart.add(Duration(days: daysCounted - 1)))})';
    return '${parts.join(' · ')}$through';
  }
}

/// When the next weekly summary is due (Monday 09:00 local, the first one
/// after [now]), and which week it reports: the one that ended the Sunday
/// before.
({DateTime at, DateTime weekOf}) nextWeeklySummarySlot(
  DateTime now, {
  int hour = 9,
}) {
  var monday = WeeklySummary.mondayOf(now);
  var at = DateTime(monday.year, monday.month, monday.day, hour);
  if (!at.isAfter(now)) {
    monday = DateTime(monday.year, monday.month, monday.day + 7);
    at = DateTime(monday.year, monday.month, monday.day, hour);
  }
  return (at: at, weekOf: DateTime(monday.year, monday.month, monday.day - 1));
}
