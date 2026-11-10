import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zerotrust_fitness/app/vault_providers.dart';
import 'package:zerotrust_fitness/core/storage/fitness_vault.dart';
import 'package:zerotrust_fitness/features/goals/goals_provider.dart';
import 'package:zerotrust_fitness/pages/water_food_page.dart';

import 'phone_layout.dart';
import 'support.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<FitnessVault> pump(WidgetTester tester, {int tab = 0}) async {
    await usePhoneScreen(tester);
    final vault = testVault();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          openFitnessVaultProvider.overrideWithValue(vault),
          goalsProvider.overrideWith(() => _NoGoals()),
        ],
        child: MaterialApp(
          theme: appTheme,
          home: WaterFoodPage(initialTab: tab),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return vault;
  }

  testWidgets('a tap adds a glass of water to today', (tester) async {
    final vault = await pump(tester);
    expect(find.text('0.00 L'), findsWidgets);
    await tester.tap(find.text('+250 ml'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('+500 ml'));
    await tester.pumpAndSettle();
    expect(find.text('0.75 L'), findsWidgets);
    final today = FitnessVault.dateKeyOf(DateTime.now());
    expect((await vault.waterFor(today)).logged, 0.75);
  });

  testWidgets('logging food shows it under its meal with the totals', (
    tester,
  ) async {
    final vault = await pump(tester, tab: 1);
    await tester.tap(find.text('Log food'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'What did you eat?'),
      'Porridge',
    );
    await tester.enterText(find.widgetWithText(TextField, 'Calories'), '320');
    // Close the keyboard, as in the bug report: Save must still be there.
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    final save = find.widgetWithText(FilledButton, 'Save');
    expectTappableOnScreen(tester, save);
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(find.text('Porridge'), findsWidgets);
    expect(find.text('320'), findsOneWidget);
    expect((await vault.fetchMeals()).single.kcal, 320);
  });

  testWidgets('food with only a name saves too', (tester) async {
    final vault = await pump(tester, tab: 1);
    await tester.tap(find.text('Log food'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'What did you eat?'),
      'Omelet & boiled potatoes',
    );
    await tester.tap(
      find.descendant(
        of: find.byType(SegmentedButton<String>),
        matching: find.text('Dinner'),
      ),
    );
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
    final meal = (await vault.fetchMeals()).single;
    expect(meal.name, 'Omelet & boiled potatoes');
    expect(meal.mealType, 'dinner');
    expect(meal.kcal, isNull);
    expect(find.text('Log food'), findsOneWidget, reason: 'sheet closed');
  });
}

class _NoGoals extends GoalsNotifier {
  @override
  Future<GoalsState> build() async => const GoalsState(goals: {});
}
