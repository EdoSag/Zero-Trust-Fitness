/// Pure-Dart Heart Points engine.
///
/// Heart Points are awarded per *minute* of the day:
///   * 1 point  for a minute of moderate activity
///   * 2 points for a minute of vigorous activity
///
/// A minute's intensity is the highest level reported by any of three signals,
/// so the same minute is never counted twice:
///   * Heart rate   – compared against the user's heart-rate reserve (or max HR
///                    when resting HR is unknown), following ACSM zones.
///   * Step cadence – steps per minute (>= 100 moderate, >= 130 vigorous).
///                    This is what lets phone-only users (no watch, no logged
///                    workouts) earn points from brisk walks.
///   * Exercise     – minutes inside a logged workout / Apple exercise minute
///                    are at least moderate.
///
/// This file intentionally has no Flutter / plugin imports so it can be unit
/// tested with plain `dart test`.
library;

class HeartRateSample {
  const HeartRateSample(this.time, this.bpm);

  final DateTime time;
  final double bpm;
}

class StepSample {
  const StepSample({
    required this.start,
    required this.end,
    required this.count,
    this.sourceId = '',
  });

  final DateTime start;
  final DateTime end;
  final num count;

  /// Steps from different sources (phone + watch) are not summed for a minute;
  /// the highest source wins, so double-recorded steps don't inflate cadence.
  final String sourceId;
}

class ActiveInterval {
  const ActiveInterval(this.start, this.end);

  final DateTime start;
  final DateTime end;
}

enum IntensityLevel { none, moderate, vigorous }

extension IntensityLevelPoints on IntensityLevel {
  int get points => switch (this) {
    IntensityLevel.none => 0,
    IntensityLevel.moderate => 1,
    IntensityLevel.vigorous => 2,
  };
}

class HeartPointsResult {
  const HeartPointsResult({
    required this.total,
    required this.moderateMinutes,
    required this.vigorousMinutes,
    required this.pointsByHour,
  });

  static const empty = HeartPointsResult(
    total: 0,
    moderateMinutes: 0,
    vigorousMinutes: 0,
    pointsByHour: <int, int>{},
  );

  final int total;
  final int moderateMinutes;
  final int vigorousMinutes;

  /// Local hour (0-23) -> points earned in that hour.
  final Map<int, int> pointsByHour;
}

class HeartPointsEngine {
  const HeartPointsEngine._();

  static const int defaultAge = 30;

  // Cadence thresholds (steps per minute).
  static const int moderateCadence = 100;
  static const int vigorousCadence = 130;

  // ACSM heart-rate-reserve zones (used when resting HR is known).
  static const double moderateHrrFraction = 0.40;
  static const double vigorousHrrFraction = 0.60;

  // ACSM %HRmax zones (fallback when resting HR is unknown).
  static const double moderateHrMaxFraction = 0.64;
  static const double vigorousHrMaxFraction = 0.77;

  static const Duration _minute = Duration(minutes: 1);

  /// Tanaka-style estimate used across the app.
  static double maxHeartRate(int age) => 206.9 - (0.67 * age);

  static IntensityLevel heartRateIntensity(
    double bpm, {
    int age = defaultAge,
    double? restingBpm,
  }) {
    if (bpm <= 0) return IntensityLevel.none;
    final maxHr = maxHeartRate(age);
    final double moderate;
    final double vigorous;
    if (restingBpm != null && restingBpm > 0 && restingBpm < maxHr) {
      final reserve = maxHr - restingBpm;
      moderate = restingBpm + reserve * moderateHrrFraction;
      vigorous = restingBpm + reserve * vigorousHrrFraction;
    } else {
      moderate = maxHr * moderateHrMaxFraction;
      vigorous = maxHr * vigorousHrMaxFraction;
    }
    if (bpm >= vigorous) return IntensityLevel.vigorous;
    if (bpm >= moderate) return IntensityLevel.moderate;
    return IntensityLevel.none;
  }

  static IntensityLevel cadenceIntensity(num stepsPerMinute) {
    if (stepsPerMinute >= vigorousCadence) return IntensityLevel.vigorous;
    if (stepsPerMinute >= moderateCadence) return IntensityLevel.moderate;
    return IntensityLevel.none;
  }

  /// Computes Heart Points for the window [windowStart, windowEnd).
  /// Pass the local start of a day and the following midnight (or "now").
  static HeartPointsResult calculate({
    required DateTime windowStart,
    required DateTime windowEnd,
    Iterable<HeartRateSample> heartRate = const [],
    Iterable<StepSample> steps = const [],
    Iterable<ActiveInterval> exercise = const [],
    int age = defaultAge,
    double? restingBpm,
  }) {
    if (!windowEnd.isAfter(windowStart)) return HeartPointsResult.empty;

    final startMs = windowStart.millisecondsSinceEpoch;
    final endMs = windowEnd.millisecondsSinceEpoch;
    final levels = <int, IntensityLevel>{};

    void raise(int minuteIndex, IntensityLevel level) {
      if (level == IntensityLevel.none) return;
      final current = levels[minuteIndex];
      if (current == null || level.index > current.index) {
        levels[minuteIndex] = level;
      }
    }

    int minuteOf(int ms) => (ms - startMs) ~/ _minute.inMilliseconds;
    final minuteCount = minuteOf(endMs - 1) + 1;

    // 1. Heart rate: credit the minute each sample falls into.
    for (final sample in heartRate) {
      final ms = sample.time.millisecondsSinceEpoch;
      if (ms < startMs || ms >= endMs) continue;
      raise(
        minuteOf(ms),
        heartRateIntensity(sample.bpm, age: age, restingBpm: restingBpm),
      );
    }

    // 2. Steps: spread each record evenly over the minutes it overlaps, per
    //    source, then take the busiest source for each minute.
    final stepsBySource = <String, Map<int, double>>{};
    for (final sample in steps) {
      var s = sample.start.millisecondsSinceEpoch;
      var e = sample.end.millisecondsSinceEpoch;
      if (sample.count <= 0) continue;
      if (e <= s) {
        // Instantaneous record: treat it as belonging to a single minute.
        e = s + 1;
      }
      final fullDuration = e - s;
      if (e <= startMs || s >= endMs) continue;
      final clippedStart = s < startMs ? startMs : s;
      final clippedEnd = e > endMs ? endMs : e;
      final perMs = sample.count / fullDuration;
      final bucket = stepsBySource.putIfAbsent(sample.sourceId, () => {});
      var cursor = clippedStart;
      while (cursor < clippedEnd) {
        final minute = minuteOf(cursor);
        final minuteEnd = startMs + (minute + 1) * _minute.inMilliseconds;
        final sliceEnd = minuteEnd < clippedEnd ? minuteEnd : clippedEnd;
        bucket[minute] = (bucket[minute] ?? 0) + perMs * (sliceEnd - cursor);
        cursor = sliceEnd;
      }
    }
    final stepsPerMinute = <int, double>{};
    for (final bucket in stepsBySource.values) {
      bucket.forEach((minute, count) {
        final existing = stepsPerMinute[minute] ?? 0;
        if (count > existing) stepsPerMinute[minute] = count;
      });
    }
    stepsPerMinute.forEach((minute, count) {
      // Round so 99.6 steps (float spreading) still counts as 100.
      raise(minute, cadenceIntensity(count.round()));
    });

    // 3. Exercise sessions: every minute inside counts as at least moderate.
    for (final interval in exercise) {
      final s = interval.start.millisecondsSinceEpoch;
      final e = interval.end.millisecondsSinceEpoch;
      if (e <= s || e <= startMs || s >= endMs) continue;
      final half = _minute.inMilliseconds ~/ 2;
      // Round both edges to the nearest minute boundary.
      var first =
          ((s < startMs ? startMs : s) - startMs + half) ~/
          _minute.inMilliseconds;
      var last =
          ((e > endMs ? endMs : e) - startMs + half) ~/ _minute.inMilliseconds;
      if (first < 0) first = 0;
      if (last > minuteCount) last = minuteCount;
      for (var m = first; m < last; m++) {
        raise(m, IntensityLevel.moderate);
      }
    }

    var total = 0;
    var moderate = 0;
    var vigorous = 0;
    final byHour = <int, int>{};
    levels.forEach((minute, level) {
      if (minute < 0 || minute >= minuteCount) return;
      total += level.points;
      if (level == IntensityLevel.vigorous) {
        vigorous++;
      } else if (level == IntensityLevel.moderate) {
        moderate++;
      }
      final hour = DateTime.fromMillisecondsSinceEpoch(
        startMs + minute * _minute.inMilliseconds,
      ).hour;
      byHour[hour] = (byHour[hour] ?? 0) + level.points;
    });

    return HeartPointsResult(
      total: total,
      moderateMinutes: moderate,
      vigorousMinutes: vigorous,
      pointsByHour: byHour,
    );
  }
}
