import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:electrosim_measurements/electrosim_measurements.dart';
import 'package:electrosim_solver_ac/electrosim_solver_ac.dart';
import 'package:electrosim_topology/electrosim_topology.dart';
import 'package:test/test.dart';

void main() {
  const TopologyEngine topologyEngine = TopologyEngine();
  const MeasurementEngine measurements = MeasurementEngine();

  group('M7 AC measurements', () {
    test('AC1 voltage/current/frequency are read from solver evidence', () {
      final CircuitState circuit = _ac1Circuit();
      final TopologyGraph topology = topologyEngine.compile(circuit);
      final Ac1SolveResult result = const SolverAC1().solve(circuit, topology);
      expect(result.isSolved, isTrue);

      final MeasurementResult voltage = measurements.measureAc1(
        request: MeasurementRequest.voltageAcRms(
          positiveProbe: TerminalId('r1a'),
          negativeProbe: TerminalId('r1b'),
        ),
        circuit: circuit,
        topology: topology,
        simulation: result,
      );
      expect(voltage.isValid, isTrue);
      expect(voltage.reading!.unit, ElectricalUnit.volt);
      expect(voltage.reading!.value, closeTo(230.0, 1e-8));

      final MeasurementResult current = measurements.measureAc1(
        request: MeasurementRequest.currentAcRms(branchId: 'component:r1'),
        circuit: circuit,
        topology: topology,
        simulation: result,
      );
      expect(current.isValid, isTrue);
      expect(current.reading!.value, closeTo(5.0, 1e-8));

      final MeasurementResult frequency = measurements.measureAc1(
        request: MeasurementRequest.frequency(),
        circuit: circuit,
        topology: topology,
        simulation: result,
      );
      expect(frequency.reading!.unit, ElectricalUnit.hertz);
      expect(frequency.reading!.value, closeTo(50.0, 1e-12));
    });

    test(
      'AC3 phase-to-neutral RMS and branch current are read from phasors',
      () {
        final CircuitState circuit = _ac3Circuit();
        final TopologyGraph topology = topologyEngine.compile(circuit);
        final Ac3SolveResult result = const SolverAC3().solve(
          circuit,
          topology,
        );
        expect(result.isSolved, isTrue);

        final MeasurementResult voltage = measurements.measureAc3(
          request: MeasurementRequest.voltageAcRms(
            positiveProbe: TerminalId('r1p'),
            negativeProbe: TerminalId('r1n'),
          ),
          circuit: circuit,
          topology: topology,
          simulation: result,
        );
        expect(voltage.isValid, isTrue);
        expect(voltage.reading!.value, closeTo(230.0, 1e-8));

        final MeasurementResult current = measurements.measureAc3(
          request: MeasurementRequest.currentAcRms(branchId: 'component:r1'),
          circuit: circuit,
          topology: topology,
          simulation: result,
        );
        expect(current.isValid, isTrue);
        expect(current.reading!.value, closeTo(5.0, 1e-8));

        final MeasurementResult frequency = measurements.measureAc3(
          request: MeasurementRequest.frequency(),
          circuit: circuit,
          topology: topology,
          simulation: result,
        );
        expect(frequency.reading!.value, closeTo(50.0, 1e-12));
      },
    );

    test('AC1 branch P Q S are derived from solved complex power', () {
      final CircuitState circuit = _ac1Circuit();
      final TopologyGraph topology = topologyEngine.compile(circuit);
      final Ac1SolveResult result = const SolverAC1().solve(circuit, topology);
      expect(result.isSolved, isTrue);

      final MeasurementResult p = measurements.measureAc1(
        request: MeasurementRequest.activePower(branchId: 'component:r1'),
        circuit: circuit,
        topology: topology,
        simulation: result,
      );
      final MeasurementResult q = measurements.measureAc1(
        request: MeasurementRequest.reactivePower(branchId: 'component:r1'),
        circuit: circuit,
        topology: topology,
        simulation: result,
      );
      final MeasurementResult apparent = measurements.measureAc1(
        request: MeasurementRequest.apparentPower(branchId: 'component:r1'),
        circuit: circuit,
        topology: topology,
        simulation: result,
      );

      expect(p.isValid, isTrue);
      expect(p.reading!.unit, ElectricalUnit.watt);
      expect(p.reading!.value, closeTo(1150.0, 1e-6));
      expect(q.isValid, isTrue);
      expect(q.reading!.unit, ElectricalUnit.varUnit);
      expect(q.reading!.value.abs(), lessThan(1e-6));
      expect(apparent.isValid, isTrue);
      expect(apparent.reading!.unit, ElectricalUnit.voltAmpere);
      expect(apparent.reading!.value, closeTo(1150.0, 1e-6));
    });

    test('AC voltage probes reject terminals absent from topology', () {
      final CircuitState circuit = _ac1Circuit();
      final TopologyGraph topology = topologyEngine.compile(circuit);
      final Ac1SolveResult result = const SolverAC1().solve(circuit, topology);

      final MeasurementResult invalid = measurements.measureAc1(
        request: MeasurementRequest.voltageAcRms(
          positiveProbe: TerminalId('missing-terminal'),
          negativeProbe: TerminalId('r1b'),
        ),
        circuit: circuit,
        topology: topology,
        simulation: result,
      );
      expect(invalid.isValid, isFalse);
      expect(invalid.errorCode, MeasurementErrorCode.unknownTerminal);
    });

    test(
      'AC power requests reject missing branches and invalid mode kinds',
      () {
        final CircuitState ac1 = _ac1Circuit();
        final TopologyGraph topology1 = topologyEngine.compile(ac1);
        final Ac1SolveResult result1 = const SolverAC1().solve(ac1, topology1);

        final MeasurementResult missing = measurements.measureAc1(
          request: MeasurementRequest.activePower(branchId: 'missing'),
          circuit: ac1,
          topology: topology1,
          simulation: result1,
        );
        expect(missing.errorCode, MeasurementErrorCode.unknownBranch);

        final MeasurementResult phaseSequence = measurements.measureAc1(
          request: MeasurementRequest.phaseSequence(),
          circuit: ac1,
          topology: topology1,
          simulation: result1,
        );
        expect(
          phaseSequence.errorCode,
          MeasurementErrorCode.wrongElectricalMode,
        );

        final MeasurementResult dcKind = measurements.measureAc1(
          request: MeasurementRequest.voltage(
            positiveProbe: TerminalId('r1a'),
            negativeProbe: TerminalId('r1b'),
          ),
          circuit: ac1,
          topology: topology1,
          simulation: result1,
        );
        expect(dcKind.errorCode, MeasurementErrorCode.wrongElectricalMode);
      },
    );

    test('AC3 total P Q S and phase sequence come from solved phasors', () {
      final CircuitState circuit = _ac3Circuit();
      final TopologyGraph topology = topologyEngine.compile(circuit);
      final Ac3SolveResult result = const SolverAC3().solve(circuit, topology);
      expect(result.isSolved, isTrue);

      final MeasurementResult p = measurements.measureAc3(
        request: MeasurementRequest.activePower(),
        circuit: circuit,
        topology: topology,
        simulation: result,
      );
      final MeasurementResult q = measurements.measureAc3(
        request: MeasurementRequest.reactivePower(),
        circuit: circuit,
        topology: topology,
        simulation: result,
      );
      final MeasurementResult apparent = measurements.measureAc3(
        request: MeasurementRequest.apparentPower(),
        circuit: circuit,
        topology: topology,
        simulation: result,
      );
      final MeasurementResult sequence = measurements.measureAc3(
        request: MeasurementRequest.phaseSequence(),
        circuit: circuit,
        topology: topology,
        simulation: result,
      );

      expect(p.reading!.unit, ElectricalUnit.watt);
      expect(p.reading!.value, closeTo(3450.0, 1e-6));
      expect(q.reading!.unit, ElectricalUnit.varUnit);
      expect(q.reading!.value.abs(), lessThan(1e-6));
      expect(apparent.reading!.unit, ElectricalUnit.voltAmpere);
      expect(apparent.reading!.value, closeTo(3450.0, 1e-6));
      expect(sequence.displayText, 'L1 → L2 → L3');
      expect(sequence.evidenceIds, contains('solver:phase-sequence'));
    });

    test('AC3 branch power and invalid DC-kind request stay explicit', () {
      final CircuitState circuit = _ac3Circuit();
      final TopologyGraph topology = topologyEngine.compile(circuit);
      final Ac3SolveResult result = const SolverAC3().solve(circuit, topology);
      expect(result.isSolved, isTrue);

      final MeasurementResult branchP = measurements.measureAc3(
        request: MeasurementRequest.activePower(branchId: 'component:r1'),
        circuit: circuit,
        topology: topology,
        simulation: result,
      );
      expect(branchP.isValid, isTrue);
      expect(branchP.reading!.value, closeTo(1150.0, 1e-6));

      final MeasurementResult missing = measurements.measureAc3(
        request: MeasurementRequest.apparentPower(branchId: 'missing'),
        circuit: circuit,
        topology: topology,
        simulation: result,
      );
      expect(missing.errorCode, MeasurementErrorCode.unknownBranch);

      final MeasurementResult dcKind = measurements.measureAc3(
        request: MeasurementRequest.current(branchId: 'component:r1'),
        circuit: circuit,
        topology: topology,
        simulation: result,
      );
      expect(dcKind.errorCode, MeasurementErrorCode.wrongElectricalMode);
    });

    test('AC preflight rejects identity and mode mismatches', () {
      final CircuitState circuit = _ac1Circuit();
      final TopologyGraph topology = topologyEngine.compile(circuit);
      final Ac1SolveResult result = const SolverAC1().solve(circuit, topology);

      final CircuitState revised = CircuitState(
        circuitId: circuit.circuitId,
        revision: circuit.revision + 1,
        mode: circuit.mode,
        components: circuit.components,
        connections: circuit.connections,
        sources: circuit.sources,
        settings: circuit.settings,
      );
      final MeasurementResult identityMismatch = measurements.measureAc1(
        request: MeasurementRequest.frequency(),
        circuit: revised,
        topology: topology,
        simulation: result,
      );
      expect(identityMismatch.errorCode, MeasurementErrorCode.identityMismatch);

      final CircuitState ac3 = _ac3Circuit();
      final TopologyGraph topology3 = topologyEngine.compile(ac3);
      final MeasurementResult modeMismatch = measurements.measureAc1(
        request: MeasurementRequest.frequency(),
        circuit: ac3,
        topology: topology3,
        simulation: result,
      );
      expect(modeMismatch.errorCode, MeasurementErrorCode.wrongElectricalMode);
    });

    test('AC3 phase sequence reports negative and indeterminate states', () {
      final CircuitState circuit = _ac3Circuit();
      final TopologyGraph topology = topologyEngine.compile(circuit);
      final Ac3SolveResult solved = const SolverAC3().solve(circuit, topology);

      final MeasurementResult negative = measurements.measureAc3(
        request: MeasurementRequest.phaseSequence(),
        circuit: circuit,
        topology: topology,
        simulation: _withSequence(solved, Ac3PhaseSequence.negative),
      );
      expect(negative.displayText, 'L1 → L3 → L2');

      final MeasurementResult indeterminate = measurements.measureAc3(
        request: MeasurementRequest.phaseSequence(),
        circuit: circuit,
        topology: topology,
        simulation: _withSequence(solved, Ac3PhaseSequence.indeterminate),
      );
      expect(indeterminate.displayText, 'Indéterminé');
    });

    test('DC entry point explicitly rejects AC measurement requests', () {
      final CircuitState circuit = _ac1Circuit();
      final TopologyGraph topology = topologyEngine.compile(circuit);
      final Ac1SolveResult ac = const SolverAC1().solve(circuit, topology);
      final MeasurementResult result = measurements.measureAc1(
        request: MeasurementRequest.currentAcRms(branchId: 'missing'),
        circuit: circuit,
        topology: topology,
        simulation: ac,
      );
      expect(result.errorCode, MeasurementErrorCode.unknownBranch);
    });
  });
}

Ac3SolveResult _withSequence(
  Ac3SolveResult source,
  Ac3PhaseSequence sequence,
) => Ac3SolveResult(
  circuitId: source.circuitId,
  circuitRevision: source.circuitRevision,
  engineVersion: source.engineVersion,
  status: source.status,
  frequencyHz: source.frequencyHz,
  referenceNodeId: source.referenceNodeId,
  nodeVoltages: source.nodeVoltages,
  branchResults: source.branchResults,
  diagnostics: source.diagnostics,
  maxMatrixResidual: source.maxMatrixResidual,
  kclResiduals: source.kclResiduals,
  phaseVoltages: source.phaseVoltages,
  lineCurrents: source.lineCurrents,
  lineToLineVoltages: source.lineToLineVoltages,
  neutralCurrent: source.neutralCurrent,
  missingPhases: source.missingPhases,
  sourceSequence: sequence,
  voltageBalanced: source.voltageBalanced,
  currentBalanced: source.currentBalanced,
  neutralConnected: source.neutralConnected,
  phaseOrderObservations: source.phaseOrderObservations,
);

CircuitState _ac1Circuit() => CircuitState(
  circuitId: CircuitId('m7-ac1'),
  revision: 0,
  mode: ElectricalMode.ac1,
  components: <ComponentInstance>[
    ComponentInstance(
      id: ComponentId('r1'),
      modelType: 'resistor',
      terminals: <Terminal>[_t('r1a', 'A'), _t('r1b', 'B')],
      parameters: const <String, Object?>{'resistanceOhm': 46.0},
    ),
  ],
  connections: <Connection>[
    Connection(
      id: ConnectionId('w1'),
      fromTerminalId: TerminalId('l'),
      toTerminalId: TerminalId('r1a'),
    ),
    Connection(
      id: ConnectionId('w2'),
      fromTerminalId: TerminalId('r1b'),
      toTerminalId: TerminalId('n'),
    ),
  ],
  sources: <SourceInstance>[
    SourceInstance(
      id: SourceId('v1'),
      modelType: 'ac_voltage_source',
      terminals: <Terminal>[
        _t('l', 'L', role: TerminalRole.line),
        _t('n', 'N', role: TerminalRole.neutral, phase: PhaseTag.neutral),
      ],
      parameters: const <String, Object?>{'voltageRmsV': 230.0},
    ),
  ],
  settings: const <String, Object?>{'frequencyHz': 50.0},
);

CircuitState _ac3Circuit() => CircuitState(
  circuitId: CircuitId('m7-ac3'),
  revision: 0,
  mode: ElectricalMode.ac3,
  components: <ComponentInstance>[
    _phaseLoad('r1', PhaseTag.l1),
    _phaseLoad('r2', PhaseTag.l2),
    _phaseLoad('r3', PhaseTag.l3),
  ],
  connections: <Connection>[
    Connection(
      id: ConnectionId('p1'),
      fromTerminalId: TerminalId('v1p'),
      toTerminalId: TerminalId('r1p'),
    ),
    Connection(
      id: ConnectionId('p2'),
      fromTerminalId: TerminalId('v2p'),
      toTerminalId: TerminalId('r2p'),
    ),
    Connection(
      id: ConnectionId('p3'),
      fromTerminalId: TerminalId('v3p'),
      toTerminalId: TerminalId('r3p'),
    ),
    Connection(
      id: ConnectionId('n1'),
      fromTerminalId: TerminalId('r1n'),
      toTerminalId: TerminalId('v1n'),
    ),
    Connection(
      id: ConnectionId('n2'),
      fromTerminalId: TerminalId('r2n'),
      toTerminalId: TerminalId('v1n'),
    ),
    Connection(
      id: ConnectionId('n3'),
      fromTerminalId: TerminalId('r3n'),
      toTerminalId: TerminalId('v1n'),
    ),
    Connection(
      id: ConnectionId('ns2'),
      fromTerminalId: TerminalId('v2n'),
      toTerminalId: TerminalId('v1n'),
    ),
    Connection(
      id: ConnectionId('ns3'),
      fromTerminalId: TerminalId('v3n'),
      toTerminalId: TerminalId('v1n'),
    ),
  ],
  sources: <SourceInstance>[
    _phaseSource('v1', PhaseTag.l1),
    _phaseSource('v2', PhaseTag.l2),
    _phaseSource('v3', PhaseTag.l3),
  ],
  settings: const <String, Object?>{'frequencyHz': 50.0},
);

ComponentInstance _phaseLoad(String id, PhaseTag phase) => ComponentInstance(
  id: ComponentId(id),
  modelType: 'resistor',
  terminals: <Terminal>[
    _t('${id}p', 'L', phase: phase),
    _t('${id}n', 'N', role: TerminalRole.neutral, phase: PhaseTag.neutral),
  ],
  parameters: const <String, Object?>{'resistanceOhm': 46.0},
);

SourceInstance _phaseSource(String id, PhaseTag phase) => SourceInstance(
  id: SourceId(id),
  modelType: 'ac_voltage_source',
  terminals: <Terminal>[
    _t('${id}p', phase.name, phase: phase),
    _t('${id}n', 'N', role: TerminalRole.neutral, phase: PhaseTag.neutral),
  ],
  parameters: const <String, Object?>{'voltageRmsV': 230.0},
);

Terminal _t(
  String id,
  String name, {
  TerminalRole role = TerminalRole.generic,
  PhaseTag phase = PhaseTag.none,
}) => Terminal(id: TerminalId(id), name: name, role: role, phase: phase);
