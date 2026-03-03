import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:health/health.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter/material.dart';
import 'package:nowa_runtime/nowa_runtime.dart';
import 'package:zerotrust_fitness/features/health/data/health_service.dart';
import 'package:zerotrust_fitness/features/health/data/gps_tracking_service.dart';
import 'package:zerotrust_fitness/components/manual_ingestion_bottom_sheet.dart';
import 'package:zerotrust_fitness/features/app/providers.dart';
import 'package:zerotrust_fitness/components/security_barrier.dart';
import 'package:flutter/services.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:zerotrust_fitness/components/shimmer_loader.dart';
import 'package:zerotrust_fitness/globals/app_state.dart';
import 'package:zerotrust_fitness/main.dart';
import 'package:zerotrust_fitness/widget_service.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:zerotrust_fitness/heart_point_calculator.dart';
import 'package:zerotrust_fitness/core/security/encryption_service.dart';
import 'package:zerotrust_fitness/core/services/supabase_service.dart';
import 'package:zerotrust_fitness/core/storage/local_vault.dart';
import 'package:zerotrust_fitness/pages/permissions_page.dart';
import 'package:zerotrust_fitness/pages/profile_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum _DeleteDataScope { cloud, local, all }

class _DualMetricPoint {
  const _DualMetricPoint({
    required this.label,
    required this.steps,
    required this.heartPoints,
  });

  final String label;
  final double steps;
  final double heartPoints;
}

class _SingleMetricPoint {
  const _SingleMetricPoint({
    required this.label,
    required this.value,
  });

  final String label;
  final double value;
}

class _MetricCardSpec {
  const _MetricCardSpec({
    required this.key,
    required this.title,
    required this.unit,
    required this.icon,
    required this.gradientColors,
  });

  final String key;
  final String title;
  final String unit;
  final IconData icon;
  final List<Color> gradientColors;
}

const _metricCardSpecs = <_MetricCardSpec>[
  _MetricCardSpec(
    key: 'steps',
    title: 'Steps',
    unit: '',
    icon: Icons.directions_walk,
    gradientColors: [Color(0xFF3B82F6), Color(0xFF6366F1)],
  ),
  _MetricCardSpec(
    key: 'heart_points',
    title: 'Heart Points',
    unit: '',
    icon: Icons.favorite,
    gradientColors: [Color(0xFFF43F5E), Color(0xFFFB7185)],
  ),
  _MetricCardSpec(
    key: 'sleep_asleep_min',
    title: 'Sleep Asleep',
    unit: 'min',
    icon: Icons.nights_stay_outlined,
    gradientColors: [Color(0xFF0EA5E9), Color(0xFF0284C7)],
  ),
  _MetricCardSpec(
    key: 'sleep_light_min',
    title: 'Sleep Light',
    unit: 'min',
    icon: Icons.bedtime_outlined,
    gradientColors: [Color(0xFF38BDF8), Color(0xFF0EA5E9)],
  ),
  _MetricCardSpec(
    key: 'sleep_deep_min',
    title: 'Sleep Deep',
    unit: 'min',
    icon: Icons.hotel_outlined,
    gradientColors: [Color(0xFF1D4ED8), Color(0xFF1E40AF)],
  ),
  _MetricCardSpec(
    key: 'sleep_rem_min',
    title: 'Sleep REM',
    unit: 'min',
    icon: Icons.bed_outlined,
    gradientColors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
  ),
  _MetricCardSpec(
    key: 'resting_hr_bpm_avg',
    title: 'Resting HR',
    unit: 'bpm',
    icon: Icons.monitor_heart_outlined,
    gradientColors: [Color(0xFFEC4899), Color(0xFFDB2777)],
  ),
  _MetricCardSpec(
    key: 'respiratory_rate_avg',
    title: 'Respiratory',
    unit: 'rpm',
    icon: Icons.air_outlined,
    gradientColors: [Color(0xFF14B8A6), Color(0xFF0F766E)],
  ),
  _MetricCardSpec(
    key: 'blood_oxygen_pct_avg',
    title: 'Blood Oxygen',
    unit: '%',
    icon: Icons.bloodtype_outlined,
    gradientColors: [Color(0xFF06B6D4), Color(0xFF0E7490)],
  ),
  _MetricCardSpec(
    key: 'weight_kg',
    title: 'Weight',
    unit: 'kg',
    icon: Icons.monitor_weight_outlined,
    gradientColors: [Color(0xFF84CC16), Color(0xFF65A30D)],
  ),
  _MetricCardSpec(
    key: 'bmi',
    title: 'BMI',
    unit: '',
    icon: Icons.straighten_outlined,
    gradientColors: [Color(0xFFF59E0B), Color(0xFFD97706)],
  ),
  _MetricCardSpec(
    key: 'body_fat_pct',
    title: 'Body Fat',
    unit: '%',
    icon: Icons.accessibility_new_outlined,
    gradientColors: [Color(0xFFF97316), Color(0xFFEA580C)],
  ),
  _MetricCardSpec(
    key: 'water_l',
    title: 'Hydration',
    unit: 'L',
    icon: Icons.water_drop_outlined,
    gradientColors: [Color(0xFF0EA5E9), Color(0xFF2563EB)],
  ),
  _MetricCardSpec(
    key: 'nutrition_entries',
    title: 'Nutrition',
    unit: 'entries',
    icon: Icons.restaurant_menu_outlined,
    gradientColors: [Color(0xFF22C55E), Color(0xFF16A34A)],
  ),
  _MetricCardSpec(
    key: 'blood_pressure_systolic_mmhg',
    title: 'BP Systolic',
    unit: 'mmHg',
    icon: Icons.monitor_heart,
    gradientColors: [Color(0xFFE11D48), Color(0xFFBE123C)],
  ),
  _MetricCardSpec(
    key: 'blood_pressure_diastolic_mmhg',
    title: 'BP Diastolic',
    unit: 'mmHg',
    icon: Icons.favorite_border,
    gradientColors: [Color(0xFFF43F5E), Color(0xFFE11D48)],
  ),
  _MetricCardSpec(
    key: 'blood_glucose_mg_dl',
    title: 'Glucose',
    unit: 'mg/dL',
    icon: Icons.science_outlined,
    gradientColors: [Color(0xFFA855F7), Color(0xFF7E22CE)],
  ),
];

@NowaGenerated()
// Changed from StatefulWidget to ConsumerStatefulWidget
class DashboardPage extends ConsumerStatefulWidget {
  @NowaGenerated({'loader': 'auto-constructor'})
  const DashboardPage({super.key});

  @override
  ConsumerState<DashboardPage> createState() {
    return _DashboardPageState();
  }
}

@NowaGenerated()
// Changed from State to ConsumerState
class _DashboardPageState extends ConsumerState<DashboardPage> {
  bool _isLoading = false;
  bool _isSyncing = false;
  bool _isPulling = false;
  bool _isDeletingData = false;
  List<HealthDataPoint> _healthData = [];
  List<Map<String, dynamic>> _recentActivities = [];
  final Health _health = Health();
  final GpsTrackingService _gpsTrackingService = GpsTrackingService();
  int _heartPointsTotal = 0;
  List<Map<String, dynamic>> _dailyMetrics = [];
  Map<String, num> _todayMetrics = const <String, num>{};
  String _selectedTrendMetricKey = 'sleep_asleep_min';
  bool _showAllMetrics = false;
  GpsTrackingSnapshot _gpsSnapshot = GpsTrackingSnapshot(
    distanceMeters: 0,
    elapsed: Duration.zero,
    currentPaceMinutesPerKm: 0,
    isTracking: false,
  );

  @override
  void initState() {
    super.initState();
    _gpsTrackingService.snapshots.listen((snapshot) {
      if (!mounted) return;
      setState(() => _gpsSnapshot = snapshot);
    });
    _loadHealthData();
  }

  Future<void> _loadHealthData() async {
    if (!mounted) return;

    setState(() => _isLoading = true);
    try {
      final healthService = HealthService();
      final isHealthConnectAvailable =
          await healthService.isHealthConnectAvailable();
      if (!isHealthConnectAvailable) {
        debugPrint(
          'Health Connect is unavailable. Install/enable it before syncing.',
        );
        setState(() {
          _healthData = [];
          _todayMetrics = const <String, num>{};
        });
        return;
      }

      final readableTypes = await _getReadableHealthTypes();
      if (readableTypes.isEmpty) {
        debugPrint('Health permissions not granted.');
        setState(() {
          _healthData = [];
          _heartPointsTotal = 0;
          _todayMetrics = const <String, num>{};
        });
        return;
      }

      final healthData = await healthService.fetchLatestData(
        requestedTypes: readableTypes,
      );
      final deduplicated = Health().removeDuplicates(healthData);
      final todayPoints = deduplicated
          .where((p) => _isSameLocalDay(p.dateFrom, DateTime.now()))
          .toList(growable: false);

      if (!mounted) return;
      final totalSteps = todayPoints
          .where((p) => p.type == HealthDataType.STEPS)
          .fold<int>(0, (sum, p) => sum + _extractNumericValue(p).toInt());

      var heartPoints = todayPoints
          .where((p) =>
              p.type == HealthDataType.EXERCISE_TIME ||
              p.type == HealthDataType.WORKOUT)
          .fold<int>(0, (sum, p) => sum + _extractExerciseMinutes(p));

      if (heartPoints == 0) {
        heartPoints = todayPoints
            .where((p) => p.type == HealthDataType.HEART_RATE)
            .fold<int>(0, (sum, p) {
          final bpm = _extractNumericValue(p);
          return sum + _calculateHeartPointsFromHeartRate(bpm, 1);
        });
      }
      final todayMetrics = _buildTodayMetricsMap(
        todayPoints,
        steps: totalSteps,
        heartPoints: heartPoints,
      );
      setState(() {
        _healthData = deduplicated;
        _heartPointsTotal = heartPoints;
        _todayMetrics = todayMetrics;
      });

      final secretKey = ref.read(securityEnclaveProvider);
      if (secretKey != null) {
        await LocalVault().upsertDailyMetrics(
          dateKey: _dateKey(DateTime.now()),
          metrics: todayMetrics,
          secretKey: secretKey,
        );
      }

      await WidgetService.updateWidgetData(
        steps: totalSteps,
        heartPoints: heartPoints,
        isLocked: secretKey == null,
      );
      await _loadRecentActivities();
      await _loadDailyMetrics();
    } catch (e) {
      debugPrint('Error loading health data: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<List<HealthDataType>> _getReadableHealthTypes() async {
    final readableTypes = <HealthDataType>[];
    for (final type in HealthService().types) {
      try {
        final status = await _health.hasPermissions(
          [type],
          permissions: [HealthDataAccess.READ],
        );
        if (status != false) {
          readableTypes.add(type);
        }
      } catch (_) {
        // Some metrics can be unavailable on specific devices/providers.
      }
    }
    return readableTypes;
  }

  Future<void> _loadRecentActivities() async {
    final secretKey = ref.read(securityEnclaveProvider);
    if (secretKey == null) {
      if (mounted) {
        setState(() => _recentActivities = []);
      }
      return;
    }

    try {
      final encryptedRows = await LocalVault().fetchWorkouts(secretKey);
      final activities = <Map<String, dynamic>>[];

      for (final encrypted in encryptedRows) {
        if (activities.length == 3) break;
        try {
          final decrypted = await EncryptionService().decryptString(
            encrypted,
            secretKey,
          );
          final decoded = jsonDecode(decrypted);
          if (decoded is Map<String, dynamic>) {
            activities.add(decoded);
          } else if (decoded is Map) {
            activities.add(decoded.map((k, v) => MapEntry('$k', v)));
          }
        } catch (_) {
          // Skip entries that fail to decrypt or parse.
        }
      }

      if (!mounted) return;
      setState(() => _recentActivities = activities);
    } catch (e) {
      debugPrint('Error loading recent activities: $e');
      if (!mounted) return;
      setState(() => _recentActivities = []);
    }
  }

  Future<void> _loadDailyMetrics() async {
    final secretKey = ref.read(securityEnclaveProvider);
    if (secretKey == null) {
      if (!mounted) return;
      setState(() => _dailyMetrics = []);
      return;
    }

    try {
      final rows = await LocalVault().fetchDailyMetrics(secretKey);
      final fallbackToday = _metricsForDate(DateTime.now(), rows);
      if (!mounted) return;
      setState(() {
        _dailyMetrics = rows;
        if (_todayMetrics.isEmpty && fallbackToday.isNotEmpty) {
          _todayMetrics = fallbackToday;
          _heartPointsTotal =
              (fallbackToday['heart_points'])?.toInt() ?? _heartPointsTotal;
        }
      });
    } catch (e) {
      debugPrint('Error loading daily metrics: $e');
      if (!mounted) return;
      setState(() => _dailyMetrics = []);
    }
  }

  String _dateKey(DateTime date) {
    final local = date.toLocal();
    return '${local.year.toString().padLeft(4, '0')}-'
        '${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')}';
  }

  bool _isSameLocalDay(DateTime left, DateTime right) {
    final l = left.toLocal();
    final r = right.toLocal();
    return l.year == r.year && l.month == r.month && l.day == r.day;
  }

  double _extractNumericValue(HealthDataPoint point) {
    final value = point.value;

    // 1. Handle NumericHealthValue (most common for steps/calories)
    if (value is NumericHealthValue) {
      return value.numericValue.toDouble();
    }

    // 2. Fallback for non-numeric HealthValue variants
    return double.tryParse(value.toString()) ?? 0.0;
  }

  int _calculateHeartPointsFromHeartRate(double bpm, int minutes) {
    // Fallback profile assumption when user age is not captured in state.
    const assumedAge = 30;
    final maxHeartRate = HeartPointCalculator.calculateMaxHeartRate(assumedAge);
    return HeartPointCalculator.calculatePoints(bpm, maxHeartRate, minutes);
  }

  int _extractExerciseMinutes(HealthDataPoint point) {
    if (point.type == HealthDataType.EXERCISE_TIME) {
      return _extractNumericValue(point).toInt();
    }
    if (point.type == HealthDataType.WORKOUT) {
      final minutes = point.dateTo.difference(point.dateFrom).inMinutes;
      return minutes < 0 ? 0 : minutes;
    }
    return 0;
  }

  int _extractSleepMinutes(HealthDataPoint point) {
    final minutes = point.dateTo.difference(point.dateFrom).inMinutes;
    if (minutes > 0) return minutes;
    return _extractNumericValue(point).toInt();
  }

  Map<String, num> _buildTodayMetricsMap(
    List<HealthDataPoint> points, {
    required int steps,
    required int heartPoints,
  }) {
    final metrics = <String, num>{
      'steps': steps,
      'heart_points': heartPoints,
      'sleep_asleep_min': 0,
      'sleep_light_min': 0,
      'sleep_deep_min': 0,
      'sleep_rem_min': 0,
      'water_l': 0.0,
      'nutrition_entries': 0,
      'resting_hr_bpm_avg': 0.0,
      'respiratory_rate_avg': 0.0,
      'blood_oxygen_pct_avg': 0.0,
      'weight_kg': 0.0,
      'bmi': 0.0,
      'body_fat_pct': 0.0,
      'blood_pressure_systolic_mmhg': 0.0,
      'blood_pressure_diastolic_mmhg': 0.0,
      'blood_glucose_mg_dl': 0.0,
    };

    final restingSamples = <double>[];
    final respiratorySamples = <double>[];
    final oxygenSamples = <double>[];
    final latestAt = <String, DateTime>{};

    void sumMetric(String key, num value) {
      final current = metrics[key] ?? 0;
      metrics[key] = current + value;
    }

    void setLatestMetric(String key, num value, DateTime date) {
      final currentLatest = latestAt[key];
      if (currentLatest == null || date.isAfter(currentLatest)) {
        latestAt[key] = date;
        metrics[key] = value;
      }
    }

    for (final point in points) {
      switch (point.type) {
        case HealthDataType.SLEEP_ASLEEP:
          sumMetric('sleep_asleep_min', _extractSleepMinutes(point));
          break;
        case HealthDataType.SLEEP_LIGHT:
          sumMetric('sleep_light_min', _extractSleepMinutes(point));
          break;
        case HealthDataType.SLEEP_DEEP:
          sumMetric('sleep_deep_min', _extractSleepMinutes(point));
          break;
        case HealthDataType.SLEEP_REM:
          sumMetric('sleep_rem_min', _extractSleepMinutes(point));
          break;
        case HealthDataType.RESTING_HEART_RATE:
          restingSamples.add(_extractNumericValue(point));
          break;
        case HealthDataType.RESPIRATORY_RATE:
          respiratorySamples.add(_extractNumericValue(point));
          break;
        case HealthDataType.BLOOD_OXYGEN:
          var value = _extractNumericValue(point);
          if (value <= 1.0) value *= 100;
          oxygenSamples.add(value);
          break;
        case HealthDataType.WATER:
          sumMetric('water_l', _extractNumericValue(point));
          break;
        case HealthDataType.NUTRITION:
          sumMetric('nutrition_entries', 1);
          break;
        case HealthDataType.WEIGHT:
          setLatestMetric(
              'weight_kg', _extractNumericValue(point), point.dateFrom);
          break;
        case HealthDataType.BODY_MASS_INDEX:
          setLatestMetric('bmi', _extractNumericValue(point), point.dateFrom);
          break;
        case HealthDataType.BODY_FAT_PERCENTAGE:
          var value = _extractNumericValue(point);
          if (value <= 1.0) value *= 100;
          setLatestMetric('body_fat_pct', value, point.dateFrom);
          break;
        case HealthDataType.BLOOD_PRESSURE_SYSTOLIC:
          setLatestMetric(
            'blood_pressure_systolic_mmhg',
            _extractNumericValue(point),
            point.dateFrom,
          );
          break;
        case HealthDataType.BLOOD_PRESSURE_DIASTOLIC:
          setLatestMetric(
            'blood_pressure_diastolic_mmhg',
            _extractNumericValue(point),
            point.dateFrom,
          );
          break;
        case HealthDataType.BLOOD_GLUCOSE:
          setLatestMetric(
            'blood_glucose_mg_dl',
            _extractNumericValue(point),
            point.dateFrom,
          );
          break;
        default:
          break;
      }
    }

    metrics['resting_hr_bpm_avg'] = _avg(restingSamples);
    metrics['respiratory_rate_avg'] = _avg(respiratorySamples);
    metrics['blood_oxygen_pct_avg'] = _avg(oxygenSamples);
    return metrics;
  }

  double _avg(List<double> values) {
    if (values.isEmpty) return 0;
    final sum = values.fold<double>(0, (a, b) => a + b);
    return sum / values.length;
  }

  num _metricFromRow(Map<String, dynamic>? row, String key) {
    if (row == null) return 0;
    final metrics = row['metrics'];
    if (metrics is Map) {
      final value = metrics[key];
      if (value is num) return value;
      if (value is String) return num.tryParse(value) ?? 0;
    }
    final fallback = row[key];
    if (fallback is num) return fallback;
    if (fallback is String) return num.tryParse(fallback) ?? 0;
    return 0;
  }

  Map<String, num> _metricsForDate(
    DateTime date,
    List<Map<String, dynamic>> rows,
  ) {
    final key = _dateKey(date);
    final row = rows.firstWhere(
      (item) => item['date_key']?.toString() == key,
      orElse: () => const <String, dynamic>{},
    );
    if (row.isEmpty) return const <String, num>{};

    final metricsRaw = row['metrics'];
    if (metricsRaw is Map) {
      final parsed = <String, num>{};
      metricsRaw.forEach((k, v) {
        if (v is num) {
          parsed['$k'] = v;
        } else if (v is String) {
          final n = num.tryParse(v);
          if (n != null) parsed['$k'] = n;
        }
      });
      if (parsed.isNotEmpty) return parsed;
    }

    return <String, num>{
      'steps': _metricFromRow(row, 'steps'),
      'heart_points': _metricFromRow(row, 'heart_points'),
    };
  }

  Future<void> _showManualIngestion(
      BuildContext context, SecretKey? secretKey) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ManualIngestionBottomSheet(secretKey: secretKey),
    );

    await _loadRecentActivities();
  }

  // Changed dynamic ref to WidgetRef for type safety
  Future<void> _unlockVault(WidgetRef ref) async {
    final LocalAuthentication auth = LocalAuthentication();
    const storage = FlutterSecureStorage();
    String? finalPassphrase;

    try {
      // 1. Check if biometrics are available and configured
      final bool canAuthenticateWithBiometrics = await auth.canCheckBiometrics;
      final bool isDeviceSupported = await auth.isDeviceSupported();

      if (canAuthenticateWithBiometrics && isDeviceSupported) {
        // 2. Attempt biometric authentication
        final bool didAuthenticate = await auth.authenticate(
          localizedReason: 'Scan fingerprint to unlock your health dashboard',
          options: const AuthenticationOptions(
            stickyAuth: true,
            biometricOnly: true, // Forces fingerprint/face specifically
          ),
        );

        if (didAuthenticate) {
          // 3. Retrieve the saved passphrase from the secure hardware enclave
          finalPassphrase = await storage.read(key: 'vault_passphrase');
        }
      }
    } catch (e) {
      debugPrint('Biometric authentication error: $e');
      // Fallback to manual if biometrics error out
    }

    // 4. Fallback: If biometrics failed or no passphrase was saved yet, show Dialog
    if (finalPassphrase == null) {
      final TextEditingController passphraseController =
          TextEditingController();
      finalPassphrase = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Unlock Vault'),
          content: TextField(
            controller: passphraseController,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Master Passphrase'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(context).pop(passphraseController.text),
              child: const Text('Unlock'),
            ),
          ],
        ),
      );
    }

    // Exit if user cancelled manual dialog
    if (finalPassphrase == null || finalPassphrase.isEmpty) return;

    // 5. Try to initialize the Enclave with the passphrase
    final unlocked = await ref
        .read(securityEnclaveProvider.notifier)
        .initialize(finalPassphrase);

    if (!unlocked) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unlock failed. Invalid passphrase.')),
        );
      }
      return;
    }

    // 6. Success! If this was a manual entry, save it for future biometric use
    await storage.write(key: 'vault_passphrase', value: finalPassphrase);

    // 7. Initialize background tasks if needed
    final tasksInitialized =
        sharedPrefs.getBool('bg_tasks_initialized') ?? false;
    if (!tasksInitialized) {
      await AppState.of(context, listen: false).initializeBackgroundTasks();
      await sharedPrefs.setBool('bg_tasks_initialized', true);
    }

    HapticFeedback.mediumImpact();
    await _loadHealthData();
  }

  Future<void> _toggleGpsTracking() async {
    if (_gpsSnapshot.isTracking) {
      await _gpsTrackingService.stop();
      return;
    }

    try {
      await _gpsTrackingService.start();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('GPS tracking unavailable: $e')),
      );
    }
  }

  Future<void> _openProfilePage(SecretKey? secretKey) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ProfilePage(
          isSyncing: _isSyncing,
          isPulling: _isPulling,
          isDeletingData: _isDeletingData,
          onSync: () => _syncEncryptedVault(secretKey),
          onPull: () => _pullEncryptedVault(secretKey),
          onDeleteData: () => _promptDeleteData(secretKey),
        ),
      ),
    );
  }

  Future<void> _syncEncryptedVault(SecretKey? secretKey) async {
    if (_isSyncing) return;
    if (secretKey == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unlock vault before syncing.')),
      );
      return;
    }

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in to sync with cloud vault.')),
      );
      return;
    }

    setState(() => _isSyncing = true);
    try {
      final payload = await _buildCloudVaultPayload(secretKey);
      final payloadJson = jsonEncode(payload);
      final encryptedPayload = await EncryptionService().encryptString(
        payloadJson,
        secretKey,
      );
      await SupabaseService().upsertEncryptedVaultBlobForCurrentUser(
        encryptedPayload,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Sync complete: ${payload['workouts_count']} workouts, ${payload['steps_count']} step records.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cloud sync failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  Future<Map<String, dynamic>> _buildCloudVaultPayload(
    SecretKey secretKey,
  ) async {
    final encryptedRows = await LocalVault().fetchWorkouts(secretKey);
    final workouts = <Map<String, dynamic>>[];
    for (final row in encryptedRows) {
      try {
        final decrypted =
            await EncryptionService().decryptString(row, secretKey);
        final decoded = jsonDecode(decrypted);
        if (decoded is Map<String, dynamic>) {
          workouts.add(decoded);
        } else if (decoded is Map) {
          workouts.add(decoded.map((k, v) => MapEntry('$k', v)));
        }
      } catch (_) {
        // Skip malformed workout entries.
      }
    }

    final steps = _healthData
        .where((point) => point.type == HealthDataType.STEPS)
        .map((point) => <String, dynamic>{
              'timestamp': point.dateFrom.toUtc().toIso8601String(),
              'value': _extractNumericValue(point).toInt(),
              'source': point.sourceId,
            })
        .toList(growable: false);

    final heartRecords = _healthData
        .where((point) =>
            point.type == HealthDataType.EXERCISE_TIME ||
            point.type == HealthDataType.WORKOUT ||
            point.type == HealthDataType.HEART_RATE)
        .map((point) {
      if (point.type == HealthDataType.EXERCISE_TIME ||
          point.type == HealthDataType.WORKOUT) {
        return <String, dynamic>{
          'timestamp': point.dateFrom.toUtc().toIso8601String(),
          'metric': 'exercise_time_min',
          'value': _extractExerciseMinutes(point),
        };
      }
      final value = _extractNumericValue(point);
      return <String, dynamic>{
        'timestamp': point.dateFrom.toUtc().toIso8601String(),
        'metric': 'heart_rate_bpm',
        'value': value.toInt(),
        'derived_points': _calculateHeartPointsFromHeartRate(value, 1),
      };
    }).toList(growable: false);
    final dailyMetrics = await LocalVault().fetchDailyMetrics(secretKey);
    final dailyMetricMap = <String, Map<String, num>>{};
    for (final row in dailyMetrics) {
      final dateKey = row['date_key']?.toString();
      if (dateKey == null || dateKey.isEmpty) continue;
      final metricsRaw = row['metrics'];
      if (metricsRaw is Map) {
        final parsed = <String, num>{};
        metricsRaw.forEach((k, v) {
          if (v is num) {
            parsed['$k'] = v;
          } else if (v is String) {
            final n = num.tryParse(v);
            if (n != null) parsed['$k'] = n;
          }
        });
        if (parsed.isNotEmpty) {
          dailyMetricMap[dateKey] = parsed;
        }
      }
    }

    return {
      'version': 2,
      'synced_at': DateTime.now().toUtc().toIso8601String(),
      'workouts_count': workouts.length,
      'steps_count': steps.length,
      'heart_points_total': _heartPointsTotal,
      'daily_metrics': dailyMetrics,
      'daily_metric_map': dailyMetricMap,
      'workouts': workouts,
      'steps': steps,
      'heart_points': {
        'total': _heartPointsTotal,
        'records': heartRecords,
      },
    };
  }

  List<Map<String, dynamic>> _buildDailyMetricsFromPayload(
    Map<String, dynamic> payload,
  ) {
    Map<String, num> parseMetricMap(dynamic raw) {
      if (raw is! Map) return const <String, num>{};
      final parsed = <String, num>{};
      raw.forEach((key, value) {
        if (value is num) {
          parsed['$key'] = value;
        } else if (value is String) {
          final n = num.tryParse(value);
          if (n != null) parsed['$key'] = n;
        }
      });
      return parsed;
    }

    final fromPayload = <Map<String, dynamic>>[];
    final dailyMetricMapRaw = payload['daily_metric_map'];
    if (dailyMetricMapRaw is Map) {
      dailyMetricMapRaw.forEach((key, value) {
        final dateKey = key.toString();
        if (dateKey.isEmpty) return;
        final parsed = parseMetricMap(value);
        if (parsed.isEmpty) return;
        fromPayload.add({
          'date_key': dateKey,
          'metrics': parsed,
          'steps': (parsed['steps'] ?? 0).toInt(),
          'heart_points': (parsed['heart_points'] ?? 0).toInt(),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        });
      });
    }

    final dailyRaw = payload['daily_metrics'];
    if (dailyRaw is List) {
      for (final row in dailyRaw) {
        if (row is! Map) continue;
        final dateKey = row['date_key']?.toString();
        if (dateKey == null || dateKey.isEmpty) continue;
        var metrics = parseMetricMap(row['metrics']);
        if (metrics.isEmpty) {
          metrics = <String, num>{
            'steps': (row['steps'] as num?) ?? 0,
            'heart_points': (row['heart_points'] as num?) ?? 0,
          };
        }
        fromPayload.add({
          'date_key': dateKey,
          'metrics': metrics,
          'steps': (metrics['steps'] ?? 0).toInt(),
          'heart_points': (metrics['heart_points'] ?? 0).toInt(),
          'updated_at': row['updated_at']?.toString() ??
              DateTime.now().toUtc().toIso8601String(),
        });
      }
    }

    if (fromPayload.isNotEmpty) {
      final deduped = <String, Map<String, dynamic>>{};
      for (final row in fromPayload) {
        final key = row['date_key']?.toString();
        if (key == null || key.isEmpty) continue;
        deduped[key] = row;
      }
      final values = deduped.values.toList(growable: false)
        ..sort((a, b) =>
            (b['date_key'] as String).compareTo(a['date_key'] as String));
      return values;
    }

    final merged = <String, Map<String, dynamic>>{};
    final stepsRaw = payload['steps'];
    if (stepsRaw is List) {
      for (final row in stepsRaw) {
        if (row is! Map) continue;
        final timestamp =
            DateTime.tryParse((row['timestamp'] ?? '').toString());
        if (timestamp == null) continue;
        final key = _dateKey(timestamp);
        final existing = merged[key] ??
            <String, dynamic>{
              'date_key': key,
              'metrics': <String, num>{'steps': 0, 'heart_points': 0},
              'updated_at': DateTime.now().toUtc().toIso8601String(),
            };
        final metrics = existing['metrics'] as Map<String, num>;
        metrics['steps'] =
            (metrics['steps'] ?? 0) + ((row['value'] as num?) ?? 0);
        existing['steps'] = (metrics['steps'] ?? 0).toInt();
        existing['heart_points'] = (metrics['heart_points'] ?? 0).toInt();
        merged[key] = existing;
      }
    }

    final heartRaw = payload['heart_points'];
    if (heartRaw is Map) {
      final records = heartRaw['records'];
      if (records is List) {
        for (final row in records) {
          if (row is! Map) continue;
          final timestamp =
              DateTime.tryParse((row['timestamp'] ?? '').toString());
          if (timestamp == null) continue;
          final key = _dateKey(timestamp);
          final existing = merged[key] ??
              <String, dynamic>{
                'date_key': key,
                'metrics': <String, num>{'steps': 0, 'heart_points': 0},
                'updated_at': DateTime.now().toUtc().toIso8601String(),
              };
          final metrics = existing['metrics'] as Map<String, num>;
          var pointsToAdd = 0;
          if (row['metric'] == 'exercise_time_min') {
            pointsToAdd = (row['value'] as num?)?.toInt() ?? 0;
          } else if (row['metric'] == 'heart_rate_bpm') {
            pointsToAdd = (row['derived_points'] as num?)?.toInt() ?? 0;
          }
          metrics['heart_points'] =
              (metrics['heart_points'] ?? 0) + pointsToAdd;
          existing['steps'] = (metrics['steps'] ?? 0).toInt();
          existing['heart_points'] = (metrics['heart_points'] ?? 0).toInt();
          merged[key] = existing;
        }
      }
    }

    final values = merged.values.toList(growable: false)
      ..sort((a, b) =>
          (b['date_key'] as String).compareTo(a['date_key'] as String));
    return values;
  }

  Future<void> _pullEncryptedVault(SecretKey? secretKey) async {
    if (_isPulling) return;
    if (secretKey == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Unlock vault before pulling cloud data.')),
      );
      return;
    }

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in to pull cloud vault data.')),
      );
      return;
    }

    setState(() => _isPulling = true);
    try {
      final encryptedBlob =
          await SupabaseService().fetchEncryptedVaultBlobForCurrentUser();
      if (encryptedBlob == null || encryptedBlob.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No cloud vault backup found yet.')),
        );
        return;
      }

      String payloadJson;
      try {
        payloadJson = await EncryptionService().decryptString(
          encryptedBlob,
          secretKey,
        );
      } catch (_) {
        // Backward compatibility for older unencrypted JSON cloud payloads.
        payloadJson = encryptedBlob;
      }

      final decoded = jsonDecode(payloadJson);
      if (decoded is! Map) {
        throw StateError('Cloud payload format is invalid.');
      }
      final payload = decoded.map((k, v) => MapEntry('$k', v));

      final workoutsRaw = payload['workouts'];
      final workouts = <Map<String, dynamic>>[];
      if (workoutsRaw is List) {
        for (final item in workoutsRaw) {
          if (item is Map<String, dynamic>) {
            workouts.add(item);
          } else if (item is Map) {
            workouts.add(item.map((k, v) => MapEntry('$k', v)));
          }
        }
      }

      final restoredEncryptedRows = <String>[];
      for (final workout in workouts) {
        final encryptedWorkout = await EncryptionService().encryptString(
          jsonEncode(workout),
          secretKey,
        );
        restoredEncryptedRows.add(encryptedWorkout);
      }
      await LocalVault().replaceWorkouts(restoredEncryptedRows, secretKey);
      final pulledDailyMetrics = _buildDailyMetricsFromPayload(payload);
      await LocalVault().replaceDailyMetrics(pulledDailyMetrics, secretKey);

      var pulledHeartTotal = 0;
      final heartPointsRaw = payload['heart_points'];
      if (heartPointsRaw is Map && heartPointsRaw['total'] is num) {
        pulledHeartTotal = (heartPointsRaw['total'] as num).toInt();
      } else if (payload['heart_points_total'] is num) {
        pulledHeartTotal = (payload['heart_points_total'] as num).toInt();
      }

      workouts.sort((a, b) {
        final aTs = DateTime.tryParse(
              (a['timestamp'] ?? a['date'] ?? '').toString(),
            ) ??
            DateTime.fromMillisecondsSinceEpoch(0);
        final bTs = DateTime.tryParse(
              (b['timestamp'] ?? b['date'] ?? '').toString(),
            ) ??
            DateTime.fromMillisecondsSinceEpoch(0);
        return bTs.compareTo(aTs);
      });

      if (!mounted) return;
      final pulledTodayMetrics =
          _metricsForDate(DateTime.now(), pulledDailyMetrics);
      if (pulledHeartTotal <= 0) {
        pulledHeartTotal = (pulledTodayMetrics['heart_points'])?.toInt() ?? 0;
      }
      setState(() {
        if (pulledHeartTotal > 0) {
          _heartPointsTotal = pulledHeartTotal;
        }
        _recentActivities = workouts.take(3).toList(growable: false);
        _dailyMetrics = pulledDailyMetrics;
        if (pulledTodayMetrics.isNotEmpty) {
          _todayMetrics = pulledTodayMetrics;
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Pull complete: ${workouts.length} workouts restored.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cloud pull failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _isPulling = false);
    }
  }

  Future<void> _promptDeleteData(SecretKey? secretKey) async {
    final selectedScope = await showDialog<_DeleteDataScope>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete data'),
        content: const Text(
          'Choose what to delete: cloud data, local data, or all data.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(_DeleteDataScope.cloud),
            child: const Text('Cloud data'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(_DeleteDataScope.local),
            child: const Text('Local data'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(_DeleteDataScope.all),
            child: const Text('All data'),
          ),
        ],
      ),
    );

    if (selectedScope == null) return;
    await _deleteDataForScope(selectedScope, secretKey);
  }

  Future<void> _deleteDataForScope(
    _DeleteDataScope scope,
    SecretKey? secretKey,
  ) async {
    if (_isDeletingData) return;

    final needsCloudDelete =
        scope == _DeleteDataScope.cloud || scope == _DeleteDataScope.all;
    final needsLocalDelete =
        scope == _DeleteDataScope.local || scope == _DeleteDataScope.all;

    if (needsLocalDelete && secretKey == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Unlock vault before deleting local data.')),
      );
      return;
    }

    final user = Supabase.instance.client.auth.currentUser;
    if (needsCloudDelete && user == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in before deleting cloud data.')),
      );
      return;
    }

    setState(() => _isDeletingData = true);
    try {
      if (needsCloudDelete) {
        await SupabaseService().deleteEncryptedVaultDataForCurrentUser();
      }
      if (needsLocalDelete) {
        await LocalVault().clearWorkouts(secretKey!);
      }

      await _loadRecentActivities();
      await _loadDailyMetrics();

      if (!mounted) return;
      setState(() {
        _recentActivities = [];
        _dailyMetrics = [];
        _todayMetrics = const <String, num>{};
      });

      final statusText = switch (scope) {
        _DeleteDataScope.cloud => 'Cloud vault data deleted.',
        _DeleteDataScope.local => 'Local vault data deleted.',
        _DeleteDataScope.all => 'Cloud and local vault data deleted.',
      };
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(statusText)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Delete failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _isDeletingData = false);
    }
  }

  String _formatElapsed(Duration duration) {
    final mins = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final secs = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '${duration.inHours.toString().padLeft(2, '0')}:$mins:$secs';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // With ConsumerState, we watch providers directly without a 'Consumer' widget
    final secretKey = ref.watch(securityEnclaveProvider);
    final isLocked = secretKey == null;

    return SecurityBarrier(
      isLocked: isLocked,
      onUnlock: () => _unlockVault(ref),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Zero-Trust Health'),
          actions: [
            IconButton(
              icon: const Icon(Icons.person_outline),
              tooltip: 'Profile',
              onPressed: () => _openProfilePage(secretKey),
            ),
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              tooltip: 'Permissions Center',
              onPressed: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const PermissionsPage(),
                  ),
                );
                await _loadHealthData();
              },
            ),
            IconButton(
              icon: const Icon(Icons.lock_outline_rounded),
              onPressed: () async {
                HapticFeedback.heavyImpact();
                await ref.read(securityEnclaveProvider.notifier).lock();
                setState(() => _recentActivities = []);
                await WidgetService.redactWidget();
              },
            ),
          ],
        ),
        body: _isLoading
            ? const Center(child: ShimmerLoader())
            : SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildMetricHighlights(theme),
                    const SizedBox(height: 16),
                    _buildAllMetricsSection(theme),
                    const SizedBox(height: 20),
                    _buildAnalyticsSection(theme),
                    const SizedBox(height: 24),
                    _buildGpsTrackingSection(theme),
                    const SizedBox(height: 32),
                    Text(
                      'Recent Activity',
                      style: theme.textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    _buildActivityFeed(theme),
                  ],
                ),
              ),
        floatingActionButton: FloatingActionButton(
          onPressed: () async => _showManualIngestion(context, secretKey),
          backgroundColor: theme.colorScheme.primary,
          foregroundColor: Colors.white,
          child: const Icon(Icons.add),
        ),
      ),
    );
  }

  Widget _buildAnalyticsSection(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary.withValues(alpha: 0.15),
            theme.colorScheme.secondary.withValues(alpha: 0.18),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Analytics', style: theme.textTheme.titleMedium),
              const Icon(Icons.insights, color: Color(0xFF6366F1)),
            ],
          ),
          const SizedBox(height: 24),
          Text('Steps & Heart Points Trend (Hourly)',
              style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          SizedBox(
            height: 220,
            child: _buildDualMetricBarChart(
              points: _buildHourlyTrendPoints(),
              stepColor: const Color(0xFF5B7CFF),
              heartColor: const Color(0xFFFF5D7A),
              xLabelInterval: 1,
            ),
          ),
          const SizedBox(height: 18),
          Text('Current Week (Sunday to Saturday)',
              style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          SizedBox(
            height: 220,
            child: _buildDualMetricBarChart(
              points: _buildCurrentWeekPoints(),
              stepColor: const Color(0xFF5B7CFF),
              heartColor: const Color(0xFFFF5D7A),
              xLabelInterval: 1,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: Text('Selected Metric Trend (Week)',
                    style: theme.textTheme.labelLarge),
              ),
              const SizedBox(width: 10),
              DropdownButton<String>(
                value: _selectedTrendMetricKey,
                items: _metricCardSpecs
                    .map(
                      (spec) => DropdownMenuItem<String>(
                        value: spec.key,
                        child: Text(spec.title),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _selectedTrendMetricKey = value);
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 220,
            child: _buildSingleMetricBarChart(
              points: _buildSelectedMetricWeekPoints(),
              color: const Color(0xFF10B981),
            ),
          ),
        ],
      ),
    );
  }

  List<_DualMetricPoint> _buildHourlyTrendPoints() {
    final now = DateTime.now();
    final todayData = _healthData
        .where((p) => _isSameLocalDay(p.dateFrom, now))
        .toList(growable: false);
    if (todayData.isEmpty) return const [];

    final hasExerciseTime = todayData.any((point) =>
        point.type == HealthDataType.EXERCISE_TIME ||
        point.type == HealthDataType.WORKOUT);
    final byHour = <int, Map<String, double>>{};
    for (final point in todayData) {
      final hour = point.dateFrom.toLocal().hour;
      final bucket = byHour.putIfAbsent(hour, () => {'steps': 0, 'heart': 0});
      if (point.type == HealthDataType.STEPS) {
        bucket['steps'] = (bucket['steps'] ?? 0) + _extractNumericValue(point);
      } else if (hasExerciseTime &&
          (point.type == HealthDataType.EXERCISE_TIME ||
              point.type == HealthDataType.WORKOUT)) {
        bucket['heart'] =
            (bucket['heart'] ?? 0) + _extractExerciseMinutes(point);
      } else if (!hasExerciseTime && point.type == HealthDataType.HEART_RATE) {
        final bpm = _extractNumericValue(point);
        bucket['heart'] =
            (bucket['heart'] ?? 0) + _calculateHeartPointsFromHeartRate(bpm, 1);
      }
    }

    final hours = byHour.keys.toList()..sort();
    return hours
        .map(
          (hour) => _DualMetricPoint(
            label: _hourLabel(hour),
            steps: byHour[hour]?['steps'] ?? 0,
            heartPoints: byHour[hour]?['heart'] ?? 0,
          ),
        )
        .toList(growable: false);
  }

  List<_DualMetricPoint> _buildCurrentWeekPoints() {
    final today = DateTime.now();
    final currentDay = DateTime(today.year, today.month, today.day);
    final daysSinceSunday = currentDay.weekday % 7;
    final weekStartSunday =
        currentDay.subtract(Duration(days: daysSinceSunday));
    final byDate = <String, Map<String, dynamic>>{};
    for (final row in _dailyMetrics) {
      final key = row['date_key']?.toString();
      if (key == null || key.isEmpty) continue;
      byDate[key] = row;
    }

    const labels = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    return List.generate(7, (index) {
      final date = weekStartSunday.add(Duration(days: index));
      final key = _dateKey(date);
      final row = byDate[key];
      return _DualMetricPoint(
        label: labels[index],
        steps: _metricFromRow(row, 'steps').toDouble(),
        heartPoints: _metricFromRow(row, 'heart_points').toDouble(),
      );
    }, growable: false);
  }

  List<_SingleMetricPoint> _buildSelectedMetricWeekPoints() {
    final today = DateTime.now();
    final currentDay = DateTime(today.year, today.month, today.day);
    final daysSinceSunday = currentDay.weekday % 7;
    final weekStartSunday =
        currentDay.subtract(Duration(days: daysSinceSunday));
    final byDate = <String, Map<String, dynamic>>{};
    for (final row in _dailyMetrics) {
      final key = row['date_key']?.toString();
      if (key == null || key.isEmpty) continue;
      byDate[key] = row;
    }

    const labels = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    return List.generate(7, (index) {
      final date = weekStartSunday.add(Duration(days: index));
      final key = _dateKey(date);
      final row = byDate[key];
      return _SingleMetricPoint(
        label: labels[index],
        value: _metricFromRow(row, _selectedTrendMetricKey).toDouble(),
      );
    }, growable: false);
  }

  String _hourLabel(int hour) {
    final suffix = hour >= 12 ? 'pm' : 'am';
    final normalized = hour % 12 == 0 ? 12 : hour % 12;
    return '$normalized:00 $suffix';
  }

  Widget _buildDualMetricBarChart({
    required List<_DualMetricPoint> points,
    required Color stepColor,
    required Color heartColor,
    int xLabelInterval = 1,
  }) {
    if (points.isEmpty) {
      return const Center(child: Text('No data yet'));
    }

    final maxY = points
        .map((point) =>
            point.steps > point.heartPoints ? point.steps : point.heartPoints)
        .fold<double>(0, (current, value) => value > current ? value : current);
    final axisMax = maxY <= 0 ? 10.0 : (maxY * 1.2).ceilToDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _buildLegendChip(color: stepColor, label: 'Steps'),
            const SizedBox(width: 8),
            _buildLegendChip(color: heartColor, label: 'Heart Points'),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: BarChart(
            BarChartData(
              maxY: axisMax,
              minY: 0,
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (_) => FlLine(
                  color: Colors.white.withValues(alpha: 0.08),
                  strokeWidth: 1,
                ),
              ),
              borderData: FlBorderData(show: false),
              groupsSpace: 10,
              barGroups: points.asMap().entries.map((entry) {
                final i = entry.key;
                final point = entry.value;
                return BarChartGroupData(
                  x: i,
                  barsSpace: 4,
                  barRods: [
                    BarChartRodData(
                      toY: point.steps,
                      width: 8,
                      borderRadius: BorderRadius.circular(3),
                      color: stepColor,
                    ),
                    BarChartRodData(
                      toY: point.heartPoints,
                      width: 8,
                      borderRadius: BorderRadius.circular(3),
                      color: heartColor,
                    ),
                  ],
                );
              }).toList(growable: false),
              titlesData: FlTitlesData(
                topTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 32,
                    interval: axisMax / 4,
                    getTitlesWidget: (value, meta) => Text(
                      value.toInt().toString(),
                      style: const TextStyle(fontSize: 10),
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 32,
                    getTitlesWidget: (value, meta) {
                      final index = value.toInt();
                      if (index < 0 || index >= points.length) {
                        return const SizedBox.shrink();
                      }
                      if (index % xLabelInterval != 0) {
                        return const SizedBox.shrink();
                      }
                      return SideTitleWidget(
                        meta: meta,
                        child: Text(points[index].label,
                            style: const TextStyle(fontSize: 10)),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSingleMetricBarChart({
    required List<_SingleMetricPoint> points,
    required Color color,
  }) {
    if (points.isEmpty) {
      return const Center(child: Text('No data yet'));
    }

    final maxY = points
        .map((point) => point.value)
        .fold<double>(0, (current, value) => value > current ? value : current);
    final axisMax = maxY <= 0 ? 10.0 : (maxY * 1.2).ceilToDouble();

    return BarChart(
      BarChartData(
        maxY: axisMax,
        minY: 0,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) => FlLine(
            color: Colors.white.withValues(alpha: 0.08),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        groupsSpace: 10,
        barGroups: points.asMap().entries.map((entry) {
          final i = entry.key;
          final point = entry.value;
          return BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: point.value,
                width: 14,
                borderRadius: BorderRadius.circular(4),
                color: color,
              ),
            ],
          );
        }).toList(growable: false),
        titlesData: FlTitlesData(
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              interval: axisMax / 4,
              getTitlesWidget: (value, meta) => Text(
                value.toInt().toString(),
                style: const TextStyle(fontSize: 10),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= points.length) {
                  return const SizedBox.shrink();
                }
                return SideTitleWidget(
                  meta: meta,
                  child: Text(points[index].label,
                      style: const TextStyle(fontSize: 10)),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLegendChip({
    required Color color,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildMetricHighlights(ThemeData theme) {
    final steps = (_todayMetrics['steps'] ?? 0).toInt().toString();
    final points =
        (_todayMetrics['heart_points'] ?? _heartPointsTotal).toInt().toString();
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            theme: theme,
            title: 'Steps Today',
            value: steps,
            icon: Icons.directions_walk,
            gradientColors: const [Color(0xFF3B82F6), Color(0xFF6366F1)],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            theme: theme,
            title: 'Heart Today',
            value: points,
            icon: Icons.favorite,
            gradientColors: const [Color(0xFFF43F5E), Color(0xFFFB7185)],
          ),
        ),
      ],
    );
  }

  Widget _buildExpandedMetricCards(ThemeData theme) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: _metricCardSpecs.map((spec) {
        final rawValue = _todayMetrics[spec.key] ?? 0;
        return SizedBox(
          width: (MediaQuery.of(context).size.width - 60) / 2,
          child: _buildCompactMetricCard(
            theme: theme,
            title: spec.title,
            value: _formatMetricValue(spec.key, rawValue, spec.unit),
            icon: spec.icon,
            gradientColors: spec.gradientColors,
          ),
        );
      }).toList(growable: false),
    );
  }

  Widget _buildAllMetricsSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.tonalIcon(
            onPressed: () => setState(() => _showAllMetrics = !_showAllMetrics),
            icon: Icon(
              _showAllMetrics
                  ? Icons.keyboard_arrow_up
                  : Icons.keyboard_arrow_down,
            ),
            label:
                Text(_showAllMetrics ? 'Hide all metrics' : 'Show all metrics'),
          ),
        ),
        const SizedBox(height: 10),
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 220),
          firstCurve: Curves.easeInOut,
          secondCurve: Curves.easeInOut,
          sizeCurve: Curves.easeInOut,
          crossFadeState: _showAllMetrics
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          firstChild: const SizedBox.shrink(),
          secondChild: _buildExpandedMetricCards(theme),
        ),
      ],
    );
  }

  String _formatMetricValue(String key, num value, String unit) {
    String text;
    if (key == 'nutrition_entries' || key == 'steps' || key == 'heart_points') {
      text = value.toInt().toString();
    } else if (key == 'blood_pressure_systolic_mmhg' ||
        key == 'blood_pressure_diastolic_mmhg') {
      text = value.toInt().toString();
    } else if (key == 'weight_kg' || key == 'bmi') {
      text = value.toStringAsFixed(1);
    } else if (key.endsWith('_pct') || key.contains('oxygen')) {
      text = value.toStringAsFixed(1);
    } else if (key == 'water_l') {
      text = value.toStringAsFixed(2);
    } else {
      text = value.toStringAsFixed(1);
    }
    if (unit.isEmpty) return text;
    return '$text $unit';
  }

  Widget _buildCompactMetricCard({
    required ThemeData theme,
    required String title,
    required String value,
    required IconData icon,
    required List<Color> gradientColors,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.white.withValues(alpha: 0.95)),
          const SizedBox(height: 8),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.9),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required ThemeData theme,
    required String title,
    required String value,
    required IconData icon,
    required List<Color> gradientColors,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white.withValues(alpha: 0.95)),
          const SizedBox(height: 12),
          Text(
            value,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.9),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGpsTrackingSection(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Real-time GPS', style: theme.textTheme.titleMedium),
              FilledButton.icon(
                onPressed: _toggleGpsTracking,
                icon: Icon(
                    _gpsSnapshot.isTracking ? Icons.stop : Icons.play_arrow),
                label: Text(_gpsSnapshot.isTracking ? 'Stop' : 'Start'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
              'Distance: ${(_gpsSnapshot.distanceMeters / 1000).toStringAsFixed(2)} km'),
          Text('Elapsed: ${_formatElapsed(_gpsSnapshot.elapsed)}'),
          Text(
              'Pace: ${_gpsSnapshot.currentPaceMinutesPerKm.toStringAsFixed(2)} min/km'),
        ],
      ),
    );
  }

  Widget _buildActivityFeed(ThemeData theme) {
    if (_recentActivities.isEmpty) {
      return Card(
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: theme.colorScheme.secondary.withOpacity(0.1),
            child:
                Icon(Icons.inbox_outlined, color: theme.colorScheme.secondary),
          ),
          title: const Text('No recent activities'),
          subtitle: const Text('Add one manually or sync from health data.'),
        ),
      );
    }

    return Column(
      children: _recentActivities.map((activity) {
        final title = _activityTitle(activity);
        final subtitle = _activitySubtitle(activity);
        final tag = _activityTag(activity);
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: theme.colorScheme.secondary.withOpacity(0.1),
              child: Icon(_activityIcon(activity),
                  color: theme.colorScheme.secondary),
            ),
            title: Text(title),
            subtitle: Text(subtitle),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.withOpacity(0.5)),
              ),
              child: Text(
                tag,
                style: TextStyle(
                    color: Colors.green,
                    fontSize: 10,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  String _activityTitle(Map<String, dynamic> activity) {
    final rawType = (activity['type'] ?? 'Activity').toString();
    if (rawType.startsWith('HealthDataType.')) {
      final normalized = rawType
          .replaceFirst('HealthDataType.', '')
          .replaceAll('_', ' ')
          .toLowerCase();
      return normalized
          .split(' ')
          .where((part) => part.isNotEmpty)
          .map((part) => part[0].toUpperCase() + part.substring(1))
          .join(' ');
    }
    return rawType;
  }

  String _activitySubtitle(Map<String, dynamic> activity) {
    final timestampRaw = activity['timestamp'] ?? activity['date'];
    final parsedTimestamp = timestampRaw is String
        ? DateTime.tryParse(timestampRaw)?.toLocal()
        : null;

    final timeText = parsedTimestamp == null
        ? 'Unknown time'
        : '${parsedTimestamp.year.toString().padLeft(4, '0')}-'
            '${parsedTimestamp.month.toString().padLeft(2, '0')}-'
            '${parsedTimestamp.day.toString().padLeft(2, '0')} '
            '${parsedTimestamp.hour.toString().padLeft(2, '0')}:'
            '${parsedTimestamp.minute.toString().padLeft(2, '0')}';

    final duration = activity['duration'];
    final intensity = activity['intensity'];
    if (duration != null) {
      final intensityText = intensity == null ? 'n/a' : '$intensity/10';
      return '$duration min, intensity $intensityText, $timeText';
    }

    final value = activity['value'];
    if (value != null) {
      return 'Value: $value, $timeText';
    }

    return timeText;
  }

  String _activityTag(Map<String, dynamic> activity) {
    if (activity.containsKey('duration')) {
      return 'MANUAL';
    }
    return 'AUTO';
  }

  IconData _activityIcon(Map<String, dynamic> activity) {
    final type = _activityTitle(activity).toLowerCase();
    if (type.contains('run')) return Icons.directions_run;
    if (type.contains('walk')) return Icons.directions_walk;
    if (type.contains('cycl')) return Icons.directions_bike;
    if (type.contains('swim')) return Icons.pool;
    if (type.contains('heart')) return Icons.favorite;
    if (type.contains('step')) return Icons.hiking;
    return Icons.bolt;
  }
}
