import 'package:electrosim/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('F17-R4 voltmeter and ammeter show real solver readings for selected lamp',
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

    await tester.tap(find.text('Mesures'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('measurement-engine-status')), findsOneWidget);
    expect(find.byKey(const Key('measurement-target-label')), findsOneWidget);
    expect(find.byKey(const Key('measurement-voltage-reading')), findsOneWidget);
    expect(find.byKey(const Key('measurement-current-reading')), findsOneWidget);

    expect(
      (tester.widget<Text>(find.byKey(const Key('measurement-voltage-reading')))).data,
      '24.000 V',
    );
    expect(
      (tester.widget<Text>(find.byKey(const Key('measurement-current-reading')))).data,
      '1.000 A',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('F17-R4 UI does not fabricate readings when the solver cannot resolve a model',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: app.F9WorkspaceDemoPage()));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('palette-search-field')), 'diode');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('palette-item-diode')), findsOneWidget);
    await tester.tap(find.byKey(const Key('palette-item-diode')));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.byKey(const Key('palette-item-diode')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Mesures'));
    await tester.pumpAndSettle();

    expect(find.text('Mesure indisponible'), findsOneWidget);
    expect(
      (tester.widget<Text>(find.byKey(const Key('measurement-voltage-reading')))).data,
      '—',
    );
    expect(
      (tester.widget<Text>(find.byKey(const Key('measurement-current-reading')))).data,
      '—',
    );
    expect(find.byKey(const Key('measurement-error-message')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
