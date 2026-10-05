import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:electrosim_solver_dc/electrosim_solver_dc.dart';
import 'package:electrosim_topology/electrosim_topology.dart';
import 'package:test/test.dart';

void main() {
  const TopologyEngine topologyEngine = TopologyEngine();
  const SolverDC solver = SolverDC();

  DcSolveResult solve(CircuitState circuit) => solver.solve(circuit, topologyEngine.compile(circuit));

  group('F3 canonical DC corpus', () {
    test('DC-001: 24 V source and 12 ohm resistor gives 2 A', () {
      final DcSolveResult result = solve(_singleResistor(voltage: 24, resistance: 12));
      expect(result.status, DcSolveStatus.solved);
      expect(result.branch('component:r1').currentA, closeTo(2.0, 1e-10));
      expect(result.branch('component:r1').voltageV.abs(), closeTo(24.0, 1e-10));
      expect(result.branch('source:v1').currentA?.abs(), closeTo(2.0, 1e-10));
      expect(result.maxMatrixResidual, lessThan(1e-10));
      _expectPhysicalResiduals(result);
    });

    test('DC-002: 10 + 20 ohm series under 30 V gives 1 A and 10/20 V', () {
      final DcSolveResult result = solve(_seriesCircuit());
      expect(result.status, DcSolveStatus.solved);
      expect(result.branch('component:r1').currentA, closeTo(1.0, 1e-10));
      expect(result.branch('component:r2').currentA, closeTo(1.0, 1e-10));
      expect(result.branch('component:r1').voltageV.abs(), closeTo(10.0, 1e-10));
      expect(result.branch('component:r2').voltageV.abs(), closeTo(20.0, 1e-10));
      _expectPhysicalResiduals(result);
    });

    test('DC-003: 10 ohm parallel 10 ohm under 10 V gives 2 A total', () {
      final DcSolveResult result = solve(_parallelCircuit());
      expect(result.status, DcSolveStatus.solved);
      expect(result.branch('component:r1').currentA, closeTo(1.0, 1e-10));
      expect(result.branch('component:r2').currentA, closeTo(1.0, 1e-10));
      expect(result.branch('source:v1').currentA?.abs(), closeTo(2.0, 1e-10));
      _expectPhysicalResiduals(result);
    });

    test('DC-004: ideal open switch carries exactly zero current', () {
      final DcSolveResult result = solve(_switchCircuit(closed: false));
      expect(result.status, DcSolveStatus.solved);
      expect(result.branch('component:s1').kind, DcBranchKind.openCircuit);
      expect(result.branch('component:s1').currentA, 0.0);
      expect(result.branch('component:r1').currentA, closeTo(0.0, 1e-12));
      expect(result.branch('component:s1').voltageV.abs(), closeTo(24.0, 1e-10));
      _expectPhysicalResiduals(result);
    });

    test('DC-005: disconnected resistor island produces explicit floating diagnostic', () {
      final DcSolveResult result = solve(_floatingIslandCircuit());
      expect(result.status, DcSolveStatus.singular);
      expect(
        result.diagnostics.whereType<DcSolverDiagnostic>().map((DcSolverDiagnostic d) => d.code),
        contains(DcDiagnosticCode.floatingElectricalIsland),
      );
    });

    test('DC-006A: current-limited source survives a direct wire short', () {
      final DcSolveResult result = solve(
        _directLimitedShortCircuit(currentLimitA: 5.0),
      );
      expect(result.status, DcSolveStatus.solved);
      expect(result.branch('source:v1').voltageV, closeTo(0.0, 1e-12));
      expect(result.branch('source:v1').currentA, closeTo(-5.0, 1e-12));
      expect(
        result.diagnostics.map((DcSolverDiagnostic d) => d.code),
        contains(DcDiagnosticCode.sourceCurrentLimited),
      );
    });

    test('DC-006B: current-limited source solves through an ideal short component', () {
      final DcSolveResult result = solve(
        _componentLimitedShortCircuit(currentLimitA: 5.0),
      );
      expect(result.status, DcSolveStatus.solved);
      expect(result.branch('source:v1').currentA, closeTo(-5.0, 1e-10));
      expect(result.branch('component:r1').kind, DcBranchKind.idealShort);
      expect(result.branch('component:r1').currentA, closeTo(5.0, 1e-10));
      expect(
        result.diagnostics.map((DcSolverDiagnostic d) => d.code),
        contains(DcDiagnosticCode.sourceCurrentLimited),
      );
      _expectPhysicalResiduals(result);
    });

    test('DC-006: shorted non-zero ideal voltage source is invalid, never arbitrary', () {
      final DcSolveResult result = solve(_shortedIdealSourceCircuit());
      expect(result.status, DcSolveStatus.invalid);
      expect(
        result.diagnostics.whereType<DcSolverDiagnostic>().map((DcSolverDiagnostic d) => d.code),
        contains(DcDiagnosticCode.contradictoryIdealSource),
      );
      expect(result.nodeVoltages, isEmpty);
    });
  });

  group('MNA behavior and determinism', () {
    test('closed ideal switch solves without magic resistance', () {
      final DcSolveResult result = solve(_switchCircuit(closed: true));
      expect(result.status, DcSolveStatus.solved);
      expect(result.branch('component:s1').kind, DcBranchKind.idealSwitch);
      expect(result.branch('component:s1').voltageV, closeTo(0.0, 1e-12));
      expect(result.branch('component:r1').currentA, closeTo(2.0, 1e-10));
      _expectPhysicalResiduals(result);
    });

    test('current source is stamped with explicit sign and KCL stays closed', () {
      final DcSolveResult result = solve(_currentSourceCircuit());
      expect(result.status, DcSolveStatus.solved);
      expect(result.branch('source:i1').currentA, closeTo(2.0, 1e-12));
      expect(result.branch('component:r1').currentA, closeTo(-2.0, 1e-10));
      expect(result.branch('component:r1').voltageV, closeTo(-20.0, 1e-10));
      _expectPhysicalResiduals(result);
    });

    test('same circuit and engine version produce identical electrical result', () {
      final CircuitState circuit = _seriesCircuit();
      final TopologyGraph topology = topologyEngine.compile(circuit);
      final DcSolveResult a = solver.solve(circuit, topology);
      final DcSolveResult b = solver.solve(circuit, topology);
      expect(a.engineVersion, b.engineVersion);
      expect(a.nodeVoltages, b.nodeVoltages);
      expect(
        a.branchResults.map(_branchSignature).toList(),
        b.branchResults.map(_branchSignature).toList(),
      );
      expect(a.kclResiduals, b.kclResiduals);
      expect(a.kvlResiduals, b.kvlResiduals);
    });

    test('topology revision mismatch is rejected', () {
      final CircuitState circuit = _singleResistor(voltage: 24, resistance: 12);
      final TopologyGraph original = topologyEngine.compile(circuit);
      final TopologyGraph wrong = TopologyGraph(
        circuitId: original.circuitId,
        circuitRevision: original.circuitRevision + 1,
        mode: original.mode,
        nodes: original.nodes,
        terminalToNode: original.terminalToNode,
        enabledConnectionIds: original.enabledConnectionIds,
        disabledConnectionIds: original.disabledConnectionIds,
        componentNodeIds: original.componentNodeIds,
        sourceNodeIds: original.sourceNodeIds,
        findings: original.findings,
      );
      final DcSolveResult result = solver.solve(circuit, wrong);
      expect(result.status, DcSolveStatus.invalid);
      expect(
        result.diagnostics.whereType<DcSolverDiagnostic>().map((DcSolverDiagnostic d) => d.code),
        contains(DcDiagnosticCode.topologyIdentityMismatch),
      );
    });

    test('unsupported model and malformed resistance fail explicitly', () {
      final CircuitState unsupported = _componentCircuit('mystery', const <String, Object?>{});
      final CircuitState badResistance = _componentCircuit(
        'resistor',
        const <String, Object?>{'resistanceOhm': 0.0},
      );
      expect(solve(unsupported).status, DcSolveStatus.invalid);
      expect(solve(badResistance).status, DcSolveStatus.invalid);
    });

    test('wrong mode and empty DC circuit are explicit failures', () {
      final CircuitState ac = CircuitState(
        circuitId: CircuitId('ac-not-dc'),
        revision: 0,
        mode: ElectricalMode.ac1,
        components: <ComponentInstance>[
          ComponentInstance(
            id: ComponentId('r'),
            modelType: 'resistor',
            terminals: <Terminal>[_terminal('a', 'A'), _terminal('b', 'B')],
            parameters: const <String, Object?>{'resistanceOhm': 10.0},
          ),
        ],
      );
      final DcSolveResult wrongMode = solver.solve(ac, topologyEngine.compile(ac));
      expect(wrongMode.status, DcSolveStatus.invalid);
      expect(wrongMode.diagnostics.map((DcSolverDiagnostic d) => d.code), contains(DcDiagnosticCode.wrongElectricalMode));

      final CircuitState empty = CircuitState(
        circuitId: CircuitId('empty'),
        revision: 0,
        mode: ElectricalMode.dc,
      );
      final DcSolveResult emptyResult = solver.solve(empty, topologyEngine.compile(empty));
      expect(emptyResult.status, DcSolveStatus.invalid);
      expect(emptyResult.diagnostics.map((DcSolverDiagnostic d) => d.code), contains(DcDiagnosticCode.emptyCircuit));
    });

    test('component terminal count, degraded state and switch control are validated', () {
      final CircuitState oneTerminal = CircuitState(
        circuitId: CircuitId('one-terminal'),
        revision: 0,
        mode: ElectricalMode.dc,
        components: <ComponentInstance>[
          ComponentInstance(
            id: ComponentId('x'),
            modelType: 'resistor',
            terminals: <Terminal>[_terminal('x1', 'only')],
            parameters: const <String, Object?>{'resistanceOhm': 10.0},
          ),
        ],
      );
      expect(solve(oneTerminal).status, DcSolveStatus.invalid);

      final CircuitState degraded = _conditionCircuit(ComponentCondition.degraded);
      final DcSolveResult degradedResult = solve(degraded);
      expect(degradedResult.status, DcSolveStatus.invalid);
      expect(degradedResult.diagnostics.map((DcSolverDiagnostic d) => d.code), contains(DcDiagnosticCode.unsupportedComponentCondition));

      final CircuitState missingControl = _componentCircuit('switch', const <String, Object?>{});
      final DcSolveResult switchResult = solve(missingControl);
      expect(switchResult.status, DcSolveStatus.invalid);
      expect(switchResult.diagnostics.map((DcSolverDiagnostic d) => d.code), contains(DcDiagnosticCode.invalidParameter));
    });

    test('open and disabled component conditions carry zero current', () {
      for (final ComponentCondition condition in <ComponentCondition>[
        ComponentCondition.openCircuit,
        ComponentCondition.disabled,
      ]) {
        final DcSolveResult result = solve(_conditionCircuit(condition));
        expect(result.status, DcSolveStatus.solved);
        expect(result.branch('component:r1').kind, DcBranchKind.openCircuit);
        expect(result.branch('component:r1').currentA, 0.0);
      }
    });

    test('source contracts reject bad terminal count, parameters and unknown models', () {
      final List<CircuitState> circuits = <CircuitState>[
        CircuitState(
          circuitId: CircuitId('bad-source-terminals'),
          revision: 0,
          mode: ElectricalMode.dc,
          sources: <SourceInstance>[
            SourceInstance(
              id: SourceId('v'),
              modelType: 'dc_voltage_source',
              terminals: <Terminal>[_terminal('vonly', '+')],
              parameters: const <String, Object?>{'voltageV': 12.0},
            ),
          ],
        ),
        _sourceContractCircuit('dc_voltage_source', const <String, Object?>{}),
        _sourceContractCircuit('dc_current_source', const <String, Object?>{}),
        _sourceContractCircuit('mystery_source', const <String, Object?>{}),
      ];
      for (final CircuitState circuit in circuits) {
        expect(solve(circuit).status, DcSolveStatus.invalid);
      }
    });

    test('zero-volt source on one node is redundant but solvable without fabricated current', () {
      final CircuitState circuit = CircuitState(
        circuitId: CircuitId('redundant-zero'),
        revision: 0,
        mode: ElectricalMode.dc,
        connections: <Connection>[
          Connection(id: ConnectionId('short'), fromTerminalId: TerminalId('z1'), toTerminalId: TerminalId('z2')),
        ],
        sources: <SourceInstance>[
          SourceInstance(
            id: SourceId('z'),
            modelType: 'dc_voltage_source',
            terminals: <Terminal>[_terminal('z1', 'A'), _terminal('z2', 'B')],
            parameters: const <String, Object?>{'voltageV': 0.0},
          ),
        ],
      );
      final DcSolveResult result = solve(circuit);
      expect(result.status, DcSolveStatus.solved);
      expect(result.branch('source:z').currentA, isNull);
      expect(result.diagnostics.map((DcSolverDiagnostic d) => d.code), contains(DcDiagnosticCode.redundantIdealConstraint));
    });

    test('reference node falls back deterministically when no source has negative metadata', () {
      final CircuitState circuit = CircuitState(
        circuitId: CircuitId('reference-fallback'),
        revision: 0,
        mode: ElectricalMode.dc,
        components: <ComponentInstance>[
          ComponentInstance(
            id: ComponentId('r'),
            modelType: 'resistor',
            terminals: <Terminal>[_terminal('a', 'A'), _terminal('b', 'B')],
            parameters: const <String, Object?>{'resistanceOhm': 10.0},
          ),
        ],
      );
      final DcSolveResult result = solve(circuit);
      expect(result.status, DcSolveStatus.solved);
      expect(result.referenceNodeId, isNotNull);
      expect(result.nodeVoltages.values.every((double value) => value == 0.0), isTrue);
    });

    test('relay NO contact follows explicit actuated state', () {
      final DcSolveResult open = solve(
        _relayContactCircuit(modelType: 'relay_contact_no', actuated: false),
      );
      expect(open.status, DcSolveStatus.solved);
      expect(open.branch('component:k1').currentA, 0.0);

      final DcSolveResult closed = solve(
        _relayContactCircuit(modelType: 'relay_contact_no', actuated: true),
      );
      expect(closed.status, DcSolveStatus.solved);
      expect(closed.branch('component:r1').currentA?.abs(), closeTo(2.0, 1e-9));
    });

    test('relay NC contact inverts the same canonical actuated state', () {
      final DcSolveResult closed = solve(
        _relayContactCircuit(modelType: 'relay_contact_nc', actuated: false),
      );
      expect(closed.status, DcSolveStatus.solved);
      expect(closed.branch('component:r1').currentA?.abs(), closeTo(2.0, 1e-9));

      final DcSolveResult open = solve(
        _relayContactCircuit(modelType: 'relay_contact_nc', actuated: true),
      );
      expect(open.status, DcSolveStatus.solved);
      expect(open.branch('component:k1').currentA, 0.0);
    });

    test('component condition shortCircuit is an ideal 0 V constraint', () {
      final CircuitState base = _singleResistor(voltage: 24, resistance: 12);
      final ComponentInstance resistor = base.components.single;
      final CircuitState circuit = CircuitState(
        circuitId: CircuitId('short-condition'),
        revision: 0,
        mode: ElectricalMode.dc,
        components: <ComponentInstance>[
          ComponentInstance(
            id: resistor.id,
            modelType: resistor.modelType,
            terminals: resistor.terminals,
            parameters: resistor.parameters,
            condition: ComponentCondition.shortCircuit,
          ),
        ],
        connections: base.connections,
        sources: base.sources,
      );
      final DcSolveResult result = solve(circuit);
      expect(result.status, DcSolveStatus.singular);
      expect(
        result.diagnostics.whereType<DcSolverDiagnostic>().map((DcSolverDiagnostic d) => d.code),
        contains(DcDiagnosticCode.singularMatrix),
      );
    });
  });
}

void _expectPhysicalResiduals(DcSolveResult result) {
  expect(result.maxMatrixResidual, isNotNull);
  expect(result.maxMatrixResidual!, lessThan(1e-9));
  for (final double residual in result.kclResiduals.values) {
    expect(residual.abs(), lessThan(1e-9));
  }
  for (final double residual in result.kvlResiduals.values) {
    expect(residual.abs(), lessThan(1e-9));
  }
}

String _branchSignature(DcBranchResult branch) =>
    '${branch.id}|${branch.voltageV}|${branch.currentA}|${branch.powerW}';

Terminal _terminal(String id, String name, {TerminalRole role = TerminalRole.generic, PhaseTag phase = PhaseTag.none}) =>
    Terminal(id: TerminalId(id), name: name, role: role, phase: phase);

SourceInstance _voltageSource(double voltage) => SourceInstance(
  id: SourceId('v1'),
  modelType: 'dc_voltage_source',
  terminals: <Terminal>[
    _terminal('vp', '+', role: TerminalRole.positive, phase: PhaseTag.dcPositive),
    _terminal('vn', '-', role: TerminalRole.negative, phase: PhaseTag.dcNegative),
  ],
  parameters: <String, Object?>{'voltageV': voltage},
);

CircuitState _singleResistor({required double voltage, required double resistance}) => CircuitState(
  circuitId: CircuitId('dc001'),
  revision: 0,
  mode: ElectricalMode.dc,
  components: <ComponentInstance>[
    ComponentInstance(
      id: ComponentId('r1'),
      modelType: 'resistor',
      terminals: <Terminal>[_terminal('r1a', 'A'), _terminal('r1b', 'B')],
      parameters: <String, Object?>{'resistanceOhm': resistance},
    ),
  ],
  connections: <Connection>[
    Connection(id: ConnectionId('w1'), fromTerminalId: TerminalId('vp'), toTerminalId: TerminalId('r1a')),
    Connection(id: ConnectionId('w2'), fromTerminalId: TerminalId('r1b'), toTerminalId: TerminalId('vn')),
  ],
  sources: <SourceInstance>[_voltageSource(voltage)],
);

CircuitState _seriesCircuit() => CircuitState(
  circuitId: CircuitId('dc002'),
  revision: 0,
  mode: ElectricalMode.dc,
  components: <ComponentInstance>[
    ComponentInstance(
      id: ComponentId('r1'),
      modelType: 'resistor',
      terminals: <Terminal>[_terminal('r1a', 'A'), _terminal('r1b', 'B')],
      parameters: const <String, Object?>{'resistanceOhm': 10.0},
    ),
    ComponentInstance(
      id: ComponentId('r2'),
      modelType: 'resistor',
      terminals: <Terminal>[_terminal('r2a', 'A'), _terminal('r2b', 'B')],
      parameters: const <String, Object?>{'resistanceOhm': 20.0},
    ),
  ],
  connections: <Connection>[
    Connection(id: ConnectionId('w1'), fromTerminalId: TerminalId('vp'), toTerminalId: TerminalId('r1a')),
    Connection(id: ConnectionId('w2'), fromTerminalId: TerminalId('r1b'), toTerminalId: TerminalId('r2a')),
    Connection(id: ConnectionId('w3'), fromTerminalId: TerminalId('r2b'), toTerminalId: TerminalId('vn')),
  ],
  sources: <SourceInstance>[_voltageSource(30)],
);

CircuitState _parallelCircuit() => CircuitState(
  circuitId: CircuitId('dc003'),
  revision: 0,
  mode: ElectricalMode.dc,
  components: <ComponentInstance>[
    for (final String id in <String>['r1', 'r2'])
      ComponentInstance(
        id: ComponentId(id),
        modelType: 'resistor',
        terminals: <Terminal>[_terminal('${id}a', 'A'), _terminal('${id}b', 'B')],
        parameters: const <String, Object?>{'resistanceOhm': 10.0},
      ),
  ],
  connections: <Connection>[
    Connection(id: ConnectionId('w1'), fromTerminalId: TerminalId('vp'), toTerminalId: TerminalId('r1a')),
    Connection(id: ConnectionId('w2'), fromTerminalId: TerminalId('vp'), toTerminalId: TerminalId('r2a')),
    Connection(id: ConnectionId('w3'), fromTerminalId: TerminalId('vn'), toTerminalId: TerminalId('r1b')),
    Connection(id: ConnectionId('w4'), fromTerminalId: TerminalId('vn'), toTerminalId: TerminalId('r2b')),
  ],
  sources: <SourceInstance>[_voltageSource(10)],
);

CircuitState _switchCircuit({required bool closed}) => CircuitState(
  circuitId: CircuitId('dc004-${closed ? 'closed' : 'open'}'),
  revision: 0,
  mode: ElectricalMode.dc,
  components: <ComponentInstance>[
    ComponentInstance(
      id: ComponentId('s1'),
      modelType: 'switch',
      terminals: <Terminal>[_terminal('s1a', 'A'), _terminal('s1b', 'B')],
      controlState: <String, Object?>{'closed': closed},
    ),
    ComponentInstance(
      id: ComponentId('r1'),
      modelType: 'resistor',
      terminals: <Terminal>[_terminal('r1a', 'A'), _terminal('r1b', 'B')],
      parameters: const <String, Object?>{'resistanceOhm': 12.0},
    ),
  ],
  connections: <Connection>[
    Connection(id: ConnectionId('w1'), fromTerminalId: TerminalId('vp'), toTerminalId: TerminalId('s1a')),
    Connection(id: ConnectionId('w2'), fromTerminalId: TerminalId('s1b'), toTerminalId: TerminalId('r1a')),
    Connection(id: ConnectionId('w3'), fromTerminalId: TerminalId('r1b'), toTerminalId: TerminalId('vn')),
  ],
  sources: <SourceInstance>[_voltageSource(24)],
);

CircuitState _relayContactCircuit({
  required String modelType,
  required bool actuated,
}) =>
    CircuitState(
      circuitId: CircuitId('relay-contact-$modelType-$actuated'),
      revision: 0,
      mode: ElectricalMode.dc,
      components: <ComponentInstance>[
        ComponentInstance(
          id: ComponentId('k1'),
          modelType: modelType,
          terminals: <Terminal>[
            _terminal('k1a', 'A'),
            _terminal('k1b', 'B'),
          ],
          controlState: <String, Object?>{'actuated': actuated},
        ),
        ComponentInstance(
          id: ComponentId('r1'),
          modelType: 'resistor',
          terminals: <Terminal>[
            _terminal('r1a', 'A'),
            _terminal('r1b', 'B'),
          ],
          parameters: const <String, Object?>{'resistanceOhm': 12.0},
        ),
      ],
      connections: <Connection>[
        Connection(
          id: ConnectionId('w1'),
          fromTerminalId: TerminalId('vp'),
          toTerminalId: TerminalId('k1a'),
        ),
        Connection(
          id: ConnectionId('w2'),
          fromTerminalId: TerminalId('k1b'),
          toTerminalId: TerminalId('r1a'),
        ),
        Connection(
          id: ConnectionId('w3'),
          fromTerminalId: TerminalId('r1b'),
          toTerminalId: TerminalId('vn'),
        ),
      ],
      sources: <SourceInstance>[_voltageSource(24)],
    );

CircuitState _floatingIslandCircuit() => CircuitState(
  circuitId: CircuitId('dc005'),
  revision: 0,
  mode: ElectricalMode.dc,
  components: <ComponentInstance>[
    ComponentInstance(
      id: ComponentId('load'),
      modelType: 'resistor',
      terminals: <Terminal>[_terminal('la', 'A'), _terminal('lb', 'B')],
      parameters: const <String, Object?>{'resistanceOhm': 10.0},
    ),
  ],
  sources: <SourceInstance>[_voltageSource(24)],
);

CircuitState _directLimitedShortCircuit({
  required double currentLimitA,
}) =>
    CircuitState(
      circuitId: CircuitId('dc-limited-direct-short'),
      revision: 0,
      mode: ElectricalMode.dc,
      connections: <Connection>[
        Connection(
          id: ConnectionId('short'),
          fromTerminalId: TerminalId('vp'),
          toTerminalId: TerminalId('vn'),
        ),
      ],
      sources: <SourceInstance>[
        SourceInstance(
          id: SourceId('v1'),
          modelType: 'dc_voltage_source',
          terminals: <Terminal>[
            _terminal(
              'vp',
              '+',
              role: TerminalRole.positive,
              phase: PhaseTag.dcPositive,
            ),
            _terminal(
              'vn',
              '-',
              role: TerminalRole.negative,
              phase: PhaseTag.dcNegative,
            ),
          ],
          parameters: <String, Object?>{
            'voltageV': 24.0,
            'currentLimitA': currentLimitA,
          },
        ),
      ],
    );

CircuitState _componentLimitedShortCircuit({
  required double currentLimitA,
}) {
  final CircuitState base = _singleResistor(voltage: 24, resistance: 12);
  final ComponentInstance resistor = base.components.single;
  return CircuitState(
    circuitId: CircuitId('dc-limited-component-short'),
    revision: 0,
    mode: ElectricalMode.dc,
    components: <ComponentInstance>[
      ComponentInstance(
        id: resistor.id,
        modelType: resistor.modelType,
        terminals: resistor.terminals,
        parameters: resistor.parameters,
        condition: ComponentCondition.shortCircuit,
      ),
    ],
    connections: base.connections,
    sources: <SourceInstance>[
      SourceInstance(
        id: SourceId('v1'),
        modelType: 'dc_voltage_source',
        terminals: <Terminal>[
          _terminal(
            'vp',
            '+',
            role: TerminalRole.positive,
            phase: PhaseTag.dcPositive,
          ),
          _terminal(
            'vn',
            '-',
            role: TerminalRole.negative,
            phase: PhaseTag.dcNegative,
          ),
        ],
        parameters: <String, Object?>{
          'voltageV': 24.0,
          'currentLimitA': currentLimitA,
        },
      ),
    ],
  );
}

CircuitState _shortedIdealSourceCircuit() => CircuitState(
  circuitId: CircuitId('dc006'),
  revision: 0,
  mode: ElectricalMode.dc,
  connections: <Connection>[
    Connection(id: ConnectionId('short'), fromTerminalId: TerminalId('vp'), toTerminalId: TerminalId('vn')),
  ],
  sources: <SourceInstance>[_voltageSource(24)],
);

CircuitState _currentSourceCircuit() => CircuitState(
  circuitId: CircuitId('current-source'),
  revision: 0,
  mode: ElectricalMode.dc,
  components: <ComponentInstance>[
    ComponentInstance(
      id: ComponentId('r1'),
      modelType: 'resistor',
      terminals: <Terminal>[_terminal('ra', 'A'), _terminal('rb', 'B')],
      parameters: const <String, Object?>{'resistanceOhm': 10.0},
    ),
  ],
  connections: <Connection>[
    Connection(id: ConnectionId('w1'), fromTerminalId: TerminalId('ia'), toTerminalId: TerminalId('ra')),
    Connection(id: ConnectionId('w2'), fromTerminalId: TerminalId('ib'), toTerminalId: TerminalId('rb')),
  ],
  sources: <SourceInstance>[
    SourceInstance(
      id: SourceId('i1'),
      modelType: 'dc_current_source',
      terminals: <Terminal>[
        _terminal('ia', 'from', role: TerminalRole.positive),
        _terminal('ib', 'to', role: TerminalRole.negative, phase: PhaseTag.dcNegative),
      ],
      parameters: const <String, Object?>{'currentA': 2.0},
    ),
  ],
);

CircuitState _conditionCircuit(ComponentCondition condition) {
  final CircuitState base = _singleResistor(voltage: 24, resistance: 12);
  final ComponentInstance original = base.components.single;
  return CircuitState(
    circuitId: CircuitId('condition-${condition.name}'),
    revision: 0,
    mode: ElectricalMode.dc,
    components: <ComponentInstance>[
      ComponentInstance(
        id: original.id,
        modelType: original.modelType,
        terminals: original.terminals,
        parameters: original.parameters,
        condition: condition,
      ),
    ],
    connections: base.connections,
    sources: base.sources,
  );
}

CircuitState _sourceContractCircuit(String modelType, Map<String, Object?> parameters) => CircuitState(
  circuitId: CircuitId('source-contract-$modelType'),
  revision: 0,
  mode: ElectricalMode.dc,
  components: <ComponentInstance>[
    ComponentInstance(
      id: ComponentId('r'),
      modelType: 'resistor',
      terminals: <Terminal>[_terminal('ra', 'A'), _terminal('rb', 'B')],
      parameters: const <String, Object?>{'resistanceOhm': 10.0},
    ),
  ],
  connections: <Connection>[
    Connection(id: ConnectionId('w1'), fromTerminalId: TerminalId('sa'), toTerminalId: TerminalId('ra')),
    Connection(id: ConnectionId('w2'), fromTerminalId: TerminalId('sb'), toTerminalId: TerminalId('rb')),
  ],
  sources: <SourceInstance>[
    SourceInstance(
      id: SourceId('s'),
      modelType: modelType,
      terminals: <Terminal>[
        _terminal('sa', 'A', role: TerminalRole.positive),
        _terminal('sb', 'B', role: TerminalRole.negative, phase: PhaseTag.dcNegative),
      ],
      parameters: parameters,
    ),
  ],
);

CircuitState _componentCircuit(String modelType, Map<String, Object?> parameters) => CircuitState(
  circuitId: CircuitId('component-contract'),
  revision: 0,
  mode: ElectricalMode.dc,
  components: <ComponentInstance>[
    ComponentInstance(
      id: ComponentId('x'),
      modelType: modelType,
      terminals: <Terminal>[_terminal('xa', 'A'), _terminal('xb', 'B')],
      parameters: parameters,
    ),
  ],
  connections: <Connection>[
    Connection(id: ConnectionId('w1'), fromTerminalId: TerminalId('vp'), toTerminalId: TerminalId('xa')),
    Connection(id: ConnectionId('w2'), fromTerminalId: TerminalId('xb'), toTerminalId: TerminalId('vn')),
  ],
  sources: <SourceInstance>[_voltageSource(12)],
);
