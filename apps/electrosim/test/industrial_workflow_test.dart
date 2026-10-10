import 'package:electrosim/main.dart';
import 'package:electrosim/runtime/electrosim_layout_persistence.dart';
import 'package:electrosim/runtime/electrosim_runtime_engine.dart';
import 'package:electrosim_canvas/electrosim_canvas.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/industrial_fixture.dart';

void main() {
  testWidgets(
    'wired three-phase cabinet survives views, routing, persistence and undo',
    (t) async {
      t.view.physicalSize = const Size(1440, 900);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final circuit = buildIndustrialSelfHoldCircuit(
        startPressed: true,
        stopPressed: false,
      );
      final initial = CabinetLayout([
        CabinetFixture(
          id: 'R1',
          kind: CabinetFixtureKind.dinRail,
          bounds: const Rect.fromLTWH(100, 900, 1000, 36),
        ),
        CabinetFixture(
          id: 'D1',
          kind: CabinetFixtureKind.wireDuct,
          bounds: const Rect.fromLTWH(24, 1300, 1700, 40),
        ),
        CabinetFixture(
          id: 'D2',
          kind: CabinetFixtureKind.wireDuct,
          bounds: const Rect.fromLTWH(1684, 24, 40, 1276),
        ),
      ]);
      await t.pumpWidget(
        MaterialApp(
          home: F9WorkspaceDemoPage(
            initialCircuit: circuit,
            initialCabinetLayout: initial,
          ),
        ),
      );
      await t.pumpAndSettle();
      SimulatorCanvas canvas() =>
          t.widget<SimulatorCanvas>(find.byType(SimulatorCanvas));
      Future<void> menu(String key) async {
        await t.tap(find.byKey(const Key('workspace-more-actions')));
        await t.pumpAndSettle();
        await t.tap(find.byKey(Key(key)));
        await t.pumpAndSettle();
      }

      await menu('workspace-configure-cabinet');
      await t.enterText(
        find.byKey(const Key('workspace-cabinet-width')),
        '2400',
      );
      await t.enterText(
        find.byKey(const Key('workspace-cabinet-height')),
        '2000',
      );
      await t.tap(find.byKey(const Key('workspace-cabinet-apply')));
      await t.pumpAndSettle();
      expect(find.byKey(const Key('workspace-cabinet-error')), findsNothing);
      final author = canvas().layout;
      expect(author.cabinetLayout.envelope!.widthMm, 2400);
      await menu('workspace-route-wiring-duct');
      final routed = canvas().layout;
      expect(routed.elementPositions, author.elementPositions);
      expect(identical(canvas().circuit, circuit), isTrue);
      await menu('workspace-undo-action');
      expect(canvas().layout.wireRoutes, author.wireRoutes);
      await menu('workspace-redo-action');
      expect(canvas().layout.wireRoutes, routed.wireRoutes);
      await t.tap(find.byKey(const Key('workspace-view-schematic')));
      await t.pumpAndSettle();
      expect(canvas().schematicPresentation, isTrue);
      expect(identical(canvas().circuit, circuit), isTrue);
      await t.tap(find.byKey(const Key('workspace-view-plate')));
      await t.pumpAndSettle();
      expect(canvas().layout.elementPositions, routed.elementPositions);
      final restored = ElectroSimLayoutPersistence.decode(
        ElectroSimLayoutPersistence.encode(canvas().layout),
      )!;
      expect(restored.cabinetLayout.envelope, routed.cabinetLayout.envelope);
      expect(restored.cabinetLayout.mounts, routed.cabinetLayout.mounts);
      expect(restored.wireRoutes, routed.wireRoutes);
      final before = const ElectroSimRuntimeEngine().evaluate(circuit);
      final after = const ElectroSimRuntimeEngine().evaluate(canvas().circuit);
      expect(before.solved, isTrue);
      expect(after.solverKind, before.solverKind);
      expect(after.contactorStates.keys, before.contactorStates.keys);
      for (final id in before.contactorStates.keys) {
        expect(after.contactorActuated(id), before.contactorActuated(id));
        expect(
          after.contactorStates[id]!.coilVoltageV,
          closeTo(before.contactorStates[id]!.coilVoltageV, 1e-9),
        );
      }
      await menu('workspace-preview-3d');
      expect(
        find.byKey(const Key('workspace-cabinet-3d-scene')),
        findsOneWidget,
      );
      expect(t.takeException(), isNull);
    },
  );
}
