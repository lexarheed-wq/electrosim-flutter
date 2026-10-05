import 'dart:math' as math;

import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:electrosim_solver_ac/electrosim_solver_ac.dart';
import 'package:electrosim_topology/electrosim_topology.dart';
import 'package:test/test.dart';

void main() {
  const SolverAC3 solver = SolverAC3();
  const TopologyEngine topologyEngine = TopologyEngine();

  Ac3SolveResult solve(CircuitState circuit) =>
      solver.solve(circuit, topologyEngine.compile(circuit));

  group('SolverAC3', () {
    test(
      'AC3-001 balanced star has explicit L1/L2/L3/N and balanced currents',
      () {
        final Ac3SolveResult result = solve(_starCircuit());
        expect(result.status, Ac3SolveStatus.solved);
        expect(result.sourceSequence, Ac3PhaseSequence.positive);
        expect(result.voltageBalanced, isTrue);
        expect(result.currentBalanced, isTrue);
        expect(result.neutralConnected, isTrue);
        expect(result.missingPhases, isEmpty);
        expect(
          result.phaseVoltage(PhaseTag.l1)!.magnitude,
          closeTo(230.0, 1e-8),
        );
        expect(
          result.phaseVoltage(PhaseTag.l2)!.magnitude,
          closeTo(230.0, 1e-8),
        );
        expect(
          result.phaseVoltage(PhaseTag.l3)!.magnitude,
          closeTo(230.0, 1e-8),
        );
        expect(result.lineCurrent(PhaseTag.l1).magnitude, closeTo(10.0, 1e-8));
        expect(result.lineCurrent(PhaseTag.l2).magnitude, closeTo(10.0, 1e-8));
        expect(result.lineCurrent(PhaseTag.l3).magnitude, closeTo(10.0, 1e-8));
        expect(result.neutralCurrent.magnitude, lessThan(1e-8));
        expect(
          result.lineToLineVoltages['L1-L2']!.magnitude,
          closeTo(230.0 * math.sqrt(3.0), 1e-8),
        );
        _expectResiduals(result);
      },
    );

    test('balanced delta is solved from three real line-to-line branches', () {
      final Ac3SolveResult result = solve(_deltaCircuit());
      expect(result.status, Ac3SolveStatus.solved);
      expect(result.neutralConnected, isFalse);
      expect(result.currentBalanced, isTrue);
      expect(
        result.branch('component:d12').current!.magnitude,
        closeTo(10.0, 1e-8),
      );
      expect(
        result.branch('component:d23').current!.magnitude,
        closeTo(10.0, 1e-8),
      );
      expect(
        result.branch('component:d31').current!.magnitude,
        closeTo(10.0, 1e-8),
      );
      expect(
        result.lineCurrent(PhaseTag.l1).magnitude,
        closeTo(10.0 * math.sqrt(3.0), 1e-8),
      );
      expect(result.neutralCurrent.magnitude, lessThan(1e-8));
      _expectResiduals(result);
    });

    test(
      'unbalanced four-wire star produces a real neutral return current',
      () {
        final Ac3SolveResult result = solve(
          _starCircuit(resistances: const <double>[23.0, 46.0, 92.0]),
        );
        expect(result.status, Ac3SolveStatus.solved);
        expect(result.currentBalanced, isFalse);
        expect(result.neutralConnected, isTrue);
        expect(result.lineCurrent(PhaseTag.l1).magnitude, closeTo(10.0, 1e-8));
        expect(result.lineCurrent(PhaseTag.l2).magnitude, closeTo(5.0, 1e-8));
        expect(result.lineCurrent(PhaseTag.l3).magnitude, closeTo(2.5, 1e-8));
        expect(result.neutralCurrent.magnitude, greaterThan(1.0));
        _expectResiduals(result);
      },
    );

    test('three-wire unbalanced star shifts its floating star point', () {
      final Ac3SolveResult result = solve(
        _starCircuit(
          resistances: const <double>[23.0, 46.0, 92.0],
          connectNeutral: false,
        ),
      );
      expect(result.status, Ac3SolveStatus.solved);
      expect(result.neutralConnected, isFalse);
      expect(result.neutralCurrent.magnitude, lessThan(1e-8));
      expect(
        result.branch('component:r1').voltage.magnitude,
        isNot(closeTo(230.0, 1e-4)),
      );
      _expectResiduals(result);
    });

    test('AC3-002 loss of L2 is an explicit degraded solved state', () {
      final Ac3SolveResult result = solve(
        _starCircuit(disabledPhase: PhaseTag.l2),
      );
      expect(result.status, Ac3SolveStatus.solved);
      expect(result.isDegradedThreePhase, isTrue);
      expect(result.missingPhases, contains(PhaseTag.l2));
      expect(result.lineCurrent(PhaseTag.l2), AcComplex.zero);
      expect(result.branch('component:r2').current!.magnitude, lessThan(1e-10));
      expect(
        result.diagnostics.map(
          (Ac3SolverDiagnostic diagnostic) => diagnostic.code,
        ),
        contains(Ac3DiagnosticCode.phaseLoss),
      );
      expect(result.currentBalanced, isFalse);
    });

    test(
      'AC3-003 swapping two physical conductors changes observed phase sequence',
      () {
        final Ac3SolveResult positive = solve(
          _starCircuit(
            probeOrder: const <PhaseTag>[PhaseTag.l1, PhaseTag.l2, PhaseTag.l3],
          ),
        );
        final Ac3SolveResult inverted = solve(
          _starCircuit(
            probeOrder: const <PhaseTag>[PhaseTag.l1, PhaseTag.l3, PhaseTag.l2],
          ),
        );
        expect(
          positive.phaseOrderObservations.single.sequence,
          Ac3PhaseSequence.positive,
        );
        expect(
          inverted.phaseOrderObservations.single.sequence,
          Ac3PhaseSequence.negative,
        );
        expect(inverted.sourceSequence, Ac3PhaseSequence.positive);
      },
    );

    test(
      'explicit source phasors can represent a negative source sequence',
      () {
        final Ac3SolveResult result = solve(
          _starCircuit(sourcePhases: const <double>[0.0, 120.0, -120.0]),
        );
        expect(result.status, Ac3SolveStatus.solved);
        expect(result.sourceSequence, Ac3PhaseSequence.negative);
      },
    );

    test('R L C and general impedance models are supported in AC3', () {
      final Ac3SolveResult result = solve(_mixedLoadCircuit());
      expect(result.status, Ac3SolveStatus.solved);
      expect(result.branch('component:r').kind, Ac3BranchKind.resistor);
      expect(result.branch('component:l').kind, Ac3BranchKind.inductor);
      expect(result.branch('component:c').kind, Ac3BranchKind.capacitor);
      expect(result.branch('component:z').kind, Ac3BranchKind.impedance);
      _expectResiduals(result);
    });

    test('open and disabled passive components have zero branch current', () {
      for (final ComponentCondition condition in <ComponentCondition>[
        ComponentCondition.openCircuit,
        ComponentCondition.disabled,
      ]) {
        final Ac3SolveResult result = solve(_conditionCircuit(condition));
        expect(result.status, Ac3SolveStatus.solved);
        expect(result.branch('component:load').kind, Ac3BranchKind.openCircuit);
        expect(result.branch('component:load').current, AcComplex.zero);
      }
    });

    test('wrong mode and topology identity mismatch are rejected', () {
      final CircuitState circuit = _starCircuit();
      final CircuitState wrongMode = CircuitState(
        circuitId: circuit.circuitId,
        revision: circuit.revision,
        mode: ElectricalMode.ac1,
        components: circuit.components,
        connections: circuit.connections,
        sources: circuit.sources,
        settings: circuit.settings,
      );
      expect(solve(wrongMode).status, Ac3SolveStatus.invalid);

      final TopologyGraph topology = topologyEngine.compile(circuit);
      final CircuitState newer = CircuitState(
        circuitId: circuit.circuitId,
        revision: 1,
        mode: circuit.mode,
        components: circuit.components,
        connections: circuit.connections,
        sources: circuit.sources,
        settings: circuit.settings,
      );
      expect(solver.solve(newer, topology).status, Ac3SolveStatus.invalid);
    });

    test('missing and invalid frequency are explicit failures', () {
      final CircuitState base = _starCircuit();
      for (final Map<String, Object?> settings in <Map<String, Object?>>[
        const <String, Object?>{},
        const <String, Object?>{'frequencyHz': '50'},
        const <String, Object?>{'frequencyHz': 0.0},
      ]) {
        final CircuitState circuit = CircuitState(
          circuitId: CircuitId('bad-frequency-${settings.hashCode}'),
          revision: 0,
          mode: ElectricalMode.ac3,
          components: base.components,
          connections: base.connections,
          sources: base.sources,
          settings: settings,
        );
        expect(solve(circuit).status, Ac3SolveStatus.invalid);
      }
    });

    test(
      'invalid passive models parameters conditions and terminal counts fail',
      () {
        for (final CircuitState circuit in <CircuitState>[
          _badComponent(modelType: 'mystery'),
          _badComponent(
            parameters: const <String, Object?>{'resistanceOhm': 0.0},
          ),
          _badComponent(condition: ComponentCondition.degraded),
          _badComponent(oneTerminal: true),
          _badProbe(),
        ]) {
          expect(solve(circuit).status, Ac3SolveStatus.invalid);
        }
      },
    );

    test(
      'invalid source model phase tag parameter and terminal count fail',
      () {
        for (final CircuitState circuit in <CircuitState>[
          _badSource(modelType: 'mystery_source'),
          _badSource(noPhaseTag: true),
          _badSource(parameters: const <String, Object?>{'voltageRmsV': -1.0}),
          _badSource(oneTerminal: true),
        ]) {
          expect(solve(circuit).status, Ac3SolveStatus.invalid);
        }
      },
    );

    test('separate passive island is detected before matrix solve', () {
      final CircuitState base = _starCircuit();
      final CircuitState circuit = CircuitState(
        circuitId: CircuitId('ac3-floating'),
        revision: 0,
        mode: ElectricalMode.ac3,
        components: <ComponentInstance>[
          ...base.components,
          ComponentInstance(
            id: ComponentId('island'),
            modelType: 'resistor',
            terminals: <Terminal>[_terminal('ia', 'IA'), _terminal('ib', 'IB')],
            parameters: const <String, Object?>{'resistanceOhm': 10.0},
          ),
        ],
        connections: base.connections,
        sources: base.sources,
        settings: base.settings,
      );
      final Ac3SolveResult result = solve(circuit);
      expect(result.status, Ac3SolveStatus.singular);
      expect(
        result.diagnostics.map(
          (Ac3SolverDiagnostic diagnostic) => diagnostic.code,
        ),
        contains(Ac3DiagnosticCode.floatingElectricalIsland),
      );
    });

    test('parallel same-phase ideal sources expose a singular MNA system', () {
      final CircuitState circuit = _parallelL1Sources();
      final Ac3SolveResult result = solve(circuit);
      expect(result.status, Ac3SolveStatus.singular);
      expect(
        result.diagnostics.map(
          (Ac3SolverDiagnostic diagnostic) => diagnostic.code,
        ),
        contains(Ac3DiagnosticCode.singularMatrix),
      );
      expect(
        result.diagnostics.map(
          (Ac3SolverDiagnostic diagnostic) => diagnostic.code,
        ),
        contains(Ac3DiagnosticCode.duplicatePhaseSource),
      );
    });

    test(
      'AC current source is stamped explicitly in the three-phase network',
      () {
        final Ac3SolveResult result = solve(_currentSourceCircuit());
        expect(result.status, Ac3SolveStatus.solved);
        expect(result.branch('source:i1').kind, Ac3BranchKind.currentSource);
        expect(
          result.branch('source:i1').current!.magnitude,
          closeTo(2.0, 1e-10),
        );
        expect(
          result.branch('component:r').current!.magnitude,
          closeTo(2.0, 1e-10),
        );
        expect(
          result.missingPhases,
          containsAll(<PhaseTag>[PhaseTag.l2, PhaseTag.l3]),
        );
      },
    );

    test(
      'invalid L C impedance and current-source parameters are rejected',
      () {
        final List<CircuitState> circuits = <CircuitState>[
          _badComponent(
            modelType: 'inductor',
            parameters: const <String, Object?>{'inductanceH': 0.0},
          ),
          _badComponent(
            modelType: 'capacitor',
            parameters: const <String, Object?>{'capacitanceF': -1.0},
          ),
          _badComponent(
            modelType: 'impedance',
            parameters: const <String, Object?>{
              'resistanceOhm': 0.0,
              'reactanceOhm': 0.0,
            },
          ),
          _badSource(
            modelType: 'ac_current_source',
            parameters: const <String, Object?>{'currentRmsA': 'bad'},
          ),
        ];
        for (final CircuitState circuit in circuits) {
          expect(solve(circuit).status, Ac3SolveStatus.invalid);
        }
      },
    );

    test(
      'ideal short and near-zero impedance create explicit singular constraints',
      () {
        for (final CircuitState circuit in <CircuitState>[
          _conditionCircuit(ComponentCondition.shortCircuit),
          _nearZeroImpedanceCircuit(),
        ]) {
          final Ac3SolveResult result = solve(circuit);
          expect(result.status, Ac3SolveStatus.singular);
          expect(
            result.diagnostics.map(
              (Ac3SolverDiagnostic diagnostic) => diagnostic.code,
            ),
            contains(Ac3DiagnosticCode.singularMatrix),
          );
        }
      },
    );

    test(
      'empty circuit and conflicting phase topology are rejected explicitly',
      () {
        final CircuitState empty = CircuitState(
          circuitId: CircuitId('empty-ac3'),
          revision: 0,
          mode: ElectricalMode.ac3,
          settings: const <String, Object?>{'frequencyHz': 50.0},
        );
        expect(solve(empty).status, Ac3SolveStatus.invalid);

        final CircuitState conflicting = _conflictingPhaseCircuit();
        final Ac3SolveResult conflictResult = solve(conflicting);
        expect(conflictResult.status, Ac3SolveStatus.invalid);
        expect(
          conflictResult.diagnostics.map(
            (Ac3SolverDiagnostic diagnostic) => diagnostic.code,
          ),
          contains(Ac3DiagnosticCode.topologyError),
        );
      },
    );

    test(
      'source with line terminal second is oriented phase-to-neutral correctly',
      () {
        final CircuitState circuit = _reversedTerminalSourceCircuit();
        final Ac3SolveResult result = solve(circuit);
        expect(result.status, Ac3SolveStatus.solved);
        expect(
          result.phaseVoltage(PhaseTag.l1)!.magnitude,
          closeTo(230.0, 1e-8),
        );
        expect(
          result.branch('component:r').current!.magnitude,
          closeTo(10.0, 1e-8),
        );
      },
    );

    test(
      'zero-voltage three-phase source has indeterminate sequence and zero power',
      () {
        final Ac3SolveResult result = solve(_zeroVoltageCircuit());
        expect(result.status, Ac3SolveStatus.solved);
        expect(result.sourceSequence, Ac3PhaseSequence.indeterminate);
        expect(result.voltageBalanced, isTrue);
        expect(result.currentBalanced, isTrue);
        expect(
          result.branch('component:r1').apparentPowerVA,
          closeTo(0.0, 1e-12),
        );
        expect(result.branch('component:r1').powerFactor, 1.0);
      },
    );

    test('non-120-degree phasors produce an indeterminate source sequence', () {
      final Ac3SolveResult result = solve(
        _starCircuit(sourcePhases: const <double>[0.0, -90.0, 100.0]),
      );
      expect(result.status, Ac3SolveStatus.solved);
      expect(result.sourceSequence, Ac3PhaseSequence.indeterminate);
    });

    test('solver options can force pivot and residual quality failures', () {
      final CircuitState circuit = _starCircuit();
      final TopologyGraph topology = topologyEngine.compile(circuit);
      final Ac3SolveResult pivotFailure = const SolverAC3(
        options: Ac3SolverOptions(pivotTolerance: 1e9),
      ).solve(circuit, topology);
      expect(pivotFailure.status, Ac3SolveStatus.singular);

      final Ac3SolveResult residualFailure = const SolverAC3(
        options: Ac3SolverOptions(residualTolerance: -1.0),
      ).solve(circuit, topology);
      expect(residualFailure.status, Ac3SolveStatus.invalid);
      expect(
        residualFailure.diagnostics.map(
          (Ac3SolverDiagnostic diagnostic) => diagnostic.code,
        ),
        contains(Ac3DiagnosticCode.numericalResidualExceeded),
      );
    });

    test('disabled three-phase sources settle a passive network at zero', () {
      final Ac3SolveResult result = solve(_allSourcesDisabledCircuit());
      expect(result.status, Ac3SolveStatus.solved);
      expect(
        result.missingPhases,
        containsAll(<PhaseTag>[PhaseTag.l1, PhaseTag.l2, PhaseTag.l3]),
      );
      expect(result.branch('component:r1').current, AcComplex.zero);
      expect(result.phaseVoltage(PhaseTag.l1), isNull);
    });

    test('same input is deterministic', () {
      final CircuitState circuit = _starCircuit(
        resistances: const <double>[23.0, 46.0, 92.0],
      );
      final Ac3SolveResult first = solve(circuit);
      final Ac3SolveResult second = solve(circuit);
      expect(first.nodeVoltages, second.nodeVoltages);
      expect(
        first.branchResults.map(_signature).toList(),
        second.branchResults.map(_signature).toList(),
      );
    });
  });
}

void _expectResiduals(Ac3SolveResult result) {
  expect(result.maxMatrixResidual, isNotNull);
  expect(result.maxMatrixResidual!, lessThan(1e-8));
  for (final double residual in result.kclResiduals.values) {
    expect(residual, lessThan(1e-8));
  }
}

String _signature(Ac3BranchResult branch) =>
    '${branch.id}|${branch.voltage.real}|${branch.voltage.imaginary}|${branch.current?.real}|${branch.current?.imaginary}';

Terminal _terminal(
  String id,
  String name, {
  PhaseTag phase = PhaseTag.none,
  TerminalRole role = TerminalRole.generic,
}) => Terminal(id: TerminalId(id), name: name, phase: phase, role: role);

TerminalRole _phaseRole(PhaseTag phase) {
  switch (phase) {
    case PhaseTag.l1:
      return TerminalRole.phaseL1;
    case PhaseTag.l2:
      return TerminalRole.phaseL2;
    case PhaseTag.l3:
      return TerminalRole.phaseL3;
    default:
      return TerminalRole.line;
  }
}

String _phaseKey(PhaseTag phase) {
  switch (phase) {
    case PhaseTag.l1:
      return '1';
    case PhaseTag.l2:
      return '2';
    case PhaseTag.l3:
      return '3';
    default:
      throw ArgumentError.value(phase, 'phase');
  }
}

SourceInstance _phaseSource(
  PhaseTag phase,
  double voltage, {
  bool enabled = true,
  double? phaseDeg,
  String? idOverride,
}) {
  final String key = idOverride ?? _phaseKey(phase);
  return SourceInstance(
    id: SourceId('s$key'),
    modelType: 'ac_voltage_source',
    terminals: <Terminal>[
      _terminal(
        's${key}p',
        phase.name.toUpperCase(),
        phase: phase,
        role: _phaseRole(phase),
      ),
      _terminal(
        's${key}n',
        'N',
        phase: PhaseTag.neutral,
        role: TerminalRole.neutral,
      ),
    ],
    parameters: <String, Object?>{
      'voltageRmsV': voltage,
      if (phaseDeg != null) 'phaseDeg': phaseDeg,
    },
    enabled: enabled,
  );
}

CircuitState _starCircuit({
  List<double> resistances = const <double>[23.0, 23.0, 23.0],
  bool connectNeutral = true,
  PhaseTag? disabledPhase,
  List<double>? sourcePhases,
  List<PhaseTag>? probeOrder,
}) {
  final List<PhaseTag> phases = <PhaseTag>[
    PhaseTag.l1,
    PhaseTag.l2,
    PhaseTag.l3,
  ];
  final List<ComponentInstance> components = <ComponentInstance>[
    for (var i = 0; i < 3; i++)
      ComponentInstance(
        id: ComponentId('r${i + 1}'),
        modelType: 'resistor',
        terminals: <Terminal>[
          _terminal(
            'r${i + 1}p',
            phases[i].name.toUpperCase(),
            phase: phases[i],
            role: _phaseRole(phases[i]),
          ),
          _terminal(
            'r${i + 1}n',
            'N',
            phase: PhaseTag.neutral,
            role: TerminalRole.neutral,
          ),
        ],
        parameters: <String, Object?>{'resistanceOhm': resistances[i]},
      ),
    if (probeOrder != null)
      ComponentInstance(
        id: ComponentId('phase-probe'),
        modelType: 'phase_sequence_probe',
        terminals: <Terminal>[
          _terminal('probe1', '1'),
          _terminal('probe2', '2'),
          _terminal('probe3', '3'),
        ],
      ),
  ];
  final List<SourceInstance> sources = <SourceInstance>[
    for (var i = 0; i < 3; i++)
      _phaseSource(
        phases[i],
        230.0,
        enabled: disabledPhase != phases[i],
        phaseDeg: sourcePhases?[i],
      ),
  ];
  final List<Connection> connections = <Connection>[
    for (var i = 0; i < 3; i++)
      Connection(
        id: ConnectionId('phase-${i + 1}'),
        fromTerminalId: TerminalId('s${i + 1}p'),
        toTerminalId: TerminalId('r${i + 1}p'),
        phase: phases[i],
      ),
    Connection(
      id: ConnectionId('source-neutral-12'),
      fromTerminalId: TerminalId('s1n'),
      toTerminalId: TerminalId('s2n'),
      phase: PhaseTag.neutral,
    ),
    Connection(
      id: ConnectionId('source-neutral-23'),
      fromTerminalId: TerminalId('s2n'),
      toTerminalId: TerminalId('s3n'),
      phase: PhaseTag.neutral,
    ),
    Connection(
      id: ConnectionId('load-neutral-12'),
      fromTerminalId: TerminalId('r1n'),
      toTerminalId: TerminalId('r2n'),
      phase: PhaseTag.neutral,
    ),
    Connection(
      id: ConnectionId('load-neutral-23'),
      fromTerminalId: TerminalId('r2n'),
      toTerminalId: TerminalId('r3n'),
      phase: PhaseTag.neutral,
    ),
    if (connectNeutral)
      Connection(
        id: ConnectionId('neutral-link'),
        fromTerminalId: TerminalId('s1n'),
        toTerminalId: TerminalId('r1n'),
        phase: PhaseTag.neutral,
      ),
    if (probeOrder != null)
      for (var i = 0; i < 3; i++)
        Connection(
          id: ConnectionId('probe-${i + 1}'),
          fromTerminalId: TerminalId('s${_phaseKey(probeOrder[i])}p'),
          toTerminalId: TerminalId('probe${i + 1}'),
        ),
  ];
  return CircuitState(
    circuitId: CircuitId(
      'ac3-star-${resistances.join('-')}-${connectNeutral ? '4w' : '3w'}-${disabledPhase?.name ?? 'ok'}-${probeOrder?.map((PhaseTag p) => p.name).join('-') ?? 'noprobe'}',
    ),
    revision: 0,
    mode: ElectricalMode.ac3,
    components: components,
    connections: connections,
    sources: sources,
    settings: const <String, Object?>{'frequencyHz': 50.0},
  );
}

CircuitState _deltaCircuit() {
  final double phaseVoltage = 400.0 / math.sqrt(3.0);
  return CircuitState(
    circuitId: CircuitId('ac3-delta-balanced'),
    revision: 0,
    mode: ElectricalMode.ac3,
    components: <ComponentInstance>[
      _deltaResistor('d12', PhaseTag.l1, PhaseTag.l2),
      _deltaResistor('d23', PhaseTag.l2, PhaseTag.l3),
      _deltaResistor('d31', PhaseTag.l3, PhaseTag.l1),
    ],
    connections: <Connection>[
      _wire('s1-d12', 's1p', 'd12a', PhaseTag.l1),
      _wire('s1-d31', 's1p', 'd31b', PhaseTag.l1),
      _wire('s2-d12', 's2p', 'd12b', PhaseTag.l2),
      _wire('s2-d23', 's2p', 'd23a', PhaseTag.l2),
      _wire('s3-d23', 's3p', 'd23b', PhaseTag.l3),
      _wire('s3-d31', 's3p', 'd31a', PhaseTag.l3),
      _wire('sn12', 's1n', 's2n', PhaseTag.neutral),
      _wire('sn23', 's2n', 's3n', PhaseTag.neutral),
    ],
    sources: <SourceInstance>[
      _phaseSource(PhaseTag.l1, phaseVoltage),
      _phaseSource(PhaseTag.l2, phaseVoltage),
      _phaseSource(PhaseTag.l3, phaseVoltage),
    ],
    settings: const <String, Object?>{'frequencyHz': 50.0},
  );
}

ComponentInstance _deltaResistor(String id, PhaseTag a, PhaseTag b) =>
    ComponentInstance(
      id: ComponentId(id),
      modelType: 'resistor',
      terminals: <Terminal>[
        _terminal('${id}a', a.name, phase: a, role: _phaseRole(a)),
        _terminal('${id}b', b.name, phase: b, role: _phaseRole(b)),
      ],
      parameters: const <String, Object?>{'resistanceOhm': 40.0},
    );

Connection _wire(String id, String from, String to, PhaseTag phase) =>
    Connection(
      id: ConnectionId(id),
      fromTerminalId: TerminalId(from),
      toTerminalId: TerminalId(to),
      phase: phase,
    );

CircuitState _mixedLoadCircuit() {
  final CircuitState base = _starCircuit();
  return CircuitState(
    circuitId: CircuitId('ac3-mixed'),
    revision: 0,
    mode: ElectricalMode.ac3,
    components: <ComponentInstance>[
      ComponentInstance(
        id: ComponentId('r'),
        modelType: 'resistor',
        terminals: <Terminal>[
          _terminal('rp', 'L1', phase: PhaseTag.l1),
          _terminal('rn', 'N', phase: PhaseTag.neutral),
        ],
        parameters: const <String, Object?>{'resistanceOhm': 23.0},
      ),
      ComponentInstance(
        id: ComponentId('l'),
        modelType: 'inductor',
        terminals: <Terminal>[
          _terminal('lp', 'L2', phase: PhaseTag.l2),
          _terminal('ln', 'N', phase: PhaseTag.neutral),
        ],
        parameters: const <String, Object?>{'inductanceH': 0.1},
      ),
      ComponentInstance(
        id: ComponentId('c'),
        modelType: 'capacitor',
        terminals: <Terminal>[
          _terminal('cp', 'L3', phase: PhaseTag.l3),
          _terminal('cn', 'N', phase: PhaseTag.neutral),
        ],
        parameters: const <String, Object?>{'capacitanceF': 0.0001},
      ),
      ComponentInstance(
        id: ComponentId('z'),
        modelType: 'impedance',
        terminals: <Terminal>[
          _terminal('za', 'L1', phase: PhaseTag.l1),
          _terminal('zb', 'N', phase: PhaseTag.neutral),
        ],
        parameters: const <String, Object?>{
          'resistanceOhm': 100.0,
          'reactanceOhm': 30.0,
        },
      ),
    ],
    connections: <Connection>[
      _wire('rpw', 's1p', 'rp', PhaseTag.l1),
      _wire('lpw', 's2p', 'lp', PhaseTag.l2),
      _wire('cpw', 's3p', 'cp', PhaseTag.l3),
      _wire('zpw', 's1p', 'za', PhaseTag.l1),
      _wire('sn12', 's1n', 's2n', PhaseTag.neutral),
      _wire('sn23', 's2n', 's3n', PhaseTag.neutral),
      _wire('rn-ln', 'rn', 'ln', PhaseTag.neutral),
      _wire('ln-cn', 'ln', 'cn', PhaseTag.neutral),
      _wire('cn-zn', 'cn', 'zb', PhaseTag.neutral),
      _wire('neutral-link', 's1n', 'rn', PhaseTag.neutral),
    ],
    sources: base.sources,
    settings: base.settings,
  );
}

CircuitState _conditionCircuit(ComponentCondition condition) {
  final CircuitState base = _starCircuit();
  return CircuitState(
    circuitId: CircuitId('condition-${condition.name}'),
    revision: 0,
    mode: ElectricalMode.ac3,
    components: <ComponentInstance>[
      ComponentInstance(
        id: ComponentId('load'),
        modelType: 'resistor',
        terminals: <Terminal>[
          _terminal('loadp', 'L1', phase: PhaseTag.l1),
          _terminal('loadn', 'N', phase: PhaseTag.neutral),
        ],
        parameters: const <String, Object?>{'resistanceOhm': 23.0},
        condition: condition,
      ),
    ],
    connections: <Connection>[
      _wire('p', 's1p', 'loadp', PhaseTag.l1),
      _wire('n', 's1n', 'loadn', PhaseTag.neutral),
      _wire('sn12', 's1n', 's2n', PhaseTag.neutral),
      _wire('sn23', 's2n', 's3n', PhaseTag.neutral),
    ],
    sources: base.sources,
    settings: base.settings,
  );
}

CircuitState _badComponent({
  String modelType = 'resistor',
  Map<String, Object?> parameters = const <String, Object?>{
    'resistanceOhm': 23.0,
  },
  ComponentCondition condition = ComponentCondition.normal,
  bool oneTerminal = false,
}) {
  final CircuitState base = _starCircuit();
  return CircuitState(
    circuitId: CircuitId('bad-component-$modelType-$condition-$oneTerminal'),
    revision: 0,
    mode: ElectricalMode.ac3,
    components: <ComponentInstance>[
      ComponentInstance(
        id: ComponentId('bad'),
        modelType: modelType,
        terminals: <Terminal>[
          _terminal('badp', 'L1', phase: PhaseTag.l1),
          if (!oneTerminal) _terminal('badn', 'N', phase: PhaseTag.neutral),
        ],
        parameters: parameters,
        condition: condition,
      ),
    ],
    connections: <Connection>[
      _wire('badpwire', 's1p', 'badp', PhaseTag.l1),
      if (!oneTerminal) _wire('badnwire', 's1n', 'badn', PhaseTag.neutral),
      _wire('sn12', 's1n', 's2n', PhaseTag.neutral),
      _wire('sn23', 's2n', 's3n', PhaseTag.neutral),
    ],
    sources: base.sources,
    settings: base.settings,
  );
}

CircuitState _badProbe() {
  final CircuitState base = _starCircuit();
  return CircuitState(
    circuitId: CircuitId('bad-probe'),
    revision: 0,
    mode: ElectricalMode.ac3,
    components: <ComponentInstance>[
      ComponentInstance(
        id: ComponentId('probe'),
        modelType: 'phase_sequence_probe',
        terminals: <Terminal>[_terminal('pa', 'A'), _terminal('pb', 'B')],
      ),
    ],
    connections: <Connection>[
      _wire('pa-wire', 's1p', 'pa', PhaseTag.l1),
      _wire('pb-wire', 's2p', 'pb', PhaseTag.l2),
      _wire('sn12', 's1n', 's2n', PhaseTag.neutral),
      _wire('sn23', 's2n', 's3n', PhaseTag.neutral),
    ],
    sources: base.sources,
    settings: base.settings,
  );
}

CircuitState _badSource({
  String modelType = 'ac_voltage_source',
  Map<String, Object?> parameters = const <String, Object?>{
    'voltageRmsV': 230.0,
  },
  bool noPhaseTag = false,
  bool oneTerminal = false,
}) {
  final SourceInstance source = SourceInstance(
    id: SourceId('badsource'),
    modelType: modelType,
    terminals: <Terminal>[
      _terminal('bsp', 'L1', phase: noPhaseTag ? PhaseTag.none : PhaseTag.l1),
      if (!oneTerminal)
        _terminal(
          'bsn',
          'N',
          phase: PhaseTag.neutral,
          role: TerminalRole.neutral,
        ),
    ],
    parameters: parameters,
  );
  return CircuitState(
    circuitId: CircuitId('bad-source-$modelType-$noPhaseTag-$oneTerminal'),
    revision: 0,
    mode: ElectricalMode.ac3,
    sources: <SourceInstance>[source],
    settings: const <String, Object?>{'frequencyHz': 50.0},
  );
}

CircuitState _parallelL1Sources() {
  final SourceInstance a = _phaseSource(PhaseTag.l1, 230.0, idOverride: 'a');
  final SourceInstance b = _phaseSource(PhaseTag.l1, 230.0, idOverride: 'b');
  return CircuitState(
    circuitId: CircuitId('parallel-l1-sources'),
    revision: 0,
    mode: ElectricalMode.ac3,
    sources: <SourceInstance>[a, b],
    connections: <Connection>[
      _wire('phase', 'sap', 'sbp', PhaseTag.l1),
      _wire('neutral', 'san', 'sbn', PhaseTag.neutral),
    ],
    settings: const <String, Object?>{'frequencyHz': 50.0},
  );
}

CircuitState _currentSourceCircuit() => CircuitState(
  circuitId: CircuitId('ac3-current-source'),
  revision: 0,
  mode: ElectricalMode.ac3,
  components: <ComponentInstance>[
    ComponentInstance(
      id: ComponentId('r'),
      modelType: 'resistor',
      terminals: <Terminal>[
        _terminal('rp-current', 'L1', phase: PhaseTag.l1),
        _terminal('rn-current', 'N', phase: PhaseTag.neutral),
      ],
      parameters: const <String, Object?>{'resistanceOhm': 10.0},
    ),
  ],
  connections: <Connection>[
    _wire('current-p', 'i1p', 'rp-current', PhaseTag.l1),
    _wire('current-n', 'i1n', 'rn-current', PhaseTag.neutral),
  ],
  sources: <SourceInstance>[
    SourceInstance(
      id: SourceId('i1'),
      modelType: 'ac_current_source',
      terminals: <Terminal>[
        _terminal('i1p', 'L1', phase: PhaseTag.l1),
        _terminal(
          'i1n',
          'N',
          phase: PhaseTag.neutral,
          role: TerminalRole.neutral,
        ),
      ],
      parameters: const <String, Object?>{'currentRmsA': 2.0, 'phaseDeg': 0.0},
    ),
  ],
  settings: const <String, Object?>{'frequencyHz': 50.0},
);

CircuitState _nearZeroImpedanceCircuit() {
  final CircuitState base = _starCircuit();
  return CircuitState(
    circuitId: CircuitId('ac3-near-zero-z'),
    revision: 0,
    mode: ElectricalMode.ac3,
    components: <ComponentInstance>[
      ComponentInstance(
        id: ComponentId('load'),
        modelType: 'impedance',
        terminals: <Terminal>[
          _terminal('loadp-z', 'L1', phase: PhaseTag.l1),
          _terminal('loadn-z', 'N', phase: PhaseTag.neutral),
        ],
        parameters: const <String, Object?>{
          'resistanceOhm': 1e-20,
          'reactanceOhm': 0.0,
        },
      ),
    ],
    connections: <Connection>[
      _wire('zp', 's1p', 'loadp-z', PhaseTag.l1),
      _wire('zn', 's1n', 'loadn-z', PhaseTag.neutral),
      _wire('zsn12', 's1n', 's2n', PhaseTag.neutral),
      _wire('zsn23', 's2n', 's3n', PhaseTag.neutral),
    ],
    sources: base.sources,
    settings: base.settings,
  );
}

CircuitState _conflictingPhaseCircuit() => CircuitState(
  circuitId: CircuitId('ac3-conflict'),
  revision: 0,
  mode: ElectricalMode.ac3,
  components: <ComponentInstance>[
    ComponentInstance(
      id: ComponentId('r'),
      modelType: 'resistor',
      terminals: <Terminal>[
        _terminal('conflict-l2', 'L2', phase: PhaseTag.l2),
        _terminal('conflict-n', 'N', phase: PhaseTag.neutral),
      ],
      parameters: const <String, Object?>{'resistanceOhm': 23.0},
    ),
  ],
  connections: <Connection>[
    _wire('conflict-p', 'conflict-s1p', 'conflict-l2', PhaseTag.l1),
    _wire('conflict-nw', 'conflict-s1n', 'conflict-n', PhaseTag.neutral),
  ],
  sources: <SourceInstance>[
    SourceInstance(
      id: SourceId('conflict-source'),
      modelType: 'ac_voltage_source',
      terminals: <Terminal>[
        _terminal('conflict-s1p', 'L1', phase: PhaseTag.l1),
        _terminal(
          'conflict-s1n',
          'N',
          phase: PhaseTag.neutral,
          role: TerminalRole.neutral,
        ),
      ],
      parameters: const <String, Object?>{'voltageRmsV': 230.0},
    ),
  ],
  settings: const <String, Object?>{'frequencyHz': 50.0},
);

CircuitState _reversedTerminalSourceCircuit() => CircuitState(
  circuitId: CircuitId('ac3-source-terminal-order'),
  revision: 0,
  mode: ElectricalMode.ac3,
  components: <ComponentInstance>[
    ComponentInstance(
      id: ComponentId('r'),
      modelType: 'resistor',
      terminals: <Terminal>[
        _terminal('rev-rp', 'L1', phase: PhaseTag.l1),
        _terminal('rev-rn', 'N', phase: PhaseTag.neutral),
      ],
      parameters: const <String, Object?>{'resistanceOhm': 23.0},
    ),
  ],
  connections: <Connection>[
    _wire('rev-p', 'rev-sp', 'rev-rp', PhaseTag.l1),
    _wire('rev-n', 'rev-sn', 'rev-rn', PhaseTag.neutral),
  ],
  sources: <SourceInstance>[
    SourceInstance(
      id: SourceId('rev-source'),
      modelType: 'ac_voltage_source',
      terminals: <Terminal>[
        _terminal(
          'rev-sn',
          'N',
          phase: PhaseTag.neutral,
          role: TerminalRole.neutral,
        ),
        _terminal(
          'rev-sp',
          'L1',
          phase: PhaseTag.l1,
          role: TerminalRole.phaseL1,
        ),
      ],
      parameters: const <String, Object?>{
        'voltageRmsV': 230.0,
        'phaseDeg': 0.0,
      },
    ),
  ],
  settings: const <String, Object?>{'frequencyHz': 50.0},
);

CircuitState _zeroVoltageCircuit() {
  final CircuitState base = _starCircuit();
  return CircuitState(
    circuitId: CircuitId('ac3-zero-voltage'),
    revision: 0,
    mode: ElectricalMode.ac3,
    components: base.components,
    connections: base.connections,
    sources: <SourceInstance>[
      _phaseSource(PhaseTag.l1, 0.0),
      _phaseSource(PhaseTag.l2, 0.0),
      _phaseSource(PhaseTag.l3, 0.0),
    ],
    settings: base.settings,
  );
}

CircuitState _allSourcesDisabledCircuit() {
  final CircuitState base = _starCircuit();
  return CircuitState(
    circuitId: CircuitId('ac3-all-disabled'),
    revision: 0,
    mode: ElectricalMode.ac3,
    components: base.components,
    connections: base.connections,
    sources: <SourceInstance>[
      _phaseSource(PhaseTag.l1, 230.0, enabled: false),
      _phaseSource(PhaseTag.l2, 230.0, enabled: false),
      _phaseSource(PhaseTag.l3, 230.0, enabled: false),
    ],
    settings: base.settings,
  );
}
