import 'package:electrosim/main.dart';
import 'package:electrosim_canvas/electrosim_canvas.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'P2 user creates a DIN rail, undoes and redoes without changing the circuit',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const MaterialApp(home: F9WorkspaceDemoPage()));
      await tester.pumpAndSettle();

      final original = tester.widget<SimulatorCanvas>(
        find.byType(SimulatorCanvas),
      );
      final beforeCircuit = original.circuit;
      expect(original.layout.cabinetLayout.fixtures, isEmpty);
      await tester.tap(find.byKey(const Key('workspace-more-actions')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('workspace-add-din-rail')), findsOneWidget);
      await tester.tap(find.byKey(const Key('workspace-add-din-rail')));
      await tester.pumpAndSettle();

      final after = tester.widget<SimulatorCanvas>(
        find.byType(SimulatorCanvas),
      );
      expect(after.layout.cabinetLayout.fixtures, hasLength(1));
      expect(
        after.layout.cabinetLayout.fixtures.single.kind,
        CabinetFixtureKind.dinRail,
      );
      expect(after.circuit, beforeCircuit);

      await tester.tap(find.byKey(const Key('workspace-more-actions')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('workspace-undo-action')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<SimulatorCanvas>(find.byType(SimulatorCanvas))
            .layout
            .cabinetLayout
            .fixtures,
        isEmpty,
      );

      await tester.tap(find.byKey(const Key('workspace-more-actions')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('workspace-redo-action')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<SimulatorCanvas>(find.byType(SimulatorCanvas))
            .layout
            .cabinetLayout
            .fixtures
            .single
            .kind,
        CabinetFixtureKind.dinRail,
      );
    },
  );

  testWidgets(
    'P2 menu creates duct and terminal area without changing circuit',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const MaterialApp(home: F9WorkspaceDemoPage()));
      await tester.pumpAndSettle();
      final before = tester
          .widget<SimulatorCanvas>(find.byType(SimulatorCanvas))
          .circuit;
      for (final key in [
        'workspace-add-wire-duct',
        'workspace-add-terminal-zone',
      ]) {
        await tester.tap(find.byKey(const Key('workspace-more-actions')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(Key(key)));
        await tester.pumpAndSettle();
      }
      final canvas = tester.widget<SimulatorCanvas>(
        find.byType(SimulatorCanvas),
      );
      expect(canvas.layout.cabinetLayout.fixtures.map((f) => f.kind).toSet(), {
        CabinetFixtureKind.wireDuct,
        CabinetFixtureKind.terminalZone,
      });
      expect(canvas.circuit, before);
    },
  );
}
