import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; // Added this
import 'package:nowa_runtime/nowa_runtime.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zerotrust_fitness/core/services/supabase_service.dart';
import 'package:zerotrust_fitness/globals/app_state.dart';
import 'package:zerotrust_fitness/globals/router.dart';
import 'package:zerotrust_fitness/core/storage/local_vault.dart';
import 'package:home_widget/home_widget.dart';

@NowaGenerated()
main() async {
  WidgetsFlutterBinding.ensureInitialized();
  LocalVault().setupSqlCipher(); // Ensure SQLCipher is set up before any database operations
  sharedPrefs = await SharedPreferences.getInstance();
  
  // Note: Ensure your .env file is in pubspec.yaml assets!
  await SupabaseService().initialize();
  await HomeWidget.setAppGroupId('group.zerotrustfitness');

  final appState = AppState();
  if (sharedPrefs.getBool('bg_tasks_initialized') ?? false) {
    await appState.initializeBackgroundTasks();
  }

  // Wrap the entire app in ProviderScope for Riverpod 3.0 support
  runApp(
    ProviderScope(
      child: MyApp(appState: appState),
    ),
  );
}

@NowaGenerated({'visibleInNowa': false})
class MyApp extends StatelessWidget {
  @NowaGenerated({'loader': 'auto-constructor'})
  const MyApp({super.key, required this.appState});

  final AppState appState;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AppState>.value(value: appState),
      ],
      builder: (context, child) => MaterialApp.router(
        debugShowCheckedModeBanner: false, // Cleaner look
        theme: AppState.of(context).theme,
        routerConfig: appRouter,
      ),
    );
  }
}

@NowaGenerated()
late final SharedPreferences sharedPrefs;