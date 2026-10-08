import 'package:electrosim/main.dart';
import 'package:electrosim_canvas/electrosim_canvas.dart';
import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:electrosim_ui_kit/electrosim_ui_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/regression_fixture.dart';

void main() {
  testWidgets('AUDIT-UI: one undo restores complete circuit and meter layout',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      theme: ElectroSimTheme.light(),
      home: F9WorkspaceDemoPage(initialCircuit: buildRegressionFixtureCircuit()),
    ));
    await tester.pumpAndSettle();
    final SimulatorCanvas initial =
        tester.widget<SimulatorCanvas>(find.byType(SimulatorCanvas));
    final CircuitState before = initial.circuit;
    tester.widget<GestureDetector>(
      find.byKey(electroSimPaletteEdgeKey),
    ).onTap!();
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('palette-search-field')), 'voltmètre');
    await tester.pump();
    await tester.tap(find.byKey(
      const Key('palette-quick-add-instrument-voltmeter')));
    await tester.pumpAndSettle();
    final SimulatorCanvas added =
        tester.widget<SimulatorCanvas>(find.byType(SimulatorCanvas));
    expect(added.circuit.instruments, hasLength(1));
    final String instrumentId = added.circuit.instruments.single.id.value;
    final Offset? position = added.layout.positionOf(instrumentId);
    expect(position, isNotNull);

    tester.widget<GestureDetector>(
      find.byKey(electroSimTopEdgeKey),
    ).onTap!();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('workspace-more-actions')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('workspace-undo-action')));
    await tester.pumpAndSettle();
    final SimulatorCanvas undone =
        tester.widget<SimulatorCanvas>(find.byType(SimulatorCanvas));
    expect(undone.circuit, before);
    expect(undone.layout.positionOf(instrumentId), isNull);

    await tester.tap(find.byKey(const Key('workspace-more-actions')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('workspace-redo-action')));
    await tester.pumpAndSettle();
    final SimulatorCanvas redone =
        tester.widget<SimulatorCanvas>(find.byType(SimulatorCanvas));
    expect(redone.circuit.instruments.single.id.value, instrumentId);
    expect(redone.layout.positionOf(instrumentId), position);
    expect(redone.circuit.connections, before.connections);
  });
}
