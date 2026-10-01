import 'package:electrosim/main.dart' as app;
import 'package:electrosim_canvas/electrosim_canvas.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void _desktop(WidgetTester tester) {
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1;
}

void main() {
  setUp(() {});

  testWidgets('home routes to real maintenance center before simulator', (WidgetTester tester) async {
    _desktop(tester);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const app.ElectroSimApp());
    await tester.tap(find.byKey(const Key('home-maintenance')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('maintenance-center-page')), findsOneWidget);
    expect(find.byKey(const Key('maintenance-troubleshooting')), findsOneWidget);
    expect(find.byKey(const Key('maintenance-fault-library')), findsOneWidget);
    expect(find.byType(SimulatorCanvas), findsNothing);
  });

  testWidgets('home routes to real design center before simulator', (WidgetTester tester) async {
    _desktop(tester);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const app.ElectroSimApp());
    await tester.tap(find.byKey(const Key('home-design')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('design-center-page')), findsOneWidget);
    expect(find.byKey(const Key('design-wiring')), findsOneWidget);
    expect(find.byKey(const Key('design-schema-library')), findsOneWidget);
    expect(find.byType(SimulatorCanvas), findsNothing);
  });

  testWidgets('session creation opens dashboard shell rather than simulator', (WidgetTester tester) async {
    _desktop(tester);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const app.ElectroSimApp());
    await tester.tap(find.byKey(const Key('home-create-session')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('session-shell-page')), findsOneWidget);
    expect(find.byKey(const Key('session-home-action')), findsOneWidget);
    expect(find.byKey(const Key('session-dashboard-action')), findsOneWidget);
    expect(find.byKey(const Key('session-manage-action')), findsOneWidget);
    expect(find.byKey(const Key('dashboard-wiring')), findsOneWidget);
    expect(find.byKey(const Key('dashboard-troubleshooting')), findsOneWidget);
    expect(find.byKey(const Key('dashboard-supervision')), findsOneWidget);
    expect(find.byType(SimulatorCanvas), findsNothing);
  });

  testWidgets('design wiring is the explicit transition into simulator', (WidgetTester tester) async {
    _desktop(tester);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const app.ElectroSimApp());
    await tester.tap(find.byKey(const Key('home-design')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('design-wiring')));
    await tester.pumpAndSettle();

    expect(find.byType(SimulatorCanvas), findsOneWidget);
    expect(find.text('Câblage'), findsWidgets);
  });

  testWidgets('maintenance troubleshooting explicitly opens troubleshooting workspace', (WidgetTester tester) async {
    _desktop(tester);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const app.ElectroSimApp());
    await tester.tap(find.byKey(const Key('home-maintenance')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('maintenance-troubleshooting')));
    await tester.pumpAndSettle();

    expect(find.byType(SimulatorCanvas), findsOneWidget);
    expect(find.text('Recherche de dérangement'), findsWidgets);
  });

  testWidgets('session dashboard wiring explicitly opens session simulator', (WidgetTester tester) async {
    _desktop(tester);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const app.ElectroSimApp());
    await tester.tap(find.byKey(const Key('home-create-session')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('dashboard-wiring')));
    await tester.pumpAndSettle();

    expect(find.byType(SimulatorCanvas), findsOneWidget);
    expect(find.byKey(const Key('session-home-action')), findsOneWidget);
    expect(find.byKey(const Key('session-dashboard-action')), findsOneWidget);
    expect(find.byKey(const Key('session-manage-action')), findsOneWidget);
  });

  testWidgets('center shells tolerate compact viewport without overflow', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const app.ElectroSimApp());
    final Finder design = find.byKey(const Key('home-design'));
    await tester.ensureVisible(design);
    await tester.pumpAndSettle();
    await tester.tap(design);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('design-center-page')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
