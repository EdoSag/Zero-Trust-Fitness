import 'package:flutter/material.dart';
import 'package:zerotrust_fitness/features/achievements/domain/achievement_definition.dart';

String formatMedalDate(DateTime dt) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
}

class MedalCard extends StatelessWidget {
  const MedalCard({
    super.key,
    required this.definition,
    required this.isEarned,
    this.unlockedAt,
    required this.onTap,
  });

  final AchievementDefinition definition;
  final bool isEarned;
  final DateTime? unlockedAt;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isEarned
                ? definition.gradientColors.first.withValues(alpha: 0.3)
                : Colors.white.withValues(alpha: 0.06),
          ),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 64,
                  height: 64,
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
                                  .withValues(alpha: 0.35),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ]
                        : null,
                  ),
                  child: Icon(
                    definition.icon,
                    color: isEarned ? Colors.white : Colors.grey[600],
                    size: 28,
                  ),
                ),
                if (!isEarned)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: Colors.grey[700],
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: theme.colorScheme.surface,
                          width: 1.5,
                        ),
                      ),
                      child: Icon(
                        Icons.lock,
                        color: Colors.grey[500],
                        size: 11,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              definition.name,
              style: theme.textTheme.bodySmall?.copyWith(
                color: isEarned ? Colors.white : Colors.grey[500],
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (isEarned && unlockedAt != null) ...[
              const SizedBox(height: 4),
              Text(
                formatMedalDate(unlockedAt!.toLocal()),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: Colors.grey[400],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
