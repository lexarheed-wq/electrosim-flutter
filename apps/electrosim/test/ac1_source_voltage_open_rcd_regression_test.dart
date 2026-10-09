import 'package:electrosim/f9_source_voltage_readout.dart';
import 'package:electrosim/runtime/electrosim_runtime_engine.dart';
import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ideal source retains 230 V when RCD opens both poles', () {
    final circuit = _circuit(rcdClosed: false);
    final snapshot = const ElectroSimRuntimeEngine().evaluate(circuit);
    expect(snapshot.solverKind, ElectroSimRuntimeSolverKind.ac1);
    expect(
      F9SourceVoltageReadout.voltageV(
        snapshot,
        circuit.sources.single,
        simulationRunning: true,
      ),
      closeTo(230, 1e-6),
    );
  });

  test('ideal source retains 230 V under load with RCD closed', () {
    final circuit = _circuit(rcdClosed: true);
    final snapshot = const ElectroSimRuntimeEngine().evaluate(circuit);
    expect(snapshot.solved, isTrue);
    expect(
      F9SourceVoltageReadout.voltageV(
        snapshot,
        circuit.sources.single,
        simulationRunning: true,
      ),
      closeTo(230, 1e-6),
    );
  });

  test('display cannot invent voltage on disabled or absent source', () {
    final circuit = _circuit(rcdClosed: false);
    final snapshot = const ElectroSimRuntimeEngine().evaluate(circuit);
    final source = circuit.sources.single;

    final disabled = SourceInstance(
      id: source.id,
      modelType: source.modelType,
      terminals: source.terminals,
      parameters: source.parameters,
      enabled: false,
    );
    expect(
      F9SourceVoltageReadout.voltageV(
        snapshot, disabled, simulationRunning: true,
      ),
      0,
    );
    expect(
      F9SourceVoltageReadout.voltageV(
        null, source, simulationRunning: true,
      ),
      0,
    );
    final currentSource = SourceInstance(
      id: SourceId('unmatched-current'),
      modelType: 'ac_current_source',
      terminals: source.terminals,
      parameters: const {'currentRmsA': 2.0},
    );
    expect(
      F9SourceVoltageReadout.voltageV(
        snapshot, currentSource, simulationRunning: true,
      ),
      0,
    );
  });
}

Terminal _terminal(String id, PhaseTag phase) => Terminal(
  id: TerminalId(id),
  name: id,
  phase: phase,
);

Connection _wire(String id, String from, String to) => Connection(
  id: ConnectionId(id),
  fromTerminalId: TerminalId(from),
  toTerminalId: TerminalId(to),
);

CircuitState _circuit({required bool rcdClosed}) => CircuitState(
  circuitId: CircuitId('source-voltage-open-rcd'),
  revision: 0,
  mode: ElectricalMode.ac1,
  sources: <SourceInstance>[
    SourceInstance(
      id: SourceId('source'),
      modelType: 'ac_voltage_source',
      terminals: <Terminal>[
        _terminal('vl', PhaseTag.l1),
        _terminal('vn', PhaseTag.neutral),
      ],
      parameters: const <String, Object?>{'voltageRmsV': 230.0},
    ),
  ],
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
      parameters: const <String, Object?>{
        ProtectionRating.ratedCurrentKey: 16.0,
        ComponentParameterKeys.residualTripCurrentA: 0.03,
      },
      controlState: <String, Object?>{
        'closed': rcdClosed,
        'tripped': false,
      },
    ),
    ComponentInstance(
      id: ComponentId('load'),
      modelType: 'resistor',
      terminals: <Terminal>[
        _terminal('rl', PhaseTag.l1),
        _terminal('rn', PhaseTag.neutral),
      ],
      parameters: const <String, Object?>{'resistanceOhm': 529.0},
    ),
  ],
  connections: <Connection>[
    _wire('w1', 'vl', 'lin'),
    _wire('w2', 'vn', 'nin'),
    _wire('w3', 'lout', 'rl'),
    _wire('w4', 'nout', 'rn'),
  ],
  settings: const <String, Object?>{'frequencyHz': 50.0},
);
