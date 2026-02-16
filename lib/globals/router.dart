import 'package:go_router/go_router.dart';
import 'package:zerotrust_fitness/pages/home_page.dart';
import 'package:nowa_runtime/nowa_runtime.dart';

@NowaGenerated()
final GoRouter appRouter = GoRouter(
  initialLocation: '/home-page',
  routes: [
    GoRoute(
      path: '/DashboardPage',
      builder: (context, state) => const HomePage(),
    ),
  ],
);
