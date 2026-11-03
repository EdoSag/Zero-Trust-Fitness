import 'package:health/health.dart';
import 'package:zerotrust_fitness/features/health/domain/heart_points_engine.dart';

/// Converts raw [HealthDataPoint]s into Heart Points for one local day.
///
/// This is the single place the app turns health data into Heart Points, used
/// by the dashboard, the hourly chart and the background/widget sync.
class HeartPointsService {
  const HeartPointsService._();

  static HeartPointsResult forDay(
    Iterable<HealthDataPoint> points,
    DateTime day, {
    int age = HeartPointsEngine.defaultAge,
  }) {
    final local = day.toLocal();
    final dayStart = DateTime(local.year, local.month, local.day);
    final dayEnd = DateTime(local.year, local.month, local.day + 1);

    final heartRate = <HeartRateSample>[];
    final steps = <StepSample>[];
    final exercise = <ActiveInterval>[];
    final resting = <double>[];

    for (final point in points) {
      switch (point.type) {
        case HealthDataType.HEART_RATE:
          heartRate.add(HeartRateSample(point.dateFrom, numericValue(point)));
        case HealthDataType.RESTING_HEART_RATE:
          final bpm = numericValue(point);
          if (bpm > 0) resting.add(bpm);
        case HealthDataType.STEPS:
          steps.add(
            StepSample(
              start: point.dateFrom,
              end: point.dateTo,
              count: numericValue(point),
              sourceId: point.sourceId,
            ),
          );
        case HealthDataType.WORKOUT:
          exercise.add(ActiveInterval(point.dateFrom, point.dateTo));
        case HealthDataType.EXERCISE_TIME:
          // Apple exercise minutes: usually a 1-minute interval, but fall back
          // to the reported minute count when the interval is empty.
          var end = point.dateTo;
          if (!end.isAfter(point.dateFrom)) {
            final minutes = numericValue(point);
            end = point.dateFrom.add(Duration(seconds: (minutes * 60).round()));
          }
          exercise.add(ActiveInterval(point.dateFrom, end));
        default:
          break;
      }
    }

    double? restingBpm;
    if (resting.isNotEmpty) {
      restingBpm = resting.reduce((a, b) => a + b) / resting.length;
    }

    return HeartPointsEngine.calculate(
      windowStart: dayStart,
      windowEnd: dayEnd,
      heartRate: heartRate,
      steps: steps,
      exercise: exercise,
      age: age,
      restingBpm: restingBpm,
    );
  }

  static double numericValue(HealthDataPoint point) {
    final value = point.value;
    if (value is NumericHealthValue) {
      return value.numericValue.toDouble();
    }
    return double.tryParse(value.toString()) ?? 0.0;
  }
}
