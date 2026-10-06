import 'package:electrosim/main.dart' as app;
import 'package:electrosim/runtime/electrosim_runtime_engine.dart';
import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:electrosim_measurements/electrosim_measurements.dart';
import 'package:electrosim_ui_kit/electrosim_ui_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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
        const MaterialApp(
          home: app.F9WorkspaceDemoPage(initialSelectedElementId: 'lamp-1'),
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
}
