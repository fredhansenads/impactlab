import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/mobile_scenario.dart';

void main() {
  testWidgets('Mobile demo navigation, roles and text submission', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await mobileScenario(tester);
  });
}
