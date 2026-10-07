import 'package:electrosim/main.dart' as app;
import 'package:electrosim_canvas/electrosim_canvas.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void _desktop(WidgetTester tester) {
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1;
}

Future<void> _tapVisible(WidgetTester tester, Key key) async {
  final Finder finder = find.byKey(key);
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('product schema library restarts empty after CORE-UNIFY', (
    WidgetTester tester,
  ) async {
    _desktop(tester);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const app.ElectroSimApp());
    await _tapVisible(tester, const Key('home-design'));
    await _tapVisible(tester, const Key('design-schema-library'));

    expect(find.byKey(const Key('schema-library-page')), findsOneWidget);
    expect(find.text('Bibliothèque de schémas'), findsOneWidget);
    expect(
      find.text('Aucun schéma ne correspond aux filtres.'),
      findsOneWidget,
    );
    expect(find.byType(SimulatorCanvas), findsNothing);
  });

  testWidgets('product fault library restarts empty after CORE-UNIFY', (
    WidgetTester tester,
  ) async {
    _desktop(tester);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const app.ElectroSimApp());
    await _tapVisible(tester, const Key('home-maintenance'));
    await _tapVisible(tester, const Key('maintenance-fault-library'));

    expect(find.byKey(const Key('fault-library-page')), findsOneWidget);
    expect(
      find.text('Aucune panne ne correspond aux filtres.'),
      findsOneWidget,
    );
    expect(find.byType(SimulatorCanvas), findsNothing);
  });
}
