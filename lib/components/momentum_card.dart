import 'package:flutter/material.dart';
import 'package:zerotrust_fitness/features/health/domain/momentum_engine.dart';
import 'package:zerotrust_fitness/l10n/l10n.dart';

/// Shows the Momentum score, today's adaptive Heart Points target and an
/// explainer dialog.
class MomentumCard extends StatelessWidget {
  const MomentumCard({super.key, required this.momentum});

  final MomentumResult momentum;

  static const _accent = Color(0xFFF59E0B);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final status = momentum.targetHit
        ? context.l10n.targetHitTomorrowsTargetGrows
        : context.l10n.morePointsToTarget(momentum.pointsToTarget);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bolt_rounded, color: _accent),
              const SizedBox(width: 8),
              Text(
                context.l10n.momentum,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              if (momentum.gainedToday > 0)
                Text(
                  context.l10n.gainedToday(momentum.gainedToday),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: _accent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              IconButton(
                icon: Icon(Icons.info_outline_rounded, size: 20, color: muted),
                tooltip: context.l10n.howMomentumWorks,
                visualDensity: VisualDensity.compact,
                onPressed: () => _showInfo(context),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${momentum.momentum}',
                style: theme.textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    '/ 100 · ${momentum.label}',
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(color: muted),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(context.l10n.todaysTarget, style: theme.textTheme.bodyMedium),
              Text(
                context.l10n.pointsOfTarget(momentum.todayPoints, momentum.target),
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: momentum.todayProgress,
              minHeight: 8,
              color: _accent,
              backgroundColor: _accent.withValues(alpha: 0.18),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            status,
            style: theme.textTheme.bodySmall?.copyWith(color: muted),
          ),
        ],
      ),
    );
  }

  Future<void> _showInfo(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.howMomentumWorks),
        content: Text(
          context.l10n.momentumExplained(MomentumEngine.defaultTarget),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(context.l10n.gotIt),
          ),
        ],
      ),
    );
  }
}
