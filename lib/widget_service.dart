import 'package:home_widget/home_widget.dart';
import 'package:nowa_runtime/nowa_runtime.dart';

@NowaGenerated()
class WidgetService {
  void test() {}

  static Future<void> updateWidgetData({
    required int steps,
    required int heartPoints,
    required bool isLocked,
  }) async {
    await HomeWidget.saveWidgetData<int>('steps', isLocked ? 0 : steps);
    await HomeWidget.saveWidgetData<int>(
      'heartPoints',
      isLocked ? 0 : heartPoints,
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
