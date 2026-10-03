import 'package:electrosim/main.dart' as app;
import 'package:electrosim_canvas/electrosim_canvas.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _waitForClassroomQr(
  WidgetTester tester, {
  Duration timeout = const Duration(seconds: 3),
}) async {
  final Finder qr = find.byKey(const Key('session-waiting-qr'));
  final Stopwatch stopwatch = Stopwatch()..start();
  while (qr.evaluate().isEmpty) {
    if (stopwatch.elapsed > timeout) {
      fail('Timed out waiting for the classroom QR code.');
    }
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
  }
}

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
  testWidgets('real F18 workspace injects G2A layout engine into SimulatorCanvas',
      (WidgetTester tester) async {
    final SimulatorCanvas canvas = await _openDesignWorkspace(tester);

    expect(canvas.wireLayoutEngine, isNotNull);
    expect(canvas.wireLayoutEngine, isA<CircuitWireLayoutEngine>());
    expect(canvas.wireLayoutEngine!.router.grid, 24);
    expect(canvas.wireLayoutEngine!.router.obstacleClearance, 24);
    expect(canvas.wireLayoutEngine!.router.envelopePadding, 120);
  });

  testWidgets('real F18 workspace injects smart G2A wire preview planner',
      (WidgetTester tester) async {
    final SimulatorCanvas canvas = await _openDesignWorkspace(tester);

    expect(canvas.wirePreviewPlanner, isNotNull);
    expect(canvas.wirePreviewPlanner, isA<WirePreviewPlanner>());
    expect(canvas.wirePreviewPlanner!.terminalSnapRadius, 24);
    expect(canvas.wirePreviewPlanner!.router.grid, 24);
  });

  testWidgets('session wiring uses the same smart canvas integration',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const app.ElectroSimApp());
    await tester.tap(find.byKey(const Key('home-create-session')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('session-create-confirm')));
    await tester.pumpAndSettle();
    await _waitForClassroomQr(tester);
    await tester.tap(find.byKey(const Key('session-waiting-continue')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('dashboard-wiring')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('activity-setup-open-workshop')));
    await tester.pumpAndSettle();

    final SimulatorCanvas canvas =
        tester.widget<SimulatorCanvas>(find.byType(SimulatorCanvas));
    expect(canvas.wireLayoutEngine, isNotNull);
    expect(canvas.wirePreviewPlanner, isNotNull);
  });
}
