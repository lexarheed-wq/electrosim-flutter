import 'package:electrosim/f18_drag_preview.dart';
import 'package:electrosim/f9_canvas_interaction.dart';
import 'package:electrosim/runtime/electrosim_connection_router.dart';
import 'package:electrosim/f18_workspace_page.dart';
import 'package:electrosim_canvas/electrosim_canvas.dart';
import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';

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
  final cabinet = CabinetLayout(
    [
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
    ],
    envelope: CabinetEnvelope(widthMm: 1000, heightMm: 700, depthMm: 200),
    mounts: {'A': CabinetMount(railId: 'DIN-1')},
  );
  final layout = CircuitVisualLayout(
    elementPositions: const {'A': Offset(150, 150), 'B': Offset(600, 300)},
    elementQuarterTurns: const {'B': 1},
    cabinetLayout: cabinet,
    terminalAnchorOffsets: const {'A-1': Offset(5, 6), 'B-0': Offset(-4, 3)},
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
    expect(preview.terminalAnchorOffsets, layout.terminalAnchorOffsets);
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
    expect(preview.terminalAnchorOffsets, layout.terminalAnchorOffsets);
    expect(circuit.revision, 7);
  });

  test(
    'legacy orthogonal routing preserves cabinet and component rotation',
    () {
      final routed = F9OrthogonalRouter.reroute(circuit, layout);
      expect(routed.wireRoutes.containsKey('W1'), isTrue);
      expect(routed.cabinetLayout, same(cabinet));
      expect(routed.elementQuarterTurns, layout.elementQuarterTurns);
      expect(routed.terminalAnchorOffsets, layout.terminalAnchorOffsets);
    },
  );

  testWidgets('real connected drag preserves the cabinet after release', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: F18WorkspacePage(
          initialCircuit: circuit,
          initialVisualLayout: layout,
        ),
      ),
    );
    await tester.pumpAndSettle();
    SimulatorCanvas canvas() =>
        tester.widget<SimulatorCanvas>(find.byType(SimulatorCanvas));
    final before = canvas().layout;
    final start =
        tester.getTopLeft(find.byType(SimulatorCanvas)) +
        canvas().viewportController!.worldToScreen(
          before.positionOf('A')! + const Offset(-25, -15),
        );
    final gesture = await tester.startGesture(start);
    await gesture.moveBy(const Offset(65, 40));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
    expect(canvas().layout.positionOf('A'), isNot(before.positionOf('A')));
    expect(canvas().layout.cabinetLayout.fixtures.map((f) => f.id), [
      'DIN-1',
      'DUCT-1',
    ]);
    expect(canvas().layout.cabinetLayout.envelope, cabinet.envelope);
    expect(canvas().layout.terminalAnchorOffsets, layout.terminalAnchorOffsets);
    expect(canvas().circuit, same(circuit));
  });

  testWidgets(
    '30-device workspace preserves cabinet through background connection routing',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final large = CircuitState(
        circuitId: circuit.circuitId,
        revision: 7,
        mode: circuit.mode,
        components: [
          ...circuit.components,
          for (var i = 0; i < 28; i++)
            ComponentInstance(
              id: ComponentId('R$i'),
              modelType: 'resistor',
              terminals: [
                Terminal(id: TerminalId('R$i-0'), name: '1'),
                Terminal(id: TerminalId('R$i-1'), name: '2'),
              ],
            ),
        ],
        connections: circuit.connections,
      );
      final largeLayout = CircuitVisualLayout(
        elementPositions: {
          ...layout.elementPositions,
          for (var i = 0; i < 28; i++)
            'R$i': Offset(1200 + (i % 7) * 200, 150 + (i ~/ 7) * 160),
        },
        elementQuarterTurns: layout.elementQuarterTurns,
        terminalAnchorOffsets: layout.terminalAnchorOffsets,
        cabinetLayout: cabinet,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: F18WorkspacePage(
            initialCircuit: large,
            initialVisualLayout: largeLayout,
          ),
        ),
      );
      await tester.pumpAndSettle();
      SimulatorCanvas canvas() =>
          tester.widget<SimulatorCanvas>(find.byType(SimulatorCanvas));
      canvas().onConnectionRequested!(TerminalId('A-0'), TerminalId('B-1'));
      await tester.pump();
      expect(canvas().circuit.connections, hasLength(2));
      expect(
        canvas().layout.cabinetLayout,
        same(cabinet),
        reason:
            'Immediate provisional layout must keep cabinet before async routing',
      );
      final provisional = canvas().layout;
      final deadline = Stopwatch()..start();
      while (identical(canvas().layout, provisional) &&
          deadline.elapsed < const Duration(seconds: 5)) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pumpAndSettle();
      }
      expect(
        canvas().layout,
        isNot(same(provisional)),
        reason: 'The real isolate routing result must have been applied',
      );
      expect(canvas().layout.cabinetLayout.envelope, cabinet.envelope);
      expect(
        canvas().layout.cabinetLayout.fixtures.map(
          (f) => (f.id, f.kind, f.bounds),
        ),
        cabinet.fixtures.map((f) => (f.id, f.kind, f.bounds)),
      );
      expect(canvas().layout.cabinetLayout.mounts, cabinet.mounts);
      expect(
        canvas().layout.terminalAnchorOffsets,
        layout.terminalAnchorOffsets,
      );
    },
  );
}
