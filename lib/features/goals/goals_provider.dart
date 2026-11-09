import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zerotrust_fitness/core/storage/fitness_vault.dart';
import 'package:zerotrust_fitness/app/vault_providers.dart';

/// A goal stored by the user. [period] is either 'daily' or 'weekly'.
class UserGoal {
  const UserGoal({
    required this.metricKey,
    required this.targetValue,
    required this.period,
  });

  final String metricKey;
  final num targetValue;
  final String period;
}

/// Holds the user's goals. Keyed by metric_key for O(1) lookup.
class GoalsState {
  const GoalsState({required this.goals});

  final Map<String, UserGoal> goals;

  UserGoal? forKey(String metricKey) => goals[metricKey];

  bool hasGoal(String metricKey) => goals.containsKey(metricKey);

  /// 0.0–1.0 progress fraction for a metric, or null if no goal exists.
  double? progressFor(String metricKey, num currentValue) {
    final goal = goals[metricKey];
    if (goal == null || goal.targetValue <= 0) return null;
    return (currentValue / goal.targetValue).clamp(0.0, 1.0).toDouble();
  }
}

class GoalsNotifier extends AsyncNotifier<GoalsState> {
  @override
  Future<GoalsState> build() async {
    final vault = ref.watch(openFitnessVaultProvider);
    if (vault == null) return const GoalsState(goals: {});
    // Goals changed on another device, or by a restore, show up too.
    ref.listen(fitnessVaultChangesProvider, (_, next) async {
      if (next is! AsyncData) return;
      final goals = await _fetch(vault);
      if (ref.mounted) state = AsyncData(goals);
    });
    return _fetch(vault);
  }

  Future<GoalsState> _fetch(FitnessVault vault) async {
    final rows = await vault.fetchGoals();
    final map = <String, UserGoal>{};
    for (final row in rows) {
      final key = row['metric_key']?.toString();
      final target = row['target_value'];
      final period = row['period']?.toString() ?? 'daily';
      if (key == null || key.isEmpty || target is! num) continue;
      map[key] = UserGoal(
        metricKey: key,
        targetValue: target,
        period: period,
      );
    }
    return GoalsState(goals: map);
  }

  Future<void> upsert(String metricKey, num targetValue, String period) async {
    final vault = ref.read(openFitnessVaultProvider);
    if (vault == null) return;
    await vault.upsertGoal(
      metricKey: metricKey,
      targetValue: targetValue,
      period: period
    );
    state = AsyncData(await _fetch(vault));
  }

  Future<void> delete(String metricKey) async {
    final vault = ref.read(openFitnessVaultProvider);
    if (vault == null) return;
    await vault.deleteGoal(metricKey);
    state = AsyncData(await _fetch(vault));
  }
}

final goalsProvider =
    AsyncNotifierProvider<GoalsNotifier, GoalsState>(GoalsNotifier.new);
