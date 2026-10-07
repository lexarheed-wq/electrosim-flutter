import 'package:electrosim/main.dart' as app;
import 'package:electrosim/f9_component_palette.dart';
import 'package:electrosim/f9_ui_context.dart';
import 'package:electrosim_canvas/electrosim_canvas.dart';
import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:electrosim_ui_kit/electrosim_ui_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/regression_fixture.dart';

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

Future<void> _openTop(WidgetTester tester) async {
  final Finder region = find.byKey(electroSimTopRegionKey);
  if (region.evaluate().isEmpty || tester.getRect(region).bottom <= 0) {
    await tester.tap(find.byKey(electroSimTopEdgeKey));
    await tester.pumpAndSettle();
  }
}

Future<void> _waitForSessionReady(
  WidgetTester tester, {
  Duration timeout = const Duration(seconds: 3),
}) async {
  final Finder qr = find.byKey(const Key('session-waiting-qr'));
  final Stopwatch stopwatch = Stopwatch()..start();
  while (qr.evaluate().isEmpty) {
    if (stopwatch.elapsed > timeout) {
      fail('Timed out waiting for the classroom QR code.');
    }
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
  }
  expect(find.byKey(const Key('session-waiting-browser-url')), findsOneWidget);
}

void main() {
  testWidgets('home exposes exactly the three validated first-level entries', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const app.ElectroSimApp());
    expect(find.text('Créer une nouvelle session'), findsOneWidget);
    expect(find.text('Centre de maintenance'), findsOneWidget);
    expect(find.text('Centre de conception'), findsOneWidget);
  });

  testWidgets('medium home keeps first two actions on the same row', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(820, 1180);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const app.ElectroSimApp());
    final Rect first = tester.getRect(
      find.byKey(const Key('home-create-session')),
    );
    final Rect second = tester.getRect(
      find.byKey(const Key('home-maintenance')),
    );
    expect((first.top - second.top).abs(), lessThan(1));
  });

  testWidgets('active session opens persistent dashboard before simulator', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(820, 1180);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const app.ElectroSimApp());
    await tester.tap(find.text('Créer une nouvelle session'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('session-create-dialog')), findsOneWidget);
    await tester.tap(find.byKey(const Key('session-create-confirm')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('session-waiting-room-page')), findsOneWidget);
    await _waitForSessionReady(tester);
    await tester.tap(find.byKey(const Key('session-waiting-continue')));
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

  testWidgets('dashboard groups wiring troubleshooting and supervision', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(820, 1180);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const app.ElectroSimApp());
    await tester.tap(find.text('Créer une nouvelle session'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('session-create-confirm')));
    await tester.pumpAndSettle();
    await _waitForSessionReady(tester);
    await tester.tap(find.byKey(const Key('session-waiting-continue')));
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

  testWidgets(
    'maintenance requires explicit troubleshooting choice before simulator',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(820, 1180);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const app.ElectroSimApp());
      await tester.tap(find.text('Centre de maintenance'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('maintenance-center-page')), findsOneWidget);
      expect(
        find.byKey(const Key('maintenance-troubleshooting')),
        findsOneWidget,
      );
      expect(find.byType(SimulatorCanvas), findsNothing);

      await tester.tap(find.byKey(const Key('maintenance-troubleshooting')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('maintenance-troubleshooting-setup-page')),
        findsOneWidget,
      );
      expect(find.byType(SimulatorCanvas), findsNothing);
      await tester.tap(find.byKey(const Key('activity-setup-open-workshop')));
      await tester.pumpAndSettle();

      expect(find.text('Recherche de dérangement'), findsWidgets);
      expect(find.byKey(const Key('session-dashboard-action')), findsNothing);
      expect(find.byKey(const Key('workspace-exit-action')), findsOneWidget);
      expect(find.byType(SimulatorCanvas), findsOneWidget);
    },
  );

  testWidgets('workspace keeps validated F8 Canvas interactions mounted', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(home: app.F9WorkspaceDemoPage(
          initialCircuit: buildRegressionFixtureCircuit(),
        )));
    expect(find.text('Câblage'), findsWidgets);
    expect(find.text('Composants'), findsOneWidget);
    expect(find.text('Propriétés'), findsWidgets);
    expect(find.byType(SimulatorCanvas), findsOneWidget);
  });

  testWidgets('compact workspace has no permanent side panels', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(home: app.F9WorkspaceDemoPage(
          initialCircuit: buildRegressionFixtureCircuit(),
        )));
    await tester.pumpAndSettle();
    expect(find.byType(SimulatorCanvas), findsOneWidget);
    expect(find.byKey(electroSimPaletteEdgeKey), findsOneWidget);
    expect(find.byKey(electroSimContextEdgeKey), findsOneWidget);
    expect(find.byKey(electroSimTopEdgeKey), findsOneWidget);
    expect(find.byKey(electroSimStatusEdgeKey), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('palette search and one-way show-all remain deterministic', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(home: app.F9WorkspaceDemoPage(
          initialCircuit: buildRegressionFixtureCircuit(),
        )));
    await _openPalette(tester);
    expect(find.byKey(const Key('palette-show-all')), findsOneWidget);
    expect(
      tester.getRect(find.byKey(const Key('palette-show-all'))).bottom,
      lessThanOrEqualTo(900),
    );
    expect(find.text('Voir tous les composants'), findsOneWidget);
    final int dcCatalogCount = f9PaletteCatalog
        .where(
          (F9PaletteDefinition item) => item.supportsMode(ElectricalMode.dc),
        )
        .length;
    expect(
      find.text('$dcCatalogCount composants disponibles · DC'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('palette-show-all')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('palette-show-all')), findsNothing);
    expect(find.textContaining('Voir moins'), findsNothing);
    expect(
      find.text('$dcCatalogCount composants disponibles · DC'),
      findsOneWidget,
    );

    await tester.enterText(
      find.byKey(const Key('palette-search-field')),
      'résistance',
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('palette-item-resistor')), findsOneWidget);
    expect(find.byKey(const Key('palette-item-lamp')), findsNothing);
    expect(find.text('1 composant disponible · DC'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'palette quick add creates a real CircuitState element and selects it',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(home: app.F9WorkspaceDemoPage(
          initialCircuit: buildRegressionFixtureCircuit(),
        )),
      );
      await _openPalette(tester);
      expect(find.byKey(const Key('status-circuit-count')), findsOneWidget);
      expect(
        (tester.widget<Text>(
          find.byKey(const Key('status-circuit-count')),
        )).data,
        contains('3 éléments · 1 source'),
      );

      await tester.tap(find.byKey(const Key('palette-quick-add-resistor')));
      await tester.pumpAndSettle();

      expect(
        (tester.widget<Text>(
          find.byKey(const Key('status-circuit-count')),
        )).data,
        contains('4 éléments · 1 source'),
      );
      expect(
        (tester.widget<Text>(find.byKey(const Key('status-message')))).data,
        contains('Ajout : Résistance'),
      );
      expect(find.textContaining('resistor-1'), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('palette allocation never collides with an existing element id', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(home: app.F9WorkspaceDemoPage(
          initialCircuit: buildRegressionFixtureCircuit(),
        )));
    await _openPalette(tester);
    await tester.tap(find.byKey(const Key('palette-quick-add-lamp')));
    await tester.pumpAndSettle();

    expect(
      (tester.widget<Text>(find.byKey(const Key('status-circuit-count')))).data,
      contains('4 éléments · 1 source'),
    );
    expect(
      (tester.widget<Text>(find.byKey(const Key('status-message')))).data,
      contains('Ajout : Lampe'),
    );
    expect(find.textContaining('lamp-2'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('drag from palette drops a component on the canvas', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(home: app.F9WorkspaceDemoPage(
          initialCircuit: buildRegressionFixtureCircuit(),
        )));
    await _openPalette(tester);
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

    expect(
      (tester.widget<Text>(find.byKey(const Key('status-circuit-count')))).data,
      contains('4 éléments · 1 source'),
    );
    expect(
      (tester.widget<Text>(find.byKey(const Key('status-message')))).data,
      contains('Ajout : Résistance'),
    );
    expect(find.textContaining('resistor-1'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'switch actuates only from a double-click on its physical rocker',
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

      SimulatorCanvas canvas = tester.widget<SimulatorCanvas>(
        find.byType(SimulatorCanvas),
      );
      ComponentInstance switchComponent = canvas.circuit.components.firstWhere(
        (ComponentInstance item) => item.id.value == 'switch-1',
      );
      expect(switchComponent.controlState['closed'], isTrue);

      final Finder visual = find.byKey(
        const ValueKey<String>('board-v1-visual-switch-1'),
      );
      expect(visual, findsOneWidget);
      final Rect rect = tester.getRect(visual);

      // Carcass double-click: selected but not actuated.
      final Offset carcass = Offset(
        rect.left + rect.width * .08,
        rect.top + rect.height * .08,
      );
      await tester.tapAt(carcass);
      await tester.pump(const Duration(milliseconds: 80));
      await tester.tapAt(carcass);
      await tester.pump(const Duration(milliseconds: 30));

      canvas = tester.widget<SimulatorCanvas>(find.byType(SimulatorCanvas));
      switchComponent = canvas.circuit.components.firstWhere(
        (ComponentInstance item) => item.id.value == 'switch-1',
      );
      expect(switchComponent.controlState['closed'], isTrue);

      // Rocker double-click: real actuation.
      final Offset rocker = rect.center;
      await tester.tapAt(rocker);
      await tester.pump(const Duration(milliseconds: 80));
      await tester.tapAt(rocker);
      await tester.pump(const Duration(milliseconds: 30));

      canvas = tester.widget<SimulatorCanvas>(find.byType(SimulatorCanvas));
      switchComponent = canvas.circuit.components.firstWhere(
        (ComponentInstance item) => item.id.value == 'switch-1',
      );
      expect(switchComponent.controlState['closed'], isFalse);
      expect(
        (tester.widget<Text>(find.byKey(const Key('status-message')))).data,
        contains('Commande directe : switch-1 — ouvert'),
      );

      await _openContext(tester);
      expect(find.byKey(const Key('properties-primary-toggle')), findsNothing);
      expect(
        find.byKey(const Key('properties-direct-control-hint')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'push button double-click produces a momentary press and release',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: app.F9WorkspaceDemoPage(
            initialCircuit: _seriesControlCircuit(
              modelType: 'push_button_no',
              elementId: 'push-1',
              controlState: const <String, Object?>{'pressed': false},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final Finder visual = find.byKey(
        const ValueKey<String>('board-v1-visual-push-1'),
      );
      final Rect rect = tester.getRect(visual);
      final Offset head = Offset(
        rect.left + rect.width * .5,
        rect.top + rect.height * (58 / 140),
      );

      await tester.tapAt(head);
      await tester.pump(const Duration(milliseconds: 80));
      await tester.tapAt(head);
      await tester.pump(const Duration(milliseconds: 20));

      SimulatorCanvas canvas = tester.widget<SimulatorCanvas>(
        find.byType(SimulatorCanvas),
      );
      ComponentInstance button = canvas.circuit.components.firstWhere(
        (ComponentInstance item) => item.id.value == 'push-1',
      );
      expect(button.controlState['pressed'], isTrue);

      await tester.pump(const Duration(milliseconds: 300));
      canvas = tester.widget<SimulatorCanvas>(find.byType(SimulatorCanvas));
      button = canvas.circuit.components.firstWhere(
        (ComponentInstance item) => item.id.value == 'push-1',
      );
      expect(button.controlState['pressed'], isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('breaker handle double-click opens and recloses the breaker', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: app.F9WorkspaceDemoPage(
          initialCircuit: _seriesControlCircuit(
            modelType: 'breaker_dc',
            elementId: 'breaker-1',
            controlState: const <String, Object?>{
              'closed': true,
              'tripped': false,
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final Finder visual = find.byKey(
      const ValueKey<String>('board-v1-visual-breaker-1'),
    );
    final Rect rect = tester.getRect(visual);
    final Offset handle = Offset(
      rect.left + rect.width * .5,
      rect.top + rect.height * .52,
    );

    Future<void> doubleClickHandle() async {
      await tester.tapAt(handle);
      await tester.pump(const Duration(milliseconds: 80));
      await tester.tapAt(handle);
      await tester.pump(const Duration(milliseconds: 30));
    }

    await doubleClickHandle();
    SimulatorCanvas canvas = tester.widget<SimulatorCanvas>(
      find.byType(SimulatorCanvas),
    );
    ComponentInstance breaker = canvas.circuit.components.firstWhere(
      (ComponentInstance item) => item.id.value == 'breaker-1',
    );
    expect(breaker.controlState['closed'], isFalse);

    await doubleClickHandle();
    canvas = tester.widget<SimulatorCanvas>(find.byType(SimulatorCanvas));
    breaker = canvas.circuit.components.firstWhere(
      (ComponentInstance item) => item.id.value == 'breaker-1',
    );
    expect(breaker.controlState['closed'], isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'selected wire is deletable from the topbar without deleting components',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: app.F9WorkspaceDemoPage(
          initialCircuit: buildRegressionFixtureCircuit(),
          initialSelectedElementId: 'wire-2',
        ),
        ),
      );
      await tester.pumpAndSettle();

      SimulatorCanvas canvas = tester.widget<SimulatorCanvas>(
        find.byType(SimulatorCanvas),
      );
      expect(canvas.circuit.connections.length, 3);
      expect(canvas.circuit.components.length, 2);

      await _openTop(tester);
      final IconButton deleteButton = tester.widget<IconButton>(
        find.byKey(const Key('workspace-delete-action')),
      );
      expect(deleteButton.onPressed, isNotNull);

      await tester.tap(find.byKey(const Key('workspace-delete-action')));
      await tester.pumpAndSettle();

      canvas = tester.widget<SimulatorCanvas>(find.byType(SimulatorCanvas));
      expect(
        canvas.circuit.connections.map((Connection item) => item.id.value),
        isNot(contains('wire-2')),
      );
      expect(canvas.circuit.connections.length, 2);
      expect(canvas.circuit.components.length, 2);
      expect(
        (tester.widget<Text>(find.byKey(const Key('status-message')))).data,
        contains('Suppression : fil — wire-2'),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'selected wire is described in Properties and Delete key removes it',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: app.F9WorkspaceDemoPage(
          initialCircuit: buildRegressionFixtureCircuit(),
          initialSelectedElementId: 'wire-1',
        ),
        ),
      );
      await tester.pumpAndSettle();
      await _openContext(tester);

      expect(
        (tester.widget<Text>(
          find.byKey(const Key('properties-model-type')),
        )).data,
        'Fil',
      );
      expect(
        (tester.widget<Text>(
          find.byKey(const Key('properties-element-id')),
        )).data,
        'wire-1',
      );
      expect(find.text('Fil · wire-1'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.delete);
      await tester.pumpAndSettle();

      final SimulatorCanvas canvas = tester.widget<SimulatorCanvas>(
        find.byType(SimulatorCanvas),
      );
      expect(
        canvas.circuit.connections.map((Connection item) => item.id.value),
        isNot(contains('wire-1')),
      );
      expect(canvas.circuit.connections.length, 2);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('diagnostic sheet exists only for student troubleshooting', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: app.F9WorkspaceDemoPage(
          initialCircuit: buildRegressionFixtureCircuit(),
          initialWorkspace: 'Recherche de dérangement',
          role: F9UserRole.teacher,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('diagnostic-tab')), findsNothing);

    await tester.pumpWidget(
      MaterialApp(
        home: app.F9WorkspaceDemoPage(
          initialCircuit: buildRegressionFixtureCircuit(),
          initialWorkspace: 'Recherche de dérangement',
          role: F9UserRole.student,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('diagnostic-tab')), findsOneWidget);
    await _openContext(tester);
    await tester.tap(find.byKey(const Key('diagnostic-tab')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('student-diagnostic-panel')), findsOneWidget);
    expect(find.byKey(const Key('diagnostic-symptom')), findsOneWidget);
  });

  testWidgets(
    'keyboard selector provides an alternative to pointer-only selection',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(home: app.F9WorkspaceDemoPage(
          initialCircuit: buildRegressionFixtureCircuit(),
        )),
      );
      await tester.pumpAndSettle();
      await _openContext(tester);
      await tester.tap(find.byKey(const Key('properties-element-selector')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lampe · lamp-1').last);
      await tester.pumpAndSettle();
      expect(find.text('lamp-1'), findsWidgets);
      expect(
        (tester.widget<Text>(find.byKey(const Key('status-message')))).data,
        contains('Sélection clavier'),
      );
    },
  );

  testWidgets(
    'escape shortcut resets canvas interaction without mutating circuit revision',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(home: app.F9WorkspaceDemoPage(
          initialCircuit: buildRegressionFixtureCircuit(),
        )),
      );
      await tester.pumpAndSettle();
      final String before = (tester.widget<Text>(
        find.byKey(const Key('status-circuit-count')),
      )).data!;
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(
        (tester.widget<Text>(find.byKey(const Key('status-message')))).data,
        contains('annulée'),
      );
      final String after = (tester.widget<Text>(
        find.byKey(const Key('status-circuit-count')),
      )).data!;
      expect(after, before);
    },
  );

  testWidgets('breakpoint transition does not mutate CircuitState', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(home: app.F9WorkspaceDemoPage(
          initialCircuit: buildRegressionFixtureCircuit(),
        )));
    await tester.pumpAndSettle();
    final String before = (tester.widget<Text>(
      find.byKey(const Key('status-circuit-count')),
    )).data!;
    expect(before, contains('Révision 1'));

    tester.view.physicalSize = const Size(390, 844);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    tester.view.physicalSize = const Size(1440, 900);
    await tester.pumpAndSettle();
    final String after = (tester.widget<Text>(
      find.byKey(const Key('status-circuit-count')),
    )).data!;
    expect(after, before);
  });

  testWidgets(
    'selected component can be replaced without losing its identity',
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
      await _openContext(tester);
      await tester.tap(find.byKey(const Key('properties-replace-element')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('replace-resistor')));
      await tester.pumpAndSettle();
      expect(find.text('Résistance'), findsWidgets);
      expect(find.text('switch-1'), findsWidgets);
      expect(
        (tester.widget<Text>(find.byKey(const Key('status-message')))).data,
        contains('Remplacement'),
      );
    },
  );

  testWidgets(
    'compact layout tolerates increased text scale without overflow',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.35)),
          child: MaterialApp(home: app.F9WorkspaceDemoPage(
          initialCircuit: buildRegressionFixtureCircuit(),
        )),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(SimulatorCanvas), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'F9 component moves immediately with pointer drag and canvas is clipped',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(home: app.F9WorkspaceDemoPage(
          initialCircuit: buildRegressionFixtureCircuit(),
        )),
      );
      await tester.pumpAndSettle();

      final Finder canvas = find.byType(SimulatorCanvas);
      expect(canvas, findsOneWidget);
      expect(
        find.ancestor(of: canvas, matching: find.byType(ClipRect)),
        findsWidgets,
      );

      final SimulatorCanvas canvasWidget = tester.widget<SimulatorCanvas>(
        canvas,
      );
      final Offset canvasTopLeft = tester.getTopLeft(canvas);
      final Offset switchWorld = canvasWidget.layout.positionOf('switch-1')!;
      final Offset switchLocal = canvasWidget.viewportController!.worldToScreen(
        switchWorld,
      );
      final Offset switchCenter = canvasTopLeft + switchLocal;
      final TestGesture gesture = await tester.startGesture(switchCenter);
      await gesture.moveBy(
        const Offset(72, 24),
        timeStamp: const Duration(milliseconds: 60),
      );
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      expect(
        (tester.widget<Text>(find.byKey(const Key('status-message')))).data,
        contains('Position graphique mise à jour'),
      );
      expect(tester.takeException(), isNull);
    },
  );
}

CircuitState _seriesControlCircuit({
  required String modelType,
  required String elementId,
  required Map<String, Object?> controlState,
}) {
  final Terminal sourcePositive = Terminal(
    id: TerminalId('source-positive'),
    name: '+',
    role: TerminalRole.positive,
    phase: PhaseTag.dcPositive,
  );
  final Terminal sourceNegative = Terminal(
    id: TerminalId('source-negative'),
    name: '−',
    role: TerminalRole.negative,
    phase: PhaseTag.dcNegative,
  );
  final Terminal controlIn = Terminal(
    id: TerminalId('$elementId-in'),
    name: '1',
    role: TerminalRole.input,
  );
  final Terminal controlOut = Terminal(
    id: TerminalId('$elementId-out'),
    name: '2',
    role: TerminalRole.output,
  );
  final Terminal lampIn = Terminal(
    id: TerminalId('control-lamp-in'),
    name: 'A',
    role: TerminalRole.input,
  );
  final Terminal lampOut = Terminal(
    id: TerminalId('control-lamp-out'),
    name: 'B',
    role: TerminalRole.output,
  );

  return CircuitState(
    circuitId: CircuitId('direct-control-$elementId'),
    revision: 1,
    mode: ElectricalMode.dc,
    sources: <SourceInstance>[
      SourceInstance(
        id: SourceId('source-24v'),
        modelType: 'dc_voltage_source',
        terminals: <Terminal>[sourcePositive, sourceNegative],
        parameters: const <String, Object?>{'voltageV': 24.0},
      ),
    ],
    components: <ComponentInstance>[
      ComponentInstance(
        id: ComponentId(elementId),
        modelType: modelType,
        terminals: <Terminal>[controlIn, controlOut],
        parameters: modelType.startsWith('breaker')
            ? const <String, Object?>{'ratedCurrentA': 10.0}
            : const <String, Object?>{},
        controlState: controlState,
      ),
      ComponentInstance(
        id: ComponentId('lamp-1'),
        modelType: 'lamp',
        terminals: <Terminal>[lampIn, lampOut],
        parameters: const <String, Object?>{'resistanceOhm': 24.0},
      ),
    ],
    connections: <Connection>[
      Connection(
        id: ConnectionId('wire-control-1'),
        fromTerminalId: sourcePositive.id,
        toTerminalId: controlIn.id,
      ),
      Connection(
        id: ConnectionId('wire-control-2'),
        fromTerminalId: controlOut.id,
        toTerminalId: lampIn.id,
      ),
      Connection(
        id: ConnectionId('wire-control-3'),
        fromTerminalId: lampOut.id,
        toTerminalId: sourceNegative.id,
      ),
    ],
  );
}
