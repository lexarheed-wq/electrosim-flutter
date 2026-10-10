import 'package:electrosim/industrial_schematic_svg_export.dart';
import 'package:electrosim_canvas/electrosim_canvas.dart';
import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/industrial_fixture.dart';
import 'support/regression_fixture.dart';

void main() {
  final circuit = buildRegressionFixtureCircuit();
  final plate = CircuitVisualLayout(
    elementPositions: const {
      'source-24v': Offset(120, 200),
      'switch-1': Offset(340, 200),
      'lamp-1': Offset(560, 200),
    },
  );

  test(
    'P3 SVG is actual multiwire vector output with stable terminal identity',
    () {
      final before = circuit.toJsonString();
      final svg = IndustrialSchematicSvgExport.render(circuit, plate);
      expect(svg, startsWith('<?xml'));
      expect(svg, contains('xmlns="http://www.w3.org/2000/svg"'));
      expect(svg, contains('data-circuit-id="regression-fixture"'));
      expect(svg, contains('id="wire-wire-1"'));
      expect(svg, contains('data-from="source-pos"'));
      expect(svg, contains('data-terminal-id="lamp-in"'));
      expect(svg, contains('id="device-lamp-1"'));
      expect(svg, contains('data-reference="lamp-1"'));
      expect(
        RegExp('<polyline ').allMatches(svg).length,
        circuit.connections.length,
      );
      expect(circuit.toJsonString(), before);
      expect(plate.terminalAnchorOffsets, isEmpty);
    },
  );

  test(
    'P3 SVG is deterministic if device and wire insertion order changes',
    () {
      final reversed = CircuitState(
        circuitId: circuit.circuitId,
        revision: circuit.revision,
        mode: circuit.mode,
        components: circuit.components.reversed.toList(),
        sources: circuit.sources.reversed.toList(),
        connections: circuit.connections.reversed.toList(),
        settings: circuit.settings,
        metadata: circuit.metadata,
      );
      expect(
        IndustrialSchematicSvgExport.render(circuit, plate),
        IndustrialSchematicSvgExport.render(reversed, plate),
      );
    },
  );

  test('P3 SVG does not silently omit devices with missing location', () {
    final missing = CircuitVisualLayout(
      elementPositions: const {
        'source-24v': Offset(120, 200),
        'lamp-1': Offset(560, 200),
      },
    );
    expect(
      () => IndustrialSchematicSvgExport.render(circuit, missing),
      throwsStateError,
    );
  });

  test('P3 contact symbols distinguish NO from NC at rest', () {
    Terminal port(String id) => Terminal(id: TerminalId(id), name: id);
    ComponentInstance contact(String id, String type) => ComponentInstance(
      id: ComponentId(id),
      modelType: type,
      terminals: [port('$id-1'), port('$id-2')],
    );
    final sample = CircuitState(
      circuitId: CircuitId('contact-export'),
      revision: 1,
      mode: ElectricalMode.dc,
      components: [
        contact('no', 'push_button_no'),
        contact('nc', 'push_button_nc'),
      ],
    );
    final layout = CircuitVisualLayout(
      elementPositions: const {'no': Offset(100, 100), 'nc': Offset(320, 100)},
    );
    final svg = IndustrialSchematicSvgExport.render(sample, layout);
    expect(svg, contains('<path d="M -16 0 H 16"/>'));
    expect(svg, contains('<path d="M -16 0 L 12 -17"/>'));
    expect(svg, contains('id="device-no"'));
    expect(svg, contains('id="device-nc"'));
  });
  test('P3 SVG preserves all six motor terminals and auxiliary contact references', () {
    final ac3 = buildIndustrialSelfHoldCircuit(startPressed: false, stopPressed: false);
    final elements = <String, Offset>{
      for (final source in ac3.sources) source.id.value: const Offset(100, 120),
      for (final component in ac3.components)
        component.id.value: Offset(350 + ac3.components.indexOf(component) * 250, 220),
    };
    final svg = IndustrialSchematicSvgExport.render(
      ac3, CircuitVisualLayout(elementPositions: elements),
    );
    for (final terminal in ['m-u1', 'm-v1', 'm-w1', 'm-u2', 'm-v2', 'm-w2']) {
      expect(svg, contains('data-terminal-id="$terminal"'), reason: terminal);
    }
    expect(svg, contains('data-reference="k1"'));
    expect(svg, contains('id="device-aux"'));
    expect(svg, contains('↔ k1'));
    expect(RegExp('<polyline ').allMatches(svg).length, ac3.connections.length);
  });

}
