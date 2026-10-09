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
    // The open poles may be removed from the solver's branch list.
    // Absent branches and branches with zero current are both physically open.
    for (final pole in <String>['N', 'L']) {
      final candidates = simulation.snapshot.ac1.branchResults.where(
        (branch) => branch.id == 'component:rcd:power:$pole',
      );
      for (final branch in candidates) {
        expect(branch.current?.magnitude ?? 0.0, closeTo(0, 1e-9));
      }
    }
    expect(simulation.testResidualDevice(ComponentId('rcd')), isFalse);
    simulation.rearmProtection(ComponentId('rcd'));
    expect(simulation.snapshot.protectionTripped(ComponentId('rcd')), isFalse);
  });

  test('unpowered RCD test T cannot invent a trip', () {
    final circuit = _circuit(powered: false);
    final simulation = ElectroSimSimulationController(circuit: circuit);
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

CircuitState _circuit({bool powered = true}) => CircuitState(
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
      parameters: <String, Object?>{'voltageRmsV': powered ? 230.0 : 0.0},
    ),
  ],
  settings: const <String, Object?>{'frequencyHz': 50.0},
);
