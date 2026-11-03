import 'package:flutter/material.dart';
import 'package:zerotrust_fitness/features/health/domain/momentum_engine.dart';

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
        ? 'Target hit! Tomorrow\'s target grows 5%.'
        : '${momentum.pointsToTarget} more Heart Points to hit today\'s target.';
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
                'Momentum',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              if (momentum.gainedToday > 0)
                Text(
                  '+${momentum.gainedToday} today',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: _accent,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              IconButton(
                icon: Icon(Icons.info_outline_rounded, size: 20, color: muted),
                tooltip: 'How Momentum works',
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
              Text('Today\'s target', style: theme.textTheme.bodyMedium),
              Text(
                '${momentum.todayPoints} / ${momentum.target} pts',
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
        title: const Text('How Momentum works'),
        content: const Text(
          'Your daily target starts at ${MomentumEngine.defaultTarget} Heart '
          'Points (about 150 a week, the WHO activity guideline) and adapts to '
          'you: hit it and it grows 5%; fall below half of it and it eases 3%.'
          '\n\n'
          'Momentum (0-100) is how close you came to your target over the last '
          '7 days, with recent days counting most. Missing a day lowers it a '
          'little instead of resetting it, and today can only push it up.'
          '\n\n'
          'Everything is calculated on this device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }
}
