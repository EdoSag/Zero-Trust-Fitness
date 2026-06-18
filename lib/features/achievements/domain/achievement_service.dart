import 'package:cryptography/cryptography.dart';
import 'package:zerotrust_fitness/core/storage/local_vault.dart';
import 'package:zerotrust_fitness/features/achievements/domain/achievement_definition.dart';

class UnlockedAchievement {
  const UnlockedAchievement({
    required this.definition,
    required this.unlockedAt,
  });

  final AchievementDefinition definition;
  final DateTime unlockedAt;
}

class AchievementService {
  AchievementService._();

  factory AchievementService() => _instance;

  static final AchievementService _instance = AchievementService._();

  Future<Set<String>> fetchUnlockedIds(SecretKey secretKey) async {
    final rows = await LocalVault().fetchAchievements(secretKey);
    return rows.map((r) => r['id']?.toString() ?? '').toSet();
  }

  Future<List<UnlockedAchievement>> fetchUnlocked(SecretKey secretKey) async {
    final rows = await LocalVault().fetchAchievements(secretKey);
    final result = <UnlockedAchievement>[];
    for (final row in rows) {
      final id = row['id']?.toString();
      final tsRaw = row['unlocked_at']?.toString();
      if (id == null || tsRaw == null) continue;
      final definition =
          kAllAchievements.where((d) => d.id == id).firstOrNull;
      if (definition == null) continue;
      final unlockedAt = DateTime.tryParse(tsRaw) ?? DateTime.now().toUtc();
      result.add(UnlockedAchievement(definition: definition, unlockedAt: unlockedAt));
    }
    result.sort((a, b) => b.unlockedAt.compareTo(a.unlockedAt));
    return result;
  }

  Future<List<String>> checkAndUnlockAchievements(SecretKey secretKey) async {
    final already = await fetchUnlockedIds(secretKey);
    final allMetrics = await LocalVault().fetchDailyMetrics(secretKey);
    final nowUnlocked = <String>[];

    Future<void> unlock(String id) async {
      await LocalVault().insertAchievementIfAbsent(
        id,
        DateTime.now().toUtc(),
        secretKey,
      );
      nowUnlocked.add(id);
    }

    num m(Map<String, dynamic> row, String key) {
      final metrics = row['metrics'];
      if (metrics is Map) {
        final v = metrics[key];
        if (v is num) return v;
        if (v is String) return num.tryParse(v) ?? 0;
      }
      return 0;
    }

    // Fitness
    if (!already.contains('first_steps') &&
        allMetrics.any((r) => m(r, 'steps') > 0)) {
      await unlock('first_steps');
    }
    if (!already.contains('step_seeker') &&
        allMetrics.any((r) => m(r, 'steps') >= 5000)) {
      await unlock('step_seeker');
    }
    if (!already.contains('step_champion') &&
        allMetrics.any((r) => m(r, 'steps') >= 10000)) {
      await unlock('step_champion');
    }
    if (!already.contains('step_legend') &&
        allMetrics.any((r) => m(r, 'steps') >= 20000)) {
      await unlock('step_legend');
    }
    if (!already.contains('heart_starter') &&
        allMetrics.any((r) => m(r, 'heart_points') >= 10)) {
      await unlock('heart_starter');
    }
    if (!already.contains('heart_warrior') &&
        allMetrics.any((r) => m(r, 'heart_points') >= 25)) {
      await unlock('heart_warrior');
    }
    if (!already.contains('heart_legend') &&
        allMetrics.any((r) => m(r, 'heart_points') >= 50)) {
      await unlock('heart_legend');
    }
    if (!already.contains('active_week') && _hasActiveWeek(allMetrics, m)) {
      await unlock('active_week');
    }

    // Sleep
    if (!already.contains('night_logged') &&
        allMetrics.any((r) => m(r, 'sleep_asleep_min') > 0)) {
      await unlock('night_logged');
    }
    if (!already.contains('well_rested') &&
        allMetrics.any((r) => m(r, 'sleep_asleep_min') >= 420)) {
      await unlock('well_rested');
    }
    if (!already.contains('deep_dreamer') &&
        allMetrics.any((r) => m(r, 'sleep_deep_min') >= 60)) {
      await unlock('deep_dreamer');
    }
    if (!already.contains('sleep_champion') &&
        allMetrics.any((r) => m(r, 'sleep_asleep_min') >= 480)) {
      await unlock('sleep_champion');
    }

    // Health
    if (!already.contains('hydrated') &&
        allMetrics.any((r) => m(r, 'water_l') >= 2.0)) {
      await unlock('hydrated');
    }
    if (!already.contains('healthy_heart')) {
      final hasLowHr = allMetrics.any((r) {
        final hr = m(r, 'resting_hr_bpm_avg');
        return hr > 0 && hr <= 60;
      });
      if (hasLowHr) await unlock('healthy_heart');
    }
    if (!already.contains('oxygen_check') &&
        allMetrics.any((r) => m(r, 'blood_oxygen_pct_avg') > 0)) {
      await unlock('oxygen_check');
    }

    // Milestones
    if (!already.contains('first_sync') && allMetrics.isNotEmpty) {
      await unlock('first_sync');
    }
    if (!already.contains('dedicated') && allMetrics.length >= 7) {
      await unlock('dedicated');
    }
    if (!already.contains('committed') && allMetrics.length >= 30) {
      await unlock('committed');
    }
    if (!already.contains('step_millionaire')) {
      final total =
          allMetrics.fold<int>(0, (s, r) => s + m(r, 'steps').toInt());
      if (total >= 1000000) await unlock('step_millionaire');
    }
    if (!already.contains('elite')) {
      final total =
          allMetrics.fold<int>(0, (s, r) => s + m(r, 'heart_points').toInt());
      if (total >= 1000) await unlock('elite');
    }

    // Streak achievements
    final streak = _longestConsecutiveDays(allMetrics);
    if (!already.contains('streak_3') && streak >= 3) await unlock('streak_3');
    if (!already.contains('streak_7') && streak >= 7) await unlock('streak_7');
    if (!already.contains('streak_30') && streak >= 30) await unlock('streak_30');

    return nowUnlocked;
  }

  int _longestConsecutiveDays(List<Map<String, dynamic>> allMetrics) {
    final dates = allMetrics
        .map((r) => r['date_key']?.toString())
        .whereType<String>()
        .map((d) => DateTime.tryParse(d))
        .whereType<DateTime>()
        .toSet()
        .toList()
      ..sort();
    if (dates.isEmpty) return 0;
    int longest = 1, run = 1;
    for (int i = 1; i < dates.length; i++) {
      if (dates[i].difference(dates[i - 1]).inDays == 1) {
        run++;
        if (run > longest) longest = run;
      } else {
        run = 1;
      }
    }
    return longest;
  }

  bool _hasActiveWeek(
    List<Map<String, dynamic>> allMetrics,
    num Function(Map<String, dynamic>, String) m,
  ) {
    if (allMetrics.length < 7) return false;

    final dated = <DateTime, int>{};
    for (final row in allMetrics) {
      final dateKey = row['date_key']?.toString();
      if (dateKey == null) continue;
      final date = DateTime.tryParse(dateKey);
      if (date == null) continue;
      dated[date] = m(row, 'heart_points').toInt();
    }

    final dates = dated.keys.toList()..sort();
    for (var i = 0; i <= dates.length - 7; i++) {
      var windowSum = 0;
      var valid = true;
      for (var j = 0; j < 7; j++) {
        if (j > 0 &&
            dates[i + j].difference(dates[i + j - 1]).inDays > 1) {
          valid = false;
          break;
        }
        windowSum += dated[dates[i + j]] ?? 0;
      }
      if (valid && windowSum >= 150) return true;
    }
    return false;
  }
}
