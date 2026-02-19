import 'package:go_router/go_router.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:zerotrust_fitness/pages/home_page.dart';
import 'package:zerotrust_fitness/pages/dashboard_page.dart';
import 'package:zerotrust_fitness/pages/onboarding_page.dart';
import 'package:nowa_runtime/nowa_runtime.dart';

@NowaGenerated()
final GoRouter appRouter = GoRouter(
  initialLocation: '/home-page',
  
  redirect: (context, state) async {
    const storage = FlutterSecureStorage();
    
    // Check if the vault's master key exists
    final hasVault = await storage.containsKey(key: 'encrypted_db_key');
    final isGoingToDashboard = state.matchedLocation == '/dashboard';
    final isGoingToOnboarding = state.matchedLocation == '/onboarding';

    // 1. Protection: If they try to go to Dashboard but haven't initialized a vault
    if (isGoingToDashboard && !hasVault) {
      return '/onboarding';
    }

    // 2. Logic: If they already have a vault, don't let them go back to onboarding
    if (isGoingToOnboarding && hasVault) {
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