import 'package:electrosim/main.dart' as app;
import 'package:electrosim/f9_ui_context.dart';
import 'package:electrosim_canvas/electrosim_canvas.dart';
import 'package:electrosim_domain/electrosim_domain.dart';
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
    expect(find.byTooltip('Accueil'), findsOneWidget);
    expect(find.byTooltip('Tableau de bord'), findsOneWidget);
    expect(find.byTooltip('Gérer la session'), findsOneWidget);
    expect(find.text('Tableau de bord'), findsOneWidget);
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
    expect(find.byKey(const Key('session-supervision-page')), findsOneWidget);
    expect(find.text('Supervision'), findsWidgets);
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
    expect(find.byKey(const Key('session-dashboard-action')), findsNothing);
    expect(find.byType(SimulatorCanvas), findsOneWidget);
    expect(find.byKey(const Key('f18-canvas-drop-region')), findsOneWidget);
  });

  testWidgets('workspace keeps validated F8 Canvas interactions mounted', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: app.F9WorkspaceDemoPage()));
    expect(find.text('Câblage'), findsWidgets);
    expect(find.text('COMPOSANTS'), findsOneWidget);
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
    expect(find.text('Palette'), findsNothing);
    expect(find.text('Propriétés'), findsNothing);
    expect(find.byKey(const Key('f18-canvas-drop-region')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });


  testWidgets('palette search and one-way show-all remain deterministic', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: app.F9WorkspaceDemoPage()));
    expect(find.byKey(const Key('palette-show-all')), findsOneWidget);
    expect(
      tester.getRect(find.byKey(const Key('palette-show-all'))).bottom,
      lessThanOrEqualTo(900),
    );
    expect(find.text('Voir tous'), findsOneWidget);

    await tester.tap(find.byKey(const Key('palette-show-all')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('palette-show-all')), findsNothing);
    expect(find.textContaining('Voir moins'), findsNothing);
    expect(find.byKey(const Key('palette-item-resistor')), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('palette-search-field')),
      'résistance',
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('palette-item-resistor')), findsOneWidget);
    expect(find.byKey(const Key('palette-item-lamp')), findsNothing);
    expect(find.byKey(const Key('palette-item-resistor')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('palette quick add creates a real CircuitState element and selects it', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: app.F9WorkspaceDemoPage()));
    SimulatorCanvas canvas =
        tester.widget<SimulatorCanvas>(find.byType(SimulatorCanvas));
    expect(canvas.circuit.components.length + canvas.circuit.sources.length, 4);

    await tester.enterText(
      find.byKey(const Key('palette-search-field')),
      'résistance',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('palette-item-resistor')));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.byKey(const Key('palette-item-resistor')));
    await tester.pumpAndSettle();

    canvas = tester.widget<SimulatorCanvas>(find.byType(SimulatorCanvas));
    expect(canvas.circuit.components.length + canvas.circuit.sources.length, 5);
    expect(
      canvas.circuit.components
          .where((ComponentInstance item) => item.id.value == 'resistor-1'),
      hasLength(1),
    );
    expect(find.textContaining('resistor-1'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('palette allocation never collides with an existing element id', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: app.F9WorkspaceDemoPage()));
    await tester.tap(find.byKey(const Key('palette-item-lamp')));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.byKey(const Key('palette-item-lamp')));
    await tester.pumpAndSettle();

    final SimulatorCanvas canvas =
        tester.widget<SimulatorCanvas>(find.byType(SimulatorCanvas));
    expect(canvas.circuit.components.length + canvas.circuit.sources.length, 5);
    expect(
      canvas.circuit.components
          .where((ComponentInstance item) => item.id.value == 'lamp-2'),
      hasLength(1),
    );
    expect(find.textContaining('lamp-2'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('drag from palette drops a component on the canvas', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: app.F9WorkspaceDemoPage()));
    await tester.enterText(
      find.byKey(const Key('palette-search-field')),
      'résistance',
    );
    await tester.pumpAndSettle();
    final Finder item = find.byKey(const Key('palette-item-resistor'));
    final Finder dropRegion = find.byKey(const Key('f18-canvas-drop-region'));
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

    final SimulatorCanvas dropped =
        tester.widget<SimulatorCanvas>(find.byType(SimulatorCanvas));
    expect(dropped.circuit.components.length + dropped.circuit.sources.length, 5);
    expect(
      dropped.circuit.components
          .where((ComponentInstance item) => item.id.value == 'resistor-1'),
      hasLength(1),
    );
    expect(find.textContaining('resistor-1'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
  testWidgets('state control remains in properties and deletion is owned by topbar', (WidgetTester tester) async {
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
    expect(
      (tester.widget<Text>(
        find.byKey(const Key('properties-model-type')),
      )).data,
      'Interrupteur',
    );
    expect(find.byKey(const Key('properties-primary-toggle')), findsOneWidget);
    SimulatorCanvas canvas =
        tester.widget<SimulatorCanvas>(find.byType(SimulatorCanvas));
    expect(canvas.circuit.components.length + canvas.circuit.sources.length, 4);
  
    await tester.tap(find.byKey(const Key('properties-primary-toggle')));
    await tester.pumpAndSettle();
    expect(
      (tester.widget<Text>(
        find.byKey(const Key('context-status-message')),
      )).data,
      contains('État modifié'),
    );
  
    await tester.tap(find.byKey(const Key('workspace-delete-action')));
    await tester.pumpAndSettle();
    canvas = tester.widget<SimulatorCanvas>(find.byType(SimulatorCanvas));
    expect(canvas.circuit.components.length + canvas.circuit.sources.length, 3);
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
    expect(
      (tester.widget<Text>(
        find.byKey(const Key('context-status-message')),
      )).data,
      contains('Sélection clavier'),
    );
  });

  testWidgets('escape shortcut resets canvas interaction without mutating circuit revision', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: app.F9WorkspaceDemoPage()));
    await tester.pumpAndSettle();
    final SimulatorCanvas before =
        tester.widget<SimulatorCanvas>(find.byType(SimulatorCanvas));
    final int beforeRevision = before.circuit.revision;
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(
      (tester.widget<Text>(
        find.byKey(const Key('context-status-message')),
      )).data,
      contains('annulée'),
    );
    final SimulatorCanvas after =
        tester.widget<SimulatorCanvas>(find.byType(SimulatorCanvas));
    expect(after.circuit.revision, beforeRevision);
  });

  testWidgets('breakpoint transition does not mutate CircuitState', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: app.F9WorkspaceDemoPage()));
    await tester.pumpAndSettle();
    final SimulatorCanvas before =
        tester.widget<SimulatorCanvas>(find.byType(SimulatorCanvas));
    expect(before.circuit.revision, 1);

    tester.view.physicalSize = const Size(390, 844);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    tester.view.physicalSize = const Size(1440, 900);
    await tester.pumpAndSettle();
    final SimulatorCanvas after =
        tester.widget<SimulatorCanvas>(find.byType(SimulatorCanvas));
    expect(after.circuit.revision, before.circuit.revision);
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
    expect(
      (tester.widget<Text>(
        find.byKey(const Key('context-status-message')),
      )).data,
      contains('Remplacement'),
    );
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

    final SimulatorCanvas canvasWidget = tester.widget<SimulatorCanvas>(canvas);
    final Offset canvasTopLeft = tester.getTopLeft(canvas);
    final Offset switchWorld = canvasWidget.layout.positionOf('switch-1')!;
    final Offset switchLocal =
        canvasWidget.viewportController!.worldToScreen(switchWorld);
    final Offset switchCenter = canvasTopLeft + switchLocal;
    final TestGesture gesture = await tester.startGesture(switchCenter);
    await gesture.moveBy(const Offset(72, 24), timeStamp: const Duration(milliseconds: 60));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(
      (tester.widget<Text>(
        find.byKey(const Key('context-status-message')),
      )).data,
      contains('Position graphique mise à jour'),
    );
    expect(tester.takeException(), isNull);
  });

}
