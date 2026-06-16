import 'package:cryptography/cryptography.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zerotrust_fitness/components/empty_state_widget.dart';
import 'package:zerotrust_fitness/core/storage/local_vault.dart';
import 'package:zerotrust_fitness/features/goals/goals_provider.dart';
import 'package:zerotrust_fitness/pages/goals_page.dart';

class MetricDetailPage extends ConsumerStatefulWidget {
  const MetricDetailPage({
    super.key,
    required this.metricKey,
    required this.metricTitle,
    required this.unit,
    required this.gradientColors,
    required this.secretKey,
  });

  final String metricKey;
  final String metricTitle;
  final String unit;
  final List<Color> gradientColors;
  final SecretKey secretKey;

  @override
  ConsumerState<MetricDetailPage> createState() => _MetricDetailPageState();
}

class _MetricDetailPageState extends ConsumerState<MetricDetailPage> {
  List<Map<String, dynamic>> _dailyMetrics = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final rows = await LocalVault().fetchDailyMetrics(widget.secretKey);
      if (mounted) setState(() { _dailyMetrics = rows; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _dateKey(DateTime date) {
    final d = date.toLocal();
    return '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }

  num _valueFromRow(Map<String, dynamic>? row, String key) {
    if (row == null) return 0;
    final metrics = row['metrics'];
    if (metrics is Map) {
      final v = metrics[key];
      if (v is num) return v;
      if (v is String) return num.tryParse(v) ?? 0;
    }
    final fb = row[key];
    if (fb is num) return fb;
    if (fb is String) return num.tryParse(fb) ?? 0;
    return 0;
  }

  /// Returns (label, value) pairs for the last [days] days, oldest first.
  List<({String label, double value})> _buildPoints(int days) {
    final today = DateTime.now();
    final currentDay = DateTime(today.year, today.month, today.day);
    final byDate = <String, Map<String, dynamic>>{};
    for (final row in _dailyMetrics) {
      final k = row['date_key']?.toString();
      if (k != null) byDate[k] = row;
    }
    return List.generate(days, (i) {
      final date = currentDay.subtract(Duration(days: days - 1 - i));
      final key = _dateKey(date);
      final row = byDate[key];
      final label = days <= 7
          ? const ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'][date.weekday % 7]
          : '${date.month}/${date.day}';
      return (label: label, value: _valueFromRow(row, widget.metricKey).toDouble());
    }, growable: false);
  }

  double _average(List<({String label, double value})> points) {
    final nonZero = points.where((p) => p.value > 0).toList();
    if (nonZero.isEmpty) return 0;
    return nonZero.map((p) => p.value).reduce((a, b) => a + b) / nonZero.length;
  }

  /// HC vs manual contribution totals across all stored rows.
  ({double hc, double manual}) _sourceTotals() {
    double hc = 0, manual = 0;
    final key = widget.metricKey;
    for (final row in _dailyMetrics) {
      hc += _valueFromRow(row, '${key}_hc').toDouble();
      manual += _valueFromRow(row, '${key}_manual').toDouble();
    }
    return (hc: hc, manual: manual);
  }

  Widget _buildChart(List<({String label, double value})> points, Color color) {
    final maxY = points.map((p) => p.value).fold<double>(0, (a, b) => b > a ? b : a);
    final axisMax = maxY <= 0 ? 10.0 : (maxY * 1.2).ceilToDouble();
    final showEvery = points.length > 14 ? 7 : 1;

    return BarChart(
      BarChartData(
        maxY: axisMax,
        minY: 0,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) =>
              FlLine(color: Colors.white.withValues(alpha: 0.08), strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => Colors.black87,
            getTooltipItem: (group, _, rod, __) {
              final p = points[group.x.toInt()];
              final unit = widget.unit.isEmpty ? '' : ' ${widget.unit}';
              return BarTooltipItem(
                '${p.label}\n${rod.toY.toStringAsFixed(1)}$unit',
                const TextStyle(
                    color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
              );
            },
          ),
        ),
        barGroups: points.asMap().entries.map((e) {
          return BarChartGroupData(
            x: e.key,
            barRods: [
              BarChartRodData(
                toY: e.value.value,
                width: points.length <= 7 ? 14 : 6,
                borderRadius: BorderRadius.circular(3),
                color: color,
              ),
            ],
          );
        }).toList(growable: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 36,
              interval: axisMax / 4,
              getTitlesWidget: (v, _) => Text(
                v.toInt().toString(),
                style: const TextStyle(fontSize: 10),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              getTitlesWidget: (v, meta) {
                final idx = v.toInt();
                if (idx < 0 || idx >= points.length) return const SizedBox.shrink();
                if (idx % showEvery != 0) return const SizedBox.shrink();
                return SideTitleWidget(
                  meta: meta,
                  child: Text(points[idx].label,
                      style: const TextStyle(fontSize: 10)),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatTile(String label, String value, {Widget? trailing}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 2),
                Text(value,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = widget.gradientColors.first;
    final goalsState = ref.watch(goalsProvider).asData?.value;
    final goal = goalsState?.forKey(widget.metricKey);

    final points7 = _buildPoints(7);
    final points30 = _buildPoints(30);
    final avg7 = _average(points7);
    final avg30 = _average(points30);
    final totals = _sourceTotals();
    final currentValue = points7.last.value;
    final goalProgress = goal != null && goal.targetValue > 0
        ? (currentValue / goal.targetValue).clamp(0.0, 1.0)
        : null;

    final unitSuffix = widget.unit.isEmpty ? '' : ' ${widget.unit}';

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.metricTitle),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: widget.gradientColors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 7-day chart
                  Text('Last 7 Days',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 180,
                    child: points7.every((p) => p.value == 0)
                        ? EmptyStateWidget.noData(widget.metricTitle)
                        : _buildChart(points7, color),
                  ),
                  const SizedBox(height: 24),
                  // Stats
                  Container(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.08)),
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    child: Column(
                      children: [
                        _buildStatTile(
                          '7-day average',
                          '${avg7.toStringAsFixed(1)}$unitSuffix',
                        ),
                        const Divider(height: 1),
                        _buildStatTile(
                          '30-day average',
                          '${avg30.toStringAsFixed(1)}$unitSuffix',
                        ),
                        if (goal != null) ...[
                          const Divider(height: 1),
                          _buildStatTile(
                            'Goal (${goal.period})',
                            '${goal.targetValue}$unitSuffix',
                            trailing: TextButton(
                              onPressed: () =>
                                  Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                    builder: (_) => const GoalsPage()),
                              ),
                              child: const Text('Edit'),
                            ),
                          ),
                          if (goalProgress != null) ...[
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Expanded(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: goalProgress,
                                      minHeight: 6,
                                      backgroundColor: theme.colorScheme
                                          .surfaceContainerHighest,
                                      color: color,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  '${(goalProgress * 100).round()}%',
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: color),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                          ],
                        ] else ...[
                          const Divider(height: 1),
                          _buildStatTile(
                            'Goal',
                            'Not set',
                            trailing: TextButton(
                              onPressed: () =>
                                  Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                    builder: (_) => const GoalsPage()),
                              ),
                              child: const Text('Set goal'),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  // Source breakdown (only show if any data exists)
                  if (totals.hc > 0 || totals.manual > 0) ...[
                    const SizedBox(height: 24),
                    Text('Source Breakdown',
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.08)),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: Column(
                        children: [
                          _buildStatTile(
                            'Health Connect',
                            '${totals.hc.toStringAsFixed(1)}$unitSuffix',
                          ),
                          const Divider(height: 1),
                          _buildStatTile(
                            'Manual entries',
                            '${totals.manual.toStringAsFixed(1)}$unitSuffix',
                          ),
                        ],
                      ),
                    ),
                  ],
                  // 30-day chart
                  const SizedBox(height: 24),
                  Text('Last 30 Days',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 180,
                    child: points30.every((p) => p.value == 0)
                        ? EmptyStateWidget.noData(widget.metricTitle)
                        : _buildChart(points30, color.withValues(alpha: 0.7)),
                  ),
                  const SizedBox(height: 28),
                ],
              ),
            ),
    );
  }
}
