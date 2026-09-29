import 'package:electrosim_ui_kit/electrosim_ui_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('breakpoints follow the F9 responsive contract', () {
    expect(ElectroSimBreakpoints.classify(390), ElectroSimWindowClass.compact);
    expect(ElectroSimBreakpoints.classify(599.9), ElectroSimWindowClass.compact);
    expect(ElectroSimBreakpoints.classify(600), ElectroSimWindowClass.medium);
    expect(ElectroSimBreakpoints.classify(1000), ElectroSimWindowClass.medium);
    expect(ElectroSimBreakpoints.classify(1000.1), ElectroSimWindowClass.expanded);
  });

  test('interface and electrical colors remain distinct tokens', () {
    expect(ElectroSimColors.primary, isNot(ElectroSimColors.dcPositive));
    expect(ElectroSimColors.secondary, isNot(ElectroSimColors.dcNegative));
    expect(ElectroSimColors.phaseL1, isNot(ElectroSimColors.phaseL2));
  });

  testWidgets('expanded shell exposes palette canvas and context simultaneously', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_harness());
    expect(find.byKey(electroSimCanvasRegionKey), findsOneWidget);
    expect(find.byKey(electroSimPaletteRegionKey), findsOneWidget);
    expect(find.byKey(electroSimContextRegionKey), findsOneWidget);
    expect(find.byKey(electroSimCompactActionsKey), findsNothing);
  });

  testWidgets('medium shell keeps canvas and at most one secondary panel', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(820, 1180);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_harness());
    expect(find.byKey(electroSimCanvasRegionKey), findsOneWidget);
    expect(find.byKey(electroSimPaletteRegionKey), findsNothing);
    expect(find.byKey(electroSimContextRegionKey), findsNothing);

    await tester.tap(find.text('Palette'));
    await tester.pump();
    expect(find.byKey(electroSimPaletteRegionKey), findsOneWidget);
    expect(find.byKey(electroSimContextRegionKey), findsNothing);

    await tester.tap(find.text('Propriétés'));
    await tester.pump();
    expect(find.byKey(electroSimPaletteRegionKey), findsNothing);
    expect(find.byKey(electroSimContextRegionKey), findsOneWidget);
  });

  testWidgets('compact shell overlays panels instead of shrinking the canvas', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_harness());
    expect(find.byKey(electroSimCanvasRegionKey), findsOneWidget);
    expect(find.byKey(electroSimCompactActionsKey), findsOneWidget);
    expect(find.byKey(electroSimPaletteRegionKey), findsNothing);

    await tester.tap(find.text('Palette'));
    await tester.pump();
    expect(find.byKey(electroSimCanvasRegionKey), findsOneWidget);
    expect(find.byKey(electroSimPaletteRegionKey), findsOneWidget);
  });
}

Widget _harness() {
  return MaterialApp(
    theme: ElectroSimTheme.light(),
    home: const Scaffold(
      body: ElectroSimWorkspaceShell(
        topBar: SizedBox(height: 56, child: Text('Top')),
        canvas: ColoredBox(color: Colors.white, child: Text('Canvas')),
        palette: Text('Palette content'),
        contextPanel: Text('Context content'),
        statusBar: Text('Status'),
      ),
    ),
  );
}
