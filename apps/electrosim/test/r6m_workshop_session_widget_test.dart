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

  testWidgets('R6/M physical drag, undo and redo retain the same placement', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 950);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(home: PneumaticWorkshopPage()));
    await tester.tap(find.byKey(const Key('add-idealSource')));
    await tester.pumpAndSettle();

    final Finder tile = find.byKey(const Key('device-air1'));
    final Offset initial = tester.getTopLeft(tile);
    await tester.drag(tile, const Offset(64, 32));
    await tester.pumpAndSettle();
    final Offset moved = tester.getTopLeft(tile);
    expect(moved.dx - initial.dx, closeTo(64, 3));
    expect(moved.dy - initial.dy, closeTo(32, 3));

    await tester.tap(find.byKey(const Key('air-undo')));
    await tester.pumpAndSettle();
    final Offset undone = tester.getTopLeft(tile);
    expect(undone.dx, closeTo(initial.dx, 3));
    expect(undone.dy, closeTo(initial.dy, 3));

    await tester.tap(find.byKey(const Key('air-redo')));
    await tester.pumpAndSettle();
    final Offset redone = tester.getTopLeft(tile);
    expect(redone.dx, closeTo(moved.dx, 3));
    expect(redone.dy, closeTo(moved.dy, 3));
  });
}
