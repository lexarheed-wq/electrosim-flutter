import 'package:electrosim/runtime/electrosim_runtime_engine.dart';
import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:electrosim_solver_dc/electrosim_solver_dc.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('F17 runtime evaluates a canonical healthy DC circuit end to end', () {
    final Terminal sourcePositive = Terminal(
      id: TerminalId('vp'),
      name: '+',
      role: TerminalRole.positive,
      phase: PhaseTag.dcPositive,
    );
    final Terminal sourceNegative = Terminal(
      id: TerminalId('vn'),
      name: '-',
      role: TerminalRole.negative,
      phase: PhaseTag.dcNegative,
    );
    final Terminal resistorA = Terminal(
      id: TerminalId('r1a'),
      name: 'A',
      role: TerminalRole.input,
    );
    final Terminal resistorB = Terminal(
      id: TerminalId('r1b'),
      name: 'B',
      role: TerminalRole.output,
    );

    final CircuitState circuit = CircuitState(
      circuitId: CircuitId('f17-runtime-smoke'),
      revision: 1,
      mode: ElectricalMode.dc,
      sources: <SourceInstance>[
        SourceInstance(
          id: SourceId('source-1'),
          modelType: 'dc_voltage_source',
          terminals: <Terminal>[sourcePositive, sourceNegative],
          parameters: const <String, Object?>{'voltageV': 24.0},
        ),
      ],
      components: <ComponentInstance>[
        ComponentInstance(
          id: ComponentId('r1'),
          modelType: 'resistor',
          terminals: <Terminal>[resistorA, resistorB],
          parameters: const <String, Object?>{'resistanceOhm': 24.0},
        ),
      ],
      connections: <Connection>[
        Connection(
          id: ConnectionId('w1'),
          fromTerminalId: sourcePositive.id,
          toTerminalId: resistorA.id,
        ),
        Connection(
          id: ConnectionId('w2'),
          fromTerminalId: resistorB.id,
          toTerminalId: sourceNegative.id,
        ),
      ],
    );

    final ElectroSimRuntimeSnapshot snapshot =
        const ElectroSimRuntimeEngine().evaluate(circuit);

    expect(snapshot.dc.status, DcSolveStatus.solved);
    expect(snapshot.dc.branch('component:r1').currentA, closeTo(1.0, 1e-9));
    expect(snapshot.topology.circuitRevision, 1);
    expect(snapshot.diagnostics.circuitRevision, 1);
  });

  test('F17 runtime preserves circuit identity through topology, solver and EIE', () {
    final Terminal p = Terminal(
      id: TerminalId('p'),
      name: '+',
      role: TerminalRole.positive,
      phase: PhaseTag.dcPositive,
    );
    final Terminal n = Terminal(
      id: TerminalId('n'),
      name: '-',
      role: TerminalRole.negative,
      phase: PhaseTag.dcNegative,
    );

    final CircuitState circuit = CircuitState(
      circuitId: CircuitId('f17-identity'),
      revision: 7,
      mode: ElectricalMode.dc,
      sources: <SourceInstance>[
        SourceInstance(
          id: SourceId('source'),
          modelType: 'dc_voltage_source',
          terminals: <Terminal>[p, n],
          parameters: const <String, Object?>{'voltageV': 12.0},
        ),
      ],
    );

    final ElectroSimRuntimeSnapshot snapshot =
        const ElectroSimRuntimeEngine().evaluate(circuit);

    expect(snapshot.topology.circuitId, circuit.circuitId);
    expect(snapshot.topology.circuitRevision, circuit.revision);
    expect(snapshot.dc.circuitId, circuit.circuitId);
    expect(snapshot.dc.circuitRevision, circuit.revision);
    expect(snapshot.diagnostics.circuitId, circuit.circuitId);
    expect(snapshot.diagnostics.circuitRevision, circuit.revision);
  });
}
