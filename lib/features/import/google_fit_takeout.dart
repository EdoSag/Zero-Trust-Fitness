import 'dart:convert';
import 'dart:math' as math;

import 'package:zerotrust_fitness/core/storage/fitness_vault.dart';

/// A workout found in a Google Fit export.
class FitSession {
  const FitSession({
    required this.start,
    required this.end,
    required this.activity,
    this.distanceMeters,
    this.route = const [],
  });

  final DateTime start;
  final DateTime end;

  /// The app's activity name (Running, Walking, ...).
  final String activity;
  final double? distanceMeters;

  /// `[lat, lng]` pairs, from the TCX files that have a GPS track.
  final List<List<double>> route;

  Duration get duration => end.difference(start);

  /// The same session from the JSON summary and the TCX file share a start
  /// time to the second.
  String get key => '${start.toUtc().millisecondsSinceEpoch ~/ 1000}';

  FitSession mergedWith(FitSession other) => FitSession(
        start: start,
        end: end.isAfter(other.end) ? end : other.end,
        activity: activity == 'Other' ? other.activity : activity,
        distanceMeters: distanceMeters ?? other.distanceMeters,
        route: route.isNotEmpty ? route : other.route,
      );

  Map<String, dynamic> toWorkout() {
    final minutes = math.max(1, (duration.inSeconds / 60).round());
    final distance = distanceMeters;
    return {
      'type': activity,
      'duration': minutes,
      'intensity': defaultIntensity(activity),
      'timestamp': start.toUtc().toIso8601String(),
      'source': 'google_fit',
      // Google Fit's own daily Heart Points come in with the days, so the
      // workout adds none of its own.
      'heart_points': 0,
      if (distance != null && distance > 0) ...{
        'distance_m': distance,
        'avg_pace_min_per_km': (duration.inSeconds / 60) / (distance / 1000),
      },
      if (route.isNotEmpty)
        'route': [
          for (final p in route) {'lat': p[0], 'lng': p[1]},
        ],
    };
  }

  static int defaultIntensity(String activity) => switch (activity) {
        'Running' || 'Cycling' || 'HIIT' || 'Swimming' => 7,
        'Hiking' || 'Strength Training' => 5,
        'Walking' || 'Yoga/Stretching' => 3,
        _ => 5,
      };
}

/// What a Google Fit export holds, parsed.
class FitTakeout {
  FitTakeout({required this.days, required this.sessions});

  /// `yyyy-MM-dd` → metrics in this app's keys (`steps`, `heart_points`,
  /// `weight_kg`).
  final Map<String, Map<String, num>> days;
  final List<FitSession> sessions;

  bool get isEmpty => days.isEmpty && sessions.isEmpty;
}

/// Reads the files of a Google Takeout export of Google Fit:
///
/// * `Fit/Daily activity metrics/Daily activity metrics.csv`: one row per
///   day (steps, Heart Points, weight, ...).
/// * `Fit/All Sessions/*.json`: one file per workout.
/// * `Fit/Activities/*.tcx`: workouts with their GPS track.
///
/// Everything is read on the phone; nothing is sent anywhere.
class GoogleFitTakeoutParser {
  /// Whether a file in the export is one [parse] reads, so a zip's other
  /// products (Photos, Mail, ...) are never even unpacked.
  static bool isRelevant(String path) {
    final p = path.toLowerCase();
    if (p.endsWith('.tcx')) return true;
    if (p.endsWith('.json')) return p.contains('session');
    // The per-day CSVs (one per date, 15-minute rows) aren't needed: the
    // summary has the same totals.
    if (p.endsWith('.csv')) {
      return p.split('/').last.startsWith('daily activity metrics');
    }
    return false;
  }

  /// [files] maps each file's path to its text.
  static FitTakeout parse(Map<String, String> files) {
    final days = <String, Map<String, num>>{};
    final sessions = <String, FitSession>{};

    void addSession(FitSession? s) {
      if (s == null || s.duration.inSeconds < 60) return;
      final existing = sessions[s.key];
      sessions[s.key] = existing == null ? s : existing.mergedWith(s);
    }

    for (final e in files.entries) {
      final path = e.key.toLowerCase();
      if (path.endsWith('.csv')) {
        days.addAll(parseDailyMetricsCsv(e.value));
      } else if (path.endsWith('.json')) {
        addSession(parseSessionJson(e.value));
      } else if (path.endsWith('.tcx')) {
        addSession(parseTcx(e.value, fileName: e.key));
      }
    }
    final list = sessions.values.toList()
      ..sort((a, b) => a.start.compareTo(b.start));
    return FitTakeout(days: days, sessions: list);
  }

  // ---------------------------------------------------------------------------
  // Daily metrics
  // ---------------------------------------------------------------------------

  static Map<String, Map<String, num>> parseDailyMetricsCsv(String csv) {
    final rows = _csvRows(csv);
    if (rows.isEmpty) return const {};
    final header = [for (final h in rows.first) h.trim().toLowerCase()];
    int col(bool Function(String h) test) => header.indexWhere(test);
    final dateCol = col((h) => h == 'date');
    if (dateCol < 0) return const {};
    final columns = <String, int>{
      'steps': col((h) => h.startsWith('step count')),
      'heart_points': col((h) => h.startsWith('heart points')),
      'weight_kg': col((h) => h.startsWith('average weight')),
    }..removeWhere((_, i) => i < 0);

    final days = <String, Map<String, num>>{};
    for (final row in rows.skip(1)) {
      if (row.length <= dateCol) continue;
      final date = DateTime.tryParse(row[dateCol].trim());
      if (date == null) continue;
      final metrics = <String, num>{};
      columns.forEach((key, i) {
        if (i >= row.length) return;
        final v = num.tryParse(row[i].trim());
        if (v == null || !v.isFinite || v <= 0) return;
        metrics[key] = switch (key) {
          'steps' || 'heart_points' => v.round(),
          _ => double.parse(v.toStringAsFixed(2)),
        };
      });
      if (metrics.isNotEmpty) {
        days[FitnessVault.dateKeyOf(DateTime(date.year, date.month, date.day))] =
            metrics;
      }
    }
    return days;
  }

  static List<List<String>> _csvRows(String text) {
    final rows = <List<String>>[];
    for (final line in const LineSplitter().convert(text)) {
      if (line.trim().isEmpty) continue;
      final cells = <String>[];
      final cell = StringBuffer();
      var quoted = false;
      for (var i = 0; i < line.length; i++) {
        final c = line[i];
        if (c == '"') {
          if (quoted && i + 1 < line.length && line[i + 1] == '"') {
            cell.write('"');
            i++;
          } else {
            quoted = !quoted;
          }
        } else if (c == ',' && !quoted) {
          cells.add(cell.toString());
          cell.clear();
        } else {
          cell.write(c);
        }
      }
      cells.add(cell.toString());
      rows.add(cells);
    }
    // A byte-order mark would hide the first header.
    if (rows.isNotEmpty && rows.first.isNotEmpty) {
      rows.first[0] = rows.first[0].replaceFirst('﻿', '');
    }
    return rows;
  }

  // ---------------------------------------------------------------------------
  // Sessions
  // ---------------------------------------------------------------------------

  static FitSession? parseSessionJson(String text) {
    final Object? json;
    try {
      json = jsonDecode(text);
    } on FormatException {
      return null;
    }
    if (json is! Map) return null;
    final start = DateTime.tryParse(json['startTime']?.toString() ?? '');
    final end = DateTime.tryParse(json['endTime']?.toString() ?? '');
    final activity = activityName(json['fitnessActivity']?.toString());
    if (start == null || end == null || activity == null) return null;
    double? distance;
    final aggregate = json['aggregate'];
    if (aggregate is List) {
      for (final a in aggregate) {
        if (a is Map && a['metricName'] == 'com.google.distance.delta') {
          distance = (a['floatValue'] as num?)?.toDouble();
        }
      }
    }
    return FitSession(
      start: start.toUtc(),
      end: end.toUtc(),
      activity: activity,
      distanceMeters: distance,
    );
  }

  static final _sportAttr = RegExp(r'<Activity\s+Sport="([^"]*)"');
  static final _idTag = RegExp(r'<Id>([^<]+)</Id>');
  static final _totalTime =
      RegExp(r'<TotalTimeSeconds>([^<]+)</TotalTimeSeconds>');
  static final _lapDistance = RegExp(
      r'<DistanceMeters>([^<]+)</DistanceMeters>\s*(?:<MaximumSpeed>|<Calories>|<Intensity>|<TriggerMethod>|<Track>|</Lap>)');
  static final _position = RegExp(
      r'<LatitudeDegrees>([^<]+)</LatitudeDegrees>\s*<LongitudeDegrees>([^<]+)</LongitudeDegrees>');

  /// Google names these files `<start>_<ACTIVITY>.tcx`, and often writes
  /// `Sport="Other"` inside, so the file name decides the activity.
  static FitSession? parseTcx(String xml, {String fileName = ''}) {
    final id = _idTag.firstMatch(xml)?.group(1);
    final start = id == null ? null : DateTime.tryParse(id.trim());
    if (start == null) return null;

    var seconds = 0.0;
    for (final m in _totalTime.allMatches(xml)) {
      seconds += double.tryParse(m.group(1)!.trim()) ?? 0;
    }
    double? distance;
    for (final m in _lapDistance.allMatches(xml)) {
      distance = (distance ?? 0) + (double.tryParse(m.group(1)!.trim()) ?? 0);
    }

    final base = fileName.split('/').last.replaceAll(RegExp(r'\.tcx$'), '');
    final fromName = base.contains('_') ? base.split('_').last : null;
    final activity = activityName(fromName) ??
        activityName(_sportAttr.firstMatch(xml)?.group(1)) ??
        'Other';

    final route = <List<double>>[
      for (final m in _position.allMatches(xml))
        if ((double.tryParse(m.group(1)!), double.tryParse(m.group(2)!))
            case (final lat?, final lng?))
          [lat, lng],
    ];
    return FitSession(
      start: start.toUtc(),
      end: start.toUtc().add(Duration(milliseconds: (seconds * 1000).round())),
      activity: activity,
      distanceMeters: distance,
      route: _thin(route, 500),
    );
  }

  /// Keeps at most [max] points, evenly spaced, and always the last.
  static List<List<double>> _thin(List<List<double>> points, int max) {
    if (points.length <= max) return points;
    final step = points.length / max;
    return [
      for (var i = 0; i < max - 1; i++) points[(i * step).floor()],
      points.last,
    ];
  }

  /// This app's activity name for a Google Fit activity, or null for the
  /// ones that aren't workouts (still, in vehicle, sleep, ...).
  static String? activityName(String? fitActivity) {
    if (fitActivity == null) return null;
    final a = fitActivity.trim().toLowerCase().replaceAll(' ', '_');
    if (a.isEmpty) return null;
    const notWorkouts = {
      'still',
      'in_vehicle',
      'sleep',
      'sleep.light',
      'sleep.deep',
      'sleep.rem',
      'sleep.awake',
      'tilting',
      'unknown',
      'on_foot',
    };
    if (notWorkouts.contains(a) || a.startsWith('sleep')) return null;
    if (a.contains('run') || a == 'jogging') return 'Running';
    if (a.contains('hik')) return 'Hiking';
    if (a.contains('walk')) return 'Walking';
    if (a.contains('bik') || a.contains('cycl') || a.contains('spinning')) {
      return 'Cycling';
    }
    if (a.contains('swim')) return 'Swimming';
    if (a.contains('strength') || a.contains('weight') || a == 'crossfit') {
      return 'Strength Training';
    }
    if (a.contains('interval') || a.contains('hiit') || a == 'circuit_training') {
      return 'HIIT';
    }
    if (a.contains('yoga') || a.contains('pilates') || a.contains('stretch')) {
      return 'Yoga/Stretching';
    }
    if (a == 'other') return 'Other';
    // Every other sport (tennis, rowing, dancing, ...) keeps its name.
    return a
        .split(RegExp(r'[_.]'))
        .where((w) => w.isNotEmpty)
        .map((w) => w[0].toUpperCase() + w.substring(1))
        .join(' ');
  }
}

/// How an import went.
class FitImportResult {
  const FitImportResult({
    required this.workoutsAdded,
    required this.workoutsSkipped,
    required this.days,
  });
  final int workoutsAdded;

  /// Already in the vault from an earlier import.
  final int workoutsSkipped;
  final int days;
}

/// Saves a parsed export into the vault. Importing the same export twice
/// adds nothing: each workout's id comes from its start time, and day
/// totals only ever raise a day.
Future<FitImportResult> importFitTakeout(
  FitnessVault vault,
  FitTakeout takeout, {
  void Function(int done, int total)? onProgress,
}) async {
  final total = takeout.sessions.length + takeout.days.length;
  var done = 0;
  var added = 0;
  var skipped = 0;
  for (final s in takeout.sessions) {
    final id = await vault.idFor('workout:google_fit|${s.key}');
    if (await vault.hasItem(id)) {
      skipped++;
    } else {
      await vault.saveWorkout(s.toWorkout(), id: id);
      added++;
    }
    onProgress?.call(++done, total);
  }
  for (final e in takeout.days.entries) {
    await vault.importDayTotals(e.key, e.value);
    onProgress?.call(++done, total);
  }
  return FitImportResult(
    workoutsAdded: added,
    workoutsSkipped: skipped,
    days: takeout.days.length,
  );
}
