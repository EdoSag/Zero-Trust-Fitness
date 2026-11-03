import 'package:flutter/material.dart';
import 'package:zerotrust_fitness/core/services/reminder_service.dart';

class RemindersPage extends StatefulWidget {
  const RemindersPage({super.key});

  @override
  State<RemindersPage> createState() => _RemindersPageState();
}

class _RemindersPageState extends State<RemindersPage> {
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

  static const _weekdayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

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
          const SnackBar(
              content: Text('Notification permission required for reminders.')),
        );
        return;
      }
      if (mounted) setState(() => _permissionGranted = true);
    }
    await ReminderService().applySettings(newSettings);
    if (mounted) setState(() => _settings = newSettings);
  }

  Future<void> _pickTime(TimeOfDay current, void Function(TimeOfDay) onPicked) async {
    final picked = await showTimePicker(context: context, initialTime: current);
    if (picked != null) onPicked(picked);
  }

  String _fmt(TimeOfDay t) {
    final h = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final m = t.minute.toString().padLeft(2, '0');
    final period = t.period == DayPeriod.am ? 'AM' : 'PM';
    return '$h:$m $period';
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
      appBar: AppBar(title: const Text('Reminders')),
      body: ListView(
        children: [
          // -- Movement -------------------------------------------------------
          _section('Activity'),
          SwitchListTile(
            secondary: const Icon(Icons.directions_walk_outlined),
            title: const Text('Movement nudge'),
            subtitle: const Text('Hourly reminder to stay active'),
            value: _settings.movementEnabled,
            onChanged: (v) =>
                _apply(_settings.copyWith(movementEnabled: v)),
          ),

          // -- Hydration ------------------------------------------------------
          SwitchListTile(
            secondary: const Icon(Icons.water_drop_outlined),
            title: const Text('Hydration reminder'),
            subtitle: const Text('Hourly prompt to drink water'),
            value: _settings.hydrationEnabled,
            onChanged: (v) =>
                _apply(_settings.copyWith(hydrationEnabled: v)),
          ),

          // -- Workout --------------------------------------------------------
          _section('Workout'),
          SwitchListTile(
            secondary: const Icon(Icons.fitness_center_outlined),
            title: const Text('Workout reminder'),
            subtitle: const Text('Choose days and time'),
            value: _settings.workoutEnabled,
            onChanged: (v) =>
                _apply(_settings.copyWith(workoutEnabled: v)),
          ),
          if (_settings.workoutEnabled) ...[
            _timeTile(
              'Reminder time',
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
                    label: Text(_weekdayLabels[i]),
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
          _section('Sleep'),
          SwitchListTile(
            secondary: const Icon(Icons.bedtime_outlined),
            title: const Text('Bedtime reminder'),
            subtitle: const Text('Daily wind-down prompt'),
            value: _settings.sleepEnabled,
            onChanged: (v) =>
                _apply(_settings.copyWith(sleepEnabled: v)),
          ),
          if (_settings.sleepEnabled)
            _timeTile(
              'Bedtime',
              _settings.sleepTime,
              () => _pickTime(_settings.sleepTime, (t) {
                _apply(_settings.copyWith(sleepTime: t));
              }),
            ),

          // -- Measurement ----------------------------------------------------
          _section('Body Measurements'),
          SwitchListTile(
            secondary: const Icon(Icons.monitor_weight_outlined),
            title: const Text('Weekly check-in'),
            subtitle:
                const Text('Weekly reminder to log weight or measurements'),
            value: _settings.measurementEnabled,
            onChanged: (v) =>
                _apply(_settings.copyWith(measurementEnabled: v)),
          ),

          const SizedBox(height: 32),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'All reminders are local-only and never leave your device.',
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
