import 'dart:math' as math;

import 'package:health/health.dart';
import 'package:zerotrust_fitness/core/storage/fitness_vault.dart';

/// What a stretch of sleep data says. Watches with stages report light,
/// deep and REM; simpler trackers report only "asleep" or just the session.
enum SleepStage { deep, rem, light, asleep, awake, session }

/// One stretch of sleep data from Health Connect (or HealthKit).
class SleepSegment {
  const SleepSegment(this.stage, this.start, this.end);

  final SleepStage stage;
  final DateTime start;
  final DateTime end;

  static const _stages = <HealthDataType, SleepStage>{
    HealthDataType.SLEEP_DEEP: SleepStage.deep,
    HealthDataType.SLEEP_REM: SleepStage.rem,
    HealthDataType.SLEEP_LIGHT: SleepStage.light,
    HealthDataType.SLEEP_ASLEEP: SleepStage.asleep,
    HealthDataType.SLEEP_AWAKE: SleepStage.awake,
    HealthDataType.SLEEP_SESSION: SleepStage.session,
  };

  /// The Health data types sleep is read from.
  static Iterable<HealthDataType> get healthTypes => _stages.keys;

  /// The sleep segments among [points]; other types are left out.
  static List<SleepSegment> fromHealth(Iterable<HealthDataPoint> points) => [
    for (final p in points)
      if (_stages[p.type] case final stage?)
        if (p.dateTo.isAfter(p.dateFrom))
          SleepSegment(stage, p.dateFrom.toLocal(), p.dateTo.toLocal()),
  ];
}

/// One night's sleep (or every sleep that ended on one day): how long, in
/// which stages, and when it began and ended.
///
/// A night belongs to the day it ends on, the way sleep apps show "last
/// night" on the morning after.
class SleepNight {
  const SleepNight({
    required this.dateKey,
    required this.asleepMinutes,
    this.lightMinutes = 0,
    this.deepMinutes = 0,
    this.remMinutes = 0,
    this.awakeMinutes = 0,
    this.bedtime,
    this.wakeTime,
  });

  /// `yyyy-MM-dd` of the morning it ended.
  final String dateKey;

  /// All time asleep, stages included.
  final int asleepMinutes;
  final int lightMinutes;
  final int deepMinutes;
  final int remMinutes;

  /// Awake in bed during the night (not counted as sleep).
  final int awakeMinutes;

  /// Local times; null for sleep typed in by hand, which has only minutes.
  final DateTime? bedtime;
  final DateTime? wakeTime;

  bool get hasStages => lightMinutes + deepMinutes + remMinutes > 0;

  /// Asleep, with no stage known.
  int get otherAsleepMinutes =>
      math.max(0, asleepMinutes - lightMinutes - deepMinutes - remMinutes);

  /// Keys the day's metrics keep: the totals the app always had, plus
  /// awake time and when the night began and ended (seconds since 1970).
  static const awakeKey = 'sleep_awake_min';
  static const bedtimeKey = 'sleep_bed_at';
  static const wakeKey = 'sleep_wake_at';

  Map<String, num> toMetrics() => {
    'sleep_asleep_min': asleepMinutes,
    'sleep_light_min': lightMinutes,
    'sleep_deep_min': deepMinutes,
    'sleep_rem_min': remMinutes,
    awakeKey: awakeMinutes,
    if (bedtime != null) bedtimeKey: bedtime!.millisecondsSinceEpoch ~/ 1000,
    if (wakeTime != null) wakeKey: wakeTime!.millisecondsSinceEpoch ~/ 1000,
  };

  /// The night a day's stored metrics describe, or null when that day has
  /// no sleep.
  static SleepNight? fromMetrics(String dateKey, Map<String, num> m) {
    int minutes(String key) => (m[key] ?? 0).round();
    final light = minutes('sleep_light_min');
    final deep = minutes('sleep_deep_min');
    final rem = minutes('sleep_rem_min');
    // Sleep typed in by hand may give a total only, or stages only.
    final asleep = math.max(minutes('sleep_asleep_min'), light + deep + rem);
    if (asleep <= 0) return null;
    DateTime? at(String key) {
      final s = m[key];
      if (s == null || s <= 0) return null;
      return DateTime.fromMillisecondsSinceEpoch(s.toInt() * 1000);
    }

    final bed = at(bedtimeKey), wake = at(wakeKey);
    final timesFit = bed != null && wake != null && wake.isAfter(bed);
    return SleepNight(
      dateKey: dateKey,
      asleepMinutes: asleep,
      lightMinutes: light,
      deepMinutes: deep,
      remMinutes: rem,
      awakeMinutes: minutes(awakeKey),
      bedtime: timesFit ? bed : null,
      wakeTime: timesFit ? wake : null,
    );
  }
}

/// Groups sleep data into nights.
class SleepNights {
  /// Sleep apart by less than this is one night (getting up at 3 a.m.).
  static const gap = Duration(hours: 3);

  /// Which stage wins where data overlaps: two sources (a watch and a phone
  /// app) or a session and its stages must not count twice.
  static const _priority = [
    SleepStage.deep,
    SleepStage.rem,
    SleepStage.light,
    SleepStage.asleep,
    SleepStage.awake,
    SleepStage.session,
  ];

  /// One [SleepNight] per stretch of sleep, oldest first. Several stretches
  /// that end on the same day (a nap) stay separate here; see [byDay].
  static List<SleepNight> group(Iterable<SleepSegment> segments) {
    final sorted = segments.toList()
      ..sort((a, b) => a.start.compareTo(b.start));
    final nights = <SleepNight>[];
    var cluster = <SleepSegment>[];
    DateTime? clusterEnd;
    for (final s in sorted) {
      if (clusterEnd != null && s.start.isAfter(clusterEnd.add(gap))) {
        if (_night(cluster) case final n?) nights.add(n);
        cluster = [];
        clusterEnd = null;
      }
      cluster.add(s);
      if (clusterEnd == null || s.end.isAfter(clusterEnd)) clusterEnd = s.end;
    }
    if (_night(cluster) case final n?) nights.add(n);
    return nights;
  }

  static SleepNight? _night(List<SleepSegment> segments) {
    if (segments.isEmpty) return null;
    final bounds = <DateTime>{
      for (final s in segments) ...[s.start, s.end],
    }.toList()..sort();
    final minutes = {for (final s in SleepStage.values) s: 0.0};
    for (var i = 1; i < bounds.length; i++) {
      final from = bounds[i - 1], to = bounds[i];
      SleepStage? top;
      for (final s in segments) {
        if (s.start.isAfter(from) || s.end.isBefore(to)) continue;
        if (top == null ||
            _priority.indexOf(s.stage) < _priority.indexOf(top)) {
          top = s.stage;
        }
      }
      if (top != null) {
        minutes[top] = minutes[top]! + to.difference(from).inSeconds / 60;
      }
    }
    final light = minutes[SleepStage.light]!.round();
    final deep = minutes[SleepStage.deep]!.round();
    final rem = minutes[SleepStage.rem]!.round();
    // A session with no stage under it counts as asleep.
    final asleep =
        light +
        deep +
        rem +
        (minutes[SleepStage.asleep]! + minutes[SleepStage.session]!).round();
    if (asleep <= 0) return null;
    final bed = bounds.first, wake = bounds.last;
    return SleepNight(
      dateKey: FitnessVault.dateKeyOf(wake),
      asleepMinutes: asleep,
      lightMinutes: light,
      deepMinutes: deep,
      remMinutes: rem,
      awakeMinutes: minutes[SleepStage.awake]!.round(),
      bedtime: bed,
      wakeTime: wake,
    );
  }

  /// Every night and nap that ended on the same day, added up into one; the
  /// longest gives the bedtime and wake-up time.
  static Map<String, SleepNight> byDay(Iterable<SleepNight> nights) {
    final days = <String, List<SleepNight>>{};
    for (final n in nights) {
      (days[n.dateKey] ??= []).add(n);
    }
    return {
      for (final e in days.entries)
        e.key: e.value.length == 1 ? e.value.single : _combine(e.value),
    };
  }

  static SleepNight _combine(List<SleepNight> nights) {
    final main = nights.reduce(
      (a, b) => b.asleepMinutes > a.asleepMinutes ? b : a,
    );
    int sum(int Function(SleepNight) f) => nights.fold(0, (t, n) => t + f(n));
    return SleepNight(
      dateKey: main.dateKey,
      asleepMinutes: sum((n) => n.asleepMinutes),
      lightMinutes: sum((n) => n.lightMinutes),
      deepMinutes: sum((n) => n.deepMinutes),
      remMinutes: sum((n) => n.remMinutes),
      awakeMinutes: sum((n) => n.awakeMinutes),
      bedtime: main.bedtime,
      wakeTime: main.wakeTime,
    );
  }

  /// Sleep per day straight from Health data points.
  static Map<String, SleepNight> fromHealth(Iterable<HealthDataPoint> points) =>
      byDay(group(SleepSegment.fromHealth(points)));
}

/// Averages over a run of nights, for the sleep page.
class SleepStats {
  SleepStats(List<SleepNight> nights)
    : nights = [
        for (final n in nights)
          if (n.asleepMinutes > 0) n,
      ];

  final List<SleepNight> nights;

  bool get isEmpty => nights.isEmpty;

  double get averageAsleep => _avg(nights.map((n) => n.asleepMinutes));

  List<SleepNight> get _staged => [
    for (final n in nights)
      if (n.hasStages) n,
  ];

  double get averageDeep => _avg(_staged.map((n) => n.deepMinutes));
  double get averageRem => _avg(_staged.map((n) => n.remMinutes));
  double get averageLight => _avg(_staged.map((n) => n.lightMinutes));
  bool get hasStages => _staged.isNotEmpty;

  /// Bedtimes as minutes after noon, so 23:30 and 00:30 are an hour apart,
  /// not 23 hours.
  List<int> get _bedMinutes => [
    for (final n in nights)
      if (n.bedtime case final b?) _afterNoon(b),
  ];

  /// Wake-up times as minutes after 18:00 the evening before.
  List<int> get _wakeMinutes => [
    for (final n in nights)
      if (n.wakeTime case final w?) (w.hour * 60 + w.minute + 6 * 60) % 1440,
  ];

  static int _afterNoon(DateTime t) =>
      (t.hour * 60 + t.minute + 12 * 60) % 1440;

  /// Average bedtime as minutes after midnight (0-1439), or null.
  int? get averageBedtime {
    final m = _bedMinutes;
    if (m.isEmpty) return null;
    return (_avg(m).round() + 12 * 60) % 1440;
  }

  int? get averageWakeTime {
    final m = _wakeMinutes;
    if (m.isEmpty) return null;
    return (_avg(m).round() + 18 * 60) % 1440;
  }

  /// How much bedtimes vary (standard deviation, minutes); null with fewer
  /// than three nights.
  int? get bedtimeSpread {
    final m = _bedMinutes;
    if (m.length < 3) return null;
    final mean = _avg(m);
    final variance = _avg(m.map((v) => (v - mean) * (v - mean)));
    return math.sqrt(variance).round();
  }

  /// Nights with at least [goalMinutes] of sleep.
  int nightsReaching(num goalMinutes) =>
      nights.where((n) => n.asleepMinutes >= goalMinutes).length;

  static double _avg(Iterable<num> values) {
    var total = 0.0, count = 0;
    for (final v in values) {
      total += v;
      count++;
    }
    return count == 0 ? 0 : total / count;
  }
}
