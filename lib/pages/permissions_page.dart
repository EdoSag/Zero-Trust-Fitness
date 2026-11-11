import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:health/health.dart';
import 'package:zerotrust_fitness/components/inline_button_style.dart';
import 'package:zerotrust_fitness/features/health/data/gps_tracking_service.dart';
import 'package:zerotrust_fitness/features/health/data/health_service.dart';
import 'package:zerotrust_fitness/l10n/l10n.dart';

class _HealthPermissionConfig {
  _HealthPermissionConfig({
    required this.key,
    required this.title,
    required this.description,
    required this.requestTypes,
    this.androidRequestTypes,
  });

  final String key;
  final String title;
  final String description;
  final List<HealthDataType> requestTypes;
  final List<HealthDataType>? androidRequestTypes;
}

List<_HealthPermissionConfig> get _healthPermissionConfigs => <_HealthPermissionConfig>[
  _HealthPermissionConfig(
    key: 'steps',
    title: currentL10n.steps,
    description: currentL10n.readDailyStepCounts,
    requestTypes: [HealthDataType.STEPS],
  ),
  _HealthPermissionConfig(
    key: 'heart_rate',
    title: currentL10n.heartRate,
    description: currentL10n.readHeartRateSamples,
    requestTypes: [HealthDataType.HEART_RATE],
  ),
  _HealthPermissionConfig(
    key: 'exercise',
    title: currentL10n.exerciseSessions,
    description: currentL10n.readWorkoutsAndActiveMinutes,
    requestTypes: [HealthDataType.WORKOUT],
  ),
  _HealthPermissionConfig(
    key: 'sleep_asleep',
    title: currentL10n.sleepAsleep,
    description: currentL10n.readSleepAsleepDuration,
    requestTypes: [HealthDataType.SLEEP_ASLEEP],
  ),
  _HealthPermissionConfig(
    key: 'sleep_light',
    title: currentL10n.sleepLight,
    description: currentL10n.readLightSleepDuration,
    requestTypes: [HealthDataType.SLEEP_LIGHT],
  ),
  _HealthPermissionConfig(
    key: 'sleep_deep',
    title: currentL10n.sleepDeep,
    description: currentL10n.readDeepSleepDuration,
    requestTypes: [HealthDataType.SLEEP_DEEP],
  ),
  _HealthPermissionConfig(
    key: 'sleep_rem',
    title: currentL10n.sleepRem,
    description: currentL10n.readRemSleepDuration,
    requestTypes: [HealthDataType.SLEEP_REM],
  ),
  _HealthPermissionConfig(
    key: 'resting_hr',
    title: currentL10n.restingHeartRate,
    description: currentL10n.readRestingBpm,
    requestTypes: [HealthDataType.RESTING_HEART_RATE],
  ),
  _HealthPermissionConfig(
    key: 'respiratory_rate',
    title: currentL10n.respiratoryRate,
    description: currentL10n.readRespirationsPerMinute,
    requestTypes: [HealthDataType.RESPIRATORY_RATE],
  ),
  _HealthPermissionConfig(
    key: 'blood_oxygen',
    title: currentL10n.bloodOxygen,
    description: currentL10n.readOxygenSaturationSpo2,
    requestTypes: [HealthDataType.BLOOD_OXYGEN],
  ),
  _HealthPermissionConfig(
    key: 'weight',
    title: currentL10n.weight,
    description: currentL10n.readBodyWeight,
    requestTypes: [HealthDataType.WEIGHT],
  ),
  _HealthPermissionConfig(
    key: 'bmi',
    title: currentL10n.bodyMassIndex,
    description: currentL10n.readBmiValues,
    requestTypes: [HealthDataType.BODY_MASS_INDEX],
    // Health Connect permissions are tied to weight/height records.
    androidRequestTypes: [HealthDataType.WEIGHT, HealthDataType.HEIGHT],
  ),
  _HealthPermissionConfig(
    key: 'body_fat',
    title: currentL10n.bodyFatX,
    description: currentL10n.readBodyFatPercentage,
    requestTypes: [HealthDataType.BODY_FAT_PERCENTAGE],
  ),
  _HealthPermissionConfig(
    key: 'water',
    title: currentL10n.hydration,
    description: currentL10n.readWaterIntake,
    requestTypes: [HealthDataType.WATER],
  ),
  _HealthPermissionConfig(
    key: 'nutrition',
    title: currentL10n.nutrition,
    description: currentL10n.readNutritionEntries,
    requestTypes: [HealthDataType.NUTRITION],
  ),
  _HealthPermissionConfig(
    key: 'bp_systolic',
    title: currentL10n.bloodPressureSystolic,
    description: currentL10n.readSystolicBloodPressure,
    requestTypes: [HealthDataType.BLOOD_PRESSURE_SYSTOLIC],
  ),
  _HealthPermissionConfig(
    key: 'bp_diastolic',
    title: currentL10n.bloodPressureDiastolic,
    description: currentL10n.readDiastolicBloodPressure,
    requestTypes: [HealthDataType.BLOOD_PRESSURE_DIASTOLIC],
  ),
  _HealthPermissionConfig(
    key: 'blood_glucose',
    title: currentL10n.bloodGlucose,
    description: currentL10n.readBloodGlucoseSamples,
    requestTypes: [HealthDataType.BLOOD_GLUCOSE],
  ),
];

class _PermissionCategory {
  _PermissionCategory({
    required this.title,
    required this.icon,
    required this.keys,
  });

  final String title;
  final IconData icon;
  final List<String> keys;
}

List<_PermissionCategory> get _healthPermissionCategories => <_PermissionCategory>[
  _PermissionCategory(
    title: currentL10n.activity,
    icon: Icons.directions_run,
    keys: ['steps', 'heart_rate', 'exercise', 'water', 'nutrition'],
  ),
  _PermissionCategory(
    title: currentL10n.sleep,
    icon: Icons.bedtime_outlined,
    keys: ['sleep_asleep', 'sleep_light', 'sleep_deep', 'sleep_rem'],
  ),
  _PermissionCategory(
    title: currentL10n.vitals,
    icon: Icons.monitor_heart_outlined,
    keys: [
      'resting_hr',
      'respiratory_rate',
      'blood_oxygen',
      'bp_systolic',
      'bp_diastolic',
      'blood_glucose',
    ],
  ),
  _PermissionCategory(
    title: currentL10n.body,
    icon: Icons.accessibility_new_outlined,
    keys: ['weight', 'bmi', 'body_fat'],
  ),
];
class PermissionsPage extends StatefulWidget {
  const PermissionsPage({super.key});

  @override
  State<PermissionsPage> createState() => _PermissionsPageState();
}
class _PermissionsPageState extends State<PermissionsPage> {
  final Health _health = Health();
  final GpsTrackingService _gpsTrackingService = GpsTrackingService();

  bool _healthConnectAvailable = true;
  final Map<String, bool?> _healthPermissionStates = {};
  bool? _locationPermission;
  bool? _backgroundHealthPermission;
  bool _permissionsBusy = false;

  @override
  void initState() {
    super.initState();
    _refreshPermissionStates();
  }

  List<HealthDataType> _effectiveTypes(_HealthPermissionConfig config) {
    if (defaultTargetPlatform == TargetPlatform.android &&
        config.androidRequestTypes != null &&
        config.androidRequestTypes!.isNotEmpty) {
      return config.androidRequestTypes!;
    }
    return config.requestTypes;
  }

  Future<void> _refreshPermissionStates() async {
    try {
      final healthService = HealthService();
      final healthConnectAvailable =
          await healthService.isHealthConnectAvailable();

      final statuses = await Future.wait<bool?>(
        _healthPermissionConfigs.map((config) async {
          final types = _effectiveTypes(config);
          if (types.isEmpty) return false;
          try {
            final status = await _health.hasPermissions(
              types,
              permissions: List<HealthDataAccess>.filled(
                types.length,
                HealthDataAccess.READ,
              ),
            );
            return status;
          } catch (_) {
            return false;
          }
        }),
      );

      bool? locationGranted;
      final locationPermission = await Geolocator.checkPermission();
      final locationServiceEnabled =
          await Geolocator.isLocationServiceEnabled();
      if (!locationServiceEnabled) {
        locationGranted = false;
      } else {
        locationGranted = locationPermission == LocationPermission.always ||
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
        for (var i = 0; i < _healthPermissionConfigs.length; i++) {
          _healthPermissionStates[_healthPermissionConfigs[i].key] =
              statuses[i];
        }
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
        SnackBar(content: Text(context.l10n.permissionActionFailed('$e'))),
      );
    } finally {
      if (mounted) setState(() => _permissionsBusy = false);
    }
  }

  Future<void> _openAppSettings() async {
    await Geolocator.openAppSettings();
  }

  Future<void> _grantHealthType(_HealthPermissionConfig config) async {
    final types = _effectiveTypes(config);
    final granted = await _health.requestAuthorization(
      types,
      permissions: List<HealthDataAccess>.filled(
        types.length,
        HealthDataAccess.READ,
      ),
    );
    if (!granted && defaultTargetPlatform == TargetPlatform.android) {
      await _openAppSettings();
    }
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
        title: Text(context.l10n.permissionsCenter),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: context.l10n.refreshPermissionStates,
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
                    context.l10n.permissionsCenter,
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
                context.l10n.controlEachPermissionDirectlyFrom,
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              ..._healthPermissionCategories.map(_buildCategorySection),
              _buildLocationCategorySection(),
              if (defaultTargetPlatform == TargetPlatform.android &&
                  !_healthConnectAvailable)
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: OutlinedButton.icon(
                    onPressed: _permissionsBusy
                        ? null
                        : () => _handlePermissionAction(
                              _health.installHealthConnect,
                            ),
                    icon: const Icon(Icons.download_rounded),
                    label: Text(context.l10n.installHealthConnect),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategorySection(_PermissionCategory category) {
    final configs = _healthPermissionConfigs
        .where((c) => category.keys.contains(c.key))
        .toList();
    final grantedCount =
        configs.where((c) => _healthPermissionStates[c.key] == true).length;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: Icon(category.icon),
        title: Text(
          category.title,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(context.l10n.nOfMGranted(grantedCount, configs.length)),
        children: configs
            .map(
              (config) => Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: _buildPermissionRow(
                  title: config.title,
                  description: config.description,
                  granted: _healthPermissionStates[config.key],
                  onEnable: () => _handlePermissionAction(
                    () => _grantHealthType(config),
                  ),
                  onDisable: () =>
                      _handlePermissionAction(_disableHealthPermissions),
                ),
              ),
            )
            .toList(growable: false),
      ),
    );
  }

  Widget _buildLocationCategorySection() {
    final locationGranted = _locationPermission == true;
    final bgGranted = _backgroundHealthPermission == true;
    final isAndroid = defaultTargetPlatform == TargetPlatform.android;
    final total = isAndroid ? 2 : 1;
    final granted = (locationGranted ? 1 : 0) + (isAndroid && bgGranted ? 1 : 0);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: const Icon(Icons.location_on_outlined),
        title: Text(
          context.l10n.location,
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(context.l10n.nOfMGranted(granted, total)),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: _buildPermissionRow(
              title: context.l10n.location,
              description: context.l10n.enableRealTimeGpsRun,
              granted: _locationPermission,
              onEnable: () =>
                  _handlePermissionAction(_grantLocationPermission),
              onDisable: () =>
                  _handlePermissionAction(_disableLocationPermission),
            ),
          ),
          if (isAndroid)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: _buildPermissionRow(
                title: context.l10n.backgroundHealthSync,
                description: context.l10n.allowPeriodicBackgroundHealthData,
                granted: _backgroundHealthPermission,
                onEnable: () => _handlePermissionAction(
                  _grantBackgroundHealthPermission,
                ),
                onDisable: () => _handlePermissionAction(
                  _disableBackgroundHealthPermission,
                ),
              ),
            ),
        ],
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
        ? context.l10n.granted
        : granted == false
            ? context.l10n.denied
            : context.l10n.unknown;
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
                style: inlineButtonStyle,
                icon: const Icon(Icons.toggle_on),
                label: Text(context.l10n.turnOn),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _permissionsBusy ? null : onDisable,
                style: inlineButtonStyle,
                icon: const Icon(Icons.toggle_off),
                label: Text(context.l10n.turnOff),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
