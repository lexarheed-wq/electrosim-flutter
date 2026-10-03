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

    test('AC3 phase-to-neutral RMS and branch current are read from phasors', () {
      final CircuitState circuit = _ac3Circuit();
      final TopologyGraph topology = topologyEngine.compile(circuit);
      final Ac3SolveResult result = const SolverAC3().solve(circuit, topology);
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
    Connection(id: ConnectionId('w1'), fromTerminalId: TerminalId('l'), toTerminalId: TerminalId('r1a')),
    Connection(id: ConnectionId('w2'), fromTerminalId: TerminalId('r1b'), toTerminalId: TerminalId('n')),
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
    Connection(id: ConnectionId('p1'), fromTerminalId: TerminalId('v1p'), toTerminalId: TerminalId('r1p')),
    Connection(id: ConnectionId('p2'), fromTerminalId: TerminalId('v2p'), toTerminalId: TerminalId('r2p')),
    Connection(id: ConnectionId('p3'), fromTerminalId: TerminalId('v3p'), toTerminalId: TerminalId('r3p')),
    Connection(id: ConnectionId('n1'), fromTerminalId: TerminalId('r1n'), toTerminalId: TerminalId('v1n')),
    Connection(id: ConnectionId('n2'), fromTerminalId: TerminalId('r2n'), toTerminalId: TerminalId('v1n')),
    Connection(id: ConnectionId('n3'), fromTerminalId: TerminalId('r3n'), toTerminalId: TerminalId('v1n')),
    Connection(id: ConnectionId('ns2'), fromTerminalId: TerminalId('v2n'), toTerminalId: TerminalId('v1n')),
    Connection(id: ConnectionId('ns3'), fromTerminalId: TerminalId('v3n'), toTerminalId: TerminalId('v1n')),
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
