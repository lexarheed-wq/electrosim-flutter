import 'dart:ui' show Offset, Size;

import 'package:electrosim_canvas/electrosim_canvas.dart';
import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_fixture.dart';

void main() {
  const WirePreviewPlanner planner = WirePreviewPlanner(
    router: OrthogonalWireRouter(
      grid: 24,
      obstacleClearance: 24,
      envelopePadding: 120,
    ),
    terminalSnapRadius: 24,
  );

  test('preview snaps to a nearby compatible geometric terminal position', () {
    final CircuitState circuit = buildTestCircuit();
    final CircuitVisualLayout layout = CircuitVisualLayout(
      elementPositions: const <String, Offset>{
        'source': Offset(120, 120),
        'resistor': Offset(120, 408),
      },
    );
    final CircuitGeometryIndex geometry = CircuitGeometryIndex.build(
      circuit,
      layout,
    );
    final Offset target = geometry.terminalPositions[TerminalId('res-in')]!;

    final WirePreviewPlan plan = planner.plan(
      circuit: circuit,
      layout: layout,
      startTerminalId: TerminalId('src-pos'),
      pointerWorldPosition: target + const Offset(8, 4),
    );

    expect(plan.route.isResolved, isTrue);
    expect(plan.snappedTargetTerminalId, TerminalId('res-in'));
    expect(plan.endPoint, target);
    expect(plan.route.path!.points.last, target);
  });

  test('preview detours around a component obstacle', () {
    final CircuitState base = buildTestCircuit();
    final CircuitState circuit = CircuitState(
      circuitId: base.circuitId,
      revision: base.revision,
      mode: base.mode,
      sources: base.sources,
      connections: const <Connection>[],
      components: <ComponentInstance>[
        base.components.first,
        ComponentInstance(
          id: ComponentId('blocker'),
          modelType: 'Routing obstacle',
          terminals: const <Terminal>[],
        ),
      ],
      settings: base.settings,
      metadata: base.metadata,
    );
    final CircuitVisualLayout layout = CircuitVisualLayout(
      elementPositions: const <String, Offset>{
        'source': Offset(120, 120),
        'blocker': Offset(120, 264),
        'resistor': Offset(120, 408),
      },
    );

    final WirePreviewPlan plan = planner.plan(
      circuit: circuit,
      layout: layout,
      startTerminalId: TerminalId('src-pos'),
      pointerWorldPosition: const Offset(68, 408),
    );

    expect(plan.route.isResolved, isTrue);
    expect(plan.route.path!.bends, isNotEmpty);
  });

  test(
    'preview detours around a long finite wall instead of crossing it',
    () {
      final CircuitState base = buildTestCircuit();
      final CircuitState circuit = CircuitState(
        circuitId: base.circuitId,
        revision: base.revision,
        mode: base.mode,
        sources: base.sources,
        connections: const <Connection>[],
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
      );

      final WirePreviewPlan plan = planner.plan(
        circuit: circuit,
        layout: layout,
        startTerminalId: TerminalId('src-pos'),
        pointerWorldPosition: const Offset(68, 408),
      );

      expect(plan.route.isResolved, isTrue);
      expect(plan.route.path!.bends, isNotEmpty);
    },
  );

  test('prepared preview preserves routing result while reusing stable context', () {
    final CircuitState circuit = buildTestCircuit();
    final CircuitVisualLayout layout = CircuitVisualLayout(
      elementPositions: const <String, Offset>{
        'source': Offset(120, 120),
        'resistor': Offset(120, 408),
      },
    );
    final WirePreviewSession session = planner.prepare(
      circuit: circuit,
      layout: layout,
      startTerminalId: TerminalId('src-pos'),
    );
    const Offset pointer = Offset(70, 405);
    final WirePreviewPlan direct = planner.plan(
      circuit: circuit,
      layout: layout,
      startTerminalId: TerminalId('src-pos'),
      pointerWorldPosition: pointer,
    );
    final WirePreviewPlan prepared = planner.planPrepared(
      session: session,
      pointerWorldPosition: pointer,
    );

    expect(prepared.snappedTargetTerminalId, direct.snappedTargetTerminalId);
    expect(prepared.endPoint, direct.endPoint);
    expect(prepared.route.isResolved, direct.route.isResolved);
    expect(prepared.route.path?.points, direct.route.path?.points);
  });

  test('prepared preview hot path stays inside frame budget on 200 elements', () {
    final CircuitState circuit = _denseCircuit(200);
    final CircuitVisualLayout layout = _denseLayout(circuit);
    final WirePreviewSession session = planner.prepare(
      circuit: circuit,
      layout: layout,
      startTerminalId: circuit.components.first.terminals.first.id,
    );

    for (var i = 0; i < 12; i++) {
      planner.planPrepared(
        session: session,
        pointerWorldPosition: Offset(260 + i * 5.0, 220 + (i % 5) * 11.0),
      );
    }
    final List<int> samples = <int>[];
    for (var i = 0; i < 80; i++) {
      final Stopwatch stopwatch = Stopwatch()..start();
      planner.planPrepared(
        session: session,
        pointerWorldPosition: Offset(260 + (i % 20) * 18.0, 220 + (i % 9) * 17.0),
      );
      stopwatch.stop();
      samples.add(stopwatch.elapsedMicroseconds);
    }
    samples.sort();
    final int p95 = samples[((samples.length - 1) * 0.95).round()];
    expect(
      p95,
      lessThan(16667),
      reason: '200-element wire preview must retain a 60 fps CPU budget',
    );
  });

}


CircuitState _denseCircuit(int count) {
  final List<ComponentInstance> components = <ComponentInstance>[];
  final List<Connection> connections = <Connection>[];
  for (var i = 0; i < count; i++) {
    final Terminal a = Terminal(id: TerminalId('dense-$i-a'), name: 'A');
    final Terminal b = Terminal(id: TerminalId('dense-$i-b'), name: 'B');
    components.add(
      ComponentInstance(
        id: ComponentId('dense-$i'),
        modelType: 'resistor',
        terminals: <Terminal>[a, b],
        parameters: const <String, Object?>{'resistanceOhm': 100.0},
      ),
    );
    if (i > 0) {
      connections.add(
        Connection(
          id: ConnectionId('dense-wire-$i'),
          fromTerminalId: components[i - 1].terminals.last.id,
          toTerminalId: a.id,
        ),
      );
    }
  }
  return CircuitState(
    circuitId: CircuitId('dense-preview-$count'),
    revision: 0,
    mode: ElectricalMode.dc,
    components: components,
    connections: connections,
  );
}

CircuitVisualLayout _denseLayout(CircuitState circuit) {
  final Map<String, Offset> positions = <String, Offset>{};
  const int columns = 20;
  for (var i = 0; i < circuit.components.length; i++) {
    positions[circuit.components[i].id.value] = Offset(
      100 + (i % columns) * 130.0,
      100 + (i ~/ columns) * 100.0,
    );
  }
  return CircuitVisualLayout(
    elementPositions: positions,
    defaultElementSize: const Size(92, 56),
  );
}
