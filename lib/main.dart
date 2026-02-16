import 'package:flutter/material.dart';
import 'package:nowa_runtime/nowa_runtime.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zerotrust_fitness/core/services/supabase_service.dart';
import 'package:zerotrust_fitness/globals/app_state.dart';
import 'package:zerotrust_fitness/globals/router.dart';

@NowaGenerated()
main() async {
  WidgetsFlutterBinding.ensureInitialized();
  sharedPrefs = await SharedPreferences.getInstance();
  await SupabaseService().initialize();

  final appState = AppState();
  if (sharedPrefs.getBool('bg_tasks_initialized') ?? false) {
    await appState.initializeBackgroundTasks();
  }

  runApp(MyApp(appState: appState));
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
        theme: AppState.of(context).theme,
        routerConfig: appRouter,
      ),
    );
  }
}

@NowaGenerated()
late final SharedPreferences sharedPrefs;
