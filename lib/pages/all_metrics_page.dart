import 'package:flutter/material.dart';
import 'package:zerotrust_fitness/core/storage/fitness_vault.dart';
import 'package:zerotrust_fitness/components/compact_metric_card.dart';
import 'package:zerotrust_fitness/features/dashboard/metric_card_specs.dart';
import 'package:zerotrust_fitness/pages/metric_detail_page.dart';
import 'package:zerotrust_fitness/pages/water_food_page.dart';
import 'package:zerotrust_fitness/l10n/l10n.dart';

class AllMetricsPage extends StatelessWidget {
  const AllMetricsPage({
    super.key,
    required this.todayMetrics,
    required this.onManualEntry,
    this.vault,
  });

  final Map<String, num> todayMetrics;
  final VoidCallback onManualEntry;
  final FitnessVault? vault;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.allMetrics)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Wrap(
          spacing: 10,
          runSpacing: 10,
          children: metricCardSpecs.map((spec) {
            final rawValue = todayMetrics[spec.key] ?? 0;
            final sk = vault;
            return SizedBox(
              width: (MediaQuery.of(context).size.width - 60) / 2,
              child: CompactMetricCard(
                title: spec.title,
                value: formatMetricValue(spec.key, rawValue, spec.unit),
                icon: spec.icon,
                gradientColors: spec.gradientColors,
                onTap: sk == null
                    ? null
                    : () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => spec.key == 'water_l' ||
                                    spec.key == 'nutrition_entries'
                                ? WaterFoodPage(
                                    initialTab:
                                        spec.key == 'water_l' ? 0 : 1)
                                : MetricDetailPage(
                              metricKey: spec.key,
                              metricTitle: spec.title,
                              unit: spec.unit,
                              gradientColors: spec.gradientColors,
                              vault: sk,
                            ),
                          ),
                        ),
              ),
            );
          }).toList(growable: false),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: onManualEntry,
        tooltip: context.l10n.logAWorkoutOrHealth,
        child: const Icon(Icons.add),
      ),
    );
  }
}
