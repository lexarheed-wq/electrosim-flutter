import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:electrosim_protection/electrosim_protection.dart';
import 'package:electrosim_topology/electrosim_topology.dart';
import 'package:test/test.dart';

void main() {
  const coordinator = ProtectionCoordinator();
  const topology = TopologyEngine();

  test('G2 structural contract has four distinct terminals and two poles', () {
    final c = CoreComponentModelContracts.registry.resolve('rcd_2p_ac1')!;
    expect(c.terminalCount, 4);
    expect(c.supportedModes, <ElectricalMode>{ElectricalMode.ac1});
    expect(c.branches.map((e) => e.id), <String>['power:N', 'power:L']);
    expect(c.branches.map((e) => e.fromTerminalIndex), <int>[0, 1]);
    expect(c.branches.map((e) => e.toTerminalIndex), <int>[2, 3]);
    expect(CoreComponentModelContracts.registry.resolve('breaker_ac1')!.terminalCount, 2);
  });

  test('healthy 5 A L-N circuit has zero residual and stays engaged', () {
    final circuit = _circuit(leakage: false);
    final result = coordinator.advanceAc1(
      circuit: circuit,
      topology: topology.compile(circuit),
      elapsed: const Duration(seconds: 1),
    );
    expect(result.result.isSolved, isTrue);
    expect(result.state.isTripped(ComponentId('rcd')), isFalse);
    final line = result.result.branch('component:rcd:power:L').current!;
    final neutral = result.result.branch('component:rcd:power:N').current!;
    expect(line.magnitude, closeTo(5, 1e-7));
    expect((line + neutral).magnitude, lessThan(1e-7));
  });

  test('L to PE-like return leakage trips and opens both L and N poles', () {
    final circuit = _circuit(leakage: true);
    final t0 = coordinator.advanceAc1(
      circuit: circuit,
      topology: topology.compile(circuit),
      elapsed: const Duration(milliseconds: 100),
    );
    expect(t0.result.isSolved, isTrue);
    expect(t0.state.isTripped(ComponentId('rcd')), isFalse);
    expect(t0.state[ComponentId('rcd')]!.lastObservedCurrentA,
        greaterThan(.03));
    final t1 = coordinator.advanceAc1(
      circuit: circuit,
      topology: topology.compile(circuit),
      elapsed: const Duration(milliseconds: 300),
      previous: t0.state,
    );
    expect(t1.state.isTripped(ComponentId('rcd')), isTrue);
    expect(t1.state[ComponentId('rcd')]!.tripCause,
        ProtectionTripCause.residualCurrent);
    expect(t1.result.isSolved, isTrue);
    expect(t1.result.branch('component:rcd:power:N').current!.magnitude,
        closeTo(0, 1e-10));
    expect(t1.result.branch('component:rcd:power:L').current!.magnitude,
        closeTo(0, 1e-10));
    expect(t1.state.reset(ComponentId('rcd')).isTripped(ComponentId('rcd')),
        isFalse);
  });
}

Terminal _terminal(String id, String name, PhaseTag phase) =>
    Terminal(id: TerminalId(id), name: name, phase: phase);

Connection _wire(String id, String a, String b) => Connection(
  id: ConnectionId(id), fromTerminalId: TerminalId(a),
  toTerminalId: TerminalId(b),
);

CircuitState _circuit({required bool leakage}) {
  return CircuitState(
    circuitId: CircuitId('rcd-2p-test'),
    revision: 0,
    mode: ElectricalMode.ac1,
    components: <ComponentInstance>[
      ComponentInstance(
        id: ComponentId('rcd'),
        modelType: 'rcd_2p_ac1',
        terminals: <Terminal>[
          _terminal('nin', 'N in', PhaseTag.neutral),
          _terminal('lin', 'L in', PhaseTag.l1),
          _terminal('nout', 'N out', PhaseTag.neutral),
          _terminal('lout', 'L out', PhaseTag.l1),
        ],
        parameters: <String, Object?>{
          ProtectionRating.ratedCurrentKey: 16.0,
          ComponentParameterKeys.residualTripCurrentA: .03,
        },
        controlState: const <String, Object?>{'closed': true, 'tripped': false},
      ),
      ComponentInstance(
        id: ComponentId('load'),
        modelType: 'resistor',
        terminals: <Terminal>[
          _terminal('rl', 'L', PhaseTag.l1),
          _terminal('rn', 'N', PhaseTag.neutral),
        ],
        parameters: const <String, Object?>{'resistanceOhm': 46.0},
      ),
      if (leakage)
        ComponentInstance(
          id: ComponentId('leak'),
          modelType: 'resistor',
          terminals: <Terminal>[
            _terminal('leakl', 'L', PhaseTag.l1),
            _terminal('leakn', 'return', PhaseTag.neutral),
          ],
          parameters: const <String, Object?>{'resistanceOhm': 1000.0},
        ),
    ],
    connections: <Connection>[
      _wire('w1', 'vl', 'lin'),
      _wire('w2', 'vn', 'nin'),
      _wire('w3', 'lout', 'rl'),
      _wire('w4', 'nout', 'rn'),
      if (leakage) ...<Connection>[
        _wire('w5', 'lout', 'leakl'),
        _wire('w6', 'leakn', 'vn'),
      ],
    ],
    sources: <SourceInstance>[
      SourceInstance(
        id: SourceId('v'),
        modelType: 'ac_voltage_source',
        terminals: <Terminal>[
          _terminal('vl', 'L', PhaseTag.l1),
          _terminal('vn', 'N', PhaseTag.neutral),
        ],
        parameters: const <String, Object?>{'voltageRmsV': 230.0},
      ),
    ],
    settings: const <String, Object?>{'frequencyHz': 50.0},
  );
}
