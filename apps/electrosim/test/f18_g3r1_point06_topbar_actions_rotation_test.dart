import 'package:electrosim/main.dart' as app;
import 'package:electrosim_canvas/electrosim_canvas.dart';
import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:electrosim_ui_kit/electrosim_ui_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Terminal _terminal(String id, TerminalRole role) => Terminal(
      id: TerminalId(id),
      name: id,
      role: role,
    );

Future<void> _openContext(WidgetTester tester) async {
  final Finder region = find.byKey(electroSimContextRegionKey);
  final double width =
      tester.view.physicalSize.width / tester.view.devicePixelRatio;
  if (region.evaluate().isEmpty ||
      tester.getRect(region).left >= width) {
    await tester.tap(find.byKey(electroSimContextEdgeKey));
    await tester.pumpAndSettle();
  }
}

Future<void> _openTop(WidgetTester tester) async {
  final Finder region = find.byKey(electroSimTopRegionKey);
  if (region.evaluate().isEmpty ||
      tester.getRect(region).bottom <= 0) {
    await tester.tap(find.byKey(electroSimTopEdgeKey));
    await tester.pumpAndSettle();
  }
}

void main() {
  test('CircuitVisualLayout rotates V2 switch terminal geometry by quarter turns', () {
    final Terminal first = _terminal('first', TerminalRole.input);
    final Terminal second = _terminal('second', TerminalRole.output);
    final CircuitState circuit = CircuitState(
      circuitId: CircuitId('rotation'),
      revision: 1,
      mode: ElectricalMode.dc,
      components: <ComponentInstance>[
        ComponentInstance(
          id: ComponentId('S1'),
          modelType: 'switch',
          terminals: <Terminal>[first, second],
        ),
      ],
      sources: const <SourceInstance>[],
      connections: const <Connection>[],
    );

    final CircuitVisualLayout initial = CircuitVisualLayout(
      elementPositions: const <String, Offset>{'S1': Offset(240, 240)},
      elementSizes: const <String, Size>{'S1': Size(90, 140)},
    );
    final CircuitGeometryIndex before =
        CircuitGeometryIndex.build(circuit, initial);
    expect(
      (before.terminalPositions[first.id]! - const Offset(240, 190)).distance,
      lessThan(1e-6),
    );
    expect(
      (before.terminalPositions[second.id]! - const Offset(240, 290)).distance,
      lessThan(1e-6),
    );

    final CircuitVisualLayout rotated = initial.rotateElement('S1');
    expect(rotated.quarterTurnsOf('S1'), 1);

    final CircuitGeometryIndex after =
        CircuitGeometryIndex.build(circuit, rotated);
    expect(
      (after.terminalPositions[first.id]! - const Offset(290, 240)).distance,
      lessThan(1e-6),
    );
    expect(
      (after.terminalPositions[second.id]! - const Offset(190, 240)).distance,
      lessThan(1e-6),
    );
  });

  testWidgets('rotated default DC layout can be rerouted safely before UI commit',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const app.ElectroSimApp());
    await tester.tap(find.byKey(const Key('home-design')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('design-wiring')));
    await tester.pumpAndSettle();

    final SimulatorCanvas canvas =
        tester.widget<SimulatorCanvas>(find.byType(SimulatorCanvas));
    final CircuitVisualLayout rotated =
        canvas.layout.rotateElement('switch-1');
    final CircuitVisualLayout clean = CircuitVisualLayout(
      elementPositions: rotated.elementPositions,
      elementSizes: rotated.elementSizes,
      elementQuarterTurns: rotated.elementQuarterTurns,
      defaultElementSize: rotated.defaultElementSize,
    );
    const CircuitWireLayoutEngine engine = CircuitWireLayoutEngine(
      router: OrthogonalWireRouter(
        grid: 24,
        obstacleClearance: 24,
        envelopePadding: 120,
      ),
    );
    final CircuitVisualLayout routed = engine.routeAll(
      circuit: canvas.circuit,
      layout: clean,
    );

    expect(routed.quarterTurnsOf('switch-1'), 1);
    final CircuitGeometryIndex geometry =
        CircuitGeometryIndex.build(canvas.circuit, routed);
    for (final Connection connection in canvas.circuit.connections) {
      final Offset start =
          geometry.terminalPositions[connection.fromTerminalId]!;
      final Offset end =
          geometry.terminalPositions[connection.toTerminalId]!;
      final List<Offset> points = <Offset>[
        start,
        ...routed.routeFor(connection.id.value),
        end,
      ];
      for (var index = 0; index + 1 < points.length; index++) {
        final Offset a = points[index];
        final Offset b = points[index + 1];
        expect(
          a.dx == b.dx || a.dy == b.dy,
          isTrue,
          reason:
              '${connection.id.value} unresolved/diagonal after rotation: $points',
        );
      }
    }
  });

  testWidgets('workspace owns the only delete action and a real rotate action',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const app.ElectroSimApp());
    await tester.tap(find.byKey(const Key('home-design')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('design-wiring')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('workspace-rotate-action')), findsOneWidget);
    expect(find.byKey(const Key('workspace-delete-action')), findsOneWidget);
    expect(find.byKey(const Key('properties-delete-element')), findsNothing);
    expect(find.text('Supprimer du circuit'), findsNothing);

    await _openContext(tester);
    await tester.tap(find.byKey(const Key('properties-element-selector')));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('switch-1').last);
    await tester.pumpAndSettle();

    final IconButton rotate = tester.widget<IconButton>(
      find.byKey(const Key('workspace-rotate-action')),
    );
    final IconButton delete = tester.widget<IconButton>(
      find.byKey(const Key('workspace-delete-action')),
    );
    expect(rotate.onPressed, isNotNull);
    expect(delete.onPressed, isNotNull);

    await _openTop(tester);
    await tester.tap(find.byKey(const Key('workspace-rotate-action')));
    await tester.pumpAndSettle();
    SimulatorCanvas canvas =
        tester.widget<SimulatorCanvas>(find.byType(SimulatorCanvas));
    expect(canvas.layout.quarterTurnsOf('switch-1'), 1);

    await tester.tap(find.byKey(const Key('workspace-delete-action')));
    await tester.pumpAndSettle();
    canvas = tester.widget<SimulatorCanvas>(find.byType(SimulatorCanvas));
    expect(
      canvas.circuit.components
          .where((ComponentInstance item) => item.id.value == 'switch-1'),
      isEmpty,
    );
  });
}
