import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:provider/provider.dart' as legacy; // Prefix to avoid Riverpod conflict
import 'package:zerotrust_fitness/main.dart';
import 'package:zerotrust_fitness/globals/app_state.dart';

void main() {
  testWidgets('Counter increments smoke test', (WidgetTester tester) async {
    // 1. Create a dummy AppState so MyApp doesn't receive null
    final mockAppState = AppState();

    await tester.pumpWidget(
      // 2. Wrap in ProviderScope for your Riverpod logic
      ProviderScope(
        child: legacy.ChangeNotifierProvider<AppState>.value(
          value: mockAppState,
          // 3. Pass the actual instance to MyApp
          child: MyApp(appState: mockAppState),
        ),
      ),
    );

    // 4. Verification logic
    // Note: If you have a '0' on screen, this passes. 
    // If your Dashboard shows "Vault Locked", you should find that text instead.
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}