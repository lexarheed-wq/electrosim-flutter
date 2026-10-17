import 'dart:io';

import 'package:electrosim/main.dart';
import 'package:electrosim/runtime/electrosim_layout_persistence.dart';
import 'package:electrosim/runtime/electrosim_persistence_controller.dart';
import 'package:electrosim/runtime/electrosim_tp_session_controller.dart';
import 'package:electrosim_canvas/electrosim_canvas.dart';
import 'package:electrosim_storage/electrosim_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/regression_fixture.dart';

void main() {
  test(
    'geometry codec is exact for positions, sizes, rotations and routes',
    () {
      final CircuitVisualLayout layout = CircuitVisualLayout(
        elementPositions: const <String, Offset>{'source': Offset(744, 552)},
        elementSizes: const <String, Size>{'source': Size(120, 84)},
        elementQuarterTurns: const <String, int>{'source': 3},
        wireRoutes: const <String, List<Offset>>{
          'link': <Offset>[Offset(48, 72), Offset(48, 552)],
        },
      );
      final CircuitVisualLayout restored = ElectroSimLayoutPersistence.decode(
        ElectroSimLayoutPersistence.encode(layout),
      )!;
      expect(restored.positionOf('source'), const Offset(744, 552));
      expect(restored.sizeOf('source'), const Size(120, 84));
      expect(restored.quarterTurnsOf('source'), 3);
      expect(restored.routeFor('link'), <Offset>[
        const Offset(48, 72),
        const Offset(48, 552),
      ]);
      expect(ElectroSimLayoutPersistence.decode(null), isNull);
      expect(
        () => ElectroSimLayoutPersistence.decode(<String, Object?>{
          'schemaVersion': 1,
          'positions': <String, Object?>{
            'x': <double>[double.nan, 2],
          },
          'sizes': const <String, Object?>{},
          'routes': const <String, Object?>{},
          'quarterTurns': const <String, Object?>{},
          'defaultSize': <double>[104, 64],
        }),
        throwsFormatException,
      );
    },
  );

  testWidgets('moving an element survives a real save and reopen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final Directory root =
        Directory.systemTemp.createTempSync('es-layout-audit-');
    addTearDown(() => root.deleteSync(recursive: true));
    final ElectroSimPersistenceController persistence =
        ElectroSimPersistenceController(LocalStorageRepository(root));
    await tester.pumpWidget(
      MaterialApp(
        home: F9WorkspaceDemoPage(
          initialCircuit: buildRegressionFixtureCircuit(),
          persistenceController: persistence,
        ),
      ),
    );
    final SimulatorCanvas canvas = tester.widget<SimulatorCanvas>(
      find.byType(SimulatorCanvas),
    );
    final String id = canvas.circuit.components.last.id.value;
    final Offset moved = canvas.layout.positionOf(id)! + const Offset(0, 240);
    canvas.onElementMoved!(id, moved);
    await tester.pump();
    expect(
      tester
          .widget<SimulatorCanvas>(find.byType(SimulatorCanvas))
          .layout
          .positionOf(id),
      moved,
    );
    await tester.tap(find.byKey(const Key('workspace-save-direct-action')));
    await tester.pump();
    await tester.runAsync(() async {
      final File saveFile = File(
        '${root.path}/${ElectroSimPersistenceController.defaultSaveId}.electrosim.json',
      );
      final Stopwatch deadline = Stopwatch()..start();
      while (!await saveFile.exists()) {
        if (deadline.elapsed > const Duration(seconds: 5)) {
          fail('The workspace save did not reach local storage.');
        }
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    });
    await tester.tap(find.byKey(const Key('workspace-open-direct-action')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('workspace-resume-confirm')), findsOneWidget);
    await tester.tap(find.byKey(const Key('workspace-resume-confirm')));
    await tester.runAsync(() async {
      final restored = await persistence.openWorkspace(
        ElectroSimPersistenceController.defaultSaveId,
        tpController: ElectroSimTpSessionController(),
      );
      expect(restored.visualLayout?.positionOf(id), moved);
    });
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<SimulatorCanvas>(find.byType(SimulatorCanvas))
          .layout
          .positionOf(id),
      moved,
    );
  });
}
