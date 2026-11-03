import 'package:shared_preferences/shared_preferences.dart';

enum DistanceUnit { metric, imperial }
enum TimeFormat { h24, h12 }

class UnitsFormatter {
  UnitsFormatter._();
  factory UnitsFormatter() => _instance;
  static final UnitsFormatter _instance = UnitsFormatter._();

  static const _kDistanceUnit = 'units_distance';
  static const _kTimeFormat = 'units_time_format';

  DistanceUnit _distanceUnit = DistanceUnit.metric;
  TimeFormat _timeFormat = TimeFormat.h24;

  DistanceUnit get distanceUnit => _distanceUnit;
  TimeFormat get timeFormat => _timeFormat;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final d = prefs.getString(_kDistanceUnit);
    _distanceUnit = d == 'imperial' ? DistanceUnit.imperial : DistanceUnit.metric;
    final t = prefs.getString(_kTimeFormat);
    _timeFormat = t == '12h' ? TimeFormat.h12 : TimeFormat.h24;
  }

  Future<void> setDistanceUnit(DistanceUnit unit) async {
    _distanceUnit = unit;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kDistanceUnit, unit == DistanceUnit.imperial ? 'imperial' : 'metric');
  }

  Future<void> setTimeFormat(TimeFormat fmt) async {
    _timeFormat = fmt;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kTimeFormat, fmt == TimeFormat.h12 ? '12h' : '24h');
  }

  // ---------------------------------------------------------------------------
  // Formatting helpers used throughout the app
  // ---------------------------------------------------------------------------

  /// Distance in km → formatted string with unit label.
  String formatDistance(double km) {
    if (_distanceUnit == DistanceUnit.imperial) {
      final miles = km * 0.621371;
      return '${miles.toStringAsFixed(2)} mi';
    }
    return '${km.toStringAsFixed(2)} km';
  }

  /// Speed in km/h → formatted string.
  String formatSpeed(double kmh) {
    if (_distanceUnit == DistanceUnit.imperial) {
      return '${(kmh * 0.621371).toStringAsFixed(1)} mph';
    }
    return '${kmh.toStringAsFixed(1)} km/h';
  }

  /// Pace in min/km → formatted string (min/km or min/mi).
  String formatPace(double minPerKm) {
    final pace = _distanceUnit == DistanceUnit.imperial
        ? minPerKm / 0.621371
        : minPerKm;
    final mins = pace.floor();
    final secs = ((pace - mins) * 60).round();
    final unit = _distanceUnit == DistanceUnit.imperial ? '/mi' : '/km';
    return "$mins'${secs.toString().padLeft(2, '0')}\"$unit";
  }

  /// Weight in kg → formatted string.
  String formatWeight(double kg) {
    if (_distanceUnit == DistanceUnit.imperial) {
      return '${(kg * 2.20462).toStringAsFixed(1)} lbs';
    }
    return '${kg.toStringAsFixed(1)} kg';
  }

  /// Height in cm → formatted string.
  String formatHeight(double cm) {
    if (_distanceUnit == DistanceUnit.imperial) {
      final totalInches = cm / 2.54;
      final feet = totalInches ~/ 12;
      final inches = (totalInches % 12).round();
      return "${feet}' ${inches}\"";
    }
    return '${cm.toStringAsFixed(0)} cm';
  }

  /// Format a DateTime for display using the user's preferred time format.
  String formatTime(DateTime dt) {
    final local = dt.toLocal();
    final h = _timeFormat == TimeFormat.h12
        ? (local.hour % 12 == 0 ? 12 : local.hour % 12)
        : local.hour;
    final m = local.minute.toString().padLeft(2, '0');
    final suffix = _timeFormat == TimeFormat.h12
        ? (local.hour < 12 ? ' AM' : ' PM')
        : '';
    return '$h:$m$suffix';
  }

  String formatDate(DateTime dt) {
    final d = dt.toLocal();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }
}
