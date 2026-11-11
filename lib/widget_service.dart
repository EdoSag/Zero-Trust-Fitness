import 'package:flutter/widgets.dart';
import 'package:home_widget/home_widget.dart';
import 'package:zerotrust_fitness/l10n/l10n.dart';
import 'package:zerotrust_fitness/core/services/reminder_service.dart';
/// Feeds the Android home screen widget (FitnessWidgetProvider).
class WidgetService {
  static Future<void> updateWidgetData({
    required int steps,
    required int heartPoints,
    required bool isLocked,
    int momentum = 0,
    String momentumLabel = '',
    int heartTarget = 0,
    int stepsGoal = 0,
  }) async {
    await HomeWidget.saveWidgetData<int>('steps', isLocked ? 0 : steps);
    await HomeWidget.saveWidgetData<int>(
      'heartPoints',
      isLocked ? 0 : heartPoints,
    );
    await HomeWidget.saveWidgetData<int>('momentum', isLocked ? 0 : momentum);
    await HomeWidget.saveWidgetData<String>(
      'momentumLabel',
      isLocked ? '' : momentumLabel,
    );
    await HomeWidget.saveWidgetData<int>(
      'heartTarget',
      isLocked ? 0 : heartTarget,
    );
    // Goals aren't health data; keep them so the rings keep their scale.
    await HomeWidget.saveWidgetData<int>('stepsGoal', stepsGoal);
    await HomeWidget.saveWidgetData<bool>('isLocked', isLocked);
    await HomeWidget.updateWidget(
      name: 'FitnessWidgetProvider',
      iOSName: 'FitnessWidget',
    );
  }

  static Future<void> redactWidget() async {
    await updateWidgetData(steps: 0, heartPoints: 0, isLocked: true);
  }

  /// The widget's fixed texts in the app's language (read by WidgetText.kt).
  /// %1$s etc. are filled in by the widget.
  static Future<void> saveTexts(AppL10n l) async {
    final texts = {
      'heart_points': l.widgetHeartPts,
      'locked': l.widgetLocked,
      'locked_short': l.widgetLockedShort,
      'today': l.today,
      'hp_goal': l.widgetHpGoal,
      'steps_goal': l.widgetStepsGoal,
      'momentum': l.widgetMomentum,
      'summary': l.widgetSummary,
    };
    for (final e in texts.entries) {
      await HomeWidget.saveWidgetData<String>(
          'fitness_widget_text_${e.key}', e.value);
    }
    await HomeWidget.updateWidget(
      name: 'FitnessWidgetProvider',
      iOSName: 'FitnessWidget',
    );
  }
}

/// Hands the home screen widget the app's language: whenever the language
/// in Settings changes (and once at start), its fixed texts are saved again.
class WidgetTextSync extends StatefulWidget {
  const WidgetTextSync({super.key, required this.child});

  final Widget child;

  @override
  State<WidgetTextSync> createState() => _WidgetTextSyncState();
}

class _WidgetTextSyncState extends State<WidgetTextSync> {
  String? _synced;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final l10n = context.l10n;
    if (l10n.localeName == _synced) return;
    final changed = _synced != null;
    _synced = l10n.localeName;
    // Best effort: the widget keeps its last texts if this fails.
    WidgetService.saveTexts(l10n).catchError((Object _) {});
    // Scheduled reminders carry their text: schedule them again in the
    // newly picked language (not at start, when nothing changed).
    if (changed) {
      final reminders = ReminderService();
      reminders
          .loadSettings()
          .then(reminders.applySettings)
          .catchError((Object _) {});
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
