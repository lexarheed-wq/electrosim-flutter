import 'dart:io';

import 'package:electrosim/main.dart';
import 'package:electrosim/runtime/electrosim_layout_persistence.dart';
import 'package:electrosim/runtime/electrosim_persistence_controller.dart';
import 'package:electrosim_canvas/electrosim_canvas.dart';
import 'package:electrosim_storage/electrosim_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/regression_fixture.dart';

void main() {
  test('geometry codec is exact for positions, sizes, rotations and routes', () {
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
      const Offset(48, 72), const Offset(48, 552),
    ]);
    expect(ElectroSimLayoutPersistence.decode(null), isNull);
    expect(
      () => ElectroSimLayoutPersistence.decode(<String, Object?>{
        'schemaVersion': 1,
        'positions': <String, Object?>{'x': <double>[double.nan, 2]},
        'sizes': const <String, Object?>{},
        'routes': const <String, Object?>{},
        'quarterTurns': const <String, Object?>{},
        'defaultSize': <double>[104, 64],
      }),
      throwsFormatException,
    );
  });

  testWidgets('moving an element survives a real save and reopen', (tester) async {
    final Directory? root = await tester.runAsync(
      () => Directory.systemTemp.createTemp('es-layout-audit-'),
    );
    final ElectroSimPersistenceController persistence =
        ElectroSimPersistenceController(LocalStorageRepository(root!));
    await tester.pumpWidget(
      MaterialApp(
        home: F9WorkspaceDemoPage(
          initialCircuit: buildRegressionFixtureCircuit(),
          persistenceController: persistence,
        ),
      ),
    );
    final SimulatorCanvas canvas =
        tester.widget<SimulatorCanvas>(find.byType(SimulatorCanvas));
    final String id = canvas.circuit.components.last.id.value;
    final Offset moved = canvas.layout.positionOf(id)! + const Offset(0, 240);
    canvas.onElementMoved!(id, moved);
    await tester.pump();
    expect(
      tester.widget<SimulatorCanvas>(find.byType(SimulatorCanvas))
          .layout.positionOf(id),
      moved,
    );
    final dynamic toolbar = tester.widget(
      find.byWidgetPredicate(
        (Widget widget) => widget.runtimeType.toString() == '_WorkspaceTopBar',
      ),
    );
    await tester.runAsync(() async {
      await toolbar.onSave();
      await toolbar.onOpen();
    });
    await tester.pump();
    expect(
      tester.widget<SimulatorCanvas>(find.byType(SimulatorCanvas))
          .layout.positionOf(id),
      moved,
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(() => root.delete(recursive: true));
  });
}
