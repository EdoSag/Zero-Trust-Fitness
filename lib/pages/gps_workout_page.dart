import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zerotrust_fitness/features/maps/tile_cache.dart';
import 'package:zerotrust_fitness/app/vault_providers.dart';
import 'package:zerotrust_fitness/core/storage/fitness_vault.dart';
import 'package:zerotrust_fitness/core/utils/units_formatter.dart';
import 'package:zerotrust_fitness/features/health/data/gps_tracking_service.dart';
import 'package:zerotrust_fitness/features/health/data/workout_feedback.dart';
import 'package:zerotrust_fitness/pages/journal_page.dart'
    show activityIcon, formatClock;

/// Records a GPS workout: choose the activity, start, and the screen shows
/// time, distance, pace and splits. Leaving the screen (or the vault
/// locking) doesn't end the workout; opening it again picks it up.
class GpsWorkoutPage extends ConsumerStatefulWidget {
  const GpsWorkoutPage({super.key, this.onSaved});

  /// After the workout is saved (Health Connect write-back uses it).
  final Future<void> Function(FitnessVault vault, String id)? onSaved;

  @override
  ConsumerState<GpsWorkoutPage> createState() => _GpsWorkoutPageState();
}

class _GpsWorkoutPageState extends ConsumerState<GpsWorkoutPage> {
  static const _autoPauseKey = 'gps_auto_pause';
  static const _activityKey = 'gps_last_activity';

  final GpsTrackingService _service = GpsTrackingService();
  final MapController _mapController = MapController();

  StreamSubscription<GpsTrackingSnapshot>? _sub;
  late GpsTrackingSnapshot _snapshot = _service.current;
  String _activityType = 'Running';
  bool _autoPause = true;
  bool _voice = true;
  bool _starting = false;
  bool _saving = false;
  String? _errorMessage;

  static const _activityTypes = [
    'Running',
    'Walking',
    'Cycling',
    'Hiking',
    'Other',
  ];

  bool get _imperial => UnitsFormatter().distanceUnit == DistanceUnit.imperial;
  double get _unitMeters =>
      _imperial ? GpsTrackingService.metersPerMile : 1000;
  String get _unitLabel => _imperial ? 'mi' : 'km';

  @override
  void initState() {
    super.initState();
    _sub = _service.snapshots.listen(_onSnapshot);
    if (_service.isTracking) {
      _activityType = _service.activityType;
      _autoPause = _service.autoPauseEnabled;
    }
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final voice = await VoiceCoach.instance.isEnabled;
    if (!mounted) return;
    setState(() {
      _voice = voice;
      if (!_service.isTracking) {
        _autoPause = prefs.getBool(_autoPauseKey) ?? true;
        final last = prefs.getString(_activityKey);
        if (last != null && _activityTypes.contains(last)) {
          _activityType = last;
        }
      }
    });
  }

  void _onSnapshot(GpsTrackingSnapshot s) {
    if (!mounted) return;
    final moved = s.routePoints.length != _snapshot.routePoints.length;
    setState(() => _snapshot = s);
    if (moved && s.routePoints.isNotEmpty) {
      final last = s.routePoints.last;
      try {
        _mapController.move(
          LatLng(last.latitude, last.longitude),
          _mapController.camera.zoom,
        );
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    // Don't stop: only the Stop button ends a workout.
    super.dispose();
  }

  Future<void> _start() async {
    setState(() {
      _starting = true;
      _errorMessage = null;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_autoPauseKey, _autoPause);
      await prefs.setString(_activityKey, _activityType);
      await _service.start(
        activityType: _activityType,
        autoPause: _autoPause,
        splitMeters: _unitMeters,
      );
      await VoiceCoach.instance.attach(_service);
      await WorkoutNotification.instance.start(_service);
      HapticFeedback.mediumImpact();
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = e is StateError
            ? 'Fitness needs location access to record a GPS workout. '
                'You can allow it in your phone\'s settings.'
            : 'Couldn\'t start: $e');
      }
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  Future<void> _stop({bool save = true}) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(save ? 'Finish workout?' : 'Discard workout?'),
        content: Text(save
            ? 'It\'s saved to your journal.'
            : 'This workout won\'t be saved.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep going'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: save
                ? null
                : FilledButton.styleFrom(
                    backgroundColor: Theme.of(ctx).colorScheme.error),
            child: Text(save ? 'Finish' : 'Discard'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final result = await _service.stopAndCollect();
    await WorkoutNotification.instance.stop();
    await VoiceCoach.instance.detach();
    if (!mounted) return;
    if (result == null || !save) {
      Navigator.of(context).pop();
      return;
    }

    final vault = ref.read(openFitnessVaultProvider);
    if (vault == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vault locked, workout not saved.')),
      );
      Navigator.of(context).pop();
      return;
    }

    setState(() => _saving = true);
    try {
      final id = await vault.logWorkout({
        'type': _activityType,
        'duration': (result.elapsed.inSeconds / 60).round(),
        'intensity': _intensityForActivity(_activityType),
        'distance_m': result.distanceMeters,
        'avg_pace_min_per_km': result.averagePaceMinutesPerKm,
        'timestamp': result.startedAt.toIso8601String(),
        'route': [for (final p in result.routePoints) p.toJson()],
        if (result.splits.isNotEmpty)
          'splits': [for (final s in result.splits) s.toJson()],
        if (result.laps.isNotEmpty)
          'laps': [for (final l in result.laps) l.toJson()],
      });
      await widget.onSaved?.call(vault, id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Workout saved: ${(result.distanceMeters / _unitMeters).toStringAsFixed(2)} '
              '$_unitLabel in ${formatClock(result.elapsed)}',
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

  int _intensityForActivity(String type) => switch (type) {
        'Running' || 'Cycling' => 7,
        'Hiking' => 5,
        'Walking' => 3,
        _ => 5,
      };

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final tracking = _snapshot.isTracking;
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        title: Text(tracking ? _activityType : 'GPS workout'),
        actions: [
          IconButton(
            tooltip: _voice ? 'Voice cues on' : 'Voice cues off',
            icon: Icon(_voice ? Icons.volume_up : Icons.volume_off),
            onPressed: () async {
              setState(() => _voice = !_voice);
              await VoiceCoach.instance.setEnabled(_voice);
            },
          ),
          if (tracking)
            PopupMenuButton<String>(
              tooltip: 'More',
              onSelected: (v) {
                if (v == 'autopause') {
                  setState(() => _autoPause = !_autoPause);
                  _service.setAutoPause(_autoPause);
                } else if (v == 'discard') {
                  _stop(save: false);
                }
              },
              itemBuilder: (_) => [
                CheckedPopupMenuItem(
                  value: 'autopause',
                  checked: _autoPause,
                  child: const Text('Auto-pause'),
                ),
                const PopupMenuItem(
                  value: 'discard',
                  child: Text('Discard workout'),
                ),
              ],
            ),
        ],
      ),
      body: tracking ? _tracking() : _setup(),
    );
  }

  Widget _setup() {
    const white70 = TextStyle(color: Colors.white70);
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text('Activity',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final t in _activityTypes)
                ChoiceChip(
                  label: Text(t),
                  avatar: Icon(activityIcon(t), size: 18),
                  selected: _activityType == t,
                  onSelected: (_) => setState(() => _activityType = t),
                ),
            ],
          ),
          const SizedBox(height: 24),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _autoPause,
            onChanged: (v) => setState(() => _autoPause = v),
            title: const Text('Auto-pause', style: TextStyle(color: Colors.white)),
            subtitle: const Text('Stops the clock when you stop moving', style: white70),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _voice,
            onChanged: (v) async {
              setState(() => _voice = v);
              await VoiceCoach.instance.setEnabled(v);
            },
            title: const Text('Voice cues', style: TextStyle(color: Colors.white)),
            subtitle: Text(
                'Time and pace every ${_imperial ? 'mile' : 'kilometre'}',
                style: white70),
          ),
          const SizedBox(height: 8),
          const Text(
            'Your route stays encrypted in your vault. While you record, a '
            'notification shows time and distance, with Pause and Lap '
            'buttons on the lock screen.',
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 16),
            Row(children: [
              const Icon(Icons.gps_off, color: Colors.redAccent),
              const SizedBox(width: 12),
              Expanded(child: Text(_errorMessage!, style: white70)),
            ]),
          ],
          const SizedBox(height: 32),
          FilledButton.icon(
            onPressed: _starting ? null : _start,
            icon: _starting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.play_arrow),
            label: Text(_starting ? 'Finding GPS…' : 'Start'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF22C55E),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tracking() {
    final s = _snapshot;
    final pace = s.currentPaceMinutesPerKm;
    return Column(
      children: [
        Expanded(flex: 3, child: _buildMap(s)),
        Container(
          color: const Color(0xFF0F172A),
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                Text(
                  formatClock(s.elapsed),
                  style: const TextStyle(
                    fontSize: 56,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                if (s.isPaused)
                  Text(
                    s.isAutoPaused ? 'AUTO-PAUSED' : 'PAUSED',
                    style: const TextStyle(
                      color: Colors.amber,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2,
                      fontSize: 13,
                    ),
                  ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _stat(_unitLabel,
                        (s.distanceMeters / _unitMeters).toStringAsFixed(2)),
                    _divider(),
                    _stat('avg pace',
                        pace > 0 ? _pace(pace) : '--'),
                    _divider(),
                    _stat(s.laps.isEmpty ? 'splits' : 'laps',
                        '${s.laps.isEmpty ? s.splits.length : s.laps.length}'),
                  ],
                ),
                if (s.splits.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Last $_unitLabel: ${formatClock(s.splits.last.duration)}',
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
                const SizedBox(height: 20),
                if (_saving)
                  const CircularProgressIndicator(color: Colors.white)
                else
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _service.togglePause,
                          icon: Icon(s.isPaused ? Icons.play_arrow : Icons.pause),
                          label: Text(s.isPaused ? 'Resume' : 'Pause'),
                          style: _outlined,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: s.isPaused
                              ? null
                              : () {
                                  HapticFeedback.selectionClick();
                                  _service.lap();
                                },
                          icon: const Icon(Icons.flag_outlined),
                          label: const Text('Lap'),
                          style: _outlined,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _stop,
                          icon: const Icon(Icons.stop),
                          label: const Text('Finish'),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFFF43F5E),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  static final _outlined = OutlinedButton.styleFrom(
    foregroundColor: Colors.white,
    side: const BorderSide(color: Colors.white38),
    padding: const EdgeInsets.symmetric(vertical: 14),
  );

  String _pace(double minPerKm) {
    final p = _imperial ? minPerKm * GpsTrackingService.metersPerMile / 1000 : minPerKm;
    final m = p.floor();
    final sec = ((p - m) * 60).round().clamp(0, 59);
    return '$m:${sec.toString().padLeft(2, '0')}';
  }

  Widget _divider() => Container(
      width: 1, height: 40, color: Colors.white.withValues(alpha: 0.2));

  Widget _stat(String label, String value) => Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 26,
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

  Widget _buildMap(GpsTrackingSnapshot snapshot) {
    final points = [
      for (final p in snapshot.routePoints) LatLng(p.latitude, p.longitude),
    ];
    if (points.isEmpty) {
      return const Center(
        child: Text('Waiting for GPS…', style: TextStyle(color: Colors.white70)),
      );
    }
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(initialCenter: points.last, initialZoom: 16),
      children: [
        ztTileLayer(),
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
        ztMapAttribution(),
      ],
    );
  }
}
