import 'package:go_router/go_router.dart';
import 'package:zerotrust_fitness/pages/home_page.dart';
import 'package:zerotrust_fitness/pages/dashboard_page.dart';
import 'package:nowa_runtime/nowa_runtime.dart';

@NowaGenerated()
final GoRouter appRouter = GoRouter(
  initialLocation: '/home-page',
  routes: [
    GoRoute(path: '/home-page', builder: (context, state) => const HomePage()),
    GoRoute(
      path: '/dashboard',
      builder: (context, state) => const DashboardPage(),
    ),
  ],
);
