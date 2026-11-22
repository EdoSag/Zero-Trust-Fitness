import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zerotrust_fitness/features/gpx/gpx_workouts.dart';
import 'package:zerotrust_fitness/features/gpx/workout_files.dart';

import 'support.dart';

/// A Garmin Connect TCX export: two laps, heart rate, calories.
const _garminTcx = '''
  <?xml version="1.0" encoding="UTF-8"?>
<TrainingCenterDatabase xmlns="http://www.garmin.com/xmlschemas/TrainingCenterDatabase/v2" xmlns:ns3="http://www.garmin.com/xmlschemas/ActivityExtension/v2">
 <Activities>
  <Activity Sport="Running">
   <Id>2026-11-08T07:00:00.000Z</Id>
   <Lap StartTime="2026-11-08T07:00:00.000Z">
    <TotalTimeSeconds>600.0</TotalTimeSeconds>
    <DistanceMeters>2000.0</DistanceMeters>
    <MaximumSpeed>4.1</MaximumSpeed>
    <Calories>150</Calories>
    <AverageHeartRateBpm><Value>140</Value></AverageHeartRateBpm>
    <MaximumHeartRateBpm><Value>160</Value></MaximumHeartRateBpm>
    <Track>
     <Trackpoint><Time>2026-11-08T07:00:00.000Z</Time><Position><LatitudeDegrees>52.52</LatitudeDegrees><LongitudeDegrees>13.405</LongitudeDegrees></Position><AltitudeMeters>34.2</AltitudeMeters><HeartRateBpm><Value>120</Value></HeartRateBpm></Trackpoint>
     <Trackpoint><Time>2026-11-08T07:05:00.000Z</Time><Position><LatitudeDegrees>52.53</LatitudeDegrees><LongitudeDegrees>13.405</LongitudeDegrees></Position></Trackpoint>
    </Track>
   </Lap>
   <Lap StartTime="2026-11-08T07:10:00.000Z">
    <TotalTimeSeconds>1200.0</TotalTimeSeconds>
    <DistanceMeters>3000.0</DistanceMeters>
    <Calories>250</Calories>
    <AverageHeartRateBpm><Value>155</Value></AverageHeartRateBpm>
    <MaximumHeartRateBpm><Value>172</Value></MaximumHeartRateBpm>
    <Track>
     <Trackpoint><Time>2026-11-08T07:20:00.000Z</Time><Position><LatitudeDegrees>52.54</LatitudeDegrees><LongitudeDegrees>13.405</LongitudeDegrees></Position></Trackpoint>
     <Trackpoint><Time>2026-11-08T07:30:00.000Z</Time></Trackpoint>
    </Track>
   </Lap>
  </Activity>
 </Activities>
</TrainingCenterDatabase>''';

/// A Polar treadmill run: no positions at all.
const _indoorTcx = '''<?xml version="1.0"?>
<TrainingCenterDatabase xmlns="http://www.garmin.com/xmlschemas/TrainingCenterDatabase/v2">
 <Activities><Activity Sport="Other"><Id>2026-11-09T18:00:00Z</Id>
  <Lap StartTime="2026-11-09T18:00:00Z"><TotalTimeSeconds>1800</TotalTimeSeconds>
   <Track><Trackpoint><Time>2026-11-09T18:00:00Z</Time><HeartRateBpm><Value>100</Value></HeartRateBpm></Trackpoint>
   <Trackpoint><Time>2026-11-09T18:30:00Z</Time><HeartRateBpm><Value>130</Value></HeartRateBpm></Trackpoint></Track>
  </Lap></Activity></Activities>
</TrainingCenterDatabase>''';

/// Writes small FIT files the way a watch does: definition messages, then
/// data messages, little- or big-endian, with compressed timestamps and
/// developer fields where asked.
class _FitWriter {
  final _body = BytesBuilder();

  static int fitTime(DateTime t) =>
      t.toUtc().difference(DateTime.utc(1989, 12, 31)).inSeconds;

  /// [fields]: (field number, size, base type).
  void define(
    int local,
    int global,
    List<(int, int, int)> fields, {
    bool bigEndian = false,
    int devFieldBytes = 0,
  }) {
    _body.addByte(0x40 | (devFieldBytes > 0 ? 0x20 : 0) | local);
    _body.addByte(0);
    _body.addByte(bigEndian ? 1 : 0);
    final g = ByteData(2)
      ..setUint16(0, global, bigEndian ? Endian.big : Endian.little);
    _body.add(g.buffer.asUint8List());
    _body.addByte(fields.length);
    for (final (n, size, type) in fields) {
      _body.add([n, size, type]);
    }
    if (devFieldBytes > 0) _body.add([1, 0, devFieldBytes, 0]);
  }

  /// [values] in the order defined; sizes 1, 2 or 4.
  void data(
    int local,
    List<(int size, int value)> values, {
    bool bigEndian = false,
    int? compressedOffset,
    List<int> dev = const [],
  }) {
    _body.addByte(
      compressedOffset == null
          ? local
          : 0x80 | (local << 5) | (compressedOffset & 0x1F),
    );
    final e = bigEndian ? Endian.big : Endian.little;
    for (final (size, value) in values) {
      final b = ByteData(size);
      switch (size) {
        case 1:
          b.setUint8(0, value & 0xFF);
        case 2:
          b.setUint16(0, value & 0xFFFF, e);
        default:
          b.setUint32(0, value & 0xFFFFFFFF, e);
      }
      _body.add(b.buffer.asUint8List());
    }
    _body.add(dev);
  }

  Uint8List build() {
    final body = _body.toBytes();
    final header = ByteData(14)
      ..setUint8(0, 14)
      ..setUint8(1, 0x20)
      ..setUint16(2, 2132, Endian.little)
      ..setUint32(4, body.length, Endian.little);
    final bytes = BytesBuilder()
      ..add(header.buffer.asUint8List(0, 8))
      ..add(ascii.encode('.FIT'))
      ..add([0, 0])
      ..add(body)
      ..add([0, 0]); // CRC, not checked
    return bytes.toBytes();
  }
}

int _semicircles(double degrees) => (degrees * 2147483648 / 180).round();

/// A 30-minute ride with three GPS records (one with a compressed
/// timestamp), heart rate and a session summary.
Uint8List _rideFit() {
  final start = DateTime.utc(2026, 11, 10, 6, 0);
  final w = _FitWriter();
  // file_id: type = activity
  w.define(0, 0, [(0, 1, 0)]);
  w.data(0, [(1, 4)]);
  // record: timestamp, lat, long, enhanced_altitude, heart_rate, distance;
  // with a developer field (power from a Connect IQ app) to skip.
  w.define(1, 20, [
    (253, 4, 0x86),
    (0, 4, 0x85),
    (1, 4, 0x85),
    (78, 4, 0x86),
    (3, 1, 2),
    (5, 4, 0x86),
  ], devFieldBytes: 2);
  w.data(
    1,
    [
      (4, _FitWriter.fitTime(start)),
      (4, _semicircles(47.1)),
      (4, _semicircles(8.2)),
      (4, (410 + 500) * 5),
      (1, 110),
      (4, 0),
    ],
    dev: [0x10, 0x01],
  );
  w.data(
    1,
    [
      (4, _FitWriter.fitTime(start.add(const Duration(minutes: 15)))),
      (4, _semicircles(47.2)),
      (4, _semicircles(8.3)),
      (4, 0xFFFFFFFF), // no altitude
      (1, 150),
      (4, 600000),
    ],
    dev: [0x10, 0x01],
  );
  // record with a compressed timestamp header: no timestamp field.
  w.define(2, 20, [(0, 4, 0x85), (1, 4, 0x85), (3, 1, 2)]);
  final last = _FitWriter.fitTime(start.add(const Duration(minutes: 15))) + 20;
  w.data(2, [
    (4, _semicircles(47.3)),
    (4, _semicircles(8.4)),
    (1, 0xFF), // no heart rate
  ], compressedOffset: last & 0x1F);
  // session, big-endian: timestamp, start_time, sport, sub_sport,
  // total_elapsed_time, total_timer_time, total_distance, total_calories,
  // avg_heart_rate, max_heart_rate.
  w.define(3, 18, [
    (253, 4, 0x86),
    (2, 4, 0x86),
    (5, 1, 0),
    (6, 1, 0),
    (7, 4, 0x86),
    (8, 4, 0x86),
    (9, 4, 0x86),
    (11, 2, 0x84),
    (16, 1, 2),
    (17, 1, 2),
  ], bigEndian: true);
  w.data(3, [
    (4, _FitWriter.fitTime(start.add(const Duration(minutes: 32)))),
    (4, _FitWriter.fitTime(start)),
    (1, 2), // cycling
    (1, 7), // road
    (4, 1920000), // 32 min elapsed
    (4, 1800000), // 30 min moving
    (4, 1234500), // 12.345 km
    (2, 420),
    (1, 131),
    (1, 168),
  ], bigEndian: true);
  return w.build();
}

/// A strength session from a watch: a session, no records with positions.
Uint8List _strengthFit() {
  final start = DateTime.utc(2026, 11, 11, 17, 0);
  final w = _FitWriter();
  w.define(0, 18, [(2, 4, 0x86), (5, 1, 0), (6, 1, 0), (8, 4, 0x86)]);
  w.data(0, [
    (4, _FitWriter.fitTime(start)),
    (1, 10), // training
    (1, 20), // strength training
    (4, 2700000),
  ]);
  return w.build();
}

void main() {
  test('reads a Garmin TCX: laps add up, heart rate is time-weighted', () {
    final t = WorkoutFiles.parse(utf8.encode(_garminTcx)).single;
    expect(t.format, 'tcx');
    expect(t.activity, 'Running');
    expect(t.start, DateTime.utc(2026, 11, 8, 7));
    expect(t.duration, const Duration(minutes: 30));
    expect(t.distanceMeters, 5000);
    expect(t.calories, 400);
    // (140 * 600 + 155 * 1200) / 1800
    expect(t.avgHeartRate, 150);
    expect(t.maxHeartRate, 172);
    expect(t.points, hasLength(3));
    expect(t.points.first.elevation, 34.2);
    expect(t.hasRoute, isTrue);
  });

  test('an indoor TCX has no route but keeps time and heart rate', () {
    final t = WorkoutFiles.parse(utf8.encode(_indoorTcx)).single;
    expect(t.hasRoute, isFalse);
    expect(t.activity, isNull);
    expect(t.duration, const Duration(minutes: 30));
    expect(t.avgHeartRate, 115);
    expect(t.maxHeartRate, 130);
    expect(t.distanceMeters, 0);
  });

  test('reads a FIT ride: session summary, route, both byte orders', () {
    final t = WorkoutFiles.parse(_rideFit()).single;
    expect(t.format, 'fit');
    expect(t.activity, 'Cycling');
    expect(t.start, DateTime.utc(2026, 11, 10, 6));
    // Moving time, not elapsed.
    expect(t.duration, const Duration(minutes: 30));
    expect(t.distanceMeters, closeTo(12345, 0.01));
    expect(t.calories, 420);
    expect(t.avgHeartRate, 131);
    expect(t.maxHeartRate, 168);
    expect(t.points, hasLength(3));
    expect(t.points.first.latitude, closeTo(47.1, 1e-6));
    expect(t.points.first.longitude, closeTo(8.2, 1e-6));
    expect(t.points.first.elevation, closeTo(410, 1e-6));
    expect(t.points[1].elevation, isNull);
    // The compressed timestamp rolls forward from the last full one.
    expect(t.points.last.time, DateTime.utc(2026, 11, 10, 6, 15, 20));
  });

  test('a FIT strength session without GPS still imports', () {
    final t = WorkoutFiles.parse(_strengthFit()).single;
    expect(t.activity, 'Strength Training');
    expect(t.hasRoute, isFalse);
    expect(t.duration, const Duration(minutes: 45));
    expect(t.start, DateTime.utc(2026, 11, 11, 17));
  });

  test('gzipped files (Strava bulk export) read the same', () {
    final gz = Uint8List.fromList(const GZipEncoder().encode(_rideFit()));
    expect(WorkoutFiles.parse(gz).single.distanceMeters, closeTo(12345, 0.01));
    final gpx = Uint8List.fromList(
      const GZipEncoder().encode(
        utf8.encode(
          '<gpx version="1.1"><trk><trkseg>'
          '<trkpt lat="1" lon="1"/><trkpt lat="1.001" lon="1"/>'
          '</trkseg></trk></gpx>',
        ),
      ),
    );
    expect(WorkoutFiles.parse(gpx).single.format, 'gpx');
  });

  test('a FIT file cut short keeps what was read', () {
    final full = _rideFit();
    final cut = Uint8List.sublistView(full, 0, full.length - 30);
    final t = WorkoutFiles.parse(cut).single;
    expect(t.points.length, greaterThanOrEqualTo(2));
  });

  test('rejects files that are none of these', () {
    expect(
      () => WorkoutFiles.parse(utf8.encode('hello')),
      throwsFormatException,
    );
    expect(
      () => WorkoutFiles.parse(utf8.encode('<kml></kml>')),
      throwsFormatException,
    );
    expect(
      () => WorkoutFiles.parse(Uint8List.fromList([0x1f, 0x8b, 1, 2, 3])),
      throwsFormatException,
    );
  });

  test('FIT sports map to this app\'s activities', () {
    expect(FitFile.sportName(1, 0), 'Running');
    expect(FitFile.sportName(4, 1), 'Running'); // treadmill
    expect(FitFile.sportName(2, 6), 'Cycling'); // indoor cycling
    expect(FitFile.sportName(5, 17), 'Swimming');
    expect(FitFile.sportName(10, 43), 'Yoga/Stretching');
    expect(FitFile.sportName(17, null), 'Hiking');
    expect(FitFile.sportName(15, null), isNull); // rowing: person picks
  });

  test('importing a FIT keeps heart rate and calories, once', () async {
    final v = testVault();
    final files = GpxWorkouts(v);
    final t = WorkoutFiles.parse(_rideFit()).single;
    for (var i = 0; i < 2; i++) {
      await files.import(
        t,
        activity: 'Cycling',
        start: t.start!,
        durationMinutes: t.duration!.inMinutes,
        countHeartPoints: true,
      );
    }
    final w = (await v.fetchWorkouts()).single.data;
    expect(w['imported_from'], 'fit');
    expect(w['source'], isNull);
    expect(w['avg_hr'], 131);
    expect(w['max_hr'], 168);
    expect(w['calories'], 420);
    expect(w['distance_m'], closeTo(12345, 0.1));
    expect(w['route'], hasLength(3));
  });

  test('the TCX and FIT export of one workout make one workout', () async {
    final v = testVault();
    final files = GpxWorkouts(v);
    final fit = WorkoutFiles.parse(_rideFit()).single;
    // The same ride exported as TCX.
    final tcx = WorkoutFiles.parse(
      utf8.encode(
        '<TrainingCenterDatabase><Activities><Activity Sport="Biking">'
        '<Id>2026-11-10T06:00:00Z</Id><Lap><TotalTimeSeconds>1800'
        '</TotalTimeSeconds></Lap></Activity></Activities>'
        '</TrainingCenterDatabase>',
      ),
    ).single;
    expect(await files.idFor(tcx), await files.idFor(fit));
    expect(tcx.activity, 'Cycling');
  });

  test('an indoor workout imports without a route', () async {
    final v = testVault();
    final t = WorkoutFiles.parse(_strengthFit()).single;
    await GpxWorkouts(v).import(
      t,
      activity: 'Strength Training',
      start: t.start!,
      durationMinutes: 45,
      countHeartPoints: false,
    );
    final w = (await v.fetchWorkouts()).single.data;
    expect(w.containsKey('route'), isFalse);
    expect(w['source'], 'fit');
    expect(w['duration'], 45);
  });
}
