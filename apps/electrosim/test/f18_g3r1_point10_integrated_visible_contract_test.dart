import 'package:electrosim/f18_component_asset_visual.dart';
import 'package:electrosim/main.dart' as app;
import 'package:electrosim_canvas/electrosim_canvas.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<SimulatorCanvas> _openDesignWorkspace(
  WidgetTester tester, {
  Size size = const Size(1440, 900),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(const app.ElectroSimApp());
  final Finder design = find.byKey(const Key('home-design'));
  await tester.ensureVisible(design);
  await tester.tap(design);
  await tester.pumpAndSettle();

  final Finder wiring = find.byKey(const Key('design-wiring'));
  await tester.ensureVisible(wiring);
  await tester.tap(wiring);
  await tester.pumpAndSettle();

  return tester.widget<SimulatorCanvas>(find.byType(SimulatorCanvas));
}

void main() {
  testWidgets('design workspace starts on a truly blank board', (
    WidgetTester tester,
  ) async {
    final SimulatorCanvas canvas = await _openDesignWorkspace(tester);

    expect(find.byType(app.F18WorkspacePage), findsOneWidget);
    expect(find.byType(app.F9WorkspaceDemoPage), findsNothing);
    expect(find.byKey(const Key('palette-show-all')), findsOneWidget);
    expect(find.byType(F18ComponentAssetVisual), findsAtLeastNWidgets(5));

    expect(canvas.circuit.sources, isEmpty);
    expect(canvas.circuit.components, isEmpty);
    expect(canvas.circuit.connections, isEmpty);
    expect(canvas.circuit.metadata['origin'], 'blank-workspace');
    expect(canvas.layout.elementPositions, isEmpty);
    expect(canvas.wireLayoutEngine, isNull);
    expect(canvas.smartWireSemantics, isTrue);
    expect(canvas.wirePreviewPlanner, isNotNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('compact blank workspace remains usable without overflow', (
    WidgetTester tester,
  ) async {
    final SimulatorCanvas canvas = await _openDesignWorkspace(
      tester,
      size: const Size(390, 844),
    );

    expect(canvas.circuit.components, isEmpty);
    expect(find.byKey(const Key('workspace-rotate-action')), findsOneWidget);
    expect(find.byKey(const Key('workspace-delete-action')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
