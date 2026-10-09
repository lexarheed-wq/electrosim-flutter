import 'dart:ui';

import 'package:electrosim/f18_drag_preview.dart';
import 'package:electrosim/f9_canvas_interaction.dart';
import 'package:electrosim/runtime/electrosim_connection_router.dart';
import 'package:electrosim_canvas/electrosim_canvas.dart';
import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final circuit = CircuitState(
    circuitId: CircuitId('g5-p2'),
    revision: 7,
    mode: ElectricalMode.dc,
    components: [
      for (final id in ['A', 'B'])
        ComponentInstance(
          id: ComponentId(id),
          modelType: 'resistor',
          terminals: [
            Terminal(id: TerminalId('$id-0'), name: '1'),
            Terminal(id: TerminalId('$id-1'), name: '2'),
          ],
        ),
    ],
    connections: [
      Connection(
        id: ConnectionId('W1'),
        fromTerminalId: TerminalId('A-1'),
        toTerminalId: TerminalId('B-0'),
      ),
    ],
  );
  final cabinet = CabinetLayout([
    CabinetFixture(
      id: 'DIN-1',
      kind: CabinetFixtureKind.dinRail,
      bounds: const Rect.fromLTWH(0, 0, 800, 35),
    ),
    CabinetFixture(
      id: 'DUCT-1',
      kind: CabinetFixtureKind.wireDuct,
      bounds: const Rect.fromLTWH(0, 500, 800, 45),
    ),
  ]);
  final layout = CircuitVisualLayout(
    elementPositions: const {'A': Offset(150, 150), 'B': Offset(600, 300)},
    elementQuarterTurns: const {'B': 1},
    cabinetLayout: cabinet,
  );

  test('connected drag preview keeps authored cabinet furniture', () {
    final preview = F18DragSession.begin(
      circuit: circuit,
      baseLayout: layout,
      elementId: 'A',
    ).previewAt(const Offset(250, 200));
    expect(preview.positionOf('A'), const Offset(250, 200));
    expect(preview.wireRoutes.containsKey('W1'), isTrue);
    expect(preview.cabinetLayout, same(cabinet));
    expect(preview.elementQuarterTurns, layout.elementQuarterTurns);
  });

  test('connection click keeps rails and ducts in provisional layout', () {
    final preview = provisionalConnectionLayout(
      circuit: circuit,
      layout: layout,
      connection: circuit.connections.single,
    );
    expect(preview.wireRoutes.containsKey('W1'), isTrue);
    expect(preview.cabinetLayout, same(cabinet));
    expect(preview.elementQuarterTurns, layout.elementQuarterTurns);
    expect(circuit.revision, 7);
  });

  test(
    'legacy orthogonal routing preserves cabinet and component rotation',
    () {
      final routed = F9OrthogonalRouter.reroute(circuit, layout);
      expect(routed.wireRoutes.containsKey('W1'), isTrue);
      expect(routed.cabinetLayout, same(cabinet));
      expect(routed.elementQuarterTurns, layout.elementQuarterTurns);
    },
  );
}
