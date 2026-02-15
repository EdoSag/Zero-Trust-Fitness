import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:nowa_runtime/nowa_runtime.dart';
import 'package:zerotrust_fitness/pages/home_page.dart';

@NowaGenerated()
final GoRouter appRouter = GoRouter(
  initialLocation: '/home-page',
  routes: [
    GoRoute(
      path: '/home-page',
      builder: (context, state) => const HomePage(),
    ),
  ],
);
