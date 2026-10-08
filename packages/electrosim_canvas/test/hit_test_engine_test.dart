import 'package:electrosim_canvas/electrosim_canvas.dart';
import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_fixture.dart';

void main() {
  test('prepared hit-test session matches compatibility path', () {
    final circuit = buildTestCircuit();
    final layout = buildTestLayout();
    const engine = HitTestEngine();
    final HitTestSession session = engine.prepare(
      circuit: circuit,
      layout: layout,
    );
    for (final Offset point in <Offset>[
      const Offset(320, 120),
      const Offset(210, 80),
      const Offset(20, 20),
    ]) {
      final CanvasHitResult legacy = engine.hitTest(
        worldPoint: point,
        circuit: circuit,
        layout: layout,
      );
      final CanvasHitResult prepared = engine.hitTestPrepared(
        worldPoint: point,
        session: session,
      );
      expect(prepared.kind, legacy.kind);
      expect(prepared.elementId, legacy.elementId);
      expect(prepared.terminalId, legacy.terminalId);
      expect(prepared.connectionId, legacy.connectionId);
    }
  });

  test('terminal-only prepared path avoids unrelated component and wire hits', () {
    final circuit = buildTestCircuit();
    final layout = buildTestLayout();
    const engine = HitTestEngine();
    final HitTestSession session = engine.prepare(
      circuit: circuit,
      layout: layout,
    );
    final Offset terminal = session.geometry.terminalPositions.values.first;
    expect(
      engine.hitTestTerminalPrepared(
        worldPoint: terminal,
        session: session,
      ).kind,
      CanvasHitKind.terminal,
    );
    expect(
      engine.hitTestTerminalPrepared(
        worldPoint: const Offset(320, 120),
        session: session,
      ).kind,
      CanvasHitKind.background,
    );
  });

  test('terminal hit has priority over its owning element', () {
    final circuit = buildTestCircuit();
    final layout = buildTestLayout();
    final geometry = CircuitGeometryIndex.build(circuit, layout);
    final position = geometry.terminalPositions.values.first;
    final hit = const HitTestEngine().hitTest(
      worldPoint: position,
      circuit: circuit,
      layout: layout,
    );
    expect(hit.kind, CanvasHitKind.terminal);
    expect(hit.terminalId, isNotNull);
  });

  test('component and wire are detected by centralized hit testing', () {
    final circuit = buildTestCircuit();
    final layout = buildTestLayout();
    final engine = const HitTestEngine();

    final componentHit = engine.hitTest(
      worldPoint: const Offset(320, 120),
      circuit: circuit,
      layout: layout,
    );
    expect(componentHit.kind, CanvasHitKind.component);
    expect(componentHit.elementId, 'resistor');

    final wireHit = engine.hitTest(
      worldPoint: const Offset(210, 80),
      circuit: circuit,
      layout: layout,
    );
    expect(wireHit.kind, CanvasHitKind.wire);
    expect(wireHit.connectionId?.value, 'wire-a');
  });

  test('preview position is used during drag hit testing', () {
    final circuit = buildTestCircuit();
    final layout = buildTestLayout();
    final hit = const HitTestEngine().hitTest(
      worldPoint: const Offset(500, 220),
      circuit: circuit,
      layout: layout,
      previewPositions: const <String, Offset>{'resistor': Offset(500, 220)},
    );
    expect(hit.kind, CanvasHitKind.component);
    expect(hit.elementId, 'resistor');
  });

  test('terminal and wire hit tolerances remain screen-stable across zoom', () {
    final circuit = buildTestCircuit();
    final layout = buildTestLayout();
    final geometry = CircuitGeometryIndex.build(circuit, layout);
    final engine = const HitTestEngine(terminalRadius: 10, wireTolerance: 6);
    final terminal = geometry.terminalPositions[TerminalId('src-pos')]!;

    final hitZoomedIn = engine.hitTest(
      worldPoint: terminal + const Offset(4, 0),
      circuit: circuit,
      layout: layout,
      viewportScale: 2,
    );
    expect(hitZoomedIn.kind, CanvasHitKind.terminal);

    final missZoomedIn = engine.hitTest(
      worldPoint: terminal + const Offset(6, 0),
      circuit: circuit,
      layout: layout,
      viewportScale: 2,
    );
    expect(missZoomedIn.kind, isNot(CanvasHitKind.terminal));

    final hitZoomedOut = engine.hitTest(
      worldPoint: terminal + const Offset(18, 0),
      circuit: circuit,
      layout: layout,
      viewportScale: 0.5,
    );
    expect(hitZoomedOut.kind, CanvasHitKind.terminal);
  });

  test(
    'cross-type visual id collision fails explicitly instead of overwriting geometry',
    () {
      final Terminal sourceTerminal = Terminal(
        id: TerminalId('collision-source-terminal'),
        name: 'S',
        role: TerminalRole.positive,
      );
      final Terminal componentTerminal = Terminal(
        id: TerminalId('collision-component-terminal'),
        name: 'C',
        role: TerminalRole.input,
      );
      final CircuitState circuit = CircuitState(
        circuitId: CircuitId('canvas-collision'),
        revision: 1,
        mode: ElectricalMode.dc,
        sources: <SourceInstance>[
          SourceInstance(
            id: SourceId('shared-visual-id'),
            modelType: 'Source',
            terminals: <Terminal>[sourceTerminal],
          ),
        ],
        components: <ComponentInstance>[
          ComponentInstance(
            id: ComponentId('shared-visual-id'),
            modelType: 'Load',
            terminals: <Terminal>[componentTerminal],
          ),
        ],
      );
      final CircuitVisualLayout layout = CircuitVisualLayout(
        elementPositions: const <String, Offset>{
          'shared-visual-id': Offset(100, 100),
        },
      );

      expect(
        () => CircuitGeometryIndex.build(circuit, layout),
        throwsA(isA<StateError>()),
      );
    },
  );

  test('element and connection visual id collision fails explicitly', () {
    final Terminal sourcePositive = Terminal(
      id: TerminalId('selection-source-pos'),
      name: '+',
      role: TerminalRole.positive,
    );
    final Terminal sourceNegative = Terminal(
      id: TerminalId('selection-source-neg'),
      name: '-',
      role: TerminalRole.negative,
    );
    final Terminal componentIn = Terminal(
      id: TerminalId('selection-component-in'),
      name: 'A',
      role: TerminalRole.input,
    );
    final CircuitState circuit = CircuitState(
      circuitId: CircuitId('canvas-selection-collision'),
      revision: 1,
      mode: ElectricalMode.dc,
      sources: <SourceInstance>[
        SourceInstance(
          id: SourceId('selection-source'),
          modelType: 'Source',
          terminals: <Terminal>[sourcePositive, sourceNegative],
        ),
      ],
      components: <ComponentInstance>[
        ComponentInstance(
          id: ComponentId('shared-selection-id'),
          modelType: 'Load',
          terminals: <Terminal>[componentIn],
        ),
      ],
      connections: <Connection>[
        Connection(
          id: ConnectionId('shared-selection-id'),
          fromTerminalId: sourcePositive.id,
          toTerminalId: componentIn.id,
        ),
      ],
    );
    final CircuitVisualLayout layout = CircuitVisualLayout(
      elementPositions: const <String, Offset>{
        'selection-source': Offset(100, 100),
        'shared-selection-id': Offset(300, 100),
      },
    );

    expect(
      () => CircuitGeometryIndex.build(circuit, layout),
      throwsA(isA<StateError>()),
    );
  });
}
