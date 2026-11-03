import 'dart:async';

import 'package:geolocator/geolocator.dart';

class GpsRoutePoint {
  const GpsRoutePoint(this.latitude, this.longitude);
  final double latitude;
  final double longitude;
}

class GpsTrackingSnapshot {
  GpsTrackingSnapshot({
    required this.distanceMeters,
    required this.elapsed,
    required this.currentPaceMinutesPerKm,
    required this.isTracking,
    required this.isPaused,
    required this.routePoints,
  });

  final double distanceMeters;
  final Duration elapsed;
  final double currentPaceMinutesPerKm;
  final bool isTracking;
  final bool isPaused;
  final List<GpsRoutePoint> routePoints;
}

/// Returned by [GpsTrackingService.stopAndCollect] so the caller can save it.
class GpsWorkoutResult {
  const GpsWorkoutResult({
    required this.distanceMeters,
    required this.elapsed,
    required this.averagePaceMinutesPerKm,
    required this.routePoints,
    required this.startedAt,
  });

  final double distanceMeters;
  final Duration elapsed;
  final double averagePaceMinutesPerKm;
  final List<GpsRoutePoint> routePoints;
  final DateTime startedAt;
}

class GpsTrackingService {
  factory GpsTrackingService() => _instance;

  GpsTrackingService._();

  static final GpsTrackingService _instance = GpsTrackingService._();

  final StreamController<GpsTrackingSnapshot> _snapshotController =
      StreamController<GpsTrackingSnapshot>.broadcast();

  StreamSubscription<Position>? _positionSubscription;
  DateTime? _startTime;
  Position? _lastPosition;
  double _distanceMeters = 0;

  bool _isPaused = false;
  DateTime? _pauseStartTime;
  Duration _pausedDuration = Duration.zero;

  final List<GpsRoutePoint> _routePoints = [];

  Stream<GpsTrackingSnapshot> get snapshots => _snapshotController.stream;

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

  Future<void> start() async {
    final hasPermission = await ensurePermission();
    if (!hasPermission) throw StateError('Location permission not granted.');

    await _cancelSubscription();
    _startTime = DateTime.now();
    _distanceMeters = 0;
    _lastPosition = null;
    _isPaused = false;
    _pauseStartTime = null;
    _pausedDuration = Duration.zero;
    _routePoints.clear();
    _emitSnapshot();

    _startPositionStream();
  }

  void pause() {
    if (!_isActiveTracking || _isPaused) return;
    _isPaused = true;
    _pauseStartTime = DateTime.now();
    _positionSubscription?.cancel();
    _positionSubscription = null;
    _emitSnapshot();
  }

  void resume() {
    if (!_isPaused) return;
    if (_pauseStartTime != null) {
      _pausedDuration += DateTime.now().difference(_pauseStartTime!);
      _pauseStartTime = null;
    }
    _isPaused = false;
    _startPositionStream();
    _emitSnapshot();
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
    final pace = distM <= 0
        ? 0.0
        : (activeElapsed.inSeconds / 60) / (distM / 1000);

    await stop();

    return GpsWorkoutResult(
      distanceMeters: distM,
      elapsed: activeElapsed,
      averagePaceMinutesPerKm: pace.isFinite ? pace : 0,
      routePoints: points,
      startedAt: startedAt,
    );
  }

  Future<void> stop() async {
    await _cancelSubscription();
    _startTime = null;
    _isPaused = false;
    _pauseStartTime = null;
    _pausedDuration = Duration.zero;
    _distanceMeters = 0;
    _lastPosition = null;
    _routePoints.clear();
    _emitSnapshot();
  }

  // ---------------------------------------------------------------------------

  bool get _isActiveTracking =>
      _startTime != null || _positionSubscription != null;

  Future<void> _cancelSubscription() async {
    await _positionSubscription?.cancel();
    _positionSubscription = null;
  }

  void _startPositionStream() {
    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 3,
      ),
    ).listen((position) {
      if (_lastPosition != null) {
        _distanceMeters += Geolocator.distanceBetween(
          _lastPosition!.latitude,
          _lastPosition!.longitude,
          position.latitude,
          position.longitude,
        );
      }
      _lastPosition = position;
      _routePoints.add(GpsRoutePoint(position.latitude, position.longitude));
      _emitSnapshot();
    });
  }

  Duration _activeElapsed() {
    if (_startTime == null) return Duration.zero;
    final raw = DateTime.now().difference(_startTime!);
    final paused = _pausedDuration +
        (_pauseStartTime != null
            ? DateTime.now().difference(_pauseStartTime!)
            : Duration.zero);
    final active = raw - paused;
    return active.isNegative ? Duration.zero : active;
  }

  void _emitSnapshot() {
    final elapsed = _activeElapsed();
    final pace = _distanceMeters <= 0
        ? 0.0
        : (elapsed.inSeconds / 60) / (_distanceMeters / 1000);

    _snapshotController.add(GpsTrackingSnapshot(
      distanceMeters: _distanceMeters,
      elapsed: elapsed,
      currentPaceMinutesPerKm: pace.isFinite ? pace : 0,
      isTracking: _startTime != null,
      isPaused: _isPaused,
      routePoints: List<GpsRoutePoint>.unmodifiable(_routePoints),
    ));
  }
}
