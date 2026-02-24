import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:health/health.dart';
import 'package:nowa_runtime/nowa_runtime.dart';
import 'package:zerotrust_fitness/heart_point_calculator.dart';
import 'package:zerotrust_fitness/core/security/encryption_service.dart';
import 'package:zerotrust_fitness/core/storage/local_vault.dart';
import 'package:zerotrust_fitness/features/health/data/health_service.dart';
import 'package:zerotrust_fitness/widget_service.dart';

@NowaGenerated()
class IntegrationService {
  IntegrationService._();

  factory IntegrationService() => _instance;

  static final IntegrationService _instance = IntegrationService._();

  Future<void> syncHealthToVault(SecretKey secretKey) async {
    final healthService = HealthService();
    final hasPermissions = await healthService.requestPermissions();
    if (!hasPermissions) {
      return;
    }

    final healthData = await healthService.fetchLatestData();
    final deduplicated = Health().removeDuplicates(healthData);

    var totalSteps = 0;
    var totalHeartPoints = 0;
    var hasExerciseMinutes = false;
    var fallbackHeartRatePoints = 0;

    for (final point in deduplicated) {
      final jsonString = jsonEncode({
        'type': point.type.toString(),
        'value': point.value.toString(),
        'date': point.dateFrom.toIso8601String(),
      });

      final encryptedBlob = await EncryptionService().encryptString(
        jsonString,
        secretKey,
      );
      await LocalVault().saveWorkout(encryptedBlob, secretKey);

      final numericValue = _extractNumericValue(point);
      if (point.type == HealthDataType.STEPS) {
        totalSteps += numericValue.toInt();
      } else if (point.type == HealthDataType.EXERCISE_TIME) {
        hasExerciseMinutes = true;
        totalHeartPoints += numericValue.toInt();
      } else if (point.type == HealthDataType.WORKOUT) {
        final minutes = point.dateTo.difference(point.dateFrom).inMinutes;
        if (minutes > 0) {
          hasExerciseMinutes = true;
          totalHeartPoints += minutes;
        }
      } else if (point.type == HealthDataType.HEART_RATE) {
        fallbackHeartRatePoints += _calculateHeartPointsFromHeartRate(
          numericValue,
          1,
        );
      }
    }
    if (!hasExerciseMinutes) {
      totalHeartPoints = fallbackHeartRatePoints;
    }

    await WidgetService.updateWidgetData(
      steps: totalSteps,
      heartPoints: totalHeartPoints,
      isLocked: false,
    );
  }

  double _extractNumericValue(HealthDataPoint point) {
  final value = point.value;

  // 1. You MUST check the type first
  if (value is NumericHealthValue) {
    // 2. You then access 'numericValue' (which is the actual num/double)
    // 3. DO NOT call .toDouble() on 'value'. Call it on 'value.numericValue'.
    return value.numericValue.toDouble();
  }

  // 4. If it's not a NumericHealthValue, we can't treat it like a number directly.
  // We have to convert it to a string and try to parse it.
  return double.tryParse(value.toString()) ?? 0.0;
}

  int _calculateHeartPointsFromHeartRate(double bpm, int minutes) {
    const assumedAge = 30;
    final maxHeartRate = HeartPointCalculator.calculateMaxHeartRate(assumedAge);
    return HeartPointCalculator.calculatePoints(bpm, maxHeartRate, minutes);
  }
}
