import 'dart:async';

import 'package:go_router/go_router.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zerotrust_fitness/pages/home_page.dart';
import 'package:zerotrust_fitness/pages/dashboard_page.dart';
import 'package:zerotrust_fitness/pages/onboarding_page.dart';
import 'package:nowa_runtime/nowa_runtime.dart';

class _RouterRefreshStream extends ChangeNotifier {
  _RouterRefreshStream(Stream<dynamic> stream) {
    _subscription = stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

@NowaGenerated()
final GoRouter appRouter = GoRouter(
  initialLocation: '/home-page',
  refreshListenable: _RouterRefreshStream(
    Supabase.instance.client.auth.onAuthStateChange,
  ),
  
  redirect: (context, state) async {
    const storage = FlutterSecureStorage();
    
    // Check if the vault's master key exists
    final hasVault = await storage.containsKey(key: 'encrypted_db_key');
    final isSignedIn = Supabase.instance.client.auth.currentUser != null;
    final isGoingToDashboard = state.matchedLocation == '/dashboard';
    final isGoingToOnboarding = state.matchedLocation == '/onboarding';

    // 1. Protection: If they try to go to Dashboard but haven't initialized a vault
    if (isGoingToDashboard && !hasVault) {
      return '/onboarding';
    }

    // 2. Protection: Dashboard is only available to authenticated users
    if (isGoingToDashboard && !isSignedIn) {
      return '/onboarding';
    }

    // 3. Logic: Keep authenticated users with an initialized vault on dashboard
    if (isGoingToOnboarding && hasVault && isSignedIn) {
      return '/dashboard';
    }

    return null; // Stay on Home or proceed as intended
  },

  routes: [
    GoRoute(
      path: '/home-page',
      builder: (context, state) => const HomePage(),
    ),
    GoRoute(
      path: '/onboarding',
      builder: (context, state) => const FirstTimeOnboardingPage(),
    ),
    GoRoute(
      path: '/dashboard',
      builder: (context, state) => const DashboardPage(),
    ),
  ],
);
