import 'package:electrosim_canvas/electrosim_canvas.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_fixture.dart';

void main() {
  const engine = CircuitWireLayoutEngine(
    router: OrthogonalWireRouter(
      grid: 24,
      obstacleClearance: 24,
      envelopePadding: 120,
    ),
  );

  test('adding a connection preserves the existing hand-positioned wire', () {
    final circuit = buildTestCircuit();
    final positions = const <String, Offset>{
      'source': Offset(120, 120),
      'resistor': Offset(120, 408),
    };
    final geometry = CircuitGeometryIndex.build(
      circuit,
      CircuitVisualLayout(elementPositions: positions),
    );
    final existing = circuit.connections.first;
    final start = geometry.terminalPositions[existing.fromTerminalId]!;
    final end = geometry.terminalPositions[existing.toTerminalId]!;
    final customRoute = [Offset(-200, start.dy), Offset(-200, end.dy)];
    final layout = CircuitVisualLayout(
      elementPositions: positions,
      wireRoutes: {existing.id.value: customRoute},
    );
    final String before = circuit.toJsonString();
    final routed = engine.routeConnection(
      circuit: circuit,
      layout: layout,
      connectionId: circuit.connections.last.id,
    );
    expect(routed.routeFor(existing.id.value), orderedEquals(customRoute));
    expect(layout.wireRoutes.length, 1);
    expect(circuit.toJsonString(), before);
    final added = circuit.connections.last;
    final path = OrthogonalWirePath(
      points: [
        geometry.terminalPositions[added.fromTerminalId]!,
        ...routed.routeFor(added.id.value),
        geometry.terminalPositions[added.toTerminalId]!,
      ],
    );
    expect(path.segments, isNotEmpty);
  });
}
