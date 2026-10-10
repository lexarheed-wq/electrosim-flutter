import 'package:electrosim/main.dart';
import 'package:electrosim/industrial_marking_registry.dart';
import 'package:electrosim/industrial_schematic_svg_export.dart';
import 'package:electrosim_canvas/electrosim_canvas.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/regression_fixture.dart';

void main() {
  testWidgets('P4 teacher generates persistent labels and exports wire refs', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final circuit = buildRegressionFixtureCircuit();
    await tester.pumpWidget(
      MaterialApp(home: F9WorkspaceDemoPage(initialCircuit: circuit)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('workspace-more-actions')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const Key('workspace-generate-industrial-markings')),
    );
    await tester.tap(
      find.byKey(const Key('workspace-generate-industrial-markings')),
    );
    await tester.pumpAndSettle();
    final board = tester.widget<SimulatorCanvas>(find.byType(SimulatorCanvas));
    final updated = board.circuit;
    final plan = IndustrialMarkingRegistry.inspect(updated);
    expect(plan.devices['lamp-1'], 'H1');
    expect(plan.devices['switch-1'], 'S1');
    expect(plan.conductors.length, circuit.connections.length);
    expect(updated.connections, circuit.connections);
    expect(updated.metadata, contains(IndustrialMarkingRegistry.metadataKey));
    final svg = IndustrialSchematicSvgExport.render(updated, board.layout);
    expect(svg, contains('data-reference="H1"'));
    expect(svg, contains('data-wire-label='));
    expect(tester.takeException(), isNull);
  });

  testWidgets('P4 teacher edits and locks selected marking', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final original = buildRegressionFixtureCircuit();
    await tester.pumpWidget(
      MaterialApp(
        home: F9WorkspaceDemoPage(
          initialCircuit: original,
          initialSelectedElementId: 'lamp-1',
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('workspace-more-actions')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const Key('workspace-edit-industrial-marking')),
    );
    await tester.tap(
      find.byKey(const Key('workspace-edit-industrial-marking')),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('p4-marking-text')), 'H7');
    await tester.tap(find.byKey(const Key('p4-marking-locked')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('p4-marking-apply')));
    await tester.pumpAndSettle();
    final board = tester.widget<SimulatorCanvas>(find.byType(SimulatorCanvas));
    final labels = IndustrialMarkingRegistry.inspect(board.circuit);
    expect(labels.devices['lamp-1'], 'H7');
    expect(labels.locks['device:lamp-1'], isTrue);
    expect(board.circuit.connections, original.connections);
    expect(tester.takeException(), isNull);
  });
  testWidgets('P4 teacher edits a terminal without changing its physical ID',
      (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final original = buildRegressionFixtureCircuit();
    await tester.pumpWidget(MaterialApp(
      home: F9WorkspaceDemoPage(
        initialCircuit: original,
        initialSelectedElementId: 'lamp-1',
      ),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('workspace-more-actions')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
        find.byKey(const Key('workspace-edit-industrial-marking')));
    await tester.tap(find.byKey(const Key('workspace-edit-industrial-marking')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('p4-marking-target')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Borne : A').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('p4-marking-text')), 'X1:01');
    await tester.tap(find.byKey(const Key('p4-marking-locked')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('p4-marking-apply')));
    await tester.pumpAndSettle();
    final board = tester.widget<SimulatorCanvas>(find.byType(SimulatorCanvas));
    final refs = IndustrialMarkingRegistry.inspect(board.circuit);
    expect(refs.terminals['lamp-in'], 'X1:01');
    expect(refs.locks['terminal:lamp-in'], isTrue);
    expect(refs.devices['lamp-1'], 'H1');
    expect(board.circuit.components, original.components);
    expect(board.circuit.connections, original.connections);
    expect(tester.takeException(), isNull);
  });

}
