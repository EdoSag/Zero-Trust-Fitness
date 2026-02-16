import 'package:nowa_runtime/nowa_runtime.dart';
import 'package:zerotrust_fitness/security_repository.dart';
import 'dart:convert';
import 'package:zerotrust_fitness/health_service.dart';
import 'package:zerotrust_fitness/encryption_service.dart';
import 'package:zerotrust_fitness/local_vault.dart';
import 'package:zerotrust_fitness/integrations/supabase_service.dart';

@NowaGenerated()
class IntegrationService {
  IntegrationService._();

  factory IntegrationService() {
    return _instance;
  }

  static final IntegrationService _instance = IntegrationService._();

  Future<void> syncHealthToVault() async {
    final masterKeyBase64 = await SecurityRepository().getOrCreateMasterKey();
    final secretKey = SecretKey(base64Url.decode(masterKeyBase64));
    final healthData = await HealthService().fetchLatestData();
    if (healthData.isEmpty) {
      return;
    }
    for (var point in healthData) {
      final jsonString = jsonEncode({
        'type': point.type.toString(),
        'value': point.value.toString(),
        'date': point.dateFrom.toIso8601String(),
      });
      final encryptedBlob = await EncryptionService().encryptString(
        jsonString,
        secretKey,
      );
      await LocalVault().saveWorkout(encryptedBlob);
      await SupabaseService().syncLocalToSupabase(encryptedBlob);
    }
  }
}
