import 'dart:math' as math;

import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:electrosim_solver_ac/electrosim_solver_ac.dart';
import 'package:electrosim_topology/electrosim_topology.dart';
import 'package:test/test.dart';

void main() {
  const TopologyEngine topologyEngine = TopologyEngine();
  const SolverAC1 solver = SolverAC1();

  Ac1SolveResult solve(CircuitState circuit) =>
      solver.solve(circuit, topologyEngine.compile(circuit));

  group('M4 AC1 convergence', () {
    test('lamp uses canonical topology branch and solves as a resistive receiver', () {
      final Ac1SolveResult result = solve(
        _seriesCircuit(
          ComponentInstance(
            id: ComponentId('x1'),
            modelType: 'lamp',
            terminals: <Terminal>[_t('x1a', 'A'), _t('x1b', 'B')],
            parameters: const <String, Object?>{'resistanceOhm': 46.0},
          ),
        ),
      );
      expect(result.status, Ac1SolveStatus.solved);
      expect(result.branch('component:x1').current?.magnitude, closeTo(5.0, 1e-9));
      expect(result.branch('component:x1').activePowerW, closeTo(1150.0, 1e-6));
      _expectResiduals(result);
    });

    test('inductor uses complex impedance at configured frequency', () {
      final Ac1SolveResult result = solve(
        _seriesCircuit(
          ComponentInstance(
            id: ComponentId('x1'),
            modelType: 'inductor',
            terminals: <Terminal>[_t('x1a', 'A'), _t('x1b', 'B')],
            parameters: const <String, Object?>{'inductanceH': 0.1},
          ),
        ),
      );
      final double expected = 230.0 / (2.0 * math.pi * 50.0 * 0.1);
      expect(result.status, Ac1SolveStatus.solved);
      expect(result.branch('component:x1').current?.magnitude, closeTo(expected, 1e-9));
      expect(result.branch('component:x1').reactivePowerVar, greaterThan(0.0));
      _expectResiduals(result);
    });

    test('switch state opens or closes the AC1 power path', () {
      final Ac1SolveResult open = solve(_switchCircuit(closed: false));
      expect(open.status, Ac1SolveStatus.solved);
      expect(open.branch('component:s1').kind, Ac1BranchKind.openCircuit);
      expect(open.branch('component:s1').current?.magnitude, closeTo(0.0, 1e-12));

      final Ac1SolveResult closed = solve(_switchCircuit(closed: true));
      expect(closed.status, Ac1SolveStatus.solved);
      expect(closed.branch('component:s1').kind, Ac1BranchKind.idealSwitch);
      expect(closed.branch('component:r1').current?.magnitude, closeTo(5.0, 1e-9));
      _expectResiduals(closed);
    });

    test('tripped AC1 breaker is an explicit open protection branch', () {
      final Ac1SolveResult result = solve(_breakerCircuit(tripped: true));
      expect(result.status, Ac1SolveStatus.solved);
      expect(result.branch('component:q1').kind, Ac1BranchKind.openCircuit);
      expect(result.branch('component:q1').current?.magnitude, closeTo(0.0, 1e-12));
      expect(result.branch('component:r1').current?.magnitude, closeTo(0.0, 1e-12));
      _expectResiduals(result);
    });

    test('closed AC1 breaker remains distinct from receiver nominal current', () {
      final Ac1SolveResult result = solve(_breakerCircuit(tripped: false));
      expect(result.status, Ac1SolveStatus.solved);
      expect(result.branch('component:q1').kind, Ac1BranchKind.idealProtection);
      expect(result.branch('component:r1').current?.magnitude, closeTo(5.0, 1e-9));
      _expectResiduals(result);
    });
  });
}

CircuitState _seriesCircuit(ComponentInstance component) => CircuitState(
  circuitId: CircuitId('m4-${component.modelType}'),
  revision: 0,
  mode: ElectricalMode.ac1,
  components: <ComponentInstance>[component],
  connections: <Connection>[
    Connection(
      id: ConnectionId('w1'),
      fromTerminalId: TerminalId('l'),
      toTerminalId: component.terminals[0].id,
    ),
    Connection(
      id: ConnectionId('w2'),
      fromTerminalId: component.terminals[1].id,
      toTerminalId: TerminalId('n'),
    ),
  ],
  sources: <SourceInstance>[_source()],
  settings: const <String, Object?>{'frequencyHz': 50.0},
);

CircuitState _switchCircuit({required bool closed}) => CircuitState(
  circuitId: CircuitId('m4-switch-$closed'),
  revision: 0,
  mode: ElectricalMode.ac1,
  components: <ComponentInstance>[
    ComponentInstance(
      id: ComponentId('s1'),
      modelType: 'switch',
      terminals: <Terminal>[_t('s1a', '1'), _t('s1b', '2')],
      controlState: <String, Object?>{'closed': closed},
    ),
    _resistor(),
  ],
  connections: <Connection>[
    Connection(id: ConnectionId('w1'), fromTerminalId: TerminalId('l'), toTerminalId: TerminalId('s1a')),
    Connection(id: ConnectionId('w2'), fromTerminalId: TerminalId('s1b'), toTerminalId: TerminalId('r1a')),
    Connection(id: ConnectionId('w3'), fromTerminalId: TerminalId('r1b'), toTerminalId: TerminalId('n')),
  ],
  sources: <SourceInstance>[_source()],
  settings: const <String, Object?>{'frequencyHz': 50.0},
);

CircuitState _breakerCircuit({required bool tripped}) => CircuitState(
  circuitId: CircuitId('m4-breaker-$tripped'),
  revision: 0,
  mode: ElectricalMode.ac1,
  components: <ComponentInstance>[
    ComponentInstance(
      id: ComponentId('q1'),
      modelType: 'breaker_ac1',
      terminals: <Terminal>[_t('q1a', 'IN'), _t('q1b', 'OUT')],
      parameters: <String, Object?>{ProtectionRating.ratedCurrentKey: 10.0},
      controlState: <String, Object?>{'closed': true, 'tripped': tripped},
    ),
    _resistor(),
  ],
  connections: <Connection>[
    Connection(id: ConnectionId('w1'), fromTerminalId: TerminalId('l'), toTerminalId: TerminalId('q1a')),
    Connection(id: ConnectionId('w2'), fromTerminalId: TerminalId('q1b'), toTerminalId: TerminalId('r1a')),
    Connection(id: ConnectionId('w3'), fromTerminalId: TerminalId('r1b'), toTerminalId: TerminalId('n')),
  ],
  sources: <SourceInstance>[_source()],
  settings: const <String, Object?>{'frequencyHz': 50.0},
);

ComponentInstance _resistor() => ComponentInstance(
  id: ComponentId('r1'),
  modelType: 'resistor',
  terminals: <Terminal>[_t('r1a', 'A'), _t('r1b', 'B')],
  parameters: const <String, Object?>{'resistanceOhm': 46.0},
);

SourceInstance _source() => SourceInstance(
  id: SourceId('v1'),
  modelType: 'ac_voltage_source',
  terminals: <Terminal>[
    _t('l', 'L', role: TerminalRole.line),
    _t('n', 'N', role: TerminalRole.neutral),
  ],
  parameters: const <String, Object?>{'voltageRmsV': 230.0, 'phaseDeg': 0.0},
);

Terminal _t(String id, String name, {TerminalRole role = TerminalRole.generic}) =>
    Terminal(id: TerminalId(id), name: name, role: role);

void _expectResiduals(Ac1SolveResult result) {
  expect(result.maxMatrixResidual, isNotNull);
  expect(result.maxMatrixResidual!, lessThan(1e-9));
  for (final double residual in result.kclResiduals.values) {
    expect(residual, lessThan(1e-9));
  }
}
