import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Notification IDs
const int _kMovementId = 1001;
const int _kHydrationId = 1002;
const int _kSleepId = 1010;
const int _kMeasurementId = 1011;
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
    await _plugin.initialize(settings);
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

  tz.TZDateTime _nextInstanceOfTime(TimeOfDay time) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
        tz.local, now.year, now.month, now.day, time.hour, time.minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  tz.TZDateTime _nextInstanceOfWeekdayTime(int weekday, TimeOfDay time) {
    var dt = _nextInstanceOfTime(time);
    while (dt.weekday != weekday) {
      dt = dt.add(const Duration(days: 1));
    }
    return dt;
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
  }

  Future<void> applySettings(ReminderSettings s) async {
    await saveSettings(s);
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
  });

  final bool movementEnabled;
  final bool hydrationEnabled;
  final bool workoutEnabled;
  final List<int> workoutDays; // DateTime.monday=1 … DateTime.sunday=7
  final TimeOfDay workoutTime;
  final bool sleepEnabled;
  final TimeOfDay sleepTime;
  final bool measurementEnabled;

  ReminderSettings copyWith({
    bool? movementEnabled,
    bool? hydrationEnabled,
    bool? workoutEnabled,
    List<int>? workoutDays,
    TimeOfDay? workoutTime,
    bool? sleepEnabled,
    TimeOfDay? sleepTime,
    bool? measurementEnabled,
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
      );
}
