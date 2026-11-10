import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zerotrust_fitness/app/vault_providers.dart';
import 'package:zerotrust_fitness/components/inline_button_style.dart';
import 'package:zerotrust_fitness/features/goals/goals_provider.dart';
import 'package:zerotrust_fitness/pages/goals_page.dart';
import 'package:zerotrust_fitness/pages/templates_page.dart';

import 'phone_layout.dart';
import 'support.dart';

/// Buttons placed next to each other in a row, drawn with the app's real
/// theme. Before the fix each of these rows failed layout and the button
/// vanished on the phone.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('the shared theme alone would break a button row', (
    tester,
  ) async {
    await usePhoneScreen(tester);
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme,
        home: Scaffold(
          body: Row(
            children: [
              const Spacer(),
              FilledButton(onPressed: () {}, child: const Text('Save')),
            ],
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNotNull);
  });

  testWidgets('inlineButtonStyle keeps a button in a row on screen', (
    tester,
  ) async {
    await usePhoneScreen(tester);
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme,
        home: Scaffold(
          body: Row(
            children: [
              const Spacer(),
              OutlinedButton(
                onPressed: () {},
                style: inlineButtonStyle,
                child: const Text('Off'),
              ),
              FilledButton(
                onPressed: () {},
                style: inlineButtonStyle,
                child: const Text('Save'),
              ),
            ],
          ),
        ),
      ),
    );
    expectTappableOnScreen(tester, find.text('Off'));
    expectTappableOnScreen(tester, find.text('Save'));
    // The theme's height stays.
    expect(tester.getSize(find.byType(FilledButton)).height, 48);
  });

  testWidgets('Goals: Save shows and saves', (tester) async {
    await usePhoneScreen(tester);
    final vault = testVault();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [openFitnessVaultProvider.overrideWithValue(vault)],
        child: MaterialApp(theme: appTheme, home: const GoalsPage()),
      ),
    );
    await tester.pumpAndSettle();
    final firstSave = find.widgetWithText(FilledButton, 'Save').first;
    expectTappableOnScreen(tester, firstSave);
    await tester.enterText(find.byType(TextField).first, '9000');
    await tester.tap(firstSave);
    await tester.pumpAndSettle();
    expect(await vault.fetchGoals(), hasLength(1));
  });

  testWidgets('Templates: the editor Create button shows and saves', (
    tester,
  ) async {
    await usePhoneScreen(tester);
    final vault = testVault();
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme,
        home: TemplatesPage(vault: vault),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Template name'),
      'Morning run',
    );
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    final create = find.widgetWithText(FilledButton, 'Create');
    expectTappableOnScreen(tester, create);
    await tester.tap(create);
    await tester.pumpAndSettle();
    expect((await vault.fetchTemplates()).single.name, 'Morning run');
  });
}
