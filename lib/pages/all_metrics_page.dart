import 'package:cryptography/cryptography.dart';
import 'package:flutter/material.dart';
import 'package:zerotrust_fitness/components/compact_metric_card.dart';
import 'package:zerotrust_fitness/features/dashboard/metric_card_specs.dart';
import 'package:zerotrust_fitness/pages/metric_detail_page.dart';

class AllMetricsPage extends StatelessWidget {
  const AllMetricsPage({
    super.key,
    required this.todayMetrics,
    required this.onManualEntry,
    this.secretKey,
  });

  final Map<String, num> todayMetrics;
  final VoidCallback onManualEntry;
  final SecretKey? secretKey;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('All Metrics')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Wrap(
          spacing: 10,
          runSpacing: 10,
          children: metricCardSpecs.map((spec) {
            final rawValue = todayMetrics[spec.key] ?? 0;
            final sk = secretKey;
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
                            builder: (_) => MetricDetailPage(
                              metricKey: spec.key,
                              metricTitle: spec.title,
                              unit: spec.unit,
                              gradientColors: spec.gradientColors,
                              secretKey: sk,
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
        tooltip: 'Log a workout or health metric',
        child: const Icon(Icons.add),
      ),
    );
  }
}
