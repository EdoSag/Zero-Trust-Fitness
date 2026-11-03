import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zerotrust_fitness/features/dashboard/metric_card_specs.dart';
import 'package:zerotrust_fitness/features/goals/goals_provider.dart';

class GoalsPage extends ConsumerStatefulWidget {
  const GoalsPage({super.key});

  @override
  ConsumerState<GoalsPage> createState() => _GoalsPageState();
}

class _GoalsPageState extends ConsumerState<GoalsPage> {
  // metricKey → controller (lazy-populated)
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, String> _periods = {};

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _controllerFor(String key, GoalsState state) {
    return _controllers.putIfAbsent(key, () {
      final goal = state.forKey(key);
      return TextEditingController(
        text: goal == null ? '' : '${goal.targetValue}',
      );
    });
  }

  String _periodFor(String key, GoalsState state) {
    return _periods.putIfAbsent(
      key,
      () => state.forKey(key)?.period ?? 'daily',
    );
  }

  Future<void> _save(String metricKey) async {
    final raw = _controllers[metricKey]?.text.trim() ?? '';
    final value = num.tryParse(raw);
    if (value == null || value <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid target value.')),
      );
      return;
    }
    final period = _periods[metricKey] ?? 'daily';
    await ref.read(goalsProvider.notifier).upsert(metricKey, value, period);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Goal saved for $metricKey')),
      );
    }
  }

  Future<void> _delete(String metricKey) async {
    await ref.read(goalsProvider.notifier).delete(metricKey);
    _controllers[metricKey]?.clear();
    setState(() => _periods.remove(metricKey));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final goalsAsync = ref.watch(goalsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Goals')),
      body: goalsAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        error: (e, _) => Center(child: Text('Failed to load goals: $e')),
        data: (state) => ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          itemCount: metricCardSpecs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final spec = metricCardSpecs[index];
            final controller = _controllerFor(spec.key, state);
            final period = _periodFor(spec.key, state);
            final hasGoal = state.hasGoal(spec.key);

            return Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(spec.icon,
                            color: spec.gradientColors.first, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            spec.title,
                            style: theme.textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        if (hasGoal)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: const Text(
                              'Active',
                              style: TextStyle(
                                  color: Colors.green,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: controller,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            decoration: InputDecoration(
                              labelText:
                                  'Target${spec.unit.isNotEmpty ? ' (${spec.unit})' : ''}',
                              isDense: true,
                              border: const OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Period',
                              isDense: true,
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: period,
                                isExpanded: true,
                                isDense: true,
                                items: const [
                                  DropdownMenuItem(
                                      value: 'daily', child: Text('Daily')),
                                  DropdownMenuItem(
                                      value: 'weekly', child: Text('Weekly')),
                                ],
                                onChanged: (v) {
                                  if (v == null) return;
                                  setState(() => _periods[spec.key] = v);
                                },
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (hasGoal)
                          TextButton(
                            onPressed: () => _delete(spec.key),
                            child: const Text('Remove',
                                style: TextStyle(color: Colors.redAccent)),
                          ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: () => _save(spec.key),
                          child: const Text('Save'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
