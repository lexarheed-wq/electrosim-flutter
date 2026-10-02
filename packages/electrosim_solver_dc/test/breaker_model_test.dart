import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:electrosim_solver_dc/electrosim_solver_dc.dart';
import 'package:electrosim_topology/electrosim_topology.dart';
import 'package:test/test.dart';

void main() {
  test('closed breaker is solved as an ideal protection switch', () {
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
    final Terminal qf1 = Terminal(
      id: TerminalId('qf1-1'),
      name: '1',
      role: TerminalRole.input,
    );
    final Terminal qf2 = Terminal(
      id: TerminalId('qf1-2'),
      name: '2',
      role: TerminalRole.output,
    );
    final Terminal h1 = Terminal(id: TerminalId('h1-l'), name: 'L');
    final Terminal h2 = Terminal(id: TerminalId('h1-n'), name: 'N');

    final CircuitState circuit = CircuitState(
      circuitId: CircuitId('breaker-model'),
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
          id: ComponentId('breaker'),
          modelType: 'breaker',
          terminals: <Terminal>[qf1, qf2],
          controlState: const <String, Object?>{
            'closed': true,
            'tripped': false,
          },
        ),
        ComponentInstance(
          id: ComponentId('lamp'),
          modelType: 'lamp',
          terminals: <Terminal>[h1, h2],
          parameters: const <String, Object?>{'resistanceOhm': 24.0},
        ),
      ],
      connections: <Connection>[
        Connection(
          id: ConnectionId('w1'),
          fromTerminalId: vp.id,
          toTerminalId: qf1.id,
        ),
        Connection(
          id: ConnectionId('w2'),
          fromTerminalId: qf2.id,
          toTerminalId: h1.id,
        ),
        Connection(
          id: ConnectionId('w3'),
          fromTerminalId: h2.id,
          toTerminalId: vn.id,
        ),
      ],
    );

    final TopologyGraph topology = const TopologyEngine().compile(circuit);
    final DcSolveResult result = const SolverDC().solve(circuit, topology);

    expect(result.status, DcSolveStatus.solved);
    expect(result.branch('component:breaker').kind, DcBranchKind.idealSwitch);
    expect(result.branch('component:breaker').currentA, closeTo(1.0, 1e-9));
    expect(result.branch('component:lamp').currentA, closeTo(1.0, 1e-9));
  });
}
