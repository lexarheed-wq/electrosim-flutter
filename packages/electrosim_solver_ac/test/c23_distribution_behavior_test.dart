import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:electrosim_solver_ac/electrosim_solver_ac.dart';
import 'package:electrosim_topology/electrosim_topology.dart';
import 'package:test/test.dart';

void main() {
  const TopologyEngine topologyEngine = TopologyEngine();
  const SolverAC3 solver = SolverAC3();

  Ac3SolveResult solve(CircuitState circuit) =>
      solver.solve(circuit, topologyEngine.compile(circuit));

  test('C23 isolator_3p closes and opens all three real power poles', () {
    final Ac3SolveResult closed = solve(
      _threePoleCircuit(modelType: 'isolator_3p', closed: true),
    );
    expect(closed.isSolved, isTrue, reason: _diagnosticReason(closed));
    for (final String phase in <String>['L1', 'L2', 'L3']) {
      expect(
        closed.branch('component:q1:power:$phase').kind,
        Ac3BranchKind.idealSwitch,
      );
    }
    expect(
      closed.branch('component:r1').current!.magnitude,
      closeTo(5.0, 1e-8),
    );

    final Ac3SolveResult open = solve(
      _threePoleCircuit(modelType: 'isolator_3p', closed: false),
    );
    expect(open.isSolved, isTrue);
    for (final String phase in <String>['L1', 'L2', 'L3']) {
      expect(
        open.branch('component:q1:power:$phase').kind,
        Ac3BranchKind.openCircuit,
      );
    }
    expect(open.branch('component:r1').current!.magnitude, closeTo(0.0, 1e-12));
  });

  test('C23 isolator open condition forces all poles open', () {
    final Ac3SolveResult result = solve(
      _threePoleCircuit(
        modelType: 'isolator_3p',
        closed: true,
        condition: ComponentCondition.openCircuit,
      ),
    );
    expect(result.isSolved, isTrue, reason: _diagnosticReason(result));
    expect(
      result.branch('component:q1:power:L1').kind,
      Ac3BranchKind.openCircuit,
    );
  });

  test('C23 isolator rejects non-boolean closed control state', () {
    final CircuitState base = _threePoleCircuit(
      modelType: 'isolator_3p',
      closed: true,
    );
    final ComponentInstance original = base.components.first;
    final ComponentInstance malformed = ComponentInstance(
      id: original.id,
      modelType: original.modelType,
      terminals: original.terminals,
      parameters: original.parameters,
      controlState: const <String, Object?>{'closed': 'yes'},
      condition: original.condition,
    );
    final CircuitState invalid = _replaceFirst(base, malformed);
    final Ac3SolveResult result = solve(invalid);
    expect(result.status, Ac3SolveStatus.invalid);
    expect(
      result.diagnostics.map((Ac3SolverDiagnostic item) => item.code),
      contains(Ac3DiagnosticCode.invalidParameter),
    );
  });

  test('C23 isolator_4p switches L1 L2 L3 and neutral together', () {
    final Ac3SolveResult closed = solve(
      _fourPoleCircuit(modelType: 'isolator_4p', closed: true),
    );
    expect(closed.isSolved, isTrue, reason: _diagnosticReason(closed));
    for (final String pole in <String>['L1', 'L2', 'L3', 'N']) {
      expect(
        closed.branch('component:q1:power:$pole').kind,
        Ac3BranchKind.idealSwitch,
      );
    }

    final Ac3SolveResult open = solve(
      _fourPoleCircuit(modelType: 'isolator_4p', closed: false),
    );
    expect(open.isSolved, isTrue);
    for (final String pole in <String>['L1', 'L2', 'L3', 'N']) {
      expect(
        open.branch('component:q1:power:$pole').kind,
        Ac3BranchKind.openCircuit,
      );
    }
  });

  test('C23 breaker_4p conducts and trips all four poles', () {
    final Ac3SolveResult armed = solve(
      _fourPoleCircuit(
        modelType: 'breaker_4p',
        closed: true,
        tripped: false,
        ratedCurrentA: 10.0,
      ),
    );
    expect(armed.isSolved, isTrue, reason: _diagnosticReason(armed));
    for (final String pole in <String>['L1', 'L2', 'L3', 'N']) {
      expect(
        armed.branch('component:q1:power:$pole').kind,
        Ac3BranchKind.idealProtection,
      );
    }

    final Ac3SolveResult tripped = solve(
      _fourPoleCircuit(
        modelType: 'breaker_4p',
        closed: true,
        tripped: true,
        ratedCurrentA: 10.0,
      ),
    );
    expect(tripped.isSolved, isTrue);
    for (final String pole in <String>['L1', 'L2', 'L3', 'N']) {
      expect(
        tripped.branch('component:q1:power:$pole').kind,
        Ac3BranchKind.openCircuit,
      );
    }
  });

  test('C23 terminal_block_5 feeds five independent conductors', () {
    final Ac3SolveResult result = solve(_terminalBlockCircuit());
    expect(result.isSolved, isTrue, reason: _diagnosticReason(result));
    final List<Ac3BranchResult> feeds = result.branchResults
        .where((Ac3BranchResult item) => item.modelType == 'terminal_block_5')
        .toList(growable: false);
    expect(feeds, hasLength(5));
    expect(
      feeds.every((Ac3BranchResult item) => item.kind == Ac3BranchKind.idealShort),
      isTrue,
    );
    expect(
      result.branch('component:r4').current!.magnitude,
      closeTo(2.5, 1e-8),
    );
  });

  test('C23 terminal_block_5 open condition isolates all five conductors', () {
    final Ac3SolveResult result = solve(
      _terminalBlockCircuit(condition: ComponentCondition.openCircuit),
    );
    expect(result.isSolved, isTrue, reason: _diagnosticReason(result));
    final List<Ac3BranchResult> feeds = result.branchResults
        .where((Ac3BranchResult item) => item.modelType == 'terminal_block_5')
        .toList(growable: false);
    expect(feeds, hasLength(5));
    expect(
      feeds.every((Ac3BranchResult item) => item.kind == Ac3BranchKind.openCircuit),
      isTrue,
    );
    expect(
      result.branch('component:r1').current!.magnitude,
      closeTo(0.0, 1e-12),
    );
    expect(
      result.branch('component:r4').current!.magnitude,
      closeTo(0.0, 1e-12),
    );
  });

  test('C23 breaker_4p rejects missing rating and malformed controls', () {
    final Ac3SolveResult missingRating = solve(
      _fourPoleCircuit(modelType: 'breaker_4p', closed: true),
    );
    expect(missingRating.status, Ac3SolveStatus.invalid);
    expect(
      missingRating.diagnostics.map((Ac3SolverDiagnostic item) => item.code),
      contains(Ac3DiagnosticCode.invalidParameter),
    );

    final CircuitState base = _fourPoleCircuit(
      modelType: 'breaker_4p',
      closed: true,
      ratedCurrentA: 10.0,
    );
    final ComponentInstance original = base.components.first;
    final ComponentInstance malformed = ComponentInstance(
      id: original.id,
      modelType: original.modelType,
      terminals: original.terminals,
      parameters: original.parameters,
      controlState: const <String, Object?>{
        'closed': true,
        'tripped': 'invalid',
      },
      condition: original.condition,
    );
    final Ac3SolveResult malformedResult = solve(
      _replaceFirst(base, malformed),
    );
    expect(malformedResult.status, Ac3SolveStatus.invalid);
    expect(
      malformedResult.diagnostics.map((Ac3SolverDiagnostic item) => item.code),
      contains(Ac3DiagnosticCode.invalidParameter),
    );
  });
}

String _diagnosticReason(Ac3SolveResult result) => result.diagnostics
    .map((Ac3SolverDiagnostic item) => '${item.code.name}: ${item.message}')
    .join(' | ');

CircuitState _replaceFirst(CircuitState base, ComponentInstance replacement) =>
    CircuitState(
      circuitId: base.circuitId,
      revision: base.revision,
      mode: base.mode,
      components: <ComponentInstance>[replacement, ...base.components.skip(1)],
      connections: base.connections,
      sources: base.sources,
      settings: base.settings,
    );

CircuitState _threePoleCircuit({
  required String modelType,
  required bool closed,
  ComponentCondition condition = ComponentCondition.normal,
}) => CircuitState(
  circuitId: CircuitId('c23-three'),
  revision: 0,
  mode: ElectricalMode.ac3,
  components: <ComponentInstance>[
    ComponentInstance(
      id: ComponentId('q1'),
      modelType: modelType,
      terminals: <Terminal>[
        _t('q-l1-in', '1L1', PhaseTag.l1),
        _t('q-l2-in', '3L2', PhaseTag.l2),
        _t('q-l3-in', '5L3', PhaseTag.l3),
        _t('q-l1-out', '2T1', PhaseTag.l1),
        _t('q-l2-out', '4T2', PhaseTag.l2),
        _t('q-l3-out', '6T3', PhaseTag.l3),
      ],
      controlState: <String, Object?>{'closed': closed},
      condition: condition,
    ),
    _load('r1', PhaseTag.l1),
    _load('r2', PhaseTag.l2),
    _load('r3', PhaseTag.l3),
  ],
  connections: <Connection>[
    _wire('p1', 'v1-p', 'q-l1-in'),
    _wire('p2', 'v2-p', 'q-l2-in'),
    _wire('p3', 'v3-p', 'q-l3-in'),
    _wire('o1', 'q-l1-out', 'r1-p'),
    _wire('o2', 'q-l2-out', 'r2-p'),
    _wire('o3', 'q-l3-out', 'r3-p'),
    _wire('n1', 'r1-n', 'v1-n'),
    _wire('n2', 'r2-n', 'v1-n'),
    _wire('n3', 'r3-n', 'v1-n'),
    _wire('ns2', 'v2-n', 'v1-n'),
    _wire('ns3', 'v3-n', 'v1-n'),
  ],
  sources: <SourceInstance>[
    _source('v1', PhaseTag.l1),
    _source('v2', PhaseTag.l2),
    _source('v3', PhaseTag.l3),
  ],
  settings: const <String, Object?>{'frequencyHz': 50.0},
);

CircuitState _fourPoleCircuit({
  required String modelType,
  required bool closed,
  bool tripped = false,
  double? ratedCurrentA,
  ComponentCondition condition = ComponentCondition.normal,
}) => CircuitState(
  circuitId: CircuitId('c23-four'),
  revision: 0,
  mode: ElectricalMode.ac3,
  components: <ComponentInstance>[
    ComponentInstance(
      id: ComponentId('q1'),
      modelType: modelType,
      terminals: <Terminal>[
        _t('q-l1-in', '1L1', PhaseTag.l1),
        _t('q-l2-in', '3L2', PhaseTag.l2),
        _t('q-l3-in', '5L3', PhaseTag.l3),
        _t('q-n-in', 'N in', PhaseTag.neutral),
        _t('q-l1-out', '2T1', PhaseTag.l1),
        _t('q-l2-out', '4T2', PhaseTag.l2),
        _t('q-l3-out', '6T3', PhaseTag.l3),
        _t('q-n-out', 'N out', PhaseTag.neutral),
      ],
      parameters: <String, Object?>{
        if (ratedCurrentA != null)
          ProtectionRating.ratedCurrentKey: ratedCurrentA,
      },
      controlState: <String, Object?>{
        'closed': closed,
        if (modelType == 'breaker_4p') 'tripped': tripped,
      },
      condition: condition,
    ),
    _load('r1', PhaseTag.l1, resistanceOhm: 46.0),
    _load('r2', PhaseTag.l2, resistanceOhm: 57.5),
    _load('r3', PhaseTag.l3, resistanceOhm: 76.6666666667),
  ],
  connections: <Connection>[
    _wire('p1', 'grid-l1', 'q-l1-in'),
    _wire('p2', 'grid-l2', 'q-l2-in'),
    _wire('p3', 'grid-l3', 'q-l3-in'),
    _wire('nin', 'grid-n', 'q-n-in'),
    _wire('o1', 'q-l1-out', 'r1-p'),
    _wire('o2', 'q-l2-out', 'r2-p'),
    _wire('o3', 'q-l3-out', 'r3-p'),
    _wire('no1', 'r1-n', 'q-n-out'),
    _wire('no2', 'r2-n', 'q-n-out'),
    _wire('no3', 'r3-n', 'q-n-out'),
  ],
  sources: <SourceInstance>[_gridSource()],
  settings: const <String, Object?>{'frequencyHz': 50.0},
);

CircuitState _terminalBlockCircuit({
  ComponentCondition condition = ComponentCondition.normal,
}) => CircuitState(
  circuitId: CircuitId('c23-terminal-block'),
  revision: 0,
  mode: ElectricalMode.ac3,
  components: <ComponentInstance>[
    ComponentInstance(
      id: ComponentId('tb1'),
      modelType: 'terminal_block_5',
      terminals: <Terminal>[
        _t('tb-l1-in', 'L1 in', PhaseTag.l1),
        _t('tb-l2-in', 'L2 in', PhaseTag.l2),
        _t('tb-l3-in', 'L3 in', PhaseTag.l3),
        _t('tb-n-in', 'N in', PhaseTag.neutral),
        _t('tb-x-in', 'X in', PhaseTag.l1),
        _t('tb-l1-out', 'L1 out', PhaseTag.l1),
        _t('tb-l2-out', 'L2 out', PhaseTag.l2),
        _t('tb-l3-out', 'L3 out', PhaseTag.l3),
        _t('tb-n-out', 'N out', PhaseTag.neutral),
        _t('tb-x-out', 'X out', PhaseTag.l1),
      ],
      condition: condition,
    ),
    _load('r1', PhaseTag.l1),
    _load('r2', PhaseTag.l2),
    _load('r3', PhaseTag.l3),
    _load('r4', PhaseTag.l1, resistanceOhm: 92.0),
  ],
  connections: <Connection>[
    _wire('p1', 'grid-l1', 'tb-l1-in'),
    _wire('p2', 'grid-l2', 'tb-l2-in'),
    _wire('p3', 'grid-l3', 'tb-l3-in'),
    _wire('pn', 'grid-n', 'tb-n-in'),
    _wire('px', 'grid-l1', 'tb-x-in'),
    _wire('o1', 'tb-l1-out', 'r1-p'),
    _wire('o2', 'tb-l2-out', 'r2-p'),
    _wire('o3', 'tb-l3-out', 'r3-p'),
    _wire('ox', 'tb-x-out', 'r4-p'),
    _wire('n1', 'r1-n', 'grid-n'),
    _wire('n2', 'r2-n', 'grid-n'),
    _wire('n3', 'r3-n', 'grid-n'),
    _wire('n4', 'r4-n', 'grid-n'),
  ],
  sources: <SourceInstance>[_gridSource()],
  settings: const <String, Object?>{'frequencyHz': 50.0},
);

ComponentInstance _load(
  String id,
  PhaseTag phase, {
  double resistanceOhm = 46.0,
}) => ComponentInstance(
  id: ComponentId(id),
  modelType: 'resistor',
  terminals: <Terminal>[
    _t('$id-p', 'L', phase),
    _t('$id-n', 'N', PhaseTag.neutral),
  ],
  parameters: <String, Object?>{'resistanceOhm': resistanceOhm},
);

SourceInstance _gridSource() => SourceInstance(
  id: SourceId('grid'),
  modelType: 'ac3_voltage_source',
  terminals: <Terminal>[
    _t('grid-l1', 'L1', PhaseTag.l1),
    _t('grid-l2', 'L2', PhaseTag.l2),
    _t('grid-l3', 'L3', PhaseTag.l3),
    _t('grid-n', 'N', PhaseTag.neutral),
  ],
  parameters: const <String, Object?>{'phaseVoltageRmsV': 230.0},
);

SourceInstance _source(String id, PhaseTag phase) => SourceInstance(
  id: SourceId(id),
  modelType: 'ac_voltage_source',
  terminals: <Terminal>[
    _t('$id-p', phase.name, phase),
    _t('$id-n', 'N', PhaseTag.neutral),
  ],
  parameters: const <String, Object?>{'voltageRmsV': 230.0},
);

Terminal _t(String id, String name, PhaseTag phase) =>
    Terminal(id: TerminalId(id), name: name, phase: phase);

Connection _wire(String id, String from, String to) => Connection(
  id: ConnectionId(id),
  fromTerminalId: TerminalId(from),
  toTerminalId: TerminalId(to),
);
