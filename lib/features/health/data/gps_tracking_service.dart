import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

class GpsRoutePoint {
  const GpsRoutePoint(this.latitude, this.longitude, {this.time, this.elevation});
  final double latitude;
  final double longitude;

  /// When the phone was here (for GPX export); null on old workouts.
  final DateTime? time;

  /// Metres above sea level, when the phone knows.
  final double? elevation;

  factory GpsRoutePoint.ofFix(GpsFix fix) => GpsRoutePoint(
        fix.latitude,
        fix.longitude,
        time: fix.time,
        elevation: fix.altitude,
      );

  /// The shape saved in a workout's `route`: `lat`, `lng`, and when known
  /// `t` (Unix seconds) and `ele` (metres).
  Map<String, dynamic> toJson() => {
        'lat': latitude,
        'lng': longitude,
        if (time != null) 't': time!.millisecondsSinceEpoch ~/ 1000,
        if (elevation != null) 'ele': double.parse(elevation!.toStringAsFixed(1)),
      };

  static GpsRoutePoint? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final lat = raw['lat'], lng = raw['lng'];
    if (lat is! num || lng is! num) return null;
    final t = raw['t'];
    final ele = raw['ele'];
    return GpsRoutePoint(
      lat.toDouble(),
      lng.toDouble(),
      time: t is num
          ? DateTime.fromMillisecondsSinceEpoch(t.toInt() * 1000, isUtc: true)
          : null,
      elevation: ele is num ? ele.toDouble() : null,
    );
  }

  /// A workout's saved route.
  static List<GpsRoutePoint> listFrom(Object? route) => route is List
      ? [for (final p in route) ?fromJson(p)]
      : const [];
}

/// One location reading.
class GpsFix {
  const GpsFix({
    required this.latitude,
    required this.longitude,
    required this.time,
    this.accuracy = 5,
    this.speed = -1,
    this.altitude,
  });

  factory GpsFix.fromPosition(Position p) => GpsFix(
        latitude: p.latitude,
        longitude: p.longitude,
        time: p.timestamp,
        accuracy: p.accuracy,
        speed: p.speed,
        // Android reports 0 when it has no altitude.
        altitude: p.altitude == 0 ? null : p.altitude,
      );

  final double latitude;
  final double longitude;
  final DateTime time;

  /// Metres; fixes worse than [GpsTrackingService.maxAccuracyMeters] are
  /// ignored.
  final double accuracy;

  /// Metres per second, or negative when the phone doesn't know.
  final double speed;

  /// Metres above sea level, or null.
  final double? altitude;
}

/// A split (every kilometre or mile) or a lap (the Lap button).
class GpsLap {
  const GpsLap({
    required this.index,
    required this.distanceMeters,
    required this.duration,
  });

  final int index;
  final double distanceMeters;
  final Duration duration;

  double get paceMinutesPerKm => distanceMeters <= 0
      ? 0
      : (duration.inMilliseconds / 60000) / (distanceMeters / 1000);

  Map<String, dynamic> toJson() => {
        'index': index,
        'distance_m': double.parse(distanceMeters.toStringAsFixed(1)),
        'seconds': duration.inSeconds,
        'pace_min_per_km': double.parse(paceMinutesPerKm.toStringAsFixed(3)),
      };
}

class GpsTrackingSnapshot {
  GpsTrackingSnapshot({
    required this.distanceMeters,
    required this.elapsed,
    required this.currentPaceMinutesPerKm,
    required this.isTracking,
    required this.isPaused,
    required this.routePoints,
    this.isAutoPaused = false,
    this.splits = const [],
    this.laps = const [],
  });

  final double distanceMeters;

  /// Moving time: manual and auto pauses don't count.
  final Duration elapsed;
  final double currentPaceMinutesPerKm;
  final bool isTracking;

  /// Paused by the person or by auto-pause.
  final bool isPaused;
  final bool isAutoPaused;
  final List<GpsRoutePoint> routePoints;
  final List<GpsLap> splits;
  final List<GpsLap> laps;
}

/// Returned by [GpsTrackingService.stopAndCollect] so the caller can save it.
class GpsWorkoutResult {
  const GpsWorkoutResult({
    required this.distanceMeters,
    required this.elapsed,
    required this.averagePaceMinutesPerKm,
    required this.routePoints,
    required this.startedAt,
    this.splits = const [],
    this.laps = const [],
  });

  final double distanceMeters;
  final Duration elapsed;
  final double averagePaceMinutesPerKm;
  final List<GpsRoutePoint> routePoints;
  final DateTime startedAt;
  final List<GpsLap> splits;
  final List<GpsLap> laps;
}

/// Something worth telling the person while they move (voice cues, the
/// lock-screen notification).
sealed class GpsEvent {
  const GpsEvent();
}

class SplitReached extends GpsEvent {
  const SplitReached(this.split, this.totalElapsed, this.unitMeters);
  final GpsLap split;
  final Duration totalElapsed;
  final double unitMeters;
}

class LapMarked extends GpsEvent {
  const LapMarked(this.lap);
  final GpsLap lap;
}

class AutoPaused extends GpsEvent {
  const AutoPaused();
}

class AutoResumed extends GpsEvent {
  const AutoResumed();
}

/// Records a GPS workout: distance, moving time, route, splits every
/// kilometre (or mile) and laps, with optional auto-pause when the person
/// stops moving.
///
/// It keeps running when its screen closes (or the vault auto-locks):
/// only Stop ends a workout, and opening the screen again picks it up.
class GpsTrackingService {
  factory GpsTrackingService() => _instance;

  GpsTrackingService.forTest({
    required Stream<GpsFix> Function() positions,
    required DateTime Function() clock,
  })  : _positions = positions,
        _clock = clock;

  GpsTrackingService._()
      : _positions = _devicePositions,
        _clock = DateTime.now;

  static final GpsTrackingService _instance = GpsTrackingService._();

  static const double maxAccuracyMeters = 35;
  static const Duration autoPauseAfter = Duration(seconds: 10);
  static const double metersPerMile = 1609.344;

  final Stream<GpsFix> Function() _positions;
  final DateTime Function() _clock;

  final StreamController<GpsTrackingSnapshot> _snapshotController =
      StreamController<GpsTrackingSnapshot>.broadcast();
  final StreamController<GpsEvent> _eventController =
      StreamController<GpsEvent>.broadcast();

  StreamSubscription<GpsFix>? _positionSubscription;
  Timer? _ticker;
  DateTime? _startTime;
  GpsFix? _lastFix;
  DateTime? _lastMovedAt;
  double _distanceMeters = 0;

  bool _manualPaused = false;
  bool _autoPaused = false;
  DateTime? _pauseStartTime;
  Duration _pausedDuration = Duration.zero;

  bool _autoPauseEnabled = false;
  double _splitMeters = 1000;
  double _movingSpeed = 0.6;
  String _activityType = 'Running';

  final List<GpsRoutePoint> _routePoints = [];
  final List<GpsLap> _splits = [];
  final List<GpsLap> _laps = [];
  double _lapStartDistance = 0;
  Duration _lapStartElapsed = Duration.zero;

  GpsTrackingSnapshot? _latest;

  Stream<GpsTrackingSnapshot> get snapshots => _snapshotController.stream;
  Stream<GpsEvent> get events => _eventController.stream;

  bool get isTracking => _startTime != null;
  bool get isPaused => _manualPaused || _autoPaused;
  String get activityType => _activityType;
  double get splitMeters => _splitMeters;
  bool get autoPauseEnabled => _autoPauseEnabled;

  /// The latest state, for a screen opened mid-workout.
  GpsTrackingSnapshot get current => _latest ?? _snapshot();

  Future<bool> ensurePermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  /// Starts a workout. [splitMeters] is 1000 for kilometre splits or
  /// [metersPerMile]; [activityType] sets how slow counts as stopped for
  /// auto-pause (cycling is faster than walking).
  Future<void> start({
    String activityType = 'Running',
    bool autoPause = false,
    double splitMeters = 1000,
    bool checkPermission = true,
  }) async {
    if (checkPermission) {
      final hasPermission = await ensurePermission();
      if (!hasPermission) {
        throw StateError('Location permission not granted.');
      }
    }

    await _cancelSubscription();
    _startTime = _clock();
    _lastMovedAt = _startTime;
    _distanceMeters = 0;
    _lastFix = null;
    _manualPaused = false;
    _autoPaused = false;
    _pauseStartTime = null;
    _pausedDuration = Duration.zero;
    _routePoints.clear();
    _splits.clear();
    _laps.clear();
    _lapStartDistance = 0;
    _lapStartElapsed = Duration.zero;
    _activityType = activityType;
    _autoPauseEnabled = autoPause;
    _splitMeters = splitMeters;
    _movingSpeed = movingSpeedFor(activityType);
    _emitSnapshot();

    _positionSubscription = _positions().listen(onFix);
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => tick());
  }

  /// Slower than this (metres per second) counts as standing still.
  static double movingSpeedFor(String activityType) =>
      switch (activityType) {
        'Cycling' => 1.5,
        'Swimming' => 0.2,
        _ => 0.6,
      };

  void setAutoPause(bool enabled) {
    _autoPauseEnabled = enabled;
    if (!enabled && _autoPaused) _resumeFromAuto();
    _emitSnapshot();
  }

  void pause() {
    if (!isTracking || _manualPaused) return;
    _manualPaused = true;
    // An auto-pause already stopped the clock.
    if (!_autoPaused) _pauseStartTime = _clock();
    _autoPaused = false;
    _emitSnapshot();
  }

  void resume() {
    if (!isTracking || !isPaused) return;
    _endPause();
    _manualPaused = false;
    _autoPaused = false;
    // Don't auto-pause again straight away.
    _lastMovedAt = _clock();
    _emitSnapshot();
  }

  void togglePause() => isPaused ? resume() : pause();

  /// Ends the current lap and starts the next one.
  GpsLap? lap() {
    if (!isTracking) return null;
    final elapsed = _activeElapsed();
    final lap = GpsLap(
      index: _laps.length + 1,
      distanceMeters: _distanceMeters - _lapStartDistance,
      duration: elapsed - _lapStartElapsed,
    );
    _laps.add(lap);
    _lapStartDistance = _distanceMeters;
    _lapStartElapsed = elapsed;
    _eventController.add(LapMarked(lap));
    _emitSnapshot();
    return lap;
  }

  /// Stops tracking and returns the collected workout data.
  /// Returns null if tracking was never started.
  Future<GpsWorkoutResult?> stopAndCollect() async {
    final startedAt = _startTime;
    if (startedAt == null) {
      await stop();
      return null;
    }

    final activeElapsed = _activeElapsed();
    final distM = _distanceMeters;
    final points = List<GpsRoutePoint>.unmodifiable(_routePoints);
    final pace =
        distM <= 0 ? 0.0 : (activeElapsed.inSeconds / 60) / (distM / 1000);
    final splits = List<GpsLap>.of(_splits);
    final laps = List<GpsLap>.of(_laps);
    // A final lap for the stretch since the last Lap press.
    if (laps.isNotEmpty && distM - _lapStartDistance > 1) {
      laps.add(GpsLap(
        index: laps.length + 1,
        distanceMeters: distM - _lapStartDistance,
        duration: activeElapsed - _lapStartElapsed,
      ));
    }

    await stop();

    return GpsWorkoutResult(
      distanceMeters: distM,
      elapsed: activeElapsed,
      averagePaceMinutesPerKm: pace.isFinite ? pace : 0,
      routePoints: points,
      startedAt: startedAt,
      splits: splits,
      laps: laps,
    );
  }

  Future<void> stop() async {
    await _cancelSubscription();
    _startTime = null;
    _manualPaused = false;
    _autoPaused = false;
    _pauseStartTime = null;
    _pausedDuration = Duration.zero;
    _distanceMeters = 0;
    _lastFix = null;
    _routePoints.clear();
    _splits.clear();
    _laps.clear();
    _emitSnapshot();
  }

  // ---------------------------------------------------------------------------

  static Stream<GpsFix> _devicePositions() => Geolocator.getPositionStream(
        locationSettings: switch (defaultTargetPlatform) {
          // The workout notification's foreground service keeps these
          // coming with the screen off.
          TargetPlatform.android => AndroidSettings(
              accuracy: LocationAccuracy.bestForNavigation,
              distanceFilter: 3,
              intervalDuration: const Duration(seconds: 1),
            ),
          TargetPlatform.iOS => AppleSettings(
              accuracy: LocationAccuracy.bestForNavigation,
              activityType: ActivityType.fitness,
              distanceFilter: 3,
              allowBackgroundLocationUpdates: true,
              pauseLocationUpdatesAutomatically: false,
              showBackgroundLocationIndicator: true,
            ),
          _ => const LocationSettings(
              accuracy: LocationAccuracy.bestForNavigation,
              distanceFilter: 3,
            ),
        },
      ).map(GpsFix.fromPosition);

  Future<void> _cancelSubscription() async {
    _ticker?.cancel();
    _ticker = null;
    await _positionSubscription?.cancel();
    _positionSubscription = null;
  }

  /// Handles one location reading. Public for tests.
  void onFix(GpsFix fix) {
    if (!isTracking || fix.accuracy > maxAccuracyMeters) return;
    final last = _lastFix;
    _lastFix = fix;
    if (last == null) {
      if (!isPaused) {
        _routePoints.add(GpsRoutePoint.ofFix(fix));
        _emitSnapshot();
      }
      return;
    }

    final d = Geolocator.distanceBetween(
        last.latitude, last.longitude, fix.latitude, fix.longitude);
    final seconds = fix.time.difference(last.time).inMilliseconds / 1000;
    final speed =
        fix.speed >= 0 ? fix.speed : (seconds > 0 ? d / seconds : 0.0);
    final moving = speed >= _movingSpeed && d >= 2;

    if (_manualPaused) return;
    if (_autoPaused) {
      if (!moving) return;
      _resumeFromAuto();
    }
    if (moving) _lastMovedAt = _clock();

    _distanceMeters += d;
    _routePoints.add(GpsRoutePoint.ofFix(fix));
    _checkSplits();
    _emitSnapshot();
  }

  /// Runs every second: moves the clock on and auto-pauses. Public for
  /// tests.
  void tick() {
    if (!isTracking) return;
    final lastMoved = _lastMovedAt;
    if (_autoPauseEnabled &&
        !isPaused &&
        lastMoved != null &&
        _clock().difference(lastMoved) >= autoPauseAfter) {
      _autoPaused = true;
      // The time spent standing before the pause kicked in doesn't count.
      _pauseStartTime = lastMoved;
      _eventController.add(const AutoPaused());
    }
    _emitSnapshot();
  }

  void _resumeFromAuto() {
    _endPause();
    _autoPaused = false;
    _lastMovedAt = _clock();
    _eventController.add(const AutoResumed());
  }

  void _endPause() {
    final pauseStart = _pauseStartTime;
    if (pauseStart != null) {
      _pausedDuration += _clock().difference(pauseStart);
      _pauseStartTime = null;
    }
  }

  void _checkSplits() {
    while (_distanceMeters >= (_splits.length + 1) * _splitMeters) {
      final index = _splits.length + 1;
      // The fix that crossed the mark is a few metres past it; close
      // enough for a split time.
      final elapsed = _activeElapsed();
      final previous = _splits.fold<Duration>(
          Duration.zero, (sum, s) => sum + s.duration);
      final split = GpsLap(
        index: index,
        distanceMeters: _splitMeters,
        duration: elapsed - previous,
      );
      _splits.add(split);
      _eventController.add(SplitReached(split, elapsed, _splitMeters));
    }
  }

  Duration _activeElapsed() {
    final start = _startTime;
    if (start == null) return Duration.zero;
    final now = _clock();
    final raw = now.difference(start);
    final pauseStart = _pauseStartTime;
    final paused = _pausedDuration +
        (pauseStart != null ? now.difference(pauseStart) : Duration.zero);
    final active = raw - paused;
    return active.isNegative ? Duration.zero : active;
  }

  GpsTrackingSnapshot _snapshot() {
    final elapsed = _activeElapsed();
    final pace = _distanceMeters <= 0
        ? 0.0
        : (elapsed.inSeconds / 60) / (_distanceMeters / 1000);
    return GpsTrackingSnapshot(
      distanceMeters: _distanceMeters,
      elapsed: elapsed,
      currentPaceMinutesPerKm: pace.isFinite ? pace : 0,
      isTracking: isTracking,
      isPaused: isPaused,
      isAutoPaused: _autoPaused,
      routePoints: List<GpsRoutePoint>.unmodifiable(_routePoints),
      splits: List<GpsLap>.unmodifiable(_splits),
      laps: List<GpsLap>.unmodifiable(_laps),
    );
  }

  void _emitSnapshot() {
    final s = _snapshot();
    _latest = s;
    _snapshotController.add(s);
  }
}
