import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zerotrust_fitness/app/vault_providers.dart';
import 'package:zerotrust_fitness/core/storage/fitness_vault.dart';
import 'package:zerotrust_fitness/features/goals/goals_provider.dart';
import 'package:zerotrust_fitness/pages/water_food_page.dart';

import 'support.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<FitnessVault> pump(WidgetTester tester, {int tab = 0}) async {
    final vault = testVault();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          openFitnessVaultProvider.overrideWithValue(vault),
          goalsProvider.overrideWith(() => _NoGoals()),
        ],
        child: MaterialApp(home: WaterFoodPage(initialTab: tab)),
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
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Porridge'), findsWidgets);
    expect(find.text('320'), findsOneWidget);
    expect((await vault.fetchMeals()).single.kcal, 320);
  });
}

class _NoGoals extends GoalsNotifier {
  @override
  Future<GoalsState> build() async => const GoalsState(goals: {});
}
