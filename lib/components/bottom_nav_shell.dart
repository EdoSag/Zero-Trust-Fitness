import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:cryptography/cryptography.dart';
import 'package:health/health.dart';
import 'package:local_auth/local_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:zerotrust_fitness/components/security_barrier.dart';
import 'package:zerotrust_fitness/components/error_state_widget.dart';
import 'package:zerotrust_fitness/core/security/encryption_service.dart';
import 'package:zerotrust_fitness/core/services/supabase_service.dart';
import 'package:zerotrust_fitness/core/storage/local_vault.dart';
import 'package:zerotrust_fitness/features/achievements/domain/achievement_definition.dart';
import 'package:zerotrust_fitness/features/achievements/domain/achievement_service.dart';
import 'package:zerotrust_fitness/features/app/providers.dart';
import 'package:zerotrust_fitness/features/dashboard/metric_card_specs.dart';
import 'package:zerotrust_fitness/features/goals/goals_provider.dart';
import 'package:zerotrust_fitness/features/health/data/gps_tracking_service.dart';
import 'package:zerotrust_fitness/features/health/data/health_service.dart';
import 'package:zerotrust_fitness/globals/app_state.dart';
import 'package:zerotrust_fitness/heart_point_calculator.dart';
import 'package:zerotrust_fitness/components/manual_ingestion_bottom_sheet.dart';
import 'package:zerotrust_fitness/main.dart';
import 'package:zerotrust_fitness/pages/activities_page.dart';
import 'package:zerotrust_fitness/pages/gps_workout_page.dart';
import 'package:zerotrust_fitness/pages/permissions_page.dart';
import 'package:zerotrust_fitness/pages/profile_page.dart';
import 'package:zerotrust_fitness/pages/today_page.dart';
import 'package:zerotrust_fitness/pages/trends_page.dart';
import 'package:zerotrust_fitness/widget_service.dart';

enum _DeleteDataScope { cloud, local, all }

class BottomNavShell extends ConsumerStatefulWidget {
  const BottomNavShell({super.key, this.initialIndex = 0});

  final int initialIndex;

  @override
  ConsumerState<BottomNavShell> createState() => _BottomNavShellState();
}

class _BottomNavShellState extends ConsumerState<BottomNavShell>
    with WidgetsBindingObserver {
  int _currentIndex = 0;

  // --- data state (moved from _DashboardPageState) ---
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
  Set<String> _unreadableMetricKeys = const {};
  List<UnlockedAchievement> _earnedMedals = [];
  DateTime? _lastBackupAt;

  // --- auto-lock ---
  static const String _kAutoLockKey = 'auto_lock_minutes';
  int _autoLockMinutes = 5; // 0 = never
  DateTime _lastInteractionAt = DateTime.now();
  bool _isObscured = false; // blur overlay when backgrounded

  GpsTrackingSnapshot _gpsSnapshot = GpsTrackingSnapshot(
    distanceMeters: 0,
    elapsed: Duration.zero,
    currentPaceMinutesPerKm: 0,
    isTracking: false,
    isPaused: false,
    routePoints: const [],
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _currentIndex = widget.initialIndex;
    _gpsTrackingService.snapshots.listen((snapshot) {
      if (!mounted) return;
      setState(() => _gpsSnapshot = snapshot);
    });
    _loadAutoLockSetting();
    _loadHealthData();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      if (mounted) setState(() => _isObscured = true);
    } else if (state == AppLifecycleState.resumed) {
      if (mounted) setState(() => _isObscured = false);
      _checkInactivity();
    }
  }

  Future<void> _loadAutoLockSetting() async {
    final prefs = await SharedPreferences.getInstance();
    final minutes = prefs.getInt(_kAutoLockKey) ?? 5;
    if (mounted) setState(() => _autoLockMinutes = minutes);
  }

  Future<void> saveAutoLockSetting(int minutes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kAutoLockKey, minutes);
    if (mounted) setState(() => _autoLockMinutes = minutes);
  }

  void _resetInteraction() {
    _lastInteractionAt = DateTime.now();
  }

  void _checkInactivity() {
    if (_autoLockMinutes == 0) return;
    final idle = DateTime.now().difference(_lastInteractionAt);
    if (idle.inMinutes >= _autoLockMinutes) {
      ref.read(securityEnclaveProvider.notifier).lock();
    }
  }

  // ---------------------------------------------------------------------------
  // Data loading
  // ---------------------------------------------------------------------------

  Future<void> _loadHealthData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final healthService = HealthService();
      final isAvailable = await healthService.isHealthConnectAvailable();
      if (!isAvailable) {
        if (mounted) setState(() => _healthData = []);
        await _loadDailyMetrics();
        return;
      }

      final readableTypes = await _getReadableHealthTypes();
      final unreadableKeys = _buildUnreadableKeys(readableTypes);
      if (mounted) setState(() => _unreadableMetricKeys = unreadableKeys);

      if (readableTypes.isEmpty) {
        if (mounted) {
          setState(() {
            _healthData = [];
            _heartPointsTotal = 0;
          });
        }
        await _loadDailyMetrics();
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
        final hcWorkoutPoints = todayPoints
            .where((p) => p.type == HealthDataType.WORKOUT)
            .toList(growable: false);
        final manualWorkoutsToday =
            await _loadTodayManualWorkouts(secretKey);
        final unmatchedManualHp = _computeUnmatchedManualHeartPoints(
          hcWorkoutPoints: hcWorkoutPoints,
          manualWorkouts: manualWorkoutsToday,
        );
        final Map<String, num> manualOverrides = {};
        if (manualWorkoutsToday.isNotEmpty) {
          manualOverrides['heart_points'] = unmatchedManualHp;
        }
        await LocalVault().syncFromHealthConnect(
          dateKey: _dateKey(DateTime.now()),
          hcMetrics: todayMetrics,
          manualContributions: manualOverrides,
          secretKey: secretKey,
        );
        final vaultRows = await LocalVault().fetchDailyMetrics(secretKey);
        final combinedToday = _metricsForDate(DateTime.now(), vaultRows);
        if (mounted && combinedToday.isNotEmpty) {
          setState(() {
            _todayMetrics = combinedToday;
            _heartPointsTotal =
                (combinedToday['heart_points'] ?? heartPoints).toInt();
          });
        }
        final newMedals =
            await AchievementService().checkAndUnlockAchievements(secretKey);
        if (newMedals.isNotEmpty && mounted) {
          _showNewMedalSnackbar(newMedals);
        }
        _earnedMedals = await AchievementService().fetchUnlocked(secretKey);
      }

      await WidgetService.updateWidgetData(
        steps: totalSteps,
        heartPoints: _heartPointsTotal,
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

  Set<String> _buildUnreadableKeys(List<HealthDataType> readableTypes) {
    const typeToKey = <HealthDataType, String>{
      HealthDataType.STEPS: 'steps',
      HealthDataType.SLEEP_ASLEEP: 'sleep_asleep_min',
      HealthDataType.SLEEP_LIGHT: 'sleep_light_min',
      HealthDataType.SLEEP_DEEP: 'sleep_deep_min',
      HealthDataType.SLEEP_REM: 'sleep_rem_min',
      HealthDataType.RESTING_HEART_RATE: 'resting_hr_bpm_avg',
      HealthDataType.RESPIRATORY_RATE: 'respiratory_rate_avg',
      HealthDataType.BLOOD_OXYGEN: 'blood_oxygen_pct_avg',
      HealthDataType.WEIGHT: 'weight_kg',
      HealthDataType.BODY_MASS_INDEX: 'bmi',
      HealthDataType.BODY_FAT_PERCENTAGE: 'body_fat_pct',
      HealthDataType.WATER: 'water_l',
      HealthDataType.NUTRITION: 'nutrition_entries',
      HealthDataType.BLOOD_PRESSURE_SYSTOLIC: 'blood_pressure_systolic_mmhg',
      HealthDataType.BLOOD_PRESSURE_DIASTOLIC: 'blood_pressure_diastolic_mmhg',
      HealthDataType.BLOOD_GLUCOSE: 'blood_glucose_mg_dl',
    };
    final unreadable = <String>{};
    for (final entry in typeToKey.entries) {
      if (!readableTypes.contains(entry.key)) {
        unreadable.add(entry.value);
      }
    }
    return unreadable;
  }

  Future<List<HealthDataType>> _getReadableHealthTypes() async {
    final readableTypes = <HealthDataType>[];
    for (final type in HealthService().types) {
      try {
        final status = await _health.hasPermissions(
          [type],
          permissions: [HealthDataAccess.READ],
        );
        if (status != false) readableTypes.add(type);
      } catch (_) {}
    }
    return readableTypes;
  }

  Future<List<Map<String, dynamic>>> _loadTodayManualWorkouts(
      SecretKey secretKey) async {
    final encryptedRows = await LocalVault().fetchWorkouts(secretKey);
    final result = <Map<String, dynamic>>[];
    final todayKey = _dateKey(DateTime.now());
    var scanned = 0;
    for (final encrypted in encryptedRows) {
      if (++scanned > 200) break;
      try {
        final decrypted =
            await EncryptionService().decryptString(encrypted, secretKey);
        final decoded = jsonDecode(decrypted);
        if (decoded is! Map<String, dynamic>) continue;
        if (!decoded.containsKey('duration')) continue;
        final ts = decoded['timestamp']?.toString() ?? '';
        final entryDate = DateTime.tryParse(ts)?.toLocal();
        if (entryDate == null) continue;
        if (_dateKey(entryDate) != todayKey) continue;
        result.add(decoded);
      } catch (_) {}
    }
    return result;
  }

  int _computeUnmatchedManualHeartPoints({
    required List<HealthDataPoint> hcWorkoutPoints,
    required List<Map<String, dynamic>> manualWorkouts,
  }) {
    var total = 0;
    const tolerance = Duration(minutes: 15);
    for (final manual in manualWorkouts) {
      final ts = DateTime.tryParse(manual['timestamp']?.toString() ?? '');
      final dur = (manual['duration'] as num?)?.toInt() ?? 0;
      if (ts == null || dur <= 0) continue;
      final manualEnd = ts.add(Duration(minutes: dur));
      final matchedByHC = hcWorkoutPoints.any((hcPoint) {
        final hcStart = hcPoint.dateFrom.subtract(tolerance);
        final hcEnd = hcPoint.dateTo.add(tolerance);
        return ts.isBefore(hcEnd) && hcStart.isBefore(manualEnd);
      });
      if (!matchedByHC) {
        final intensity = (manual['intensity'] as num?)?.toInt() ?? 5;
        total += HeartPointCalculator.calculateFromManualWorkout(
          activityType: manual['type']?.toString() ?? 'Other',
          durationMinutes: dur,
          intensity: intensity,
        );
      }
    }
    return total;
  }

  Future<void> _loadRecentActivities() async {
    final secretKey = ref.read(securityEnclaveProvider);
    if (secretKey == null) {
      if (mounted) setState(() => _recentActivities = []);
      return;
    }
    try {
      final rows = await LocalVault().fetchWorkoutsWithIds(secretKey);
      final activities = <Map<String, dynamic>>[];
      for (final row in rows) {
        try {
          final decrypted = await EncryptionService()
              .decryptString(row.encryptedData, secretKey);
          final decoded = jsonDecode(decrypted);
          final Map<String, dynamic> map;
          if (decoded is Map<String, dynamic>) {
            map = decoded;
          } else if (decoded is Map) {
            map = decoded.map((k, v) => MapEntry('$k', v));
          } else {
            continue;
          }
          activities.add({...map, '_id': row.id});
        } catch (_) {}
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

  Future<void> _refreshDashboardData() async {
    final secretKey = ref.read(securityEnclaveProvider);
    if (secretKey == null) {
      await _loadRecentActivities();
      await _loadDailyMetrics();
      return;
    }
    await _loadHealthData();
    await _loadLastBackupAt(secretKey);
  }

  Future<void> _loadLastBackupAt(SecretKey secretKey) async {
    try {
      final row = await LocalVault().fetchLatestBackup(secretKey);
      if (row == null || !mounted) return;
      final ts = DateTime.tryParse(row['created_at']?.toString() ?? '');
      if (ts != null) setState(() => _lastBackupAt = ts.toLocal());
    } catch (_) {}
  }

  // ---------------------------------------------------------------------------
  // Metric helpers (moved from _DashboardPageState)
  // ---------------------------------------------------------------------------

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
    if (value is NumericHealthValue) return value.numericValue.toDouble();
    return double.tryParse(value.toString()) ?? 0.0;
  }

  int _calculateHeartPointsFromHeartRate(double bpm, int minutes) {
    const assumedAge = 30;
    final maxHR = HeartPointCalculator.calculateMaxHeartRate(assumedAge);
    return HeartPointCalculator.calculatePoints(bpm, maxHR, minutes);
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
      metrics[key] = (metrics[key] ?? 0) + value;
    }

    void setLatestMetric(String key, num value, DateTime date) {
      final cur = latestAt[key];
      if (cur == null || date.isAfter(cur)) {
        latestAt[key] = date;
        metrics[key] = value;
      }
    }

    for (final point in points) {
      switch (point.type) {
        case HealthDataType.SLEEP_ASLEEP:
          sumMetric('sleep_asleep_min', _extractSleepMinutes(point));
        case HealthDataType.SLEEP_LIGHT:
          sumMetric('sleep_light_min', _extractSleepMinutes(point));
        case HealthDataType.SLEEP_DEEP:
          sumMetric('sleep_deep_min', _extractSleepMinutes(point));
        case HealthDataType.SLEEP_REM:
          sumMetric('sleep_rem_min', _extractSleepMinutes(point));
        case HealthDataType.RESTING_HEART_RATE:
          restingSamples.add(_extractNumericValue(point));
        case HealthDataType.RESPIRATORY_RATE:
          respiratorySamples.add(_extractNumericValue(point));
        case HealthDataType.BLOOD_OXYGEN:
          var value = _extractNumericValue(point);
          if (value <= 1.0) value *= 100;
          oxygenSamples.add(value);
        case HealthDataType.WATER:
          sumMetric('water_l', _extractNumericValue(point));
        case HealthDataType.NUTRITION:
          sumMetric('nutrition_entries', 1);
        case HealthDataType.WEIGHT:
          setLatestMetric(
              'weight_kg', _extractNumericValue(point), point.dateFrom);
        case HealthDataType.BODY_MASS_INDEX:
          setLatestMetric('bmi', _extractNumericValue(point), point.dateFrom);
        case HealthDataType.BODY_FAT_PERCENTAGE:
          var value = _extractNumericValue(point);
          if (value <= 1.0) value *= 100;
          setLatestMetric('body_fat_pct', value, point.dateFrom);
        case HealthDataType.BLOOD_PRESSURE_SYSTOLIC:
          setLatestMetric('blood_pressure_systolic_mmhg',
              _extractNumericValue(point), point.dateFrom);
        case HealthDataType.BLOOD_PRESSURE_DIASTOLIC:
          setLatestMetric('blood_pressure_diastolic_mmhg',
              _extractNumericValue(point), point.dateFrom);
        case HealthDataType.BLOOD_GLUCOSE:
          setLatestMetric('blood_glucose_mg_dl',
              _extractNumericValue(point), point.dateFrom);
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
    return values.fold<double>(0, (a, b) => a + b) / values.length;
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
      DateTime date, List<Map<String, dynamic>> rows) {
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

  // ---------------------------------------------------------------------------
  // Chart point builders
  // ---------------------------------------------------------------------------

  List<DualMetricPoint> _buildHourlyTrendPoints() {
    final now = DateTime.now();
    final todayData = _healthData
        .where((p) => _isSameLocalDay(p.dateFrom, now))
        .toList(growable: false);
    if (todayData.isEmpty) return const [];

    final hasExerciseTime = todayData.any((p) =>
        p.type == HealthDataType.EXERCISE_TIME ||
        p.type == HealthDataType.WORKOUT);
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
    return hours.map((hour) {
      final suffix = hour >= 12 ? 'pm' : 'am';
      final normalized = hour % 12 == 0 ? 12 : hour % 12;
      return DualMetricPoint(
        label: '$normalized:00 $suffix',
        steps: byHour[hour]?['steps'] ?? 0,
        heartPoints: byHour[hour]?['heart'] ?? 0,
      );
    }).toList(growable: false);
  }

  List<DualMetricPoint> _buildCurrentWeekPoints() {
    final today = DateTime.now();
    final currentDay = DateTime(today.year, today.month, today.day);
    final weekStart = currentDay.subtract(Duration(days: currentDay.weekday % 7));
    final byDate = <String, Map<String, dynamic>>{};
    for (final row in _dailyMetrics) {
      final key = row['date_key']?.toString();
      if (key != null) byDate[key] = row;
    }
    const labels = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    return List.generate(7, (index) {
      final date = weekStart.add(Duration(days: index));
      final key = _dateKey(date);
      final row = byDate[key];
      return DualMetricPoint(
        label: labels[index],
        steps: _metricFromRow(row, 'steps').toDouble(),
        heartPoints: _metricFromRow(row, 'heart_points').toDouble(),
      );
    }, growable: false);
  }

  List<SingleMetricPoint> _buildSelectedMetricWeekPoints() {
    final today = DateTime.now();
    final currentDay = DateTime(today.year, today.month, today.day);
    final weekStart = currentDay.subtract(Duration(days: currentDay.weekday % 7));
    final byDate = <String, Map<String, dynamic>>{};
    for (final row in _dailyMetrics) {
      final key = row['date_key']?.toString();
      if (key != null) byDate[key] = row;
    }
    const labels = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    return List.generate(7, (index) {
      final date = weekStart.add(Duration(days: index));
      final key = _dateKey(date);
      final row = byDate[key];
      return SingleMetricPoint(
        label: labels[index],
        value: _metricFromRow(row, _selectedTrendMetricKey).toDouble(),
      );
    }, growable: false);
  }

  List<DualMetricPoint> _buildCurrentMonthPoints() {
    final today = DateTime.now();
    final currentDay = DateTime(today.year, today.month, today.day);
    final byDate = <String, Map<String, dynamic>>{};
    for (final row in _dailyMetrics) {
      final key = row['date_key']?.toString();
      if (key != null) byDate[key] = row;
    }
    return List.generate(30, (index) {
      final date = currentDay.subtract(Duration(days: 29 - index));
      final key = _dateKey(date);
      final row = byDate[key];
      return DualMetricPoint(
        label: '${date.month}/${date.day}',
        steps: _metricFromRow(row, 'steps').toDouble(),
        heartPoints: _metricFromRow(row, 'heart_points').toDouble(),
      );
    }, growable: false);
  }

  List<SingleMetricPoint> _buildSelectedMetricMonthPoints() {
    final today = DateTime.now();
    final currentDay = DateTime(today.year, today.month, today.day);
    final byDate = <String, Map<String, dynamic>>{};
    for (final row in _dailyMetrics) {
      final key = row['date_key']?.toString();
      if (key != null) byDate[key] = row;
    }
    return List.generate(30, (index) {
      final date = currentDay.subtract(Duration(days: 29 - index));
      final key = _dateKey(date);
      final row = byDate[key];
      return SingleMetricPoint(
        label: '${date.month}/${date.day}',
        value: _metricFromRow(row, _selectedTrendMetricKey).toDouble(),
      );
    }, growable: false);
  }

  // ---------------------------------------------------------------------------
  // Actions (moved from _DashboardPageState)
  // ---------------------------------------------------------------------------

  Future<void> _showManualIngestion(SecretKey? secretKey) async {
    final newMedals = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ManualIngestionBottomSheet(secretKey: secretKey),
    );
    if (newMedals != null) {
      await _loadRecentActivities();
      await _loadDailyMetrics();
      if (newMedals.isNotEmpty && mounted) {
        _showNewMedalSnackbar(newMedals);
      }
    }
  }

  Future<void> _editActivity(
      int id, Map<String, dynamic> data, SecretKey secretKey) async {
    final newMedals = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ManualIngestionBottomSheet(
        secretKey: secretKey,
        existingWorkoutId: id,
        initialActivityType: data['type']?.toString(),
        initialDurationMinutes:
            data['duration'] is num ? (data['duration'] as num).toInt() : null,
        initialIntensity: data['intensity'] is num
            ? (data['intensity'] as num).toDouble()
            : null,
        initialTimestamp: data['timestamp'] is String
            ? DateTime.tryParse(data['timestamp'] as String)
            : null,
      ),
    );
    if (!mounted) return;
    if (newMedals != null) {
      await _loadRecentActivities();
      await _loadDailyMetrics();
      if (newMedals.isNotEmpty && mounted) {
        _showNewMedalSnackbar(newMedals);
      }
    }
  }

  Future<void> _deleteActivity(int id, SecretKey secretKey) async {
    await LocalVault().deleteWorkout(id, secretKey);
    await _loadRecentActivities();
  }

  Future<void> _unlockVault(WidgetRef ref) async {
    final LocalAuthentication auth = LocalAuthentication();
    const storage = FlutterSecureStorage();
    String? finalPassphrase;

    try {
      final canBiometrics = await auth.canCheckBiometrics;
      final isSupported = await auth.isDeviceSupported();
      if (canBiometrics && isSupported) {
        final didAuthenticate = await auth.authenticate(
          localizedReason: 'Scan fingerprint to unlock your health dashboard',
          options: const AuthenticationOptions(
            stickyAuth: true,
            biometricOnly: true,
          ),
        );
        if (didAuthenticate) {
          finalPassphrase = await storage.read(key: 'vault_passphrase');
        }
      }
    } catch (e) {
      debugPrint('Biometric authentication error: $e');
    }

    if (finalPassphrase == null) {
      if (!mounted) return;
      final controller = TextEditingController();
      finalPassphrase = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Unlock Vault'),
          content: TextField(
            controller: controller,
            obscureText: true,
            decoration:
                const InputDecoration(labelText: 'Master Passphrase'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(controller.text),
              child: const Text('Unlock'),
            ),
          ],
        ),
      );
    }

    if (finalPassphrase == null || finalPassphrase.isEmpty) return;

    final unlocked = await ref
        .read(securityEnclaveProvider.notifier)
        .initialize(finalPassphrase);

    if (!unlocked) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Unlock failed. Invalid passphrase.')),
        );
      }
      return;
    }

    await storage.write(key: 'vault_passphrase', value: finalPassphrase);

    final tasksInitialized =
        sharedPrefs.getBool('bg_tasks_initialized') ?? false;
    if (!tasksInitialized) {
      if (!mounted) return;
      final appState = AppState.of(context, listen: false);
      await appState.initializeBackgroundTasks();
      await sharedPrefs.setBool('bg_tasks_initialized', true);
    }

    HapticFeedback.mediumImpact();
    await _loadHealthData();
  }

  Future<void> _toggleGpsTracking() async {
    final secretKey = ref.read(securityEnclaveProvider);
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => GpsWorkoutPage(secretKey: secretKey),
      ),
    );
    await _loadRecentActivities();
  }

  void _showNewMedalSnackbar(List<String> ids) {
    final definitions = ids
        .map((id) =>
            kAllAchievements.where((d) => d.id == id).firstOrNull)
        .whereType<AchievementDefinition>()
        .take(3)
        .toList();
    for (final def in definitions) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.emoji_events, color: Colors.amber, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Medal unlocked: ${def.name}!',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  static const _kLastKnownRemoteTs = 'last_known_remote_updated_at';

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
      // -- Conflict detection (3.5) ------------------------------------------
      final prefs = await SharedPreferences.getInstance();
      final lastKnownRaw = prefs.getString(_kLastKnownRemoteTs);
      final lastKnown = lastKnownRaw != null
          ? DateTime.tryParse(lastKnownRaw)?.toUtc()
          : null;

      final remote =
          await SupabaseService().fetchEncryptedVaultWithTimestamp();
      if (remote != null && lastKnown != null) {
        final remoteIsNewer = remote.updatedAt.isAfter(lastKnown);
        if (remoteIsNewer && mounted) {
          final choice = await showDialog<_ConflictChoice>(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => AlertDialog(
              title: const Text('Sync conflict'),
              content: const Text(
                'Another device pushed changes after your last sync.\n\n'
                'Keep cloud version (pull) or overwrite with this device?',
              ),
              actions: [
                TextButton(
                  onPressed: () =>
                      Navigator.pop(ctx, _ConflictChoice.cancel),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () =>
                      Navigator.pop(ctx, _ConflictChoice.keepCloud),
                  child: const Text('Keep cloud'),
                ),
                FilledButton(
                  onPressed: () =>
                      Navigator.pop(ctx, _ConflictChoice.overwrite),
                  child: const Text('Overwrite'),
                ),
              ],
            ),
          );
          if (!mounted) return;
          if (choice == _ConflictChoice.cancel) return;
          if (choice == _ConflictChoice.keepCloud) {
            setState(() => _isSyncing = false);
            await _pullEncryptedVault(secretKey);
            return;
          }
          // choice == overwrite → fall through to upload
        }
      }
      // -- Upload -------------------------------------------------------------
      final payload = await _buildCloudVaultPayload(secretKey);
      final payloadJson = jsonEncode(payload);
      final encryptedPayload =
          await EncryptionService().encryptString(payloadJson, secretKey);
      await SupabaseService()
          .upsertEncryptedVaultBlobForCurrentUser(encryptedPayload);

      // Record the timestamp we just wrote so the next sync can compare.
      final now = DateTime.now().toUtc().toIso8601String();
      await prefs.setString(_kLastKnownRemoteTs, now);

      // Log to backup_history (3.4).
      await LocalVault().insertBackupHistory(
        backupType: 'cloud_sync',
        status: 'success',
        details:
            '${payload['workouts_count']} workouts, ${payload['steps_count']} step records',
        secretKey: secretKey,
      );
      setState(() => _lastBackupAt = DateTime.now());

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
      showActionableErrorSnackBar(context,
          error: e, onRetry: () => _syncEncryptedVault(secretKey));
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  Future<Map<String, dynamic>> _buildCloudVaultPayload(
      SecretKey secretKey) async {
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
      } catch (_) {}
    }
    final steps = _healthData
        .where((p) => p.type == HealthDataType.STEPS)
        .map((p) => <String, dynamic>{
              'timestamp': p.dateFrom.toUtc().toIso8601String(),
              'value': _extractNumericValue(p).toInt(),
              'source': p.sourceId,
            })
        .toList(growable: false);

    final heartRecords = _healthData
        .where((p) =>
            p.type == HealthDataType.EXERCISE_TIME ||
            p.type == HealthDataType.WORKOUT ||
            p.type == HealthDataType.HEART_RATE)
        .map((p) {
      if (p.type == HealthDataType.EXERCISE_TIME ||
          p.type == HealthDataType.WORKOUT) {
        return <String, dynamic>{
          'timestamp': p.dateFrom.toUtc().toIso8601String(),
          'metric': 'exercise_time_min',
          'value': _extractExerciseMinutes(p),
        };
      }
      final value = _extractNumericValue(p);
      return <String, dynamic>{
        'timestamp': p.dateFrom.toUtc().toIso8601String(),
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
        if (parsed.isNotEmpty) dailyMetricMap[dateKey] = parsed;
      }
    }
    final achievements = await LocalVault().fetchAchievements(secretKey);
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
      'heart_points': {'total': _heartPointsTotal, 'records': heartRecords},
      'achievements': achievements,
    };
  }

  List<Map<String, dynamic>> _buildDailyMetricsFromPayload(
      Map<String, dynamic> payload) {
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
        payloadJson = await EncryptionService()
            .decryptString(encryptedBlob, secretKey);
      } catch (_) {
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
        final enc = await EncryptionService()
            .encryptString(jsonEncode(workout), secretKey);
        restoredEncryptedRows.add(enc);
      }
      await LocalVault().replaceWorkouts(restoredEncryptedRows, secretKey);
      final pulledDailyMetrics =
          _buildDailyMetricsFromPayload(payload);
      await LocalVault()
          .replaceDailyMetrics(pulledDailyMetrics, secretKey);
      final achievementsRaw = payload['achievements'];
      if (achievementsRaw is List) {
        for (final item in achievementsRaw) {
          if (item is! Map) continue;
          final id = item['id']?.toString();
          final tsRaw = item['unlocked_at']?.toString();
          if (id == null || tsRaw == null) continue;
          final unlockedAt =
              DateTime.tryParse(tsRaw) ?? DateTime.now().toUtc();
          await LocalVault()
              .insertAchievementIfAbsent(id, unlockedAt, secretKey);
        }
      }
      var pulledHeartTotal = 0;
      final heartPointsRaw = payload['heart_points'];
      if (heartPointsRaw is Map && heartPointsRaw['total'] is num) {
        pulledHeartTotal = (heartPointsRaw['total'] as num).toInt();
      } else if (payload['heart_points_total'] is num) {
        pulledHeartTotal = (payload['heart_points_total'] as num).toInt();
      }
      workouts.sort((a, b) {
        final aTs = DateTime.tryParse(
                (a['timestamp'] ?? a['date'] ?? '').toString()) ??
            DateTime.fromMillisecondsSinceEpoch(0);
        final bTs = DateTime.tryParse(
                (b['timestamp'] ?? b['date'] ?? '').toString()) ??
            DateTime.fromMillisecondsSinceEpoch(0);
        return bTs.compareTo(aTs);
      });
      if (!mounted) return;
      final pulledTodayMetrics =
          _metricsForDate(DateTime.now(), pulledDailyMetrics);
      if (pulledHeartTotal <= 0) {
        pulledHeartTotal =
            (pulledTodayMetrics['heart_points'])?.toInt() ?? 0;
      }
      setState(() {
        if (pulledHeartTotal > 0) _heartPointsTotal = pulledHeartTotal;
        _dailyMetrics = pulledDailyMetrics;
        if (pulledTodayMetrics.isNotEmpty) _todayMetrics = pulledTodayMetrics;
      });
      await _loadRecentActivities();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Pull complete: ${workouts.length} workouts restored.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      showActionableErrorSnackBar(context,
          error: e, onRetry: () => _pullEncryptedVault(secretKey));
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
            'Choose what to delete: cloud data, local data, or all data.'),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.of(context).pop(_DeleteDataScope.cloud),
            child: const Text('Cloud data'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(context).pop(_DeleteDataScope.local),
            child: const Text('Local data'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(context).pop(_DeleteDataScope.all),
            child: const Text('All data'),
          ),
        ],
      ),
    );
    if (selectedScope == null) return;
    await _deleteDataForScope(selectedScope, secretKey);
  }

  Future<void> _deleteDataForScope(
      _DeleteDataScope scope, SecretKey? secretKey) async {
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
        const SnackBar(
            content: Text('Sign in before deleting cloud data.')),
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
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(statusText)));
    } catch (e) {
      if (!mounted) return;
      showActionableErrorSnackBar(context, error: e);
    } finally {
      if (mounted) setState(() => _isDeletingData = false);
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final secretKey = ref.watch(securityEnclaveProvider);
    final isLocked = secretKey == null;
    final goalsState = ref.watch(goalsProvider).asData?.value;

    final shell = SecurityBarrier(
      isLocked: isLocked,
      onUnlock: () => _unlockVault(ref),
      child: Scaffold(
        body: IndexedStack(
          index: _currentIndex,
          children: [
            TodayPage(
              todayMetrics: _todayMetrics,
              heartPointsTotal: _heartPointsTotal,
              isLoading: _isLoading,
              isSyncing: _isSyncing,
              isPulling: _isPulling,
              gpsSnapshot: _gpsSnapshot,
              secretKey: secretKey,
              unreadableMetricKeys: _unreadableMetricKeys,
              onToggleGps: _toggleGpsTracking,
              onManualEntry: () => _showManualIngestion(secretKey),
              onRefresh: _refreshDashboardData,
              onSync: () => _syncEncryptedVault(secretKey),
              onPull: () => _pullEncryptedVault(secretKey),
              onOpenPermissions: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const PermissionsPage(),
                  ),
                );
                await _loadHealthData();
              },
              onLock: () async {
                await ref.read(securityEnclaveProvider.notifier).lock();
                setState(() => _recentActivities = []);
                await WidgetService.redactWidget();
              },
              goalsState: goalsState,
              lastBackupAt: _lastBackupAt,
            ),
            TrendsPage(
              hourlyTrendPoints: _buildHourlyTrendPoints(),
              currentWeekPoints: _buildCurrentWeekPoints(),
              currentMonthPoints: _buildCurrentMonthPoints(),
              selectedMetricWeekPoints: _buildSelectedMetricWeekPoints(),
              selectedMetricMonthPoints: _buildSelectedMetricMonthPoints(),
              selectedTrendMetricKey: _selectedTrendMetricKey,
              onTrendMetricChanged: (value) =>
                  setState(() => _selectedTrendMetricKey = value),
              onRefresh: _refreshDashboardData,
            ),
            ActivitiesPage(
              recentActivities: _recentActivities,
              isLoading: _isLoading,
              onManualEntry: () => _showManualIngestion(secretKey),
              onRefresh: _refreshDashboardData,
              secretKey: secretKey,
              onEditActivity: (id, data) =>
                  secretKey != null ? _editActivity(id, data, secretKey) : Future.value(),
              onDeleteActivity: (id) =>
                  secretKey != null ? _deleteActivity(id, secretKey) : Future.value(),
            ),
            ProfilePage(
              isSyncing: _isSyncing,
              isPulling: _isPulling,
              isDeletingData: _isDeletingData,
              onSync: () => _syncEncryptedVault(secretKey),
              onPull: () => _pullEncryptedVault(secretKey),
              onDeleteData: () => _promptDeleteData(secretKey),
              earnedMedals: _earnedMedals,
              onViewAllMedals: () => context.push('/achievements'),
              autoLockMinutes: _autoLockMinutes,
              onAutoLockChanged: saveAutoLockSetting,
              secretKey: secretKey,
            ),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: (i) => setState(() => _currentIndex = i),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.today_outlined),
              selectedIcon: Icon(Icons.today),
              label: 'Today',
            ),
            NavigationDestination(
              icon: Icon(Icons.show_chart_outlined),
              selectedIcon: Icon(Icons.show_chart),
              label: 'Trends',
            ),
            NavigationDestination(
              icon: Icon(Icons.local_fire_department_outlined),
              selectedIcon: Icon(Icons.local_fire_department),
              label: 'Activities',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _resetInteraction(),
      child: Stack(
        children: [
          shell,
          if (_isObscured)
            Positioned.fill(
              child: Container(
                color: Theme.of(context).colorScheme.surface,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.lock_outline_rounded,
                          size: 64,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.4)),
                      const SizedBox(height: 16),
                      Text(
                        'Zero-Trust Health',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

enum _ConflictChoice { cancel, keepCloud, overwrite }
