import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:zerotrust_fitness/features/health/data/gps_tracking_service.dart';
import 'package:zerotrust_fitness/features/health/data/workout_feedback.dart';

/// Roughly 0.0009 degrees of latitude is 100 m.
const _degPer100m = 100 / 111195;

void main() {
  late StreamController<GpsFix> fixes;
  late DateTime now;
  late GpsTrackingService gps;
  late List<GpsEvent> events;
  var lat = 51.0;

  setUp(() async {
    fixes = StreamController<GpsFix>();
    now = DateTime.utc(2026, 11, 9, 7);
    lat = 51.0;
    gps = GpsTrackingService.forTest(
        positions: () => fixes.stream, clock: () => now);
    events = [];
    gps.events.listen(events.add);
    await gps.start(autoPause: true, checkPermission: false);
  });

  tearDown(() => gps.stop());

  /// Moves 100 m north in [seconds].
  void run100m({int seconds = 30}) {
    now = now.add(Duration(seconds: seconds));
    lat += _degPer100m;
    gps.onFix(GpsFix(latitude: lat, longitude: 0, time: now, speed: 100 / seconds));
  }

  void standStill(int seconds) {
    for (var i = 0; i < seconds; i++) {
      now = now.add(const Duration(seconds: 1));
      gps.tick();
    }
  }

  test('distance, splits every kilometre and moving time', () async {
    gps.onFix(GpsFix(latitude: lat, longitude: 0, time: now));
    for (var i = 0; i < 25; i++) {
      run100m();
    }
    await Future<void>.delayed(Duration.zero);
    final s = gps.current;
    expect(s.distanceMeters, closeTo(2500, 5));
    expect(s.splits, hasLength(2));
    expect(s.splits.first.duration, const Duration(minutes: 5));
    expect(events.whereType<SplitReached>(), hasLength(2));
    expect(s.elapsed, const Duration(minutes: 12, seconds: 30));
  });

  test('auto-pause stops the clock while standing, and resumes on moving',
      () async {
    gps.onFix(GpsFix(latitude: lat, longitude: 0, time: now));
    run100m();
    standStill(60);
    expect(gps.current.isAutoPaused, isTrue);
    // The first fix that shows movement ends the pause; the clock runs
    // from there.
    run100m(seconds: 5);
    run100m(seconds: 25);
    await Future<void>.delayed(Duration.zero);
    expect(gps.current.isPaused, isFalse);
    // 30 s + 25 s of running; the minute standing doesn't count.
    expect(gps.current.elapsed, const Duration(seconds: 55));
    expect(events.whereType<AutoPaused>(), hasLength(1));
    expect(events.whereType<AutoResumed>(), hasLength(1));
  });

  test('GPS jitter and poor fixes add no distance', () {
    gps.onFix(GpsFix(latitude: lat, longitude: 0, time: now));
    now = now.add(const Duration(seconds: 5));
    gps.onFix(GpsFix(
        latitude: lat + _degPer100m * 5, longitude: 0, time: now, accuracy: 80));
    expect(gps.current.distanceMeters, 0);
  });

  test('a manual pause holds distance and time until resumed', () {
    gps.onFix(GpsFix(latitude: lat, longitude: 0, time: now));
    run100m();
    gps.pause();
    run100m();
    standStill(120);
    expect(gps.current.isAutoPaused, isFalse);
    gps.resume();
    expect(gps.current.distanceMeters, closeTo(100, 2));
    expect(gps.current.elapsed, const Duration(seconds: 30));
  });

  test('laps, and the last stretch becomes a final lap', () async {
    gps.onFix(GpsFix(latitude: lat, longitude: 0, time: now));
    for (var i = 0; i < 4; i++) {
      run100m();
    }
    final lap = gps.lap()!;
    expect(lap.distanceMeters, closeTo(400, 3));
    expect(lap.duration, const Duration(minutes: 2));
    run100m();
    run100m();
    final result = (await gps.stopAndCollect())!;
    expect(result.laps, hasLength(2));
    expect(result.laps.last.distanceMeters, closeTo(200, 3));
    expect(result.distanceMeters, closeTo(600, 5));
    expect(result.routePoints, hasLength(7));
    expect(gps.isTracking, isFalse);
  });

  test('voice cue wording', () {
    final split = SplitReached(
      const GpsLap(
          index: 2,
          distanceMeters: 1000,
          duration: Duration(minutes: 5, seconds: 1)),
      const Duration(minutes: 10, seconds: 30),
      1000,
    );
    expect(VoiceCues.split(split),
        '2 kilometres. Time 10 minutes 30 seconds. '
        'Split 5 minutes 1 second per kilometre.');
  });
}
