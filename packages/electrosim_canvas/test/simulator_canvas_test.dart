import 'package:electrosim_canvas/electrosim_canvas.dart';
import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_fixture.dart';

Widget _host({
  required CircuitState circuit,
  required CircuitVisualLayout layout,
  ViewportController? viewport,
  ValueChanged<String?>? onSelectionChanged,
  ElementMovedCallback? onElementMoved,
  ConnectionRequestedCallback? onConnectionRequested,
  ValueChanged<CanvasHitResult>? onContextAction,
  CircuitWireLayoutEngine? wireLayoutEngine,
  WirePreviewPlanner? wirePreviewPlanner,
}) => MaterialApp(
  home: Scaffold(
    body: SizedBox.expand(
      child: SimulatorCanvas(
        circuit: circuit,
        layout: layout,
        viewportController: viewport,
        onSelectionChanged: onSelectionChanged,
        onElementMoved: onElementMoved,
        onConnectionRequested: onConnectionRequested,
        onContextAction: onContextAction,
        wireLayoutEngine: wireLayoutEngine,
        wirePreviewPlanner: wirePreviewPlanner,
      ),
    ),
  ),
);

void main() {
  testWidgets('click selects component without moving it', (
    WidgetTester tester,
  ) async {
    final CircuitState circuit = buildTestCircuit();
    final CircuitVisualLayout layout = buildTestLayout();
    String? selected;
    var moveCount = 0;
    await tester.pumpWidget(
      _host(
        circuit: circuit,
        layout: layout,
        onSelectionChanged: (String? value) => selected = value,
        onElementMoved: (String _, Offset __) => moveCount++,
      ),
    );

    await tester.tapAt(const Offset(320, 120));
    await tester.pump();
    expect(selected, 'resistor');
    expect(moveCount, 0);
    expect(layout.positionOf('resistor'), const Offset(320, 120));
    await tester.pumpAndSettle();
  });

  testWidgets('long press plus drag requests a graphical move', (
    WidgetTester tester,
  ) async {
    final CircuitState circuit = buildTestCircuit();
    final CircuitVisualLayout layout = buildTestLayout();
    String? movedId;
    Offset? movedPosition;
    await tester.pumpWidget(
      _host(
        circuit: circuit,
        layout: layout,
        onElementMoved: (String id, Offset position) {
          movedId = id;
          movedPosition = position;
        },
      ),
    );

    final TestGesture gesture = await tester.startGesture(
      const Offset(320, 120),
    );
    await tester.pump(const Duration(milliseconds: 550));
    await gesture.moveTo(const Offset(390, 170));
    await tester.pump();
    await gesture.up();
    await tester.pump();

    expect(movedId, 'resistor');
    expect(movedPosition, isNotNull);
    expect((movedPosition! - const Offset(390, 170)).distance, lessThan(1));
  });

  testWidgets(
    'two terminal taps request a connection and do not mutate CircuitState',
    (WidgetTester tester) async {
      final CircuitState circuit = buildTestCircuit();
      final String before = circuit.toJsonString();
      final CircuitVisualLayout layout = buildTestLayout();
      final CircuitGeometryIndex geometry = CircuitGeometryIndex.build(
        circuit,
        layout,
      );
      TerminalId? from;
      TerminalId? to;

      await tester.pumpWidget(
        _host(
          circuit: circuit,
          layout: layout,
          onConnectionRequested: (TerminalId a, TerminalId b) {
            from = a;
            to = b;
          },
        ),
      );

      await tester.tapAt(geometry.terminalPositions[TerminalId('src-pos')]!);
      await tester.pump(const Duration(milliseconds: 320));
      await tester.tapAt(geometry.terminalPositions[TerminalId('res-in')]!);
      await tester.pump(const Duration(milliseconds: 320));

      expect(from?.value, 'src-pos');
      expect(to?.value, 'res-in');
      expect(circuit.toJsonString(), before);
    },
  );

  testWidgets('background drag pans viewport but leaves layout unchanged', (
    WidgetTester tester,
  ) async {
    final CircuitState circuit = buildTestCircuit();
    final CircuitVisualLayout layout = buildTestLayout();
    final ViewportController viewport = ViewportController();
    await tester.pumpWidget(
      _host(circuit: circuit, layout: layout, viewport: viewport),
    );

    await tester.dragFrom(const Offset(520, 420), const Offset(60, 30));
    await tester.pumpAndSettle();
    expect(viewport.translation.distance, greaterThan(0));
    expect(layout.positionOf('source'), const Offset(100, 120));
  });

  testWidgets('double tap on a component emits contextual action', (
    WidgetTester tester,
  ) async {
    final CircuitState circuit = buildTestCircuit();
    final CircuitVisualLayout layout = buildTestLayout();
    CanvasHitResult? contextHit;
    await tester.pumpWidget(
      _host(
        circuit: circuit,
        layout: layout,
        onContextAction: (CanvasHitResult hit) => contextHit = hit,
      ),
    );

    await tester.tapAt(const Offset(320, 120));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tapAt(const Offset(320, 120));
    await tester.pumpAndSettle();

    expect(contextHit?.kind, CanvasHitKind.component);
    expect(contextHit?.elementId, 'resistor');
  });

  testWidgets(
    'background tap cancels pending wiring before another terminal tap',
    (WidgetTester tester) async {
      final CircuitState circuit = buildTestCircuit();
      final CircuitVisualLayout layout = buildTestLayout();
      final CircuitGeometryIndex geometry = CircuitGeometryIndex.build(
        circuit,
        layout,
      );
      var connectionCount = 0;

      await tester.pumpWidget(
        _host(
          circuit: circuit,
          layout: layout,
          onConnectionRequested: (TerminalId _, TerminalId __) =>
              connectionCount++,
        ),
      );

      await tester.tapAt(geometry.terminalPositions[TerminalId('src-pos')]!);
      await tester.pump();
      await tester.tapAt(const Offset(620, 500));
      await tester.pump();
      await tester.tapAt(geometry.terminalPositions[TerminalId('res-in')]!);
      await tester.pump();

      expect(connectionCount, 0);
    },
  );

  testWidgets('clicking a wire selects its connection id', (
    WidgetTester tester,
  ) async {
    final CircuitState circuit = buildTestCircuit();
    final CircuitVisualLayout layout = buildTestLayout();
    String? selected;
    await tester.pumpWidget(
      _host(
        circuit: circuit,
        layout: layout,
        onSelectionChanged: (String? value) => selected = value,
      ),
    );

    await tester.tapAt(const Offset(210, 80));
    await tester.pump();
    expect(selected, 'wire-a');
  });

  testWidgets('smart routing opt-in supplies routed geometry to the painter', (
    WidgetTester tester,
  ) async {
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
    const OrthogonalWireRouter router = OrthogonalWireRouter(
      grid: 24,
      obstacleClearance: 24,
      envelopePadding: 120,
    );

    await tester.pumpWidget(
      _host(
        circuit: circuit,
        layout: layout,
        wireLayoutEngine: const CircuitWireLayoutEngine(router: router),
        wirePreviewPlanner: const WirePreviewPlanner(
          router: router,
          terminalSnapRadius: 24,
        ),
      ),
    );

    final CustomPaint paint = tester.widget<CustomPaint>(
      find.byType(CustomPaint).last,
    );
    final CircuitScenePainter painter = paint.painter! as CircuitScenePainter;
    expect(painter.layout.routeFor('wire-a'), isNotEmpty);
    expect(painter.wirePreviewPlanner, isNotNull);
    expect(painter.smartWireSemantics, isTrue);
    expect(circuit.toJsonString(), before);
  });

  testWidgets('wheel zoom changes viewport around pointer', (
    WidgetTester tester,
  ) async {
    final CircuitState circuit = buildTestCircuit();
    final CircuitVisualLayout layout = buildTestLayout();
    final ViewportController viewport = ViewportController();
    await tester.pumpWidget(
      _host(circuit: circuit, layout: layout, viewport: viewport),
    );

    final TestPointer mouse = TestPointer(1, PointerDeviceKind.mouse);
    tester.binding.handlePointerEvent(mouse.hover(const Offset(250, 200)));
    tester.binding.handlePointerEvent(
      PointerScrollEvent(
        position: const Offset(250, 200),
        scrollDelta: const Offset(0, -20),
      ),
    );
    await tester.pump();
    expect(viewport.scale, greaterThan(1));
  });
}
