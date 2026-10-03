import 'package:electrosim/main.dart' as app;
import 'package:electrosim_canvas/electrosim_canvas.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<SimulatorCanvas> _openDcWorkspace(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(const app.ElectroSimApp());
  await tester.tap(find.byKey(const Key('home-design')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('design-wiring')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('activity-setup-open-workshop')));
  await tester.pumpAndSettle();
  return tester.widget<SimulatorCanvas>(find.byType(SimulatorCanvas));
}

void main() {
  testWidgets('default DC workspace uses visible rectangular arrangement',
      (WidgetTester tester) async {
    final SimulatorCanvas canvas = await _openDcWorkspace(tester);
    final CircuitVisualLayout layout = canvas.layout;

    final Offset source = layout.positionOf('source-24v')!;
    final Offset load = layout.positionOf('lamp-1')!;
    final Offset series = layout.positionOf('switch-1')!;

    expect(source.dx, lessThan(load.dx));
    expect(source.dy, load.dy);
    expect(series.dy, lessThan(source.dy));

    final double branchMidpointX = (source.dx + load.dx) / 2;
    expect((series.dx - branchMidpointX).abs(), lessThanOrEqualTo(0.01));
  });

  testWidgets('DC series component stays far from both rectangular corners',
      (WidgetTester tester) async {
    final SimulatorCanvas canvas = await _openDcWorkspace(tester);
    final CircuitVisualLayout layout = canvas.layout;

    final Offset source = layout.positionOf('source-24v')!;
    final Offset load = layout.positionOf('lamp-1')!;
    final Offset series = layout.positionOf('switch-1')!;
    final Size seriesSize = layout.sizeOf('switch-1');

    const double bendKeepOut = 48;
    const double minimumTerminalStub = 24;
    final double required = bendKeepOut + minimumTerminalStub + seriesSize.width / 2;

    expect(series.dx - source.dx, greaterThanOrEqualTo(required));
    expect(load.dx - series.dx, greaterThanOrEqualTo(required));
  });

  testWidgets('committed DC routes remain orthogonal after rectangular arrange',
      (WidgetTester tester) async {
    final SimulatorCanvas canvas = await _openDcWorkspace(tester);
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
          reason: '${connection.id.value} contains a diagonal segment',
        );
      }
    }
  });
}
