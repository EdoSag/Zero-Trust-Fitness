import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:zerotrust_fitness/features/summary/weekly_summary.dart';
import 'package:zerotrust_fitness/l10n/l10n.dart';

/// This week next to last week: Heart Points, steps, workouts, active days.
class WeeklySummaryCard extends StatelessWidget {
  const WeeklySummaryCard({super.key, required this.summary});

  final WeeklySummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final n = NumberFormat.compact();
    final week = summary.week;
    final prev = summary.previous;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.insights_outlined, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  summary.isComplete ? context.l10n.thisWeek : context.l10n.thisWeekSoFar,
                  style: theme.textTheme.titleMedium,
                ),
              ),
              Text(
                context.l10n.vsTheWeekBefore,
                style: TextStyle(color: theme.hintColor, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _cell(
                context,
                '${week.heartPoints}',
                context.l10n.heartPoints,
                WeeklySummary.change(week.heartPoints, prev.heartPoints),
              ),
              _cell(
                context,
                n.format(week.steps),
                'steps',
                WeeklySummary.change(week.steps, prev.steps),
              ),
              _cell(
                context,
                '${week.workouts}',
                'workouts',
                WeeklySummary.change(week.workouts, prev.workouts),
              ),
              _cell(
                context,
                '${week.activeDays}/${summary.daysCounted}',
                context.l10n.activeDays,
                null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _cell(BuildContext context, String value, String label, int? change) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(label, style: TextStyle(color: theme.hintColor, fontSize: 12)),
          if (change != null)
            Text(
              change >= 0 ? '+$change%' : '$change%',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: change >= 0 ? Colors.green : theme.colorScheme.error,
              ),
            ),
        ],
      ),
    );
  }
}
