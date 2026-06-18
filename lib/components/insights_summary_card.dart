import 'package:flutter/material.dart';
import 'package:zerotrust_fitness/core/services/insights_service.dart';

class InsightsSummaryCard extends StatelessWidget {
  const InsightsSummaryCard({
    super.key,
    required this.streaks,
    required this.weeklySteps,
  });

  final StreakResult streaks;
  final WeeklyComparison weeklySteps;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pct = weeklySteps.percentChange;
    final pctText = pct == null
        ? 'No prior week data'
        : pct >= 0
            ? '+${pct.toStringAsFixed(0)}% vs last week'
            : '${pct.toStringAsFixed(0)}% vs last week';
    final pctColor = pct == null
        ? theme.hintColor
        : pct >= 0
            ? Colors.green
            : theme.colorScheme.error;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          // Streak
          Expanded(
            child: _Stat(
              icon: Icons.local_fire_department,
              iconColor: const Color(0xFFF97316),
              value: '${streaks.current}',
              label: 'day streak',
              sub: streaks.longest > streaks.current
                  ? 'Best: ${streaks.longest}'
                  : streaks.current > 0
                      ? 'Personal best!'
                      : null,
            ),
          ),
          Container(
            width: 1,
            height: 48,
            color: Colors.white.withValues(alpha: 0.1),
          ),
          // Weekly steps comparison
          Expanded(
            child: _Stat(
              icon: Icons.directions_walk,
              iconColor: const Color(0xFF3B82F6),
              value: _compact(weeklySteps.thisWeekTotal),
              label: 'steps this week',
              sub: pctText,
              subColor: pctColor,
            ),
          ),
        ],
      ),
    );
  }

  String _compact(double v) {
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}k';
    return v.toInt().toString();
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
    this.sub,
    this.subColor,
  });

  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;
  final String? sub;
  final Color? subColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 16),
              const SizedBox(width: 4),
              Text(
                value,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          Text(label,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.hintColor)),
          if (sub != null) ...[
            const SizedBox(height: 2),
            Text(
              sub!,
              style: theme.textTheme.labelSmall?.copyWith(
                color: subColor ?? theme.hintColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
