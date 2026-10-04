import 'dart:ui' show Offset, Size;

import 'package:electrosim_canvas/electrosim_canvas.dart';
import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Terminal terminal(String id, TerminalRole role) => Terminal(
        id: TerminalId(id),
        name: id,
        role: role,
      );

  test('Point 5 pilot terminal anchors follow each visible component body', () {
    const Size size = Size(104, 64);
    const Map<String, double> expectedHalfSpans = <String, double>{
      'dc_voltage_source': 46.0,
      'switch': 31.2,
      'lamp': 27.0,
      'breaker_dc': 37.2,
      'push_button_no': 31.2,
    };

    for (final MapEntry<String, double> entry in expectedHalfSpans.entries) {
      expect(
        TerminalVisualProfile.terminalOffset(
          modelType: entry.key,
          size: size,
          index: 0,
          count: 2,
        ),
        Offset(-entry.value, 0),
        reason: entry.key,
      );
      expect(
        TerminalVisualProfile.terminalOffset(
          modelType: entry.key,
          size: size,
          index: 1,
          count: 2,
        ),
        Offset(entry.value, 0),
        reason: entry.key,
      );
      expect(entry.value, lessThan(52), reason: entry.key);
    }
  });

  test('CircuitGeometryIndex uses the physical pilot anchors', () {
    final Terminal left = terminal('left', TerminalRole.input);
    final Terminal right = terminal('right', TerminalRole.output);
    final CircuitState circuit = CircuitState(
      circuitId: CircuitId('physical-terminals'),
      revision: 1,
      mode: ElectricalMode.dc,
      components: <ComponentInstance>[
        ComponentInstance(
          id: ComponentId('switch-a'),
          modelType: 'switch',
          terminals: <Terminal>[left, right],
        ),
      ],
      sources: const <SourceInstance>[],
      connections: const <Connection>[],
    );
    final CircuitVisualLayout layout = CircuitVisualLayout(
      elementPositions: const <String, Offset>{
        'switch-a': Offset(200, 100),
      },
    );

    final CircuitGeometryIndex geometry =
        CircuitGeometryIndex.build(circuit, layout);

    expect(geometry.terminalPositions[left.id], const Offset(168.8, 100));
    expect(geometry.terminalPositions[right.id], const Offset(231.2, 100));
  });

  test('non-pilot two-terminal components keep the generic box-edge anchors', () {
    const Size size = Size(104, 64);
    expect(
      TerminalVisualProfile.terminalOffset(
        modelType: 'resistor',
        size: size,
        index: 0,
        count: 2,
      ),
      const Offset(-52, 0),
    );
    expect(
      TerminalVisualProfile.terminalOffset(
        modelType: 'resistor',
        size: size,
        index: 1,
        count: 2,
      ),
      const Offset(52, 0),
    );
  });
}
