import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:electrosim_solver_dc/electrosim_solver_dc.dart';
import 'package:electrosim_topology/electrosim_topology.dart';
import 'package:test/test.dart';

void main() {
  test('canonical lamp is solved as a resistive DC load', () {
    final Terminal vp = Terminal(
      id: TerminalId('vp'),
      name: '+',
      role: TerminalRole.positive,
      phase: PhaseTag.dcPositive,
    );
    final Terminal vn = Terminal(
      id: TerminalId('vn'),
      name: '-',
      role: TerminalRole.negative,
      phase: PhaseTag.dcNegative,
    );
    final Terminal a = Terminal(id: TerminalId('a'), name: 'A');
    final Terminal b = Terminal(id: TerminalId('b'), name: 'B');

    final CircuitState circuit = CircuitState(
      circuitId: CircuitId('lamp-alias'),
      revision: 1,
      mode: ElectricalMode.dc,
      sources: <SourceInstance>[
        SourceInstance(
          id: SourceId('source'),
          modelType: 'dc_voltage_source',
          terminals: <Terminal>[vp, vn],
          parameters: const <String, Object?>{'voltageV': 24.0},
        ),
      ],
      components: <ComponentInstance>[
        ComponentInstance(
          id: ComponentId('lamp'),
          modelType: 'lamp',
          terminals: <Terminal>[a, b],
          parameters: const <String, Object?>{'resistanceOhm': 24.0},
        ),
      ],
      connections: <Connection>[
        Connection(id: ConnectionId('w1'), fromTerminalId: vp.id, toTerminalId: a.id),
        Connection(id: ConnectionId('w2'), fromTerminalId: b.id, toTerminalId: vn.id),
      ],
    );

    final TopologyGraph topology = const TopologyEngine().compile(circuit);
    final DcSolveResult result = const SolverDC().solve(circuit, topology);

    expect(result.status, DcSolveStatus.solved);
    expect(result.branch('component:lamp').currentA, closeTo(1.0, 1e-9));
  });
}
