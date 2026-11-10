import 'package:flutter_test/flutter_test.dart';
import 'package:zerotrust_fitness/core/services/export_service.dart';
import 'package:zerotrust_fitness/core/storage/fitness_vault.dart';
import 'package:zerotrust_fitness/pages/water_food_page.dart';

import 'support.dart';

void main() {
  group('water', () {
    test(
      'glasses add on top of Health Connect and survive a refresh',
      () async {
        final v = testVault();
        await v.syncFromHealthConnect(
          dateKey: '2026-11-10',
          hcMetrics: {'water_l': 0.5},
        );
        await v.addWater('2026-11-10', 0.25);
        await v.addWater('2026-11-10', 0.5);
        await v.syncFromHealthConnect(
          dateKey: '2026-11-10',
          hcMetrics: {'water_l': 0.6},
        );
        final w = await v.waterFor('2026-11-10');
        expect(w.total, closeTo(1.35, 1e-9));
        expect(w.logged, closeTo(0.75, 1e-9));
        expect(w.health, closeTo(0.6, 1e-9));
      },
    );

    test('taking water off never goes below what was logged here', () async {
      final v = testVault();
      await v.syncFromHealthConnect(
        dateKey: '2026-11-10',
        hcMetrics: {'water_l': 1.0},
      );
      await v.addWater('2026-11-10', 0.25);
      await v.addWater('2026-11-10', -0.5);
      final w = await v.waterFor('2026-11-10');
      expect(w.logged, 0);
      expect(w.total, 1.0);
    });
  });

  group('meals', () {
    FitnessMeal meal(String id, String name, DateTime at, {num? kcal}) =>
        FitnessMeal(
          id: id,
          name: name,
          mealType: mealTypeFor(at),
          at: at,
          kcal: kcal,
        );

    test('logging, editing and deleting keep the day count in step', () async {
      final v = testVault();
      final at = DateTime(2026, 11, 10, 8, 15);
      final day = FitnessVault.dateKeyOf(at);
      await v.logMeal(meal('a', 'Oats', at, kcal: 350));
      await v.logMeal(meal('b', 'Apple', at.add(const Duration(hours: 3))));
      Future<num?> count(String d) async =>
          ((await v.fetchDailyMetrics()).firstWhere(
                (r) => r['date_key'] == d,
              )['metrics']
              as Map<String, num>)['nutrition_entries'];
      expect(await count(day), 2);

      // Editing a meal in place doesn't count it twice.
      await v.logMeal(meal('a', 'Oats with honey', at, kcal: 420));
      expect(await count(day), 2);
      expect(
        (await v.fetchMeals(dateKey: day)).map((m) => m.name),
        containsAll(['Oats with honey', 'Apple']),
      );

      // Moving it to the day before moves the count.
      final yesterday = at.subtract(const Duration(days: 1));
      await v.logMeal(meal('a', 'Oats with honey', yesterday, kcal: 420));
      expect(await count(day), 1);
      expect(await count(FitnessVault.dateKeyOf(yesterday)), 1);

      await v.removeMeal('b');
      expect(await count(day), 0);
      expect(await v.fetchMeals(dateKey: day), isEmpty);
      expect((await v.countsByKind())['meal'], 1);
    });

    test('totals add up only what was entered', () {
      final totals = MealTotals.of([
        FitnessMeal(
          id: '1',
          name: 'x',
          mealType: 'lunch',
          at: DateTime.utc(2026),
          kcal: 500,
          proteinG: 30,
        ),
        FitnessMeal(
          id: '2',
          name: 'y',
          mealType: 'lunch',
          at: DateTime.utc(2026),
        ),
      ]);
      expect(totals.kcal, 500);
      expect(totals.proteinG, 30);
      expect(totals.fatG, 0);
    });

    test('meal type follows the time of day', () {
      expect(mealTypeFor(DateTime(2026, 1, 1, 7)), 'breakfast');
      expect(mealTypeFor(DateTime(2026, 1, 1, 12, 30)), 'lunch');
      expect(mealTypeFor(DateTime(2026, 1, 1, 19)), 'dinner');
      expect(mealTypeFor(DateTime(2026, 1, 1, 16)), 'snack');
    });

    test('meals come back from an export once, however often restored', () async {
      final v = testVault();
      final at = DateTime.utc(2026, 11, 9, 12);
      await v.logMeal(
        FitnessMeal(
          id: FitnessVault.newId(),
          name: 'Soup',
          mealType: 'lunch',
          at: at,
          kcal: 300,
        ),
      );
      final json =
          '{"version":1,"exported_at":"2026-11-10T00:00:00Z",'
          '"meals":[${'{"name":"Soup","meal":"lunch","at":"${at.toIso8601String()}","kcal":300}'}]}';
      await ExportService().restoreFromJson(json, v);
      await ExportService().restoreFromJson(json, v);
      expect(await v.fetchMeals(), hasLength(1));

      final fresh = testVault();
      await ExportService().restoreFromJson(json, fresh);
      await ExportService().restoreFromJson(json, fresh);
      final meals = await fresh.fetchMeals();
      expect(meals.single.kcal, 300);
    });
  });
}
