import 'package:electrosim/industrial_workspace_representation.dart';
import 'dart:io';
import 'dart:convert';
import 'package:electrosim/runtime/workspace_layout_preferences.dart';
import 'package:electrosim/runtime/electrosim_simulation_controller.dart';
import 'package:electrosim/main.dart';
import 'package:electrosim/f9_component_visuals.dart';
import 'package:electrosim_canvas/electrosim_canvas.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/regression_fixture.dart';

void main() {
  testWidgets('view preference loads and saves without circuit serialization', (
    tester,
  ) async {
    final dir = Directory.systemTemp.createTempSync('industrial-view-');
    addTearDown(() => dir.deleteSync(recursive: true));
    final prefs = WorkspaceLayoutPreferences(
      File('${dir.path}/preferences.json'),
    );
    await tester.runAsync(
      () => prefs.save({'version': 1, 'representation': 'schematic'}),
    );
    await tester.runAsync(() async {
      await tester.pumpWidget(
        MaterialApp(
          home: F9WorkspaceDemoPage(
            initialCircuit: buildRegressionFixtureCircuit(),
            layoutPreferences: prefs,
          ),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 80));
    });
    await tester.pumpAndSettle();
    expect(find.byType(F9CanvasVisualOverlay), findsNothing);
    await tester.tap(find.byKey(const Key('workspace-view-plate')));
    await tester.runAsync(() async {
      await tester.pumpWidget(const SizedBox());
      final deadline = Stopwatch()..start();
      while ((await prefs.load())?['representation'] != 'plate' &&
          deadline.elapsedMilliseconds < 2000) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      expect(
        (jsonDecode(prefs.file.readAsStringSync()) as Map)['representation'],
        'plate',
      );
    });
  });
  testWidgets(
    'switching representations cancels a pending wire and a physical drag',
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
      final author = canvas().layout;
      Offset screen(Offset p) =>
          tester.getTopLeft(find.byType(SimulatorCanvas)) +
          canvas().viewportController!.worldToScreen(p);
      final ports = CircuitGeometryIndex.build(
        circuit,
        author,
      ).terminalPositions;
      await tester.tapAt(screen(ports.entries.first.value));
      await tester.pump();
      await tester.tap(find.byKey(const Key('workspace-view-schematic')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<IndustrialSchematicOverlay>(
              find.byType(IndustrialSchematicOverlay),
            )
            .pendingTerminal,
        isNull,
      );
      final target = circuit.components.last.terminals.first.id;
      await tester.tapAt(
        screen(
          CircuitGeometryIndex.build(
            circuit,
            canvas().layout,
          ).terminalPositions[target]!,
        ),
      );
      await tester.pump();
      expect(identical(canvas().circuit, circuit), isTrue);
      expect(
        tester
            .widget<IndustrialSchematicOverlay>(
              find.byType(IndustrialSchematicOverlay),
            )
            .pendingTerminal,
        target,
      );
      await tester.tap(find.byKey(const Key('workspace-view-plate')));
      await tester.pumpAndSettle();
      final gesture = await tester.startGesture(
        screen(author.positionOf('lamp-1')!),
      );
      await gesture.moveBy(const Offset(25, 15));
      await tester.pump();
      await tester.tap(find.byKey(const Key('workspace-view-schematic')));
      await tester.pumpAndSettle();
      await gesture.up();
      await tester.pump();
      await tester.tap(find.byKey(const Key('workspace-view-plate')));
      await tester.pumpAndSettle();
      expect(identical(canvas().layout, author), isTrue);
      expect(identical(canvas().circuit, circuit), isTrue);
    },
  );
  for (final size in [const Size(1440, 900), const Size(390, 844)]) {
    testWidgets(
      'plate and white schematic share electrical identities at $size',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final circuit = buildRegressionFixtureCircuit();
        await tester.pumpWidget(
          MaterialApp(
            home: F9WorkspaceDemoPage(
              initialCircuit: circuit,
              initialSelectedElementId: 'lamp-1',
            ),
          ),
        );
        await tester.pumpAndSettle();
        SimulatorCanvas canvas() =>
            tester.widget<SimulatorCanvas>(find.byType(SimulatorCanvas));
        final simulation = tester
            .widgetList<AnimatedBuilder>(find.byType(AnimatedBuilder))
            .map((w) => w.listenable)
            .whereType<ElectroSimSimulationController>()
            .first;
        simulation.advance(const Duration(seconds: 2));
        await tester.pump();
        final snapshot = simulation.snapshot;
        final time = simulation.simulatedTime;
        final physical = canvas().layout;
        final physicalPorts = CircuitGeometryIndex.build(
          circuit,
          physical,
        ).terminalPositions;
        expect(find.byKey(const Key('workspace-view-plate')), findsOneWidget);
        expect(
          find.byKey(const Key('workspace-view-schematic')),
          findsOneWidget,
        );
        for (var count = 0; count < 3; count++) {
          await tester.tap(find.byKey(const Key('workspace-view-schematic')));
          await tester.pumpAndSettle();
          expect(identical(canvas().circuit, circuit), isTrue);
          expect(identical(simulation.snapshot, snapshot), isTrue);
          expect(simulation.simulatedTime, time);
          expect(canvas().selectedElementId, 'lamp-1');
          expect(find.byType(F9CanvasVisualOverlay), findsNothing);
          expect(canvas().layout.elementPositions, physical.elementPositions);
          final schematicPorts = CircuitGeometryIndex.build(
            circuit,
            canvas().layout,
          ).terminalPositions;
          expect(schematicPorts.keys.toSet(), physicalPorts.keys.toSet());
          expect(
            schematicPorts.values.toList(),
            isNot(physicalPorts.values.toList()),
          );
          final hitEngine = const HitTestEngine();
          final session = hitEngine.prepare(
            circuit: circuit,
            layout: canvas().layout,
          );
          for (final port in schematicPorts.entries) {
            expect(
              hitEngine
                  .hitTestPrepared(worldPoint: port.value, session: session)
                  .terminalId,
              port.key,
            );
          }
          await tester.tap(find.byKey(const Key('workspace-view-plate')));
          await tester.pumpAndSettle();
          expect(find.byType(F9CanvasVisualOverlay), findsOneWidget);
          expect(identical(canvas().layout, physical), isTrue);
        }
        expect(tester.takeException(), isNull);
      },
    );
  }
}
