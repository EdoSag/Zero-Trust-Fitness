import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zero_trust_core/zero_trust_core.dart';
import 'package:zerotrust_fitness/app/app_gate.dart';
import 'package:zerotrust_fitness/core/services/reminder_service.dart';
import 'package:zerotrust_fitness/core/utils/units_formatter.dart';

/// Store name "Zero-Trust Fitness"; on the phone it is "ZT Fitness".
const fitnessAppConfig =
    ZtAppConfig(appId: 'fitness', displayName: 'Zero-Trust Fitness');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: '.env');
  final url = dotenv.env['SUPABASE_URL'] ?? '';
  final key = dotenv.env['SUPABASE_ANON_KEY'] ?? '';
  if (url.isEmpty || key.isEmpty || Uri.tryParse(url)?.scheme != 'https') {
    throw StateError('Set SUPABASE_URL (https) and SUPABASE_ANON_KEY in .env');
  }
  await Supabase.initialize(url: url, publishableKey: key);

  await HomeWidget.setAppGroupId('group.zerotrustfitness');
  await ReminderService().initialize();
  await UnitsFormatter().load();

  runApp(
    ProviderScope(
      overrides: [ztAppConfigProvider.overrideWithValue(fitnessAppConfig)],
      child: const ZeroTrustFitnessApp(),
    ),
  );
}

class ZeroTrustFitnessApp extends StatelessWidget {
  const ZeroTrustFitnessApp({super.key, this.home = const AppGate()});

  final Widget home;

  @override
  Widget build(BuildContext context) {
    return ZtThemeBuilder(
      builder: (context, theme, darkTheme, mode) => MaterialApp(
        title: 'ZT Fitness', // task switcher label; store name stays Zero-Trust Fitness
        debugShowCheckedModeBanner: false,
        theme: theme,
        darkTheme: darkTheme,
        themeMode: mode,
        home: home,
        builder: (context, child) =>
            AutoLockActivity(child: child ?? const SizedBox.shrink()),
      ),
    );
  }
}
