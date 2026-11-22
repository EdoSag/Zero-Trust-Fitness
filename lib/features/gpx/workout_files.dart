import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';
import 'package:zerotrust_fitness/features/gpx/gpx.dart';
import 'package:zerotrust_fitness/features/health/data/gps_tracking_service.dart';

/// Reads the workout files sports watches, bike computers and apps export:
/// GPX (Strava, Komoot), TCX (Garmin Connect, Polar Flow) and FIT (Garmin,
/// Coros, Wahoo, Suunto), each also gzipped (`.fit.gz`, as in a Strava bulk
/// export). Everything is read on the phone.
class WorkoutFiles {
  /// The extensions the import screen mentions.
  static const extensions = ['gpx', 'tcx', 'fit'];

  /// Every workout in [bytes]. The format is told from the content, not the
  /// name, so a renamed file still reads. Throws [FormatException] when it
  /// isn't one of these formats.
  static List<GpxTrack> parse(Uint8List bytes) {
    if (_isGzip(bytes)) {
      final List<int> inflated;
      try {
        inflated = const GZipDecoder().decodeBytes(bytes);
      } catch (_) {
        throw const FormatException('Damaged .gz file');
      }
      return parse(Uint8List.fromList(inflated));
    }
    if (FitFile.looksLikeFit(bytes)) return FitFile.parse(bytes);
    var text = utf8.decode(bytes, allowMalformed: true);
    if (text.startsWith('﻿')) text = text.substring(1);
    final start = text.trimLeft();
    if (!start.startsWith('<')) {
      throw const FormatException('Not a GPX, TCX or FIT file');
    }
    // Watch exports often have spaces before the XML declaration, which the
    // parser refuses.
    if (start.contains('<TrainingCenterDatabase')) return Tcx.parse(start);
    return Gpx.parse(start);
  }

  static bool _isGzip(Uint8List b) =>
      b.length > 2 && b[0] == 0x1f && b[1] == 0x8b;
}

/// Garmin's Training Center XML: activities made of laps, each with a
/// summary and its track points, and courses (planned routes).
class Tcx {
  static List<GpxTrack> parse(String source) {
    final XmlDocument doc;
    try {
      doc = XmlDocument.parse(source);
    } on XmlException catch (e) {
      throw FormatException('Not a TCX file: ${e.message}');
    }
    final root = doc.rootElement;
    if (root.localName != 'TrainingCenterDatabase') {
      throw const FormatException('Not a TCX file');
    }
    final tracks = <GpxTrack>[];
    for (final activity in root.findAllElements(
      'Activity',
      namespaceUri: '*',
    )) {
      final laps = activity.findElements('Lap', namespaceUri: '*').toList();
      final points = <GpsRoutePoint>[];
      final heartRates = <int>[];
      var seconds = 0.0, meters = 0.0, calories = 0;
      var weightedHr = 0.0, hrSeconds = 0.0;
      int? maxHr;
      DateTime? lapStart;
      for (final lap in laps) {
        lapStart ??= DateTime.tryParse(lap.getAttribute('StartTime') ?? '');
        final lapSeconds = _num(lap, 'TotalTimeSeconds') ?? 0;
        seconds += lapSeconds;
        meters += _num(lap, 'DistanceMeters') ?? 0;
        calories += (_num(lap, 'Calories') ?? 0).round();
        final avg = _bpm(lap, 'AverageHeartRateBpm');
        if (avg != null && lapSeconds > 0) {
          weightedHr += avg * lapSeconds;
          hrSeconds += lapSeconds;
        }
        final max = _bpm(lap, 'MaximumHeartRateBpm');
        if (max != null && (maxHr == null || max > maxHr)) maxHr = max;
        for (final tp in lap.findAllElements('Trackpoint', namespaceUri: '*')) {
          if (_bpm(tp, 'HeartRateBpm') case final hr?) heartRates.add(hr);
          if (_trackpoint(tp) case final p?) points.add(p);
        }
      }
      final start = (DateTime.tryParse(_text(activity, 'Id') ?? '') ?? lapStart)
          ?.toUtc();
      final avgHr = hrSeconds > 0
          ? (weightedHr / hrSeconds).round()
          : _average(heartRates);
      maxHr ??= heartRates.isEmpty ? null : heartRates.reduce(math.max);
      if (points.length < 2 && seconds <= 0) continue;
      tracks.add(
        GpxTrack(
          name: _text(activity, 'Notes'),
          type: activity.getAttribute('Sport'),
          points: points,
          format: 'tcx',
          startTime: start,
          recordedDuration: seconds > 0
              ? Duration(milliseconds: (seconds * 1000).round())
              : null,
          recordedDistanceMeters: meters > 0 ? meters : null,
          avgHeartRate: avgHr,
          maxHeartRate: maxHr,
          calories: calories > 0 ? calories : null,
        ),
      );
    }
    for (final course in root.findAllElements('Course', namespaceUri: '*')) {
      final points = [
        for (final tp in course.findAllElements(
          'Trackpoint',
          namespaceUri: '*',
        ))
          ?_trackpoint(tp),
      ];
      if (points.length < 2) continue;
      tracks.add(
        GpxTrack(name: _text(course, 'Name'), points: points, format: 'tcx'),
      );
    }
    return tracks;
  }

  static GpsRoutePoint? _trackpoint(XmlElement tp) {
    final pos = tp.findElements('Position', namespaceUri: '*').firstOrNull;
    if (pos == null) return null;
    final lat = _num(pos, 'LatitudeDegrees');
    final lon = _num(pos, 'LongitudeDegrees');
    if (lat == null || lon == null || lat.abs() > 90 || lon.abs() > 180) {
      return null;
    }
    return GpsRoutePoint(
      lat,
      lon,
      time: DateTime.tryParse(_text(tp, 'Time') ?? '')?.toUtc(),
      elevation: _num(tp, 'AltitudeMeters'),
    );
  }

  static String? _text(XmlElement parent, String name) {
    final text = parent
        .findElements(name, namespaceUri: '*')
        .firstOrNull
        ?.innerText
        .trim();
    return text == null || text.isEmpty ? null : text;
  }

  static double? _num(XmlElement parent, String name) =>
      double.tryParse(_text(parent, name) ?? '');

  /// `<AverageHeartRateBpm><Value>142</Value></AverageHeartRateBpm>`.
  static int? _bpm(XmlElement parent, String name) {
    final e = parent.findElements(name, namespaceUri: '*').firstOrNull;
    if (e == null) return null;
    final v = _num(e, 'Value');
    return v == null || v <= 0 ? null : v.round();
  }
}

int? _average(List<int> values) => values.isEmpty
    ? null
    : (values.reduce((a, b) => a + b) / values.length).round();

/// The binary FIT format of Garmin and most other sports watches and bike
/// computers. Only what a workout needs is read: sessions (sport, start,
/// time, distance, heart rate, calories) and records (the route).
class FitFile {
  /// FIT times count seconds from 1989-12-31 00:00 UTC.
  static final fitEpoch = DateTime.utc(1989, 12, 31);

  static bool looksLikeFit(List<int> b, [int at = 0]) =>
      b.length >= at + 12 &&
      b[at + 8] == 0x2E && // .
      b[at + 9] == 0x46 && // F
      b[at + 10] == 0x49 && // I
      b[at + 11] == 0x54; // T

  static const _fileId = 0, _session = 18, _record = 20, _sport = 12;
  static const _timestamp = 253;

  static List<GpxTrack> parse(Uint8List bytes) {
    if (!looksLikeFit(bytes)) throw const FormatException('Not a FIT file');
    final messages = <_FitMessage>[];
    try {
      _decode(bytes, messages);
    } on RangeError {
      // A file cut short (the watch was switched off mid-write) keeps
      // whatever was read before the cut.
      if (messages.isEmpty) throw const FormatException('Damaged FIT file');
    }
    final sessions = [
      for (final m in messages)
        if (m.global == _session) m,
    ];
    final records = [
      for (final m in messages)
        if (m.global == _record && m.time != null) m,
    ];
    final sportMessage = messages.where((m) => m.global == _sport).firstOrNull;
    final fileType = messages
        .where((m) => m.global == _fileId)
        .firstOrNull
        ?.values[0];
    final tracks = <GpxTrack>[];
    if (sessions.isEmpty) {
      // Courses and some older devices have records only.
      final track = _track(
        records,
        sport: sportMessage?.values[0]?.toInt(),
        subSport: sportMessage?.values[1]?.toInt(),
        isCourse: fileType == 6,
      );
      if (track != null) tracks.add(track);
      return tracks;
    }
    for (final s in sessions) {
      final v = s.values;
      final elapsed = v[7] == null ? null : v[7]! / 1000;
      final timer = v[8] == null ? null : v[8]! / 1000;
      // A session's own timestamp is when it ended.
      final start =
          _time(v[2]) ??
          _time(v[_timestamp])?.subtract(
            Duration(milliseconds: ((elapsed ?? timer ?? 0) * 1000).round()),
          );
      final end = start?.add(
        Duration(milliseconds: ((elapsed ?? timer ?? 0) * 1000).round()),
      );
      final inSession = start == null || end == null || end == start
          ? records
          : [
              for (final r in records)
                if (!r.time!.isBefore(start) &&
                    !r.time!.isAfter(end.add(const Duration(seconds: 1))))
                  r,
            ];
      final track = _track(
        inSession,
        sport: v[5]?.toInt() ?? sportMessage?.values[0]?.toInt(),
        subSport: v[6]?.toInt() ?? sportMessage?.values[1]?.toInt(),
        start: start,
        seconds: timer ?? elapsed,
        meters: v[9] == null ? null : v[9]! / 100,
        avgHr: v[16]?.toInt(),
        maxHr: v[17]?.toInt(),
        calories: v[11]?.toInt(),
      );
      if (track != null) tracks.add(track);
    }
    return tracks;
  }

  static GpxTrack? _track(
    List<_FitMessage> records, {
    int? sport,
    int? subSport,
    DateTime? start,
    double? seconds,
    double? meters,
    int? avgHr,
    int? maxHr,
    int? calories,
    bool isCourse = false,
  }) {
    final points = <GpsRoutePoint>[];
    final heartRates = <int>[];
    double? lastDistance;
    for (final r in records) {
      final v = r.values;
      if (v[3] case final hr? when hr > 0) heartRates.add(hr.toInt());
      if (v[5] case final d?) lastDistance = d / 100;
      final lat = v[0], lon = v[1];
      if (lat == null || lon == null) continue;
      final altitude = v[78] ?? v[2];
      points.add(
        GpsRoutePoint(
          lat * 180 / 2147483648,
          lon * 180 / 2147483648,
          time: r.time,
          elevation: altitude == null ? null : altitude / 5 - 500,
        ),
      );
    }
    final first = records.firstOrNull?.time, last = records.lastOrNull?.time;
    seconds ??= first != null && last != null
        ? last.difference(first).inSeconds.toDouble()
        : null;
    if (points.length < 2 && (seconds == null || seconds <= 0)) return null;
    return GpxTrack(
      type: isCourse ? null : sportName(sport, subSport),
      points: points,
      format: 'fit',
      startTime: isCourse ? null : start ?? first,
      recordedDuration: isCourse || seconds == null || seconds <= 0
          ? null
          : Duration(milliseconds: (seconds * 1000).round()),
      recordedDistanceMeters: meters ?? lastDistance,
      avgHeartRate: avgHr ?? _average(heartRates),
      maxHeartRate:
          maxHr ?? (heartRates.isEmpty ? null : heartRates.reduce(math.max)),
      calories: calories == null || calories <= 0 ? null : calories,
    );
  }

  /// This app's activity for FIT's `sport` and `sub_sport` numbers, or null
  /// when there is no match (the person picks one).
  static String? sportName(int? sport, int? subSport) {
    switch (subSport) {
      case 1 || 45: // treadmill, indoor running
        return 'Running';
      case 6: // indoor cycling
        return 'Cycling';
      case 27: // indoor walking
        return 'Walking';
      case 20: // strength training
        return 'Strength Training';
      case 19 || 43 || 44: // flexibility, yoga, pilates
        return 'Yoga/Stretching';
    }
    return switch (sport) {
      1 => 'Running',
      2 => 'Cycling',
      5 => 'Swimming',
      11 => 'Walking',
      17 => 'Hiking',
      62 => 'HIIT',
      _ => null,
    };
  }

  static DateTime? _time(num? seconds) =>
      seconds == null ? null : fitEpoch.add(Duration(seconds: seconds.toInt()));

  static void _decode(Uint8List bytes, List<_FitMessage> out) {
    final data = ByteData.sublistView(bytes);
    var offset = 0;
    // A file can hold several FIT files back to back (chained).
    while (looksLikeFit(bytes, offset)) {
      final headerSize = bytes[offset];
      final dataSize = data.getUint32(offset + 4, Endian.little);
      var pos = offset + headerSize;
      final end = math.min(pos + dataSize, bytes.length);
      final definitions = <int, _FitDefinition>{};
      var lastTimestamp = 0;
      while (pos < end) {
        final header = bytes[pos++];
        final int local;
        int? compressedTime;
        if (header & 0x80 != 0) {
          // Compressed timestamp header: a data message whose time is the
          // last full timestamp plus a 5-bit offset.
          local = (header >> 5) & 0x03;
          final offsetT = header & 0x1F;
          compressedTime =
              lastTimestamp + ((offsetT - (lastTimestamp & 0x1F)) & 0x1F);
          lastTimestamp = compressedTime;
        } else if (header & 0x40 != 0) {
          local = header & 0x0F;
          final hasDevFields = header & 0x20 != 0;
          pos++; // reserved
          final bigEndian = bytes[pos++] == 1;
          final global = data.getUint16(
            pos,
            bigEndian ? Endian.big : Endian.little,
          );
          pos += 2;
          final count = bytes[pos++];
          final fields = <_FitField>[];
          for (var i = 0; i < count; i++) {
            fields.add(_FitField(bytes[pos], bytes[pos + 1], bytes[pos + 2]));
            pos += 3;
          }
          var devSize = 0;
          if (hasDevFields) {
            final devCount = bytes[pos++];
            for (var i = 0; i < devCount; i++) {
              devSize += bytes[pos + 1];
              pos += 3;
            }
          }
          definitions[local] = _FitDefinition(
            global,
            bigEndian,
            fields,
            devSize,
          );
          continue;
        } else {
          local = header & 0x0F;
        }
        final def = definitions[local];
        if (def == null) {
          throw const FormatException('FIT data before its definition');
        }
        final values = <int, num?>{};
        for (final f in def.fields) {
          if (pos + f.size > bytes.length) throw RangeError('FIT cut short');
          values[f.number] = _read(data, pos, f, def.bigEndian);
          pos += f.size;
        }
        pos += def.devSize;
        if (values[_timestamp] case final t?) {
          lastTimestamp = t.toInt();
        } else if (compressedTime != null) {
          values[_timestamp] = compressedTime;
        }
        if (def.global == _fileId ||
            def.global == _session ||
            def.global == _record ||
            def.global == _sport) {
          out.add(_FitMessage(def.global, values));
        }
      }
      offset = end + 2; // CRC
    }
  }

  /// One value, or null when the field holds FIT's "invalid" marker or a
  /// type this reader skips (strings, 64-bit numbers). Arrays give their
  /// first element.
  static num? _read(ByteData data, int pos, _FitField f, bool bigEndian) {
    final e = bigEndian ? Endian.big : Endian.little;
    switch (f.baseType & 0x1F) {
      case 0 || 2 || 10 || 13: // enum, uint8, uint8z, byte
        final v = data.getUint8(pos);
        return v == 0xFF || (f.baseType & 0x1F == 10 && v == 0) ? null : v;
      case 1: // sint8
        final v = data.getInt8(pos);
        return v == 0x7F ? null : v;
      case 3 when f.size >= 2: // sint16
        final v = data.getInt16(pos, e);
        return v == 0x7FFF ? null : v;
      case 4 || 11 when f.size >= 2: // uint16, uint16z
        final v = data.getUint16(pos, e);
        return v == 0xFFFF || (f.baseType & 0x1F == 11 && v == 0) ? null : v;
      case 5 when f.size >= 4: // sint32
        final v = data.getInt32(pos, e);
        return v == 0x7FFFFFFF ? null : v;
      case 6 || 12 when f.size >= 4: // uint32, uint32z
        final v = data.getUint32(pos, e);
        return v == 0xFFFFFFFF || (f.baseType & 0x1F == 12 && v == 0)
            ? null
            : v;
      case 8 when f.size >= 4: // float32
        final v = data.getFloat32(pos, e);
        return v.isFinite ? v : null;
      case 9 when f.size >= 8: // float64
        final v = data.getFloat64(pos, e);
        return v.isFinite ? v : null;
      default:
        return null;
    }
  }
}

class _FitField {
  const _FitField(this.number, this.size, this.baseType);
  final int number;
  final int size;
  final int baseType;
}

class _FitDefinition {
  const _FitDefinition(this.global, this.bigEndian, this.fields, this.devSize);
  final int global;
  final bool bigEndian;
  final List<_FitField> fields;
  final int devSize;
}

class _FitMessage {
  _FitMessage(this.global, this.values);
  final int global;
  final Map<int, num?> values;

  DateTime? get time => FitFile._time(values[FitFile._timestamp]);
}
