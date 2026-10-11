import 'package:electrosim/pneumatics/pneumatic_workshop_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('R6/M user editor has bounded physical undo/redo', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 950);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(home: PneumaticWorkshopPage()));
    await tester.tap(find.byKey(const Key('add-idealSource')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('device-air1')), findsOneWidget);
    await tester.tap(find.byKey(const Key('air-undo')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('device-air1')), findsNothing);
    await tester.tap(find.byKey(const Key('air-redo')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('device-air1')), findsOneWidget);
  });
}
