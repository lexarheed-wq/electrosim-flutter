import 'package:electrosim/main.dart' as app;
import 'package:electrosim_canvas/electrosim_canvas.dart';
import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:electrosim_ui_kit/electrosim_ui_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/regression_fixture.dart';

SimulatorCanvas board(WidgetTester t) =>
    t.widget<SimulatorCanvas>(find.byType(SimulatorCanvas));
Future<void> mount(WidgetTester t, {bool unwired = false}) async {
  t.view.physicalSize = const Size(1440, 900);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  final fixture = buildRegressionFixtureCircuit();
  final circuit = unwired
      ? CircuitState(
          circuitId: fixture.circuitId,
          revision: fixture.revision,
          mode: fixture.mode,
          sources: fixture.sources,
          components: fixture.components,
          connections: [],
          settings: fixture.settings,
        )
      : fixture;
  await t.pumpWidget(
    MaterialApp(
      theme: ElectroSimTheme.light(),
      home: app.F9WorkspaceDemoPage(initialCircuit: circuit),
    ),
  );
  await t.pumpAndSettle();
}

Offset terminal(WidgetTester t, String id) {
  final canvas = board(t);
  final geometry = CircuitGeometryIndex.build(canvas.circuit, canvas.layout);
  return t.getTopLeft(find.byKey(electroSimCanvasRegionKey)) +
      canvas.viewportController!.worldToScreen(
        geometry.terminalPositions[TerminalId(id)]!,
      );
}

void main() {
  testWidgets(
    'dock changes preserve world center and complete circuit layout',
    (t) async {
      await mount(t);
      final first = board(t);
      final vp = first.viewportController!;
      final rect = t.getRect(find.byKey(electroSimCanvasRegionKey));
      final worldCenter = vp.screenToWorld(rect.size.center(Offset.zero));
      await t.tap(find.byKey(electroSimPaletteEdgeKey));
      await t.pumpAndSettle();
      final next = t.getRect(find.byKey(electroSimCanvasRegionKey));
      expect(
        (vp.screenToWorld(next.size.center(Offset.zero)) - worldCenter)
            .distance,
        lessThan(1e-6),
      );
      expect(board(t).layout.elementPositions, first.layout.elementPositions);
      expect(board(t).layout.wireRoutes, first.layout.wireRoutes);
      expect(board(t).circuit.revision, first.circuit.revision);
      await t.drag(
        find.byKey(const Key('workspace-context-resizer')),
        const Offset(-25, 0),
      );
      await t.pumpAndSettle();
      expect(board(t).layout.elementPositions, first.layout.elementPositions);
      expect(board(t).layout.wireRoutes, first.layout.wireRoutes);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'connection pointer coordinates remain correct after closing docks',
    (t) async {
      await mount(t, unwired: true);
      await t.tap(find.byKey(electroSimPaletteEdgeKey));
      await t.pumpAndSettle();
      await t.tap(find.byKey(electroSimContextEdgeKey));
      await t.pumpAndSettle();
      await t.tapAt(terminal(t, 'switch-out'));
      await t.pump();
      await t.tapAt(terminal(t, 'lamp-in'));
      await t.pumpAndSettle();
      expect(board(t).circuit.connections, hasLength(1));
      final connection = board(t).circuit.connections.single;
      expect(
        {connection.fromTerminalId.value, connection.toTerminalId.value},
        {'switch-out', 'lamp-in'},
      );
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'window resize cancels a pending wire without a phantom connection',
    (t) async {
      await mount(t, unwired: true);
      await t.tapAt(terminal(t, 'switch-out'));
      await t.pump();
      t.view.physicalSize = const Size(1100, 900);
      await t.pumpAndSettle();
      await t.tapAt(terminal(t, 'lamp-in'));
      await t.pumpAndSettle();
      expect(board(t).circuit.connections, isEmpty);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets('blank workspace remains usable after adaptive resize', (
    t,
  ) async {
    t.view.physicalSize = const Size(1440, 900);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(
      MaterialApp(
        theme: ElectroSimTheme.light(),
        home: const app.F18WorkspacePage(),
      ),
    );
    await t.pumpAndSettle();
    t.view.physicalSize = const Size(390, 844);
    await t.pumpAndSettle();
    expect(board(t).circuit.components, isEmpty);
    expect(t.takeException(), isNull);
  });
  testWidgets(
    'compact recenter fits the fixture in the actual visible viewport',
    (t) async {
      await mount(t);
      t.view.physicalSize = const Size(390, 844);
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('workspace-more-actions')));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const Key('workspace-recenter-action')));
      await t.pumpAndSettle();
      final canvas = board(t);
      final geometry = CircuitGeometryIndex.build(
        canvas.circuit,
        canvas.layout,
      );
      final size = t.getSize(find.byKey(electroSimCanvasRegionKey));
      for (final rect in geometry.elementRects.values) {
        final a = canvas.viewportController!.worldToScreen(rect.topLeft);
        final b = canvas.viewportController!.worldToScreen(rect.bottomRight);
        expect(a.dx, greaterThanOrEqualTo(0));
        expect(b.dx, lessThanOrEqualTo(size.width));
        expect(a.dy, greaterThanOrEqualTo(0));
        expect(b.dy, lessThanOrEqualTo(size.height));
      }
    },
  );
}
