import 'package:electrosim/main.dart' as app;
import 'package:electrosim_ui_kit/electrosim_ui_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/regression_fixture.dart';

Future<void> _openContext(WidgetTester tester) async {
  final Finder region = find.byKey(electroSimContextRegionKey);
  final double width =
      tester.view.physicalSize.width / tester.view.devicePixelRatio;
  if (region.evaluate().isEmpty || tester.getRect(region).left >= width) {
    await tester.tap(find.byKey(electroSimContextEdgeKey));
    await tester.pumpAndSettle();
  }
}

void main() {
  testWidgets(
    'F17-R5 healthy runtime keeps EIE neutral without speculative advice',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: app.F9WorkspaceDemoPage(
            initialCircuit: buildRegressionFixtureCircuit(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _openContext(tester);

      await tester.tap(find.text('EIE'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('eie-engine-status')), findsOneWidget);
      expect(find.text('Aucune anomalie étayée'), findsOneWidget);
      expect(find.byKey(const Key('eie-no-advice')), findsOneWidget);
      expect(find.text('Branche ouverte observée'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Post-M13 normally open switching device does not create false EIE anomaly',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: app.F9WorkspaceDemoPage(
            initialCircuit: buildRegressionFixtureCircuit(),
            initialSelectedElementId: 'switch-1',
          ),
        ),
      );
      await tester.pumpAndSettle();

      final Finder switchVisual = find.byKey(
        const ValueKey<String>('board-v1-visual-switch-1'),
      );
      final Offset rocker = tester.getRect(switchVisual).center;
      await tester.tapAt(rocker);
      await tester.pump(const Duration(milliseconds: 80));
      await tester.tapAt(rocker);
      await tester.pump(const Duration(milliseconds: 30));

      await _openContext(tester);
      await tester.tap(find.text('EIE'));
      await tester.pumpAndSettle();

      expect(find.text('Aucune anomalie étayée'), findsOneWidget);
      expect(find.byKey(const Key('eie-no-advice')), findsOneWidget);
      expect(find.byKey(const Key('eie-advice-openBranch')), findsNothing);
      expect(find.text('Branche ouverte observée'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
