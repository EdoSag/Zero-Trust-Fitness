import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zerotrust_fitness/core/storage/fitness_vault.dart';
import 'package:zerotrust_fitness/core/utils/units_formatter.dart';

/// Today's numbers as the watch shows them.
@immutable
class WearToday {
  const WearToday({
    required this.day,
    required this.steps,
    required this.stepsGoal,
    required this.heartPoints,
    required this.heartPointsGoal,
    required this.waterMl,
    required this.waterGoalMl,
    required this.glassMl,
    required this.imperial,
  });

  final String day;
  final int steps, stepsGoal, heartPoints, heartPointsGoal;
  final int waterMl, waterGoalMl, glassMl;
  final bool imperial;

  Map<String, Object> toMap() => {
    'day': day,
    'steps': steps,
    'stepsGoal': stepsGoal,
    'heartPoints': heartPoints,
    'heartPointsGoal': heartPointsGoal,
    'waterMl': waterMl,
    'waterGoalMl': waterGoalMl,
    'glassMl': glassMl,
    'imperial': imperial,
  };

  @override
  bool operator ==(Object other) =>
      other is WearToday && mapEquals(other.toMap(), toMap());

  @override
  int get hashCode => Object.hashAll(toMap().values);
}

/// The Wear OS companion (F10): sends today's totals to the paired watch
/// while the vault is open, and brings in water logged on the watch.
///
/// Off until the person turns it on in Settings: the numbers then leave the
/// phone (only to the paired watch, over the Wear OS Data Layer).
class WearCompanion {
  WearCompanion._();
  static final instance = WearCompanion._();

  static const _channel = MethodChannel('zt.fitness/wear');
  static const _enabledKey = 'wear_companion_enabled';

  WearToday? _lastSent;

  Future<bool> get isEnabled async =>
      (await SharedPreferences.getInstance()).getBool(_enabledKey) ?? false;

  Future<void> setEnabled(bool on) async {
    await (await SharedPreferences.getInstance()).setBool(_enabledKey, on);
    _lastSent = null;
    if (!on) await _call('clear');
  }

  /// What [today]'s metrics and goals look like on the watch.
  static WearToday todayFrom(
    Map<String, num> metrics, {
    required num? stepsGoal,
    required num? heartPointsGoal,
    required num? waterGoalLiters,
    DateTime? now,
  }) {
    final units = UnitsFormatter();
    return WearToday(
      day: FitnessVault.dateKeyOf(now ?? DateTime.now()),
      steps: (metrics['steps'] ?? 0).round(),
      stepsGoal: (stepsGoal ?? 10000).round(),
      heartPoints: (metrics['heart_points'] ?? 0).round(),
      heartPointsGoal: (heartPointsGoal ?? 150 / 7).round(),
      waterMl: ((metrics['water_l'] ?? 0) * 1000).round(),
      waterGoalMl: ((waterGoalLiters ?? 2.0) * 1000).round(),
      glassMl: (units.waterPresets.first.liters * 1000).round(),
      imperial: units.distanceUnit == DistanceUnit.imperial,
    );
  }

  /// Sends [today] to the watch when it changed since the last send.
  Future<void> push(WearToday today) async {
    if (!await isEnabled || today == _lastSent) return;
    final ok = await _call('pushToday', today.toMap());
    if (ok == true) _lastSent = today;
  }

  /// Adds water logged on the watch while the app was closed or locked to
  /// today. Returns the litres added.
  Future<double> drainPendingWater(FitnessVault vault) async {
    final ml = await _call('takePendingWater');
    if (ml is! int || ml <= 0) return 0;
    final liters = ml / 1000;
    await vault.addWater(FitnessVault.dateKeyOf(DateTime.now()), liters);
    return liters;
  }

  /// Phones without Google Play services, iOS and tests have no watch.
  Future<Object?> _call(String method, [Object? args]) async {
    if (defaultTargetPlatform != TargetPlatform.android) return null;
    try {
      return await _channel.invokeMethod<Object?>(method, args);
    } on MissingPluginException {
      return null;
    } on PlatformException catch (e) {
      debugPrint('Wear companion: ${e.message}');
      return null;
    }
  }
}
