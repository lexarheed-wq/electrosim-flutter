import 'package:electrosim/main.dart' as app;
import 'package:electrosim_canvas/electrosim_canvas.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void _desktop(WidgetTester tester) {
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1;
  testWidgets('desktop home keeps the three primary cards aligned in one row', (WidgetTester tester) async {
    _desktop(tester);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const app.ElectroSimApp());
    await tester.pumpAndSettle();

    final Rect session = tester.getRect(find.byKey(const Key('home-create-session')));
    final Rect maintenance = tester.getRect(find.byKey(const Key('home-maintenance')));
    final Rect design = tester.getRect(find.byKey(const Key('home-design')));
    expect((session.top - maintenance.top).abs(), lessThan(1));
    expect((maintenance.top - design.top).abs(), lessThan(1));
    expect(session.left, lessThan(maintenance.left));
    expect(maintenance.left, lessThan(design.left));

    final Rect join = tester.getRect(find.byKey(const Key('home-join-panel')));
    expect(join.top, greaterThan(session.bottom));
    expect(join.top, greaterThan(maintenance.bottom));
    expect(join.top, greaterThan(design.bottom));
    expect(tester.takeException(), isNull);
  });

  testWidgets('medium home keeps two-column hierarchy and secondary join panel below', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(820, 1180);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const app.ElectroSimApp());
    await tester.pumpAndSettle();

    final Rect session = tester.getRect(find.byKey(const Key('home-create-session')));
    final Rect maintenance = tester.getRect(find.byKey(const Key('home-maintenance')));
    final Rect design = tester.getRect(find.byKey(const Key('home-design')));
    expect((session.top - maintenance.top).abs(), lessThan(1));
    expect(design.top, greaterThan(session.bottom));
    expect(find.byKey(const Key('home-join-panel')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('compact home scrolls all primary and secondary actions without overflow', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const app.ElectroSimApp());
    await tester.pumpAndSettle();

    for (final Key key in const <Key>[
      Key('home-create-session'),
      Key('home-maintenance'),
      Key('home-design'),
      Key('home-join-panel'),
    ]) {
      final Finder finder = find.byKey(key);
      await tester.ensureVisible(finder);
      await tester.pumpAndSettle();
      expect(finder, findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });
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

  testWidgets('session shell tolerates compact viewport without overflow', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const app.ElectroSimApp());
    final Finder createSession = find.byKey(const Key('home-create-session'));
    await tester.ensureVisible(createSession);
    await tester.tap(createSession);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('session-shell-page')), findsOneWidget);
    expect(find.byKey(const Key('session-home-action')), findsOneWidget);
    expect(find.byKey(const Key('session-dashboard-action')), findsOneWidget);
    expect(find.byKey(const Key('session-manage-action')), findsOneWidget);
    expect(tester.takeException(), isNull);
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
