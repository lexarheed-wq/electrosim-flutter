import 'package:electrosim/main.dart' as app;
import 'package:electrosim/f9_ui_context.dart';
import 'package:electrosim_canvas/electrosim_canvas.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('home exposes exactly the three validated first-level entries', (WidgetTester tester) async {
    await tester.pumpWidget(const app.ElectroSimApp());
    expect(find.text('Créer une nouvelle session'), findsOneWidget);
    expect(find.text('Centre de maintenance'), findsOneWidget);
    expect(find.text('Centre de conception'), findsOneWidget);
  });

  testWidgets('medium home keeps first two actions on the same row', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(820, 1180);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const app.ElectroSimApp());
    final Rect first = tester.getRect(find.byKey(const Key('home-create-session')));
    final Rect second = tester.getRect(find.byKey(const Key('home-maintenance')));
    expect((first.top - second.top).abs(), lessThan(1));
  });

  testWidgets('active session opens persistent dashboard before simulator', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(820, 1180);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const app.ElectroSimApp());
    await tester.tap(find.text('Créer une nouvelle session'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('session-home-action')), findsOneWidget);
    expect(find.byKey(const Key('session-dashboard-action')), findsOneWidget);
    expect(find.byKey(const Key('session-manage-action')), findsOneWidget);
    expect(find.text('Accueil'), findsOneWidget);
    expect(find.text('Tableau de bord'), findsOneWidget);
    expect(find.text('Gérer la session'), findsOneWidget);
    expect(find.byKey(const Key('dashboard-wiring')), findsOneWidget);
    expect(find.byKey(const Key('dashboard-troubleshooting')), findsOneWidget);
    expect(find.byKey(const Key('dashboard-supervision')), findsOneWidget);
    expect(find.byType(SimulatorCanvas), findsNothing);
  });

  testWidgets('dashboard groups wiring troubleshooting and supervision', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(820, 1180);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const app.ElectroSimApp());
    await tester.tap(find.text('Créer une nouvelle session'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('session-dashboard-action')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('dashboard-wiring')), findsOneWidget);
    expect(find.byKey(const Key('dashboard-troubleshooting')), findsOneWidget);
    expect(find.byKey(const Key('dashboard-supervision')), findsOneWidget);

    await tester.tap(find.byKey(const Key('dashboard-supervision')));
    await tester.pumpAndSettle();
    expect(find.text('Supervision'), findsOneWidget);
    expect(find.text('Recherche de dérangement'), findsNothing);
  });

  testWidgets('maintenance requires explicit troubleshooting choice before simulator', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(820, 1180);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const app.ElectroSimApp());
    await tester.tap(find.text('Centre de maintenance'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('maintenance-center-page')), findsOneWidget);
    expect(find.byKey(const Key('maintenance-troubleshooting')), findsOneWidget);
    expect(find.byType(SimulatorCanvas), findsNothing);

    await tester.tap(find.byKey(const Key('maintenance-troubleshooting')));
    await tester.pumpAndSettle();

    expect(find.text('Recherche de dérangement'), findsWidgets);
    expect(find.byKey(const Key('direct-entry-status')), findsOneWidget);
    expect(find.text('Accès direct'), findsOneWidget);
    expect(find.byKey(const Key('session-dashboard-action')), findsNothing);
    expect(find.byType(SimulatorCanvas), findsOneWidget);
  });

  testWidgets('workspace keeps validated F8 Canvas interactions mounted', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: app.F9WorkspaceDemoPage()));
    expect(find.text('Câblage'), findsWidgets);
    expect(find.text('Composants'), findsOneWidget);
    expect(find.text('Propriétés'), findsWidgets);
    expect(find.byType(SimulatorCanvas), findsOneWidget);
  });

  testWidgets('compact workspace has no permanent side panels', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: app.F9WorkspaceDemoPage()));
    await tester.pumpAndSettle();
    expect(find.byType(SimulatorCanvas), findsOneWidget);
    expect(find.text('Palette'), findsOneWidget);
    expect(find.text('Propriétés'), findsWidgets);
    expect(tester.takeException(), isNull);
  });


  testWidgets('palette search and pinned show-more remain deterministic', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: app.F9WorkspaceDemoPage()));
    expect(find.byKey(const Key('palette-show-more')), findsOneWidget);
    expect(tester.getRect(find.byKey(const Key('palette-show-more'))).bottom, lessThanOrEqualTo(900));
    expect(find.text('12 composants disponibles'), findsOneWidget);

    await tester.tap(find.byKey(const Key('palette-show-more')));
    await tester.pumpAndSettle();
    expect(find.text('Voir moins de composants'), findsOneWidget);
    expect(find.text('12 composants disponibles'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('palette-search-field')), 'résistance');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('palette-item-resistor')), findsOneWidget);
    expect(find.byKey(const Key('palette-item-lamp')), findsNothing);
    expect(find.text('1 composant disponible'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('palette quick add creates a real CircuitState element and selects it', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: app.F9WorkspaceDemoPage()));
    expect(find.byKey(const Key('status-circuit-count')), findsOneWidget);
    expect((tester.widget<Text>(find.byKey(const Key('status-circuit-count')))).data, contains('3 éléments · 1 source'));

    await tester.tap(find.byKey(const Key('palette-quick-add-resistor')));
    await tester.pumpAndSettle();

    expect((tester.widget<Text>(find.byKey(const Key('status-circuit-count')))).data, contains('4 éléments · 1 source'));
    expect((tester.widget<Text>(find.byKey(const Key('status-message')))).data, contains('Ajout : Résistance'));
    expect(find.textContaining('resistor-1'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('palette allocation never collides with an existing element id', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: app.F9WorkspaceDemoPage()));
    await tester.tap(find.byKey(const Key('palette-quick-add-lamp')));
    await tester.pumpAndSettle();

    expect((tester.widget<Text>(find.byKey(const Key('status-circuit-count')))).data, contains('4 éléments · 1 source'));
    expect((tester.widget<Text>(find.byKey(const Key('status-message')))).data, contains('Ajout : Lampe'));
    expect(find.textContaining('lamp-2'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('drag from palette drops a component on the canvas', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: app.F9WorkspaceDemoPage()));
    final Finder item = find.byKey(const Key('palette-item-resistor'));
    final Finder dropRegion = find.byKey(const Key('f9-canvas-drop-region'));
    expect(item, findsOneWidget);
    expect(dropRegion, findsOneWidget);

    final Offset start = tester.getCenter(item);
    final Offset end = tester.getCenter(dropRegion);
    final TestGesture gesture = await tester.startGesture(start);
    await gesture.moveBy(const Offset(12, 0));
    await tester.pump();
    await gesture.moveTo(end, timeStamp: const Duration(milliseconds: 250));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect((tester.widget<Text>(find.byKey(const Key('status-circuit-count')))).data, contains('4 éléments · 1 source'));
    expect((tester.widget<Text>(find.byKey(const Key('status-message')))).data, contains('Ajout : Résistance'));
    expect(find.textContaining('resistor-1'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
  testWidgets('context panel exposes state control and safe deletion', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  
    await tester.pumpWidget(
      const MaterialApp(
        home: app.F9WorkspaceDemoPage(initialSelectedElementId: 'switch-1'),
      ),
    );
    await tester.pumpAndSettle();
  
    expect(find.byKey(const Key('properties-model-type')), findsOneWidget);
    expect(find.text('Interrupteur'), findsOneWidget);
    expect(find.byKey(const Key('properties-primary-toggle')), findsOneWidget);
    expect((tester.widget<Text>(find.byKey(const Key('status-circuit-count')))).data, contains('3 éléments'));
  
    await tester.tap(find.byKey(const Key('properties-primary-toggle')));
    await tester.pumpAndSettle();
    expect((tester.widget<Text>(find.byKey(const Key('status-message')))).data, contains('État modifié'));
  
    await tester.tap(find.byKey(const Key('properties-delete-element')));
    await tester.pumpAndSettle();
    expect((tester.widget<Text>(find.byKey(const Key('status-circuit-count')))).data, contains('2 éléments'));
    expect(find.text('Aucun élément sélectionné'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });


  testWidgets('diagnostic sheet exists only for student troubleshooting', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: app.F9WorkspaceDemoPage(
          initialWorkspace: 'Recherche de dérangement',
          role: F9UserRole.teacher,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('diagnostic-tab')), findsNothing);

    await tester.pumpWidget(
      const MaterialApp(
        home: app.F9WorkspaceDemoPage(
          initialWorkspace: 'Recherche de dérangement',
          role: F9UserRole.student,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('diagnostic-tab')), findsOneWidget);
    await tester.tap(find.byKey(const Key('diagnostic-tab')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('student-diagnostic-panel')), findsOneWidget);
    expect(find.byKey(const Key('diagnostic-symptom')), findsOneWidget);
  });

  testWidgets('keyboard selector provides an alternative to pointer-only selection', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: app.F9WorkspaceDemoPage()));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('properties-element-selector')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lampe · lamp-1').last);
    await tester.pumpAndSettle();
    expect(find.text('lamp-1'), findsWidgets);
    expect((tester.widget<Text>(find.byKey(const Key('status-message')))).data, contains('Sélection clavier'));
  });

  testWidgets('escape shortcut resets canvas interaction without mutating circuit revision', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: app.F9WorkspaceDemoPage()));
    await tester.pumpAndSettle();
    final String before = (tester.widget<Text>(find.byKey(const Key('status-circuit-count')))).data!;
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect((tester.widget<Text>(find.byKey(const Key('status-message')))).data, contains('annulée'));
    final String after = (tester.widget<Text>(find.byKey(const Key('status-circuit-count')))).data!;
    expect(after, before);
  });

  testWidgets('breakpoint transition does not mutate CircuitState', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: app.F9WorkspaceDemoPage()));
    await tester.pumpAndSettle();
    final String before = (tester.widget<Text>(find.byKey(const Key('status-circuit-count')))).data!;
    expect(before, contains('Révision 1'));

    tester.view.physicalSize = const Size(390, 844);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    tester.view.physicalSize = const Size(1440, 900);
    await tester.pumpAndSettle();
    final String after = (tester.widget<Text>(find.byKey(const Key('status-circuit-count')))).data!;
    expect(after, before);
  });

  testWidgets('selected component can be replaced without losing its identity', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(home: app.F9WorkspaceDemoPage(initialSelectedElementId: 'switch-1')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('properties-replace-element')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('replace-resistor')));
    await tester.pumpAndSettle();
    expect(find.text('Résistance'), findsWidgets);
    expect(find.text('switch-1'), findsWidgets);
    expect((tester.widget<Text>(find.byKey(const Key('status-message')))).data, contains('Remplacement'));
  });


  testWidgets('compact layout tolerates increased text scale without overflow', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(1.35)),
        child: const MaterialApp(home: app.F9WorkspaceDemoPage()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(SimulatorCanvas), findsOneWidget);
    expect(tester.takeException(), isNull);
  });


  testWidgets('F9 component moves immediately with pointer drag and canvas is clipped', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: app.F9WorkspaceDemoPage()));
    await tester.pumpAndSettle();

    final Finder canvas = find.byType(SimulatorCanvas);
    expect(canvas, findsOneWidget);
    expect(find.ancestor(of: canvas, matching: find.byType(ClipRect)), findsWidgets);

    final Offset canvasTopLeft = tester.getTopLeft(canvas);
    final Offset switchCenter = canvasTopLeft + const Offset(430, 260);
    final TestGesture gesture = await tester.startGesture(switchCenter);
    await gesture.moveBy(const Offset(72, 24), timeStamp: const Duration(milliseconds: 60));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect((tester.widget<Text>(find.byKey(const Key('status-message')))).data, contains('Position graphique mise à jour'));
    expect(tester.takeException(), isNull);
  });

}
