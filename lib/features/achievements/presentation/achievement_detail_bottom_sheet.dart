import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:zerotrust_fitness/features/achievements/domain/achievement_definition.dart';
import 'package:zerotrust_fitness/features/achievements/presentation/medal_card.dart';

void showAchievementDetail(
  BuildContext context,
  AchievementDefinition definition,
  bool isEarned,
  DateTime? unlockedAt,
) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _AchievementDetailSheet(
      definition: definition,
      isEarned: isEarned,
      unlockedAt: unlockedAt,
    ),
  );
}

class _AchievementDetailSheet extends StatelessWidget {
  const _AchievementDetailSheet({
    required this.definition,
    required this.isEarned,
    this.unlockedAt,
  });

  final AchievementDefinition definition;
  final bool isEarned;
  final DateTime? unlockedAt;

  String _categoryLabel(AchievementCategory category) {
    return switch (category) {
      AchievementCategory.fitness => 'Fitness',
      AchievementCategory.sleep => 'Sleep',
      AchievementCategory.health => 'Health',
      AchievementCategory.milestones => 'Milestones',
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface.withValues(alpha: 0.92),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        padding: EdgeInsets.fromLTRB(
          24,
          24,
          24,
          24 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: isEarned
                    ? LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: definition.gradientColors,
                      )
                    : null,
                color: isEarned ? null : Colors.grey[800],
                boxShadow: isEarned
                    ? [
                        BoxShadow(
                          color: definition.gradientColors.first
                              .withValues(alpha: 0.45),
                          blurRadius: 24,
                          offset: const Offset(0, 6),
                        ),
                      ]
                    : null,
              ),
              child: Icon(
                definition.icon,
                color: isEarned ? Colors.white : Colors.grey[600],
                size: 44,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              definition.name,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: isEarned
                    ? definition.gradientColors.first.withValues(alpha: 0.2)
                    : Colors.grey[800],
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _categoryLabel(definition.category),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: isEarned
                      ? definition.gradientColors.first
                      : Colors.grey[400],
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              definition.description,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.hintColor,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isEarned
                    ? const Color(0xFF22C55E).withValues(alpha: 0.12)
                    : Colors.grey[800]!.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isEarned
                      ? const Color(0xFF22C55E).withValues(alpha: 0.3)
                      : Colors.white.withValues(alpha: 0.06),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isEarned ? Icons.emoji_events : Icons.lock_outline,
                    size: 18,
                    color: isEarned
                        ? const Color(0xFF22C55E)
                        : Colors.grey[500],
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isEarned && unlockedAt != null
                        ? 'Unlocked on ${formatMedalDate(unlockedAt!.toLocal())}'
                        : isEarned
                            ? 'Unlocked'
                            : 'Keep going!',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isEarned
                          ? const Color(0xFF22C55E)
                          : Colors.grey[400],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
