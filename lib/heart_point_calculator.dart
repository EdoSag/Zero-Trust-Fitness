import 'package:nowa_runtime/nowa_runtime.dart';

@NowaGenerated()
class HeartPointCalculator {
  static double calculateMaxHeartRate(int age) {
    return 206.9 - (0.67 * age);
  }

  static int calculatePoints(
    double heartRate,
    double maxHeartRate,
    int minutes,
  ) {
    double percentage = heartRate / maxHeartRate;
    if (percentage >= 0.7) {
      return minutes * 2;
    } else if (percentage >= 0.5) {
      return minutes;
    }
    return 0;
  }

  static int calculateBriskWalkPoints(int stepsPerMinute, int minutes) {
    if (stepsPerMinute > 100) {
      return minutes;
    }
    return 0;
  }

  // Maps intensity 1–10 to Google Fit heart point zones:
  // 1–3 = light (0 pts), 4–6 = moderate (1 pt/min), 7–10 = vigorous (2 pts/min)
  static int calculateFromManualWorkout({
    required String activityType,
    required int durationMinutes,
    required int intensity,
  }) {
    if (durationMinutes <= 0) return 0;
    if (intensity <= 3) return 0;
    if (intensity <= 6) return durationMinutes;
    return durationMinutes * 2;
  }
}
