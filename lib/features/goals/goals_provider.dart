import 'package:cryptography/cryptography.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zerotrust_fitness/core/storage/local_vault.dart';
import 'package:zerotrust_fitness/features/app/providers.dart';

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
    final secretKey = ref.watch(securityEnclaveProvider);
    if (secretKey == null) return const GoalsState(goals: {});
    return _fetch(secretKey);
  }

  Future<GoalsState> _fetch(SecretKey secretKey) async {
    final rows = await LocalVault().fetchGoals(secretKey);
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
    final secretKey = ref.read(securityEnclaveProvider);
    if (secretKey == null) return;
    await LocalVault().upsertGoal(
      metricKey: metricKey,
      targetValue: targetValue,
      period: period,
      secretKey: secretKey,
    );
    state = AsyncData(await _fetch(secretKey));
  }

  Future<void> delete(String metricKey) async {
    final secretKey = ref.read(securityEnclaveProvider);
    if (secretKey == null) return;
    await LocalVault().deleteGoal(metricKey, secretKey);
    state = AsyncData(await _fetch(secretKey));
  }
}

final goalsProvider =
    AsyncNotifierProvider<GoalsNotifier, GoalsState>(GoalsNotifier.new);
