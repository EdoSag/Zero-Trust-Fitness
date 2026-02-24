import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; // Riverpod tools
import 'package:nowa_runtime/nowa_runtime.dart';
import 'package:provider/provider.dart' as legacy; // Prefixing to avoid collision
import 'package:workmanager/workmanager.dart';
import 'package:zerotrust_fitness/features/app/providers.dart';
import 'package:zerotrust_fitness/features/health/domain/integration_service.dart';
import 'package:zerotrust_fitness/functions/callback_dispatcher.dart';
import 'package:zerotrust_fitness/globals/themes.dart';
import 'package:zerotrust_fitness/widget_service.dart';

@NowaGenerated()
class AppState extends ChangeNotifier {
  AppState();

  factory AppState.of(BuildContext context, {bool listen = true}) {
    // Use the prefixed legacy provider for Nowa compatibility
    return legacy.Provider.of<AppState>(context, listen: listen);
  }

  ThemeData _theme = lightTheme;

  ThemeData get theme => _theme;

  void changeTheme(ThemeData theme) {
    _theme = theme;
    notifyListeners();
  }

  Future<void> initializeBackgroundTasks() async {
    // Ensure you use the top-level callbackDispatcher imported from its own file
    await Workmanager().initialize(
      callbackDispatcher, // This must be the top-level function in callback_dispatcher.dart
      isInDebugMode: kDebugMode,
    );
    
    await Workmanager().registerPeriodicTask(
      '1',
      syncTask,
      frequency: const Duration(minutes: 15),
      existingWorkPolicy: ExistingWorkPolicy.replace,
      constraints: Constraints(networkType: NetworkType.connected),
    );
  }
}
