import 'package:flutter/material.dart';

enum AchievementCategory { fitness, momentum, sleep, health, milestones }

class AchievementDefinition {
  const AchievementDefinition({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.gradientColors,
    required this.category,
  });

  final String id;
  final String name;
  final String description;
  final IconData icon;
  final List<Color> gradientColors;
  final AchievementCategory category;
}

const kAllAchievements = <AchievementDefinition>[
  // Fitness
  AchievementDefinition(
    id: 'first_steps',
    name: 'First Steps',
    description: 'Log your first steps data.',
    icon: Icons.directions_walk,
    gradientColors: [Color(0xFF3B82F6), Color(0xFF6366F1)],
    category: AchievementCategory.fitness,
  ),
  AchievementDefinition(
    id: 'step_seeker',
    name: 'Step Seeker',
    description: 'Walk 5,000 steps in a single day.',
    icon: Icons.directions_walk,
    gradientColors: [Color(0xFF3B82F6), Color(0xFF6366F1)],
    category: AchievementCategory.fitness,
  ),
  AchievementDefinition(
    id: 'step_champion',
    name: 'Step Champion',
    description: 'Walk 10,000 steps in a single day.',
    icon: Icons.emoji_events,
    gradientColors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
    category: AchievementCategory.fitness,
  ),
  AchievementDefinition(
    id: 'step_legend',
    name: 'Step Legend',
    description: 'Walk 20,000 steps in a single day.',
    icon: Icons.military_tech,
    gradientColors: [Color(0xFFF59E0B), Color(0xFFD97706)],
    category: AchievementCategory.fitness,
  ),
  AchievementDefinition(
    id: 'heart_starter',
    name: 'Heart Starter',
    description: 'Earn 10 heart points in a single day.',
    icon: Icons.favorite,
    gradientColors: [Color(0xFFF43F5E), Color(0xFFFB7185)],
    category: AchievementCategory.fitness,
  ),
  AchievementDefinition(
    id: 'heart_warrior',
    name: 'Heart Warrior',
    description: 'Earn 25 heart points in a single day.',
    icon: Icons.favorite,
    gradientColors: [Color(0xFFF43F5E), Color(0xFFE11D48)],
    category: AchievementCategory.fitness,
  ),
  AchievementDefinition(
    id: 'heart_legend',
    name: 'Heart Legend',
    description: 'Earn 50 heart points in a single day.',
    icon: Icons.local_fire_department,
    gradientColors: [Color(0xFFDC2626), Color(0xFFB91C1C)],
    category: AchievementCategory.fitness,
  ),
  AchievementDefinition(
    id: 'active_week',
    name: 'Active Week',
    description: 'Earn 150 heart points across any 7-day period.',
    icon: Icons.bolt,
    gradientColors: [Color(0xFFF97316), Color(0xFFEA580C)],
    category: AchievementCategory.fitness,
  ),
  // Momentum (rules in momentum_medals.dart)
  AchievementDefinition(
    id: 'on_target',
    name: 'On Target',
    description: 'Hit your daily Heart Points target for the first time.',
    icon: Icons.track_changes,
    gradientColors: [Color(0xFFF59E0B), Color(0xFFF97316)],
    category: AchievementCategory.momentum,
  ),
  AchievementDefinition(
    id: 'target_streak_3',
    name: 'Hat Trick',
    description: 'Hit your daily target 3 days in a row.',
    icon: Icons.looks_3,
    gradientColors: [Color(0xFFF59E0B), Color(0xFFEA580C)],
    category: AchievementCategory.momentum,
  ),
  AchievementDefinition(
    id: 'target_streak_7',
    name: 'Locked In',
    description: 'Hit your daily target 7 days in a row.',
    icon: Icons.lock_clock,
    gradientColors: [Color(0xFFEA580C), Color(0xFFC2410C)],
    category: AchievementCategory.momentum,
  ),
  AchievementDefinition(
    id: 'comeback',
    name: 'Comeback',
    description: 'Hit your target after 3 or more days without hitting it.',
    icon: Icons.replay,
    gradientColors: [Color(0xFF10B981), Color(0xFF059669)],
    category: AchievementCategory.momentum,
  ),
  AchievementDefinition(
    id: 'target_40',
    name: 'Raising the Bar',
    description: 'Grow your daily target to 40 Heart Points.',
    icon: Icons.trending_up,
    gradientColors: [Color(0xFF14B8A6), Color(0xFF0D9488)],
    category: AchievementCategory.momentum,
  ),
  AchievementDefinition(
    id: 'momentum_50',
    name: 'Steady',
    description: 'Reach a Momentum score of 50.',
    icon: Icons.bolt,
    gradientColors: [Color(0xFFFBBF24), Color(0xFFF59E0B)],
    category: AchievementCategory.momentum,
  ),
  AchievementDefinition(
    id: 'momentum_75',
    name: 'Unstoppable',
    description: 'Reach a Momentum score of 75.',
    icon: Icons.flash_on,
    gradientColors: [Color(0xFFF59E0B), Color(0xFFDC2626)],
    category: AchievementCategory.momentum,
  ),
  AchievementDefinition(
    id: 'momentum_week_75',
    name: 'Perpetual Motion',
    description: 'End 7 days in a row with Momentum of 75 or higher.',
    icon: Icons.all_inclusive,
    gradientColors: [Color(0xFFDC2626), Color(0xFF7C3AED)],
    category: AchievementCategory.momentum,
  ),
  // Sleep
  AchievementDefinition(
    id: 'night_logged',
    name: 'Night Logged',
    description: 'Log sleep data for the first time.',
    icon: Icons.nights_stay_outlined,
    gradientColors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
    category: AchievementCategory.sleep,
  ),
  AchievementDefinition(
    id: 'well_rested',
    name: 'Well Rested',
    description: 'Get 7+ hours of sleep in a single night.',
    icon: Icons.bedtime_outlined,
    gradientColors: [Color(0xFF7C3AED), Color(0xFF1D4ED8)],
    category: AchievementCategory.sleep,
  ),
  AchievementDefinition(
    id: 'deep_dreamer',
    name: 'Deep Dreamer',
    description: 'Get 1+ hour of deep sleep in a single night.',
    icon: Icons.hotel_outlined,
    gradientColors: [Color(0xFF1D4ED8), Color(0xFF1E40AF)],
    category: AchievementCategory.sleep,
  ),
  AchievementDefinition(
    id: 'sleep_champion',
    name: 'Sleep Champion',
    description: 'Get 8+ hours of sleep in a single night.',
    icon: Icons.star,
    gradientColors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
    category: AchievementCategory.sleep,
  ),
  // Health
  AchievementDefinition(
    id: 'hydrated',
    name: 'Hydrated',
    description: 'Log 2+ litres of water in a single day.',
    icon: Icons.water_drop_outlined,
    gradientColors: [Color(0xFF0EA5E9), Color(0xFF2563EB)],
    category: AchievementCategory.health,
  ),
  AchievementDefinition(
    id: 'healthy_heart',
    name: 'Healthy Heart',
    description: 'Record a resting heart rate of 60 bpm or lower.',
    icon: Icons.monitor_heart,
    gradientColors: [Color(0xFFEC4899), Color(0xFFDB2777)],
    category: AchievementCategory.health,
  ),
  AchievementDefinition(
    id: 'oxygen_check',
    name: 'Oxygen Check',
    description: 'Log blood oxygen (SpO2) data.',
    icon: Icons.bloodtype_outlined,
    gradientColors: [Color(0xFF06B6D4), Color(0xFF0E7490)],
    category: AchievementCategory.health,
  ),
  // Milestones
  AchievementDefinition(
    id: 'first_sync',
    name: 'First Sync',
    description: 'Sync your health data for the first time.',
    icon: Icons.sync,
    gradientColors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
    category: AchievementCategory.milestones,
  ),
  AchievementDefinition(
    id: 'dedicated',
    name: 'Dedicated',
    description: 'Sync data on 7 different days.',
    icon: Icons.calendar_today,
    gradientColors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
    category: AchievementCategory.milestones,
  ),
  AchievementDefinition(
    id: 'committed',
    name: 'Committed',
    description: 'Sync data on 30 different days.',
    icon: Icons.workspace_premium,
    gradientColors: [Color(0xFFF59E0B), Color(0xFFD97706)],
    category: AchievementCategory.milestones,
  ),
  AchievementDefinition(
    id: 'step_millionaire',
    name: 'Step Millionaire',
    description: 'Walk a total of 1,000,000 steps.',
    icon: Icons.military_tech,
    gradientColors: [Color(0xFFF59E0B), Color(0xFFD97706)],
    category: AchievementCategory.milestones,
  ),
  AchievementDefinition(
    id: 'elite',
    name: 'Elite',
    description: 'Earn a total of 1,000 heart points.',
    icon: Icons.diamond,
    gradientColors: [Color(0xFF06B6D4), Color(0xFF8B5CF6)],
    category: AchievementCategory.milestones,
  ),
];
