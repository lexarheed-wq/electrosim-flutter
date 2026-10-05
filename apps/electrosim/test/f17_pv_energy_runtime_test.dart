import 'package:electrosim/main.dart' as app;
import 'package:electrosim/runtime/electrosim_runtime_engine.dart';
import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:electrosim_energy/electrosim_energy.dart';
import 'package:electrosim_pv/electrosim_pv.dart';
import 'package:electrosim_ui_kit/electrosim_ui_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _ensureContextOpen(WidgetTester tester) async {
  final Finder region = find.byKey(electroSimContextRegionKey);
  final double width =
      tester.view.physicalSize.width / tester.view.devicePixelRatio;
  if (region.evaluate().isEmpty || tester.getRect(region).left >= width) {
    await tester.tap(find.byKey(electroSimContextEdgeKey));
    await tester.pumpAndSettle();
  }
}

void main() {
  group('F17-R10 PV and energy runtime routing', () {
    test('routes a nominal PV circuit through SolverPV', () {
      final CircuitState circuit = _pvCircuit(loadPowerAt230W: 2000.0);
      final ElectroSimRuntimeSnapshot snapshot = const ElectroSimRuntimeEngine()
          .evaluate(circuit);

      expect(snapshot.solverKind, ElectroSimRuntimeSolverKind.pv);
      expect(snapshot.solved, isTrue);
      expect(snapshot.energyAvailable, isTrue);
      expect(snapshot.pv.status, PvSolveStatus.solved);
      expect(snapshot.pv.pvAvailablePowerW, closeTo(4000.0, 1e-9));
      expect(snapshot.pv.inverterOutputPowerW, closeTo(2000.0, 1e-7));
      expect(snapshot.dcResult, isNull);
      expect(snapshot.ac1Result, isNull);
      expect(snapshot.ac3Result, isNull);
    });

    test('converts the solved PV result into a balanced energy sample', () {
      final ElectroSimRuntimeSnapshot snapshot = const ElectroSimRuntimeEngine()
          .evaluate(_pvCircuit(loadPowerAt230W: 1900.0));

      final EnergyPowerSample sample = snapshot.energyPowerSample();

      expect(sample.inputPowerW, closeTo(2000.0, 1e-7));
      expect(sample.outputPowerW, closeTo(1900.0, 1e-7));
      expect(sample.lossPowerW, closeTo(100.0, 1e-7));
      expect(
        sample.inputPowerW,
        closeTo(sample.outputPowerW + sample.lossPowerW, 1e-7),
      );
    });

    test('accumulates energy only from explicit simulation duration', () {
      final ElectroSimRuntimeSnapshot snapshot = const ElectroSimRuntimeEngine()
          .evaluate(_pvCircuit(loadPowerAt230W: 1900.0));

      final EnergySnapshot zeroTime = snapshot.advanceEnergy(
        elapsed: Duration.zero,
      );
      expect(zeroTime.elapsedSeconds, 0.0);
      expect(zeroTime.inputEnergyWh, 0.0);
      expect(zeroTime.outputEnergyWh, 0.0);

      final EnergySnapshot halfHour = snapshot.advanceEnergy(
        previous: zeroTime,
        elapsed: const Duration(minutes: 30),
      );
      expect(halfHour.elapsedSeconds, 1800.0);
      expect(halfHour.inputEnergyWh, closeTo(1000.0, 1e-7));
      expect(halfHour.outputEnergyWh, closeTo(950.0, 1e-7));
      expect(halfHour.lossEnergyWh, closeTo(50.0, 1e-7));
    });

    test('an unsolved PV circuit cannot fabricate energy', () {
      final CircuitState invalid = _pvCircuit(disconnectDcPositive: true);
      final ElectroSimRuntimeSnapshot snapshot = const ElectroSimRuntimeEngine()
          .evaluate(invalid);

      expect(snapshot.solved, isFalse);
      expect(snapshot.energyAvailable, isFalse);
      expect(
        () => snapshot.energyPowerSample(),
        throwsA(
          isA<EnergyException>().having(
            (EnergyException error) => error.code,
            'code',
            EnergyErrorCode.unsolvedSource,
          ),
        ),
      );
    });

    testWidgets('workspace renders PV evidence from the runtime snapshot', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: app.F9WorkspaceDemoPage(
            initialCircuit: _pvCircuit(loadPowerAt230W: 2000.0),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await _ensureContextOpen(tester);
      await tester.tap(find.text('Mesures'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('pv-runtime-status')), findsOneWidget);
      expect(find.text('Solveur PV actif'), findsOneWidget);
      expect(
        tester
            .widget<Text>(find.byKey(const Key('pv-irradiance-reading')))
            .data,
        '1000.0 W/m²',
      );
      expect(
        tester
            .widget<Text>(find.byKey(const Key('pv-output-power-reading')))
            .data,
        '2000.0 W',
      );
      expect(find.byKey(const Key('pv-energy-time-policy')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    test('non-PV runtime refuses energy routing explicitly', () {
      final CircuitState dc = CircuitState(
        circuitId: CircuitId('f17-r10-dc'),
        revision: 0,
        mode: ElectricalMode.dc,
      );
      final ElectroSimRuntimeSnapshot snapshot = const ElectroSimRuntimeEngine()
          .evaluate(dc);

      expect(snapshot.energyAvailable, isFalse);
      expect(
        () => snapshot.advanceEnergy(elapsed: const Duration(seconds: 1)),
        throwsStateError,
      );
    });
  });
}

CircuitState _pvCircuit({
  double loadPowerAt230W = 1000.0,
  bool disconnectDcPositive = false,
}) {
  final double resistance = 230.0 * 230.0 / loadPowerAt230W;

  final SourceInstance array = SourceInstance(
    id: SourceId('pv'),
    modelType: 'pv_array',
    terminals: <Terminal>[
      Terminal(
        id: TerminalId('pv-pos'),
        name: '+',
        role: TerminalRole.positive,
        phase: PhaseTag.dcPositive,
      ),
      Terminal(
        id: TerminalId('pv-neg'),
        name: '-',
        role: TerminalRole.negative,
        phase: PhaseTag.dcNegative,
      ),
    ],
    parameters: const <String, Object?>{
      'mppVoltageV': 400.0,
      'mppCurrentA': 10.0,
      'powerTemperatureCoefficientPerC': 0.0,
      'voltageTemperatureCoefficientPerC': 0.0,
    },
  );

  final ComponentInstance inverter = ComponentInstance(
    id: ComponentId('inv'),
    modelType: 'pv_inverter',
    terminals: <Terminal>[
      Terminal(
        id: TerminalId('inv-dc-pos'),
        name: 'DC+',
        role: TerminalRole.positive,
        phase: PhaseTag.dcPositive,
      ),
      Terminal(
        id: TerminalId('inv-dc-neg'),
        name: 'DC-',
        role: TerminalRole.negative,
        phase: PhaseTag.dcNegative,
      ),
      Terminal(
        id: TerminalId('inv-l'),
        name: 'L',
        role: TerminalRole.line,
        phase: PhaseTag.l1,
      ),
      Terminal(
        id: TerminalId('inv-n'),
        name: 'N',
        role: TerminalRole.neutral,
        phase: PhaseTag.neutral,
      ),
    ],
    parameters: const <String, Object?>{
      'minDcVoltageV': 300.0,
      'maxDcVoltageV': 500.0,
      'nominalAcVoltageV': 230.0,
      'ratedAcPowerW': 3500.0,
      'efficiency': 0.95,
    },
  );

  final ComponentInstance load = ComponentInstance(
    id: ComponentId('load'),
    modelType: 'pv_resistive_load',
    terminals: <Terminal>[
      Terminal(
        id: TerminalId('load-l'),
        name: 'L',
        role: TerminalRole.line,
        phase: PhaseTag.l1,
      ),
      Terminal(
        id: TerminalId('load-n'),
        name: 'N',
        role: TerminalRole.neutral,
        phase: PhaseTag.neutral,
      ),
    ],
    parameters: <String, Object?>{'resistanceOhm': resistance},
  );

  return CircuitState(
    circuitId: CircuitId('f17-r10-pv'),
    revision: 10,
    mode: ElectricalMode.pv,
    sources: <SourceInstance>[array],
    components: <ComponentInstance>[inverter, load],
    connections: <Connection>[
      if (!disconnectDcPositive)
        Connection(
          id: ConnectionId('dc-pos'),
          fromTerminalId: TerminalId('pv-pos'),
          toTerminalId: TerminalId('inv-dc-pos'),
          phase: PhaseTag.dcPositive,
        ),
      Connection(
        id: ConnectionId('dc-neg'),
        fromTerminalId: TerminalId('pv-neg'),
        toTerminalId: TerminalId('inv-dc-neg'),
        phase: PhaseTag.dcNegative,
      ),
      Connection(
        id: ConnectionId('ac-l'),
        fromTerminalId: TerminalId('inv-l'),
        toTerminalId: TerminalId('load-l'),
        phase: PhaseTag.l1,
      ),
      Connection(
        id: ConnectionId('ac-n'),
        fromTerminalId: TerminalId('inv-n'),
        toTerminalId: TerminalId('load-n'),
        phase: PhaseTag.neutral,
      ),
    ],
    settings: const <String, Object?>{
      'irradianceWm2': 1000.0,
      'cellTemperatureC': 25.0,
    },
  );
}
