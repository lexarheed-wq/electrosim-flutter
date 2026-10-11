import 'package:electrosim/main.dart';
import 'package:electrosim/runtime/electrosim_layout_persistence.dart';
import 'package:electrosim/runtime/electrosim_runtime_engine.dart';
import 'package:electrosim_canvas/electrosim_canvas.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/regression_fixture.dart';

void main() {
  testWidgets(
    'P2 live DC load survives cabinet geometry, duct routing and schematic view',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final circuit = buildRegressionFixtureCircuit();
      const runtime = ElectroSimRuntimeEngine();
      final reference = runtime.evaluate(circuit);
      expect(reference.solved, isTrue);
      final referenceLoad = reference.dc.branch('component:lamp-1');
      expect(referenceLoad.currentA, isNotNull);
      expect(referenceLoad.powerW, isNotNull);

      final cabinet = CabinetLayout([
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
      await tester.pumpWidget(
        MaterialApp(
          home: F9WorkspaceDemoPage(
            initialCircuit: circuit,
            initialCabinetLayout: cabinet,
          ),
        ),
      );
      await tester.pumpAndSettle();

      SimulatorCanvas canvas() =>
          tester.widget<SimulatorCanvas>(find.byType(SimulatorCanvas));

      Future<void> menu(String key) async {
        await tester.tap(find.byKey(const Key('workspace-more-actions')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(Key(key)));
        await tester.pumpAndSettle();
      }

      await menu('workspace-configure-cabinet');
      await tester.enterText(
        find.byKey(const Key('workspace-cabinet-width')),
        '2400',
      );
      await tester.enterText(
        find.byKey(const Key('workspace-cabinet-height')),
        '2000',
      );
      await tester.tap(find.byKey(const Key('workspace-cabinet-apply')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('workspace-cabinet-error')), findsNothing);
      expect(canvas().layout.cabinetLayout.envelope!.widthMm, 2400);

      await menu('workspace-route-wiring-duct');
      await tester.tap(find.byKey(const Key('workspace-view-schematic')));
      await tester.pumpAndSettle();
      expect(canvas().schematicPresentation, isTrue);
      expect(identical(canvas().circuit, circuit), isTrue);
      await tester.tap(find.byKey(const Key('workspace-view-plate')));
      await tester.pumpAndSettle();
      expect(canvas().schematicPresentation, isFalse);

      final layout = canvas().layout;
      final restored = ElectroSimLayoutPersistence.decode(
        ElectroSimLayoutPersistence.encode(layout),
      )!;
      expect(restored.cabinetLayout.fixtures.length, 3);
      expect(restored.cabinetLayout.envelope, layout.cabinetLayout.envelope);
      expect(restored.wireRoutes, layout.wireRoutes);

      // Neither geometry nor projection is allowed to rewrite CircuitState.
      expect(identical(canvas().circuit, circuit), isTrue);
      expect(canvas().circuit.connections, circuit.connections);

      final result = runtime.evaluate(canvas().circuit);
      expect(result.solved, isTrue);
      expect(result.solverKind, reference.solverKind);
      final load = result.dc.branch('component:lamp-1');
      expect(load.voltageV, closeTo(referenceLoad.voltageV, 1e-9));
      expect(load.currentA, closeTo(referenceLoad.currentA!, 1e-9));
      expect(load.powerW, closeTo(referenceLoad.powerW!, 1e-9));
      expect(tester.takeException(), isNull);
    },
  );
}
