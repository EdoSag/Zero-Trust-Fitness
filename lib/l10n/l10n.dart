import 'package:flutter/widgets.dart';
import 'package:zero_trust_core/zero_trust_core.dart';

import 'generated/app_l10n.dart';

export 'generated/app_l10n.dart';

/// ZT Fitness's own strings, in English and Hebrew (`app_en.arb`,
/// `app_he.arb`). The language is the one picked under Settings →
/// Appearance → Language (`ztLanguageProvider` in the core).
extension AppL10nContext on BuildContext {
  AppL10n get l10n => AppL10n.of(this);
}

/// The strings for the app's current language, for code without a
/// [BuildContext] (notifications, the home screen widget, exports).
AppL10n get currentL10n {
  final code = ZtL10n.current.localeName.split('_').first;
  return lookupAppL10n(
    AppL10n.supportedLocales.any((l) => l.languageCode == code)
        ? Locale(code)
        : const Locale('en'),
  );
}

/// Keeps [text] left-to-right inside Hebrew (numbers with units, emails).
String ltr(String text) => text.isEmpty ? text : '\u2066$text\u2069';

/// An activity type in the app's language. Workouts store the English name
/// ('Running', 'Strength Training', ...), so only the display is translated.
String activityLabel(String type) {
  final l = currentL10n;
  return switch (type) {
    'Running' => l.actRunning,
    'Cycling' => l.actCycling,
    'Swimming' => l.actSwimming,
    'Walking' => l.actWalking,
    'Hiking' => l.actHiking,
    'Strength Training' => l.actStrengthTraining,
    'Yoga/Stretching' => l.actYogaStretching,
    'Strength' => l.actStrength,
    'HIIT' => l.actHiit,
    'Yoga' => l.actYoga,
    'Other' => l.actOther,
    _ => type,
  };
}
