import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:zerotrust_fitness/components/empty_state_widget.dart';
import 'package:zerotrust_fitness/core/storage/fitness_vault.dart';
import 'package:zerotrust_fitness/core/utils/units_formatter.dart';
import 'package:zerotrust_fitness/features/dashboard/metric_card_specs.dart';
import 'package:zerotrust_fitness/features/health/data/gps_tracking_service.dart';
import 'package:zerotrust_fitness/features/maps/route_map.dart';
import 'package:zerotrust_fitness/l10n/l10n.dart';

enum JournalFilter { all, workouts, measurements }

/// One line in the journal: a workout, or a metric typed in by hand.
sealed class JournalItem {
  const JournalItem();
  DateTime get at;
  String get dayKey;
}

class WorkoutItem extends JournalItem {
  const WorkoutItem(this.id, this.data);
  final String id;
  final Map<String, dynamic> data;

  @override
  DateTime get at =>
      DateTime.tryParse((data['timestamp'] ?? data['date'] ?? '').toString())
          ?.toLocal() ??
      DateTime(1970);

  @override
  String get dayKey => FitnessVault.workoutDateKey(data) ?? '';

  /// Logged here (manual or GPS), so its duration and intensity can be
  /// edited. Records read from Health Connect by older versions can only be
  /// deleted.
  bool get isEditable => data['duration'] is num;

  bool get isGps => data['route'] is List || data['distance_m'] is num;

  String get sourceLabel => switch (data['source']) {
        'google_fit' => 'GOOGLE FIT',
        'gpx' => 'GPX',
        _ when data['imported_from'] == 'gpx' => 'GPX',
        _ when !isEditable => 'HEALTH',
        _ when data['route'] is List => 'GPS',
        _ => 'MANUAL',
      };

  String get title {
    final raw = (data['type'] ?? currentL10n.activity).toString();
    if (!raw.startsWith('HealthDataType.')) return raw;
    return raw
        .replaceFirst('HealthDataType.', '')
        .split('_')
        .where((p) => p.isNotEmpty)
        .map((p) => p[0].toUpperCase() + p.substring(1).toLowerCase())
        .join(' ');
  }
}

class MeasurementItem extends JournalItem {
  const MeasurementItem(this.entry);
  final ManualEntry entry;

  MetricCardSpec? get spec =>
      metricCardSpecs.where((s) => s.key == entry.metricKey).firstOrNull;

  String get title => spec?.title ?? entry.metricKey;

  @override
  DateTime get at => DateTime.tryParse(entry.dateKey) ?? DateTime(1970);

  @override
  String get dayKey => entry.dateKey;
}

/// Every workout and every hand-entered measurement in one history, newest
/// first, with edit and delete on each.
class JournalPage extends StatefulWidget {
  const JournalPage({
    super.key,
    required this.workouts,
    required this.measurements,
    required this.isLoading,
    required this.canEdit,
    required this.onLog,
    required this.onRefresh,
    required this.onEditWorkout,
    required this.onDeleteWorkout,
    required this.onEditMeasurement,
    required this.onDeleteMeasurement,
    this.onImportGpx,
    this.onExportGpx,
  });

  /// Workout data with its item id under `_id`.
  final List<Map<String, dynamic>> workouts;
  final List<ManualEntry> measurements;
  final bool isLoading;
  final bool canEdit;
  final VoidCallback onLog;
  final Future<void> Function() onRefresh;
  final Future<void> Function(String id, Map<String, dynamic> data)
      onEditWorkout;
  final Future<void> Function(String id) onDeleteWorkout;
  final Future<void> Function(ManualEntry entry, num value) onEditMeasurement;
  final Future<void> Function(ManualEntry entry) onDeleteMeasurement;

  /// Opens the GPX import screen.
  final VoidCallback? onImportGpx;

  /// Shares a workout's route as a GPX file.
  final Future<void> Function(Map<String, dynamic> data)? onExportGpx;

  @override
  State<JournalPage> createState() => _JournalPageState();
}

class _JournalPageState extends State<JournalPage> {
  final TextEditingController _searchController = TextEditingController();
  JournalFilter _filter = JournalFilter.all;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _query = _searchController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<JournalItem> get _items {
    final items = <JournalItem>[
      if (_filter != JournalFilter.measurements)
        for (final w in widget.workouts)
          if (w['_id'] case final String id) WorkoutItem(id, w),
      if (_filter != JournalFilter.workouts)
        for (final m in widget.measurements) MeasurementItem(m),
    ];
    final filtered = _query.isEmpty
        ? items
        : items.where((i) {
            final title = switch (i) {
              // The stored name and the one shown in the app's language.
              WorkoutItem w => '${w.title} ${activityLabel(w.title)}',
              MeasurementItem m => m.title,
            };
            return title.toLowerCase().contains(_query);
          }).toList();
    filtered.sort((a, b) {
      final byDay = b.dayKey.compareTo(a.dayKey);
      if (byDay != 0) return byDay;
      // Workouts first within a day, newest first.
      return switch ((a, b)) {
        (WorkoutItem(), MeasurementItem()) => -1,
        (MeasurementItem(), WorkoutItem()) => 1,
        _ => b.at.compareTo(a.at),
      };
    });
    return filtered;
  }

  String _dayLabel(String dayKey) {
    final d = DateTime.tryParse(dayKey);
    if (d == null) return context.l10n.unknownDate;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(d.year, d.month, d.day);
    if (day == today) return context.l10n.today;
    if (day == today.subtract(const Duration(days: 1))) return context.l10n.yesterday;
    return day.year == today.year
        ? DateFormat.MMMEd().format(day)
        : DateFormat.yMMMEd().format(day);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final items = _items;

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.journal),
        actions: [
          if (widget.onImportGpx != null && widget.canEdit)
            IconButton(
              tooltip: context.l10n.importGpxRoutes,
              icon: const Icon(Icons.route_outlined),
              onPressed: widget.onImportGpx,
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: widget.onRefresh,
        child: widget.isLoading && widget.workouts.isEmpty
            ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
            : CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(child: _searchField()),
                  SliverToBoxAdapter(child: _filterChips()),
                  if (items.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: EmptyStateWidget(
                        icon: Icons.history,
                        title: _query.isEmpty
                            ? context.l10n.nothingLoggedYet
                            : context.l10n.nothingMatches(_query),
                        subtitle: context.l10n.workoutsAndMeasurementsYouLog,
                        action: TextButton.icon(
                          onPressed: widget.onLog,
                          icon: const Icon(Icons.add, size: 16),
                          label: Text(context.l10n.logAWorkoutOrMeasurement),
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                      sliver: SliverList.builder(
                        itemCount: items.length,
                        itemBuilder: (context, i) {
                          final item = items[i];
                          final header = i == 0 ||
                              items[i - 1].dayKey != item.dayKey;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (header)
                                Padding(
                                  padding:
                                      const EdgeInsetsDirectional.fromSTEB(4, 16, 0, 6),
                                  child: Text(
                                    _dayLabel(item.dayKey),
                                    style: theme.textTheme.labelMedium
                                        ?.copyWith(
                                      color: theme.hintColor,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              switch (item) {
                                WorkoutItem w => _workoutTile(theme, w),
                                MeasurementItem m =>
                                  _measurementTile(theme, m),
                              },
                            ],
                          );
                        },
                      ),
                    ),
                ],
              ),
      ),
      floatingActionButton: FloatingActionButton(
        // Today and Journal are both kept alive in the tab stack.
        heroTag: 'fab-journal',
        onPressed: widget.onLog,
        tooltip: context.l10n.logAWorkoutOrMeasurement,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _searchField() => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: context.l10n.searchTheJournal,
            prefixIcon: const Icon(Icons.search, size: 20),
            suffixIcon: _query.isNotEmpty
                ? IconButton(
                    tooltip: context.l10n.clear,
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: _searchController.clear,
                  )
                : null,
            isDense: true,
            border:
                OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      );

  Widget _filterChips() => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            for (final f in JournalFilter.values)
              Padding(
                padding: const EdgeInsetsDirectional.only(end: 8),
                child: FilterChip(
                  label: Text(switch (f) {
                    JournalFilter.all => context.l10n.all,
                    JournalFilter.workouts => context.l10n.workouts,
                    JournalFilter.measurements => context.l10n.measurements,
                  }),
                  selected: _filter == f,
                  onSelected: (_) => setState(() => _filter = f),
                ),
              ),
          ],
        ),
      );

  // ---------------------------------------------------------------------------
  // Workouts
  // ---------------------------------------------------------------------------

  String _workoutSubtitle(WorkoutItem w) {
    final units = UnitsFormatter();
    final parts = <String>[];
    final duration = w.data['duration'];
    if (duration is num) parts.add(context.l10n.nMin(duration.toInt()));
    final distance = w.data['distance_m'];
    if (distance is num && distance > 0) {
      parts.add(units.formatDistance(distance / 1000));
    }
    final points = FitnessVault.workoutHeartPoints(w.data);
    if (points > 0) parts.add(context.l10n.nPts(points));
    final value = w.data['value'];
    if (duration == null && value != null) parts.add('$value');
    if (w.at.year > 1970) parts.add(units.formatTime(w.at));
    return parts.join(' · ');
  }

  Widget _sourceBadge(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: Text(
          switch (label) {
            'MANUAL' => context.l10n.srcManual,
            'HEALTH' => context.l10n.srcHealth,
            'GOOGLE FIT' => context.l10n.srcGoogleFit,
            _ => label,
          },
          style: TextStyle(
              color: color, fontSize: 10, fontWeight: FontWeight.bold),
        ),
      );

  Color _badgeColor(String label) => switch (label) {
        'GPS' => Colors.deepPurple,
        'GOOGLE FIT' => Colors.teal,
        'HEALTH' => Colors.green,
        _ => Colors.blue,
      };

  Widget _workoutTile(ThemeData theme, WorkoutItem w) {
    final label = w.sourceLabel;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: () => _showWorkout(w),
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.secondary.withValues(alpha: 0.1),
          child: Icon(activityIcon(w.title), color: theme.colorScheme.secondary),
        ),
        title: Text(activityLabel(w.title)),
        subtitle: Text(_workoutSubtitle(w)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _sourceBadge(label, _badgeColor(label)),
            if (widget.canEdit)
              PopupMenuButton<_Action>(
                tooltip: context.l10n.more,
                icon: const Icon(Icons.more_vert, size: 18),
                onSelected: (a) => switch (a) {
                  _Action.edit => widget.onEditWorkout(w.id, w.data),
                  _Action.delete => _confirmDeleteWorkout(w),
                },
                itemBuilder: (_) => [
                  if (w.isEditable) _menuItem(_Action.edit),
                  _menuItem(_Action.delete),
                ],
              ),
          ],
        ),
      ),
    );
  }

  PopupMenuItem<_Action> _menuItem(_Action a) => PopupMenuItem(
        value: a,
        child: Row(children: [
          Icon(
            a == _Action.edit ? Icons.edit_outlined : Icons.delete_outline,
            size: 16,
            color: a == _Action.delete ? Colors.redAccent : null,
          ),
          const SizedBox(width: 8),
          Text(
            a == _Action.edit ? context.l10n.edit : context.l10n.delete,
            style: a == _Action.delete
                ? const TextStyle(color: Colors.redAccent)
                : null,
          ),
        ]),
      );

  Future<bool> _confirm(String title, String body) async =>
      await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(title),
          content: Text(body),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(context.l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(ctx).colorScheme.error),
              child: Text(context.l10n.delete),
            ),
          ],
        ),
      ) ??
      false;

  Future<void> _confirmDeleteWorkout(WorkoutItem w) async {
    final points = FitnessVault.workoutHeartPoints(w.data);
    final ok = await _confirm(
      context.l10n.deleteThisItem(activityLabel(w.title).toLowerCase()),
      points > 0
          ? context.l10n.itsPointsComeOff(points)
          : context.l10n.thisDeletesItOnAll,
    );
    if (ok) await widget.onDeleteWorkout(w.id);
  }

  Future<void> _showWorkout(WorkoutItem w) async {
    final units = UnitsFormatter();
    final splits = _laps(w.data['splits']);
    final laps = _laps(w.data['laps']);
    final distance = (w.data['distance_m'] as num?)?.toDouble();
    final pace = (w.data['avg_pace_min_per_km'] as num?)?.toDouble();
    final route = GpsRoutePoint.listFrom(w.data['route']);
    final hasRoute = route.length >= 2;
    final action = await showModalBottomSheet<_Action>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize:
            hasRoute ? 0.75 : (splits.isEmpty && laps.isEmpty ? 0.4 : 0.6),
        maxChildSize: 0.9,
        builder: (ctx, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          children: [
            Text(w.title, style: Theme.of(ctx).textTheme.headlineSmall),
            const SizedBox(height: 4),
            Text(
              '${_dayLabel(w.dayKey)} · ${units.formatTime(w.at)} · '
              '${w.sourceLabel.toLowerCase()}',
              style: TextStyle(color: Theme.of(ctx).hintColor),
            ),
            if (hasRoute) ...[
              const SizedBox(height: 16),
              RouteMap(points: route),
            ],
            const SizedBox(height: 16),
            Wrap(
              spacing: 24,
              runSpacing: 12,
              children: [
                if (w.data['duration'] case final num d)
                  _stat(ctx, context.l10n.duration, context.l10n.nMin(d.toInt())),
                if (distance != null && distance > 0)
                  _stat(ctx, context.l10n.distance, units.formatDistance(distance / 1000)),
                if (pace != null && pace > 0 && pace.isFinite)
                  _stat(ctx, context.l10n.avgPaceX, units.formatPace(pace)),
                if (w.data['intensity'] case final num i)
                  _stat(ctx, context.l10n.intensity, '${i.toInt()}/10'),
                _stat(ctx, context.l10n.heartPoints,
                    '${FitnessVault.workoutHeartPoints(w.data)}'),
              ],
            ),
            if (splits.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text(context.l10n.splits, style: Theme.of(ctx).textTheme.titleMedium),
              _lapTable(ctx, splits, auto: true),
            ],
            if (laps.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text(context.l10n.laps, style: Theme.of(ctx).textTheme.titleMedium),
              _lapTable(ctx, laps, auto: false),
            ],
            if (hasRoute && widget.onExportGpx != null) ...[
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: () => widget.onExportGpx!(w.data),
                icon: const Icon(Icons.ios_share),
                label: Text(context.l10n.exportRouteGpx),
              ),
            ],
            if (widget.canEdit) ...[
              const SizedBox(height: 24),
              Row(
                children: [
                  if (w.isEditable)
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.pop(ctx, _Action.edit),
                        icon: const Icon(Icons.edit_outlined),
                        label: Text(context.l10n.edit),
                      ),
                    ),
                  if (w.isEditable) const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.pop(ctx, _Action.delete),
                      style: OutlinedButton.styleFrom(
                          foregroundColor: Theme.of(ctx).colorScheme.error),
                      icon: const Icon(Icons.delete_outline),
                      label: Text(context.l10n.delete),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
    if (!mounted) return;
    switch (action) {
      case _Action.edit:
        await widget.onEditWorkout(w.id, w.data);
      case _Action.delete:
        await _confirmDeleteWorkout(w);
      case null:
        break;
    }
  }

  static List<Map<String, dynamic>> _laps(Object? raw) => raw is List
      ? [
          for (final l in raw)
            if (l is Map) l.map((k, v) => MapEntry(k.toString(), v)),
        ]
      : const [];

  Widget _stat(BuildContext ctx, String label, String value) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value,
              style: Theme.of(ctx)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700)),
          Text(label, style: TextStyle(color: Theme.of(ctx).hintColor)),
        ],
      );

  Widget _lapTable(BuildContext ctx, List<Map<String, dynamic>> laps,
      {required bool auto}) {
    final units = UnitsFormatter();
    return Column(
      children: [
        for (final (i, lap) in laps.indexed)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Text(auto ? '${lap['index'] ?? i + 1}' : context.l10n.lapN(i + 1),
                style: const TextStyle(fontWeight: FontWeight.w600)),
            title: Text(formatClock(
                Duration(seconds: (lap['seconds'] as num?)?.toInt() ?? 0))),
            trailing: Text(
              [
                if (!auto && lap['distance_m'] is num)
                  units.formatDistance((lap['distance_m'] as num) / 1000),
                if (lap['pace_min_per_km'] case final num p when p > 0)
                  units.formatPace(p.toDouble()),
              ].join(' · '),
            ),
          ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Measurements
  // ---------------------------------------------------------------------------

  Widget _measurementTile(ThemeData theme, MeasurementItem m) {
    final spec = m.spec;
    final color = spec?.gradientColors.first ?? theme.colorScheme.primary;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: widget.canEdit ? () => _editMeasurement(m) : null,
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.12),
          child: Icon(spec?.icon ?? Icons.edit_note, color: color),
        ),
        title: Text(m.title),
        subtitle: Text(formatMetricValue(
            m.entry.metricKey, m.entry.value, spec?.unit ?? '')),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _sourceBadge('MANUAL', Colors.blue),
            if (widget.canEdit)
              PopupMenuButton<_Action>(
                tooltip: context.l10n.more,
                icon: const Icon(Icons.more_vert, size: 18),
                onSelected: (a) async {
                  switch (a) {
                    case _Action.edit:
                      await _editMeasurement(m);
                    case _Action.delete:
                      if (await _confirm(context.l10n.deleteThisEntry(m.title.toLowerCase()),
                          context.l10n.valuesFromHealthConnectFor)) {
                        await widget.onDeleteMeasurement(m.entry);
                      }
                  }
                },
                itemBuilder: (_) =>
                    [_menuItem(_Action.edit), _menuItem(_Action.delete)],
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _editMeasurement(MeasurementItem m) async {
    final controller =
        TextEditingController(text: _plain(m.entry.value));
    final value = await showDialog<num>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.editItem(m.title.toLowerCase())),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
          ],
          decoration: InputDecoration(
            suffixText: m.spec?.unit,
            helperText: _dayLabel(m.dayKey),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            onPressed: () {
              final v = num.tryParse(controller.text.trim());
              if (v != null && v >= 0) Navigator.pop(ctx, v);
            },
            child: Text(context.l10n.save),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value != null) await widget.onEditMeasurement(m.entry, value);
  }

  static String _plain(num v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();
}

enum _Action { edit, delete }

IconData activityIcon(String type) {
  final t = type.toLowerCase();
  if (t.contains('run')) return Icons.directions_run;
  if (t.contains('hik')) return Icons.terrain;
  if (t.contains('walk')) return Icons.directions_walk;
  if (t.contains('cycl') || t.contains('bik')) return Icons.directions_bike;
  if (t.contains('swim')) return Icons.pool;
  if (t.contains('strength')) return Icons.fitness_center;
  if (t.contains('hiit')) return Icons.bolt;
  if (t.contains('yoga') || t.contains('stretch')) {
    return Icons.self_improvement;
  }
  if (t.contains('heart')) return Icons.favorite;
  if (t.contains('step')) return Icons.hiking;
  return Icons.sports_gymnastics;
}

String formatClock(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return h > 0 ? '$h:$m:$s' : '$m:$s';
}
