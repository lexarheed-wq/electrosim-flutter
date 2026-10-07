import 'package:electrosim/f15_source_pv_components.dart';
import 'package:electrosim/f18_component_asset_visual.dart';
import 'package:electrosim/f23_distribution_components.dart';
import 'package:electrosim/f9_component_palette.dart';
import 'package:electrosim/main.dart' as app;
import 'package:electrosim_canvas/electrosim_canvas.dart';
import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:electrosim_ui_kit/electrosim_ui_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/regression_fixture.dart';

Future<void> _openTop(WidgetTester tester) async {
  final Finder region = find.byKey(electroSimTopRegionKey);
  if (region.evaluate().isEmpty || tester.getRect(region).bottom <= 0) {
    await tester.tap(find.byKey(electroSimTopEdgeKey));
    await tester.pumpAndSettle();
  }
}

Future<void> _openPalette(WidgetTester tester) async {
  final Finder region = find.byKey(electroSimPaletteRegionKey);
  if (region.evaluate().isEmpty || tester.getRect(region).right <= 0) {
    await tester.tap(find.byKey(electroSimPaletteEdgeKey));
    await tester.pumpAndSettle();
  }
}

void main() {
  test('catalog does not duplicate base DC lamp and fan entries', () {
    expect(
      f9PaletteCatalog.any(
        (F9PaletteDefinition item) => item.keyName == 'external-lamp-dc',
      ),
      isFalse,
    );
    expect(
      f9PaletteCatalog.any(
        (F9PaletteDefinition item) => item.keyName == 'external-fan-dc',
      ),
      isFalse,
    );
  });

  test('catalog keeps diode types but not diode use-case duplicates', () {
    for (final String removedKey in <String>[
      'diode-freewheel',
      'diode-reverse-protection',
    ]) {
      expect(
        f9PaletteCatalog.any(
          (F9PaletteDefinition item) => item.keyName == removedKey,
        ),
        isFalse,
        reason: removedKey,
      );
    }

    for (final String retainedKey in <String>[
      'diode',
      'diode-schottky',
      'led-red',
      'led-green',
      'zener-5v1',
      'tvs-12v',
    ]) {
      expect(
        f9PaletteCatalog.any(
          (F9PaletteDefinition item) => item.keyName == retainedKey,
        ),
        isTrue,
        reason: retainedKey,
      );
    }
  });

  test('C15 source catalog preserves phase semantics', () {
    final F9PaletteDefinition ac1 = f9PaletteCatalog.singleWhere(
      (F9PaletteDefinition item) => item.keyName == 'source-ac1-230v',
    );
    expect(ac1.supportsMode(ElectricalMode.ac1), isTrue);
    expect(ac1.supportsMode(ElectricalMode.ac3), isFalse);
    expect(ac1.terminals[0].phase, PhaseTag.l1);
    expect(ac1.terminals[1].phase, PhaseTag.neutral);

    final Map<String, double> expected = <String, double>{
      'source-ac3-l1': 0,
      'source-ac3-l2': -120,
      'source-ac3-l3': 120,
    };
    for (final MapEntry<String, double> entry in expected.entries) {
      final F9PaletteDefinition item = f9PaletteCatalog.singleWhere(
        (F9PaletteDefinition value) => value.keyName == entry.key,
      );
      expect(item.supportsMode(ElectricalMode.ac3), isTrue);
      expect(item.supportsMode(ElectricalMode.ac1), isFalse);
      expect(item.defaultParameters['phaseDeg'], entry.value);
    }
  });

  test('mode-specific distribution hardware is strictly filtered', () {
    const List<String> ac3Only = <String>[
      'contactor-3p',
      'breaker-3p',
      'isolator-3p',
      'isolator-4p',
      'breaker-4p',
      'terminal-block-5',
      'thermal-overload-3p',
      'motor-3p-6t',
      'load-wye-3p',
      'load-delta-3p',
    ];
    for (final String key in ac3Only) {
      final F9PaletteDefinition item = f9PaletteCatalog.singleWhere(
        (F9PaletteDefinition value) => value.keyName == key,
      );
      expect(item.supportsMode(ElectricalMode.ac3), isTrue, reason: key);
      expect(item.supportsMode(ElectricalMode.dc), isFalse, reason: key);
      expect(item.supportsMode(ElectricalMode.ac1), isFalse, reason: key);
      expect(item.supportsMode(ElectricalMode.pv), isFalse, reason: key);
    }

    final F9PaletteDefinition ac1Contactor = f9PaletteCatalog.singleWhere(
      (F9PaletteDefinition value) => value.keyName == 'contactor-ac1',
    );
    expect(ac1Contactor.supportsMode(ElectricalMode.ac1), isTrue);
    expect(ac1Contactor.supportsMode(ElectricalMode.dc), isFalse);
    expect(ac1Contactor.supportsMode(ElectricalMode.ac3), isFalse);

    final F9PaletteDefinition dcTerminal = f9PaletteCatalog.singleWhere(
      (F9PaletteDefinition value) => value.keyName == 'terminal-block-dc-5',
    );
    expect(dcTerminal.supportsMode(ElectricalMode.dc), isTrue);
    expect(dcTerminal.supportsMode(ElectricalMode.ac1), isFalse);
    expect(dcTerminal.supportsMode(ElectricalMode.ac3), isFalse);
    expect(dcTerminal.visualVariant, 'dc');
    expect(
      dcTerminal.terminals.map((F9PaletteTerminalSpec t) => t.phase).toSet(),
      containsAll(<PhaseTag>[
        PhaseTag.dcPositive,
        PhaseTag.dcNegative,
        PhaseTag.protectiveEarth,
      ]),
    );
  });

  testWidgets('DC terminal block uses the dedicated DC physical identity', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: F18ComponentAssetVisual(
            modelType: 'terminal_block_5',
            variantKey: 'dc',
            size: Size(280, 210),
          ),
        ),
      ),
    );
    await tester.pump();
    final F23DistributionComponentView view = tester
        .widget<F23DistributionComponentView>(
          find.byType(F23DistributionComponentView),
        );
    expect(view.state.variantKey, 'dc');
  });

  test('C15 PV palette matches structural contracts', () {
    final F9PaletteDefinition inverter = f9PaletteCatalog.singleWhere(
      (F9PaletteDefinition item) => item.modelType == 'pv_inverter',
    );
    final F9PaletteDefinition load = f9PaletteCatalog.singleWhere(
      (F9PaletteDefinition item) => item.modelType == 'pv_resistive_load',
    );
    expect(inverter.terminalCount, 4);
    expect(load.terminalCount, 2);
    expect(
      CoreComponentModelContracts.registry
          .resolve('pv_inverter')
          ?.terminalCount,
      4,
    );
    expect(
      CoreComponentModelContracts.registry
          .resolve('pv_resistive_load')
          ?.terminalCount,
      2,
    );
  });

  test('C15 visual variants keep distinct hardware identities', () {
    expect(
      F15SourcePvVisualIdentity.ac3SourceSilhouette('ac3-grid'),
      F15Ac3SourceSilhouette.grid,
    );
    expect(
      F15SourcePvVisualIdentity.ac3SourceSilhouette('ac3-generator'),
      F15Ac3SourceSilhouette.alternator,
    );
    expect(
      F15SourcePvVisualIdentity.pvControllerSilhouette('pv-mppt'),
      F15PvControllerSilhouette.mppt,
    );
    expect(
      F15SourcePvVisualIdentity.pvControllerSilhouette('pv-pwm'),
      F15PvControllerSilhouette.pwm,
    );
  });

  test('C15 PV physical terminals are deterministic', () {
    const Size inverter = Size(190, 230);
    final List<Offset> points = <Offset>[
      for (var index = 0; index < 4; index++)
        TerminalVisualProfile.terminalOffset(
          modelType: 'pv_inverter',
          size: inverter,
          index: index,
          count: 4,
        ),
    ];
    expect(points.toSet().length, 4);
    expect(points[0].dy, lessThan(0));
    expect(points[1].dy, lessThan(0));
    expect(points[2].dy, greaterThan(0));
    expect(points[3].dy, greaterThan(0));
  });

  testWidgets('workspace switches safely from DC to AC1', (
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
    await _openTop(tester);

    await tester.tap(find.byKey(const Key('workspace-electrical-mode')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('AC 1φ — monophasé'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('mode-change-confirm')), findsOneWidget);
    await tester.tap(find.byKey(const Key('mode-change-confirm')));
    await tester.pumpAndSettle();

    final SimulatorCanvas canvas = tester.widget<SimulatorCanvas>(
      find.byType(SimulatorCanvas),
    );
    expect(canvas.circuit.mode, ElectricalMode.ac1);
    expect(canvas.circuit.components, isEmpty);
    expect(canvas.circuit.sources, isEmpty);
    expect(canvas.circuit.settings['frequencyHz'], 50.0);

    await _openPalette(tester);
    await tester.enterText(
      find.byKey(const Key('palette-search-field')),
      'Source AC 230 V',
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('palette-item-source-ac1-230v')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('palette-item-source-dc-24v')), findsNothing);
  });

  testWidgets(
    'PV mode is selectable and palette categories stay synchronized with the mode',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1440, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(home: app.F9WorkspaceDemoPage(
      initialCircuit: buildRegressionFixtureCircuit(),
    )),
      );
      await tester.pumpAndSettle();
      await _openTop(tester);

      await tester.tap(find.byKey(const Key('workspace-electrical-mode')));
      await tester.pumpAndSettle();
      final PopupMenuItem<ElectricalMode> pvEntry = tester
          .widget<PopupMenuItem<ElectricalMode>>(
            find.byKey(const Key('workspace-mode-pv')),
          );
      expect(pvEntry.enabled, isTrue);

      await tester.tap(find.byKey(const Key('workspace-mode-pv')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('mode-change-confirm')), findsOneWidget);
      await tester.tap(find.byKey(const Key('mode-change-confirm')));
      await tester.pumpAndSettle();

      SimulatorCanvas canvas = tester.widget<SimulatorCanvas>(
        find.byType(SimulatorCanvas),
      );
      expect(canvas.circuit.mode, ElectricalMode.pv);
      expect(canvas.circuit.settings['irradianceWm2'], 1000.0);
      expect(canvas.circuit.settings['cellTemperatureC'], 25.0);

      await _openPalette(tester);
      await tester.tap(find.byKey(const Key('palette-category-selector')));
      await tester.pumpAndSettle();
      expect(find.text('Photovoltaïque'), findsOneWidget);
      expect(find.text('Sources 3φ'), findsNothing);
      expect(find.text('Moteurs 3φ'), findsNothing);

      await tester.tap(find.text('Photovoltaïque'));
      await tester.pumpAndSettle();

      await _openTop(tester);
      await tester.tap(find.byKey(const Key('workspace-electrical-mode')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('workspace-mode-dc')));
      await tester.pumpAndSettle();

      canvas = tester.widget<SimulatorCanvas>(find.byType(SimulatorCanvas));
      expect(canvas.circuit.mode, ElectricalMode.dc);

      await _openPalette(tester);
      await tester.tap(find.byKey(const Key('palette-category-selector')));
      await tester.pumpAndSettle();
      expect(find.text('Photovoltaïque'), findsNothing);
      expect(find.text('Sources 3φ'), findsNothing);
      expect(find.text('Tous'), findsWidgets);
    },
  );

  testWidgets('DC palette never exposes three-phase distribution hardware', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(MaterialApp(home: app.F9WorkspaceDemoPage(
      initialCircuit: buildRegressionFixtureCircuit(),
    )));
    await tester.pumpAndSettle();
    await _openPalette(tester);

    await tester.enterText(
      find.byKey(const Key('palette-search-field')),
      'Bornier',
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('palette-item-terminal-block-dc-5')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('palette-item-terminal-block-5')),
      findsNothing,
    );

    await tester.tap(find.byKey(const Key('palette-category-selector')));
    await tester.pumpAndSettle();
    expect(find.text('Distribution CC'), findsOneWidget);
    expect(find.text('Distribution 3φ'), findsNothing);
    expect(find.text('Triphasé'), findsNothing);
  });

  testWidgets('C15 source and PV visuals use native production painters', (
    WidgetTester tester,
  ) async {
    const List<(String, String?, Type)> cases = <(String, String?, Type)>[
      ('dc_current_source', 'dc-current', F15SourcePvComponentView),
      ('ac_voltage_source', 'ac-l1', F15SourcePvComponentView),
      ('ac_current_source', 'ac-current', F15SourcePvComponentView),
      ('pv_array', 'pv-array', F15SourcePvComponentView),
      ('pv_inverter', 'pv-inverter-1p', F15SourcePvComponentView),
      ('pv_resistive_load', 'pv-load', F15SourcePvComponentView),
    ];
    for (final (String modelType, String? variant, Type widgetType) in cases) {
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: F18ComponentAssetVisual(
              modelType: modelType,
              variantKey: variant,
              size: F18ReferenceComponentMetrics.dragSizeFor(modelType),
              energized: true,
              voltageV: modelType.startsWith('pv_') ? 230 : 230,
              currentA: 2.0,
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(widgetType), findsOneWidget, reason: modelType);
      expect(tester.takeException(), isNull, reason: modelType);
    }
  });
}
