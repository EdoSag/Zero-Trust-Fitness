import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zerotrust_fitness/app/vault_providers.dart';
import 'package:zerotrust_fitness/core/services/reminder_service.dart';
import 'package:zerotrust_fitness/l10n/l10n.dart';

class RemindersPage extends ConsumerStatefulWidget {
  const RemindersPage({super.key});

  @override
  ConsumerState<RemindersPage> createState() => _RemindersPageState();
}

class _RemindersPageState extends ConsumerState<RemindersPage> {
  ReminderSettings _settings = const ReminderSettings(
    movementEnabled: false,
    hydrationEnabled: false,
    workoutEnabled: false,
    workoutDays: [],
    workoutTime: TimeOfDay(hour: 7, minute: 0),
    sleepEnabled: false,
    sleepTime: TimeOfDay(hour: 22, minute: 0),
    measurementEnabled: false,
  );
  bool _loading = true;
  bool _permissionGranted = false;


  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await ReminderService().initialize();
    final s = await ReminderService().loadSettings();
    if (mounted) setState(() { _settings = s; _loading = false; });
  }

  Future<void> _apply(ReminderSettings newSettings) async {
    if (!_permissionGranted) {
      final granted = await ReminderService().requestPermission();
      if (!granted && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(context.l10n.notificationPermissionRequiredForReminders)),
        );
        return;
      }
      if (mounted) setState(() => _permissionGranted = true);
    }
    await ReminderService().applySettings(newSettings,
        vault: ref.read(openFitnessVaultProvider));
    if (mounted) setState(() => _settings = newSettings);
  }

  Future<void> _pickTime(TimeOfDay current, void Function(TimeOfDay) onPicked) async {
    final picked = await showTimePicker(context: context, initialTime: current);
    if (picked != null) onPicked(picked);
  }

  String _fmt(TimeOfDay t) {
    return MaterialLocalizations.of(context).formatTimeOfDay(t);
  }

  Widget _section(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).hintColor,
            ),
      ),
    );
  }

  Widget _timeTile(String label, TimeOfDay time, VoidCallback onTap) {
    return ListTile(
      dense: true,
      leading: const Icon(Icons.access_time_outlined, size: 20),
      title: Text(label),
      trailing: TextButton(onPressed: onTap, child: Text(_fmt(time))),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        appBar: null,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.reminders)),
      body: ListView(
        children: [
          // -- Weekly summary -------------------------------------------------
          _section(context.l10n.summary),
          SwitchListTile(
            secondary: const Icon(Icons.insights_outlined),
            title: Text(context.l10n.weeklySummaryX),
            subtitle: Text(
                context.l10n.mondaysAt900Heart),
            value: _settings.weeklySummaryEnabled,
            onChanged: (v) =>
                _apply(_settings.copyWith(weeklySummaryEnabled: v)),
          ),

          // -- Movement -------------------------------------------------------
          _section(context.l10n.activity),
          SwitchListTile(
            secondary: const Icon(Icons.directions_walk_outlined),
            title: Text(context.l10n.movementNudge),
            subtitle: Text(context.l10n.hourlyReminderToStayActive),
            value: _settings.movementEnabled,
            onChanged: (v) =>
                _apply(_settings.copyWith(movementEnabled: v)),
          ),

          // -- Hydration ------------------------------------------------------
          SwitchListTile(
            secondary: const Icon(Icons.water_drop_outlined),
            title: Text(context.l10n.hydrationReminder),
            subtitle: Text(context.l10n.hourlyPromptToDrinkWater),
            value: _settings.hydrationEnabled,
            onChanged: (v) =>
                _apply(_settings.copyWith(hydrationEnabled: v)),
          ),

          // -- Workout --------------------------------------------------------
          _section(context.l10n.workout),
          SwitchListTile(
            secondary: const Icon(Icons.fitness_center_outlined),
            title: Text(context.l10n.workoutReminder),
            subtitle: Text(context.l10n.chooseDaysAndTime),
            value: _settings.workoutEnabled,
            onChanged: (v) =>
                _apply(_settings.copyWith(workoutEnabled: v)),
          ),
          if (_settings.workoutEnabled) ...[
            _timeTile(
              context.l10n.reminderTime,
              _settings.workoutTime,
              () => _pickTime(_settings.workoutTime, (t) {
                _apply(_settings.copyWith(workoutTime: t));
              }),
            ),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Wrap(
                spacing: 8,
                children: List.generate(7, (i) {
                  final day = i + 1; // 1=Mon … 7=Sun
                  final selected = _settings.workoutDays.contains(day);
                  return FilterChip(
                    label: Text(DateFormat.E().format(DateTime(2024, 1, i + 1))),
                    selected: selected,
                    onSelected: (v) {
                      final days = List<int>.from(_settings.workoutDays);
                      v ? days.add(day) : days.remove(day);
                      _apply(_settings.copyWith(workoutDays: days));
                    },
                  );
                }),
              ),
            ),
          ],

          // -- Sleep ----------------------------------------------------------
          _section(context.l10n.sleep),
          SwitchListTile(
            secondary: const Icon(Icons.bedtime_outlined),
            title: Text(context.l10n.bedtimeReminder),
            subtitle: Text(context.l10n.dailyWindDownPrompt),
            value: _settings.sleepEnabled,
            onChanged: (v) =>
                _apply(_settings.copyWith(sleepEnabled: v)),
          ),
          if (_settings.sleepEnabled)
            _timeTile(
              context.l10n.bedtime,
              _settings.sleepTime,
              () => _pickTime(_settings.sleepTime, (t) {
                _apply(_settings.copyWith(sleepTime: t));
              }),
            ),

          // -- Measurement ----------------------------------------------------
          _section(context.l10n.bodyMeasurements),
          SwitchListTile(
            secondary: const Icon(Icons.monitor_weight_outlined),
            title: Text(context.l10n.weeklyCheckIn),
            subtitle:
                Text(context.l10n.weeklyReminderToLogWeight),
            value: _settings.measurementEnabled,
            onChanged: (v) =>
                _apply(_settings.copyWith(measurementEnabled: v)),
          ),

          const SizedBox(height: 32),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              context.l10n.allRemindersAreLocalOnly,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Theme.of(context).hintColor),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
