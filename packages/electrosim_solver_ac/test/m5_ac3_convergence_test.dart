import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:electrosim_solver_ac/electrosim_solver_ac.dart';
import 'package:electrosim_topology/electrosim_topology.dart';
import 'package:test/test.dart';

void main() {
  const TopologyEngine topologyEngine = TopologyEngine();
  const SolverAC3 solver = SolverAC3();

  Ac3SolveResult solve(CircuitState circuit) =>
      solver.solve(circuit, topologyEngine.compile(circuit));

  group('M5 AC3 convergence', () {
    test('lamp is solved through its canonical M2 branch in a balanced star', () {
      final Ac3SolveResult result = solve(_balancedStar());
      expect(result.status, Ac3SolveStatus.solved);
      expect(result.sourceSequence, Ac3PhaseSequence.positive);
      expect(result.voltageBalanced, isTrue);
      expect(result.currentBalanced, isTrue);
      expect(result.branch('component:l1').current?.magnitude, closeTo(5.0, 1e-8));
      expect(result.lineCurrent(PhaseTag.l1).magnitude, closeTo(5.0, 1e-8));
      expect(result.neutralCurrent.magnitude, lessThan(1e-8));
      _expectResiduals(result);
    });

    test('single-pole AC3 switch opens and closes one phase without changing source sequence', () {
      final Ac3SolveResult open = solve(_switchedStar(closed: false));
      expect(open.status, Ac3SolveStatus.solved);
      expect(open.sourceSequence, Ac3PhaseSequence.positive);
      expect(open.branch('component:s1').kind, Ac3BranchKind.openCircuit);
      expect(open.branch('component:l1').current?.magnitude, lessThan(1e-10));
      expect(open.currentBalanced, isFalse);

      final Ac3SolveResult closed = solve(_switchedStar(closed: true));
      expect(closed.status, Ac3SolveStatus.solved);
      expect(closed.branch('component:s1').kind, Ac3BranchKind.idealSwitch);
      expect(closed.branch('component:l1').current?.magnitude, closeTo(5.0, 1e-8));
      expect(closed.currentBalanced, isTrue);
      _expectResiduals(closed);
    });
  });
}

CircuitState _balancedStar() => CircuitState(
  circuitId: CircuitId('m5-balanced'),
  revision: 0,
  mode: ElectricalMode.ac3,
  components: <ComponentInstance>[
    _load('l1', 'lamp', PhaseTag.l1),
    _load('l2', 'resistor', PhaseTag.l2),
    _load('l3', 'resistor', PhaseTag.l3),
  ],
  connections: _starConnections(switched: false),
  sources: _sources(),
  settings: const <String, Object?>{'frequencyHz': 50.0},
);

CircuitState _switchedStar({required bool closed}) => CircuitState(
  circuitId: CircuitId('m5-switch-$closed'),
  revision: 0,
  mode: ElectricalMode.ac3,
  components: <ComponentInstance>[
    ComponentInstance(
      id: ComponentId('s1'),
      modelType: 'switch',
      terminals: <Terminal>[
        _t('s1-in', '1', phase: PhaseTag.l1),
        _t('s1-out', '2', phase: PhaseTag.l1),
      ],
      controlState: <String, Object?>{'closed': closed},
    ),
    _load('l1', 'lamp', PhaseTag.l1),
    _load('l2', 'resistor', PhaseTag.l2),
    _load('l3', 'resistor', PhaseTag.l3),
  ],
  connections: _starConnections(switched: true),
  sources: _sources(),
  settings: const <String, Object?>{'frequencyHz': 50.0},
);

ComponentInstance _load(String id, String modelType, PhaseTag phase) =>
    ComponentInstance(
      id: ComponentId(id),
      modelType: modelType,
      terminals: <Terminal>[
        _t('$id-p', 'L', phase: phase),
        _t('$id-n', 'N', phase: PhaseTag.neutral, role: TerminalRole.neutral),
      ],
      parameters: const <String, Object?>{'resistanceOhm': 46.0},
    );

List<SourceInstance> _sources() => <SourceInstance>[
  _source('v1', PhaseTag.l1),
  _source('v2', PhaseTag.l2),
  _source('v3', PhaseTag.l3),
];

SourceInstance _source(String id, PhaseTag phase) => SourceInstance(
  id: SourceId(id),
  modelType: 'ac_voltage_source',
  terminals: <Terminal>[
    _t('$id-p', phase.name.toUpperCase(), phase: phase),
    _t('$id-n', 'N', phase: PhaseTag.neutral, role: TerminalRole.neutral),
  ],
  parameters: const <String, Object?>{'voltageRmsV': 230.0},
);

List<Connection> _starConnections({required bool switched}) => <Connection>[
  Connection(
    id: ConnectionId('p1a'),
    fromTerminalId: TerminalId('v1-p'),
    toTerminalId: TerminalId(switched ? 's1-in' : 'l1-p'),
  ),
  if (switched)
    Connection(
      id: ConnectionId('p1b'),
      fromTerminalId: TerminalId('s1-out'),
      toTerminalId: TerminalId('l1-p'),
    ),
  Connection(
    id: ConnectionId('p2'),
    fromTerminalId: TerminalId('v2-p'),
    toTerminalId: TerminalId('l2-p'),
  ),
  Connection(
    id: ConnectionId('p3'),
    fromTerminalId: TerminalId('v3-p'),
    toTerminalId: TerminalId('l3-p'),
  ),
  Connection(
    id: ConnectionId('n1'),
    fromTerminalId: TerminalId('l1-n'),
    toTerminalId: TerminalId('v1-n'),
  ),
  Connection(
    id: ConnectionId('n2'),
    fromTerminalId: TerminalId('l2-n'),
    toTerminalId: TerminalId('v1-n'),
  ),
  Connection(
    id: ConnectionId('n3'),
    fromTerminalId: TerminalId('l3-n'),
    toTerminalId: TerminalId('v1-n'),
  ),
  Connection(
    id: ConnectionId('ns2'),
    fromTerminalId: TerminalId('v2-n'),
    toTerminalId: TerminalId('v1-n'),
  ),
  Connection(
    id: ConnectionId('ns3'),
    fromTerminalId: TerminalId('v3-n'),
    toTerminalId: TerminalId('v1-n'),
  ),
];

Terminal _t(
  String id,
  String name, {
  PhaseTag phase = PhaseTag.none,
  TerminalRole role = TerminalRole.generic,
}) => Terminal(id: TerminalId(id), name: name, phase: phase, role: role);

void _expectResiduals(Ac3SolveResult result) {
  expect(result.maxMatrixResidual, isNotNull);
  expect(result.maxMatrixResidual!, lessThan(1e-8));
  for (final double residual in result.kclResiduals.values) {
    expect(residual, lessThan(1e-8));
  }
}
