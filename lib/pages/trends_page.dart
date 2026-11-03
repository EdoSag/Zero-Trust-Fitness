import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:zerotrust_fitness/components/compact_metric_card.dart';
import 'package:zerotrust_fitness/components/empty_state_widget.dart';
import 'package:zerotrust_fitness/features/dashboard/metric_card_specs.dart';

enum ChartRange { day, week, month }

class TrendsPage extends StatefulWidget {
  const TrendsPage({
    super.key,
    required this.hourlyTrendPoints,
    required this.currentWeekPoints,
    required this.currentMonthPoints,
    required this.selectedMetricWeekPoints,
    required this.selectedMetricMonthPoints,
    required this.selectedTrendMetricKey,
    required this.onTrendMetricChanged,
    required this.onRefresh,
    this.baselines = const {},
    this.sleepStepsCorrelation,
  });

  final List<DualMetricPoint> hourlyTrendPoints;
  final List<DualMetricPoint> currentWeekPoints;
  final List<DualMetricPoint> currentMonthPoints;
  final List<SingleMetricPoint> selectedMetricWeekPoints;
  final List<SingleMetricPoint> selectedMetricMonthPoints;
  final String selectedTrendMetricKey;
  final ValueChanged<String> onTrendMetricChanged;
  final Future<void> Function() onRefresh;
  final Map<String, double> baselines;
  final double? sleepStepsCorrelation;

  @override
  State<TrendsPage> createState() => _TrendsPageState();
}

class _TrendsPageState extends State<TrendsPage> {
  ChartRange _range = ChartRange.week;
  bool _baselineCardDismissed = false;
  bool _correlationCardDismissed = false;

  Widget _buildDualMetricBarChart({
    required List<DualMetricPoint> points,
    required Color stepColor,
    required Color heartColor,
    int xLabelInterval = 1,
  }) {
    if (points.isEmpty) {
      return EmptyStateWidget.noData('trend data');
    }

    final maxY = points
        .map((p) => p.steps > p.heartPoints ? p.steps : p.heartPoints)
        .fold<double>(0, (cur, v) => v > cur ? v : cur);
    final axisMax = maxY <= 0 ? 10.0 : (maxY * 1.2).ceilToDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            LegendChip(color: stepColor, label: 'Steps'),
            const SizedBox(width: 8),
            LegendChip(color: heartColor, label: 'Heart Points'),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: BarChart(
            BarChartData(
              maxY: axisMax,
              minY: 0,
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (_) => FlLine(
                  color: Colors.white.withValues(alpha: 0.08),
                  strokeWidth: 1,
                ),
              ),
              borderData: FlBorderData(show: false),
              barTouchData: BarTouchData(
                enabled: true,
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (_) => Colors.black87,
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    final point = points[group.x.toInt()];
                    final label = rodIndex == 0 ? 'Steps' : 'Heart Points';
                    final value = rod.toY.toStringAsFixed(0);
                    return BarTooltipItem(
                      '${point.label}\n$label: $value',
                      const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    );
                  },
                ),
              ),
              groupsSpace: 10,
              barGroups: points.asMap().entries.map((entry) {
                final i = entry.key;
                final point = entry.value;
                return BarChartGroupData(
                  x: i,
                  barsSpace: 4,
                  barRods: [
                    BarChartRodData(
                      toY: point.steps,
                      width: 8,
                      borderRadius: BorderRadius.circular(3),
                      color: stepColor,
                    ),
                    BarChartRodData(
                      toY: point.heartPoints,
                      width: 8,
                      borderRadius: BorderRadius.circular(3),
                      color: heartColor,
                    ),
                  ],
                );
              }).toList(growable: false),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 32,
                    interval: axisMax / 4,
                    getTitlesWidget: (value, meta) => Text(
                      value.toInt().toString(),
                      style: const TextStyle(fontSize: 10),
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 32,
                    getTitlesWidget: (value, meta) {
                      final index = value.toInt();
                      if (index < 0 || index >= points.length) {
                        return const SizedBox.shrink();
                      }
                      if (index % xLabelInterval != 0) {
                        return const SizedBox.shrink();
                      }
                      return SideTitleWidget(
                        meta: meta,
                        child: Text(points[index].label,
                            style: const TextStyle(fontSize: 10)),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSingleMetricBarChart({
    required List<SingleMetricPoint> points,
    required Color color,
  }) {
    if (points.isEmpty) {
      return EmptyStateWidget.noData('trend data');
    }

    final maxY = points
        .map((p) => p.value)
        .fold<double>(0, (cur, v) => v > cur ? v : cur);
    final axisMax = maxY <= 0 ? 10.0 : (maxY * 1.2).ceilToDouble();

    return BarChart(
      BarChartData(
        maxY: axisMax,
        minY: 0,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) => FlLine(
            color: Colors.white.withValues(alpha: 0.08),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => Colors.black87,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final point = points[group.x.toInt()];
              final spec = metricCardSpecs
                  .where((s) => s.key == widget.selectedTrendMetricKey)
                  .firstOrNull;
              final unit = spec?.unit ?? '';
              final value = rod.toY.toStringAsFixed(1);
              return BarTooltipItem(
                '${point.label}\n$value${unit.isEmpty ? '' : ' $unit'}',
                const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              );
            },
          ),
        ),
        groupsSpace: 10,
        barGroups: points.asMap().entries.map((entry) {
          final i = entry.key;
          final point = entry.value;
          return BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: point.value,
                width: 14,
                borderRadius: BorderRadius.circular(4),
                color: color,
              ),
            ],
          );
        }).toList(growable: false),
        titlesData: FlTitlesData(
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              interval: axisMax / 4,
              getTitlesWidget: (value, meta) => Text(
                value.toInt().toString(),
                style: const TextStyle(fontSize: 10),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= points.length) {
                  return const SizedBox.shrink();
                }
                return SideTitleWidget(
                  meta: meta,
                  child: Text(points[index].label,
                      style: const TextStyle(fontSize: 10)),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildInsightCards(ThemeData theme) {
    final cards = <Widget>[];

    final hrBaseline = widget.baselines['resting_hr_bpm_avg'];
    final stepsBaseline = widget.baselines['steps'];
    if (!_baselineCardDismissed && (hrBaseline != null || stepsBaseline != null)) {
      final parts = <String>[
        if (hrBaseline != null && hrBaseline > 0)
          'Resting HR avg: ${hrBaseline.toStringAsFixed(0)} bpm',
        if (stepsBaseline != null && stepsBaseline > 0)
          'Daily steps avg: ${stepsBaseline.toStringAsFixed(0)}',
      ];
      cards.add(_InsightCard(
        theme: theme,
        icon: Icons.analytics_outlined,
        title: '30-Day Baselines',
        body: parts.join('  ·  '),
        onDismiss: () => setState(() => _baselineCardDismissed = true),
      ));
      cards.add(const SizedBox(height: 12));
    }

    final corr = widget.sleepStepsCorrelation;
    if (!_correlationCardDismissed && corr != null) {
      final strength =
          corr.abs() >= 0.5 ? 'strong' : corr.abs() >= 0.3 ? 'moderate' : 'weak';
      final direction = corr >= 0 ? 'positive' : 'negative';
      cards.add(_InsightCard(
        theme: theme,
        icon: Icons.link_outlined,
        title: 'Sleep & Steps',
        body:
            'Your sleep duration shows a $strength $direction correlation '
            'with your daily step count.',
        onDismiss: () => setState(() => _correlationCardDismissed = true),
      ));
      cards.add(const SizedBox(height: 12));
    }

    return cards;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final dualPoints = switch (_range) {
      ChartRange.day => widget.hourlyTrendPoints,
      ChartRange.week => widget.currentWeekPoints,
      ChartRange.month => widget.currentMonthPoints,
    };
    final singlePoints = switch (_range) {
      ChartRange.day => widget.selectedMetricWeekPoints,
      ChartRange.week => widget.selectedMetricWeekPoints,
      ChartRange.month => widget.selectedMetricMonthPoints,
    };
    final dualLabel = switch (_range) {
      ChartRange.day => 'Steps & Heart Points (Today, Hourly)',
      ChartRange.week => 'Steps & Heart Points (This Week)',
      ChartRange.month => 'Steps & Heart Points (Last 30 Days)',
    };
    final singleLabel = switch (_range) {
      ChartRange.day || ChartRange.week => 'Selected Metric (Week)',
      ChartRange.month => 'Selected Metric (Month)',
    };

    return Scaffold(
      appBar: AppBar(title: const Text('Trends')),
      body: RefreshIndicator(
        onRefresh: widget.onRefresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  theme.colorScheme.primary.withValues(alpha: 0.15),
                  theme.colorScheme.secondary.withValues(alpha: 0.18),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              border:
                  Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ..._buildInsightCards(theme),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Analytics', style: theme.textTheme.titleMedium),
                    const Icon(Icons.insights, color: Color(0xFF6366F1)),
                  ],
                ),
                const SizedBox(height: 16),
                Center(
                  child: SegmentedButton<ChartRange>(
                    segments: const [
                      ButtonSegment(
                          value: ChartRange.day,
                          label: Text('Day'),
                          icon: Icon(Icons.today_outlined, size: 16)),
                      ButtonSegment(
                          value: ChartRange.week,
                          label: Text('Week'),
                          icon: Icon(Icons.date_range_outlined, size: 16)),
                      ButtonSegment(
                          value: ChartRange.month,
                          label: Text('Month'),
                          icon: Icon(Icons.calendar_month_outlined, size: 16)),
                    ],
                    selected: {_range},
                    onSelectionChanged: (s) =>
                        setState(() => _range = s.first),
                  ),
                ),
                const SizedBox(height: 20),
                Text(dualLabel, style: theme.textTheme.labelLarge),
                const SizedBox(height: 8),
                SizedBox(
                  height: 220,
                  child: _buildDualMetricBarChart(
                    points: dualPoints,
                    stepColor: const Color(0xFF5B7CFF),
                    heartColor: const Color(0xFFFF5D7A),
                    xLabelInterval: _range == ChartRange.month ? 7 : 1,
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: Text(singleLabel,
                          style: theme.textTheme.labelLarge),
                    ),
                    const SizedBox(width: 10),
                    DropdownButton<String>(
                      value: widget.selectedTrendMetricKey,
                      items: metricCardSpecs
                          .map(
                            (spec) => DropdownMenuItem<String>(
                              value: spec.key,
                              child: Text(spec.title),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: (value) {
                        if (value == null) return;
                        widget.onTrendMetricChanged(value);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 220,
                  child: _buildSingleMetricBarChart(
                    points: singlePoints,
                    color: const Color(0xFF10B981),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InsightCard extends StatelessWidget {
  const _InsightCard({
    required this.theme,
    required this.icon,
    required this.title,
    required this.body,
    required this.onDismiss,
  });

  final ThemeData theme;
  final IconData icon;
  final String title;
  final String body;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(title,
                        style: theme.textTheme.labelLarge
                            ?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.secondaryContainer
                            .withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text('Informational',
                          style: theme.textTheme.labelSmall
                              ?.copyWith(fontSize: 9)),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(body,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.hintColor)),
                const SizedBox(height: 2),
                Text('Not medical advice · based on your logged data',
                    style: theme.textTheme.labelSmall?.copyWith(
                        fontSize: 9,
                        color: theme.hintColor.withValues(alpha: 0.6))),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.close, size: 16, color: theme.hintColor),
            onPressed: onDismiss,
            tooltip: 'Dismiss',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          ),
        ],
      ),
    );
  }
}
