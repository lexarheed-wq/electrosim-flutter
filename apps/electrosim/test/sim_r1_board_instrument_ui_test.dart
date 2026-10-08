import 'package:electrosim/main.dart';
import 'package:electrosim_canvas/electrosim_canvas.dart';
import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/regression_fixture.dart';

void main() {
  testWidgets('SIM-R1 physical voltmeter is added to canvas, not receiver list',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(
      home: F9WorkspaceDemoPage(
        initialCircuit: buildRegressionFixtureCircuit(),
      ),
    ));
    await tester.pumpAndSettle();
    // F18 workspace auto-hides its palette: open it through its real edge.
    await tester.tap(find.byKey(const Key('electrosim-palette-edge')));
    await tester.pumpAndSettle();
    final CircuitState before = tester
        .widget<SimulatorCanvas>(find.byType(SimulatorCanvas)).circuit;
    await tester.enterText(find.byKey(const Key('palette-search-field')), 'voltmètre');
    await tester.pump();
    expect(find.text('Voltmètre physique'), findsWidgets);
    await tester.tap(find.byKey(
      const Key('palette-quick-add-instrument-voltmeter')));
    await tester.pumpAndSettle();

    final SimulatorCanvas canvas =
        tester.widget<SimulatorCanvas>(find.byType(SimulatorCanvas));
    expect(canvas.circuit.instruments, hasLength(1));
    expect(canvas.circuit.components.length, before.components.length);
    expect(canvas.circuit.sources.length, before.sources.length);
    expect(canvas.circuit.connections.length, before.connections.length);
    final String id = canvas.circuit.instruments.single.id.value;
    expect(canvas.layout.positionOf(id), isNotNull);
    expect(canvas.layout.sizeOf(id).height, 152);
    final CircuitGeometryIndex geometry =
        CircuitGeometryIndex.build(canvas.circuit, canvas.layout);
    final Offset center = geometry.elementRects[id]!.center;
    final CanvasHitResult hit = const HitTestEngine().hitTest(
      worldPoint: center,
      circuit: canvas.circuit,
      layout: canvas.layout,
    );
    expect(hit.kind, CanvasHitKind.component);
    expect(hit.elementId, id);
    expect(canvas.circuit.toJsonString(), contains('"instruments"'));
    expect(CircuitState.fromJsonString(canvas.circuit.toJsonString()),
        canvas.circuit);
  });

  testWidgets('SIM-R1 physical ammeter is a native saved canvas entity',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      home: F9WorkspaceDemoPage(
        initialCircuit: buildRegressionFixtureCircuit(),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('electrosim-palette-edge')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('palette-search-field')), 'ampèremètre');
    await tester.pump();
    await tester.tap(find.byKey(
      const Key('palette-quick-add-instrument-ammeter')));
    await tester.pumpAndSettle();
    final SimulatorCanvas canvas =
        tester.widget<SimulatorCanvas>(find.byType(SimulatorCanvas));
    expect(canvas.circuit.instruments.single.kind, InstrumentKind.ammeter);
    expect(canvas.circuit.instruments.single.mode, InstrumentMode.currentDc);
    expect(canvas.circuit.connections, hasLength(3));
    expect(canvas.circuit.probes, isEmpty);
  });
}
