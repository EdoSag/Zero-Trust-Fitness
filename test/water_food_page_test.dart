import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zerotrust_fitness/app/vault_providers.dart';
import 'package:zerotrust_fitness/core/storage/fitness_vault.dart';
import 'package:zerotrust_fitness/features/goals/goals_provider.dart';
import 'package:zerotrust_fitness/features/health/data/health_writeback.dart';
import 'package:zerotrust_fitness/pages/water_food_page.dart';

import 'phone_layout.dart';
import 'support.dart';
import 'package:zerotrust_fitness/l10n/l10n.dart';
import 'package:zerotrust_fitness/main.dart' show fitnessAppConfig;
import 'package:zero_trust_core/zero_trust_core.dart';

class _HealthSink implements HealthWorkoutSink {
  bool waterAccess = false;
  final waterWrites = <double>[];

  @override
  Future<bool> available() async => true;
  @override
  Future<bool> requestWriteAccess() async => waterAccess = true;
  @override
  Future<bool> hasWorkoutAccess() async => waterAccess;
  @override
  Future<bool> hasWaterAccess() async => waterAccess;
  @override
  Future<bool> write({
    required String type,
    required DateTime start,
    required DateTime end,
    double? distanceMeters,
  }) async => true;
  @override
  Future<bool> delete({required DateTime start, required DateTime end}) async =>
      true;
  @override
  Future<bool> writeWater({
    required double liters,
    required DateTime start,
    required DateTime end,
  }) async {
    waterWrites.add(liters);
    return true;
  }

  @override
  Future<bool> deleteWater({
    required DateTime start,
    required DateTime end,
  }) async => true;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  tearDown(() => HealthWriteback.instance = HealthWriteback());

  Future<FitnessVault> pump(WidgetTester tester, {int tab = 0}) async {
    await usePhoneScreen(tester);
    final vault = testVault();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          openFitnessVaultProvider.overrideWithValue(vault),
          // For the vault controller, which keeps the app unlocked while
          // Health Connect's permission screen is open.
          ztAppConfigProvider.overrideWithValue(fitnessAppConfig),
          ztPreferencesStoreProvider.overrideWithValue(
            InMemoryPreferencesStore(),
          ),
          goalsProvider.overrideWith(() => _NoGoals()),
        ],
        child: MaterialApp(
          localizationsDelegates: const [AppL10n.delegate, ...ZtLanguages.delegates],
          supportedLocales: ZtLanguages.supported,
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

  testWidgets('turning on the Health Connect offer sends water to other apps', (
    tester,
  ) async {
    final sink = _HealthSink();
    HealthWriteback.instance = HealthWriteback(sink: sink);
    await pump(tester);
    final offer = find.byKey(const Key('health-water-offer'));
    expect(offer, findsOneWidget);
    expect(
      find.textContaining('ZT Quests and other apps can count them'),
      findsOneWidget,
    );

    await tester.tap(find.text('+250 ml'));
    await tester.pumpAndSettle();
    expect(sink.waterWrites, isEmpty, reason: 'off until asked for');

    final turnOn = find.descendant(of: offer, matching: find.text('Turn On'));
    await tester.ensureVisible(turnOn);
    await tester.pumpAndSettle();
    expectTappableOnScreen(tester, turnOn);
    // Both buttons sit side by side inside the card, sized to their labels.
    final card = tester.getRect(offer);
    final on = tester.getRect(
      find.ancestor(of: turnOn, matching: find.byType(TextButton)),
    );
    final no = tester.getRect(
      find.ancestor(
        of: find.descendant(of: offer, matching: find.text('Not now')),
        matching: find.byType(TextButton),
      ),
    );
    expect(on.center.dy, no.center.dy);
    expect(no.right, lessThanOrEqualTo(on.left));
    expect(on.width, lessThan(card.width / 2));
    expect(card.contains(on.topLeft) && card.contains(on.bottomRight), isTrue);
    expect(card.contains(no.topLeft), isTrue);
    await tester.tap(turnOn);
    await tester.pumpAndSettle();
    expect(offer, findsNothing);
    expect(sink.waterWrites, [0.25], reason: "today's water goes over");

    await tester.tap(find.text('+500 ml'));
    await tester.pumpAndSettle();
    expect(sink.waterWrites, [0.25, 0.5]);
  });

  testWidgets('the Health Connect offer stays away once turned down', (
    tester,
  ) async {
    HealthWriteback.instance = HealthWriteback(sink: _HealthSink());
    await pump(tester);
    final offer = find.byKey(const Key('health-water-offer'));
    final notNow = find.descendant(of: offer, matching: find.text('Not now'));
    await tester.ensureVisible(notNow);
    await tester.pumpAndSettle();
    await tester.tap(notNow);
    await tester.pumpAndSettle();
    expect(offer, findsNothing);

    await tester.pumpWidget(const SizedBox());
    await pump(tester);
    expect(offer, findsNothing);
  });

  testWidgets('no offer where there is no Health Connect', (tester) async {
    await pump(tester);
    expect(find.byKey(const Key('health-water-offer')), findsNothing);
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
