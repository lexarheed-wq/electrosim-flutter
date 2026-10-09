import 'package:electrosim/runtime/electrosim_simulation_controller.dart';
import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('powered RCD test T trips both poles, then rearms', () {
    final simulation = ElectroSimSimulationController(circuit: _circuit());
    addTearDown(simulation.dispose);
    expect(simulation.snapshot.solved, isTrue);
    expect(simulation.testResidualDevice(ComponentId('rcd')), isTrue);
    expect(simulation.snapshot.protectionTripped(ComponentId('rcd')), isTrue);
    expect(
      simulation.snapshot.ac1.branch('component:rcd:power:L').current!.magnitude,
      closeTo(0, 1e-9),
    );
    expect(
      simulation.snapshot.ac1.branch('component:rcd:power:N').current!.magnitude,
      closeTo(0, 1e-9),
    );
    expect(simulation.testResidualDevice(ComponentId('rcd')), isFalse);
    simulation.rearmProtection(ComponentId('rcd'));
    expect(simulation.snapshot.protectionTripped(ComponentId('rcd')), isFalse);
  });

  test('unpowered RCD test T cannot invent a trip', () {
    final circuit = _circuit();
    final unpowered = CircuitState(
      circuitId: CircuitId('test-unpowered'),
      revision: 0,
      mode: ElectricalMode.ac1,
      components: circuit.components,
      connections: circuit.connections,
      settings: circuit.settings,
    );
    final simulation = ElectroSimSimulationController(circuit: unpowered);
    addTearDown(simulation.dispose);
    expect(simulation.testResidualDevice(ComponentId('rcd')), isFalse);
    expect(simulation.snapshot.protectionTripped(ComponentId('rcd')), isFalse);
  });
}

Terminal _terminal(String id, PhaseTag phase) =>
    Terminal(id: TerminalId(id), name: id, phase: phase);

Connection _wire(String id, String from, String to) => Connection(
  id: ConnectionId(id),
  fromTerminalId: TerminalId(from),
  toTerminalId: TerminalId(to),
);

CircuitState _circuit() => CircuitState(
  circuitId: CircuitId('test-powered'),
  revision: 0,
  mode: ElectricalMode.ac1,
  components: <ComponentInstance>[
    ComponentInstance(
      id: ComponentId('rcd'),
      modelType: 'rcd_2p_ac1',
      terminals: <Terminal>[
        _terminal('nin', PhaseTag.neutral),
        _terminal('lin', PhaseTag.l1),
        _terminal('nout', PhaseTag.neutral),
        _terminal('lout', PhaseTag.l1),
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
        _terminal('rl', PhaseTag.l1),
        _terminal('rn', PhaseTag.neutral),
      ],
      parameters: const <String, Object?>{'resistanceOhm': 46.0},
    ),
  ],
  connections: <Connection>[
    _wire('w1', 'vl', 'lin'),
    _wire('w2', 'vn', 'nin'),
    _wire('w3', 'lout', 'rl'),
    _wire('w4', 'nout', 'rn'),
  ],
  sources: <SourceInstance>[
    SourceInstance(
      id: SourceId('v'),
      modelType: 'ac_voltage_source',
      terminals: <Terminal>[
        _terminal('vl', PhaseTag.l1),
        _terminal('vn', PhaseTag.neutral),
      ],
      parameters: const <String, Object?>{'voltageRmsV': 230.0},
    ),
  ],
  settings: const <String, Object?>{'frequencyHz': 50.0},
);
