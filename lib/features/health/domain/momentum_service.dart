import 'package:cryptography/cryptography.dart';
import 'package:zerotrust_fitness/core/storage/local_vault.dart';
import 'package:zerotrust_fitness/features/health/domain/momentum_engine.dart';

/// Bridges the encrypted daily-metrics rows in [LocalVault] to
/// [MomentumEngine], so the dashboard, widget sync and medals all read
/// Momentum the same way.
class MomentumService {
  const MomentumService._();

  /// Converts `LocalVault.fetchDailyMetrics` rows to day -> Heart Points.
  static Map<DateTime, int> historyFromDailyRows(
    List<Map<String, dynamic>> rows,
  ) {
    final history = <DateTime, int>{};
    for (final row in rows) {
      final date = DateTime.tryParse(row['date_key']?.toString() ?? '');
      if (date == null) continue;
      history[date] = _heartPoints(row);
    }
    return history;
  }

  /// Heart Points stored for [day], or 0 when there is no row.
  static int pointsForDay(List<Map<String, dynamic>> rows, DateTime day) {
    final local = day.toLocal();
    for (final row in rows) {
      final date = DateTime.tryParse(row['date_key']?.toString() ?? '');
      if (date != null &&
          date.year == local.year &&
          date.month == local.month &&
          date.day == local.day) {
        return _heartPoints(row);
      }
    }
    return 0;
  }

  /// Today's Momentum using stored history plus today's live [todayPoints].
  static Future<MomentumResult> forToday(
    SecretKey secretKey, {
    required int todayPoints,
  }) async {
    final rows = await LocalVault().fetchDailyMetrics(secretKey);
    return MomentumEngine.calculate(
      history: historyFromDailyRows(rows),
      today: DateTime.now(),
      todayPoints: todayPoints,
    );
  }

  static int _heartPoints(Map<String, dynamic> row) {
    final metrics = row['metrics'];
    final value = metrics is Map ? metrics['heart_points'] : null;
    final raw = value ?? row['heart_points'];
    if (raw is num) return raw.toInt();
    if (raw is String) return num.tryParse(raw)?.toInt() ?? 0;
    return 0;
  }
}
