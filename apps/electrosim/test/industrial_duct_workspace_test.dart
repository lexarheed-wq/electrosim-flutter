import 'package:electrosim/main.dart';
import 'package:electrosim_canvas/electrosim_canvas.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/regression_fixture.dart';

void main() {
  for (final rotated in [false, true]) {
    testWidgets(
      'duct command preserves topology and terminal escapes rotated=$rotated',
      (tester) async {
        tester.view.physicalSize = const Size(1440, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final circuit = buildRegressionFixtureCircuit();
        await tester.pumpWidget(
          MaterialApp(
            home: F9WorkspaceDemoPage(
              initialCircuit: circuit,
              initialSelectedElementId: 'switch-1',
              initialCabinetLayout: CabinetLayout([
                CabinetFixture(
                  id: 'bottom',
                  kind: CabinetFixtureKind.wireDuct,
                  bounds: const Rect.fromLTWH(-200, 800, 1800, 40),
                ),
                CabinetFixture(
                  id: 'side',
                  kind: CabinetFixtureKind.wireDuct,
                  bounds: const Rect.fromLTWH(1560, 840, 40, 500),
                ),
              ]),
            ),
          ),
        );
        await tester.pumpAndSettle();
        SimulatorCanvas canvas() =>
            tester.widget<SimulatorCanvas>(find.byType(SimulatorCanvas));
        if (rotated) {
          await tester.tap(find.byKey(const Key('workspace-rotate-action')));
          await tester.pumpAndSettle();
          expect(canvas().layout.quarterTurnsOf('switch-1'), 1);
        }
        final before = canvas().layout;
        await tester.tap(find.byKey(const Key('workspace-more-actions')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('workspace-route-wiring-duct')));
        await tester.pumpAndSettle();
        final after = canvas().layout;
        expect(identical(canvas().circuit, circuit), isTrue);
        expect(after.elementPositions, before.elementPositions);
        expect(after.elementQuarterTurns, before.elementQuarterTurns);
        final geometry = CircuitGeometryIndex.build(circuit, after);
        var changed = 0;
        for (final connection in circuit.connections) {
          final route = after.routeFor(connection.id.value);
          if (route.toString() ==
              before.routeFor(connection.id.value).toString()) {
            continue;
          }
          changed++;
          final a = geometry.terminalPositions[connection.fromTerminalId]!;
          final b = geometry.terminalPositions[connection.toTerminalId]!;
          expect(
            route.first,
            geometry.terminalRoutingPositions[connection.fromTerminalId],
          );
          expect(
            route.last,
            geometry.terminalRoutingPositions[connection.toTerminalId],
          );
          expect(
            CabinetDuctWirePlanner.isClear(
              route,
              obstacles: geometry.elementRects.values,
            ),
            isTrue,
          );
          final points = [a, ...route, b];
          for (var i = 1; i < points.length; i++) {
            expect(
              points[i].dx == points[i - 1].dx ||
                  points[i].dy == points[i - 1].dy,
              isTrue,
            );
          }
        }
        expect(changed, greaterThan(0));
        await tester.tap(find.byKey(const Key('workspace-more-actions')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('workspace-undo-action')));
        await tester.pumpAndSettle();
        expect(canvas().layout.wireRoutes, before.wireRoutes);
        expect(identical(canvas().circuit, circuit), isTrue);
      },
    );
  }
}
