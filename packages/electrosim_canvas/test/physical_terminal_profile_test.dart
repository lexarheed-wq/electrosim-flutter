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

  test('Point 5 pilot terminal anchors scale with each model proportion', () {
    const Map<String, (Size, double)> cases = <String, (Size, double)>{
      'dc_voltage_source': (Size(156, 88), .48),
      'switch': (Size(118, 72), .46),
      'lamp': (Size(86, 86), .44),
      'breaker_dc': (Size(76, 132), .46),
      'push_button_no': (Size(88, 88), .44),
    };

    for (final MapEntry<String, (Size, double)> entry in cases.entries) {
      final Size size = entry.value.$1;
      final double span = size.width * entry.value.$2;
      expect(
        TerminalVisualProfile.terminalOffset(
          modelType: entry.key,
          size: size,
          index: 0,
          count: 2,
        ),
        isA<Offset>()
            .having((Offset value) => value.dx, 'dx', closeTo(-span, 0.0001))
            .having((Offset value) => value.dy, 'dy', 0),
        reason: entry.key,
      );
      expect(
        TerminalVisualProfile.terminalOffset(
          modelType: entry.key,
          size: size,
          index: 1,
          count: 2,
        ),
        isA<Offset>()
            .having((Offset value) => value.dx, 'dx', closeTo(span, 0.0001))
            .having((Offset value) => value.dy, 'dy', 0),
        reason: entry.key,
      );
      expect(span, lessThan(size.width / 2), reason: entry.key);
    }
  });

  test('CircuitGeometryIndex uses the switch-specific physical size', () {
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
      elementSizes: const <String, Size>{
        'switch-a': Size(118, 72),
      },
    );

    final CircuitGeometryIndex geometry =
        CircuitGeometryIndex.build(circuit, layout);

    expect(
      geometry.terminalPositions[left.id]!.dx,
      closeTo(200 - 118 * .46, 0.0001),
    );
    expect(
      geometry.terminalPositions[right.id]!.dx,
      closeTo(200 + 118 * .46, 0.0001),
    );
    expect(
      geometry.terminalRoutingPositions[left.id]!.dx,
      closeTo(200 - 59, 0.0001),
    );
    expect(
      geometry.terminalRoutingPositions[right.id]!.dx,
      closeTo(200 + 59, 0.0001),
    );
  });

  test('physical pilot terminals keep generic invisible routing ports', () {
    const Size size = Size(86, 86);
    expect(
      TerminalVisualProfile.routingOffset(size: size, index: 0, count: 2),
      const Offset(-43, 0),
    );
    expect(
      TerminalVisualProfile.routingOffset(size: size, index: 1, count: 2),
      const Offset(43, 0),
    );
    expect(
      TerminalVisualProfile.terminalOffset(
        modelType: 'lamp',
        size: size,
        index: 0,
        count: 2,
      ).dx,
      greaterThan(-43),
    );
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
