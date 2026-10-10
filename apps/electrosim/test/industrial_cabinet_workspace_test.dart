import 'package:electrosim/main.dart';
import 'package:electrosim_canvas/electrosim_canvas.dart';
import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/regression_fixture.dart';

void main() {
  testWidgets(
    'palette insertion respects enclosure and deletion cleans mounting metadata',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final circuit = CircuitState(
        circuitId: CircuitId('empty-cabinet'),
        revision: 0,
        mode: ElectricalMode.dc,
        components: const [],
        sources: const [],
        connections: const [],
      );
      Future<void> open(double width) async {
        await tester.pumpWidget(const SizedBox());
        await tester.pumpWidget(
          MaterialApp(
            home: F9WorkspaceDemoPage(
              initialCircuit: circuit,
              initialCabinetLayout: CabinetLayout(
                [],
                envelope: CabinetEnvelope(
                  widthMm: width,
                  heightMm: width,
                  depthMm: 300,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      SimulatorCanvas canvas() =>
          tester.widget<SimulatorCanvas>(find.byType(SimulatorCanvas));
      await open(80);
      await tester.tap(
        find.byKey(const Key('palette-quick-add-source-dc-24v')),
      );
      await tester.pumpAndSettle();
      expect(canvas().circuit.sources, isEmpty);
      expect(canvas().layout.cabinetLayout.mounts, isEmpty);
      await open(2400);
      await tester.tap(
        find.byKey(const Key('palette-quick-add-source-dc-24v')),
      );
      await tester.pumpAndSettle();
      expect(canvas().circuit.sources, hasLength(1));
      final id = canvas().circuit.sources.single.id.value;
      expect(canvas().layout.cabinetLayout.mounts, contains(id));
      await tester.tap(find.byKey(const Key('workspace-delete-action')));
      await tester.pumpAndSettle();
      expect(canvas().layout.cabinetLayout.mounts, isNot(contains(id)));
      await tester.tap(find.byKey(const Key('workspace-more-actions')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('workspace-undo-action')));
      await tester.pumpAndSettle();
      expect(canvas().layout.cabinetLayout.mounts, contains(id));
    },
  );
  testWidgets(
    'cabinet dimensions and preview preserve the authored circuit and undo',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final circuit = buildRegressionFixtureCircuit();
      await tester.pumpWidget(
        MaterialApp(home: F9WorkspaceDemoPage(initialCircuit: circuit)),
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
      expect(find.byKey(const Key('workspace-cabinet-width')), findsOneWidget);
      await tester.tap(find.byKey(const Key('workspace-cabinet-apply')));
      await tester.pumpAndSettle();
      final dynamic cabinet = canvas().layout.cabinetLayout;
      expect(cabinet.envelope.widthMm, 1200);
      expect(cabinet.envelope.heightMm, 1000);
      expect(identical(canvas().circuit, circuit), isTrue);
      final author = canvas().layout;
      await menu('workspace-preview-3d');
      final scene = find.byKey(const Key('workspace-cabinet-3d-scene'));
      expect(scene, findsOneWidget);
      final dynamic first = tester.widget<CustomPaint>(scene).painter;
      final yaw = first.yaw;
      await tester.drag(scene, const Offset(70, 25));
      await tester.pump();
      final dynamic rotated = tester.widget<CustomPaint>(scene).painter;
      expect(rotated.yaw, isNot(yaw));
      expect(identical(rotated.circuit, circuit), isTrue);
      expect(identical(rotated.layout, author), isTrue);
      await tester.tap(find.byKey(const Key('workspace-preview-reset')));
      await tester.pump();
      final dynamic reset = tester.widget<CustomPaint>(scene).painter;
      expect(reset.yaw, yaw);
      await tester.tap(find.byKey(const Key('workspace-preview-close')));
      await tester.pumpAndSettle();
      expect(identical(canvas().layout, author), isTrue);
      await menu('workspace-undo-action');
      final dynamic undone = canvas().layout.cabinetLayout;
      expect(undone.envelope, isNull);
      await menu('workspace-redo-action');
      expect(identical(canvas().layout, author), isTrue);
      await menu('workspace-configure-cabinet');
      await tester.enterText(
        find.byKey(const Key('workspace-cabinet-width')),
        '0',
      );
      await tester.tap(find.byKey(const Key('workspace-cabinet-apply')));
      await tester.pump();
      expect(find.byKey(const Key('workspace-cabinet-error')), findsOneWidget);
      expect(identical(canvas().layout, author), isTrue);
    },
  );
}
