import 'dart:async';
import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:zerotrust_fitness/core/security/encryption_service.dart';
import 'package:zerotrust_fitness/core/storage/local_vault.dart';
import 'package:zerotrust_fitness/features/health/data/gps_tracking_service.dart';
import 'package:zerotrust_fitness/heart_point_calculator.dart';

class GpsWorkoutPage extends StatefulWidget {
  const GpsWorkoutPage({super.key, required this.secretKey});

  final SecretKey? secretKey;

  @override
  State<GpsWorkoutPage> createState() => _GpsWorkoutPageState();
}

class _GpsWorkoutPageState extends State<GpsWorkoutPage> {
  final GpsTrackingService _service = GpsTrackingService();
  final MapController _mapController = MapController();

  StreamSubscription<GpsTrackingSnapshot>? _sub;
  GpsTrackingSnapshot? _snapshot;
  String _activityType = 'Running';
  bool _starting = true;
  bool _saving = false;
  String? _errorMessage;

  static const _activityTypes = [
    'Running',
    'Walking',
    'Cycling',
    'Hiking',
    'Swimming',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _sub = _service.snapshots.listen(
      (s) {
        if (!mounted) return;
        setState(() => _snapshot = s);
        // Keep map centered on latest point.
        if (s.routePoints.isNotEmpty) {
          final last = s.routePoints.last;
          try {
            _mapController.move(
              LatLng(last.latitude, last.longitude),
              _mapController.camera.zoom,
            );
          } catch (_) {}
        }
      },
    );
    _startTracking();
  }

  Future<void> _startTracking() async {
    try {
      await _service.start();
    } catch (e) {
      if (mounted) setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    // Don't auto-stop — user may have backgrounded accidentally.
    // Stopping is explicit via the Stop button.
    super.dispose();
  }

  Future<void> _stop() async {
    final result = await _service.stopAndCollect();
    if (result == null || !mounted) {
      if (mounted) Navigator.of(context).pop();
      return;
    }

    final sk = widget.secretKey;
    if (sk == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Vault locked — workout not saved.')),
        );
        Navigator.of(context).pop();
      }
      return;
    }

    setState(() => _saving = true);
    try {
      final durationMins = result.elapsed.inSeconds ~/ 60;
      final intensity = _intensityForActivity(_activityType);
      final heartPts = HeartPointCalculator.calculateFromManualWorkout(
        activityType: _activityType,
        durationMinutes: durationMins,
        intensity: intensity,
      );

      final workoutData = {
        'type': _activityType,
        'duration': durationMins,
        'intensity': intensity,
        'distance_m': result.distanceMeters,
        'avg_pace_min_per_km': result.averagePaceMinutesPerKm,
        'timestamp': result.startedAt.toIso8601String(),
        'route': result.routePoints
            .map((p) => {'lat': p.latitude, 'lng': p.longitude})
            .toList(),
      };

      final encrypted = await EncryptionService()
          .encryptString(jsonEncode(workoutData), sk);
      await LocalVault().saveWorkout(encrypted, sk);

      if (heartPts > 0) {
        final dateKey = _dateKey(result.startedAt);
        await LocalVault().mergeDailyMetrics(
          dateKey: dateKey,
          incoming: {'heart_points': heartPts},
          secretKey: sk,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Workout saved! ${(result.distanceMeters / 1000).toStringAsFixed(2)} km '
              'in ${_formatElapsed(result.elapsed)}',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
        Navigator.of(context).pop();
      }
    }
  }

  String _dateKey(DateTime dt) {
    final d = dt.toLocal();
    return '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }

  String _formatElapsed(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  int _intensityForActivity(String type) {
    switch (type) {
      case 'Running':
      case 'Cycling':
        return 7;
      case 'Hiking':
        return 5;
      case 'Walking':
        return 3;
      default:
        return 5;
    }
  }

  Widget _buildMap(GpsTrackingSnapshot snapshot) {
    final points = snapshot.routePoints
        .map((p) => LatLng(p.latitude, p.longitude))
        .toList();

    final center = points.isNotEmpty
        ? points.last
        : const LatLng(51.509364, -0.128928); // London fallback

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: center,
        initialZoom: 16,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.zerotrust.fitness',
        ),
        if (points.length >= 2)
          PolylineLayer(
            polylines: [
              Polyline(
                points: points,
                color: const Color(0xFF3B82F6),
                strokeWidth: 4,
              ),
            ],
          ),
        if (points.isNotEmpty)
          MarkerLayer(
            markers: [
              Marker(
                point: points.last,
                width: 16,
                height: 16,
                child: Container(
                  decoration: const BoxDecoration(
                    color: Color(0xFF3B82F6),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildStatColumn(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withValues(alpha: 0.75),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = _snapshot;
    final isPaused = snapshot?.isPaused ?? false;
    final isTracking = snapshot?.isTracking ?? false;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        title: const Text('GPS Workout',
            style: TextStyle(color: Colors.white)),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: DropdownButton<String>(
              value: _activityType,
              dropdownColor: const Color(0xFF1E293B),
              style: const TextStyle(color: Colors.white),
              iconEnabledColor: Colors.white,
              underline: const SizedBox.shrink(),
              items: _activityTypes
                  .map((t) => DropdownMenuItem(
                        value: t,
                        child: Text(t),
                      ))
                  .toList(),
              onChanged: isTracking
                  ? null
                  : (v) {
                      if (v != null) setState(() => _activityType = v);
                    },
            ),
          ),
        ],
      ),
      body: _starting
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Colors.white),
                  SizedBox(height: 16),
                  Text('Acquiring GPS signal…',
                      style: TextStyle(color: Colors.white)),
                ],
              ),
            )
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.gps_off,
                            color: Colors.redAccent, size: 48),
                        const SizedBox(height: 16),
                        Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.white70),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        FilledButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Go Back'),
                        ),
                      ],
                    ),
                  ),
                )
              : Column(
                  children: [
                    // Map takes top portion
                    Expanded(
                      flex: 3,
                      child: snapshot != null
                          ? _buildMap(snapshot)
                          : const Center(
                              child: Text('Waiting for location…',
                                  style: TextStyle(color: Colors.white70)),
                            ),
                    ),
                    // Stats + controls panel
                    Container(
                      color: const Color(0xFF0F172A),
                      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
                      child: Column(
                        children: [
                          // Timer
                          Text(
                            snapshot != null
                                ? _formatElapsed(snapshot.elapsed)
                                : '00:00:00',
                            style: const TextStyle(
                              fontSize: 56,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                          if (isPaused)
                            const Padding(
                              padding: EdgeInsets.only(top: 4),
                              child: Text(
                                'PAUSED',
                                style: TextStyle(
                                  color: Colors.amber,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 2,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          const SizedBox(height: 20),
                          // Distance + Pace
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _buildStatColumn(
                                'km',
                                snapshot != null
                                    ? (snapshot.distanceMeters / 1000)
                                        .toStringAsFixed(2)
                                    : '0.00',
                              ),
                              Container(
                                  width: 1,
                                  height: 40,
                                  color:
                                      Colors.white.withValues(alpha: 0.2)),
                              _buildStatColumn(
                                'min/km pace',
                                snapshot != null &&
                                        snapshot.currentPaceMinutesPerKm > 0
                                    ? snapshot.currentPaceMinutesPerKm
                                        .toStringAsFixed(1)
                                    : '--',
                              ),
                            ],
                          ),
                          const SizedBox(height: 28),
                          // Controls
                          if (_saving)
                            const CircularProgressIndicator(
                                color: Colors.white)
                          else
                            Row(
                              children: [
                                // Pause / Resume
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: isTracking
                                        ? () {
                                            if (isPaused) {
                                              _service.resume();
                                            } else {
                                              _service.pause();
                                            }
                                          }
                                        : null,
                                    icon: Icon(isPaused
                                        ? Icons.play_arrow
                                        : Icons.pause),
                                    label: Text(
                                        isPaused ? 'Resume' : 'Pause'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.white,
                                      side: const BorderSide(
                                          color: Colors.white38),
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 14),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                // Stop
                                Expanded(
                                  child: FilledButton.icon(
                                    onPressed: _stop,
                                    icon: const Icon(Icons.stop),
                                    label: const Text('Stop & Save'),
                                    style: FilledButton.styleFrom(
                                      backgroundColor:
                                          const Color(0xFFF43F5E),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 14),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }
}
