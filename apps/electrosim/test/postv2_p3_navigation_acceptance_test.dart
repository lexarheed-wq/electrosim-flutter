import 'package:electrosim/main.dart';
import 'package:electrosim/industrial_schematic_svg_export.dart';
import 'package:electrosim/runtime/electrosim_runtime_engine.dart';
import 'package:electrosim_canvas/electrosim_canvas.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/regression_fixture.dart';

void main() {
  testWidgets(
    'P3 selecting a schematic symbol selects the same physical component',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final circuit = buildRegressionFixtureCircuit();
      await tester.pumpWidget(
        MaterialApp(
          home: F9WorkspaceDemoPage(
            initialCircuit: circuit,
            initialSelectedElementId: 'switch-1',
          ),
        ),
      );
      await tester.pumpAndSettle();

      SimulatorCanvas board() =>
          tester.widget<SimulatorCanvas>(find.byType(SimulatorCanvas));
      expect(board().selectedElementId, 'switch-1');
      await tester.tap(find.byKey(const Key('workspace-view-schematic')));
      await tester.pumpAndSettle();
      expect(board().schematicPresentation, isTrue);
      final lampPosition = board().layout.positionOf('lamp-1')!;
      final screenPosition =
          tester.getTopLeft(find.byType(SimulatorCanvas)) +
          board().viewportController!.worldToScreen(lampPosition);
      await tester.tapAt(screenPosition);
      await tester.pump();
      expect(board().selectedElementId, 'lamp-1');
      expect(identical(board().circuit, circuit), isTrue);

      await tester.tap(find.byKey(const Key('workspace-view-plate')));
      await tester.pumpAndSettle();
      expect(board().schematicPresentation, isFalse);
      expect(board().selectedElementId, 'lamp-1');
      expect(identical(board().circuit, circuit), isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  test('P3 changing only plate geometry cannot alter voltages or current', () {
    final circuit = buildRegressionFixtureCircuit();
    final input = circuit.toJsonString();
    const runtime = ElectroSimRuntimeEngine();
    final reference = runtime.evaluate(circuit);
    final a = CircuitVisualLayout(
      elementPositions: const {
        'source-24v': Offset(120, 200),
        'switch-1': Offset(340, 200),
        'lamp-1': Offset(560, 200),
      },
    );
    final b = CircuitVisualLayout(
      elementPositions: const {
        'source-24v': Offset(250, 300),
        'switch-1': Offset(480, 100),
        'lamp-1': Offset(750, 350),
      },
    );
    final first = IndustrialSchematicSvgExport.render(circuit, a);
    final second = IndustrialSchematicSvgExport.render(circuit, b);
    expect(first, isNot(second));
    for (final wire in circuit.connections) {
      expect(first, contains('id="wire-${wire.id.value}"'));
      expect(second, contains('id="wire-${wire.id.value}"'));
    }
    final after = runtime.evaluate(circuit);
    expect(
      reference.dc.branch('component:lamp-1').voltageV,
      closeTo(after.dc.branch('component:lamp-1').voltageV, 1e-9),
    );
    expect(
      reference.dc.branch('component:lamp-1').currentA,
      closeTo(after.dc.branch('component:lamp-1').currentA!, 1e-9),
    );
    expect(circuit.toJsonString(), input);
  });
}
