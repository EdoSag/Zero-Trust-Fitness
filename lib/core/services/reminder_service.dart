import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import 'package:zerotrust_fitness/core/storage/fitness_vault.dart';
import 'package:zerotrust_fitness/features/health/data/workout_feedback.dart';
import 'package:zerotrust_fitness/features/summary/weekly_summary.dart';
import 'package:zerotrust_fitness/l10n/l10n.dart';

/// Notification IDs
const int _kMovementId = 1001;
const int _kHydrationId = 1002;
const int _kSleepId = 1010;
const int _kMeasurementId = 1011;
const int _kWeeklySummaryId = 1012;
// Workout uses 1003–1009 (one per weekday 1–7)

/// SharedPreferences keys
const String kReminderMovementEnabled = 'reminder_movement_enabled';
const String kReminderHydrationEnabled = 'reminder_hydration_enabled';
const String kReminderWorkoutEnabled = 'reminder_workout_enabled';
const String kReminderWorkoutDays = 'reminder_workout_days'; // JSON int list
const String kReminderWorkoutHour = 'reminder_workout_hour';
const String kReminderWorkoutMinute = 'reminder_workout_minute';
const String kReminderSleepEnabled = 'reminder_sleep_enabled';
const String kReminderSleepHour = 'reminder_sleep_hour';
const String kReminderSleepMinute = 'reminder_sleep_minute';
const String kReminderMeasurementEnabled = 'reminder_measurement_enabled';
const String kWeeklySummaryEnabled = 'weekly_summary_enabled';

/// When the hydration reminder counts its hours from (milliseconds since
/// the epoch): the last water logged, or when the reminder was turned on.
const String kReminderHydrationCountFrom = 'reminder_hydration_count_from_ms';

class ReminderService {
  ReminderService._();
  factory ReminderService() => _instance;
  static final ReminderService _instance = ReminderService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    tz_data.initializeTimeZones();
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const settings =
        InitializationSettings(android: androidSettings, iOS: darwinSettings);
    // The GPS workout notification's buttons (Pause, Lap) are handled here
    // too: the plugin keeps one set of handlers for the whole app.
    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: workoutNotificationForegroundHandler,
      onDidReceiveBackgroundNotificationResponse:
          workoutNotificationBackgroundHandler,
    );
    _initialized = true;
  }

  Future<bool> requestPermission() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    return await android?.requestNotificationsPermission() ?? false;
  }

  // ---------------------------------------------------------------------------
  // Movement reminder — repeats hourly
  // ---------------------------------------------------------------------------

  Future<void> scheduleMovementReminder() async {
    await _plugin.cancel(_kMovementId);
    await _plugin.periodicallyShow(
      _kMovementId,
      currentL10n.timeToMove,
      currentL10n.youHaventBeenActiveIn,
      RepeatInterval.hourly,
      _details('movement', currentL10n.movementReminders),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  Future<void> cancelMovementReminder() =>
      _plugin.cancel(_kMovementId);

  // ---------------------------------------------------------------------------
  // Hydration reminder — hourly, counted from the last water logged
  // ---------------------------------------------------------------------------

  /// Schedules the hourly reminder, counted from [from]: the first one comes
  /// an hour after it, then one every hour.
  ///
  /// Without [from] it keeps counting from where it was (so changing another
  /// reminder or the language doesn't move it), or from now when it is new.
  Future<void> scheduleHydrationReminder({DateTime? from, DateTime? now}) async {
    final prefs = await SharedPreferences.getInstance();
    final at = now ?? DateTime.now();
    var countFrom = from ?? _hydrationCountFrom(prefs, at) ?? at;
    if (countFrom.isAfter(at)) countFrom = at;
    await prefs.setInt(
        kReminderHydrationCountFrom, countFrom.millisecondsSinceEpoch);
    // Also clears a reminder that is showing.
    await _plugin.cancel(_kHydrationId);
    // On Android the plugin counts the repeats from the moment it is called,
    // which it reads from package:clock, so that is set to [countFrom] for
    // the call. Always a little in the past: a time that isn't would be
    // shown at once. (iOS counts the hour from now whatever the clock says.)
    final latest = at.subtract(const Duration(seconds: 1));
    await withClock(
      Clock.fixed(countFrom.isAfter(latest) ? latest : countFrom),
      () => _plugin.periodicallyShow(
        _kHydrationId,
        currentL10n.stayHydrated,
        currentL10n.drinkAGlassOfWater,
        RepeatInterval.hourly,
        _details('hydration', currentL10n.hydrationReminders),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      ),
    );
  }

  Future<void> cancelHydrationReminder() async {
    await _plugin.cancel(_kHydrationId);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(kReminderHydrationCountFrom);
  }

  /// Water was logged at [at] (now when not given): the hourly reminder
  /// counts again from then, so the next one comes an hour after the water.
  ///
  /// Does nothing while the reminder is off, or when [at] is no later than
  /// what it already counts from (water it has seen before). Returns
  /// whether the reminder was restarted.
  Future<bool> restartHydrationReminder({DateTime? at, DateTime? now}) {
    // One at a time: water seen in the app and in Health Connect at the
    // same moment must not leave the earlier of the two in charge.
    final done =
        _hydrationQueue.then((_) => _restartHydrationReminder(at, now));
    _hydrationQueue = done.then((_) {}, onError: (_) {});
    return done;
  }

  Future<void> _hydrationQueue = Future.value();

  Future<bool> _restartHydrationReminder(DateTime? at, DateTime? now) async {
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool(kReminderHydrationEnabled) ?? false)) return false;
    final current = now ?? DateTime.now();
    var loggedAt = at ?? current;
    if (loggedAt.isAfter(current)) loggedAt = current;
    final countFrom = _hydrationCountFrom(prefs, current);
    if (countFrom != null && !loggedAt.isAfter(countFrom)) return false;
    await scheduleHydrationReminder(from: loggedAt, now: current);
    return true;
  }

  /// Tells the reminder how much water [dateKey] (today) has logged in this
  /// app, whenever that may have changed. More than last time means water
  /// was just logged (a tap in the app, the watch, another device), which
  /// restarts the reminder; water taken off doesn't.
  ///
  /// The first call after the app starts only notes the amount: what was
  /// logged before can't be told from new water. Returns whether the
  /// reminder was restarted.
  Future<bool> noteLoggedWater(String dateKey, num liters,
      {DateTime? now}) async {
    // A new day starts with nothing logged.
    final before = _waterDay == null
        ? null
        : (_waterDay == dateKey ? _waterLiters : 0);
    _waterDay = dateKey;
    _waterLiters = liters;
    if (before == null || liters <= before + _waterTolerance) return false;
    return restartHydrationReminder(now: now);
  }

  String? _waterDay;
  num _waterLiters = 0;

  /// Half a millilitre: smaller differences are rounding.
  static const _waterTolerance = 0.0005;

  /// Forgets the water seen so far, as after an app start.
  @visibleForTesting
  void forgetLoggedWater() => _waterDay = null;

  /// What the reminder counts from; null when nothing is saved, or the
  /// saved time is ahead of the clock (the phone's time was set back).
  static DateTime? _hydrationCountFrom(SharedPreferences prefs, DateTime now) {
    final ms = prefs.getInt(kReminderHydrationCountFrom);
    if (ms == null || ms > now.millisecondsSinceEpoch) return null;
    return DateTime.fromMillisecondsSinceEpoch(ms);
  }

  // ---------------------------------------------------------------------------
  // Workout reminder — weekly on selected days at a specific time
  // ---------------------------------------------------------------------------

  Future<void> scheduleWorkoutReminder(
      List<int> weekdays, TimeOfDay time) async {
    // Cancel all 7 possible workout slots first
    for (int i = 1; i <= 7; i++) {
      await _plugin.cancel(1002 + i);
    }
    for (final day in weekdays) {
      final id = 1002 + day; // 1003–1009
      await _plugin.zonedSchedule(
        id,
        currentL10n.workoutTime,
        currentL10n.yourScheduledWorkoutIsToday,
        _nextInstanceOfWeekdayTime(day, time),
        _details('workout', currentL10n.workoutReminders),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      );
    }
  }

  Future<void> cancelWorkoutReminder() async {
    for (int i = 1; i <= 7; i++) {
      await _plugin.cancel(1002 + i);
    }
  }

  // ---------------------------------------------------------------------------
  // Sleep reminder — daily at a specific time
  // ---------------------------------------------------------------------------

  Future<void> scheduleSleepReminder(TimeOfDay time) async {
    await _plugin.cancel(_kSleepId);
    await _plugin.zonedSchedule(
      _kSleepId,
      currentL10n.bedtimeSoon,
      currentL10n.windingDownNowSupportsBetter,
      _nextInstanceOfTime(time),
      _details('sleep', currentL10n.sleepReminders),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> cancelSleepReminder() => _plugin.cancel(_kSleepId);

  // ---------------------------------------------------------------------------
  // Measurement reminder — weekly (weigh-in, etc.)
  // ---------------------------------------------------------------------------

  Future<void> scheduleMeasurementReminder() async {
    await _plugin.cancel(_kMeasurementId);
    await _plugin.periodicallyShow(
      _kMeasurementId,
      currentL10n.weeklyCheckIn,
      currentL10n.timeToLogYourWeight,
      RepeatInterval.weekly,
      _details('measurement', currentL10n.measurementReminders),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  Future<void> cancelMeasurementReminder() =>
      _plugin.cancel(_kMeasurementId);

  // ---------------------------------------------------------------------------
  // Weekly summary — Monday 09:00, about the week that just ended
  // ---------------------------------------------------------------------------

  /// Schedules the next weekly summary from the vault as it is now.
  ///
  /// The vault is encrypted and locked while the app is closed, so the
  /// summary can't be worked out in the background on Monday morning.
  /// Instead it is worked out every time the app has the data open, and the
  /// one pending notification is replaced; if the app isn't opened again
  /// before Monday, the text says which day it counts up to.
  Future<void> refreshWeeklySummary(FitnessVault vault, {DateTime? now}) async {
    final prefs = await SharedPreferences.getInstance();
    if (!(prefs.getBool(kWeeklySummaryEnabled) ?? false)) return;
    final at = now ?? DateTime.now();
    final slot = nextWeeklySummarySlot(at);
    final summary = WeeklySummary.compute(
      dailyRows: await vault.fetchDailyMetrics(),
      workouts: [for (final w in await vault.fetchWorkouts()) w.data],
      weekOf: slot.weekOf,
      now: at,
    );
    await scheduleWeeklySummary(summary, slot.at);
  }

  Future<void> scheduleWeeklySummary(WeeklySummary summary, DateTime at) async {
    if (!_initialized) await initialize();
    await _plugin.cancel(_kWeeklySummaryId);
    await _plugin.zonedSchedule(
      _kWeeklySummaryId,
      summary.title,
      summary.body,
      tz.TZDateTime.from(at, tz.local),
      NotificationDetails(
        android: AndroidNotificationDetails(
          'zt_health_weekly_summary',
          currentL10n.weeklySummary,
          channelDescription: currentL10n.yourWeekOfHeartPoints,
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          icon: '@mipmap/ic_launcher',
          styleInformation: BigTextStyleInformation(summary.body),
          // Health numbers stay off the lock screen unless the phone is set
          // to show private notification content.
          visibility: NotificationVisibility.private,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> cancelWeeklySummary() => _plugin.cancel(_kWeeklySummaryId);

  Future<void> cancelAll() async {
    await _plugin.cancelAll();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(kReminderHydrationCountFrom);
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  NotificationDetails _details(String channelId, String channelName) {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        'zt_health_$channelId',
        channelName,
        channelDescription: channelName,
        importance: Importance.low,
        priority: Priority.low,
        icon: '@mipmap/ic_launcher',
      ),
      iOS: const DarwinNotificationDetails(),
    );
  }

  // The timezone database's `local` is UTC (the app never sets the phone's
  // zone), so times are worked out in the phone's local time and handed
  // over as that instant. Repeats then keep the same instant each day.
  tz.TZDateTime _nextInstanceOfTime(TimeOfDay time) =>
      tz.TZDateTime.from(_nextLocal(time, null), tz.local);

  tz.TZDateTime _nextInstanceOfWeekdayTime(int weekday, TimeOfDay time) =>
      tz.TZDateTime.from(_nextLocal(time, weekday), tz.local);

  static DateTime _nextLocal(TimeOfDay time, int? weekday) {
    final now = DateTime.now();
    var at = DateTime(now.year, now.month, now.day, time.hour, time.minute);
    while (!at.isAfter(now) || (weekday != null && at.weekday != weekday)) {
      at = DateTime(at.year, at.month, at.day + 1, time.hour, time.minute);
    }
    return at;
  }

  // ---------------------------------------------------------------------------
  // Persist + load settings
  // ---------------------------------------------------------------------------

  Future<ReminderSettings> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final workoutDaysJson = prefs.getString(kReminderWorkoutDays) ?? '[]';
    final workoutDays =
        (jsonDecode(workoutDaysJson) as List).cast<int>();
    return ReminderSettings(
      movementEnabled: prefs.getBool(kReminderMovementEnabled) ?? false,
      hydrationEnabled: prefs.getBool(kReminderHydrationEnabled) ?? false,
      workoutEnabled: prefs.getBool(kReminderWorkoutEnabled) ?? false,
      workoutDays: workoutDays,
      workoutTime: TimeOfDay(
        hour: prefs.getInt(kReminderWorkoutHour) ?? 7,
        minute: prefs.getInt(kReminderWorkoutMinute) ?? 0,
      ),
      sleepEnabled: prefs.getBool(kReminderSleepEnabled) ?? false,
      sleepTime: TimeOfDay(
        hour: prefs.getInt(kReminderSleepHour) ?? 22,
        minute: prefs.getInt(kReminderSleepMinute) ?? 0,
      ),
      measurementEnabled:
          prefs.getBool(kReminderMeasurementEnabled) ?? false,
      weeklySummaryEnabled: prefs.getBool(kWeeklySummaryEnabled) ?? false,
    );
  }

  Future<void> saveSettings(ReminderSettings s) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kReminderMovementEnabled, s.movementEnabled);
    await prefs.setBool(kReminderHydrationEnabled, s.hydrationEnabled);
    await prefs.setBool(kReminderWorkoutEnabled, s.workoutEnabled);
    await prefs.setString(
        kReminderWorkoutDays, jsonEncode(s.workoutDays));
    await prefs.setInt(kReminderWorkoutHour, s.workoutTime.hour);
    await prefs.setInt(kReminderWorkoutMinute, s.workoutTime.minute);
    await prefs.setBool(kReminderSleepEnabled, s.sleepEnabled);
    await prefs.setInt(kReminderSleepHour, s.sleepTime.hour);
    await prefs.setInt(kReminderSleepMinute, s.sleepTime.minute);
    await prefs.setBool(kReminderMeasurementEnabled, s.measurementEnabled);
    await prefs.setBool(kWeeklySummaryEnabled, s.weeklySummaryEnabled);
  }

  /// Saves and schedules [s]. The weekly summary needs the open [vault] to
  /// be worked out.
  Future<void> applySettings(ReminderSettings s, {FitnessVault? vault}) async {
    await saveSettings(s);
    if (!s.weeklySummaryEnabled) {
      await cancelWeeklySummary();
    } else if (vault != null) {
      await refreshWeeklySummary(vault);
    }
    if (s.movementEnabled) {
      await scheduleMovementReminder();
    } else {
      await cancelMovementReminder();
    }
    if (s.hydrationEnabled) {
      await scheduleHydrationReminder();
    } else {
      await cancelHydrationReminder();
    }
    if (s.workoutEnabled && s.workoutDays.isNotEmpty) {
      await scheduleWorkoutReminder(s.workoutDays, s.workoutTime);
    } else {
      await cancelWorkoutReminder();
    }
    if (s.sleepEnabled) {
      await scheduleSleepReminder(s.sleepTime);
    } else {
      await cancelSleepReminder();
    }
    if (s.measurementEnabled) {
      await scheduleMeasurementReminder();
    } else {
      await cancelMeasurementReminder();
    }
  }
}

class ReminderSettings {
  const ReminderSettings({
    required this.movementEnabled,
    required this.hydrationEnabled,
    required this.workoutEnabled,
    required this.workoutDays,
    required this.workoutTime,
    required this.sleepEnabled,
    required this.sleepTime,
    required this.measurementEnabled,
    this.weeklySummaryEnabled = false,
  });

  final bool movementEnabled;
  final bool hydrationEnabled;
  final bool workoutEnabled;
  final List<int> workoutDays; // DateTime.monday=1 … DateTime.sunday=7
  final TimeOfDay workoutTime;
  final bool sleepEnabled;
  final TimeOfDay sleepTime;
  final bool measurementEnabled;
  final bool weeklySummaryEnabled;

  ReminderSettings copyWith({
    bool? movementEnabled,
    bool? hydrationEnabled,
    bool? workoutEnabled,
    List<int>? workoutDays,
    TimeOfDay? workoutTime,
    bool? sleepEnabled,
    TimeOfDay? sleepTime,
    bool? measurementEnabled,
    bool? weeklySummaryEnabled,
  }) =>
      ReminderSettings(
        movementEnabled: movementEnabled ?? this.movementEnabled,
        hydrationEnabled: hydrationEnabled ?? this.hydrationEnabled,
        workoutEnabled: workoutEnabled ?? this.workoutEnabled,
        workoutDays: workoutDays ?? this.workoutDays,
        workoutTime: workoutTime ?? this.workoutTime,
        sleepEnabled: sleepEnabled ?? this.sleepEnabled,
        sleepTime: sleepTime ?? this.sleepTime,
        measurementEnabled: measurementEnabled ?? this.measurementEnabled,
        weeklySummaryEnabled:
            weeklySummaryEnabled ?? this.weeklySummaryEnabled,
      );
}
