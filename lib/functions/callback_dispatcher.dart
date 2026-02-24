import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:nowa_runtime/nowa_runtime.dart';
import 'package:workmanager/workmanager.dart'; // Added this import
import 'package:cryptography/cryptography.dart';
import 'package:zerotrust_fitness/core/security/key_derivation_service.dart';
import 'package:zerotrust_fitness/core/security/security_repository.dart';
import 'package:zerotrust_fitness/features/health/domain/integration_service.dart';
import 'package:zerotrust_fitness/widget_service.dart';

@NowaGenerated()
const String syncTask = 'syncTask';

Future<bool> _isVaultLocked() async {
  const storage = FlutterSecureStorage();
  final raw = await storage.read(key: 'vault_locked');
  return raw != 'false';
}

Future<SecretKey?> _resolveBackgroundSecretKey() async {
  const storage = FlutterSecureStorage();
  final passphrase = await storage.read(key: 'vault_passphrase');
  if (passphrase == null || passphrase.isEmpty) {
    return null;
  }

  final salt = await SecurityRepository().getOrCreateSalt();
  return KeyDerivationService().deriveKey(passphrase, salt);
}

/// This annotation is REQUIRED for background tasks in newer Flutter versions.
/// It prevents the function from being stripped out during tree-shaking in release mode.
@pragma('vm:entry-point') 
@NowaGenerated()
void callbackDispatcher() {
  Workmanager().executeTask((task, _) async {
    if (task == syncTask) {
      try {
        if (await _isVaultLocked()) {
          await WidgetService.redactWidget();
          return true;
        }

        final secretKey = await _resolveBackgroundSecretKey();
        if (secretKey == null) {
          await WidgetService.redactWidget();
          return true;
        }

        await IntegrationService().syncHealthToVault(secretKey);
      } catch (e) {
        debugPrint('Background sync failed: $e');
        return false; // Task failed, OS may retry later
      }
    }
    return true;
  });
}
