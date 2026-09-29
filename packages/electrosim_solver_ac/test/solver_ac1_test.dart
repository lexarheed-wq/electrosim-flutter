import 'dart:math' as math;

import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:electrosim_solver_ac/electrosim_solver_ac.dart';
import 'package:electrosim_topology/electrosim_topology.dart';
import 'package:test/test.dart';

void main() {
  const SolverAC1 solver = SolverAC1();
  const TopologyEngine topologyEngine = TopologyEngine();

  Ac1SolveResult solve(CircuitState circuit) => solver.solve(circuit, topologyEngine.compile(circuit));

  group('AcComplex', () {
    test('polar representation and arithmetic preserve RMS phasor angle and magnitude', () {
      final AcComplex a = AcComplex.polar(10.0, math.pi / 6.0);
      expect(a.magnitude, closeTo(10.0, 1e-12));
      expect(a.angleDegrees, closeTo(30.0, 1e-12));
      expect(a.conjugate.angleDegrees, closeTo(-30.0, 1e-12));
      expect((a + const AcComplex(1.0, 2.0)) - const AcComplex(1.0, 2.0), a);
      final AcComplex product = const AcComplex(2.0, 3.0) * const AcComplex(4.0, -1.0);
      expect(product.real, closeTo(11.0, 1e-12));
      expect(product.imaginary, closeTo(10.0, 1e-12));
      final AcComplex quotient = product / const AcComplex(2.0, 3.0);
      expect(quotient.real, closeTo(4.0, 1e-12));
      expect(quotient.imaginary, closeTo(-1.0, 1e-12));
      expect((-a).real, closeTo(-a.real, 1e-12));
      expect(a.scale(2.0).magnitude, closeTo(20.0, 1e-12));
      expect(a.isFinite, isTrue);
      expect(AcComplex.zero.toString(), contains('AcComplex'));
      expect(() => AcComplex.one / AcComplex.zero, throwsStateError);
    });
  });

  group('canonical AC1 cases', () {
    test('AC1-001 resistive load gives Q≈0, cosφ≈1 and in-phase current', () {
      final Ac1SolveResult result = solve(_singleLoad('resistor', const <String, Object?>{'resistanceOhm': 46.0}));
      expect(result.status, Ac1SolveStatus.solved);
      expect(result.frequencyHz, 50.0);
      final Ac1BranchResult load = result.branch('component:load');
      expect(load.voltage.magnitude, closeTo(230.0, 1e-9));
      expect(load.current!.magnitude, closeTo(5.0, 1e-9));
      expect(load.current!.angleDegrees, closeTo(0.0, 1e-9));
      expect(load.activePowerW, closeTo(1150.0, 1e-7));
      expect(load.reactivePowerVar, closeTo(0.0, 1e-7));
      expect(load.apparentPowerVA, closeTo(1150.0, 1e-7));
      expect(load.powerFactor, closeTo(1.0, 1e-12));
      _expectResiduals(result);
    });

    test('AC1-002 inductive load has positive Q and lagging current', () {
      final Ac1SolveResult result = solve(_singleLoad('inductor', const <String, Object?>{'inductanceH': 0.1}));
      expect(result.status, Ac1SolveStatus.solved);
      final Ac1BranchResult load = result.branch('component:load');
      expect(load.current!.angleDegrees, closeTo(-90.0, 1e-9));
      expect(load.reactivePowerVar!, greaterThan(0.0));
      expect(load.activePowerW, closeTo(0.0, 1e-7));
      expect(load.powerFactor, closeTo(0.0, 1e-12));
      _expectResiduals(result);
    });

    test('capacitive load has negative Q and leading current', () {
      final Ac1SolveResult result = solve(_singleLoad('capacitor', const <String, Object?>{'capacitanceF': 0.0001}));
      expect(result.status, Ac1SolveStatus.solved);
      final Ac1BranchResult load = result.branch('component:load');
      expect(load.current!.angleDegrees, closeTo(90.0, 1e-9));
      expect(load.reactivePowerVar!, lessThan(0.0));
      expect(load.activePowerW, closeTo(0.0, 1e-7));
      _expectResiduals(result);
    });

    test('series R-L uses complex impedance and produces a -45 degree current', () {
      final double inductance = 10.0 / (2.0 * math.pi * 50.0);
      final CircuitState circuit = _seriesRl(inductance);
      final Ac1SolveResult result = solve(circuit);
      expect(result.status, Ac1SolveStatus.solved);
      final Ac1BranchResult resistor = result.branch('component:r');
      final Ac1BranchResult inductor = result.branch('component:l');
      expect(resistor.current!.magnitude, closeTo(math.sqrt(50.0), 1e-8));
      expect(resistor.current!.angleDegrees, closeTo(-45.0, 1e-8));
      expect(inductor.current!.angleDegrees, closeTo(-45.0, 1e-8));
      expect(resistor.activePowerW, closeTo(500.0, 1e-7));
      expect(inductor.reactivePowerVar, closeTo(500.0, 1e-7));
      _expectResiduals(result);
    });

    test('explicit impedance model preserves R+jX and source phase is respected', () {
      final CircuitState circuit = _singleLoad(
        'impedance',
        const <String, Object?>{'resistanceOhm': 10.0, 'reactanceOhm': 10.0},
        voltage: 100.0,
        phaseDeg: 30.0,
      );
      final Ac1SolveResult result = solve(circuit);
      expect(result.status, Ac1SolveStatus.solved);
      final Ac1BranchResult load = result.branch('component:load');
      expect(load.voltage.angleDegrees, closeTo(30.0, 1e-8));
      expect(load.current!.angleDegrees, closeTo(-15.0, 1e-8));
      expect(load.powerFactor, closeTo(math.sqrt(0.5), 1e-9));
    });

    test('AC current source is solved as a phasor source', () {
      final CircuitState circuit = _currentSourceLoad();
      final Ac1SolveResult result = solve(circuit);
      expect(result.status, Ac1SolveStatus.solved);
      final Ac1BranchResult resistor = result.branch('component:r');
      expect(resistor.current!.magnitude, closeTo(2.0, 1e-9));
      expect(resistor.voltage.magnitude, closeTo(20.0, 1e-9));
      expect(resistor.activePowerW, closeTo(40.0, 1e-8));
    });

    test('same input is deterministic', () {
      final CircuitState circuit = _singleLoad('resistor', const <String, Object?>{'resistanceOhm': 46.0});
      final Ac1SolveResult first = solve(circuit);
      final Ac1SolveResult second = solve(circuit);
      expect(first.nodeVoltages, second.nodeVoltages);
      expect(first.branchResults.map(_signature).toList(), second.branchResults.map(_signature).toList());
    });
  });

  group('AC1 contract failures', () {
    test('wrong mode is rejected', () {
      final CircuitState circuit = CircuitState(circuitId: CircuitId('wrong'), revision: 0, mode: ElectricalMode.dc);
      final Ac1SolveResult result = solver.solve(circuit, topologyEngine.compile(circuit));
      expect(result.status, Ac1SolveStatus.invalid);
      expect(result.diagnostics.single.code, Ac1DiagnosticCode.wrongElectricalMode);
    });

    test('topology identity/revision mismatch is rejected', () {
      final CircuitState original = _singleLoad('resistor', const <String, Object?>{'resistanceOhm': 46.0});
      final CircuitState changed = CircuitState(
        circuitId: original.circuitId,
        revision: 1,
        mode: original.mode,
        components: original.components,
        connections: original.connections,
        sources: original.sources,
        settings: original.settings,
      );
      final Ac1SolveResult result = solver.solve(changed, topologyEngine.compile(original));
      expect(result.status, Ac1SolveStatus.invalid);
      expect(result.diagnostics.single.code, Ac1DiagnosticCode.topologyIdentityMismatch);
    });

    test('empty circuit, missing frequency and invalid frequency are explicit failures', () {
      final CircuitState empty = CircuitState(
        circuitId: CircuitId('empty'),
        revision: 0,
        mode: ElectricalMode.ac1,
        settings: const <String, Object?>{'frequencyHz': 50.0},
      );
      expect(solve(empty).diagnostics.single.code, Ac1DiagnosticCode.emptyCircuit);

      final CircuitState missing = _singleLoad('resistor', const <String, Object?>{'resistanceOhm': 10.0}, includeFrequency: false);
      expect(solve(missing).diagnostics.map((Ac1SolverDiagnostic d) => d.code), contains(Ac1DiagnosticCode.missingFrequency));

      for (final Object value in <Object>[-50.0, '50']) {
        final CircuitState bad = _singleLoad('resistor', const <String, Object?>{'resistanceOhm': 10.0}, frequencyValue: value);
        expect(solve(bad).diagnostics.map((Ac1SolverDiagnostic d) => d.code), contains(Ac1DiagnosticCode.invalidFrequency));
      }
    });

    test('topology phase conflict is propagated as an AC1 topology error', () {
      final CircuitState circuit = CircuitState(
        circuitId: CircuitId('phase-conflict'),
        revision: 0,
        mode: ElectricalMode.ac1,
        components: <ComponentInstance>[
          ComponentInstance(
            id: ComponentId('r'),
            modelType: 'resistor',
            terminals: <Terminal>[
              _terminal('a', 'A', phase: PhaseTag.l1),
              _terminal('b', 'B', phase: PhaseTag.neutral),
            ],
            parameters: const <String, Object?>{'resistanceOhm': 10.0},
          ),
        ],
        connections: <Connection>[
          Connection(id: ConnectionId('bad'), fromTerminalId: TerminalId('a'), toTerminalId: TerminalId('b')),
        ],
        settings: const <String, Object?>{'frequencyHz': 50.0},
      );
      final Ac1SolveResult result = solve(circuit);
      expect(result.status, Ac1SolveStatus.invalid);
      expect(result.diagnostics.map((Ac1SolverDiagnostic d) => d.code), contains(Ac1DiagnosticCode.topologyError));
    });

    test('bad component terminal count, conditions, models and parameters are rejected', () {
      final List<CircuitState> circuits = <CircuitState>[
        _oneTerminalComponent(),
        _componentCondition(ComponentCondition.degraded),
        _singleLoad('mystery', const <String, Object?>{}),
        _singleLoad('resistor', const <String, Object?>{'resistanceOhm': 0.0}),
        _singleLoad('inductor', const <String, Object?>{'inductanceH': -1.0}),
        _singleLoad('capacitor', const <String, Object?>{'capacitanceF': 0.0}),
        _singleLoad('impedance', const <String, Object?>{'resistanceOhm': 0.0, 'reactanceOhm': 0.0}),
      ];
      for (final CircuitState circuit in circuits) {
        expect(solve(circuit).status, Ac1SolveStatus.invalid);
      }
    });

    test('bad source terminal count, model and phasor parameters are rejected', () {
      final List<CircuitState> circuits = <CircuitState>[
        _badSource(oneTerminal: true),
        _badSource(modelType: 'mystery_source'),
        _badSource(parameters: const <String, Object?>{}),
        _badSource(parameters: const <String, Object?>{'voltageRmsV': -1.0, 'phaseDeg': 0.0}),
        _badSource(modelType: 'ac_current_source', parameters: const <String, Object?>{'currentRmsA': 'x'}),
      ];
      for (final CircuitState circuit in circuits) {
        expect(solve(circuit).status, Ac1SolveStatus.invalid);
      }
    });

    test('separate electrical island is reported before solve', () {
      final CircuitState base = _singleLoad('resistor', const <String, Object?>{'resistanceOhm': 46.0});
      final CircuitState circuit = CircuitState(
        circuitId: CircuitId('floating'),
        revision: 0,
        mode: ElectricalMode.ac1,
        components: <ComponentInstance>[
          ...base.components,
          ComponentInstance(
            id: ComponentId('island'),
            modelType: 'resistor',
            terminals: <Terminal>[_terminal('ia', 'A'), _terminal('ib', 'B')],
            parameters: const <String, Object?>{'resistanceOhm': 5.0},
          ),
        ],
        connections: base.connections,
        sources: base.sources,
        settings: base.settings,
      );
      final Ac1SolveResult result = solve(circuit);
      expect(result.status, Ac1SolveStatus.singular);
      expect(result.diagnostics.map((Ac1SolverDiagnostic d) => d.code), contains(Ac1DiagnosticCode.floatingElectricalIsland));
    });

    test('parallel ideal voltage constraints expose a singular MNA system', () {
      final CircuitState circuit = _parallelVoltageSources();
      final Ac1SolveResult result = solve(circuit);
      expect(result.status, Ac1SolveStatus.singular);
      expect(result.diagnostics.map((Ac1SolverDiagnostic d) => d.code), contains(Ac1DiagnosticCode.singularMatrix));
    });

    test('open and disabled conditions produce an explicit zero-current branch', () {
      for (final ComponentCondition condition in <ComponentCondition>[ComponentCondition.openCircuit, ComponentCondition.disabled]) {
        final Ac1SolveResult result = solve(_componentCondition(condition));
        expect(result.status, Ac1SolveStatus.solved);
        final Ac1BranchResult branch = result.branch('component:load');
        expect(branch.kind, Ac1BranchKind.openCircuit);
        expect(branch.current, AcComplex.zero);
      }
    });


    test('short-circuit component becomes a 0 V ideal constraint', () {
      final Ac1SolveResult result = solve(_componentCondition(ComponentCondition.shortCircuit));
      expect(result.status, Ac1SolveStatus.singular);
      expect(result.diagnostics.map((Ac1SolverDiagnostic d) => d.code), contains(Ac1DiagnosticCode.singularMatrix));
    });

    test('very small explicit impedance is promoted to an ideal short constraint', () {
      final Ac1SolveResult result = solve(
        _singleLoad('impedance', const <String, Object?>{'resistanceOhm': 1e-20, 'reactanceOhm': 0.0}),
      );
      expect(result.status, Ac1SolveStatus.singular);
      expect(result.diagnostics.map((Ac1SolverDiagnostic d) => d.code), contains(Ac1DiagnosticCode.singularMatrix));
    });

    test('zero-voltage source exercises zero-power factor semantics', () {
      final Ac1SolveResult result = solve(
        _singleLoad('resistor', const <String, Object?>{'resistanceOhm': 10.0}, voltage: 0.0),
      );
      expect(result.status, Ac1SolveStatus.solved);
      final Ac1BranchResult load = result.branch('component:load');
      expect(load.apparentPowerVA, closeTo(0.0, 1e-12));
      expect(load.powerFactor, 1.0);
    });

    test('voltage source without a load uses pivot swapping and solves zero current', () {
      final CircuitState circuit = CircuitState(
        circuitId: CircuitId('source-only'),
        revision: 0,
        mode: ElectricalMode.ac1,
        sources: <SourceInstance>[_voltageSource(12.0)],
        settings: const <String, Object?>{'frequencyHz': 50.0},
      );
      final Ac1SolveResult result = solve(circuit);
      expect(result.status, Ac1SolveStatus.solved);
      expect(result.branch('source:v1').current!.magnitude, closeTo(0.0, 1e-12));
    });

    test('self-loop passive circuit uses deterministic reference fallback and empty MNA', () {
      final CircuitState circuit = CircuitState(
        circuitId: CircuitId('passive-self-loop'),
        revision: 0,
        mode: ElectricalMode.ac1,
        components: <ComponentInstance>[
          ComponentInstance(
            id: ComponentId('r'),
            modelType: 'resistor',
            terminals: <Terminal>[_terminal('ra', 'A'), _terminal('rb', 'B')],
            parameters: const <String, Object?>{'resistanceOhm': 10.0},
          ),
        ],
        connections: <Connection>[
          Connection(id: ConnectionId('loop'), fromTerminalId: TerminalId('ra'), toTerminalId: TerminalId('rb')),
        ],
        settings: const <String, Object?>{'frequencyHz': 50.0},
      );
      final Ac1SolveResult result = solve(circuit);
      expect(result.status, Ac1SolveStatus.solved);
      expect(result.referenceNodeId, isNotNull);
      expect(result.branch('component:r').current, AcComplex.zero);
    });

    test('disabled source is omitted and passive network settles at zero potential', () {
      final CircuitState circuit = CircuitState(
        circuitId: CircuitId('disabled-source'),
        revision: 0,
        mode: ElectricalMode.ac1,
        components: <ComponentInstance>[
          ComponentInstance(
            id: ComponentId('r'),
            modelType: 'resistor',
            terminals: <Terminal>[_terminal('ra', 'A'), _terminal('rb', 'B')],
            parameters: const <String, Object?>{'resistanceOhm': 10.0},
          ),
        ],
        connections: <Connection>[
          Connection(id: ConnectionId('w1'), fromTerminalId: TerminalId('vp'), toTerminalId: TerminalId('ra')),
          Connection(id: ConnectionId('w2'), fromTerminalId: TerminalId('rb'), toTerminalId: TerminalId('vn')),
        ],
        sources: <SourceInstance>[
          SourceInstance(
            id: SourceId('v'),
            modelType: 'ac_voltage_source',
            terminals: <Terminal>[_terminal('vp', 'P'), _terminal('vn', 'N')],
            parameters: const <String, Object?>{'voltageRmsV': 230.0},
            enabled: false,
          ),
        ],
        settings: const <String, Object?>{'frequencyHz': 50.0},
      );
      final Ac1SolveResult result = solve(circuit);
      expect(result.status, Ac1SolveStatus.solved);
      expect(result.branchResults.map((Ac1BranchResult b) => b.id), isNot(contains('source:v')));
    });
  });
}

void _expectResiduals(Ac1SolveResult result) {
  expect(result.maxMatrixResidual, isNotNull);
  expect(result.maxMatrixResidual!, lessThan(1e-9));
  for (final double residual in result.kclResiduals.values) {
    expect(residual, lessThan(1e-9));
  }
}

String _signature(Ac1BranchResult branch) =>
    '${branch.id}|${branch.voltage.real}|${branch.voltage.imaginary}|${branch.current?.real}|${branch.current?.imaginary}';

Terminal _terminal(String id, String name, {PhaseTag phase = PhaseTag.none}) =>
    Terminal(id: TerminalId(id), name: name, phase: phase);

SourceInstance _voltageSource(double voltage, {double phaseDeg = 0.0, String id = 'v1'}) => SourceInstance(
  id: SourceId(id),
  modelType: 'ac_voltage_source',
  terminals: <Terminal>[_terminal('${id}p', 'L'), _terminal('${id}n', 'N')],
  parameters: <String, Object?>{'voltageRmsV': voltage, 'phaseDeg': phaseDeg},
);

CircuitState _singleLoad(
  String modelType,
  Map<String, Object?> parameters, {
  double voltage = 230.0,
  double phaseDeg = 0.0,
  bool includeFrequency = true,
  Object frequencyValue = 50.0,
}) => CircuitState(
  circuitId: CircuitId('ac1-$modelType-$voltage-$phaseDeg-${parameters.hashCode}'),
  revision: 0,
  mode: ElectricalMode.ac1,
  components: <ComponentInstance>[
    ComponentInstance(
      id: ComponentId('load'),
      modelType: modelType,
      terminals: <Terminal>[_terminal('la', 'A'), _terminal('lb', 'B')],
      parameters: parameters,
    ),
  ],
  connections: <Connection>[
    Connection(id: ConnectionId('w1'), fromTerminalId: TerminalId('v1p'), toTerminalId: TerminalId('la')),
    Connection(id: ConnectionId('w2'), fromTerminalId: TerminalId('lb'), toTerminalId: TerminalId('v1n')),
  ],
  sources: <SourceInstance>[_voltageSource(voltage, phaseDeg: phaseDeg)],
  settings: includeFrequency ? <String, Object?>{'frequencyHz': frequencyValue} : const <String, Object?>{},
);

CircuitState _seriesRl(double inductance) => CircuitState(
  circuitId: CircuitId('ac1-series-rl'),
  revision: 0,
  mode: ElectricalMode.ac1,
  components: <ComponentInstance>[
    ComponentInstance(
      id: ComponentId('r'),
      modelType: 'resistor',
      terminals: <Terminal>[_terminal('ra', 'A'), _terminal('rb', 'B')],
      parameters: const <String, Object?>{'resistanceOhm': 10.0},
    ),
    ComponentInstance(
      id: ComponentId('l'),
      modelType: 'inductor',
      terminals: <Terminal>[_terminal('la', 'A'), _terminal('lb', 'B')],
      parameters: <String, Object?>{'inductanceH': inductance},
    ),
  ],
  connections: <Connection>[
    Connection(id: ConnectionId('w1'), fromTerminalId: TerminalId('v1p'), toTerminalId: TerminalId('ra')),
    Connection(id: ConnectionId('w2'), fromTerminalId: TerminalId('rb'), toTerminalId: TerminalId('la')),
    Connection(id: ConnectionId('w3'), fromTerminalId: TerminalId('lb'), toTerminalId: TerminalId('v1n')),
  ],
  sources: <SourceInstance>[_voltageSource(100.0)],
  settings: const <String, Object?>{'frequencyHz': 50.0},
);

CircuitState _currentSourceLoad() => CircuitState(
  circuitId: CircuitId('ac1-current-source'),
  revision: 0,
  mode: ElectricalMode.ac1,
  components: <ComponentInstance>[
    ComponentInstance(
      id: ComponentId('r'),
      modelType: 'resistor',
      terminals: <Terminal>[_terminal('ra', 'A'), _terminal('rb', 'B')],
      parameters: const <String, Object?>{'resistanceOhm': 10.0},
    ),
  ],
  connections: <Connection>[
    Connection(id: ConnectionId('w1'), fromTerminalId: TerminalId('ip'), toTerminalId: TerminalId('ra')),
    Connection(id: ConnectionId('w2'), fromTerminalId: TerminalId('rb'), toTerminalId: TerminalId('in')),
  ],
  sources: <SourceInstance>[
    SourceInstance(
      id: SourceId('i'),
      modelType: 'ac_current_source',
      terminals: <Terminal>[_terminal('ip', 'A'), _terminal('in', 'B')],
      parameters: const <String, Object?>{'currentRmsA': 2.0, 'phaseDeg': 0.0},
    ),
  ],
  settings: const <String, Object?>{'frequencyHz': 50.0},
);

CircuitState _oneTerminalComponent() => CircuitState(
  circuitId: CircuitId('one-terminal'),
  revision: 0,
  mode: ElectricalMode.ac1,
  components: <ComponentInstance>[
    ComponentInstance(
      id: ComponentId('r'),
      modelType: 'resistor',
      terminals: <Terminal>[_terminal('r1', 'A')],
      parameters: const <String, Object?>{'resistanceOhm': 10.0},
    ),
  ],
  sources: <SourceInstance>[_voltageSource(10.0)],
  settings: const <String, Object?>{'frequencyHz': 50.0},
);

CircuitState _componentCondition(ComponentCondition condition) {
  final CircuitState base = _singleLoad('resistor', const <String, Object?>{'resistanceOhm': 10.0});
  final ComponentInstance c = base.components.single;
  return CircuitState(
    circuitId: CircuitId('condition-${condition.name}'),
    revision: 0,
    mode: ElectricalMode.ac1,
    components: <ComponentInstance>[
      ComponentInstance(
        id: c.id,
        modelType: c.modelType,
        terminals: c.terminals,
        parameters: c.parameters,
        condition: condition,
      ),
    ],
    connections: base.connections,
    sources: base.sources,
    settings: base.settings,
  );
}

CircuitState _badSource({
  bool oneTerminal = false,
  String modelType = 'ac_voltage_source',
  Map<String, Object?> parameters = const <String, Object?>{'voltageRmsV': 10.0, 'phaseDeg': 0.0},
}) {
  final List<Terminal> sourceTerminals = oneTerminal
      ? <Terminal>[_terminal('sp', 'P')]
      : <Terminal>[_terminal('sp', 'P'), _terminal('sn', 'N')];
  return CircuitState(
    circuitId: CircuitId('bad-source-$modelType-$oneTerminal-${parameters.hashCode}'),
    revision: 0,
    mode: ElectricalMode.ac1,
    components: <ComponentInstance>[
      ComponentInstance(
        id: ComponentId('r'),
        modelType: 'resistor',
        terminals: <Terminal>[_terminal('ra', 'A'), _terminal('rb', 'B')],
        parameters: const <String, Object?>{'resistanceOhm': 10.0},
      ),
    ],
    connections: oneTerminal
        ? const <Connection>[]
        : <Connection>[
            Connection(id: ConnectionId('w1'), fromTerminalId: TerminalId('sp'), toTerminalId: TerminalId('ra')),
            Connection(id: ConnectionId('w2'), fromTerminalId: TerminalId('rb'), toTerminalId: TerminalId('sn')),
          ],
    sources: <SourceInstance>[
      SourceInstance(id: SourceId('s'), modelType: modelType, terminals: sourceTerminals, parameters: parameters),
    ],
    settings: const <String, Object?>{'frequencyHz': 50.0},
  );
}

CircuitState _parallelVoltageSources() => CircuitState(
  circuitId: CircuitId('parallel-vsources'),
  revision: 0,
  mode: ElectricalMode.ac1,
  connections: <Connection>[
    Connection(id: ConnectionId('p'), fromTerminalId: TerminalId('v1p'), toTerminalId: TerminalId('v2p')),
    Connection(id: ConnectionId('n'), fromTerminalId: TerminalId('v1n'), toTerminalId: TerminalId('v2n')),
  ],
  sources: <SourceInstance>[_voltageSource(10.0), _voltageSource(10.0, id: 'v2')],
  settings: const <String, Object?>{'frequencyHz': 50.0},
);
