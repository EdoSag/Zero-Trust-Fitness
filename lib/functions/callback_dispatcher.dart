import 'package:nowa_runtime/nowa_runtime.dart';
import 'package:zerotrust_fitness/misc.dart';
import 'package:zerotrust_fitness/widget_service.dart';
import 'package:zerotrust_fitness/integration_service.dart';
import 'package:flutter/material.dart';

@NowaGenerated()
const String syncTask = 'syncTask';

@NowaGenerated()
void callbackDispatcher() {
  Workmanager().executeTask((task, _) async {
    if (task == 'syncTask') {
      final container = ProviderContainer();
      try {
        final secretKey = container.read(securityEnclaveProvider);
        if (secretKey == null) {
          await WidgetService.redactWidget();
          return true;
        }
        await IntegrationService().syncHealthToVault();
      } catch (e) {
        debugPrint('Background sync failed: ${e}');
      } finally {
        container.dispose();
      }
    }
    return true;
  });
}
