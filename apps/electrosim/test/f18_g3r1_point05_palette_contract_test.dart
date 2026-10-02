import 'package:electrosim/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('F18 palette exposes exactly five quick components',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: app.F9WorkspaceDemoPage()));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('palette-item-source-dc-24v')), findsOneWidget);
    expect(find.byKey(const Key('palette-item-switch-no')), findsOneWidget);
    expect(find.byKey(const Key('palette-item-lamp')), findsOneWidget);
    expect(find.byKey(const Key('palette-item-resistor')), findsOneWidget);
    expect(find.byKey(const Key('palette-item-breaker')), findsOneWidget);
    expect(find.byKey(const Key('palette-item-push-button-no')), findsNothing);
    expect(find.byKey(const Key('palette-show-all')), findsOneWidget);
    expect(find.text('Voir tous les composants'), findsOneWidget);
  });

  testWidgets('Voir tous expands once and never becomes a Voir moins toggle',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: app.F9WorkspaceDemoPage()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('palette-show-all')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('palette-show-all')), findsNothing);
    expect(find.textContaining('Voir moins'), findsNothing);

    final Finder list = find.byKey(const Key('palette-results-list'));
    final Finder target =
        find.byKey(const Key('palette-item-push-button-no'));
    for (var attempt = 0; attempt < 8 && target.evaluate().isEmpty; attempt++) {
      await tester.drag(list, const Offset(0, -220));
      await tester.pumpAndSettle();
    }
    expect(target, findsOneWidget);
  });

  testWidgets('search exposes non-quick component without requiring Voir tous',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: app.F9WorkspaceDemoPage()));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('palette-search-field')),
      'Moteur',
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('palette-item-motor-dc')), findsOneWidget);
    expect(find.byKey(const Key('palette-show-all')), findsNothing);
  });
}
