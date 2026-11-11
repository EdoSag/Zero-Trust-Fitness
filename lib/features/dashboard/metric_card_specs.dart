import 'package:flutter/material.dart';
import 'package:zerotrust_fitness/l10n/l10n.dart';

class MetricCardSpec {
  MetricCardSpec({
    required this.key,
    required this.title,
    required this.unit,
    required this.icon,
    required this.gradientColors,
  });

  final String key;
  final String title;
  final String unit;
  final IconData icon;
  final List<Color> gradientColors;
}

List<MetricCardSpec> get metricCardSpecs => <MetricCardSpec>[
  MetricCardSpec(
    key: 'steps',
    title: currentL10n.steps,
    unit: '',
    icon: Icons.directions_walk,
    gradientColors: [Color(0xFF3B82F6), Color(0xFF6366F1)],
  ),
  MetricCardSpec(
    key: 'heart_points',
    title: currentL10n.heartPoints,
    unit: '',
    icon: Icons.favorite,
    gradientColors: [Color(0xFFF43F5E), Color(0xFFFB7185)],
  ),
  MetricCardSpec(
    key: 'sleep_asleep_min',
    title: currentL10n.sleepAsleep,
    unit: 'min',
    icon: Icons.nights_stay_outlined,
    gradientColors: [Color(0xFF0EA5E9), Color(0xFF0284C7)],
  ),
  MetricCardSpec(
    key: 'sleep_light_min',
    title: currentL10n.sleepLight,
    unit: 'min',
    icon: Icons.bedtime_outlined,
    gradientColors: [Color(0xFF38BDF8), Color(0xFF0EA5E9)],
  ),
  MetricCardSpec(
    key: 'sleep_deep_min',
    title: currentL10n.sleepDeep,
    unit: 'min',
    icon: Icons.hotel_outlined,
    gradientColors: [Color(0xFF1D4ED8), Color(0xFF1E40AF)],
  ),
  MetricCardSpec(
    key: 'sleep_rem_min',
    title: currentL10n.sleepRem,
    unit: 'min',
    icon: Icons.bed_outlined,
    gradientColors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
  ),
  MetricCardSpec(
    key: 'resting_hr_bpm_avg',
    title: currentL10n.restingHr,
    unit: 'bpm',
    icon: Icons.monitor_heart_outlined,
    gradientColors: [Color(0xFFEC4899), Color(0xFFDB2777)],
  ),
  MetricCardSpec(
    key: 'respiratory_rate_avg',
    title: currentL10n.respiratory,
    unit: 'rpm',
    icon: Icons.air_outlined,
    gradientColors: [Color(0xFF14B8A6), Color(0xFF0F766E)],
  ),
  MetricCardSpec(
    key: 'blood_oxygen_pct_avg',
    title: currentL10n.bloodOxygen,
    unit: '%',
    icon: Icons.bloodtype_outlined,
    gradientColors: [Color(0xFF06B6D4), Color(0xFF0E7490)],
  ),
  MetricCardSpec(
    key: 'weight_kg',
    title: currentL10n.weight,
    unit: 'kg',
    icon: Icons.monitor_weight_outlined,
    gradientColors: [Color(0xFF84CC16), Color(0xFF65A30D)],
  ),
  MetricCardSpec(
    key: 'bmi',
    title: 'BMI',
    unit: '',
    icon: Icons.straighten_outlined,
    gradientColors: [Color(0xFFF59E0B), Color(0xFFD97706)],
  ),
  MetricCardSpec(
    key: 'body_fat_pct',
    title: currentL10n.bodyFat,
    unit: '%',
    icon: Icons.accessibility_new_outlined,
    gradientColors: [Color(0xFFF97316), Color(0xFFEA580C)],
  ),
  MetricCardSpec(
    key: 'water_l',
    title: currentL10n.hydration,
    unit: 'L',
    icon: Icons.water_drop_outlined,
    gradientColors: [Color(0xFF0EA5E9), Color(0xFF2563EB)],
  ),
  MetricCardSpec(
    key: 'nutrition_entries',
    title: currentL10n.nutrition,
    unit: 'entries',
    icon: Icons.restaurant_menu_outlined,
    gradientColors: [Color(0xFF22C55E), Color(0xFF16A34A)],
  ),
  MetricCardSpec(
    key: 'blood_pressure_systolic_mmhg',
    title: currentL10n.bpSystolic,
    unit: 'mmHg',
    icon: Icons.monitor_heart,
    gradientColors: [Color(0xFFE11D48), Color(0xFFBE123C)],
  ),
  MetricCardSpec(
    key: 'blood_pressure_diastolic_mmhg',
    title: currentL10n.bpDiastolic,
    unit: 'mmHg',
    icon: Icons.favorite_border,
    gradientColors: [Color(0xFFF43F5E), Color(0xFFE11D48)],
  ),
  MetricCardSpec(
    key: 'blood_glucose_mg_dl',
    title: currentL10n.glucose,
    unit: 'mg/dL',
    icon: Icons.science_outlined,
    gradientColors: [Color(0xFFA855F7), Color(0xFF7E22CE)],
  ),
];

/// Keys shown on the Today tab as priority metrics.
const priorityMetricKeys = <String>[
  'sleep_asleep_min',
  'resting_hr_bpm_avg',
  'weight_kg',
  'blood_oxygen_pct_avg',
];

String formatMetricValue(String key, num value, String unit) {
  String text;
  if (key == 'nutrition_entries' || key == 'steps' || key == 'heart_points') {
    text = value.toInt().toString();
  } else if (key == 'blood_pressure_systolic_mmhg' ||
      key == 'blood_pressure_diastolic_mmhg') {
    text = value.toInt().toString();
  } else if (key == 'weight_kg' || key == 'bmi') {
    text = value.toStringAsFixed(1);
  } else if (key.endsWith('_pct') || key.contains('oxygen')) {
    text = value.toStringAsFixed(1);
  } else if (key == 'water_l') {
    text = value.toStringAsFixed(2);
  } else {
    text = value.toStringAsFixed(1);
  }
  if (unit.isEmpty) return text;
  return '$text $unit';
}

class DualMetricPoint {
  const DualMetricPoint({
    required this.label,
    required this.steps,
    required this.heartPoints,
  });

  final String label;
  final double steps;
  final double heartPoints;
}

class SingleMetricPoint {
  const SingleMetricPoint({
    required this.label,
    required this.value,
  });

  final String label;
  final double value;
}
