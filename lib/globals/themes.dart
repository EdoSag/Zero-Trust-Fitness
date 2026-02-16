import 'package:flutter/material.dart';
import 'package:nowa_runtime/nowa_runtime.dart';

@NowaGenerated()
final ThemeData lightTheme = ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(
    seedColor: const Color(0xFF6366F1),
    primary: const Color(0xFF6366F1),
    secondary: const Color(0xFFF43F5E),
    brightness: Brightness.light,
  ),
  textTheme: const TextTheme(),
);

@NowaGenerated()
final ThemeData darkTheme = ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(
    seedColor: const Color(0xFF6366F1),
    primary: const Color(0xFF6366F1),
    secondary: const Color(0xFFF43F5E),
    brightness: Brightness.dark,
    surface: const Color(0xFF121212),
  ),
  scaffoldBackgroundColor: const Color(0xFF000000),
  cardTheme: CardThemeData(
    color: const Color(0xFF1E1E1E),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    elevation: 0,
  ),
);
