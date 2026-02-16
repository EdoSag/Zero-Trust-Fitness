import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:nowa_runtime/nowa_runtime.dart';
import 'package:provider/provider.dart';
import 'package:zerotrust_fitness/features/app/providers.dart';
import 'package:zerotrust_fitness/features/health/domain/integration_service.dart';
import 'package:zerotrust_fitness/functions/callback_dispatcher.dart';
import 'package:zerotrust_fitness/globals/themes.dart';
import 'package:zerotrust_fitness/widget_service.dart';

@NowaGenerated()
class AppState extends ChangeNotifier {
  AppState();

  factory AppState.of(BuildContext context, {bool listen = true}) {
    return Provider.of<AppState>(context, listen: listen);
  }

  ThemeData _theme = lightTheme;

  ThemeData get theme => _theme;

  void changeTheme(ThemeData theme) {
    _theme = theme;
    notifyListeners();
  }

  Future<void> initializeBackgroundTasks() async {
    await Workmanager().initialize(callbackDispatcher, isInDebugMode: kDebugMode);
    await Workmanager().registerPeriodicTask(
      '1',
      syncTask,
      frequency: const Duration(hours: 6),
      constraints: Constraints(networkType: NetworkType.connected),
    );
  }

  void callbackDispatcher() {
    Workmanager().executeTask((task, _) async {
      if (task == syncTask) {
        final container = ProviderContainer();
        try {
          final secretKey = container.read(securityEnclaveProvider);
          if (secretKey == null) {
            await WidgetService.redactWidget();
            return true;
          }
          await IntegrationService().syncHealthToVault(secretKey);
        } finally {
          container.dispose();
        }
      }
      return true;
    });
  }
}
