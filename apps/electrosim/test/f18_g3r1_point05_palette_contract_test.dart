import 'package:electrosim/f18_component_asset_visual.dart';
import 'package:electrosim/main.dart' as app;
import 'package:electrosim_canvas/electrosim_canvas.dart';
import 'package:electrosim_domain/electrosim_domain.dart';
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

void main() {
  testWidgets('F18 palette exposes exactly five quick components', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: app.F9WorkspaceDemoPage()));
    await tester.pumpAndSettle();
    await _openPalette(tester);

    expect(find.byKey(const Key('palette-item-source-dc-24v')), findsOneWidget);
    expect(find.byKey(const Key('palette-item-switch-no')), findsOneWidget);
    expect(find.byKey(const Key('palette-item-lamp')), findsOneWidget);
    expect(find.byKey(const Key('palette-item-resistor')), findsOneWidget);
    expect(find.byKey(const Key('palette-item-breaker')), findsOneWidget);
    expect(find.byKey(const Key('palette-item-push-button-no')), findsNothing);
    expect(find.byKey(const Key('palette-show-all')), findsOneWidget);
    expect(find.text('Voir tous les composants'), findsOneWidget);
  });

  testWidgets('Voir tous expands once and never becomes a Voir moins toggle', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: app.F9WorkspaceDemoPage()));
    await tester.pumpAndSettle();
    await _openPalette(tester);

    await tester.tap(find.byKey(const Key('palette-show-all')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('palette-show-all')), findsNothing);
    expect(find.textContaining('Voir moins'), findsNothing);

    expect(
      find.byKey(const Key('palette-item-push-button-no'), skipOffstage: false),
      findsOneWidget,
    );
  });

  testWidgets(
    'search exposes non-quick component without requiring Voir tous',
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
        'Moteur',
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('palette-item-motor-dc')), findsOneWidget);
      expect(find.byKey(const Key('palette-show-all')), findsNothing);
    },
  );

  testWidgets(
    'quick add preserves visual model and variant on the board component',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1440, 1000);
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
        'Pompe solaire',
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const Key('palette-quick-add-external-solar-pump')),
      );
      await tester.pumpAndSettle();

      final SimulatorCanvas canvas = tester.widget<SimulatorCanvas>(
        find.byType(SimulatorCanvas),
      );
      final component = canvas.circuit.components.singleWhere(
        (item) => item.id.value.startsWith('external-solar-pump'),
      );
      expect(
        component.parameters['_visualModelType'],
        'catalog_motor_driven_2t',
      );
      expect(component.parameters['_visualVariant'], 'pump');
      expect(
        canvas.layout.sizeOf(component.id.value),
        F18ReferenceComponentMetrics.boardSizeFor(
          'catalog_motor_driven_2t',
        ),
      );
    },
  );

  testWidgets(
    'restored workspace keeps the visual-model board size',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1440, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final ComponentInstance appliance = ComponentInstance(
        id: ComponentId('restored-tv'),
        modelType: 'impedance',
        terminals: <Terminal>[
          Terminal(id: TerminalId('restored-tv-a'), name: '1'),
          Terminal(id: TerminalId('restored-tv-b'), name: '2'),
        ],
        parameters: const <String, Object?>{
          '_visualModelType': 'catalog_appliance_2t',
          '_visualVariant': 'television',
          'resistanceOhm': 100.0,
        },
      );
      final CircuitState circuit = CircuitState(
        circuitId: CircuitId('visual-restore'),
        revision: 1,
        mode: ElectricalMode.ac1,
        components: <ComponentInstance>[appliance],
        connections: const <Connection>[],
        sources: const <SourceInstance>[],
      );

      await tester.pumpWidget(
        MaterialApp(home: app.F18WorkspacePage(initialCircuit: circuit)),
      );
      await tester.pumpAndSettle();

      final SimulatorCanvas canvas = tester.widget<SimulatorCanvas>(
        find.byType(SimulatorCanvas),
      );
      expect(
        canvas.layout.sizeOf('restored-tv'),
        F18ReferenceComponentMetrics.boardSizeFor('catalog_appliance_2t'),
      );
    },
  );
}
