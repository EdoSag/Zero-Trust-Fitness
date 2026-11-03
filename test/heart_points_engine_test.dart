import 'package:flutter_test/flutter_test.dart';
import 'package:zerotrust_fitness/features/health/domain/heart_points_engine.dart';

void main() {
  final dayStart = DateTime(2026, 11, 3);
  final dayEnd = DateTime(2026, 11, 4);
  DateTime at(int h, int m, [int s = 0]) => DateTime(2026, 11, 3, h, m, s);

  HeartPointsResult run({
    List<HeartRateSample> hr = const [],
    List<StepSample> steps = const [],
    List<ActiveInterval> exercise = const [],
    double? resting,
  }) => HeartPointsEngine.calculate(
    windowStart: dayStart,
    windowEnd: dayEnd,
    heartRate: hr,
    steps: steps,
    exercise: exercise,
    restingBpm: resting,
  );

  test('phone-only brisk walk earns points from step cadence', () {
    // 20 one-minute records at 110 steps/min (no watch, no workout logged).
    final steps = [
      for (var i = 0; i < 20; i++)
        StepSample(start: at(8, i), end: at(8, i + 1), count: 110),
    ];
    final result = run(steps: steps);
    expect(result.total, 20);
    expect(result.moderateMinutes, 20);
    expect(result.pointsByHour, {8: 20});
  });

  test('running cadence is vigorous', () {
    final steps = [
      StepSample(start: at(7, 0), end: at(7, 10), count: 1600), // 160 spm
    ];
    expect(run(steps: steps).total, 20);
  });

  test('a long low-cadence step record does not earn points', () {
    final steps = [
      StepSample(start: at(9, 0), end: at(10, 0), count: 3000), // 50 spm
    ];
    expect(run(steps: steps).total, 0);
  });

  test('duplicate step sources are not summed', () {
    final steps = [
      for (final src in ['phone', 'watch'])
        StepSample(start: at(8, 0), end: at(8, 10), count: 600, sourceId: src),
    ];
    // 60 spm per source; summing would wrongly give 120 spm.
    expect(run(steps: steps).total, 0);
  });

  test('workout minutes count once even with matching heart rate', () {
    final result = run(
      exercise: [ActiveInterval(at(18, 0), at(18, 30))],
      hr: [for (var i = 0; i < 30; i++) HeartRateSample(at(18, i, 15), 125)],
    );
    // 125 bpm is moderate for age 30 (>= 119.5), so 1 pt/min, no double count.
    expect(result.total, 30);
  });

  test('vigorous heart rate upgrades workout minutes', () {
    final result = run(
      exercise: [ActiveInterval(at(18, 0), at(18, 10))],
      hr: [for (var i = 0; i < 10; i++) HeartRateSample(at(18, i), 160)],
    );
    expect(result.total, 20);
    expect(result.vigorousMinutes, 10);
  });

  test('many HR samples in one minute only credit that minute', () {
    final result = run(
      hr: [for (var s = 0; s < 60; s += 5) HeartRateSample(at(12, 0, s), 165)],
    );
    expect(result.total, 2);
  });

  test('resting heart rate switches to heart-rate-reserve zones', () {
    // Max 186.8, rest 50 -> moderate >= 104.7, vigorous >= 132.1
    final hr = [HeartRateSample(at(12, 0), 110)];
    expect(run(hr: hr).total, 0); // %HRmax: 110 < 119.5
    expect(run(hr: hr, resting: 50).total, 1);
  });

  test('records outside the day are clipped', () {
    final result = run(
      exercise: [ActiveInterval(DateTime(2026, 11, 2, 23, 50), at(0, 10))],
    );
    expect(result.total, 10);
  });

  test('manual intensity maps to levels', () {
    expect(HeartPointsEngine.manualIntensity(3), IntensityLevel.none);
    expect(HeartPointsEngine.manualIntensity(5), IntensityLevel.moderate);
    expect(HeartPointsEngine.manualIntensity(8), IntensityLevel.vigorous);
  });

  test('vigorous manual workout earns 2 points per minute', () {
    final result = run(
      exercise: [
        ActiveInterval(at(7, 0), at(7, 30), level: IntensityLevel.vigorous),
      ],
    );
    expect(result.total, 60);
  });

  test('manual workout does not double count running cadence', () {
    final cadence = [
      StepSample(start: at(7, 0), end: at(7, 30), count: 4800), // 160 spm
    ];
    final sensorsOnly = run(steps: cadence).total;
    final withManual = run(
      steps: cadence,
      exercise: [
        ActiveInterval(at(7, 0), at(7, 30), level: IntensityLevel.vigorous),
      ],
    ).total;
    expect(sensorsOnly, 60);
    expect(withManual, 60); // same minutes, so nothing extra
  });

  test('no data yields zero', () {
    expect(run().total, 0);
  });
}
