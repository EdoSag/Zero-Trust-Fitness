import 'dart:convert';
import 'dart:ui';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nowa_runtime/nowa_runtime.dart';
import 'package:zerotrust_fitness/core/security/encryption_service.dart';
import 'package:zerotrust_fitness/core/storage/local_vault.dart';
import 'package:zerotrust_fitness/features/achievements/domain/achievement_service.dart';
import 'package:zerotrust_fitness/heart_point_calculator.dart';

// Metric definitions mirrored from dashboard to drive the metrics tab UI.
class _MetricSpec {
  const _MetricSpec({
    required this.key,
    required this.title,
    required this.unit,
    required this.icon,
    required this.iconColor,
    required this.isAdditive,
  });

  final String key;
  final String title;
  final String unit;
  final IconData icon;
  final Color iconColor;
  final bool isAdditive;
}

const _activityTypes = <String>[
  'Running',
  'Cycling',
  'Swimming',
  'Walking',
  'Strength Training',
  'HIIT',
  'Yoga/Stretching',
  'Other',
];

IconData _iconForActivity(String type) {
  switch (type) {
    case 'Running':
      return Icons.directions_run;
    case 'Cycling':
      return Icons.directions_bike;
    case 'Swimming':
      return Icons.pool;
    case 'Walking':
      return Icons.directions_walk;
    case 'Strength Training':
      return Icons.fitness_center;
    case 'HIIT':
      return Icons.bolt;
    case 'Yoga/Stretching':
      return Icons.self_improvement;
    default:
      return Icons.sports_gymnastics;
  }
}

const _metricSections = <String, List<_MetricSpec>>{
  'Activity': [
    _MetricSpec(
      key: 'steps',
      title: 'Steps',
      unit: 'steps',
      icon: Icons.directions_walk,
      iconColor: Color(0xFF3B82F6),
      isAdditive: true,
    ),
    _MetricSpec(
      key: 'heart_points',
      title: 'Heart Points',
      unit: 'pts',
      icon: Icons.favorite,
      iconColor: Color(0xFFF43F5E),
      isAdditive: true,
    ),
  ],
  'Sleep': [
    _MetricSpec(
      key: 'sleep_asleep_min',
      title: 'Total Sleep',
      unit: 'min',
      icon: Icons.nights_stay_outlined,
      iconColor: Color(0xFF0EA5E9),
      isAdditive: true,
    ),
    _MetricSpec(
      key: 'sleep_light_min',
      title: 'Light Sleep',
      unit: 'min',
      icon: Icons.bedtime_outlined,
      iconColor: Color(0xFF38BDF8),
      isAdditive: true,
    ),
    _MetricSpec(
      key: 'sleep_deep_min',
      title: 'Deep Sleep',
      unit: 'min',
      icon: Icons.hotel_outlined,
      iconColor: Color(0xFF1D4ED8),
      isAdditive: true,
    ),
    _MetricSpec(
      key: 'sleep_rem_min',
      title: 'REM Sleep',
      unit: 'min',
      icon: Icons.bed_outlined,
      iconColor: Color(0xFF8B5CF6),
      isAdditive: true,
    ),
  ],
  'Vitals': [
    _MetricSpec(
      key: 'resting_hr_bpm_avg',
      title: 'Resting HR',
      unit: 'bpm',
      icon: Icons.monitor_heart_outlined,
      iconColor: Color(0xFFEC4899),
      isAdditive: false,
    ),
    _MetricSpec(
      key: 'respiratory_rate_avg',
      title: 'Respiratory Rate',
      unit: 'rpm',
      icon: Icons.air_outlined,
      iconColor: Color(0xFF14B8A6),
      isAdditive: false,
    ),
    _MetricSpec(
      key: 'blood_oxygen_pct_avg',
      title: 'Blood Oxygen',
      unit: '%',
      icon: Icons.bloodtype_outlined,
      iconColor: Color(0xFF06B6D4),
      isAdditive: false,
    ),
    _MetricSpec(
      key: 'blood_pressure_systolic_mmhg',
      title: 'BP Systolic',
      unit: 'mmHg',
      icon: Icons.monitor_heart,
      iconColor: Color(0xFFE11D48),
      isAdditive: false,
    ),
    _MetricSpec(
      key: 'blood_pressure_diastolic_mmhg',
      title: 'BP Diastolic',
      unit: 'mmHg',
      icon: Icons.favorite_border,
      iconColor: Color(0xFFF43F5E),
      isAdditive: false,
    ),
    _MetricSpec(
      key: 'blood_glucose_mg_dl',
      title: 'Blood Glucose',
      unit: 'mg/dL',
      icon: Icons.science_outlined,
      iconColor: Color(0xFFA855F7),
      isAdditive: false,
    ),
  ],
  'Body': [
    _MetricSpec(
      key: 'weight_kg',
      title: 'Weight',
      unit: 'kg',
      icon: Icons.monitor_weight_outlined,
      iconColor: Color(0xFF84CC16),
      isAdditive: false,
    ),
    _MetricSpec(
      key: 'bmi',
      title: 'BMI',
      unit: '',
      icon: Icons.straighten_outlined,
      iconColor: Color(0xFFF59E0B),
      isAdditive: false,
    ),
    _MetricSpec(
      key: 'body_fat_pct',
      title: 'Body Fat',
      unit: '%',
      icon: Icons.accessibility_new_outlined,
      iconColor: Color(0xFFF97316),
      isAdditive: false,
    ),
  ],
  'Lifestyle': [
    _MetricSpec(
      key: 'water_l',
      title: 'Hydration',
      unit: 'L',
      icon: Icons.water_drop_outlined,
      iconColor: Color(0xFF0EA5E9),
      isAdditive: true,
    ),
    _MetricSpec(
      key: 'nutrition_entries',
      title: 'Nutrition',
      unit: 'entries',
      icon: Icons.restaurant_menu_outlined,
      iconColor: Color(0xFF22C55E),
      isAdditive: true,
    ),
  ],
};

@NowaGenerated()
class ManualIngestionBottomSheet extends StatefulWidget {
  @NowaGenerated({'loader': 'auto-constructor'})
  const ManualIngestionBottomSheet({super.key, required this.secretKey});

  final SecretKey? secretKey;

  @override
  State<ManualIngestionBottomSheet> createState() {
    return _ManualIngestionBottomSheetState();
  }
}

@NowaGenerated()
class _ManualIngestionBottomSheetState
    extends State<ManualIngestionBottomSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  DateTime _selectedDateTime = DateTime.now();

  // Workout tab
  String _activityType = 'Running';
  final TextEditingController _durationController = TextEditingController();
  double _intensitySlider = 5.0;

  // Health metrics tab — one controller per metric key
  final Map<String, TextEditingController> _metricControllers = {};

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _durationController.addListener(() => setState(() {}));
    for (final specs in _metricSections.values) {
      for (final spec in specs) {
        _metricControllers[spec.key] = TextEditingController();
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _durationController.dispose();
    for (final c in _metricControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  // Live heart points preview based on current workout tab values.
  int get _previewHeartPoints {
    final duration = int.tryParse(_durationController.text) ?? 0;
    return HeartPointCalculator.calculateFromManualWorkout(
      activityType: _activityType,
      durationMinutes: duration,
      intensity: _intensitySlider.round(),
    );
  }

  String _dateKey(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  String _formatDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$h:$min';
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDateTime,
      firstDate: DateTime(2000),
      lastDate: now,
    );
    if (picked != null) {
      setState(() {
        _selectedDateTime = DateTime(
          picked.year,
          picked.month,
          picked.day,
          _selectedDateTime.hour,
          _selectedDateTime.minute,
        );
      });
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_selectedDateTime),
    );
    if (picked != null) {
      setState(() {
        _selectedDateTime = DateTime(
          _selectedDateTime.year,
          _selectedDateTime.month,
          _selectedDateTime.day,
          picked.hour,
          picked.minute,
        );
      });
    }
  }

  Color _intensityColor(int intensity) {
    if (intensity <= 3) return Colors.blue;
    if (intensity <= 6) return Colors.orange;
    return const Color(0xFFF43F5E);
  }

  Future<void> _saveData() async {
    final duration = int.tryParse(_durationController.text) ?? 0;
    final hasWorkout = duration > 0;
    final metricEntries = _metricControllers.entries
        .where((e) => e.value.text.trim().isNotEmpty)
        .toList();
    final hasMetrics = metricEntries.isNotEmpty;

    if (!hasWorkout && !hasMetrics) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter at least one workout or metric to log.'),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    HapticFeedback.mediumImpact();

    try {
      final secretKey = widget.secretKey;
      if (secretKey == null) {
        throw StateError('Vault is locked. Unlock before saving data.');
      }

      final dateKey = _dateKey(_selectedDateTime);

      // Save workout entry and merge derived heart points.
      if (hasWorkout) {
        final intensity = _intensitySlider.round();
        final heartPts = HeartPointCalculator.calculateFromManualWorkout(
          activityType: _activityType,
          durationMinutes: duration,
          intensity: intensity,
        );

        final workoutData = {
          'type': _activityType,
          'duration': duration,
          'intensity': intensity,
          'timestamp': _selectedDateTime.toIso8601String(),
        };
        final encryptedBlob = await EncryptionService().encryptString(
          jsonEncode(workoutData),
          secretKey,
        );
        await LocalVault().saveWorkout(encryptedBlob, secretKey);

        if (heartPts > 0) {
          await LocalVault().mergeDailyMetrics(
            dateKey: dateKey,
            incoming: {'heart_points': heartPts},
            secretKey: secretKey,
          );
        }
      }

      // Merge any filled health metric fields.
      if (hasMetrics) {
        final incoming = <String, num>{};
        for (final entry in metricEntries) {
          final value = num.tryParse(entry.value.text.trim());
          if (value != null && value >= 0) {
            incoming[entry.key] = value;
          }
        }
        if (incoming.isNotEmpty) {
          await LocalVault().mergeDailyMetrics(
            dateKey: dateKey,
            incoming: incoming,
            secretKey: secretKey,
          );
        }
      }

      final newMedals =
          await AchievementService().checkAndUnlockAchievements(secretKey);

      if (mounted) {
        Navigator.pop(context, newMedals);
      }
    } catch (e) {
      debugPrint('Save error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DraggableScrollableSheet(
      initialChildSize: 0.70,
      minChildSize: 0.50,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface.withValues(alpha: 0.85),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(32)),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Column(
              children: [
                _buildDragHandle(theme),
                _buildHeader(theme),
                _buildDateTimePicker(theme),
                _buildTabBar(theme),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildWorkoutTab(theme, scrollController),
                      _buildHealthMetricsTab(theme, scrollController),
                    ],
                  ),
                ),
                _buildSaveButton(theme),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDragHandle(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 4),
      child: Center(
        child: Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: theme.hintColor.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Log Health Data',
            style: theme.textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'All data is encrypted before leaving this device.',
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.hintColor),
          ),
        ],
      ),
    );
  }

  Widget _buildDateTimePicker(ThemeData theme) {
    final isToday = _dateKey(_selectedDateTime) == _dateKey(DateTime.now());
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: theme.cardTheme.color,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today_outlined,
                size: 18, color: theme.colorScheme.primary),
            const SizedBox(width: 10),
            Expanded(
              child: InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(8),
                child: Text(
                  isToday ? 'Today' : _formatDate(_selectedDateTime),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: isToday
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            Container(
              width: 1,
              height: 20,
              color: theme.dividerColor,
              margin: const EdgeInsets.symmetric(horizontal: 12),
            ),
            Icon(Icons.access_time_outlined,
                size: 18, color: theme.colorScheme.primary),
            const SizedBox(width: 10),
            InkWell(
              onTap: _pickTime,
              borderRadius: BorderRadius.circular(8),
              child: Text(
                _formatTime(_selectedDateTime),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabBar(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: TabBar(
        controller: _tabController,
        dividerColor: Colors.transparent,
        indicator: BoxDecoration(
          color: theme.colorScheme.primary.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: theme.colorScheme.primary.withValues(alpha: 0.4)),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: theme.colorScheme.primary,
        unselectedLabelColor: theme.hintColor,
        labelStyle:
            theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        tabs: const [
          Tab(text: 'Workout'),
          Tab(text: 'Health Metrics'),
        ],
      ),
    );
  }

  Widget _buildWorkoutTab(ThemeData theme, ScrollController scrollController) {
    final intensity = _intensitySlider.round();
    final intensityColor = _intensityColor(intensity);

    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
      children: [
        Text('Activity Type',
            style: theme.textTheme.labelLarge
                ?.copyWith(color: theme.hintColor)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _activityTypes.map((type) {
            final selected = _activityType == type;
            return ChoiceChip(
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(_iconForActivity(type),
                      size: 16,
                      color: selected
                          ? Colors.white
                          : theme.colorScheme.onSurface),
                  const SizedBox(width: 6),
                  Text(type),
                ],
              ),
              selected: selected,
              selectedColor: theme.colorScheme.primary,
              backgroundColor: theme.cardTheme.color,
              labelStyle: TextStyle(
                color: selected ? Colors.white : theme.colorScheme.onSurface,
                fontWeight:
                    selected ? FontWeight.w600 : FontWeight.normal,
              ),
              onSelected: (_) => setState(() => _activityType = type),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              side: BorderSide(
                color: selected
                    ? theme.colorScheme.primary
                    : Colors.white.withValues(alpha: 0.1),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 24),
        Text('Duration',
            style: theme.textTheme.labelLarge
                ?.copyWith(color: theme.hintColor)),
        const SizedBox(height: 10),
        TextField(
          controller: _durationController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            hintText: 'Minutes',
            prefixIcon: const Icon(Icons.timer_outlined),
            filled: true,
            fillColor: theme.cardTheme.color,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Intensity',
                style: theme.textTheme.labelLarge
                    ?.copyWith(color: theme.hintColor)),
            Text(
              '$intensity / 10',
              style: theme.textTheme.titleMedium?.copyWith(
                color: intensityColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: intensityColor,
            thumbColor: intensityColor,
            overlayColor: intensityColor.withValues(alpha: 0.12),
            inactiveTrackColor:
                intensityColor.withValues(alpha: 0.2),
          ),
          child: Slider(
            value: _intensitySlider,
            min: 1,
            max: 10,
            divisions: 9,
            onChanged: (v) => setState(() => _intensitySlider = v),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Light',
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: theme.hintColor)),
              Text('Moderate',
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: theme.hintColor)),
              Text('Vigorous',
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: theme.hintColor)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Live heart points preview
        AnimatedOpacity(
          opacity: _previewHeartPoints > 0 ? 1.0 : 0.4,
          duration: const Duration(milliseconds: 200),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF43F5E).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: const Color(0xFFF43F5E).withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.favorite,
                    size: 16, color: Color(0xFFF43F5E)),
                const SizedBox(width: 8),
                Text(
                  _previewHeartPoints > 0
                      ? '≈ $_previewHeartPoints heart points earned'
                      : 'Light intensity — no heart points',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: const Color(0xFFF43F5E),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildHealthMetricsTab(
      ThemeData theme, ScrollController scrollController) {
    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
      children: [
        for (final section in _metricSections.entries) ...[
          _buildSectionHeader(theme, section.key),
          const SizedBox(height: 10),
          for (final spec in section.value) ...[
            _buildMetricField(theme, spec),
            const SizedBox(height: 12),
          ],
          const SizedBox(height: 8),
        ],
      ],
    );
  }

  Widget _buildSectionHeader(ThemeData theme, String title) {
    return Row(
      children: [
        Text(
          title.toUpperCase(),
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.hintColor,
            letterSpacing: 1.2,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Divider(
            color: theme.dividerColor,
            thickness: 1,
          ),
        ),
      ],
    );
  }

  Widget _buildMetricField(ThemeData theme, _MetricSpec spec) {
    final label = spec.unit.isEmpty
        ? spec.title
        : '${spec.title} (${spec.unit})';
    return TextField(
      controller: _metricControllers[spec.key],
      keyboardType:
          const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        hintText: spec.isAdditive ? 'Adds to existing' : 'Replaces existing',
        prefixIcon: Icon(spec.icon, color: spec.iconColor, size: 20),
        filled: true,
        fillColor: theme.cardTheme.color,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildSaveButton(ThemeData theme) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: ElevatedButton(
        onPressed: _isSaving ? null : _saveData,
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: _isSaving
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Text('Encrypt & Vault Data'),
      ),
    );
  }
}
