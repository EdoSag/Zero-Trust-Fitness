import 'package:flutter_test/flutter_test.dart';
import 'package:zerotrust_fitness/features/import/google_fit_takeout.dart';

import 'support.dart';

const _csv = '﻿Date,Move Minutes count,Calories (kcal),Distance (m),'
    'Heart Points,Heart Minutes,Average heart rate (bpm),Step count,'
    'Average weight (kg),Max weight (kg)\n'
    '2023-05-01,45,2100.5,5200.1,32,30,,8123,71.25,71.3\n'
    '2023-05-02,10,1900,800,0,,,1500,,\n'
    '2023-05-03,,,,,,,,,\n';

const _sessionJson = '''
{
  "fitnessActivity": "running",
  "startTime": "2023-05-01T06:00:00.000Z",
  "endTime": "2023-05-01T06:31:00.000Z",
  "duration": "1860.000s",
  "aggregate": [
    {"metricName": "com.google.calories.expended", "floatValue": 310.2},
    {"metricName": "com.google.distance.delta", "floatValue": 5012.5}
  ]
}''';

const _stillJson = '''
{"fitnessActivity": "still", "startTime": "2023-05-01T09:00:00Z",
 "endTime": "2023-05-01T10:00:00Z"}''';

const _tcx = '''<?xml version="1.0" encoding="UTF-8"?>
<TrainingCenterDatabase>
 <Activities>
  <Activity Sport="Other">
   <Id>2023-05-01T06:00:00.000Z</Id>
   <Lap StartTime="2023-05-01T06:00:00.000Z">
    <TotalTimeSeconds>1860.0</TotalTimeSeconds>
    <DistanceMeters>5012.5</DistanceMeters>
    <Track>
     <Trackpoint><Time>2023-05-01T06:00:00Z</Time><Position><LatitudeDegrees>51.5</LatitudeDegrees><LongitudeDegrees>-0.12</LongitudeDegrees></Position></Trackpoint>
     <Trackpoint><Time>2023-05-01T06:00:05Z</Time><Position><LatitudeDegrees>51.501</LatitudeDegrees><LongitudeDegrees>-0.121</LongitudeDegrees></Position></Trackpoint>
    </Track>
   </Lap>
  </Activity>
 </Activities>
</TrainingCenterDatabase>''';

void main() {
  test('daily metrics CSV: steps, Heart Points and weight per day', () {
    final days = GoogleFitTakeoutParser.parseDailyMetricsCsv(_csv);
    expect(days, {
      '2023-05-01': {'steps': 8123, 'heart_points': 32, 'weight_kg': 71.25},
      '2023-05-02': {'steps': 1500},
    });
  });

  test('session JSON becomes a workout; non-workouts are skipped', () {
    final s = GoogleFitTakeoutParser.parseSessionJson(_sessionJson)!;
    expect(s.activity, 'Running');
    expect(s.duration, const Duration(minutes: 31));
    expect(s.distanceMeters, 5012.5);
    expect(GoogleFitTakeoutParser.parseSessionJson(_stillJson), isNull);
    expect(GoogleFitTakeoutParser.parseSessionJson('not json'), isNull);
  });

  test('TCX takes the activity from the file name and keeps the route', () {
    final s = GoogleFitTakeoutParser.parseTcx(_tcx,
        fileName: 'Takeout/Fit/Activities/2023-05-01T07_00_00+01_00_RUNNING.tcx')!;
    expect(s.activity, 'Running');
    expect(s.distanceMeters, 5012.5);
    expect(s.route, [
      [51.5, -0.12],
      [51.501, -0.121],
    ]);
  });

  test('the same workout from JSON and TCX is one workout, with the route',
      () {
    final t = GoogleFitTakeoutParser.parse({
      'Takeout/Fit/Daily activity metrics/Daily activity metrics.csv': _csv,
      'Takeout/Fit/All Sessions/2023-05-01T06_00_00.000Z_RUNNING.json':
          _sessionJson,
      'Takeout/Fit/All Sessions/2023-05-01T09_00_00.000Z_STILL.json':
          _stillJson,
      'Takeout/Fit/Activities/2023-05-01T07_00_00+01_00_RUNNING.tcx': _tcx,
    });
    expect(t.days, hasLength(2));
    expect(t.sessions, hasLength(1));
    final w = t.sessions.single.toWorkout();
    expect(w['type'], 'Running');
    expect(w['duration'], 31);
    expect(w['source'], 'google_fit');
    expect(w['heart_points'], 0);
    expect(w['route'], hasLength(2));
  });

  test('only Fit files in a zip are read', () {
    expect(
        GoogleFitTakeoutParser.isRelevant(
            'Takeout/Fit/Daily activity metrics/Daily activity metrics.csv'),
        isTrue);
    expect(GoogleFitTakeoutParser.isRelevant('Takeout/Fit/All Sessions/x.json'),
        isTrue);
    expect(GoogleFitTakeoutParser.isRelevant('Takeout/Fit/Activities/a.tcx'),
        isTrue);
    expect(GoogleFitTakeoutParser.isRelevant('Takeout/Mail/All mail.mbox'),
        isFalse);
    expect(
        GoogleFitTakeoutParser.isRelevant(
            'Takeout/Fit/Daily activity metrics/2023-05-01.csv'),
        isFalse);
  });

  test('activity names map onto the app\'s', () {
    String? n(String a) => GoogleFitTakeoutParser.activityName(a);
    expect(n('walking.fitness'), 'Walking');
    expect(n('biking.road'), 'Cycling');
    expect(n('swimming.pool'), 'Swimming');
    expect(n('strength_training'), 'Strength Training');
    expect(n('high_intensity_interval_training'), 'HIIT');
    expect(n('hiking'), 'Hiking');
    expect(n('rowing_machine'), 'Rowing Machine');
    expect(n('in_vehicle'), isNull);
    expect(n('sleep.deep'), isNull);
  });

  test('importing twice adds nothing the second time', () async {
    final v = testVault();
    final t = GoogleFitTakeoutParser.parse({
      'Fit/Daily activity metrics/Daily activity metrics.csv': _csv,
      'Fit/All Sessions/a.json': _sessionJson,
    });
    final first = await importFitTakeout(v, t);
    expect(first.workoutsAdded, 1);
    expect(first.days, 2);
    final second = await importFitTakeout(v, t);
    expect(second.workoutsAdded, 0);
    expect(second.workoutsSkipped, 1);
    expect(await v.fetchWorkouts(), hasLength(1));
    final day = (await v.fetchDailyMetrics())
        .firstWhere((d) => d['date_key'] == '2023-05-01');
    expect(day['steps'], 8123);
    expect(day['heart_points'], 32);
  });
}
