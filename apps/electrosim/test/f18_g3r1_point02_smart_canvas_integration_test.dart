import 'package:electrosim/main.dart' as app;
import 'package:electrosim_canvas/electrosim_canvas.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<SimulatorCanvas> _openDesignWorkspace(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(const app.ElectroSimApp());
  await tester.tap(find.byKey(const Key('home-design')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('design-wiring')));
  await tester.pumpAndSettle();

  return tester.widget<SimulatorCanvas>(find.byType(SimulatorCanvas));
}

void main() {
  testWidgets('real workspace keeps G2A routing outside the hot paint path', (
    WidgetTester tester,
  ) async {
    final SimulatorCanvas canvas = await _openDesignWorkspace(tester);

    expect(canvas.wireLayoutEngine, isNull);
    expect(canvas.smartWireSemantics, isTrue);
    expect(canvas.wirePreviewPlanner, isNotNull);
    expect(canvas.wirePreviewPlanner, isA<WirePreviewPlanner>());
    expect(canvas.wirePreviewPlanner!.router.grid, 24);
    expect(canvas.wirePreviewPlanner!.router.obstacleClearance, 24);
    expect(canvas.wirePreviewPlanner!.router.envelopePadding, 120);
  });
}
