import 'dart:io';

import 'package:electrosim/main.dart' as app;
import 'package:electrosim_canvas/electrosim_canvas.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('production workspace no longer calls the legacy F9 router', () {
    final String source = File('lib/main.dart').readAsStringSync();
    expect(source, isNot(contains('F9OrthogonalRouter.reroute')));
  });

  testWidgets('real design workspace exposes G2A-routed committed geometry',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const app.ElectroSimApp());
    await tester.tap(find.byKey(const Key('home-design')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('design-wiring')));
    await tester.pumpAndSettle();

    final SimulatorCanvas canvas =
        tester.widget<SimulatorCanvas>(find.byType(SimulatorCanvas));

    const CircuitWireLayoutEngine engine = CircuitWireLayoutEngine(
      router: OrthogonalWireRouter(
        grid: 24,
        obstacleClearance: 24,
        envelopePadding: 120,
      ),
    );
    final CircuitVisualLayout rerouted = engine.routeAll(
      circuit: canvas.circuit,
      layout: canvas.layout,
    );

    for (final connection in canvas.circuit.connections) {
      expect(
        canvas.layout.routeFor(connection.id.value),
        orderedEquals(rerouted.routeFor(connection.id.value)),
        reason:
            'Committed route for ${connection.id.value} must already be the G2A route.',
      );
    }
  });
}
