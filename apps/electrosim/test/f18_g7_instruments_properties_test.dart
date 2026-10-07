import 'package:electrosim/main.dart' as app;
import 'package:electrosim/f18_g7_property_presenter.dart';
import 'package:electrosim/f9_element_editor.dart';
import 'package:electrosim/runtime/electrosim_runtime_engine.dart';
import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:electrosim_measurements/electrosim_measurements.dart';
import 'package:electrosim_ui_kit/electrosim_ui_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/regression_fixture.dart';

Future<void> _openContext(WidgetTester tester) async {
  final Finder region = find.byKey(electroSimContextRegionKey);
  final double width =
      tester.view.physicalSize.width / tester.view.devicePixelRatio;
  if (region.evaluate().isEmpty || tester.getRect(region).left >= width) {
    await tester.tap(find.byKey(electroSimContextEdgeKey));
    await tester.pumpAndSettle();
  }
}

void main() {
  testWidgets(
    'F18-G7 properties expose solver-backed state and humanized parameters',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: app.F9WorkspaceDemoPage(
          initialCircuit: buildRegressionFixtureCircuit(),
          initialSelectedElementId: 'lamp-1',
        ),
        ),
      );
      await tester.pumpAndSettle();
      await _openContext(tester);

      expect(
        find.byKey(const Key('properties-runtime-heading')),
        findsOneWidget,
      );
      expect(find.text('CC'), findsWidgets);
      expect(find.text('Résolu'), findsOneWidget);
      expect(find.text('Alimenté'), findsOneWidget);
      expect(find.text('24.000 V'), findsWidgets);
      expect(find.text('1.000 A'), findsOneWidget);
      expect(find.text('24.000 W'), findsOneWidget);
      expect(find.text('Résistance'), findsOneWidget);
      expect(find.text('resistanceOhm'), findsNothing);
      await tester.drag(
        find.byKey(const Key('properties-panel')),
        const Offset(0, -360),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('properties-runtime-evidence')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  test('F18-G7 missing evidence never manufactures operating quantities', () {
    final ComponentInstance isolated = ComponentInstance(
      id: ComponentId('isolated'),
      modelType: 'unsupported_f18_g7',
      terminals: <Terminal>[
        Terminal(id: TerminalId('ia'), name: 'A'),
        Terminal(id: TerminalId('ib'), name: 'B'),
      ],
      parameters: const <String, Object?>{'resistanceOhm': 10.0},
    );
    final CircuitState circuit = CircuitState(
      circuitId: CircuitId('f18-g7-missing-evidence'),
      revision: 1,
      mode: ElectricalMode.dc,
      components: <ComponentInstance>[isolated],
    );
    final ElectroSimRuntimeSnapshot snapshot = const ElectroSimRuntimeEngine()
        .evaluate(circuit);
    final ComponentOperatingState state = snapshot.componentOperatingState(
      isolated.id,
    )!;

    expect(state.code, ComponentOperatingCode.undetermined);
    expect(state.voltageV, isNull);
    expect(state.currentA, isNull);
    expect(state.powerW, isNull);

    final Iterable<OperatingWarningCode> warningCodes = state.warnings.map(
      (OperatingWarning warning) => warning.code,
    );
    expect(
      warningCodes.any(
        (OperatingWarningCode code) =>
            code == OperatingWarningCode.simulationNotSolved ||
            code == OperatingWarningCode.missingBranchResult,
      ),
      isTrue,
    );
  });

  test('F18-G7 reports runtime component health and damage', () {
    final CircuitState circuit = CircuitState(
      circuitId: CircuitId('f18-g7-health'),
      revision: 0,
      mode: ElectricalMode.dc,
      sources: <SourceInstance>[
        SourceInstance(
          id: SourceId('v1'),
          modelType: 'dc_voltage_source',
          terminals: <Terminal>[
            Terminal(id: TerminalId('vp'), name: '+', phase: PhaseTag.dcPositive),
            Terminal(id: TerminalId('vn'), name: '−', phase: PhaseTag.dcNegative),
          ],
          parameters: const <String, Object?>{'voltageV': 30.0},
        ),
      ],
      components: <ComponentInstance>[
        ComponentInstance(
          id: ComponentId('lamp-health'),
          modelType: 'lamp',
          terminals: <Terminal>[
            Terminal(id: TerminalId('lh-a'), name: 'A'),
            Terminal(id: TerminalId('lh-b'), name: 'B'),
          ],
          parameters: const <String, Object?>{
            ComponentParameterKeys.resistanceOhm: 24.0,
            ReceiverNominalRating.voltageKey: 24.0,
            ReceiverNominalRating.currentKey: 1.0,
            ReceiverNominalRating.powerKey: 24.0,
            ComponentParameterKeys.thermalWithstandSeconds: 1.0,
          },
        ),
      ],
      connections: <Connection>[
        Connection(
          id: ConnectionId('hp'),
          fromTerminalId: TerminalId('vp'),
          toTerminalId: TerminalId('lh-a'),
        ),
        Connection(
          id: ConnectionId('hn'),
          fromTerminalId: TerminalId('lh-b'),
          toTerminalId: TerminalId('vn'),
        ),
      ],
    );
    const ElectroSimRuntimeEngine engine = ElectroSimRuntimeEngine();
    final ElectroSimRuntimeSnapshot first = engine.advance(
      circuit,
      elapsed: const Duration(milliseconds: 400),
      previousComponentHealthStates: <ComponentId, ComponentHealthState>{
        ComponentId('lamp-health'): ComponentHealthState(
          code: ComponentHealthCode.stressed,
          thermalExposure: 0.45,
          stressRatio: 1.25,
        ),
      },
    );
    final F9ElementDetails details = F9ElementEditor.describe(
      circuit,
      'lamp-health',
    )!;
    final F18G7PropertySnapshot properties = F18G7PropertyPresenter.describe(
      details: details,
      runtimeSnapshot: first,
    );

    expect(
      properties.runtimeValues.any(
        (F18G7PropertyRow row) =>
            row.label == 'Santé' && row.value == 'Dégradée',
      ),
      isTrue,
    );
    expect(
      properties.runtimeValues.any(
        (F18G7PropertyRow row) => row.label == 'Dommage thermique',
      ),
      isTrue,
    );
  });

  test('F18-G7 never labels health normal when solver is unresolved', () {
    final ComponentInstance unsupported = ComponentInstance(
      id: ComponentId('health-unresolved'),
      modelType: 'unsupported_health',
      terminals: <Terminal>[
        Terminal(id: TerminalId('hu-a'), name: 'A'),
        Terminal(id: TerminalId('hu-b'), name: 'B'),
      ],
    );
    final CircuitState circuit = CircuitState(
      circuitId: CircuitId('f18-g7-health-unresolved'),
      revision: 0,
      mode: ElectricalMode.dc,
      components: <ComponentInstance>[unsupported],
    );
    final ElectroSimRuntimeSnapshot snapshot = const ElectroSimRuntimeEngine()
        .evaluate(circuit);
    final F18G7PropertySnapshot properties = F18G7PropertyPresenter.describe(
      details: F9ElementEditor.describe(circuit, unsupported.id.value)!,
      runtimeSnapshot: snapshot,
    );

    expect(
      properties.runtimeValues.any(
        (F18G7PropertyRow row) =>
            row.label == 'Santé' &&
            row.value == 'Non évaluée — solveur indisponible',
      ),
      isTrue,
    );
  });

}
