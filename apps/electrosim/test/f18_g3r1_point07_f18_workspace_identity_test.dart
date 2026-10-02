import 'dart:io';

import 'package:electrosim/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('F18 product routes mount F18 workspace identity only',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const app.ElectroSimApp());
    await tester.tap(find.byKey(const Key('home-design')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('design-wiring')));
    await tester.pumpAndSettle();

    expect(find.byType(app.F18WorkspacePage), findsOneWidget);
    expect(find.byType(app.F9WorkspaceDemoPage), findsNothing);
    expect(find.textContaining('F9'), findsNothing);
    expect(find.textContaining('F8'), findsNothing);
  });

  test('F18 route builders no longer instantiate the legacy workspace class',
      () {
    final String source = File('lib/main.dart').readAsStringSync();
    expect(
      RegExp(r'builder:[\s\S]{0,240}F9WorkspaceDemoPage\(')
          .hasMatch(source),
      isFalse,
    );
    expect(
      source.contains('F9 final — interface responsive et Canvas F8 validé'),
      isFalse,
    );
    expect(source.contains("debugLabel: 'f9-canvas-drop-target'"), isFalse);
  });
}
