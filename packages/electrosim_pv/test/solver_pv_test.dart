import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:electrosim_pv/electrosim_pv.dart';
import 'package:electrosim_topology/electrosim_topology.dart';
import 'package:test/test.dart';

void main() {
  const SolverPV solver = SolverPV();
  const TopologyEngine topologyEngine = TopologyEngine();

  PvSolveResult solve(CircuitState circuit) =>
      solver.solve(circuit, topologyEngine.compile(circuit));

  group('SolverPV', () {
    test('PV-002 nominal PV/inverter/load power flow is physically balanced', () {
      final PvSolveResult result = solve(_pvCircuit(loadPowerAt230W: 2000.0));
      expect(result.status, PvSolveStatus.solved);
      expect(result.pvOperatingVoltageV, closeTo(400.0, 1e-9));
      expect(result.pvAvailableCurrentA, closeTo(10.0, 1e-9));
      expect(result.pvAvailablePowerW, closeTo(4000.0, 1e-9));
      expect(result.inverterState, PvInverterState.running);
      expect(result.inverterOutputVoltageRmsV, closeTo(230.0, 1e-9));
      expect(result.inverterOutputPowerW, closeTo(2000.0, 1e-7));
      expect(result.pvDrawnPowerW, closeTo(2000.0 / 0.95, 1e-7));
      expect(
        result.inverterConversionLossW,
        closeTo((2000.0 / 0.95) - 2000.0, 1e-7),
      );
      expect(
        result.pvDrawnPowerW,
        closeTo(result.inverterOutputPowerW + result.inverterConversionLossW, 1e-8),
      );
      expect(result.curtailedPowerW, greaterThan(1800.0));
      expect(result.load(ComponentId('load')).activePowerW, closeTo(2000.0, 1e-7));
    });

    test('PV-002 low irradiance reduces available power and causes real output droop', () {
      final PvSolveResult result = solve(
        _pvCircuit(loadPowerAt230W: 3000.0, irradianceWm2: 500.0),
      );
      expect(result.status, PvSolveStatus.solved);
      expect(result.pvAvailablePowerW, closeTo(2000.0, 1e-7));
      expect(result.inverterState, PvInverterState.powerLimited);
      expect(result.inverterOutputPowerW, closeTo(1900.0, 1e-6));
      expect(result.inverterOutputVoltageRmsV, lessThan(230.0));
      expect(result.inverterOutputVoltageRmsV, greaterThan(0.0));
    });

    test('M8 shading reduces effective irradiance without changing raw setting semantics', () {
      final PvSolveResult result = solve(
        _pvCircuit(
          loadPowerAt230W: 3000.0,
          irradianceWm2: 800.0,
          shadingPct: 25.0,
        ),
      );
      expect(result.status, PvSolveStatus.solved);
      expect(result.irradianceWm2, closeTo(600.0, 1e-9));
      expect(result.pvAvailablePowerW, closeTo(2400.0, 1e-7));
    });

    test('M8 invalid shading fails explicitly', () {
      final PvSolveResult result = solve(
        _pvCircuit(invalidShadingSetting: true),
      );
      expect(result.status, PvSolveStatus.invalid);
      expect(
        result.diagnostics.map((PvSolverDiagnostic item) => item.code),
        contains(PvDiagnosticCode.invalidPvParameter),
      );
    });

    test('PV-003 temperature coefficients are applied explicitly', () {
      final PvSolveResult result = solve(
        _pvCircuit(
          loadPowerAt230W: 1000.0,
          cellTemperatureC: 50.0,
          powerTemperatureCoefficientPerC: -0.004,
          voltageTemperatureCoefficientPerC: -0.002,
        ),
      );
      expect(result.status, PvSolveStatus.solved);
      expect(result.pvAvailablePowerW, closeTo(3600.0, 1e-7));
      expect(result.pvOperatingVoltageV, closeTo(380.0, 1e-7));
    });

    test('PV-001 inverter fault conditions stop downstream output physically', () {
      for (final ComponentCondition condition in <ComponentCondition>[
        ComponentCondition.disabled,
        ComponentCondition.openCircuit,
        ComponentCondition.shortCircuit,
      ]) {
        final PvSolveResult result = solve(
          _pvCircuit(loadPowerAt230W: 1200.0, inverterCondition: condition),
        );
        expect(result.status, PvSolveStatus.solved);
        expect(result.inverterState, PvInverterState.faulted);
        expect(result.inverterOutputVoltageRmsV, 0.0);
        expect(result.inverterOutputCurrentRmsA, 0.0);
        expect(result.inverterOutputPowerW, 0.0);
        expect(result.pvDrawnPowerW, 0.0);
        expect(result.load(ComponentId('load')).activePowerW, 0.0);
        expect(
          result.diagnostics.map((PvSolverDiagnostic item) => item.code),
          contains(PvDiagnosticCode.inverterFaulted),
        );
      }
    });

    test('PV-005 inverter DC limits prevent fictitious AC output', () {
      final PvSolveResult result = solve(
        _pvCircuit(loadPowerAt230W: 1200.0, minDcVoltageV: 450.0),
      );
      expect(result.status, PvSolveStatus.solved);
      expect(result.inverterState, PvInverterState.inputOutOfRange);
      expect(result.inverterOutputPowerW, 0.0);
      expect(result.inverterOutputVoltageRmsV, 0.0);
      expect(
        result.diagnostics.map((PvSolverDiagnostic item) => item.code),
        contains(PvDiagnosticCode.inputVoltageOutOfRange),
      );
    });

    test('degraded inverter uses only its explicit deratingFactor', () {
      final PvSolveResult result = solve(
        _pvCircuit(
          loadPowerAt230W: 3000.0,
          inverterCondition: ComponentCondition.degraded,
          deratingFactor: 0.5,
        ),
      );
      expect(result.status, PvSolveStatus.solved);
      expect(result.inverterState, PvInverterState.powerLimited);
      expect(result.inverterOutputPowerW, closeTo(1750.0, 1e-6));
      expect(
        result.diagnostics.map((PvSolverDiagnostic item) => item.code),
        contains(PvDiagnosticCode.inverterDerated),
      );
    });

    test('idle inverter regulates nominal voltage without inventing load power', () {
      final PvSolveResult result = solve(_pvCircuit(includeLoad: false));
      expect(result.status, PvSolveStatus.solved);
      expect(result.inverterState, PvInverterState.idle);
      expect(result.inverterOutputVoltageRmsV, closeTo(230.0, 1e-9));
      expect(result.inverterOutputCurrentRmsA, 0.0);
      expect(result.inverterOutputPowerW, 0.0);
      expect(result.pvDrawnPowerW, 0.0);
      expect(result.inverterConversionLossW, 0.0);
    });

    test('disconnected DC input is an explicit invalid topology', () {
      final CircuitState circuit = _pvCircuit(disconnectDcPositive: true);
      final PvSolveResult result = solve(circuit);
      expect(result.status, PvSolveStatus.invalid);
      expect(
        result.diagnostics.map((PvSolverDiagnostic item) => item.code),
        contains(PvDiagnosticCode.dcInputDisconnected),
      );
    });

    test('disconnected AC load is an explicit invalid topology', () {
      final PvSolveResult result = solve(_pvCircuit(disconnectLoadLine: true));
      expect(result.status, PvSolveStatus.invalid);
      expect(
        result.diagnostics.map((PvSolverDiagnostic item) => item.code),
        contains(PvDiagnosticCode.acOutputDisconnected),
      );
    });

    test('wrong mode and topology revision mismatch fail explicitly', () {
      final CircuitState wrongMode = CircuitState(
        circuitId: CircuitId('wrong-mode'),
        revision: 0,
        mode: ElectricalMode.dc,
      );
      expect(solve(wrongMode).status, PvSolveStatus.invalid);

      final CircuitState circuit = _pvCircuit();
      final TopologyGraph topology = topologyEngine.compile(circuit);
      final CircuitState changed = CircuitState(
        circuitId: circuit.circuitId,
        revision: 1,
        mode: circuit.mode,
        components: circuit.components,
        connections: circuit.connections,
        sources: circuit.sources,
        settings: circuit.settings,
      );
      final PvSolveResult mismatch = solver.solve(changed, topology);
      expect(mismatch.status, PvSolveStatus.invalid);
      expect(
        mismatch.diagnostics.map((PvSolverDiagnostic item) => item.code),
        contains(PvDiagnosticCode.topologyIdentityMismatch),
      );
    });

    test('invalid PV/inverter/load parameters do not fall back to magic values', () {
      for (final CircuitState circuit in <CircuitState>[
        _pvCircuit(mppVoltageV: 0.0),
        _pvCircuit(efficiency: 1.2),
        _pvCircuit(loadResistanceOverride: -1.0),
        _pvCircuit(
          inverterCondition: ComponentCondition.degraded,
          deratingFactor: 1.2,
        ),
      ]) {
        expect(solve(circuit).status, PvSolveStatus.invalid);
      }
    });

    test('missing environmental settings use documented solver defaults', () {
      final PvSolveResult result = solve(
        _pvCircuit(omitEnvironmentalSettings: true),
      );
      expect(result.status, PvSolveStatus.solved);
      expect(result.isSolved, isTrue);
      expect(result.irradianceWm2, closeTo(1000.0, 1e-9));
      expect(result.cellTemperatureC, closeTo(25.0, 1e-9));
    });

    test('invalid environmental settings fail explicitly', () {
      final PvSolveResult invalidIrradiance = solve(
        _pvCircuit(invalidIrradianceSetting: true),
      );
      expect(invalidIrradiance.status, PvSolveStatus.invalid);
      expect(invalidIrradiance.isSolved, isFalse);
      expect(
        invalidIrradiance.diagnostics.map((PvSolverDiagnostic item) => item.code),
        contains(PvDiagnosticCode.invalidPvParameter),
      );

      final PvSolveResult invalidTemperature = solve(
        _pvCircuit(invalidTemperatureSetting: true),
      );
      expect(invalidTemperature.status, PvSolveStatus.invalid);
      expect(
        invalidTemperature.diagnostics.map((PvSolverDiagnostic item) => item.code),
        contains(PvDiagnosticCode.invalidPvParameter),
      );
    });

    test('degraded inverter still enforces its DC input window', () {
      final PvSolveResult result = solve(
        _pvCircuit(
          inverterCondition: ComponentCondition.degraded,
          deratingFactor: 0.8,
          minDcVoltageV: 450.0,
        ),
      );
      expect(result.status, PvSolveStatus.solved);
      expect(result.inverterState, PvInverterState.inputOutOfRange);
      expect(result.inverterOutputPowerW, 0.0);
      expect(
        result.diagnostics.map((PvSolverDiagnostic item) => item.code),
        containsAll(<PvDiagnosticCode>[
          PvDiagnosticCode.inverterDerated,
          PvDiagnosticCode.inputVoltageOutOfRange,
        ]),
      );
    });

    test('zero PV operating voltage cannot invent available current or AC output', () {
      final PvSolveResult result = solve(
        _pvCircuit(
          cellTemperatureC: 125.0,
          voltageTemperatureCoefficientPerC: -0.01,
        ),
      );
      expect(result.status, PvSolveStatus.solved);
      expect(result.pvOperatingVoltageV, 0.0);
      expect(result.pvAvailableCurrentA, 0.0);
      expect(result.pvDrawnCurrentA, 0.0);
      expect(result.inverterState, PvInverterState.inputOutOfRange);
      expect(result.inverterOutputPowerW, 0.0);
    });

    test('zero reference irradiance is handled deterministically without division by zero', () {
      const SolverPV zeroReferenceSolver = SolverPV(
        options: PvSolverOptions(referenceIrradianceWm2: 0.0),
      );
      final CircuitState circuit = _pvCircuit(loadPowerAt230W: 1000.0);
      final PvSolveResult result = zeroReferenceSolver.solve(
        circuit,
        topologyEngine.compile(circuit),
      );
      expect(result.status, PvSolveStatus.solved);
      expect(result.pvAvailablePowerW, 0.0);
      expect(result.pvAvailableCurrentA, 0.0);
      expect(result.inverterOutputPowerW, 0.0);
      expect(result.inverterOutputVoltageRmsV, 0.0);
      expect(result.inverterState, PvInverterState.powerLimited);
    });

    test('same PV input is deterministic', () {
      final CircuitState circuit = _pvCircuit(
        loadPowerAt230W: 2750.0,
        irradianceWm2: 725.0,
        cellTemperatureC: 42.0,
      );
      final PvSolveResult a = solve(circuit);
      final PvSolveResult b = solve(circuit);
      expect(a.status, b.status);
      expect(a.pvAvailablePowerW, b.pvAvailablePowerW);
      expect(a.pvDrawnPowerW, b.pvDrawnPowerW);
      expect(a.inverterOutputVoltageRmsV, b.inverterOutputVoltageRmsV);
      expect(a.inverterOutputPowerW, b.inverterOutputPowerW);
      expect(a.inverterConversionLossW, b.inverterConversionLossW);
    });
  });
}

CircuitState _pvCircuit({
  double loadPowerAt230W = 1000.0,
  bool includeLoad = true,
  bool disconnectDcPositive = false,
  bool disconnectLoadLine = false,
  double irradianceWm2 = 1000.0,
  double cellTemperatureC = 25.0,
  double mppVoltageV = 400.0,
  double mppCurrentA = 10.0,
  double powerTemperatureCoefficientPerC = 0.0,
  double voltageTemperatureCoefficientPerC = 0.0,
  double minDcVoltageV = 300.0,
  double maxDcVoltageV = 500.0,
  double efficiency = 0.95,
  ComponentCondition inverterCondition = ComponentCondition.normal,
  double deratingFactor = 0.5,
  double? loadResistanceOverride,
  bool omitEnvironmentalSettings = false,
  bool invalidIrradianceSetting = false,
  bool invalidTemperatureSetting = false,
  double shadingPct = 0.0,
  bool invalidShadingSetting = false,
}) {
  final double resistance =
      loadResistanceOverride ?? (230.0 * 230.0 / loadPowerAt230W);
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
        id: TerminalId('inv-dc-'),
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
    parameters: <String, Object?>{
      'minDcVoltageV': minDcVoltageV,
      'maxDcVoltageV': maxDcVoltageV,
      'nominalAcVoltageV': 230.0,
      'ratedAcPowerW': 3500.0,
      'efficiency': efficiency,
      if (inverterCondition == ComponentCondition.degraded)
        'deratingFactor': deratingFactor,
    },
    condition: inverterCondition,
  );

  final List<ComponentInstance> components = <ComponentInstance>[inverter];
  if (includeLoad) {
    components.add(
      ComponentInstance(
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
      ),
    );
  }

  final List<Connection> connections = <Connection>[
    if (!disconnectDcPositive)
      _wire('dc-pos', 'pv-pos', 'inv-dc-pos', PhaseTag.dcPositive),
    _wire('dc-', 'pv-', 'inv-dc-', PhaseTag.dcNegative),
    if (includeLoad && !disconnectLoadLine)
      _wire('ac-l', 'inv-l', 'load-l', PhaseTag.l1),
    if (includeLoad) _wire('ac-n', 'inv-n', 'load-n', PhaseTag.neutral),
  ];

  return CircuitState(
    circuitId: CircuitId('pv-test'),
    revision: 0,
    mode: ElectricalMode.pv,
    components: components,
    connections: connections,
    sources: <SourceInstance>[
      SourceInstance(
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
            id: TerminalId('pv-'),
            name: '-',
            role: TerminalRole.negative,
            phase: PhaseTag.dcNegative,
          ),
        ],
        parameters: <String, Object?>{
          'mppVoltageV': mppVoltageV,
          'mppCurrentA': mppCurrentA,
          'powerTemperatureCoefficientPerC': powerTemperatureCoefficientPerC,
          'voltageTemperatureCoefficientPerC': voltageTemperatureCoefficientPerC,
        },
      ),
    ],
    settings: omitEnvironmentalSettings
        ? const <String, Object?>{}
        : <String, Object?>{
            'irradianceWm2': invalidIrradianceSetting ? -1.0 : irradianceWm2,
            'shadingPct': invalidShadingSetting ? 101.0 : shadingPct,
            'cellTemperatureC': invalidTemperatureSetting
                ? 'invalid-temperature'
                : cellTemperatureC,
          },
  );
}

Connection _wire(String id, String from, String to, PhaseTag phase) => Connection(
  id: ConnectionId(id),
  fromTerminalId: TerminalId(from),
  toTerminalId: TerminalId(to),
  phase: phase,
);
