import 'dart:ui' show Offset, Size;

import 'package:electrosim_canvas/electrosim_canvas.dart';
import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  void expectOffset(
    Offset actual,
    Offset expected, {
    required String reason,
  }) {
    expect(
      (actual - expected).distance,
      lessThan(1e-6),
      reason: reason,
    );
  }

  Terminal terminal(String id, TerminalRole role) => Terminal(
        id: TerminalId(id),
        name: id,
        role: role,
      );

  test('uploaded V2 physical terminals match exact Dart design coordinates', () {
    const Map<String, (Size, List<Offset>)> cases =
        <String, (Size, List<Offset>)>{
      'dc_voltage_source': (
        Size(140, 160),
        <Offset>[Offset(-28, 47), Offset(24, 47)],
      ),
      'breaker_dc': (
        Size(72, 160),
        <Offset>[Offset(0, -57), Offset(0, 57)],
      ),
      'switch': (
        Size(90, 140),
        <Offset>[Offset(0, -50), Offset(0, 50)],
      ),
      'push_button_no': (
        Size(90, 140),
        <Offset>[Offset(-14, 49), Offset(14, 49)],
      ),
      'lamp': (
        Size(130, 160),
        <Offset>[Offset(-25, 59), Offset(25, 59)],
      ),
    };

    for (final MapEntry<String, (Size, List<Offset>)> entry
        in cases.entries) {
      final Size size = entry.value.$1;
      final List<Offset> expected = entry.value.$2;
      for (var index = 0; index < 2; index++) {
        expectOffset(
          TerminalVisualProfile.terminalOffset(
            modelType: entry.key,
            size: size,
            index: index,
            count: 2,
          ),
          expected[index],
          reason: '${entry.key} terminal $index',
        );
      }
    }
  });

  test('extended reference components retain existing horizontal lug anchors',
      () {
    const Map<String, (Size, double)> cases =
        <String, (Size, double)>{
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
        Offset(-span, 0),
        reason: entry.key,
      );
      expect(
        TerminalVisualProfile.terminalOffset(
          modelType: entry.key,
          size: size,
          index: 1,
          count: 2,
        ),
        Offset(span, 0),
        reason: entry.key,
      );
    }
  });

  test('uploaded V2 routing ports follow each physical terminal exit side', () {
    expectOffset(
      TerminalVisualProfile.routingOffset(
        modelType: 'switch',
        size: const Size(90, 140),
        index: 0,
        count: 2,
      ),
      const Offset(0, -70),
      reason: 'switch route 0',
    );
    expectOffset(
      TerminalVisualProfile.routingOffset(
        modelType: 'switch',
        size: const Size(90, 140),
        index: 1,
        count: 2,
      ),
      const Offset(0, 70),
      reason: 'switch route 1',
    );
    expectOffset(
      TerminalVisualProfile.routingOffset(
        modelType: 'dc_voltage_source',
        size: const Size(140, 160),
        index: 0,
        count: 2,
      ),
      const Offset(-28, 80),
      reason: 'supply route 0',
    );
    expectOffset(
      TerminalVisualProfile.routingOffset(
        modelType: 'push_button_no',
        size: const Size(90, 140),
        index: 1,
        count: 2,
      ),
      const Offset(14, 70),
      reason: 'button route 1',
    );
  });

  test('CircuitGeometryIndex rotates V2 switch anchors with the component', () {
    final Terminal first = terminal('first', TerminalRole.input);
    final Terminal second = terminal('second', TerminalRole.output);
    final CircuitState circuit = CircuitState(
      circuitId: CircuitId('physical-terminals-v2'),
      revision: 1,
      mode: ElectricalMode.dc,
      components: <ComponentInstance>[
        ComponentInstance(
          id: ComponentId('switch-a'),
          modelType: 'switch',
          terminals: <Terminal>[first, second],
        ),
      ],
    );
    final CircuitVisualLayout layout = CircuitVisualLayout(
      elementPositions: const <String, Offset>{
        'switch-a': Offset(200, 100),
      },
      elementSizes: const <String, Size>{
        'switch-a': Size(90, 140),
      },
      elementQuarterTurns: const <String, int>{'switch-a': 1},
    );

    final CircuitGeometryIndex geometry =
        CircuitGeometryIndex.build(circuit, layout);

    expectOffset(
      geometry.terminalPositions[first.id]!,
      const Offset(250, 100),
      reason: 'rotated switch terminal 0',
    );
    expectOffset(
      geometry.terminalPositions[second.id]!,
      const Offset(150, 100),
      reason: 'rotated switch terminal 1',
    );
    expectOffset(
      geometry.terminalRoutingPositions[first.id]!,
      const Offset(270, 100),
      reason: 'rotated switch routing 0',
    );
    expectOffset(
      geometry.terminalRoutingPositions[second.id]!,
      const Offset(130, 100),
      reason: 'rotated switch routing 1',
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
