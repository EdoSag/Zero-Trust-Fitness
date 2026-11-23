import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:health/health.dart';
import 'package:intl/intl.dart';
import 'package:zerotrust_fitness/components/empty_state_widget.dart';
import 'package:zerotrust_fitness/core/storage/fitness_vault.dart';
import 'package:zerotrust_fitness/core/utils/units_formatter.dart';
import 'package:zerotrust_fitness/features/dashboard/metric_card_specs.dart';
import 'package:zerotrust_fitness/features/goals/goals_provider.dart';
import 'package:zerotrust_fitness/features/health/data/health_service.dart';
import 'package:zerotrust_fitness/features/sleep/sleep_nights.dart';
import 'package:zerotrust_fitness/l10n/l10n.dart';
import 'package:zerotrust_fitness/pages/goals_page.dart';

const _gradient = [Color(0xFF1D4ED8), Color(0xFF6D28D9)];
const _deepColor = Color(0xFF1D4ED8);
const _remColor = Color(0xFF8B5CF6);
const _lightColor = Color(0xFF38BDF8);
const _asleepColor = Color(0xFF0EA5E9);
const _awakeColor = Color(0xFFF59E0B);

/// Sleep per night, read from Health Connect when it has a month of it and
/// from the vault for everything stored (other devices, entries by hand).
typedef SleepLoader = Future<Map<String, SleepNight>> Function();

/// Last night in stages, and weekly or monthly trends: how long, when to bed
/// and up, how steady, and against the sleep goal.
class SleepPage extends ConsumerStatefulWidget {
  const SleepPage({super.key, required this.vault, this.loadHealthSleep});

  final FitnessVault vault;

  /// Health Connect's nights (tests pass their own); by default the last
  /// 30 days are read, when sleep may be read.
  final SleepLoader? loadHealthSleep;

  @override
  ConsumerState<SleepPage> createState() => _SleepPageState();

  static Future<Map<String, SleepNight>> healthSleep() async {
    try {
      final service = HealthService();
      if (!await service.isHealthConnectAvailable()) return const {};
      final health = Health();
      final readable = <HealthDataType>[];
      for (final type in service.types) {
        if (!HealthService.sleepTypeSet.contains(type)) continue;
        try {
          final ok = await health.hasPermissions(
            [type],
            permissions: [HealthDataAccess.READ],
          );
          if (ok != false) readable.add(type);
        } catch (_) {}
      }
      final points = await service.fetchSleep(readable: readable, days: 30);
      return SleepNights.fromHealth(points);
    } catch (e) {
      debugPrint('Sleep not read from Health Connect: $e');
      return const {};
    }
  }
}

class _SleepPageState extends ConsumerState<SleepPage> {
  Map<String, SleepNight> _nights = const {};
  bool _loading = true;
  int _days = 7;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final nights = <String, SleepNight>{};
    try {
      for (final row in await widget.vault.fetchDailyMetrics()) {
        final key = row['date_key']?.toString();
        if (key == null) continue;
        final night = SleepNight.fromMetrics(
          key,
          FitnessVault.parseMetrics(row['metrics']),
        );
        if (night != null) nights[key] = night;
      }
    } catch (e) {
      debugPrint('Sleep not loaded: $e');
    }
    if (mounted) setState(() => _nights = Map.of(nights));
    final health = await (widget.loadHealthSleep ?? SleepPage.healthSleep)
        .call();
    for (final e in health.entries) {
      final stored = nights[e.key];
      if (stored == null || e.value.asleepMinutes >= stored.asleepMinutes) {
        nights[e.key] = e.value;
      } else if (stored.bedtime == null && e.value.bedtime != null) {
        // Entered by hand as longer: keep its minutes, take the times.
        nights[e.key] = SleepNight(
          dateKey: stored.dateKey,
          asleepMinutes: stored.asleepMinutes,
          lightMinutes: stored.lightMinutes,
          deepMinutes: stored.deepMinutes,
          remMinutes: stored.remMinutes,
          awakeMinutes: stored.awakeMinutes,
          bedtime: e.value.bedtime,
          wakeTime: e.value.wakeTime,
        );
      }
    }
    if (!mounted) return;
    setState(() {
      _nights = nights;
      _loading = false;
    });
  }

  /// The [count] days ending [endsDaysAgo] days before today, oldest first.
  List<({DateTime day, SleepNight? night})> _range(
    int count, {
    int endsDaysAgo = 0,
  }) {
    final now = DateTime.now();
    return [
      for (var i = count - 1; i >= 0; i--)
        () {
          final day = DateTime(now.year, now.month, now.day - endsDaysAgo - i);
          return (day: day, night: _nights[FitnessVault.dateKeyOf(day)]);
        }(),
    ];
  }

  String _duration(num minutes) => formatSleepMinutes(minutes);

  String _clock(int minuteOfDay) {
    final now = DateTime.now();
    return UnitsFormatter().formatTime(
      DateTime(
        now.year,
        now.month,
        now.day,
        minuteOfDay ~/ 60,
        minuteOfDay % 60,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final goal = ref
        .watch(goalsProvider)
        .asData
        ?.value
        .forKey('sleep_asleep_min');
    final goalMinutes = goal != null && goal.period != 'weekly'
        ? goal.targetValue
        : goal == null
        ? null
        : goal.targetValue / 7;
    final latest = _nights.values.isEmpty
        ? null
        : _nights.values.reduce(
            (a, b) => a.dateKey.compareTo(b.dateKey) >= 0 ? a : b,
          );
    final range = _range(_days);
    final stats = SleepStats([
      for (final d in range)
        if (d.night != null) d.night!,
    ]);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.sleep),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: _gradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        foregroundColor: Colors.white,
      ),
      body: _loading && _nights.isEmpty
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : latest == null
          ? Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: EmptyStateWidget(
                  icon: Icons.nights_stay_outlined,
                  title: context.l10n.noSleepYet,
                  subtitle: context.l10n.noSleepYetHint,
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              children: [
                _lastNight(context, latest, goalMinutes),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<int>(
                    segments: [
                      ButtonSegment(value: 7, label: Text(context.l10n.week)),
                      ButtonSegment(value: 30, label: Text(context.l10n.month)),
                    ],
                    selected: {_days},
                    showSelectedIcon: false,
                    onSelectionChanged: (s) => setState(() => _days = s.first),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  key: const ValueKey('sleep-chart'),
                  height: 200,
                  child: stats.isEmpty
                      ? EmptyStateWidget.noData(context.l10n.sleep)
                      : _chart(range, goalMinutes),
                ),
                const SizedBox(height: 24),
                _panel(theme, [
                  _stat(
                    context.l10n.averageSleep,
                    stats.isEmpty ? '–' : _duration(stats.averageAsleep),
                  ),
                  if (stats.averageBedtime case final bed?)
                    _stat(context.l10n.averageBedtime, _clock(bed)),
                  if (stats.averageWakeTime case final wake?)
                    _stat(context.l10n.averageWakeUp, _clock(wake)),
                  if (stats.bedtimeSpread case final spread?)
                    _stat(
                      context.l10n.bedtimeConsistency,
                      context.l10n.plusMinusMinutes(spread),
                    ),
                  if (_days == 7) ?_weekOverWeek(),
                  if (goalMinutes != null)
                    _stat(
                      context.l10n.nightsAtGoal(_duration(goalMinutes)),
                      context.l10n.nOfTotal(
                        stats.nightsReaching(goalMinutes),
                        stats.nights.length,
                      ),
                      trailing: _goalButton(context.l10n.edit),
                    )
                  else
                    _stat(
                      context.l10n.goal,
                      context.l10n.notSet,
                      trailing: _goalButton(context.l10n.setGoal),
                    ),
                ]),
                if (stats.hasStages) ...[
                  const SizedBox(height: 24),
                  Text(
                    context.l10n.averageStages,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _panel(theme, [
                    _stageStat(
                      context.l10n.sleepStageDeep,
                      stats.averageDeep,
                      stats,
                      _deepColor,
                    ),
                    _stageStat(
                      context.l10n.sleepStageRem,
                      stats.averageRem,
                      stats,
                      _remColor,
                    ),
                    _stageStat(
                      context.l10n.sleepStageLight,
                      stats.averageLight,
                      stats,
                      _lightColor,
                    ),
                  ]),
                ],
                const SizedBox(height: 16),
                Text(
                  context.l10n.sleepSourcesNote,
                  style: TextStyle(color: theme.hintColor, fontSize: 12),
                ),
              ],
            ),
    );
  }

  Widget _goalButton(String label) => TextButton(
    onPressed: () => Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const GoalsPage())),
    child: Text(label),
  );

  /// This week's average against the week before, when both have nights.
  Widget? _weekOverWeek() {
    final now = SleepStats([
      for (final d in _range(7))
        if (d.night != null) d.night!,
    ]);
    final before = SleepStats([
      for (final d in _range(7, endsDaysAgo: 7))
        if (d.night != null) d.night!,
    ]);
    if (now.isEmpty || before.isEmpty) return null;
    final diff = (now.averageAsleep - before.averageAsleep).round();
    final text = diff == 0
        ? context.l10n.sameAsBefore
        : '${diff > 0 ? '+' : '−'}${context.l10n.nMin(diff.abs())}';
    return _stat(context.l10n.comparedWithWeekBefore, text);
  }

  Widget _lastNight(BuildContext context, SleepNight night, num? goalMinutes) {
    final theme = Theme.of(context);
    final units = UnitsFormatter();
    final isToday = night.dateKey == FitnessVault.dateKeyOf(DateTime.now());
    final day = DateTime.tryParse(night.dateKey);
    final title = isToday || day == null
        ? context.l10n.lastNight
        : DateFormat.MMMEd().format(day);
    final parts = <(String, int, Color)>[
      if (night.hasStages) ...[
        (context.l10n.sleepStageDeep, night.deepMinutes, _deepColor),
        (context.l10n.sleepStageRem, night.remMinutes, _remColor),
        (context.l10n.sleepStageLight, night.lightMinutes, _lightColor),
      ],
      if (night.otherAsleepMinutes > 0)
        (context.l10n.sleepStageAsleep, night.otherAsleepMinutes, _asleepColor),
      if (night.awakeMinutes > 0)
        (context.l10n.sleepStageAwake, night.awakeMinutes, _awakeColor),
    ];
    final total = parts.fold<int>(0, (t, p) => t + p.$2);
    return Card(
      key: const ValueKey('last-night'),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(color: theme.hintColor)),
            const SizedBox(height: 4),
            Text(
              _duration(night.asleepMinutes),
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            if (night.bedtime != null && night.wakeTime != null)
              Text(
                '${units.formatTime(night.bedtime!)} – '
                '${units.formatTime(night.wakeTime!)}',
                style: theme.textTheme.titleSmall,
              ),
            if (goalMinutes != null && goalMinutes > 0) ...[
              const SizedBox(height: 8),
              Text(
                night.asleepMinutes >= goalMinutes
                    ? context.l10n.sleepGoalReached
                    : context.l10n.sleepShortOfGoal(
                        _duration(goalMinutes - night.asleepMinutes),
                      ),
                style: TextStyle(color: theme.hintColor),
              ),
            ],
            if (total > 0) ...[
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  height: 14,
                  child: Row(
                    children: [
                      for (final p in parts)
                        if (p.$2 > 0)
                          Expanded(
                            flex: math.max(1, p.$2),
                            child: ColoredBox(color: p.$3),
                          ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 16,
                runSpacing: 6,
                children: [
                  for (final p in parts)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: p.$3,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${p.$1} ${_duration(p.$2)}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _chart(
    List<({DateTime day, SleepNight? night})> range,
    num? goalMinutes,
  ) {
    final hours = [for (final d in range) (d.night?.asleepMinutes ?? 0) / 60];
    final goalHours = goalMinutes == null ? null : goalMinutes / 60;
    final top = math.max(hours.fold<double>(0, math.max), goalHours ?? 0);
    final maxY = math.max(4.0, (top + 1).ceilToDouble());
    final showEvery = range.length > 14 ? 7 : 1;
    final width = range.length <= 7 ? 16.0 : 6.0;
    return BarChart(
      BarChartData(
        minY: 0,
        maxY: maxY,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 2,
          getDrawingHorizontalLine: (_) => FlLine(
            color: Colors.white.withValues(alpha: 0.08),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        extraLinesData: ExtraLinesData(
          horizontalLines: [
            if (goalHours != null && goalHours > 0)
              HorizontalLine(
                y: goalHours,
                color: Colors.white.withValues(alpha: 0.5),
                strokeWidth: 1,
                dashArray: const [4, 4],
              ),
          ],
        ),
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => Colors.black87,
            getTooltipItem: (group, _, rod, _) {
              final d = range[group.x];
              return BarTooltipItem(
                '${DateFormat.MMMd().format(d.day)}\n'
                '${_duration(d.night?.asleepMinutes ?? 0)}',
                const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              );
            },
          ),
        ),
        barGroups: [
          for (var i = 0; i < range.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [_rod(range[i].night, hours[i], width)],
            ),
        ],
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              interval: 2,
              getTitlesWidget: (v, _) => Text(
                context.l10n.nHoursShort(v.toInt()),
                style: const TextStyle(fontSize: 10),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              getTitlesWidget: (v, meta) {
                final i = v.toInt();
                if (i < 0 || i >= range.length || i % showEvery != 0) {
                  return const SizedBox.shrink();
                }
                final day = range[i].day;
                return SideTitleWidget(
                  meta: meta,
                  child: Text(
                    range.length <= 7
                        ? DateFormat.E().format(day)
                        : DateFormat.Md().format(day),
                    style: const TextStyle(fontSize: 10),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  /// A bar in stages (deep at the bottom) when the night has them.
  BarChartRodData _rod(SleepNight? night, double hours, double width) {
    final radius = BorderRadius.circular(3);
    if (night == null || !night.hasStages) {
      return BarChartRodData(
        toY: hours,
        width: width,
        borderRadius: radius,
        color: _asleepColor,
      );
    }
    final items = <BarChartRodStackItem>[];
    var from = 0.0;
    for (final (minutes, color) in [
      (night.deepMinutes, _deepColor),
      (night.remMinutes, _remColor),
      (night.lightMinutes, _lightColor),
      (night.otherAsleepMinutes, _asleepColor),
    ]) {
      if (minutes <= 0) continue;
      final to = from + minutes / 60;
      items.add(BarChartRodStackItem(from, to, color));
      from = to;
    }
    return BarChartRodData(
      toY: hours,
      width: width,
      borderRadius: radius,
      rodStackItems: items,
      color: _asleepColor,
    );
  }

  Widget _panel(ThemeData theme, List<Widget> rows) => Container(
    decoration: BoxDecoration(
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
    ),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    child: Column(
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) const Divider(height: 1),
          rows[i],
        ],
      ],
    ),
  );

  Widget _stat(String label, String value, {Widget? trailing}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        ?trailing,
      ],
    ),
  );

  Widget _stageStat(
    String label,
    double minutes,
    SleepStats stats,
    Color color,
  ) {
    final staged = stats.averageDeep + stats.averageRem + stats.averageLight;
    final share = staged <= 0 ? 0 : (minutes / staged * 100).round();
    return _stat(
      label,
      '${_duration(minutes)} · $share%',
      trailing: Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}
