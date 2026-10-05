import 'package:electrosim/main.dart' as app;
import 'package:electrosim_ui_kit/electrosim_ui_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _openPalette(WidgetTester tester) async {
  final Finder region = find.byKey(electroSimPaletteRegionKey);
  if (region.evaluate().isEmpty || tester.getRect(region).right <= 0) {
    await tester.tap(find.byKey(electroSimPaletteEdgeKey));
    await tester.pumpAndSettle();
  }
}

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
    'F17-R4 voltmeter and ammeter show real solver readings for selected lamp',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: app.F9WorkspaceDemoPage(initialSelectedElementId: 'lamp-1'),
        ),
      );
      await tester.pumpAndSettle();
      await _openContext(tester);

      await tester.tap(find.text('Mesures'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('measurement-engine-status')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('measurement-target-label')), findsOneWidget);
      expect(
        find.byKey(const Key('measurement-voltage-reading')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('measurement-current-reading')),
        findsOneWidget,
      );

      expect(
        (tester.widget<Text>(
          find.byKey(const Key('measurement-voltage-reading')),
        )).data,
        '24.000 V',
      );
      expect(
        (tester.widget<Text>(
          find.byKey(const Key('measurement-current-reading')),
        )).data,
        '1.000 A',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'F17-R4 UI does not fabricate readings when the solver cannot resolve a model',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(home: app.F9WorkspaceDemoPage()),
      );
      await tester.pumpAndSettle();
      await _openPalette(tester);

      await tester.enterText(
        find.byKey(const Key('palette-search-field')),
        'diode',
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('palette-quick-add-diode')), findsOneWidget);
      await tester.tap(find.byKey(const Key('palette-quick-add-diode')));
      await tester.pumpAndSettle();
      await _openContext(tester);

      await tester.tap(find.text('Mesures'));
      await tester.pumpAndSettle();

      expect(find.text('Mesure indisponible'), findsOneWidget);
      expect(
        (tester.widget<Text>(
          find.byKey(const Key('measurement-voltage-reading')),
        )).data,
        '—',
      );
      expect(
        (tester.widget<Text>(
          find.byKey(const Key('measurement-current-reading')),
        )).data,
        '—',
      );
      expect(
        find.byKey(const Key('measurement-error-message')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
