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

  testWidgets(
      'real design workspace exposes qualified orthogonal committed geometry',
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
    final CircuitGeometryIndex geometry =
        CircuitGeometryIndex.build(canvas.circuit, canvas.layout);

    for (final connection in canvas.circuit.connections) {
      final Offset start =
          geometry.terminalPositions[connection.fromTerminalId]!;
      final Offset end =
          geometry.terminalPositions[connection.toTerminalId]!;
      final List<Offset> points = <Offset>[
        start,
        ...canvas.layout.routeFor(connection.id.value),
        end,
      ];
      for (var index = 0; index + 1 < points.length; index++) {
        final Offset a = points[index];
        final Offset b = points[index + 1];
        expect(
          a.dx == b.dx || a.dy == b.dy,
          isTrue,
          reason:
              'Committed route for ${connection.id.value} must remain orthogonal: $points',
        );
      }
    }

    // MagicPath qualifies the negative return below the straight positive
    // branch. This is an intentional product composition, not an invitation
    // for the generic shortest-path router to move the return above devices.
    expect(
      canvas.layout.routeFor('wire-4'),
      orderedEquals(const <Offset>[
        Offset(784, 430),
        Offset(104, 430),
      ]),
    );
    final double lowestDeviceBottom = geometry.elementRects.values
        .map((Rect rect) => rect.bottom)
        .reduce((double a, double b) => a > b ? a : b);
    expect(
      canvas.layout.routeFor('wire-4').first.dy,
      greaterThan(lowestDeviceBottom + 48),
    );
  });
}
