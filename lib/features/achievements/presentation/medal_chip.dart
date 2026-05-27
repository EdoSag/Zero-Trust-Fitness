import 'package:flutter/material.dart';
import 'package:zerotrust_fitness/features/achievements/domain/achievement_definition.dart';

class MedalChip extends StatelessWidget {
  const MedalChip({
    super.key,
    required this.definition,
    this.size = 64,
  });

  final AchievementDefinition definition;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: definition.gradientColors,
        ),
        boxShadow: [
          BoxShadow(
            color: definition.gradientColors.first.withValues(alpha: 0.4),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Icon(
        definition.icon,
        color: Colors.white,
        size: size * 0.44,
      ),
    );
  }
}
