import 'dart:async';

import 'package:geolocator/geolocator.dart';

class GpsTrackingSnapshot {
  GpsTrackingSnapshot({
    required this.distanceMeters,
    required this.elapsed,
    required this.currentPaceMinutesPerKm,
    required this.isTracking,
  });

  final double distanceMeters;
  final Duration elapsed;
  final double currentPaceMinutesPerKm;
  final bool isTracking;
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

  Stream<GpsTrackingSnapshot> get snapshots => _snapshotController.stream;

  Future<bool> ensurePermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  Future<void> start() async {
    final hasPermission = await ensurePermission();
    if (!hasPermission) {
      throw StateError('Location permission not granted.');
    }

    await stop();
    _startTime = DateTime.now();
    _distanceMeters = 0;
    _lastPosition = null;
    _emitSnapshot();

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
      _emitSnapshot();
    });
  }

  Future<void> stop() async {
    await _positionSubscription?.cancel();
    _positionSubscription = null;
    _emitSnapshot();
  }

  void _emitSnapshot() {
    final elapsed = _startTime == null
        ? Duration.zero
        : DateTime.now().difference(_startTime!);

    final pace = _distanceMeters <= 0
        ? 0.0
        : (elapsed.inSeconds / 60) / (_distanceMeters / 1000);

    _snapshotController.add(
      GpsTrackingSnapshot(
        distanceMeters: _distanceMeters,
        elapsed: elapsed,
        currentPaceMinutesPerKm: pace.isFinite ? pace : 0,
        isTracking: _positionSubscription != null,
      ),
    );
  }
}
