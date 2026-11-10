import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:zerotrust_fitness/core/storage/fitness_vault.dart';
import 'package:zerotrust_fitness/features/gpx/gpx.dart';
import 'package:zerotrust_fitness/features/health/data/gps_tracking_service.dart';
import 'package:zerotrust_fitness/features/import/google_fit_takeout.dart';

/// Turning GPX tracks into workouts, and workouts into GPX files.
class GpxWorkouts {
  const GpxWorkouts(this.vault);

  final FitnessVault vault;

  /// The same id for the same track however often the file is imported.
  Future<String> idFor(GpxTrack track) {
    final first = track.points.first;
    final key = track.start != null
        ? track.start!.toIso8601String()
        : '${first.latitude.toStringAsFixed(5)},'
              '${first.longitude.toStringAsFixed(5)}|${track.name ?? ''}';
    return vault.idFor('workout:gpx|$key|${track.points.length}');
  }

  Future<bool> isImported(GpxTrack track) async =>
      vault.hasItem(await idFor(track));

  /// The workout a track becomes. With [countHeartPoints] it scores like a
  /// workout logged here; without, like other imports (no Heart Points),
  /// for a workout Health Connect already has.
  static Map<String, dynamic> workoutData(
    GpxTrack track, {
    required String activity,
    required DateTime start,
    required int durationMinutes,
    required bool countHeartPoints,
  }) {
    final distance = track.distanceMeters;
    return {
      'type': activity,
      'duration': durationMinutes,
      'intensity': FitSession.defaultIntensity(activity),
      'distance_m': double.parse(distance.toStringAsFixed(1)),
      if (distance > 0 && durationMinutes > 0)
        'avg_pace_min_per_km': double.parse(
          (durationMinutes / (distance / 1000)).toStringAsFixed(3),
        ),
      'timestamp': start.toLocal().toIso8601String(),
      if (track.name != null) 'name': track.name,
      'route': [for (final p in Gpx.thin(track.points)) p.toJson()],
      // Both keys are always written, so importing a track again with the
      // other choice replaces the earlier one (logWorkout merges fields).
      'imported_from': countHeartPoints ? 'gpx' : null,
      'source': countHeartPoints ? null : 'gpx',
    };
  }

  Future<String> import(
    GpxTrack track, {
    required String activity,
    required DateTime start,
    required int durationMinutes,
    required bool countHeartPoints,
  }) async {
    final id = await idFor(track);
    return vault.logWorkout(
      workoutData(
        track,
        activity: activity,
        start: start,
        durationMinutes: durationMinutes,
        countHeartPoints: countHeartPoints,
      ),
      id: id,
    );
  }

  /// Writes a workout's route to a `.gpx` file and opens the share sheet,
  /// so the person picks where it goes (Strava, Files, ...). Returns false
  /// when the workout has no route.
  static Future<bool> share(Map<String, dynamic> data) async {
    final gpx = Gpx.encodeWorkout(data);
    if (gpx == null) return false;
    final dir = await getTemporaryDirectory();
    final day = FitnessVault.workoutDateKey(data) ?? 'workout';
    final type = (data['type']?.toString() ?? 'workout')
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-');
    final file = File('${dir.path}/zt-fitness-$type-$day.gpx');
    await file.writeAsString(gpx, flush: true);
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'application/gpx+xml')],
        subject: 'Workout route (GPX)',
      ),
    );
    return true;
  }

  /// Whether a workout has a route to export.
  static bool hasRoute(Map<String, dynamic> data) =>
      GpsRoutePoint.listFrom(data['route']).length >= 2;
}
