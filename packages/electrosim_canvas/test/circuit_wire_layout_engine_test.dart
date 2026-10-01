import 'dart:ui' show Offset, Size;

import 'package:electrosim_canvas/electrosim_canvas.dart';
import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_fixture.dart';

void main() {
  const CircuitWireLayoutEngine engine = CircuitWireLayoutEngine(
    router: OrthogonalWireRouter(
      grid: 24,
      obstacleClearance: 24,
      envelopePadding: 120,
    ),
  );

  test('routes all connections without mutating CircuitState', () {
    final CircuitState base = buildTestCircuit();
    final CircuitState circuit = CircuitState(
      circuitId: base.circuitId,
      revision: base.revision,
      mode: base.mode,
      sources: base.sources,
      connections: base.connections,
      components: <ComponentInstance>[
        ...base.components,
        ComponentInstance(
          id: ComponentId('blocker'),
          modelType: 'Routing obstacle',
          terminals: const <Terminal>[],
        ),
      ],
      settings: base.settings,
      metadata: base.metadata,
    );
    final String before = circuit.toJsonString();
    final CircuitVisualLayout layout = CircuitVisualLayout(
      elementPositions: const <String, Offset>{
        'source': Offset(120, 120),
        'blocker': Offset(120, 264),
        'resistor': Offset(120, 408),
      },
    );

    final CircuitVisualLayout routed = engine.routeAll(
      circuit: circuit,
      layout: layout,
    );

    expect(circuit.toJsonString(), before);
    expect(routed.elementPositions, equals(layout.elementPositions));
    expect(routed.wireRoutes.keys, containsAll(<String>['wire-a', 'wire-b']));

    final CircuitGeometryIndex geometry = CircuitGeometryIndex.build(
      circuit,
      routed,
    );
    for (final Connection connection in circuit.connections) {
      final OrthogonalWirePath path = OrthogonalWirePath(
        points: <Offset>[
          geometry.terminalPositions[connection.fromTerminalId]!,
          ...routed.routeFor(connection.id.value),
          geometry.terminalPositions[connection.toTerminalId]!,
        ],
      );
      expect(path.segments, isNotEmpty);
      expect(
        path.segments.every(
          (OrthogonalSegment segment) =>
              segment.axis == WireAxis.horizontal ||
              segment.axis == WireAxis.vertical,
        ),
        isTrue,
      );
    }
  });

  test('routeAll is idempotent', () {
    final CircuitState circuit = buildTestCircuit();
    final CircuitVisualLayout layout = CircuitVisualLayout(
      elementPositions: const <String, Offset>{
        'source': Offset(120, 120),
        'resistor': Offset(120, 408),
      },
    );

    final CircuitVisualLayout first = engine.routeAll(
      circuit: circuit,
      layout: layout,
    );
    final CircuitVisualLayout second = engine.routeAll(
      circuit: circuit,
      layout: first,
    );

    expect(second.wireRoutes, equals(first.wireRoutes));
    expect(second.elementPositions, equals(first.elementPositions));
  });

  test('unresolved routing preserves the previous visual route', () {
    final CircuitState base = buildTestCircuit();
    final CircuitState circuit = CircuitState(
      circuitId: base.circuitId,
      revision: base.revision,
      mode: base.mode,
      sources: base.sources,
      connections: <Connection>[base.connections.first],
      components: <ComponentInstance>[
        base.components.first,
        ComponentInstance(
          id: ComponentId('wall'),
          modelType: 'Wall',
          terminals: const <Terminal>[],
        ),
      ],
      settings: base.settings,
      metadata: base.metadata,
    );
    final CircuitVisualLayout layout = CircuitVisualLayout(
      elementPositions: const <String, Offset>{
        'source': Offset(120, 120),
        'resistor': Offset(120, 408),
        'wall': Offset(120, 264),
      },
      elementSizes: const <String, Size>{
        'wall': Size(1000, 120),
      },
      wireRoutes: const <String, List<Offset>>{
        'wire-a': <Offset>[
          Offset(24, 120),
          Offset(24, 408),
        ],
      },
    );

    final CircuitVisualLayout routed = engine.routeAll(
      circuit: circuit,
      layout: layout,
    );

    expect(routed.routeFor('wire-a'), layout.routeFor('wire-a'));
  });
}
