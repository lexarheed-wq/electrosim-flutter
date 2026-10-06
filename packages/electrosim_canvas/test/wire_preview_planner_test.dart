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
}
