import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zerotrust_fitness/core/storage/fitness_vault.dart';
import 'package:zerotrust_fitness/pages/gps_workout_page.dart';
import 'package:zerotrust_fitness/pages/journal_page.dart';
import 'package:zerotrust_fitness/l10n/l10n.dart';
import 'package:zero_trust_core/zero_trust_core.dart';

void main() {
  final today = DateTime.now();
  final key = FitnessVault.dateKeyOf(today);

  Widget journal({
    required List<String> deleted,
    bool canEdit = true,
  }) =>
      MaterialApp(
        localizationsDelegates: const [AppL10n.delegate, ...ZtLanguages.delegates],
        supportedLocales: ZtLanguages.supported,
        home: JournalPage(
          workouts: [
            {
              '_id': 'gps',
              'type': 'Running',
              'duration': 31,
              'intensity': 7,
              'distance_m': 5012.0,
              'timestamp': today.toIso8601String(),
              'route': [
                {'lat': 1.0, 'lng': 2.0},
              ],
              'splits': [
                {'index': 1, 'seconds': 301, 'pace_min_per_km': 5.0},
              ],
            },
            {
              '_id': 'fit',
              'type': 'Cycling',
              'duration': 60,
              'source': 'google_fit',
              'timestamp': DateTime(2023, 5, 1, 7).toIso8601String(),
            },
          ],
          measurements: [
            ManualEntry(
                dateKey: key,
                metricKey: 'water_l',
                value: 1.25,
                updatedAt: today),
          ],
          isLoading: false,
          canEdit: canEdit,
          onLog: () {},
          onRefresh: () async {},
          onEditWorkout: (_, __) async {},
          onDeleteWorkout: (id) async => deleted.add(id),
          onEditMeasurement: (_, __) async {},
          onDeleteMeasurement: (e) async => deleted.add(e.metricKey),
        ),
      );

  testWidgets('shows workouts and measurements by day, with filters',
      (tester) async {
    await tester.pumpWidget(journal(deleted: []));
    await tester.pump();
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Running'), findsOneWidget);
    expect(find.text('GPS'), findsOneWidget);
    expect(find.text('Hydration'), findsOneWidget);
    expect(find.text('GOOGLE FIT'), findsOneWidget);

    await tester.tap(find.text('Measurements'));
    await tester.pump();
    expect(find.text('Running'), findsNothing);
    expect(find.text('Hydration'), findsOneWidget);

    await tester.tap(find.text('Workouts'));
    await tester.pump();
    expect(find.text('Hydration'), findsNothing);
    expect(find.text('Cycling'), findsOneWidget);
  });

  testWidgets('a workout opens with its splits, and can be deleted',
      (tester) async {
    final deleted = <String>[];
    await tester.pumpWidget(journal(deleted: deleted));
    await tester.pump();
    await tester.tap(find.text('Running'));
    await tester.pumpAndSettle();
    expect(find.text('Splits'), findsOneWidget);
    expect(find.text('05:01'), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(deleted, ['gps']);
  });

  testWidgets('locked: no edit menus', (tester) async {
    await tester.pumpWidget(journal(deleted: [], canEdit: false));
    await tester.pump();
    expect(find.byTooltip('More'), findsNothing);
  });

  testWidgets('GPS screen starts on the setup step', (tester) async {
    SharedPreferences.setMockInitialValues({'gps_last_activity': 'Cycling'});
    await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(
          localizationsDelegates: const [AppL10n.delegate, ...ZtLanguages.delegates],
          supportedLocales: ZtLanguages.supported,
          home: GpsWorkoutPage())));
    await tester.pumpAndSettle();
    expect(find.text('Start'), findsOneWidget);
    expect(find.text('Auto-pause'), findsOneWidget);
    expect(find.text('Voice cues'), findsOneWidget);
    final cycling = tester.widget<ChoiceChip>(
        find.widgetWithText(ChoiceChip, 'Cycling'));
    expect(cycling.selected, isTrue);
  });
}
