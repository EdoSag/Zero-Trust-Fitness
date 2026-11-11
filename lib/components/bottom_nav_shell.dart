import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:health/health.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:zerotrust_fitness/core/storage/fitness_vault.dart';
import 'package:zerotrust_fitness/features/achievements/domain/achievement_definition.dart';
import 'package:zerotrust_fitness/features/achievements/domain/achievement_service.dart';
import 'package:zerotrust_fitness/app/vault_providers.dart';
import 'package:zerotrust_fitness/features/dashboard/metric_card_specs.dart';
import 'package:zerotrust_fitness/core/services/insights_service.dart';
import 'package:zerotrust_fitness/features/goals/goals_provider.dart';
import 'package:zerotrust_fitness/features/health/data/gps_tracking_service.dart';
import 'package:zerotrust_fitness/features/health/data/health_service.dart';
import 'package:zerotrust_fitness/features/health/data/health_writeback.dart';
import 'package:zerotrust_fitness/features/health/domain/heart_points_engine.dart';
import 'package:zerotrust_fitness/features/health/domain/heart_points_service.dart';
import 'package:zerotrust_fitness/features/health/domain/momentum_engine.dart';
import 'package:zerotrust_fitness/features/health/domain/momentum_service.dart';
import 'package:zerotrust_fitness/features/legacy_import/legacy_import_banner.dart';
import 'package:zerotrust_fitness/features/summary/weekly_summary.dart';
import 'package:zerotrust_fitness/features/wear/wear_companion.dart';
import 'package:zerotrust_fitness/core/services/reminder_service.dart';
import 'package:zerotrust_fitness/components/manual_ingestion_bottom_sheet.dart';
import 'package:zerotrust_fitness/pages/journal_page.dart';
import 'package:zerotrust_fitness/pages/gpx_import_page.dart';
import 'package:zerotrust_fitness/features/gpx/gpx_workouts.dart';
import 'package:zerotrust_fitness/pages/gps_workout_page.dart';
import 'package:zerotrust_fitness/pages/permissions_page.dart';
import 'package:zerotrust_fitness/pages/settings_page.dart';
import 'package:zerotrust_fitness/pages/today_page.dart';
import 'package:zero_trust_core/zero_trust_core.dart';
import 'package:zerotrust_fitness/pages/trends_page.dart';
import 'package:zerotrust_fitness/widget_service.dart';
import 'package:zerotrust_fitness/l10n/l10n.dart';

class BottomNavShell extends ConsumerStatefulWidget {
  const BottomNavShell({
    super.key,
    this.initialIndex = 0,
    this.legacyImportPending = false,
  });

  final int initialIndex;

  /// Data from the previous version is still being brought over (or that
  /// failed and waits for a retry). Health Connect refreshes don't write to
  /// the vault until it's done, so they can't hide older entries for the
  /// same days.
  final bool legacyImportPending;

  @override
  ConsumerState<BottomNavShell> createState() => _BottomNavShellState();
}

class _BottomNavShellState extends ConsumerState<BottomNavShell>
    with WidgetsBindingObserver {
  int _currentIndex = 0;

  // --- data state (moved from _DashboardPageState) ---
  bool _isLoading = false;
  List<HealthDataPoint> _healthData = [];
  List<Map<String, dynamic>> _recentActivities = [];
  List<ManualEntry> _manualEntries = [];
  final Health _health = Health();
  final GpsTrackingService _gpsTrackingService = GpsTrackingService();
  int _heartPointsTotal = 0;
  List<Map<String, dynamic>> _dailyMetrics = [];
  Map<String, num> _todayMetrics = const <String, num>{};
  String _selectedTrendMetricKey = 'sleep_asleep_min';
  Set<String> _unreadableMetricKeys = const {};
  List<UnlockedAchievement> _earnedMedals = [];
  StreakResult? _streaks;
  WeeklyComparison? _weeklySteps;
  Map<String, double> _baselines = {};
  double? _sleepStepsCorrelation;

  bool _isObscured = false; // privacy cover in the app switcher
  StreamSubscription<Set<String>>? _changes;
  Timer? _reloadDebounce;

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
    WearCompanion.instance
      ..listen()
      ..changes.addListener(_onWatchChanged);
    _currentIndex = widget.initialIndex;
    _gpsTrackingService.snapshots.listen((snapshot) {
      if (!mounted) return;
      setState(() => _gpsSnapshot = snapshot);
    });
    _loadHealthData();
    _maybeOfferHealthSetup();
  }

  @override
  void didUpdateWidget(BottomNavShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The import finished: write today's Health Connect data now.
    if (oldWidget.legacyImportPending && !widget.legacyImportPending) {
      _loadHealthData();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    WearCompanion.instance.changes.removeListener(_onWatchChanged);
    _changes?.cancel();
    _reloadDebounce?.cancel();
    _weeklySummaryDebounce?.cancel();
    _watchDebounce?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      if (mounted) setState(() => _isObscured = true);
    } else if (state == AppLifecycleState.resumed) {
      if (mounted) setState(() => _isObscured = false);
      _drainWatchWater();
    }
  }

  // ---------------------------------------------------------------------------
  // Data loading
  // ---------------------------------------------------------------------------

  Future<void> _loadHealthData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      await _drainWatchWater();
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

      // Heart Points are scored per minute from heart rate, step cadence and
      // logged workouts (whichever is highest). Pass all fetched points so
      // records that started yesterday but overlap today are clipped in.
      final heartPoints =
          HeartPointsService.forDay(deduplicated, DateTime.now()).total;
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

      final vault = ref.read(openFitnessVaultProvider);
      if (vault != null && !widget.legacyImportPending) {
        final hcWorkoutPoints = todayPoints
            .where((p) => p.type == HealthDataType.WORKOUT)
            .toList(growable: false);
        final manualWorkoutsToday =
            await _loadTodayManualWorkouts(vault);
        final unmatchedManualHp = _computeUnmatchedManualHeartPoints(
          allPoints: deduplicated,
          hcWorkoutPoints: hcWorkoutPoints,
          manualWorkouts: manualWorkoutsToday,
          hcHeartPoints: heartPoints,
        );
        final Map<String, num> manualOverrides = {};
        if (manualWorkoutsToday.isNotEmpty) {
          // Workouts are rescored; points typed in by hand stay.
          final todayRow = _metricsForDate(
              DateTime.now(), await vault.fetchDailyMetrics());
          manualOverrides['heart_points'] = unmatchedManualHp +
              FitnessVault.enteredHeartPoints(todayRow);
        }
        await vault.syncFromHealthConnect(
          dateKey: _dateKey(DateTime.now()),
          hcMetrics: todayMetrics,
          manualContributions: manualOverrides
        );
        await _backfillRecentDays(deduplicated, vault);
        final vaultRows = await vault.fetchDailyMetrics();
        final combinedToday = _metricsForDate(DateTime.now(), vaultRows);
        if (mounted && combinedToday.isNotEmpty) {
          setState(() {
            _todayMetrics = combinedToday;
            _heartPointsTotal =
                (combinedToday['heart_points'] ?? heartPoints).toInt();
          });
        }
        final newMedals =
            await AchievementService().checkAndUnlockAchievements(vault);
        if (newMedals.isNotEmpty && mounted) {
          _showNewMedalSnackbar(newMedals);
        }
        _earnedMedals = await AchievementService().fetchUnlocked(vault);
      }

      final momentum = vault == null
          ? null
          : await MomentumService.forToday(
              vault,
              todayPoints: _heartPointsTotal,
            );
      await WidgetService.updateWidgetData(
        steps: totalSteps,
        heartPoints: _heartPointsTotal,
        isLocked: vault == null,
        momentum: momentum?.momentum ?? 0,
        momentumLabel: momentum?.label ?? '',
        heartTarget: momentum?.target ?? 0,
        stepsGoal: _dailyStepsGoal(),
      );
      await _loadRecentActivities();
      await _loadDailyMetrics();
    } catch (e) {
      debugPrint('Error loading health data: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Health data is fetched with a short lookback, so also score those past
  /// days. Otherwise a day the app wasn't opened has no record and counts as
  /// zero toward Momentum. Only the Health Connect share of steps and Heart
  /// Points is raised; manual entries and other metrics are left alone.
  Future<void> _backfillRecentDays(
    List<HealthDataPoint> points,
    FitnessVault vault,
  ) async {
    final now = DateTime.now();
    for (var back = 1; back <= HealthService.defaultLookbackDays; back++) {
      final day = DateTime(now.year, now.month, now.day - back);
      final steps = points
          .where((p) =>
              p.type == HealthDataType.STEPS && _isSameLocalDay(p.dateFrom, day))
          .fold<int>(0, (sum, p) => sum + _extractNumericValue(p).toInt());
      await vault.raiseHealthConnectTotals(
        dateKey: _dateKey(day),
        hcMetrics: {
          'steps': steps,
          'heart_points': HeartPointsService.forDay(points, day).total,
        }
      );
    }
  }

  MomentumResult _computeMomentum() {
    return MomentumEngine.calculate(
      history: MomentumService.historyFromDailyRows(_dailyMetrics),
      today: DateTime.now(),
      todayPoints: _heartPointsTotal,
    );
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
      FitnessVault vault) async {
    final todayKey = _dateKey(DateTime.now());
    return [
      for (final w in (await vault.fetchWorkouts()).take(200))
        // Logged here (manual or GPS); imported workouts add no points.
        if (w.data.containsKey('duration') && w.data['source'] == null)
          if (DateTime.tryParse(w.data['timestamp']?.toString() ?? '')
                  ?.toLocal()
              case final at? when _dateKey(at) == todayKey)
            w.data,
    ];
  }

  /// Extra Heart Points from manual workouts that Health Connect doesn't
  /// already have (no synced workout within 15 minutes).
  ///
  /// Manual workouts are scored minute by minute together with the sensor
  /// data, so minutes already credited from heart rate or step cadence are
  /// not counted twice; only the difference is returned.
  int _computeUnmatchedManualHeartPoints({
    required List<HealthDataPoint> allPoints,
    required List<HealthDataPoint> hcWorkoutPoints,
    required List<Map<String, dynamic>> manualWorkouts,
    required int hcHeartPoints,
  }) {
    final intervals = <ActiveInterval>[];
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
      if (matchedByHC) continue;
      final intensity = (manual['intensity'] as num?)?.toInt() ?? 5;
      intervals.add(ActiveInterval(
        ts,
        manualEnd,
        level: HeartPointsEngine.manualIntensity(intensity),
      ));
    }
    if (intervals.isEmpty) return 0;
    final combined = HeartPointsService.forDay(
      allPoints,
      DateTime.now(),
      extraExercise: intervals,
    ).total;
    final extra = combined - hcHeartPoints;
    return extra > 0 ? extra : 0;
  }

  Future<void> _loadRecentActivities() async {
    final vault = ref.read(openFitnessVaultProvider);
    if (vault == null) {
      if (mounted) {
        setState(() {
          _recentActivities = [];
          _manualEntries = [];
        });
      }
      return;
    }
    try {
      final activities = [
        for (final w in await vault.fetchWorkouts()) {...w.data, '_id': w.id},
      ];
      final entries = await vault.fetchManualEntries();
      if (!mounted) return;
      setState(() {
        _recentActivities = activities;
        _manualEntries = entries;
      });
    } catch (e) {
      debugPrint('Error loading recent activities: $e');
      if (!mounted) return;
      setState(() => _recentActivities = []);
    }
  }

  /// With [refreshToday], today's headline numbers follow the vault too
  /// (a synced edit or a delete), unless the old-data import is pending and Health
  /// Connect values are only on screen.
  Future<void> _loadDailyMetrics({bool refreshToday = false}) async {
    final vault = ref.read(openFitnessVaultProvider);
    if (vault == null) {
      if (!mounted) return;
      setState(() => _dailyMetrics = []);
      return;
    }
    try {
      final rows = await vault.fetchDailyMetrics();
      final fallbackToday = _metricsForDate(DateTime.now(), rows);
      _scheduleWeeklySummary(vault);
      _syncWatchSoon();
      if (!mounted) return;
      setState(() {
        _dailyMetrics = rows;
        if (refreshToday && !widget.legacyImportPending) {
          _todayMetrics = fallbackToday;
          _heartPointsTotal = (fallbackToday['heart_points'])?.toInt() ?? 0;
        } else if (_todayMetrics.isEmpty && fallbackToday.isNotEmpty) {
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

  Timer? _weeklySummaryDebounce;
  Timer? _watchDebounce;

  /// Adds water logged on the watch; errors leave it queued on the phone.
  Future<void> _drainWatchWater() async {
    final vault = ref.read(openFitnessVaultProvider);
    if (vault == null) return;
    try {
      await WearCompanion.instance.drainPendingWater(vault);
    } catch (e) {
      debugPrint('Watch water not added yet: $e');
    }
  }

  /// Water from the watch while the app runs, or the switch turned on.
  void _onWatchChanged() {
    _drainWatchWater();
    _syncWatchSoon();
  }

  /// Today's step goal for the home screen widget (0 = widget default).
  int _dailyStepsGoal() {
    final g = ref.read(goalsProvider).asData?.value.forKey('steps');
    if (g == null) return 0;
    return (g.period == 'weekly' ? g.targetValue / 7 : g.targetValue).round();
  }

  /// Sends today's numbers to the Wear OS watch (when that's on), once the
  /// screen has settled.
  void _syncWatchSoon() {
    _watchDebounce?.cancel();
    _watchDebounce = Timer(const Duration(seconds: 2), () {
      if (!mounted || ref.read(openFitnessVaultProvider) == null) return;
      final goals = ref.read(goalsProvider).asData?.value;
      num? daily(String key) {
        final g = goals?.forKey(key);
        if (g == null) return null;
        return g.period == 'weekly' ? g.targetValue / 7 : g.targetValue;
      }

      WearCompanion.instance
          .push(WearCompanion.todayFrom(
            _todayMetrics,
            stepsGoal: daily('steps'),
            heartPointsGoal: daily('heart_points'),
            waterGoalLiters: daily('water_l'),
          ))
          .catchError((Object e) => debugPrint('Watch not updated: $e'));
    });
  }

  /// Re-prepares the Monday summary from the latest data (see
  /// [ReminderService.refreshWeeklySummary]); several reloads in a row
  /// schedule once.
  void _scheduleWeeklySummary(FitnessVault vault) {
    _weeklySummaryDebounce?.cancel();
    _weeklySummaryDebounce = Timer(const Duration(seconds: 5), () {
      ReminderService().refreshWeeklySummary(vault).catchError(
          (Object e) => debugPrint('Weekly summary not scheduled: $e'));
    });
  }

  Future<void> _refreshDashboardData() async {
    final vault = ref.read(openFitnessVaultProvider);
    if (vault == null) {
      await _loadRecentActivities();
      await _loadDailyMetrics();
      return;
    }
    await _loadHealthData();
    _computeInsights();
    unawaited(ref.read(ztSyncControllerProvider.notifier).syncNow());
  }

  void _computeInsights() {
    final goalsState = ref.read(goalsProvider).asData?.value;
    if (goalsState == null || _dailyMetrics.isEmpty) return;
    final streaks = InsightsService().computeStreaks(goalsState, _dailyMetrics);
    final weekly = InsightsService().weeklyComparison(_dailyMetrics, 'steps');
    final baselines = InsightsService().computeBaselines(_dailyMetrics);
    final corr = InsightsService()
        .computeCorrelation(_dailyMetrics, 'sleep_asleep_min', 'steps');
    if (mounted) {
      setState(() {
        _streaks = streaks;
        _weeklySteps = weekly;
        _baselines = baselines;
        _sleepStepsCorrelation = corr;
      });
    }
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

    final byHour = <int, Map<String, double>>{};
    for (final point in todayData) {
      if (point.type != HealthDataType.STEPS) continue;
      final hour = point.dateFrom.toLocal().hour;
      final bucket = byHour.putIfAbsent(hour, () => {'steps': 0, 'heart': 0});
      bucket['steps'] = (bucket['steps'] ?? 0) + _extractNumericValue(point);
    }
    final heartByHour = HeartPointsService.forDay(_healthData, now).pointsByHour;
    heartByHour.forEach((hour, points) {
      final bucket = byHour.putIfAbsent(hour, () => {'steps': 0, 'heart': 0});
      bucket['heart'] = points.toDouble();
    });
    final hours = byHour.keys.toList()..sort();
    return hours.map((hour) {
      return DualMetricPoint(
        label: DateFormat.j().format(DateTime(2000, 1, 1, hour)),
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
    return List.generate(7, (index) {
      final date = weekStart.add(Duration(days: index));
      final key = _dateKey(date);
      final row = byDate[key];
      return DualMetricPoint(
        label: DateFormat.E().format(date),
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
    return List.generate(7, (index) {
      final date = weekStart.add(Duration(days: index));
      final key = _dateKey(date);
      final row = byDate[key];
      return SingleMetricPoint(
        label: DateFormat.E().format(date),
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

  Future<void> _showManualIngestion(FitnessVault? vault) async {
    final newMedals = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ManualIngestionBottomSheet(
        vault: vault,
        onWorkoutSaved: (id) => _writeBack(vault, id),
      ),
    );
    if (newMedals != null) {
      await _loadRecentActivities();
      await _loadDailyMetrics(refreshToday: true);
      if (newMedals.isNotEmpty && mounted) {
        _showNewMedalSnackbar(newMedals);
      }
    }
  }

  Future<void> _editActivity(
      String id, Map<String, dynamic> data, FitnessVault vault) async {
    final newMedals = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ManualIngestionBottomSheet(
        vault: vault,
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
        onWorkoutSaved: (id) => _writeBack(vault, id),
      ),
    );
    if (!mounted) return;
    if (newMedals != null) {
      await _rescoreToday();
      if (newMedals.isNotEmpty && mounted) {
        _showNewMedalSnackbar(newMedals);
      }
    }
  }

  Future<void> _deleteActivity(String id, FitnessVault vault) async {
    await vault.removeWorkout(id);
    await HealthWriteback.instance.remove(id);
    await _rescoreToday();
  }

  /// After a workout changes: today's manual Heart Points are scored
  /// against Health Connect (a workout it already has adds nothing), so
  /// rescore them from the workouts now logged rather than trusting the
  /// plain subtraction the vault did.
  Future<void> _rescoreToday() async {
    await _loadHealthData();
    await _loadRecentActivities();
    await _loadDailyMetrics(refreshToday: true);
  }

  /// Copies a saved workout to Health Connect / Apple Health when the
  /// person turned that on.
  Future<void> _writeBack(FitnessVault? vault, String id) async {
    final workout = await vault?.getWorkout(id);
    if (workout != null) {
      await HealthWriteback.instance.sync(id, workout.data);
    }
  }

  Future<void> _editMeasurement(
      FitnessVault vault, ManualEntry entry, num value) async {
    await vault.editManualEntry(entry, value);
    await _loadRecentActivities();
    await _loadDailyMetrics(refreshToday: true);
  }

  Future<void> _deleteMeasurement(FitnessVault vault, ManualEntry entry) async {
    await vault.deleteManualEntry(entry);
    await _loadRecentActivities();
    await _loadDailyMetrics(refreshToday: true);
  }

  Future<void> _toggleGpsTracking() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => GpsWorkoutPage(onSaved: (vault, id) => _writeBack(vault, id)),
      ),
    );
    await _loadRecentActivities();
    await _loadDailyMetrics(refreshToday: true);
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
                  context.l10n.medalUnlocked(def.title),
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

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  /// Reloads after changes from sync (another device) or from a screen
  /// this shell didn't open, at most a few times a second.
  void _onVaultChanged() {
    _reloadDebounce?.cancel();
    _reloadDebounce = Timer(const Duration(milliseconds: 400), () async {
      if (!mounted) return;
      await _loadRecentActivities();
      await _loadDailyMetrics(refreshToday: true);
      final vault = ref.read(openFitnessVaultProvider);
      if (vault != null) {
        final medals = await AchievementService().fetchUnlocked(vault);
        if (mounted) setState(() => _earnedMedals = medals);
      }
      _computeInsights();
    });
  }

  /// Once per install, after the first unlock: offer to connect Health
  /// Connect (what the old onboarding's last step did).
  Future<void> _maybeOfferHealthSetup() async {
    const key = 'health_setup_offered';
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(key) ?? false) return;
    await prefs.setBool(key, true);
    if (!mounted) return;
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.health_and_safety_outlined),
        title: Text(context.l10n.connectYourHealthData),
        content: Text(
          context.l10n.fitnessCanReadStepsWorkouts,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.l10n.notNow),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(context.l10n.choosePermissions),
          ),
        ],
      ),
    );
    if (go != true || !mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const PermissionsPage()),
    );
    await _loadHealthData();
  }

  @override
  Widget build(BuildContext context) {
    final vault = ref.watch(openFitnessVaultProvider);
    final isLocked = vault == null;
    final goalsState = ref.watch(goalsProvider).asData?.value;
    final syncStatus = ref.watch(ztSyncControllerProvider);
    ref.listen(fitnessVaultChangesProvider, (_, __) => _onVaultChanged());

    final shell = Scaffold(
      body: Column(
        children: [
          const SafeArea(bottom: false, child: LegacyImportBanner()),
          Expanded(
            child: IndexedStack(
              index: _currentIndex,
              children: [
                TodayPage(
                  todayMetrics: _todayMetrics,
                  heartPointsTotal: _heartPointsTotal,
                  momentum: isLocked ? null : _computeMomentum(),
                  isLoading: _isLoading,
                  syncStatus: syncStatus,
                  gpsSnapshot: _gpsSnapshot,
                  vault: vault,
                  unreadableMetricKeys: _unreadableMetricKeys,
                  onToggleGps: _toggleGpsTracking,
                  onManualEntry: () => _showManualIngestion(vault),
                  onRefresh: _refreshDashboardData,
                  onOpenPermissions: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const PermissionsPage(),
                      ),
                    );
                    await _loadHealthData();
                  },
                  onLock: () =>
                      ref.read(vaultControllerProvider.notifier).lock(),
                  goalsState: goalsState,
                  streaks: _streaks,
                  weeklySteps: _weeklySteps,
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
                  baselines: _baselines,
                  sleepStepsCorrelation: _sleepStepsCorrelation,
                  weeklySummary: isLocked || _dailyMetrics.isEmpty
                      ? null
                      : WeeklySummary.compute(
                          dailyRows: _dailyMetrics,
                          workouts: _recentActivities,
                          weekOf: DateTime.now(),
                          now: DateTime.now(),
                        ),
                ),
                JournalPage(
                  workouts: _recentActivities,
                  measurements: _manualEntries,
                  isLoading: _isLoading,
                  canEdit: vault != null,
                  onLog: () => _showManualIngestion(vault),
                  onRefresh: _refreshDashboardData,
                  onEditWorkout: (id, data) => vault != null
                      ? _editActivity(id, data, vault)
                      : Future.value(),
                  onDeleteWorkout: (id) => vault != null
                      ? _deleteActivity(id, vault)
                      : Future.value(),
                  onEditMeasurement: (entry, value) => vault != null
                      ? _editMeasurement(vault, entry, value)
                      : Future.value(),
                  onDeleteMeasurement: (entry) => vault != null
                      ? _deleteMeasurement(vault, entry)
                      : Future.value(),
                  onImportGpx: vault == null
                      ? null
                      : () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                                builder: (_) => GpxImportPage(vault: vault)),
                          ),
                  onExportGpx: (data) => ref
                      .read(vaultControllerProvider.notifier)
                      .whileShowingSystemUi(() => GpxWorkouts.share(data)),
                ),
                FitnessSettingsPage(
                  earnedMedals: _earnedMedals,
                  onDataDeleted: () {
                    setState(() {
                      _recentActivities = [];
                      _manualEntries = [];
                      _dailyMetrics = [];
                      _todayMetrics = <String, num>{};
                    });
                    _onVaultChanged();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        destinations: [
          NavigationDestination(
            icon: Icon(Icons.today_outlined),
            selectedIcon: Icon(Icons.today),
            label: context.l10n.today,
          ),
          NavigationDestination(
            icon: Icon(Icons.show_chart_outlined),
            selectedIcon: Icon(Icons.show_chart),
            label: context.l10n.trends,
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history),
            label: context.l10n.journal,
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: context.l10n.settings,
          ),
        ],
      ),
    );

    return Stack(
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
                    const ZtBrandMark(app: ZtSuite.fitness),
                    const SizedBox(height: 16),
                    Text(
                      ZtSuite.fitness.fullName,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
