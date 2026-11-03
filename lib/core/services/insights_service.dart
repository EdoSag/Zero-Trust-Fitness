import 'dart:math' as math;

import 'package:zerotrust_fitness/features/goals/goals_provider.dart';

class InsightsService {
  InsightsService._();
  factory InsightsService() => _instance;
  static final InsightsService _instance = InsightsService._();

  // ---------------------------------------------------------------------------
  // Streaks — consecutive days where every active goal was met
  // ---------------------------------------------------------------------------

  StreakResult computeStreaks(
    GoalsState goals,
    List<Map<String, dynamic>> dailyMetrics,
  ) {
    if (goals.goals.isEmpty || dailyMetrics.isEmpty) {
      return const StreakResult(current: 0, longest: 0);
    }

    final byDate = <String, Map<String, double>>{};
    for (final row in dailyMetrics) {
      final dateKey = row['date_key']?.toString();
      if (dateKey == null) continue;
      final raw = row['metrics'];
      if (raw is Map) {
        byDate[dateKey] = raw.map((k, v) {
          final n = v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '') ?? 0.0;
          return MapEntry('$k', n);
        });
      }
    }

    final sortedDates = byDate.keys.toList()..sort();

    bool metAllGoals(String dateKey) {
      final m = byDate[dateKey] ?? {};
      for (final g in goals.goals.values) {
        if ((m[g.metricKey] ?? 0) < g.targetValue) return false;
      }
      return true;
    }

    int longest = 0;
    int run = 0;
    for (final date in sortedDates) {
      if (metAllGoals(date)) {
        run++;
        if (run > longest) longest = run;
      } else {
        run = 0;
      }
    }

    // Current streak: count backwards from the most recent date
    int current = 0;
    if (sortedDates.isNotEmpty) {
      final last = sortedDates.last;
      final today = _dateKey(DateTime.now());
      final yesterday = _dateKey(DateTime.now().subtract(const Duration(days: 1)));
      if (last == today || last == yesterday) {
        for (int i = sortedDates.length - 1; i >= 0; i--) {
          if (!metAllGoals(sortedDates[i])) break;
          current++;
          // Verify the day before was consecutive
          if (i > 0) {
            final expected = _dateKey(
              DateTime.parse(sortedDates[i])
                  .subtract(const Duration(days: 1)),
            );
            if (sortedDates[i - 1] != expected) break;
          }
        }
      }
    }

    return StreakResult(current: current, longest: longest);
  }

  // ---------------------------------------------------------------------------
  // Weekly comparison
  // ---------------------------------------------------------------------------

  WeeklyComparison weeklyComparison(
    List<Map<String, dynamic>> dailyMetrics,
    String metricKey,
  ) {
    final today = DateTime.now();
    final startOfThisWeek = today.subtract(Duration(days: today.weekday - 1));
    final startOfLastWeek = startOfThisWeek.subtract(const Duration(days: 7));

    double thisWeek = 0, lastWeek = 0;
    int thisCount = 0, lastCount = 0;

    for (final row in dailyMetrics) {
      final dateKey = row['date_key']?.toString();
      if (dateKey == null) continue;
      final date = DateTime.tryParse(dateKey);
      if (date == null) continue;
      final raw = row['metrics'];
      if (raw is! Map) continue;
      final v = raw[metricKey];
      final value = (v is num ? v : num.tryParse(v?.toString() ?? ''))?.toDouble() ?? 0;

      if (!date.isBefore(startOfThisWeek) && !date.isAfter(today)) {
        thisWeek += value;
        thisCount++;
      } else if (!date.isBefore(startOfLastWeek) && date.isBefore(startOfThisWeek)) {
        lastWeek += value;
        lastCount++;
      }
    }

    final thisAvg = thisCount > 0 ? thisWeek / thisCount : 0.0;
    final lastAvg = lastCount > 0 ? lastWeek / lastCount : 0.0;
    final pctChange = lastAvg > 0 ? ((thisAvg - lastAvg) / lastAvg) * 100 : null;

    return WeeklyComparison(
      thisWeekTotal: thisWeek,
      lastWeekTotal: lastWeek,
      thisWeekDailyAvg: thisAvg,
      lastWeekDailyAvg: lastAvg,
      percentChange: pctChange,
    );
  }

  // ---------------------------------------------------------------------------
  // Personal records
  // ---------------------------------------------------------------------------

  PersonalRecords personalRecords(
    List<Map<String, dynamic>> dailyMetrics,
    List<String> metricKeys,
  ) {
    final maxValues = <String, double>{};
    final maxDates = <String, String>{};

    for (final row in dailyMetrics) {
      final dateKey = row['date_key']?.toString() ?? '';
      final raw = row['metrics'];
      if (raw is! Map) continue;
      for (final key in metricKeys) {
        final v = raw[key];
        final value = (v is num ? v : num.tryParse(v?.toString() ?? ''))?.toDouble() ?? 0;
        if (value > 0 && value > (maxValues[key] ?? 0)) {
          maxValues[key] = value;
          maxDates[key] = dateKey;
        }
      }
    }

    return PersonalRecords(maxValues: maxValues, maxDates: maxDates);
  }

  // ---------------------------------------------------------------------------
  // Baselines — 30-day rolling average per metric
  // ---------------------------------------------------------------------------

  Map<String, double> computeBaselines(List<Map<String, dynamic>> dailyMetrics) {
    final cutoff = DateTime.now().subtract(const Duration(days: 30));
    final sums = <String, double>{};
    final counts = <String, int>{};

    for (final row in dailyMetrics) {
      final dateKey = row['date_key']?.toString();
      if (dateKey == null) continue;
      final date = DateTime.tryParse(dateKey);
      if (date == null || date.isBefore(cutoff)) continue;
      final raw = row['metrics'];
      if (raw is! Map) continue;
      raw.forEach((k, v) {
        final n = (v is num ? v : num.tryParse(v?.toString() ?? ''))?.toDouble();
        if (n != null && n > 0) {
          sums['$k'] = (sums['$k'] ?? 0) + n;
          counts['$k'] = (counts['$k'] ?? 0) + 1;
        }
      });
    }

    return Map.fromEntries(
      sums.entries.map((e) => MapEntry(e.key, e.value / (counts[e.key] ?? 1))),
    );
  }

  // ---------------------------------------------------------------------------
  // Pearson correlation between two metrics (returns null if < 5 data points)
  // ---------------------------------------------------------------------------

  double? computeCorrelation(
    List<Map<String, dynamic>> dailyMetrics,
    String keyA,
    String keyB,
  ) {
    final xs = <double>[];
    final ys = <double>[];

    for (final row in dailyMetrics) {
      final raw = row['metrics'];
      if (raw is! Map) continue;
      final a = (raw[keyA] is num ? raw[keyA] as num : num.tryParse(raw[keyA]?.toString() ?? ''))?.toDouble();
      final b = (raw[keyB] is num ? raw[keyB] as num : num.tryParse(raw[keyB]?.toString() ?? ''))?.toDouble();
      if (a != null && a > 0 && b != null && b > 0) {
        xs.add(a);
        ys.add(b);
      }
    }

    if (xs.length < 5) return null;

    final n = xs.length;
    final meanX = xs.reduce((a, b) => a + b) / n;
    final meanY = ys.reduce((a, b) => a + b) / n;
    double cov = 0, varX = 0, varY = 0;
    for (int i = 0; i < n; i++) {
      final dx = xs[i] - meanX;
      final dy = ys[i] - meanY;
      cov += dx * dy;
      varX += dx * dx;
      varY += dy * dy;
    }
    final denom = math.sqrt(varX * varY);
    return denom == 0 ? null : cov / denom;
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  String _dateKey(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-'
      '${dt.day.toString().padLeft(2, '0')}';
}

// ---------------------------------------------------------------------------
// Result types
// ---------------------------------------------------------------------------

class StreakResult {
  const StreakResult({required this.current, required this.longest});
  final int current;
  final int longest;
}

class WeeklyComparison {
  const WeeklyComparison({
    required this.thisWeekTotal,
    required this.lastWeekTotal,
    required this.thisWeekDailyAvg,
    required this.lastWeekDailyAvg,
    required this.percentChange,
  });
  final double thisWeekTotal;
  final double lastWeekTotal;
  final double thisWeekDailyAvg;
  final double lastWeekDailyAvg;
  final double? percentChange;
}

class PersonalRecords {
  const PersonalRecords({required this.maxValues, required this.maxDates});
  final Map<String, double> maxValues;
  final Map<String, String> maxDates;
}
