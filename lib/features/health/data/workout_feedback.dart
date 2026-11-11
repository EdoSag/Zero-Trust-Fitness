import 'dart:async';
import 'dart:isolate';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zerotrust_fitness/features/health/data/gps_tracking_service.dart';
import 'package:zerotrust_fitness/l10n/l10n.dart';

// -----------------------------------------------------------------------------
// Voice cues
// -----------------------------------------------------------------------------

/// What the coach says, kept apart from the speech engine so it can be
/// tested.
class VoiceCues {
  static String split(SplitReached e) {
    final n = e.split.index;
    final total = _spoken(e.totalElapsed);
    final split = _spoken(e.split.duration);
    return e.unitMeters == 1000
        ? currentL10n.cueSplitKm(n, total, split)
        : currentL10n.cueSplitMile(n, total, split);
  }

  static String lap(LapMarked e) =>
      currentL10n.cueLap(e.lap.index, _spoken(e.lap.duration));

  static String get paused => currentL10n.workoutPaused;
  static String get resumed => currentL10n.workoutResumed;

  static String _spoken(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    final l = currentL10n;
    return [
      if (h > 0) l.spokenHours(h),
      if (m > 0 || h > 0) l.spokenMinutes(m),
      l.spokenSeconds(s),
    ].join(' ');
  }
}

/// Speaks splits, laps and auto-pause while a GPS workout records. The
/// phone's own text-to-speech does it, offline; nothing leaves the device.
class VoiceCoach {
  VoiceCoach._();
  static final VoiceCoach instance = VoiceCoach._();

  static const prefsKey = 'gps_voice_cues';

  FlutterTts? _tts;
  StreamSubscription<GpsEvent>? _sub;

  Future<bool> get isEnabled async =>
      (await SharedPreferences.getInstance()).getBool(prefsKey) ?? true;

  Future<void> setEnabled(bool on) async =>
      (await SharedPreferences.getInstance()).setBool(prefsKey, on);

  /// Listens to [service] for the rest of the workout.
  Future<void> attach(GpsTrackingService service) async {
    await _sub?.cancel();
    _sub = service.events.listen((e) async {
      if (!await isEnabled) return;
      final text = switch (e) {
        SplitReached() => VoiceCues.split(e),
        LapMarked() => VoiceCues.lap(e),
        AutoPaused() => VoiceCues.paused,
        AutoResumed() => VoiceCues.resumed,
      };
      await _say(text);
    });
  }

  Future<void> detach() async {
    await _sub?.cancel();
    _sub = null;
    await _tts?.stop();
  }

  Future<void> _say(String text) async {
    try {
      final tts = _tts ??= await _create();
      await tts.speak(text, focus: true);
    } on Object catch (e) {
      debugPrint('Voice cue failed: $e');
    }
  }

  static Future<FlutterTts> _create() async {
    final tts = FlutterTts();
    await tts.setSpeechRate(0.5);
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      // Speak over (and briefly lower) the person's music.
      await tts.setIosAudioCategory(
        IosTextToSpeechAudioCategory.playback,
        [
          IosTextToSpeechAudioCategoryOptions.duckOthers,
          IosTextToSpeechAudioCategoryOptions.mixWithOthers,
        ],
      );
    }
    return tts;
  }
}

// -----------------------------------------------------------------------------
// Lock-screen controls
// -----------------------------------------------------------------------------

const _portName = 'zt_fitness_gps_actions';
const _pauseAction = 'gps_pause';
const _resumeAction = 'gps_resume';
const _lapAction = 'gps_lap';

/// Taps on the workout notification's buttons arrive here when the app's
/// own isolate isn't the one handling them (Android runs notification
/// actions in a background isolate): they're passed on to the app.
@pragma('vm:entry-point')
void workoutNotificationBackgroundHandler(NotificationResponse response) {
  final id = response.actionId;
  if (id == null) return;
  IsolateNameServer.lookupPortByName(_portName)?.send(id);
}

/// Taps that arrive in the app's own isolate.
void workoutNotificationForegroundHandler(NotificationResponse response) {
  final id = response.actionId;
  if (id != null) WorkoutNotification.instance._handle(id);
}

/// An ongoing notification while a GPS workout records (Android): time,
/// distance and Pause / Resume and Lap buttons on the lock screen. It is
/// also the foreground service that keeps location coming while the screen
/// is off.
///
/// It shows the activity, time and distance only; never the route or a
/// place.
class WorkoutNotification {
  WorkoutNotification._();
  static final WorkoutNotification instance = WorkoutNotification._();

  static const int notificationId = 4242;
  static const _channelId = 'gps_workout';

  final _plugin = FlutterLocalNotificationsPlugin();
  GpsTrackingService? _service;
  StreamSubscription<GpsTrackingSnapshot>? _sub;
  ReceivePort? _port;
  DateTime _lastUpdate = DateTime(2000);
  bool? _lastPaused;

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  Future<void> start(GpsTrackingService service) async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    _service = service;
    _port?.close();
    IsolateNameServer.removePortNameMapping(_portName);
    final port = ReceivePort();
    IsolateNameServer.registerPortWithName(port.sendPort, _portName);
    port.listen((id) => _handle(id as String));
    _port = port;

    try {
      final s = service.current;
      await _android?.startForegroundService(
        notificationId,
        _title(s),
        _body(s),
        notificationDetails: _details(s),
        foregroundServiceTypes: {
          AndroidServiceForegroundType.foregroundServiceTypeLocation,
        },
      );
    } on Object catch (e) {
      debugPrint('Workout notification failed: $e');
    }
    await _sub?.cancel();
    _sub = service.snapshots.listen(_update);
  }

  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
    _port?.close();
    _port = null;
    IsolateNameServer.removePortNameMapping(_portName);
    _service = null;
    _lastPaused = null;
    if (defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await _android?.stopForegroundService();
    } on Object catch (e) {
      debugPrint('Stopping workout notification failed: $e');
    }
  }

  void _handle(String actionId) {
    final service = _service;
    if (service == null) return;
    switch (actionId) {
      case _pauseAction:
        service.pause();
      case _resumeAction:
        service.resume();
      case _lapAction:
        service.lap();
    }
  }

  Future<void> _update(GpsTrackingSnapshot s) async {
    if (!s.isTracking) return;
    final now = DateTime.now();
    // Every few seconds is plenty, except when the buttons change.
    if (_lastPaused == s.isPaused &&
        now.difference(_lastUpdate) < const Duration(seconds: 5)) {
      return;
    }
    _lastUpdate = now;
    _lastPaused = s.isPaused;
    try {
      await _plugin.show(
          notificationId, _title(s), _body(s), NotificationDetails(android: _details(s)));
    } on Object catch (e) {
      debugPrint('Workout notification update failed: $e');
    }
  }

  String _title(GpsTrackingSnapshot s) {
    final type = _service?.activityType;
    final activity = type == null ? currentL10n.workout : activityLabel(type);
    if (s.isAutoPaused) return currentL10n.activityAutoPaused(activity);
    if (s.isPaused) return currentL10n.activityPaused(activity);
    return activity;
  }

  String _body(GpsTrackingSnapshot s) {
    final unit = _service?.splitMeters == GpsTrackingService.metersPerMile
        ? GpsTrackingService.metersPerMile
        : 1000.0;
    final label = unit == 1000 ? 'km' : 'mi';
    final d = s.elapsed;
    final clock = '${d.inHours}:${d.inMinutes.remainder(60).toString().padLeft(2, '0')}'
        ':${d.inSeconds.remainder(60).toString().padLeft(2, '0')}';
    return '${(s.distanceMeters / unit).toStringAsFixed(2)} $label · $clock';
  }

  AndroidNotificationDetails _details(GpsTrackingSnapshot s) =>
      AndroidNotificationDetails(
        _channelId,
        currentL10n.gpsWorkout,
        channelDescription: currentL10n.timeDistanceAndControlsWhile,
        importance: Importance.low,
        priority: Priority.low,
        ongoing: true,
        autoCancel: false,
        onlyAlertOnce: true,
        showWhen: false,
        playSound: false,
        enableVibration: false,
        category: AndroidNotificationCategory.workout,
        visibility: NotificationVisibility.public,
        actions: [
          s.isPaused
              ? AndroidNotificationAction(_resumeAction, currentL10n.resume,
                  cancelNotification: false)
              : AndroidNotificationAction(_pauseAction, currentL10n.pause,
                  cancelNotification: false),
          AndroidNotificationAction(_lapAction, currentL10n.lap,
              cancelNotification: false),
        ],
      );
}
