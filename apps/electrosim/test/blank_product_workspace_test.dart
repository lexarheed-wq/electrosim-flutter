import 'package:electrosim/main.dart' as app;
import 'package:electrosim_canvas/electrosim_canvas.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('design wiring opens a genuinely blank product board', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const app.ElectroSimApp());
    await tester.tap(find.byKey(const Key('home-design')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('design-wiring')));
    await tester.pumpAndSettle();

    final SimulatorCanvas canvas = tester.widget<SimulatorCanvas>(
      find.byType(SimulatorCanvas),
    );
    expect(canvas.circuit.sources, isEmpty);
    expect(canvas.circuit.components, isEmpty);
    expect(canvas.circuit.connections, isEmpty);
    expect(canvas.circuit.revision, 0);
    expect(canvas.circuit.metadata['origin'], 'blank-workspace');
    expect(
      (tester.widget<Text>(find.byKey(const Key('status-circuit-count')))).data,
      contains('0 éléments · 0 sources'),
    );
    expect(find.textContaining('switch-1'), findsNothing);
    expect(find.textContaining('lamp-1'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
