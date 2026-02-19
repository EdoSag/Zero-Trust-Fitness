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
    final healthData = await HealthService().fetchLatestData();
    var totalSteps = 0;

    for (final point in healthData) {
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

      if (point.type == HealthDataType.STEPS && point.value is NumericHealthValue) {
        totalSteps += (point.value as NumericHealthValue).numericValue.toInt();
      }
    }

    final totalPoints = (totalSteps / 1000).floor();
    await WidgetService.updateWidgetData(
      steps: totalSteps,
      heartPoints: totalPoints,
      isLocked: false,
    );
  }
}
