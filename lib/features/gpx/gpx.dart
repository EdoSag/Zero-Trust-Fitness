import 'dart:math' as math;

import 'package:xml/xml.dart';
import 'package:zerotrust_fitness/features/health/data/gps_tracking_service.dart';

/// One track (or route) read from a GPX file.
class GpxTrack {
  const GpxTrack({this.name, this.type, required this.points});

  final String? name;

  /// The `<type>` the recording app wrote (`running`, `cycling`, ...).
  final String? type;
  final List<GpsRoutePoint> points;

  /// Set when the points carry times.
  DateTime? get start =>
      points.map((p) => p.time).whereType<DateTime>().firstOrNull;
  DateTime? get end =>
      points.map((p) => p.time).whereType<DateTime>().lastOrNull;

  Duration? get duration {
    final s = start, e = end;
    if (s == null || e == null || !e.isAfter(s)) return null;
    return e.difference(s);
  }

  double get distanceMeters => Gpx.distanceMeters(points);

  /// This app's activity name for [type] and [name]: Running, Cycling,
  /// Hiking or Walking, or null when neither says.
  String? get activity => Gpx.activityFor('${type ?? ''} ${name ?? ''}');
}

/// GPX 1.1 files: the format Strava, Komoot, Garmin and most map apps read
/// and write.
class Gpx {
  static const namespace = 'http://www.topografix.com/GPX/1/1';

  /// The most route points a workout keeps; longer tracks are thinned
  /// evenly (start and end kept), so one workout stays a small item.
  static const maxStoredPoints = 3000;

  /// Reads every track (`trk`) and route (`rte`) with at least two points.
  /// Throws [FormatException] when the file isn't GPX.
  static List<GpxTrack> parse(String source) {
    final XmlDocument doc;
    try {
      doc = XmlDocument.parse(source);
    } on XmlException catch (e) {
      throw FormatException('Not a GPX file: ${e.message}');
    }
    final root = doc.rootElement;
    if (root.localName != 'gpx') {
      throw const FormatException('Not a GPX file');
    }
    final tracks = <GpxTrack>[];
    for (final trk in root.findElements('trk', namespaceUri: '*')) {
      final points = [
        for (final seg in trk.findElements('trkseg', namespaceUri: '*'))
          for (final pt in seg.findElements('trkpt', namespaceUri: '*'))
            ?_point(pt),
      ];
      if (points.length >= 2) {
        tracks.add(
          GpxTrack(
            name: _text(trk, 'name'),
            type: _text(trk, 'type'),
            points: points,
          ),
        );
      }
    }
    for (final rte in root.findElements('rte', namespaceUri: '*')) {
      final points = [
        for (final pt in rte.findElements('rtept', namespaceUri: '*'))
          ?_point(pt),
      ];
      if (points.length >= 2) {
        tracks.add(
          GpxTrack(
            name: _text(rte, 'name'),
            type: _text(rte, 'type'),
            points: points,
          ),
        );
      }
    }
    return tracks;
  }

  static String? _text(XmlElement parent, String name) {
    final text = parent
        .findElements(name, namespaceUri: '*')
        .firstOrNull
        ?.innerText
        .trim();
    return text == null || text.isEmpty ? null : text;
  }

  static GpsRoutePoint? _point(XmlElement e) {
    final lat = double.tryParse(e.getAttribute('lat') ?? '');
    final lon = double.tryParse(e.getAttribute('lon') ?? '');
    if (lat == null || lon == null) return null;
    if (lat.abs() > 90 || lon.abs() > 180) return null;
    final time = DateTime.tryParse(_text(e, 'time') ?? '')?.toUtc();
    final ele = double.tryParse(_text(e, 'ele') ?? '');
    return GpsRoutePoint(lat, lon, time: time, elevation: ele);
  }

  /// A GPX 1.1 file for one workout, with times and elevation where the
  /// recording has them.
  static String encode({
    required List<GpsRoutePoint> points,
    String? name,
    String? activity,
    DateTime? start,
  }) {
    final b = XmlBuilder();
    b.processing('xml', 'version="1.0" encoding="UTF-8"');
    b.element(
      'gpx',
      nest: () {
        b.attribute('version', '1.1');
        b.attribute('creator', 'Zero-Trust Fitness');
        b.attribute('xmlns', namespace);
        b.element(
          'metadata',
          nest: () {
            if (name != null) b.element('name', nest: name);
            if (start != null) {
              b.element('time', nest: start.toUtc().toIso8601String());
            }
          },
        );
        b.element(
          'trk',
          nest: () {
            if (name != null) b.element('name', nest: name);
            if (activity != null)
              b.element('type', nest: activity.toLowerCase());
            b.element(
              'trkseg',
              nest: () {
                for (final p in points) {
                  b.element(
                    'trkpt',
                    nest: () {
                      b.attribute('lat', p.latitude.toStringAsFixed(7));
                      b.attribute('lon', p.longitude.toStringAsFixed(7));
                      if (p.elevation != null) {
                        b.element('ele', nest: p.elevation!.toStringAsFixed(1));
                      }
                      if (p.time != null) {
                        b.element(
                          'time',
                          nest: p.time!.toUtc().toIso8601String(),
                        );
                      }
                    },
                  );
                }
              },
            );
          },
        );
      },
    );
    return b.buildDocument().toXmlString(pretty: true, indent: '  ');
  }

  /// The GPX for a saved workout's data, or null when it has no route.
  static String? encodeWorkout(Map<String, dynamic> data) {
    final points = GpsRoutePoint.listFrom(data['route']);
    if (points.length < 2) return null;
    final activity = data['type']?.toString();
    final start = DateTime.tryParse(
      (data['timestamp'] ?? '').toString(),
    )?.toUtc();
    return encode(
      points: points,
      name: data['name']?.toString() ?? activity,
      activity: activity,
      start: start,
    );
  }

  /// Total length of a route in metres (great-circle).
  static double distanceMeters(List<GpsRoutePoint> points) {
    var total = 0.0;
    for (var i = 1; i < points.length; i++) {
      total += haversine(points[i - 1], points[i]);
    }
    return total;
  }

  static double haversine(GpsRoutePoint a, GpsRoutePoint b) {
    const r = 6371000.0;
    double rad(double d) => d * math.pi / 180;
    final dLat = rad(b.latitude - a.latitude);
    final dLon = rad(b.longitude - a.longitude);
    final h =
        math.pow(math.sin(dLat / 2), 2) +
        math.cos(rad(a.latitude)) *
            math.cos(rad(b.latitude)) *
            math.pow(math.sin(dLon / 2), 2);
    return 2 * r * math.asin(math.min(1, math.sqrt(h)));
  }

  /// At most [max] points, evenly spaced, keeping the first and last.
  static List<GpsRoutePoint> thin(
    List<GpsRoutePoint> points, {
    int max = maxStoredPoints,
  }) {
    if (points.length <= max) return points;
    final step = (points.length - 1) / (max - 1);
    return [for (var i = 0; i < max; i++) points[(i * step).round()]];
  }

  static String? activityFor(String text) {
    final t = text.toLowerCase();
    if (t.contains('run') || t.contains('jog')) return 'Running';
    if (t.contains('cycl') || t.contains('bik') || t.contains('ride')) {
      return 'Cycling';
    }
    if (t.contains('hik')) return 'Hiking';
    if (t.contains('walk')) return 'Walking';
    return null;
  }
}
