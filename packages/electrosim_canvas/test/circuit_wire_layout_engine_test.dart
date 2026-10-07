import 'dart:ui' show Offset, Rect, Size;

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

  test(
    'finite wall is rerouted around instead of preserving an invalid visual route',
    () {
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
        elementSizes: const <String, Size>{'wall': Size(1000, 120)},
        wireRoutes: const <String, List<Offset>>{
          'wire-a': <Offset>[Offset(24, 120), Offset(24, 408)],
        },
      );

      final CircuitVisualLayout routed = engine.routeAll(
        circuit: circuit,
        layout: layout,
      );

      expect(
        routed.routeFor('wire-a'),
        isNot(equals(layout.routeFor('wire-a'))),
      );
      final List<Offset> route = routed.routeFor('wire-a');
      expect(
        route.any((Offset point) => point.dx < -380 || point.dx > 620),
        isTrue,
        reason:
            'A finite component wall must be bypassed through free workspace instead of forcing a refusal.',
      );
    },
  );


  test('routeAll prefers a clean pass over an earlier bridged pass', () {
    final Terminal sourcePositive = Terminal(
      id: TerminalId('q-source-pos'),
      name: '+',
      role: TerminalRole.positive,
      phase: PhaseTag.dcPositive,
    );
    final Terminal sourceNegative = Terminal(
      id: TerminalId('q-source-neg'),
      name: '−',
      role: TerminalRole.negative,
      phase: PhaseTag.dcNegative,
    );
    final Terminal switchIn = Terminal(
      id: TerminalId('q-switch-in'),
      name: '1',
      role: TerminalRole.input,
    );
    final Terminal switchOut = Terminal(
      id: TerminalId('q-switch-out'),
      name: '2',
      role: TerminalRole.output,
    );
    final Terminal lampIn = Terminal(
      id: TerminalId('q-lamp-in'),
      name: 'A',
      role: TerminalRole.input,
    );
    final Terminal lampOut = Terminal(
      id: TerminalId('q-lamp-out'),
      name: 'B',
      role: TerminalRole.output,
    );

    final CircuitState circuit = CircuitState(
      circuitId: CircuitId('route-quality'),
      revision: 1,
      mode: ElectricalMode.dc,
      sources: <SourceInstance>[
        SourceInstance(
          id: SourceId('q-source'),
          modelType: 'dc_voltage_source',
          terminals: <Terminal>[sourcePositive, sourceNegative],
        ),
      ],
      components: <ComponentInstance>[
        ComponentInstance(
          id: ComponentId('q-switch'),
          modelType: 'switch',
          terminals: <Terminal>[switchIn, switchOut],
        ),
        ComponentInstance(
          id: ComponentId('q-lamp'),
          modelType: 'lamp',
          terminals: <Terminal>[lampIn, lampOut],
        ),
      ],
      connections: <Connection>[
        Connection(
          id: ConnectionId('q-wire-1'),
          fromTerminalId: sourcePositive.id,
          toTerminalId: switchIn.id,
        ),
        Connection(
          id: ConnectionId('q-wire-2'),
          fromTerminalId: switchOut.id,
          toTerminalId: lampIn.id,
        ),
        Connection(
          id: ConnectionId('q-wire-3'),
          fromTerminalId: lampOut.id,
          toTerminalId: sourceNegative.id,
        ),
      ],
    );
    final CircuitVisualLayout layout = CircuitVisualLayout(
      elementPositions: const <String, Offset>{
        'q-source': Offset(250, 560),
        'q-switch': Offset(720, 280),
        'q-lamp': Offset(1140, 560),
      },
      elementSizes: const <String, Size>{
        'q-source': Size(190, 210),
        'q-switch': Size(150, 190),
        'q-lamp': Size(140, 180),
      },
    );

    final CircuitVisualLayout routed = engine.routeAll(
      circuit: circuit,
      layout: layout,
    );
    final WireSemantics semantics = const WireSemanticsAnalyzer().analyze(
      circuit: circuit,
      layout: routed,
    );

    expect(
      semantics.nonJunctionCrossings,
      isEmpty,
      reason:
          'If one routing order is crossing-free, the engine must prefer it over an earlier bridged pass.',
    );
  });

  test(
    'rotated terminal exits owner body through an outward orthogonal stub',
    () {
      final Terminal aIn = Terminal(
        id: TerminalId('a-in'),
        name: '1',
        role: TerminalRole.input,
      );
      final Terminal aOut = Terminal(
        id: TerminalId('a-out'),
        name: '2',
        role: TerminalRole.output,
      );
      final Terminal bIn = Terminal(
        id: TerminalId('b-in'),
        name: '1',
        role: TerminalRole.input,
      );
      final Terminal bOut = Terminal(
        id: TerminalId('b-out'),
        name: '2',
        role: TerminalRole.output,
      );
      final CircuitState circuit = CircuitState(
        circuitId: CircuitId('rotated-stub'),
        revision: 1,
        mode: ElectricalMode.dc,
        components: <ComponentInstance>[
          ComponentInstance(
            id: ComponentId('A'),
            modelType: 'switch',
            terminals: <Terminal>[aIn, aOut],
          ),
          ComponentInstance(
            id: ComponentId('B'),
            modelType: 'lamp',
            terminals: <Terminal>[bIn, bOut],
          ),
        ],
        sources: const <SourceInstance>[],
        connections: <Connection>[
          Connection(
            id: ConnectionId('wire'),
            fromTerminalId: aOut.id,
            toTerminalId: bIn.id,
          ),
        ],
      );
      final CircuitVisualLayout layout = CircuitVisualLayout(
        elementPositions: const <String, Offset>{
          'A': Offset(240, 240),
          'B': Offset(528, 360),
        },
        elementQuarterTurns: const <String, int>{'A': 1},
      );

      final CircuitVisualLayout routed = engine.routeAll(
        circuit: circuit,
        layout: layout,
      );
      final CircuitGeometryIndex geometry = CircuitGeometryIndex.build(
        circuit,
        routed,
      );
      final Offset start = geometry.terminalPositions[aOut.id]!;
      final Offset end = geometry.terminalPositions[bIn.id]!;
      final List<Offset> points = <Offset>[
        start,
        ...routed.routeFor('wire'),
        end,
      ];

      final Rect ownerRect = geometry.elementRects['A']!;
      expect(points.length, greaterThanOrEqualTo(3));
      expect(points[1].dy, start.dy);
      expect(points[1].dx, lessThan(ownerRect.left));
      expect(
        OrthogonalWirePath(points: points).segments.every(
          (OrthogonalSegment segment) =>
              segment.axis == WireAxis.horizontal ||
              segment.axis == WireAxis.vertical,
        ),
        isTrue,
      );
    },
  );
}
