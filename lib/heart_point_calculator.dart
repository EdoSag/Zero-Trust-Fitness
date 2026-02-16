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
}
