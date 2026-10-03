import 'package:electrosim/f18_component_archetypes.dart';
import 'package:electrosim/f18_workspace_wire_safety.dart';
import 'package:electrosim/main.dart' as app;
import 'package:electrosim_canvas/electrosim_canvas.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _openDesignWorkspace(
  WidgetTester tester, {
  Size size = const Size(1440, 900),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(const app.ElectroSimApp());
  final Finder design = find.byKey(const Key('home-design'));
  await tester.ensureVisible(design);
  await tester.pumpAndSettle();
  await tester.tap(design);
  await tester.pumpAndSettle();

  final Finder wiring = find.byKey(const Key('design-wiring'));
  await tester.ensureVisible(wiring);
  await tester.pumpAndSettle();
  await tester.tap(wiring);
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('activity-setup-open-workshop')));
  await tester.pumpAndSettle();
}

void _expectOrthogonalCommittedRoutes(SimulatorCanvas canvas) {
  final CircuitGeometryIndex geometry =
      CircuitGeometryIndex.build(canvas.circuit, canvas.layout);

  for (final connection in canvas.circuit.connections) {
    final Offset start =
        geometry.terminalPositions[connection.fromTerminalId]!;
    final Offset end =
        geometry.terminalPositions[connection.toTerminalId]!;
    final List<Offset> points = <Offset>[
      start,
      ...canvas.layout.routeFor(connection.id.value),
      end,
    ];
    for (var index = 0; index + 1 < points.length; index++) {
      final Offset a = points[index];
      final Offset b = points[index + 1];
      expect(
        a.dx == b.dx || a.dy == b.dy,
        isTrue,
        reason:
            '${connection.id.value} must remain orthogonal: $points',
      );
    }
  }
}

void main() {
  testWidgets('desktop F18 workspace satisfies the complete visible contract',
      (WidgetTester tester) async {
    await _openDesignWorkspace(tester);

    expect(find.byType(app.F18WorkspacePage), findsOneWidget);
    expect(find.byType(app.F9WorkspaceDemoPage), findsNothing);
    expect(find.textContaining('Palette F9'), findsNothing);
    expect(find.textContaining('Canvas F8'), findsNothing);

    expect(find.byKey(const Key('palette-show-all')), findsOneWidget);
    expect(
      find.byType(F18ComponentArchetypeGlyph),
      findsAtLeastNWidgets(3),
      reason:
          'The visible palette viewport must use F18 archetype visuals; '
          'P05 separately proves the five-item quick contract.',
    );
    expect(find.byKey(const Key('workspace-rotate-action')), findsOneWidget);
    expect(find.byKey(const Key('workspace-delete-action')), findsOneWidget);
    expect(find.text('Supprimer du circuit'), findsNothing);

    SimulatorCanvas canvas =
        tester.widget<SimulatorCanvas>(find.byType(SimulatorCanvas));
    expect(canvas.wireLayoutEngine, isNotNull);
    expect(canvas.wirePreviewPlanner, isNotNull);

    final Offset source = canvas.layout.positionOf('source-24v')!;
    final Offset load = canvas.layout.positionOf('lamp-1')!;
    final Offset series = canvas.layout.positionOf('switch-1')!;
    final Size seriesSize = canvas.layout.sizeOf('switch-1');

    expect(source.dy, load.dy);
    expect(series.dy, lessThan(source.dy));
    expect(
      (series.dx - ((source.dx + load.dx) / 2)).abs(),
      lessThanOrEqualTo(.01),
    );

    const double bendKeepOut = 48;
    const double minimumStub = 24;
    final double required =
        bendKeepOut + minimumStub + seriesSize.width / 2;
    expect(series.dx - source.dx, greaterThanOrEqualTo(required));
    expect(load.dx - series.dx, greaterThanOrEqualTo(required));

    _expectOrthogonalCommittedRoutes(canvas);
    expect(
      F18WorkspaceWireSafety.isCrossingFree(
        circuit: canvas.circuit,
        layout: canvas.layout,
      ),
      isTrue,
    );

    await tester.tap(find.byKey(const Key('properties-element-selector')));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('switch-1').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('workspace-rotate-action')));
    await tester.pumpAndSettle();

    canvas = tester.widget<SimulatorCanvas>(find.byType(SimulatorCanvas));
    expect(canvas.layout.quarterTurnsOf('switch-1'), 1);
    _expectOrthogonalCommittedRoutes(canvas);
    expect(
      F18WorkspaceWireSafety.isCrossingFree(
        circuit: canvas.circuit,
        layout: canvas.layout,
      ),
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('compact F18 workspace remains usable without layout overflow',
      (WidgetTester tester) async {
    await _openDesignWorkspace(
      tester,
      size: const Size(390, 844),
    );

    expect(find.byType(app.F18WorkspacePage), findsOneWidget);
    expect(find.byKey(const Key('workspace-rotate-action')), findsOneWidget);
    expect(find.byKey(const Key('workspace-delete-action')), findsOneWidget);
    expect(find.textContaining('F9 final'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
