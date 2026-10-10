import 'package:electrosim/main.dart';
import 'package:electrosim_canvas/electrosim_canvas.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/regression_fixture.dart';

void main() {
  testWidgets('P3 offers PDF and SVG export without modifying the circuit', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final circuit = buildRegressionFixtureCircuit();
    await tester.pumpWidget(
      MaterialApp(home: F9WorkspaceDemoPage(initialCircuit: circuit)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('workspace-more-actions')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('workspace-export-schematic-svg')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('workspace-export-schematic-pdf')),
      findsOneWidget,
    );
    final board = tester.widget<SimulatorCanvas>(find.byType(SimulatorCanvas));
    expect(identical(board.circuit, circuit), isTrue);
    expect(tester.takeException(), isNull);
  });
}
