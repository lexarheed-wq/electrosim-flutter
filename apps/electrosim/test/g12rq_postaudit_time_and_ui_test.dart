import 'package:electrosim/main.dart';
import 'package:electrosim_ui_kit/electrosim_ui_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/regression_fixture.dart';

void main() {
  testWidgets('AUDIT UI: Mesures tab remains clickable beneath pinned command bar',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      theme: ElectroSimTheme.light(),
      home: F9WorkspaceDemoPage(
        initialCircuit: buildRegressionFixtureCircuit(),
        initialSelectedElementId: 'lamp-1',
      ),
    ));
    for (final (Key activator, Key pin) in <(Key, Key)>[
      (electroSimContextEdgeKey, electroSimContextPinKey),
      (electroSimTopEdgeKey, electroSimTopPinKey),
    ]) {
      tester.widget<GestureDetector>(find.byKey(activator)).onTap!();
      await tester.pumpAndSettle();
      tester.widget<IconButton>(find.byKey(pin)).onPressed!();
      await tester.pumpAndSettle();
    }
    final Rect tab = tester.getRect(find.text('Mesures'));
    final Rect top = tester.getRect(find.byKey(electroSimTopRegionKey));
    expect(tab.top, greaterThanOrEqualTo(top.bottom));
    expect(find.text('Mesures').hitTestable(), findsOneWidget);
  });

  testWidgets('G12-RQ: fast simulation time controls are accessible',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      theme: ElectroSimTheme.light(),
      home: F9WorkspaceDemoPage(initialCircuit: buildRegressionFixtureCircuit()),
    ));
    tester.widget<GestureDetector>(
      find.byKey(electroSimTopEdgeKey),
    ).onTap!();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('workspace-time-advance')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('workspace-time-plus-minute')), findsOneWidget);
    expect(find.byKey(const Key('workspace-time-plus-hour')), findsOneWidget);
    expect(find.byKey(const Key('workspace-time-plus-day')), findsOneWidget);
    await tester.tap(find.byKey(const Key('workspace-time-plus-minute')));
    await tester.pumpAndSettle();
    expect(find.textContaining('t=60.0 s'), findsWidgets);
  });

  testWidgets('AUDIT UI: compact side drawers never cover one another',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      theme: ElectroSimTheme.light(),
      home: F9WorkspaceDemoPage(initialCircuit: buildRegressionFixtureCircuit()),
    ));
    tester.widget<GestureDetector>(
      find.byKey(electroSimPaletteEdgeKey),
    ).onTap!();
    await tester.pumpAndSettle();
    expect(find.byKey(electroSimPaletteRegionKey).hitTestable(), findsOneWidget);
    tester.widget<GestureDetector>(
      find.byKey(electroSimContextEdgeKey),
    ).onTap!();
    await tester.pumpAndSettle();
    expect(find.byKey(electroSimContextRegionKey).hitTestable(), findsOneWidget);
    expect(find.byKey(electroSimPaletteRegionKey).hitTestable(), findsNothing);
  });
}
