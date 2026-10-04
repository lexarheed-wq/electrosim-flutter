import 'package:electrosim_ui_kit/electrosim_ui_kit.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('breakpoints follow the F9 responsive contract', () {
    expect(ElectroSimBreakpoints.classify(390), ElectroSimWindowClass.compact);
    expect(ElectroSimBreakpoints.classify(599.9), ElectroSimWindowClass.compact);
    expect(ElectroSimBreakpoints.classify(600), ElectroSimWindowClass.medium);
    expect(ElectroSimBreakpoints.classify(1000), ElectroSimWindowClass.medium);
    expect(
      ElectroSimBreakpoints.classify(1000.1),
      ElectroSimWindowClass.expanded,
    );
  });

  test('interface and electrical colors remain distinct tokens', () {
    expect(ElectroSimColors.primary, isNot(ElectroSimColors.dcPositive));
    expect(ElectroSimColors.secondary, isNot(ElectroSimColors.dcNegative));
    expect(ElectroSimColors.phaseL1, isNot(ElectroSimColors.phaseL2));
    expect(ElectroSimColors.background, isNot(ElectroSimColors.surface));
    expect(ElectroSimColors.focus, isNot(ElectroSimColors.dcPositive));
  });

  test('F18 qualified interaction geometry remains accessible', () {
    expect(ElectroSimGeometry.minimumTouchTarget, greaterThanOrEqualTo(48));
    expect(ElectroSimGeometry.terminalHitTarget, greaterThanOrEqualTo(48));
    expect(
      ElectroSimGeometry.terminalVisualDiameter,
      lessThan(ElectroSimGeometry.terminalHitTarget),
    );
    expect(ElectroSimComponentTokens.quickPaletteItemCount, 5);
    expect(ElectroSimComponentTokens.paletteExpansionLabel, 'Voir tous');
  });

  testWidgets('expanded shell gives the complete viewport to the canvas',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    final Rect canvas = tester.getRect(find.byKey(electroSimCanvasRegionKey));
    expect(canvas, const Rect.fromLTWH(0, 0, 1440, 900));

    final Rect palette =
        tester.getRect(find.byKey(electroSimPaletteRegionKey));
    final Rect context =
        tester.getRect(find.byKey(electroSimContextRegionKey));
    final Rect top = tester.getRect(find.byKey(electroSimTopRegionKey));
    final Rect status = tester.getRect(find.byKey(electroSimStatusRegionKey));

    expect(palette.right, lessThanOrEqualTo(0));
    expect(context.left, greaterThanOrEqualTo(1440));
    expect(top.bottom, lessThanOrEqualTo(0));
    expect(status.top, greaterThanOrEqualTo(900));
  });

  testWidgets('desktop hover opens and auto-closes the palette overlay',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    final TestGesture mouse =
        await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: const Offset(700, 450));
    await tester.pump();

    await mouse.moveTo(
      tester.getCenter(find.byKey(electroSimPaletteEdgeKey)),
    );
    await tester.pumpAndSettle();

    final Rect open = tester.getRect(find.byKey(electroSimPaletteRegionKey));
    expect(open.left, closeTo(0, .5));
    expect(open.width, ElectroSimGeometry.expandedPaletteWidth);

    await mouse.moveTo(const Offset(700, 450));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    final Rect closed =
        tester.getRect(find.byKey(electroSimPaletteRegionKey));
    expect(closed.right, lessThanOrEqualTo(0));
  });

  testWidgets('touch edge opens a panel and canvas tap closes it',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(electroSimContextEdgeKey));
    await tester.pumpAndSettle();
    final Rect open = tester.getRect(find.byKey(electroSimContextRegionKey));
    expect(open.right, closeTo(390, .5));
    expect(open.left, lessThan(390));

    await tester.tapAt(const Offset(120, 420));
    await tester.pumpAndSettle();
    final Rect closed =
        tester.getRect(find.byKey(electroSimContextRegionKey));
    expect(closed.left, greaterThanOrEqualTo(390));
  });

  testWidgets('pin keeps palette open after pointer leaves',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(electroSimPaletteEdgeKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(electroSimPalettePinKey));
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(800, 450));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    final Rect pinned =
        tester.getRect(find.byKey(electroSimPaletteRegionKey));
    expect(pinned.left, closeTo(0, .5));

    await tester.tap(find.byKey(electroSimPalettePinKey));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(800, 450));
    await tester.pumpAndSettle();

    final Rect closed =
        tester.getRect(find.byKey(electroSimPaletteRegionKey));
    expect(closed.right, lessThanOrEqualTo(0));
  });

  testWidgets('horizontal top and status surfaces also auto-hide',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(820, 1180);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(electroSimTopEdgeKey));
    await tester.pumpAndSettle();
    expect(
      tester.getRect(find.byKey(electroSimTopRegionKey)).top,
      closeTo(0, .5),
    );

    await tester.tapAt(const Offset(410, 590));
    await tester.pumpAndSettle();
    expect(
      tester.getRect(find.byKey(electroSimTopRegionKey)).bottom,
      lessThanOrEqualTo(0),
    );

    await tester.tap(find.byKey(electroSimStatusEdgeKey));
    await tester.pumpAndSettle();
    expect(
      tester.getRect(find.byKey(electroSimStatusRegionKey)).bottom,
      closeTo(1180, .5),
    );
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
        statusBar: SizedBox(height: 40, child: Text('Status')),
      ),
    ),
  );
}
