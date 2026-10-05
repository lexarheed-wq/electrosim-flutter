import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:electrosim_solver_ac/electrosim_solver_ac.dart';
import 'package:electrosim_topology/electrosim_topology.dart';
import 'package:test/test.dart';

void main() {
  const TopologyEngine topologyEngine = TopologyEngine();
  const SolverAC3 solver = SolverAC3();

  Ac3SolveResult solve(CircuitState circuit) =>
      solver.solve(circuit, topologyEngine.compile(circuit));

  test('six-terminal motor windings solve in external star connection', () {
    final CircuitState circuit = _motorStarCircuit();
    final Ac3SolveResult result = solve(circuit);
    expect(result.status, Ac3SolveStatus.solved);

    for (final String winding in <String>['U', 'V', 'W']) {
      final Ac3BranchResult branch = result.branch(
        'component:m1:winding:$winding',
      );
      expect(branch.kind, Ac3BranchKind.impedance);
      expect(branch.current?.magnitude, closeTo(10.0, 1e-7));
    }
    expect(result.currentBalanced, isTrue);
  });

  test('delta load solves three real line-to-line branches', () {
    final CircuitState circuit = _deltaLoadCircuit();
    final Ac3SolveResult result = solve(circuit);
    expect(result.status, Ac3SolveStatus.solved);

    for (final String branchId in <String>[
      'branch:L1-L2',
      'branch:L2-L3',
      'branch:L3-L1',
    ]) {
      final Ac3BranchResult branch = result.branch('component:load:$branchId');
      expect(branch.kind, Ac3BranchKind.impedance);
      expect(branch.current?.magnitude, closeTo(10.0, 1e-6));
    }
    expect(result.voltageBalanced, isTrue);
  });
}

CircuitState _motorStarCircuit() {
  final List<SourceInstance> sources = _sources();
  final List<Terminal> t = <Terminal>[
    _t('u1', 'U1', PhaseTag.l1),
    _t('v1', 'V1', PhaseTag.l2),
    _t('w1', 'W1', PhaseTag.l3),
    _t('u2', 'U2', PhaseTag.none),
    _t('v2', 'V2', PhaseTag.none),
    _t('w2', 'W2', PhaseTag.none),
  ];

  return CircuitState(
    circuitId: CircuitId('motor-star'),
    revision: 0,
    mode: ElectricalMode.ac3,
    sources: sources,
    components: <ComponentInstance>[
      ComponentInstance(
        id: ComponentId('m1'),
        modelType: 'motor_3p_6t',
        terminals: t,
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
      _w('star1', 'u2', 'v2'),
      _w('star2', 'v2', 'w2'),
      _w('n12', 's1-n', 's2-n'),
      _w('n23', 's2-n', 's3-n'),
    ],
    settings: const <String, Object?>{'frequencyHz': 50.0},
  );
}

CircuitState _deltaLoadCircuit() {
  final List<SourceInstance> sources = _sources();
  return CircuitState(
    circuitId: CircuitId('delta-load'),
    revision: 0,
    mode: ElectricalMode.ac3,
    sources: sources,
    components: <ComponentInstance>[
      ComponentInstance(
        id: ComponentId('load'),
        modelType: 'load_delta_3p',
        terminals: <Terminal>[
          _t('dl1', 'L1', PhaseTag.l1),
          _t('dl2', 'L2', PhaseTag.l2),
          _t('dl3', 'L3', PhaseTag.l3),
        ],
        parameters: const <String, Object?>{
          'resistanceOhm': 39.83716857408418,
          'inductanceH': 0.0,
        },
      ),
    ],
    connections: <Connection>[
      _w('l1', 's1-p', 'dl1'),
      _w('l2', 's2-p', 'dl2'),
      _w('l3', 's3-p', 'dl3'),
      _w('n12', 's1-n', 's2-n'),
      _w('n23', 's2-n', 's3-n'),
    ],
    settings: const <String, Object?>{'frequencyHz': 50.0},
  );
}

List<SourceInstance> _sources() => <SourceInstance>[
  _source('s1', PhaseTag.l1, 0.0),
  _source('s2', PhaseTag.l2, -120.0),
  _source('s3', PhaseTag.l3, 120.0),
];

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
}) => Terminal(id: TerminalId(id), name: name, role: role, phase: phase);

Connection _w(String id, String from, String to) => Connection(
  id: ConnectionId(id),
  fromTerminalId: TerminalId(from),
  toTerminalId: TerminalId(to),
);
