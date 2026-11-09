import 'package:home_widget/home_widget.dart';
class WidgetService {
  void test() {}

  static Future<void> updateWidgetData({
    required int steps,
    required int heartPoints,
    required bool isLocked,
    int momentum = 0,
    String momentumLabel = '',
    int heartTarget = 0,
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
    await HomeWidget.saveWidgetData<bool>('isLocked', isLocked);
    await HomeWidget.updateWidget(
      name: 'FitnessWidgetProvider',
      iOSName: 'FitnessWidget',
    );
  }

  static Future<void> redactWidget() async {
    await updateWidgetData(steps: 0, heartPoints: 0, isLocked: true);
  }
}
