import 'package:electrosim_canvas/electrosim_canvas.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_fixture.dart';

Widget _goldenHost(Size size) => MaterialApp(
  debugShowCheckedModeBanner: false,
  home: Scaffold(
    body: SizedBox(
      width: size.width,
      height: size.height,
      child: RepaintBoundary(
        key: const ValueKey<String>('canvas-golden'),
        child: SimulatorCanvas(
          circuit: buildTestCircuit(),
          layout: buildTestLayout(),
          viewportController: ViewportController(
            scale: size.width < 500 ? 0.8 : 1,
            translation: const Offset(28, 36),
          ),
          enableInteraction: false,
        ),
      ),
    ),
  ),
);

Future<void> _expectGolden(
  WidgetTester tester,
  Size size,
  String fileName,
) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(_goldenHost(size));
  await tester.pumpAndSettle();
  expect(find.byType(SimulatorCanvas), findsOneWidget);
  await expectLater(
    find.byKey(const ValueKey<String>('canvas-golden')),
    matchesGoldenFile('goldens/$fileName'),
  );
}

void main() {
  testWidgets('compact canvas golden', (WidgetTester tester) async {
    await _expectGolden(tester, const Size(390, 700), 'canvas_compact.png');
  });

  testWidgets('medium canvas golden', (WidgetTester tester) async {
    await _expectGolden(tester, const Size(800, 900), 'canvas_medium.png');
  });

  testWidgets('expanded canvas golden', (WidgetTester tester) async {
    await _expectGolden(tester, const Size(1280, 800), 'canvas_expanded.png');
  });
}
