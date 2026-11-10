import 'package:flutter_test/flutter_test.dart';
import 'package:zerotrust_fitness/core/storage/fitness_vault.dart';
import 'package:zerotrust_fitness/features/gpx/gpx.dart';
import 'package:zerotrust_fitness/features/gpx/gpx_workouts.dart';
import 'package:zerotrust_fitness/features/health/data/gps_tracking_service.dart';

import 'support.dart';

const _strava = '''<?xml version="1.0" encoding="UTF-8"?>
<gpx creator="StravaGPX" version="1.1" xmlns="http://www.topografix.com/GPX/1/1">
 <metadata><time>2026-11-08T07:00:00Z</time></metadata>
 <trk>
  <name>Morning Run</name>
  <type>running</type>
  <trkseg>
   <trkpt lat="52.5200000" lon="13.4050000"><ele>34.2</ele><time>2026-11-08T07:00:00Z</time></trkpt>
   <trkpt lat="52.5210000" lon="13.4050000"><ele>35.0</ele><time>2026-11-08T07:00:30Z</time></trkpt>
   <trkpt lat="52.5220000" lon="13.4050000"><ele>35.4</ele><time>2026-11-08T07:31:00Z</time></trkpt>
  </trkseg>
 </trk>
</gpx>''';

const _komootRoute = '''<?xml version="1.0"?>
<gpx version="1.1" creator="komoot"><rte><name>Lake loop (hike)</name>
<rtept lat="47.0" lon="8.0"/><rtept lat="47.001" lon="8.0"/><rtept lat="47.002" lon="8.001"/>
</rte></gpx>''';

void main() {
  test('reads a Strava track: name, type, times, elevation, distance', () {
    final t = Gpx.parse(_strava).single;
    expect(t.name, 'Morning Run');
    expect(t.activity, 'Running');
    expect(t.points, hasLength(3));
    expect(t.points.first.elevation, 34.2);
    expect(t.start, DateTime.utc(2026, 11, 8, 7));
    expect(t.duration, const Duration(minutes: 31));
    expect(t.distanceMeters, closeTo(222.4, 1));
  });

  test('reads a route without times and guesses the activity', () {
    final t = Gpx.parse(_komootRoute).single;
    expect(t.start, isNull);
    expect(t.duration, isNull);
    expect(t.activity, 'Hiking');
  });

  test('rejects files that are not GPX', () {
    expect(() => Gpx.parse('not xml at all <'), throwsFormatException);
    expect(() => Gpx.parse('<kml></kml>'), throwsFormatException);
  });

  test('a workout exported to GPX reads back the same', () {
    final data = {
      'type': 'Cycling',
      'timestamp': '2026-11-08T09:00:00.000',
      'route': [
        GpsRoutePoint(
          47.1,
          8.2,
          time: DateTime.utc(2026, 11, 8, 8),
          elevation: 410,
        ).toJson(),
        GpsRoutePoint(
          47.2,
          8.3,
          time: DateTime.utc(2026, 11, 8, 8, 30),
        ).toJson(),
        // Routes from before times were recorded have none.
        {'lat': 47.3, 'lng': 8.4},
      ],
    };
    final back = Gpx.parse(Gpx.encodeWorkout(data)!).single;
    expect(back.activity, 'Cycling');
    expect(back.points.map((p) => p.latitude), [47.1, 47.2, 47.3]);
    expect(back.points.first.elevation, 410);
    expect(back.points[1].time, DateTime.utc(2026, 11, 8, 8, 30));
    expect(back.points.last.time, isNull);
    expect(Gpx.encodeWorkout({'type': 'Yoga'}), isNull);
  });

  test('long tracks are thinned, keeping both ends', () {
    final pts = [for (var i = 0; i < 10000; i++) GpsRoutePoint(i / 1e4, 0)];
    final thin = Gpx.thin(pts, max: 100);
    expect(thin, hasLength(100));
    expect(thin.first, pts.first);
    expect(thin.last, pts.last);
  });

  test('importing the same track twice makes one workout', () async {
    final v = testVault();
    final gpx = GpxWorkouts(v);
    final t = Gpx.parse(_strava).single;
    expect(await gpx.isImported(t), isFalse);
    for (var i = 0; i < 2; i++) {
      await gpx.import(
        t,
        activity: 'Running',
        start: t.start!,
        durationMinutes: 31,
        countHeartPoints: true,
      );
    }
    expect(await gpx.isImported(t), isTrue);
    final workouts = await v.fetchWorkouts();
    expect(workouts, hasLength(1));
    final w = workouts.single.data;
    expect(w['imported_from'], 'gpx');
    expect(w['distance_m'], closeTo(222.4, 1));
    expect((w['route'] as List).first['t'], isA<int>());
    // Counted once on its day, not twice.
    final day = (await v.fetchDailyMetrics()).single;
    expect(day['heart_points'], FitnessVault.workoutHeartPoints(w));
    expect(day['heart_points'], greaterThan(0));
  });

  test('without Heart Points it counts like other imports', () async {
    final v = testVault();
    final t = Gpx.parse(_strava).single;
    await GpxWorkouts(v).import(
      t,
      activity: 'Running',
      start: t.start!,
      durationMinutes: 31,
      countHeartPoints: false,
    );
    final w = (await v.fetchWorkouts()).single.data;
    expect(w['source'], 'gpx');
    expect(FitnessVault.workoutHeartPoints(w), 0);
  });
}
