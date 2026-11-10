import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import 'package:zerotrust_fitness/core/storage/fitness_vault.dart';
import 'package:zerotrust_fitness/features/health/data/workout_feedback.dart';
import 'package:zerotrust_fitness/features/summary/weekly_summary.dart';

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
      'Time to move!',
      "You haven't been active in a while. A short walk counts.",
      RepeatInterval.hourly,
      _details('movement', 'Movement Reminders'),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  Future<void> cancelMovementReminder() =>
      _plugin.cancel(_kMovementId);

  // ---------------------------------------------------------------------------
  // Hydration reminder — repeats hourly
  // ---------------------------------------------------------------------------

  Future<void> scheduleHydrationReminder() async {
    await _plugin.cancel(_kHydrationId);
    await _plugin.periodicallyShow(
      _kHydrationId,
      'Stay hydrated!',
      'Drink a glass of water to keep your hydration on track.',
      RepeatInterval.hourly,
      _details('hydration', 'Hydration Reminders'),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  Future<void> cancelHydrationReminder() =>
      _plugin.cancel(_kHydrationId);

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
        'Workout time!',
        "Your scheduled workout is today. Let's get moving.",
        _nextInstanceOfWeekdayTime(day, time),
        _details('workout', 'Workout Reminders'),
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
      'Bedtime soon',
      'Winding down now supports better sleep quality.',
      _nextInstanceOfTime(time),
      _details('sleep', 'Sleep Reminders'),
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
      'Weekly check-in',
      'Time to log your weight or other measurements.',
      RepeatInterval.weekly,
      _details('measurement', 'Measurement Reminders'),
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
          'Weekly Summary',
          channelDescription: 'Your week of Heart Points and steps, Mondays',
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

  Future<void> cancelAll() => _plugin.cancelAll();

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
