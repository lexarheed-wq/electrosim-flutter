import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:electrosim_solver_dc/electrosim_solver_dc.dart';
import 'package:electrosim_topology/electrosim_topology.dart';
import 'package:test/test.dart';

void main() {
  const TopologyEngine topologyEngine = TopologyEngine();
  const SolverDC solver = SolverDC();

  DcSolveResult solve(CircuitState circuit) =>
      solver.solve(circuit, topologyEngine.compile(circuit));

  group('M3A DC convergence', () {
    test(
      'voltage source enters bounded current regulation without breaking KCL',
      () {
        final DcSolveResult result = solve(
          _resistiveCircuit(currentLimitA: 1.0),
        );

        expect(result.status, DcSolveStatus.solved);
        expect(result.branch('component:r1').currentA, closeTo(1.0, 1e-9));
        expect(
          result.branch('component:r1').voltageV.abs(),
          closeTo(12.0, 1e-9),
        );
        expect(result.branch('source:v1').currentA?.abs(), closeTo(1.0, 1e-9));
        expect(result.branch('source:v1').voltageV.abs(), closeTo(12.0, 1e-9));
        expect(
          result.diagnostics.map((DcSolverDiagnostic d) => d.code),
          contains(DcDiagnosticCode.sourceCurrentLimited),
        );
        _expectResiduals(result);
      },
    );

    test('voltage source stays in voltage regulation below current limit', () {
      final DcSolveResult result = solve(_resistiveCircuit(currentLimitA: 3.0));

      expect(result.status, DcSolveStatus.solved);
      expect(result.branch('component:r1').currentA, closeTo(2.0, 1e-9));
      expect(result.branch('component:r1').voltageV.abs(), closeTo(24.0, 1e-9));
      expect(
        result.diagnostics.map((DcSolverDiagnostic d) => d.code),
        isNot(contains(DcDiagnosticCode.sourceCurrentLimited)),
      );
      _expectResiduals(result);
    });

    test('currentLimitA must be finite and strictly positive', () {
      final DcSolveResult result = solve(_resistiveCircuit(currentLimitA: 0.0));
      expect(result.status, DcSolveStatus.invalid);
      expect(
        result.diagnostics.map((DcSolverDiagnostic d) => d.code),
        contains(DcDiagnosticCode.invalidParameter),
      );
    });

    test(
      'DC breaker is a canonical topology branch and can be tripped open',
      () {
        final DcSolveResult closed = solve(_breakerCircuit(tripped: false));
        expect(closed.status, DcSolveStatus.solved);
        expect(
          closed.branch('component:q1').kind,
          DcBranchKind.idealProtection,
        );
        expect(
          closed.branch('component:q1').currentA?.abs(),
          closeTo(2.0, 1e-9),
        );
        _expectResiduals(closed);

        final DcSolveResult open = solve(_breakerCircuit(tripped: true));
        expect(open.status, DcSolveStatus.solved);
        expect(open.branch('component:q1').kind, DcBranchKind.openCircuit);
        expect(open.branch('component:q1').currentA, 0.0);
        expect(open.branch('component:r1').currentA, closeTo(0.0, 1e-12));
        _expectResiduals(open);
      },
    );

    test(
      'receiver nominal current is descriptive and never a source limit',
      () {
        final CircuitState base = _resistiveCircuit();
        final ComponentInstance original = base.components.single;
        final CircuitState circuit = CircuitState(
          circuitId: CircuitId('receiver-rating-separation'),
          revision: 0,
          mode: ElectricalMode.dc,
          components: <ComponentInstance>[
            ComponentInstance(
              id: original.id,
              modelType: original.modelType,
              terminals: original.terminals,
              parameters: <String, Object?>{
                ...original.parameters,
                ReceiverNominalRating.currentKey: 0.5,
              },
            ),
          ],
          connections: base.connections,
          sources: base.sources,
        );

        final DcSolveResult result = solve(circuit);
        expect(result.status, DcSolveStatus.solved);
        expect(result.branch('component:r1').currentA, closeTo(2.0, 1e-9));
        expect(
          result.diagnostics.map((DcSolverDiagnostic d) => d.code),
          isNot(contains(DcDiagnosticCode.sourceCurrentLimited)),
        );
      },
    );
  });
}

CircuitState _resistiveCircuit({double? currentLimitA}) => CircuitState(
  circuitId: CircuitId('m3-current-limit-${currentLimitA ?? 'none'}'),
  revision: 0,
  mode: ElectricalMode.dc,
  components: <ComponentInstance>[
    ComponentInstance(
      id: ComponentId('r1'),
      modelType: 'resistor',
      terminals: <Terminal>[_terminal('r1a', 'A'), _terminal('r1b', 'B')],
      parameters: const <String, Object?>{'resistanceOhm': 12.0},
    ),
  ],
  connections: <Connection>[
    Connection(
      id: ConnectionId('w1'),
      fromTerminalId: TerminalId('vp'),
      toTerminalId: TerminalId('r1a'),
    ),
    Connection(
      id: ConnectionId('w2'),
      fromTerminalId: TerminalId('r1b'),
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
        if (currentLimitA != null) 'currentLimitA': currentLimitA,
      },
    ),
  ],
);

CircuitState _breakerCircuit({required bool tripped}) => CircuitState(
  circuitId: CircuitId('m3-breaker-$tripped'),
  revision: 0,
  mode: ElectricalMode.dc,
  components: <ComponentInstance>[
    ComponentInstance(
      id: ComponentId('q1'),
      modelType: 'breaker_dc',
      terminals: <Terminal>[_terminal('q1a', 'in'), _terminal('q1b', 'out')],
      parameters: <String, Object?>{ProtectionRating.ratedCurrentKey: 5.0},
      controlState: <String, Object?>{'tripped': tripped},
    ),
    ComponentInstance(
      id: ComponentId('r1'),
      modelType: 'resistor',
      terminals: <Terminal>[_terminal('r1a', 'A'), _terminal('r1b', 'B')],
      parameters: const <String, Object?>{'resistanceOhm': 12.0},
    ),
  ],
  connections: <Connection>[
    Connection(
      id: ConnectionId('w1'),
      fromTerminalId: TerminalId('vp'),
      toTerminalId: TerminalId('q1a'),
    ),
    Connection(
      id: ConnectionId('w2'),
      fromTerminalId: TerminalId('q1b'),
      toTerminalId: TerminalId('r1a'),
    ),
    Connection(
      id: ConnectionId('w3'),
      fromTerminalId: TerminalId('r1b'),
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
      parameters: const <String, Object?>{'voltageV': 24.0},
    ),
  ],
);

Terminal _terminal(
  String id,
  String name, {
  TerminalRole role = TerminalRole.generic,
  PhaseTag phase = PhaseTag.none,
}) => Terminal(id: TerminalId(id), name: name, role: role, phase: phase);

void _expectResiduals(DcSolveResult result) {
  expect(result.maxMatrixResidual, isNotNull);
  expect(result.maxMatrixResidual!, lessThan(1e-9));
  for (final double residual in result.kclResiduals.values) {
    expect(residual.abs(), lessThan(1e-9));
  }
  for (final double residual in result.kvlResiduals.values) {
    expect(residual.abs(), lessThan(1e-9));
  }
}
