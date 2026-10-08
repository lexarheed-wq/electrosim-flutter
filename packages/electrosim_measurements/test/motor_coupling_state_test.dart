import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:electrosim_measurements/electrosim_measurements.dart';
import 'package:electrosim_solver_ac/electrosim_solver_ac.dart';
import 'package:electrosim_topology/electrosim_topology.dart';
import 'package:test/test.dart';

void main() {
  test('invalid six-terminal coupling cannot report normal motor operation', () {
    final CircuitState circuit = _partialStarCircuit();
    final Ac3SolveResult result = const SolverAC3().solve(
      circuit,
      const TopologyEngine().compile(circuit),
    );
    expect(result.status, Ac3SolveStatus.solved);

    final ComponentOperatingState state = const DeviceStateEngine().evaluateAc3(
      component: circuit.components.single,
      circuit: circuit,
      simulation: result,
    );
    expect(state.code, ComponentOperatingCode.faulted);
    expect(
      state.warnings.map((OperatingWarning item) => item.code),
      contains(OperatingWarningCode.invalidMotorCoupling),
    );
  });
}

CircuitState _partialStarCircuit() {
  return CircuitState(
    circuitId: CircuitId('motor-partial-star-state'),
    revision: 0,
    mode: ElectricalMode.ac3,
    sources: <SourceInstance>[
      _source('s1', PhaseTag.l1, 0.0),
      _source('s2', PhaseTag.l2, -120.0),
      _source('s3', PhaseTag.l3, 120.0),
    ],
    components: <ComponentInstance>[
      ComponentInstance(
        id: ComponentId('m1'),
        modelType: 'motor_3p_6t',
        terminals: <Terminal>[
          _t('u1', 'U1', PhaseTag.l1),
          _t('v1', 'V1', PhaseTag.l2),
          _t('w1', 'W1', PhaseTag.l3),
          _t('u2', 'U2', PhaseTag.none),
          _t('v2', 'V2', PhaseTag.none),
          _t('w2', 'W2', PhaseTag.none),
        ],
        parameters: const <String, Object?>{
          'resistanceOhm': 23.0,
          'inductanceH': 0.0,
        },
      ),
    ],
    connections: <Connection>[
      _w('l1', 's1-p', 'u1'),
      _w('l2', 's2-p', 'v1'),
      _w('l3', 's3-p', 'w1'),
      _w('partial', 'u2', 'v2'),
      _w('n12', 's1-n', 's2-n'),
      _w('n23', 's2-n', 's3-n'),
    ],
    settings: const <String, Object?>{'frequencyHz': 50.0},
  );
}

SourceInstance _source(String id, PhaseTag phase, double angle) =>
    SourceInstance(
      id: SourceId(id),
      modelType: 'ac_voltage_source',
      terminals: <Terminal>[
        _t('$id-p', phase.name.toUpperCase(), phase),
        _t('$id-n', 'N', PhaseTag.neutral, role: TerminalRole.neutral),
      ],
      parameters: <String, Object?>{'voltageRmsV': 230.0, 'phaseDeg': angle},
    );

Terminal _t(
  String id,
  String name,
  PhaseTag phase, {
  TerminalRole role = TerminalRole.generic,
}) => Terminal(id: TerminalId(id), name: name, phase: phase, role: role);

Connection _w(String id, String from, String to) => Connection(
  id: ConnectionId(id),
  fromTerminalId: TerminalId(from),
  toTerminalId: TerminalId(to),
);
