import 'package:flutter/material.dart';

enum AchievementCategory { fitness, sleep, health, milestones }

/// Describes what value to track for progress toward an achievement.
enum AchievementProgressType {
  none,
  bestDailySteps,
  bestDailyHeartPoints,
  bestDailySleepAsleepMin,
  bestDailySleepDeepMin,
  bestDailyWaterL,
  totalSteps,
  totalHeartPoints,
  totalDays,
  activeWeekHeartPoints,
}

class AchievementDefinition {
  const AchievementDefinition({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.gradientColors,
    required this.category,
    this.progressType = AchievementProgressType.none,
    this.progressTarget = 1,
  });

  final String id;
  final String name;
  final String description;
  final IconData icon;
  final List<Color> gradientColors;
  final AchievementCategory category;
  final AchievementProgressType progressType;
  final num progressTarget;
}

/// Computes a 0.0–1.0 progress fraction for [def] using [allMetrics].
/// Returns 1.0 if the achievement is already unlocked (caller responsibility).
double computeAchievementProgress(
  AchievementDefinition def,
  List<Map<String, dynamic>> allMetrics,
) {
  if (def.progressType == AchievementProgressType.none) return 0;
  if (def.progressTarget <= 0) return 0;

  num m(Map<String, dynamic> row, String key) {
    final metrics = row['metrics'];
    if (metrics is Map) {
      final v = metrics[key];
      if (v is num) return v;
      if (v is String) return num.tryParse(v) ?? 0;
    }
    return 0;
  }

  switch (def.progressType) {
    case AchievementProgressType.bestDailySteps:
      final best = allMetrics.fold<num>(
          0, (best, r) => m(r, 'steps') > best ? m(r, 'steps') : best);
      return (best / def.progressTarget).clamp(0.0, 1.0).toDouble();

    case AchievementProgressType.bestDailyHeartPoints:
      final best = allMetrics.fold<num>(0,
          (best, r) => m(r, 'heart_points') > best ? m(r, 'heart_points') : best);
      return (best / def.progressTarget).clamp(0.0, 1.0).toDouble();

    case AchievementProgressType.bestDailySleepAsleepMin:
      final best = allMetrics.fold<num>(0,
          (best, r) => m(r, 'sleep_asleep_min') > best ? m(r, 'sleep_asleep_min') : best);
      return (best / def.progressTarget).clamp(0.0, 1.0).toDouble();

    case AchievementProgressType.bestDailySleepDeepMin:
      final best = allMetrics.fold<num>(0,
          (best, r) => m(r, 'sleep_deep_min') > best ? m(r, 'sleep_deep_min') : best);
      return (best / def.progressTarget).clamp(0.0, 1.0).toDouble();

    case AchievementProgressType.bestDailyWaterL:
      final best = allMetrics.fold<num>(
          0, (best, r) => m(r, 'water_l') > best ? m(r, 'water_l') : best);
      return (best / def.progressTarget).clamp(0.0, 1.0).toDouble();

    case AchievementProgressType.totalSteps:
      final total =
          allMetrics.fold<num>(0, (s, r) => s + m(r, 'steps'));
      return (total / def.progressTarget).clamp(0.0, 1.0).toDouble();

    case AchievementProgressType.totalHeartPoints:
      final total =
          allMetrics.fold<num>(0, (s, r) => s + m(r, 'heart_points'));
      return (total / def.progressTarget).clamp(0.0, 1.0).toDouble();

    case AchievementProgressType.totalDays:
      return (allMetrics.length / def.progressTarget).clamp(0.0, 1.0).toDouble();

    case AchievementProgressType.activeWeekHeartPoints:
      if (allMetrics.length < 7) {
        final total =
            allMetrics.fold<num>(0, (s, r) => s + m(r, 'heart_points'));
        return (total / def.progressTarget).clamp(0.0, 1.0).toDouble();
      }
      final dated = <DateTime, num>{};
      for (final row in allMetrics) {
        final dateKey = row['date_key']?.toString();
        if (dateKey == null) continue;
        final date = DateTime.tryParse(dateKey);
        if (date == null) continue;
        dated[date] = m(row, 'heart_points');
      }
      final dates = dated.keys.toList()..sort();
      num best = 0;
      for (var i = 0; i <= dates.length - 7; i++) {
        var windowSum = 0.0;
        var valid = true;
        for (var j = 0; j < 7; j++) {
          if (j > 0 && dates[i + j].difference(dates[i + j - 1]).inDays > 1) {
            valid = false;
            break;
          }
          windowSum += (dated[dates[i + j]] ?? 0).toDouble();
        }
        if (valid && windowSum > best) best = windowSum;
      }
      return (best / def.progressTarget).clamp(0.0, 1.0).toDouble();

    case AchievementProgressType.none:
      return 0;
  }
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
    progressType: AchievementProgressType.bestDailySteps,
    progressTarget: 5000,
  ),
  AchievementDefinition(
    id: 'step_champion',
    name: 'Step Champion',
    description: 'Walk 10,000 steps in a single day.',
    icon: Icons.emoji_events,
    gradientColors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
    category: AchievementCategory.fitness,
    progressType: AchievementProgressType.bestDailySteps,
    progressTarget: 10000,
  ),
  AchievementDefinition(
    id: 'step_legend',
    name: 'Step Legend',
    description: 'Walk 20,000 steps in a single day.',
    icon: Icons.military_tech,
    gradientColors: [Color(0xFFF59E0B), Color(0xFFD97706)],
    category: AchievementCategory.fitness,
    progressType: AchievementProgressType.bestDailySteps,
    progressTarget: 20000,
  ),
  AchievementDefinition(
    id: 'heart_starter',
    name: 'Heart Starter',
    description: 'Earn 10 heart points in a single day.',
    icon: Icons.favorite,
    gradientColors: [Color(0xFFF43F5E), Color(0xFFFB7185)],
    category: AchievementCategory.fitness,
    progressType: AchievementProgressType.bestDailyHeartPoints,
    progressTarget: 10,
  ),
  AchievementDefinition(
    id: 'heart_warrior',
    name: 'Heart Warrior',
    description: 'Earn 25 heart points in a single day.',
    icon: Icons.favorite,
    gradientColors: [Color(0xFFF43F5E), Color(0xFFE11D48)],
    category: AchievementCategory.fitness,
    progressType: AchievementProgressType.bestDailyHeartPoints,
    progressTarget: 25,
  ),
  AchievementDefinition(
    id: 'heart_legend',
    name: 'Heart Legend',
    description: 'Earn 50 heart points in a single day.',
    icon: Icons.local_fire_department,
    gradientColors: [Color(0xFFDC2626), Color(0xFFB91C1C)],
    category: AchievementCategory.fitness,
    progressType: AchievementProgressType.bestDailyHeartPoints,
    progressTarget: 50,
  ),
  AchievementDefinition(
    id: 'active_week',
    name: 'Active Week',
    description: 'Earn 150 heart points across any 7-day period.',
    icon: Icons.bolt,
    gradientColors: [Color(0xFFF97316), Color(0xFFEA580C)],
    category: AchievementCategory.fitness,
    progressType: AchievementProgressType.activeWeekHeartPoints,
    progressTarget: 150,
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
    progressType: AchievementProgressType.bestDailySleepAsleepMin,
    progressTarget: 420,
  ),
  AchievementDefinition(
    id: 'deep_dreamer',
    name: 'Deep Dreamer',
    description: 'Get 1+ hour of deep sleep in a single night.',
    icon: Icons.hotel_outlined,
    gradientColors: [Color(0xFF1D4ED8), Color(0xFF1E40AF)],
    category: AchievementCategory.sleep,
    progressType: AchievementProgressType.bestDailySleepDeepMin,
    progressTarget: 60,
  ),
  AchievementDefinition(
    id: 'sleep_champion',
    name: 'Sleep Champion',
    description: 'Get 8+ hours of sleep in a single night.',
    icon: Icons.star,
    gradientColors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
    category: AchievementCategory.sleep,
    progressType: AchievementProgressType.bestDailySleepAsleepMin,
    progressTarget: 480,
  ),
  // Health
  AchievementDefinition(
    id: 'hydrated',
    name: 'Hydrated',
    description: 'Log 2+ litres of water in a single day.',
    icon: Icons.water_drop_outlined,
    gradientColors: [Color(0xFF0EA5E9), Color(0xFF2563EB)],
    category: AchievementCategory.health,
    progressType: AchievementProgressType.bestDailyWaterL,
    progressTarget: 2.0,
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
    progressType: AchievementProgressType.totalDays,
    progressTarget: 7,
  ),
  AchievementDefinition(
    id: 'committed',
    name: 'Committed',
    description: 'Sync data on 30 different days.',
    icon: Icons.workspace_premium,
    gradientColors: [Color(0xFFF59E0B), Color(0xFFD97706)],
    category: AchievementCategory.milestones,
    progressType: AchievementProgressType.totalDays,
    progressTarget: 30,
  ),
  AchievementDefinition(
    id: 'step_millionaire',
    name: 'Step Millionaire',
    description: 'Walk a total of 1,000,000 steps.',
    icon: Icons.military_tech,
    gradientColors: [Color(0xFFF59E0B), Color(0xFFD97706)],
    category: AchievementCategory.milestones,
    progressType: AchievementProgressType.totalSteps,
    progressTarget: 1000000,
  ),
  AchievementDefinition(
    id: 'elite',
    name: 'Elite',
    description: 'Earn a total of 1,000 heart points.',
    icon: Icons.diamond,
    gradientColors: [Color(0xFF06B6D4), Color(0xFF8B5CF6)],
    category: AchievementCategory.milestones,
    progressType: AchievementProgressType.totalHeartPoints,
    progressTarget: 1000,
  ),
];
