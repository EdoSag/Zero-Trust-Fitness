import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zero_trust_core/zero_trust_core.dart';

/// A real phone screen (Pixel-class, 1080 x 2400 px) with gesture navigation,
/// drawn edge to edge the way Android 15+ does.
Future<void> usePhoneScreen(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.625;
  tester.view.padding = const FakeViewPadding(top: 63, bottom: 63);
  tester.view.viewPadding = const FakeViewPadding(top: 63, bottom: 63);
  addTearDown(tester.view.reset);
}

/// The app's real theme. Tests that use the plain Material theme miss
/// layout bugs that only the shared Zero-Trust button sizes cause.
ThemeData get appTheme => ZtTheme.dark();

/// Fails unless the widget [finder] matches is fully on screen, inside the
/// system bars, and would get a tap at its centre.
void expectTappableOnScreen(WidgetTester tester, Finder finder) {
  expect(finder, findsOneWidget);
  final rect = tester.getRect(finder);
  final view = tester.view;
  final size = view.physicalSize / view.devicePixelRatio;
  final bottomBar = view.viewPadding.bottom / view.devicePixelRatio;
  expect(rect.width, greaterThan(0), reason: 'has no width');
  expect(rect.height, greaterThan(0), reason: 'has no height');
  expect(rect.left, greaterThanOrEqualTo(0));
  expect(rect.right, lessThanOrEqualTo(size.width));
  expect(rect.top, greaterThanOrEqualTo(0));
  expect(
    rect.bottom,
    lessThanOrEqualTo(size.height - bottomBar),
    reason: 'is under the navigation bar or off screen',
  );
  // Throws if something else would take the tap.
  finder.hitTestable().evaluate().single;
  expect(finder.hitTestable(), findsOneWidget);
}
