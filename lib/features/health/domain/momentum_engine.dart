/// Pure-Dart Momentum engine: an adaptive daily Heart Points target and a
/// 0-100 Momentum score that fades gradually instead of resetting.
///
/// Adaptive target
///   * Starts at [MomentumEngine.defaultTarget] (~150 points/week, the WHO
///     weekly activity guideline).
///   * Replays the last [MomentumEngine.targetWindowDays] days in order:
///       - hit the target            -> it grows by 5%
///       - fall below half of it     -> it eases by 3%
///       - anything in between       -> it holds
///   * Clamped to [MomentumEngine.minTarget]..[MomentumEngine.maxTarget].
///
/// Momentum
///   * Each day's effort = points / that day's target, capped at 1.
///   * Momentum = weighted average of the last 7 days' effort, with each day
///     back counting 0.75x the day after it, scaled to 0-100.
///   * Today can only push Momentum up; a slow day only counts against you
///     once it is over.
///
/// Days before the first recorded day are ignored (new users aren't punished
/// for days before they installed). Missing days after that count as 0.
///
/// No Flutter imports so it can be unit tested with plain `dart test`.
library;

import 'dart:math' as math;

class MomentumResult {
  const MomentumResult({
    required this.target,
    required this.todayPoints,
    required this.momentum,
    required this.gainedToday,
    required this.daysTracked,
  });

  /// Today's Heart Points target.
  final int target;
  final int todayPoints;

  /// 0-100.
  final int momentum;

  /// How much today's activity has added on top of yesterday's Momentum.
  final int gainedToday;

  /// Days of history (including today) that feed the score.
  final int daysTracked;

  bool get targetHit => todayPoints >= target;

  /// Progress toward today's target, capped at 1.
  double get todayProgress =>
      target <= 0 ? 0 : math.min(1.0, todayPoints / target);

  int get pointsToTarget => math.max(0, target - todayPoints);

  String get label {
    if (momentum >= 75) return 'Unstoppable';
    if (momentum >= 50) return 'Steady';
    if (momentum >= 25) return 'Building';
    return 'Getting started';
  }
}

/// One day in a Momentum timeline.
class MomentumDay {
  const MomentumDay({
    required this.date,
    required this.points,
    required this.target,
    required this.momentum,
    required this.isComplete,
  });

  final DateTime date;
  final int points;

  /// The target in force on [date].
  final int target;

  /// End-of-day Momentum for completed days; the live value for today.
  final int momentum;

  /// False only for today, which is still in progress.
  final bool isComplete;

  bool get targetHit => points >= target;
}

class MomentumEngine {
  const MomentumEngine._();

  static const int defaultTarget = 22;
  static const int minTarget = 10;
  static const int maxTarget = 120;
  static const int targetWindowDays = 28;
  static const int momentumWindowDays = 7;
  static const double growOnHit = 1.05;
  static const double easeOnBigMiss = 0.97;
  static const double bigMissFraction = 0.5;
  static const double dayDecay = 0.75;

  /// [history] maps a calendar day (any time on that day) to the Heart Points
  /// earned that day. Entries for [today] or later are ignored; pass today's
  /// live total via [todayPoints].
  static MomentumResult calculate({
    required Map<DateTime, int> history,
    required DateTime today,
    required int todayPoints,
    bool dayComplete = false,
  }) {
    final todayDate = _dateOnly(today);
    final pointsByDay = <DateTime, int>{};
    history.forEach((day, points) {
      final date = _dateOnly(day);
      if (!date.isBefore(todayDate)) return;
      pointsByDay[date] = points;
    });
    pointsByDay[todayDate] = math.max(0, todayPoints);

    final firstDay = pointsByDay.keys.reduce((a, b) => a.isBefore(b) ? a : b);
    int pointsOn(DateTime day) => pointsByDay[day] ?? 0;
    bool tracked(DateTime day) => !day.isBefore(firstDay);

    // Replay the target over the window. targets[day] = target in force that
    // day (i.e. before that day's result adjusts it).
    final targets = <DateTime, int>{};
    var target = defaultTarget.toDouble();
    for (var offset = targetWindowDays; offset >= 0; offset--) {
      final day = _addDays(todayDate, -offset);
      if (!tracked(day)) continue;
      final shown = target.round();
      targets[day] = shown;
      if (offset == 0) break; // Today's result doesn't move today's target.
      final points = pointsOn(day);
      if (points >= shown) {
        target *= growOnHit;
      } else if (points < shown * bigMissFraction) {
        target *= easeOnBigMiss;
      }
      target = target.clamp(minTarget.toDouble(), maxTarget.toDouble());
    }

    double effort(DateTime day) {
      final dayTarget = targets[day] ?? defaultTarget;
      return math.min(1.0, pointsOn(day) / dayTarget);
    }

    // Weighted effort over the 7 days ending at [end]; null if none tracked.
    double? momentumEnding(DateTime end) {
      var weighted = 0.0;
      var weights = 0.0;
      for (var k = 0; k < momentumWindowDays; k++) {
        final day = _addDays(end, -k);
        if (!tracked(day)) break;
        final w = math.pow(dayDecay, k).toDouble();
        weighted += w * effort(day);
        weights += w;
      }
      return weights == 0 ? null : weighted / weights;
    }

    final withToday = momentumEnding(todayDate)!;
    final yesterday = momentumEnding(_addDays(todayDate, -1));
    // While a day is in progress it can only raise Momentum; once it is
    // over ([dayComplete]) it counts at face value.
    final score = (dayComplete || yesterday == null)
        ? withToday
        : math.max(withToday, yesterday);
    final momentum = (score * 100).round();
    final previous = yesterday == null ? 0 : (yesterday * 100).round();

    return MomentumResult(
      target: targets[todayDate] ?? defaultTarget,
      todayPoints: math.max(0, todayPoints),
      momentum: momentum,
      gainedToday: math.max(0, momentum - previous),
      daysTracked: todayDate.difference(firstDay).inDays + 1,
    );
  }

  /// Rebuilds target and Momentum for each day from the first recorded day
  /// (at most [maxDays] back) through [today]. Used for medals.
  static List<MomentumDay> timeline({
    required Map<DateTime, int> history,
    required DateTime today,
    required int todayPoints,
    int maxDays = 90,
  }) {
    final todayDate = _dateOnly(today);
    final pointsByDay = <DateTime, int>{};
    history.forEach((day, points) {
      final date = _dateOnly(day);
      if (date.isBefore(todayDate)) pointsByDay[date] = points;
    });

    var start = _addDays(todayDate, -(maxDays - 1));
    if (pointsByDay.isNotEmpty) {
      final first = pointsByDay.keys.reduce((a, b) => a.isBefore(b) ? a : b);
      if (first.isAfter(start)) start = first;
    } else {
      start = todayDate;
    }

    final days = <MomentumDay>[];
    for (var day = start; !day.isAfter(todayDate); day = _addDays(day, 1)) {
      final isToday = day == todayDate;
      final result = calculate(
        history: pointsByDay,
        today: day,
        todayPoints: isToday ? todayPoints : (pointsByDay[day] ?? 0),
        dayComplete: !isToday,
      );
      days.add(
        MomentumDay(
          date: day,
          points: result.todayPoints,
          target: result.target,
          momentum: result.momentum,
          isComplete: !isToday,
        ),
      );
    }
    return days;
  }

  static DateTime _dateOnly(DateTime d) {
    final local = d.toLocal();
    return DateTime(local.year, local.month, local.day);
  }

  // Calendar arithmetic (not Duration) so DST changes don't shift the day.
  static DateTime _addDays(DateTime d, int days) =>
      DateTime(d.year, d.month, d.day + days);
}
