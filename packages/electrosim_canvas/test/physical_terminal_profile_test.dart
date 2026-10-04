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

  test('reference component terminal anchors scale with each model geometry', () {
    const Map<String, (Size, double)> cases =
        <String, (Size, double)>{
      'dc_voltage_source': (Size(240, 160), .455),
      'switch': (Size(240, 160), .455),
      'lamp': (Size(240, 160), .455),
      'breaker_dc': (Size(240, 160), .455),
      'push_button_no': (Size(240, 160), .455),
      'resistor': (Size(280, 110), .4714285714),
      'push_button_nc': (Size(180, 180), .4444444444),
      'buzzer': (Size(190, 190), .4473684211),
      'fuse_dc': (Size(300, 110), .4733333333),
      'diode': (Size(270, 105), .4703703704),
      'fan_dc': (Size(210, 210), .4523809524),
      'motor_dc': (Size(230, 190), .4565217391),
      'relay_coil': (Size(190, 230), .4473684211),
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

  test('CircuitGeometryIndex uses uploaded switch terminal coordinates', () {
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
        'switch-a': Size(240, 160),
      },
    );

    final CircuitGeometryIndex geometry =
        CircuitGeometryIndex.build(circuit, layout);

    expect(
      geometry.terminalPositions[left.id]!.dx,
      closeTo(200 - 240 * .455, 0.0001),
    );
    expect(
      geometry.terminalPositions[right.id]!.dx,
      closeTo(200 + 240 * .455, 0.0001),
    );
    expect(
      geometry.terminalRoutingPositions[left.id]!.dx,
      closeTo(80, 0.0001),
    );
    expect(
      geometry.terminalRoutingPositions[right.id]!.dx,
      closeTo(320, 0.0001),
    );
  });

  test('reference terminals keep generic invisible routing ports', () {
    const Size size = Size(210, 210);
    expect(
      TerminalVisualProfile.routingOffset(size: size, index: 0, count: 2),
      const Offset(-105, 0),
    );
    expect(
      TerminalVisualProfile.routingOffset(size: size, index: 1, count: 2),
      const Offset(105, 0),
    );
    expect(
      TerminalVisualProfile.terminalOffset(
        modelType: 'fan_dc',
        size: size,
        index: 0,
        count: 2,
      ).dx,
      greaterThan(-105),
    );
  });

  test('unknown two-terminal models keep generic box-edge anchors', () {
    const Size size = Size(104, 64);
    expect(
      TerminalVisualProfile.terminalOffset(
        modelType: 'unknown_model',
        size: size,
        index: 0,
        count: 2,
      ),
      const Offset(-52, 0),
    );
    expect(
      TerminalVisualProfile.terminalOffset(
        modelType: 'unknown_model',
        size: size,
        index: 1,
        count: 2,
      ),
      const Offset(52, 0),
    );
  });
}
