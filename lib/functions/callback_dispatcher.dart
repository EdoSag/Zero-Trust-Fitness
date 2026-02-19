import 'package:flutter/material.dart';
import 'package:nowa_runtime/nowa_runtime.dart';
import 'package:workmanager/workmanager.dart'; // Added this import
import 'package:flutter_riverpod/flutter_riverpod.dart'; // Added this import
import 'package:zerotrust_fitness/features/app/providers.dart';
import 'package:zerotrust_fitness/features/health/domain/integration_service.dart';
import 'package:zerotrust_fitness/widget_service.dart';

@NowaGenerated()
const String syncTask = 'syncTask';

/// This annotation is REQUIRED for background tasks in newer Flutter versions.
/// It prevents the function from being stripped out during tree-shaking in release mode.
@pragma('vm:entry-point') 
@NowaGenerated()
void callbackDispatcher() {
  Workmanager().executeTask((task, _) async {
    if (task == syncTask) {
      // ProviderContainer is the entry point for Riverpod in non-UI code
      final container = ProviderContainer();
      try {
        // Read your security provider to get the key
        final secretKey = container.read(securityEnclaveProvider);
        
        if (secretKey == null) {
          // If the vault is locked (no key), redact the widget data for security
          await WidgetService.redactWidget();
          return true;
        }
        
        // If key exists, proceed with the encrypted sync
        await IntegrationService().syncHealthToVault(secretKey);
      } catch (e) {
        debugPrint('Background sync failed: $e');
        return false; // Task failed, OS may retry later
      } finally {
        // Always dispose your container to prevent memory leaks in the background
        container.dispose();
      }
    }
    return true;
  });
}