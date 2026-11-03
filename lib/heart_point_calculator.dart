import 'package:nowa_runtime/nowa_runtime.dart';
import 'package:zerotrust_fitness/features/health/domain/heart_points_engine.dart';

/// Legacy facade kept for existing callers. All thresholds live in
/// [HeartPointsEngine]; prefer `HeartPointsService.forDay` for daily totals.
@NowaGenerated()
class HeartPointCalculator {
  static double calculateMaxHeartRate(int age) {
    return HeartPointsEngine.maxHeartRate(age);
  }

  static int calculatePoints(
    double heartRate,
    double maxHeartRate,
    int minutes,
  ) {
    final percentage = maxHeartRate <= 0 ? 0 : heartRate / maxHeartRate;
    if (percentage >= HeartPointsEngine.vigorousHrMaxFraction) {
      return minutes * 2;
    } else if (percentage >= HeartPointsEngine.moderateHrMaxFraction) {
      return minutes;
    }
    return 0;
  }

  static int calculateBriskWalkPoints(int stepsPerMinute, int minutes) {
    return HeartPointsEngine.cadenceIntensity(stepsPerMinute).points * minutes;
  }

  // Maps intensity 1–10 to Google Fit heart point zones:
  // 1–3 = light (0 pts), 4–6 = moderate (1 pt/min), 7–10 = vigorous (2 pts/min)
  static int calculateFromManualWorkout({
    required String activityType,
    required int durationMinutes,
    required int intensity,
  }) {
    if (durationMinutes <= 0) return 0;
    return HeartPointsEngine.manualIntensity(intensity).points *
        durationMinutes;
  }
}
