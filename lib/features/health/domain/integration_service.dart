import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:health/health.dart';
import 'package:nowa_runtime/nowa_runtime.dart';
import 'package:zerotrust_fitness/core/security/encryption_service.dart';
import 'package:zerotrust_fitness/core/services/supabase_service.dart';
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
      await SupabaseService().syncLocalToSupabase(encryptedBlob);

      final numericValue = _extractNumericValue(point);
      if (point.type == HealthDataType.STEPS) {
        totalSteps += numericValue.toInt();
      } else if (point.type == HealthDataType.EXERCISE_TIME) {
        totalHeartPoints += numericValue.toInt();
      }
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
}
