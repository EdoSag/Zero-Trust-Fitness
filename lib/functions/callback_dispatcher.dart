import 'package:nowa_runtime/nowa_runtime.dart';
import 'package:zerotrust_fitness/misc.dart';
import 'package:zerotrust_fitness/integration_service.dart';

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
          return true;
        }
        await IntegrationService().syncHealthToVault();
      } finally {
        container.dispose();
      }
    }
    return true;
  });
}
