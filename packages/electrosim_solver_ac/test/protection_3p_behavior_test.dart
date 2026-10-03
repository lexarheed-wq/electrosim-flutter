
import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:electrosim_solver_ac/electrosim_solver_ac.dart';
import 'package:electrosim_topology/electrosim_topology.dart';
import 'package:test/test.dart';

void main() {
  const TopologyEngine topologyEngine = TopologyEngine();
  const SolverAC3 solver = SolverAC3();

  for (final String modelType
      in <String>['breaker_3p', 'thermal_overload_3p']) {
    test('$modelType conducts all phases before trip', () {
      final CircuitState circuit = _circuit(
        modelType: modelType,
        tripped: false,
      );
      final Ac3SolveResult result =
          solver.solve(circuit, topologyEngine.compile(circuit));

      expect(result.isSolved, isTrue);
      for (final String phase in <String>['L1', 'L2', 'L3']) {
        expect(
          result.branch('component:q1:power:$phase').kind,
          Ac3BranchKind.idealProtection,
        );
      }
      for (final String load in <String>['r1', 'r2', 'r3']) {
        expect(
          result.branch('component:$load').current!.magnitude,
          closeTo(5.0, 1e-8),
        );
      }
    });

    test('$modelType opens all phases after trip', () {
      final CircuitState circuit = _circuit(
        modelType: modelType,
        tripped: true,
      );
      final Ac3SolveResult result =
          solver.solve(circuit, topologyEngine.compile(circuit));

      expect(result.isSolved, isTrue);
      for (final String phase in <String>['L1', 'L2', 'L3']) {
        final Ac3BranchResult branch =
            result.branch('component:q1:power:$phase');
        expect(branch.kind, Ac3BranchKind.openCircuit);
        expect(branch.current!.magnitude, closeTo(0.0, 1e-12));
      }
      for (final String load in <String>['r1', 'r2', 'r3']) {
        expect(
          result.branch('component:$load').current!.magnitude,
          closeTo(0.0, 1e-12),
        );
      }
    });
  }
}

CircuitState _circuit({
  required String modelType,
  required bool tripped,
}) =>
    CircuitState(
      circuitId: CircuitId('$modelType-$tripped'),
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
          parameters: <String, Object?>{
            ProtectionRating.ratedCurrentKey: 10.0,
          },
          controlState: <String, Object?>{
            'closed': true,
            'tripped': tripped,
          },
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

ComponentInstance _load(String id, PhaseTag phase) => ComponentInstance(
      id: ComponentId(id),
      modelType: 'resistor',
      terminals: <Terminal>[
        _t('$id-p', 'L', phase),
        _t('$id-n', 'N', PhaseTag.neutral),
      ],
      parameters: const <String, Object?>{'resistanceOhm': 46.0},
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
