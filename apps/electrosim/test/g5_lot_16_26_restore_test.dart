import 'package:electrosim/f18_workspace_page.dart';
import 'package:electrosim_canvas/electrosim_canvas.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'g5_lot_16_26_fixtures.dart';

void main() {
  for (final key in ['source-ac3-grid', 'source-ac3-alternator']) {
    testWidgets('$key restores its own dimensions when no layout is saved', (
      t,
    ) async {
      t.view.physicalSize = const Size(1600, 1000);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final s = NativeApplianceGeometry.catalogue[key]!;
      await t.pumpWidget(
        MaterialApp(home: F18WorkspacePage(initialCircuit: lastLotFixture(s))),
      );
      await t.pump(const Duration(seconds: 1));
      await t.pump();
      expect(
        t
            .widget<SimulatorCanvas>(find.byType(SimulatorCanvas))
            .layout
            .sizeOf(key),
        s.boardSize,
      );
      expect(t.takeException(), isNull);
    });
  }
  testWidgets('saved custom television size is preserved', (t) async {
    t.view.physicalSize = const Size(1600, 1000);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    final s = NativeApplianceGeometry.catalogue['external-tv']!;
    final l = lastLotLayout(s);
    final saved = CircuitVisualLayout(
      elementPositions: l.elementPositions,
      elementSizes: {...l.elementSizes, s.key: const Size(180, 190)},
    );
    await t.pumpWidget(
      MaterialApp(
        home: F18WorkspacePage(
          initialCircuit: lastLotFixture(s),
          initialVisualLayout: saved,
        ),
      ),
    );
    await t.pump(const Duration(seconds: 1));
    await t.pump();
    expect(
      t
          .widget<SimulatorCanvas>(find.byType(SimulatorCanvas))
          .layout
          .sizeOf(s.key),
      const Size(180, 190),
    );
  });
}
