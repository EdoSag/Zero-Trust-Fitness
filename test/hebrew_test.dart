import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zero_trust_core/zero_trust_core.dart';
import 'package:zerotrust_fitness/core/storage/fitness_vault.dart';
import 'package:zerotrust_fitness/features/achievements/domain/achievement_definition.dart';
import 'package:zerotrust_fitness/l10n/l10n.dart';
import 'package:zerotrust_fitness/pages/journal_page.dart';

/// Where the letters of [text] are actually drawn (a Text widget's own
/// rect can span the whole row).
Rect glyphs(WidgetTester tester, String text) {
  final paragraph =
      tester.renderObject<RenderParagraph>(find.text(text).first);
  final boxes = paragraph.getBoxesForSelection(
      TextSelection(baseOffset: 0, extentOffset: text.length));
  final origin = paragraph.localToGlobal(Offset.zero);
  return boxes
      .map((b) => b.toRect().shift(origin))
      .reduce((a, b) => a.expandToInclude(b));
}

void main() {
  tearDown(() => ZtL10n.current = lookupZtLocalizations(const Locale('en')));

  test('every English string has a Hebrew translation with the same '
      'placeholders', () {
    Map<String, dynamic> read(String lang) =>
        jsonDecode(File('lib/l10n/app_$lang.arb').readAsStringSync())
            as Map<String, dynamic>;
    final en = read('en');
    final he = read('he');
    // A placeholder's brace follows a non-word character; a select or
    // plural case's brace follows its name (`strong{...}`, `=1{...}`).
    final placeholder = RegExp(r'(?<!\w)\{(\w+)[,}]');
    Set<String?> names(String text) =>
        placeholder.allMatches(text).map((m) => m[1]).toSet();
    for (final key in en.keys.where((k) => !k.startsWith('@'))) {
      expect(he[key], isA<String>(), reason: 'app_he.arb is missing "$key"');
      expect(names(he[key] as String), names(en[key] as String),
          reason: 'placeholders differ in "$key"');
    }
  });

  test('Hebrew plurals read naturally', () {
    final he = lookupAppL10n(const Locale('he'));
    expect(he.nWorkouts(1), 'אימון אחד');
    expect(he.nWorkouts(2), 'שני אימונים');
    expect(he.nWorkouts(5), '5 אימונים');
    expect(he.spokenHours(2), 'שעתיים');
    expect(lookupAppL10n(const Locale('en')).nWorkouts(1), '1 workout');
  });

  test('stored English names show in the app language', () {
    ZtL10n.current = lookupZtLocalizations(const Locale('he'));
    expect(activityLabel('Running'), 'ריצה');
    expect(activityLabel('Something custom'), 'Something custom');
    final medal = kAllAchievements.firstWhere((a) => a.id == 'step_champion');
    expect(medal.title, 'אלוף הצעדים');
    // The stored English name never changes.
    expect(medal.name, 'Step Champion');
    for (final a in kAllAchievements) {
      expect(a.title, isNot(a.name), reason: '${a.id} has no Hebrew name');
    }

    ZtL10n.current = lookupZtLocalizations(const Locale('en'));
    expect(activityLabel('Running'), 'Running');
    expect(medal.title, 'Step Champion');
  });

  testWidgets('Hebrew journal: right-to-left, names translated',
      (tester) async {
    final today = DateTime.now();
    await tester.pumpWidget(MaterialApp(
      locale: ZtLanguages.hebrew,
      localizationsDelegates: const [AppL10n.delegate, ...ZtLanguages.delegates],
      supportedLocales: ZtLanguages.supported,
      home: JournalPage(
        workouts: [
          {
            '_id': 'w',
            'type': 'Running',
            'duration': 31,
            'intensity': 7,
            'timestamp': today.toIso8601String(),
          },
        ],
        measurements: [
          ManualEntry(
              dateKey: FitnessVault.dateKeyOf(today),
              metricKey: 'water_l',
              value: 1.25,
              updatedAt: today),
        ],
        isLoading: false,
        canEdit: true,
        onLog: () {},
        onRefresh: () async {},
        onEditWorkout: (_, __) async {},
        onDeleteWorkout: (_) async {},
        onEditMeasurement: (_, __) async {},
        onDeleteMeasurement: (_) async {},
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('היום'), findsOneWidget); // "Today"
    expect(find.text('ריצה'), findsOneWidget); // "Running"
    expect(find.text('Running'), findsNothing);
    expect(find.text('ידני'), findsNWidgets(2)); // "MANUAL" badges

    final context = tester.element(find.byType(JournalPage));
    expect(Directionality.of(context), TextDirection.rtl);

    // The activity icon sits on the right, the name to its left, and the
    // badge further left still.
    final tile = find.ancestor(
        of: find.text('ריצה'), matching: find.byType(ListTile));
    final icon = tester.getRect(
        find.descendant(of: tile, matching: find.byType(CircleAvatar)));
    final name = glyphs(tester, 'ריצה');
    final badgeText = find.descendant(of: tile, matching: find.text('ידני'));
    final badge = tester.getRect(badgeText);
    expect(name.right, lessThanOrEqualTo(icon.left));
    expect(badge.right, lessThan(name.left));
    // The day header starts on the right edge, like Hebrew text should.
    final header = glyphs(tester, 'היום');
    expect(header.right, greaterThan(tester.view.physicalSize.width /
        tester.view.devicePixelRatio / 2));
  });
}
