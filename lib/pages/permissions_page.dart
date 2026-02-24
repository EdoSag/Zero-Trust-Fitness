import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:health/health.dart';
import 'package:nowa_runtime/nowa_runtime.dart';
import 'package:zerotrust_fitness/features/health/data/gps_tracking_service.dart';
import 'package:zerotrust_fitness/features/health/data/health_service.dart';

@NowaGenerated()
class PermissionsPage extends StatefulWidget {
  @NowaGenerated({'loader': 'auto-constructor'})
  const PermissionsPage({super.key});

  @override
  State<PermissionsPage> createState() => _PermissionsPageState();
}

@NowaGenerated()
class _PermissionsPageState extends State<PermissionsPage> {
  final Health _health = Health();
  final GpsTrackingService _gpsTrackingService = GpsTrackingService();

  bool _healthConnectAvailable = true;
  bool? _stepsPermission;
  bool? _heartPermission;
  bool? _exercisePermission;
  bool? _locationPermission;
  bool? _backgroundHealthPermission;
  bool _permissionsBusy = false;

  @override
  void initState() {
    super.initState();
    _refreshPermissionStates();
  }

  Future<void> _refreshPermissionStates() async {
    try {
      final healthService = HealthService();
      final healthConnectAvailable = await healthService
          .isHealthConnectAvailable();

      final results = await Future.wait<bool?>([
        _health.hasPermissions(
          [HealthDataType.STEPS],
          permissions: [HealthDataAccess.READ],
        ),
        _health.hasPermissions(
          [HealthDataType.HEART_RATE],
          permissions: [HealthDataAccess.READ],
        ),
        _health.hasPermissions(
          [HealthDataType.WORKOUT],
          permissions: [HealthDataAccess.READ],
        ),
      ]);

      bool? locationGranted;
      final locationPermission = await Geolocator.checkPermission();
      final locationServiceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!locationServiceEnabled) {
        locationGranted = false;
      } else {
        locationGranted =
            locationPermission == LocationPermission.always ||
            locationPermission == LocationPermission.whileInUse;
      }

      bool? backgroundHealthGranted = true;
      if (defaultTargetPlatform == TargetPlatform.android &&
          healthConnectAvailable) {
        backgroundHealthGranted =
            await _health.isHealthDataInBackgroundAuthorized();
      }

      if (!mounted) return;
      setState(() {
        _healthConnectAvailable = healthConnectAvailable;
        _stepsPermission = results[0];
        _heartPermission = results[1];
        _exercisePermission = results[2];
        _locationPermission = locationGranted;
        _backgroundHealthPermission = backgroundHealthGranted;
      });
    } catch (e) {
      debugPrint('Permission refresh failed: $e');
    }
  }

  Future<void> _handlePermissionAction(Future<void> Function() action) async {
    if (_permissionsBusy) return;
    setState(() => _permissionsBusy = true);
    try {
      await action();
      await _refreshPermissionStates();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Permission action failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _permissionsBusy = false);
    }
  }

  Future<void> _openAppSettings() async {
    await Geolocator.openAppSettings();
  }

  Future<void> _grantHealthType(HealthDataType type) async {
    final granted = await _health.requestAuthorization(
      [type],
      permissions: [HealthDataAccess.READ],
    );
    if (!granted && defaultTargetPlatform == TargetPlatform.android) {
      await _openAppSettings();
    }
  }

  Future<void> _grantExercisePermission() async {
    await _grantHealthType(HealthDataType.WORKOUT);
  }

  Future<void> _disableHealthPermissions() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      await _health.revokePermissions();
    }
    await _openAppSettings();
  }

  Future<void> _grantLocationPermission() async {
    await _gpsTrackingService.ensurePermission();
  }

  Future<void> _disableLocationPermission() async {
    await _openAppSettings();
  }

  Future<void> _grantBackgroundHealthPermission() async {
    final granted = await _health.requestHealthDataInBackgroundAuthorization();
    if (!granted && defaultTargetPlatform == TargetPlatform.android) {
      await _openAppSettings();
    }
  }

  Future<void> _disableBackgroundHealthPermission() async {
    await _openAppSettings();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Permissions Center'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _permissionsBusy ? null : _refreshPermissionStates,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: theme.cardColor.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.admin_panel_settings_outlined,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Permissions Center',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  if (_permissionsBusy)
                    const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Control each permission directly from here.',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              _buildPermissionRow(
                title: 'Steps',
                description: 'Read daily step count from health provider.',
                granted: _stepsPermission,
                onEnable: () => _handlePermissionAction(
                  () => _grantHealthType(HealthDataType.STEPS),
                ),
                onDisable: () => _handlePermissionAction(_disableHealthPermissions),
              ),
              _buildPermissionRow(
                title: 'Heart Rate',
                description: 'Read BPM and heart-rate events.',
                granted: _heartPermission,
                onEnable: () => _handlePermissionAction(
                  () => _grantHealthType(HealthDataType.HEART_RATE),
                ),
                onDisable: () => _handlePermissionAction(_disableHealthPermissions),
              ),
              _buildPermissionRow(
                title: 'Exercise Sessions',
                description: 'Read workouts to derive exercise minutes for points.',
                granted: _exercisePermission,
                onEnable: () => _handlePermissionAction(_grantExercisePermission),
                onDisable: () => _handlePermissionAction(_openAppSettings),
              ),
              _buildPermissionRow(
                title: 'Location',
                description: 'Enable real-time GPS run/cycle tracking.',
                granted: _locationPermission,
                onEnable: () => _handlePermissionAction(_grantLocationPermission),
                onDisable: () => _handlePermissionAction(_disableLocationPermission),
              ),
              if (defaultTargetPlatform == TargetPlatform.android)
                _buildPermissionRow(
                  title: 'Background Health Sync',
                  description: 'Allow periodic background health data reads.',
                  granted: _backgroundHealthPermission,
                  onEnable: () => _handlePermissionAction(
                    _grantBackgroundHealthPermission,
                  ),
                  onDisable: () => _handlePermissionAction(
                    _disableBackgroundHealthPermission,
                  ),
                ),
              if (defaultTargetPlatform == TargetPlatform.android &&
                  !_healthConnectAvailable)
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: _permissionsBusy
                        ? null
                        : () => _handlePermissionAction(
                              _health.installHealthConnect,
                            ),
                    icon: const Icon(Icons.download_rounded),
                    label: const Text('Install Health Connect'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPermissionRow({
    required String title,
    required String description,
    required bool? granted,
    required VoidCallback onEnable,
    required VoidCallback onDisable,
  }) {
    final statusText = granted == true
        ? 'Granted'
        : granted == false
            ? 'Denied'
            : 'Unknown';
    final statusColor = granted == true
        ? Colors.green
        : granted == false
            ? Colors.redAccent
            : Colors.orangeAccent;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(description, style: const TextStyle(fontSize: 12)),
          const SizedBox(height: 10),
          Row(
            children: [
              FilledButton.tonalIcon(
                onPressed: _permissionsBusy ? null : onEnable,
                icon: const Icon(Icons.toggle_on),
                label: const Text('Turn On'),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _permissionsBusy ? null : onDisable,
                icon: const Icon(Icons.toggle_off),
                label: const Text('Turn Off'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
