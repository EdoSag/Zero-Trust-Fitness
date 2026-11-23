import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zero_trust_core/zero_trust_core.dart';
import 'package:zerotrust_fitness/core/storage/fitness_vault.dart';
import 'package:zerotrust_fitness/core/utils/units_formatter.dart';
import 'package:zerotrust_fitness/features/gpx/gpx.dart';
import 'package:zerotrust_fitness/features/gpx/workout_files.dart';
import 'package:zerotrust_fitness/features/gpx/gpx_workouts.dart';
import 'package:zerotrust_fitness/l10n/l10n.dart';

const _activities = [
  'Running',
  'Cycling',
  'Hiking',
  'Walking',
  'Swimming',
  'Strength Training',
  'HIIT',
  'Yoga/Stretching',
  'Other',
];

/// Brings workouts in from the files watches and apps export: FIT (Garmin,
/// Coros, Wahoo, Suunto), TCX (Garmin Connect, Polar) and GPX (Strava,
/// Komoot, a bike computer...). The file is read on the phone; only the
/// encrypted workout is synced.
class WorkoutFilesImportPage extends ConsumerStatefulWidget {
  const WorkoutFilesImportPage({super.key, required this.vault});

  final FitnessVault vault;

  @override
  ConsumerState<WorkoutFilesImportPage> createState() =>
      _WorkoutFilesImportPageState();
}

class _TrackDraft {
  _TrackDraft(this.track, this.alreadyImported)
    : activity =
          track.activity ?? (track.format == 'gpx' ? 'Running' : 'Other'),
      start = track.start?.toLocal() ?? DateTime.now(),
      minutes = track.duration?.inMinutes ?? 0,
      selected = !alreadyImported;

  final GpxTrack track;
  final bool alreadyImported;
  String activity;
  DateTime start;
  int minutes;
  bool selected;

  bool get hasTimes => track.duration != null;
}

class _WorkoutFilesImportPageState
    extends ConsumerState<WorkoutFilesImportPage> {
  List<_TrackDraft> _drafts = const [];
  bool _countHeartPoints = true;
  bool _busy = false;
  String? _error;
  String? _done;

  GpxWorkouts get _gpx => GpxWorkouts(widget.vault);

  Future<void> _pick() async {
    final files = await ref
        .read(vaultControllerProvider.notifier)
        .whileShowingSystemUi(() => FilePicker.pickFiles(type: FileType.any));
    final paths = [
      for (final f in files)
        if (f.path case final p?) p,
    ];
    if (paths.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
      _done = null;
      _drafts = const [];
    });
    final drafts = <_TrackDraft>[];
    final failed = <String>[];
    for (final path in paths) {
      try {
        final tracks = WorkoutFiles.parse(await File(path).readAsBytes());
        for (final t in tracks) {
          drafts.add(_TrackDraft(t, await _gpx.isImported(t)));
        }
      } catch (_) {
        failed.add(path.split(Platform.pathSeparator).last);
      }
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _drafts = drafts;
      if (drafts.isEmpty) {
        _error = failed.isNotEmpty
            ? context.l10n.couldntReadWorkoutFiles(failed.join(', '))
            : context.l10n.noWorkoutsInFile;
      } else if (failed.isNotEmpty) {
        _error = context.l10n.skippedUnreadableFiles(failed.join(', '));
      }
    });
  }

  Future<void> _import() async {
    final chosen = _drafts.where((d) => d.selected).toList();
    if (chosen.any((d) => d.minutes <= 0)) {
      setState(() => _error = context.l10n.enterHowLongEachWorkout);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    var count = 0;
    try {
      for (final d in chosen) {
        await _gpx.import(
          d.track,
          activity: d.activity,
          start: d.start,
          durationMinutes: d.minutes,
          countHeartPoints: _countHeartPoints,
        );
        count++;
      }
      if (!mounted) return;
      setState(() {
        _done = context.l10n.importedWorkouts(count);
        _drafts = const [];
      });
    } catch (e) {
      if (mounted) setState(() => _error = ztErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickStart(_TrackDraft d) async {
    final date = await showDatePicker(
      context: context,
      initialDate: d.start,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(d.start),
    );
    if (!mounted) return;
    setState(
      () => d.start = DateTime(
        date.year,
        date.month,
        date.day,
        time?.hour ?? d.start.hour,
        time?.minute ?? d.start.minute,
      ),
    );
  }

  /// TCX and FIT files have no names: the activity and day stand in.
  String _fallbackTitle(_TrackDraft d) {
    if (d.track.format == 'gpx') return context.l10n.track;
    final start = d.track.start;
    final label = activityLabel(d.activity);
    if (start == null) return label;
    return '$label · ${UnitsFormatter().formatDate(start.toLocal())}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final units = UnitsFormatter();
    final selected = _drafts.where((d) => d.selected).length;
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.importWorkoutFiles)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            context.l10n.bringInWorkoutFiles,
            style: TextStyle(color: theme.hintColor),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _busy ? null : _pick,
            icon: const Icon(Icons.file_open_outlined),
            label: Text(context.l10n.chooseWorkoutFiles),
          ),
          if (_busy) ...[
            const SizedBox(height: 16),
            const LinearProgressIndicator(),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
          ],
          if (_done != null) ...[const SizedBox(height: 12), Text(_done!)],
          for (final d in _drafts)
            Card(
              margin: const EdgeInsets.only(top: 12),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CheckboxListTile(
                      contentPadding: const EdgeInsets.only(left: 4),
                      value: d.selected,
                      onChanged: (v) => setState(() => d.selected = v ?? false),
                      title: Text(d.track.name ?? _fallbackTitle(d)),
                      subtitle: Text(
                        [
                          if (d.track.distanceMeters > 0)
                            units.formatDistance(d.track.distanceMeters / 1000),
                          if (d.track.hasRoute)
                            context.l10n.nPoints(d.track.points.length)
                          else
                            context.l10n.noRouteInFile,
                          if (d.track.avgHeartRate case final hr?) '$hr bpm',
                          if (d.alreadyImported) context.l10n.alreadyImported,
                        ].join(' · '),
                      ),
                    ),
                    if (d.selected)
                      Padding(
                        padding: const EdgeInsets.only(left: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            DropdownButton<String>(
                              value: d.activity,
                              items: [
                                for (final a in {..._activities, d.activity})
                                  DropdownMenuItem(
                                    value: a,
                                    child: Text(activityLabel(a)),
                                  ),
                              ],
                              onChanged: (v) =>
                                  setState(() => d.activity = v ?? d.activity),
                            ),
                            if (d.hasTimes)
                              Text(
                                '${units.formatDate(d.start)} '
                                '${units.formatTime(d.start)} · '
                                '${context.l10n.nMin(d.minutes)}',
                                style: TextStyle(color: theme.hintColor),
                              )
                            else ...[
                              Text(
                                context.l10n.thisFileHasNoTimes,
                                style: TextStyle(color: theme.hintColor),
                              ),
                              Row(
                                children: [
                                  TextButton.icon(
                                    onPressed: () => _pickStart(d),
                                    icon: const Icon(Icons.event_outlined),
                                    label: Text(
                                      '${units.formatDate(d.start)} '
                                      '${units.formatTime(d.start)}',
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  SizedBox(
                                    width: 96,
                                    child: TextFormField(
                                      initialValue: d.minutes > 0
                                          ? '${d.minutes}'
                                          : '',
                                      keyboardType: TextInputType.number,
                                      decoration: const InputDecoration(
                                        suffixText: 'min',
                                        isDense: true,
                                      ),
                                      onChanged: (v) =>
                                          d.minutes = int.tryParse(v) ?? 0,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          if (_drafts.isNotEmpty) ...[
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(context.l10n.countHeartPoints),
              subtitle: Text(context.l10n.turnOffIfTheseWorkouts),
              value: _countHeartPoints,
              onChanged: (v) => setState(() => _countHeartPoints = v),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _busy || selected == 0 ? null : _import,
              child: Text(context.l10n.importNWorkouts(selected)),
            ),
          ],
        ],
      ),
    );
  }
}
