import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:electrosim_solver_dc/electrosim_solver_dc.dart';
import 'package:electrosim_topology/electrosim_topology.dart';
import 'package:test/test.dart';

void main() {
  test('unused passive terminal-block poles do not singularize energized DC island', () {
    final List<Terminal> block = <Terminal>[
      for (var i = 0; i < 10; i++) Terminal(id: TerminalId('x1-$i'), name: '${i + 1}'),
    ];
    final Terminal sourcePositive = Terminal(
      id: TerminalId('v-pos'),
      name: '+',
      role: TerminalRole.positive,
      phase: PhaseTag.dcPositive,
    );
    final Terminal sourceNegative = Terminal(
      id: TerminalId('v-neg'),
      name: '-',
      role: TerminalRole.negative,
      phase: PhaseTag.dcNegative,
    );
    final Terminal loadA = Terminal(id: TerminalId('load-a'), name: 'A');
    final Terminal loadB = Terminal(id: TerminalId('load-b'), name: 'B');

    final CircuitState circuit = CircuitState(
      circuitId: CircuitId('core-unify-terminal-islands'),
      revision: 0,
      mode: ElectricalMode.dc,
      components: <ComponentInstance>[
        ComponentInstance(
          id: ComponentId('x1'),
          modelType: 'terminal_block_5',
          terminals: block,
        ),
        ComponentInstance(
          id: ComponentId('load'),
          modelType: 'resistor',
          terminals: <Terminal>[loadA, loadB],
          parameters: const <String, Object?>{'resistanceOhm': 24.0},
        ),
      ],
      sources: <SourceInstance>[
        SourceInstance(
          id: SourceId('v1'),
          modelType: 'dc_voltage_source',
          terminals: <Terminal>[sourcePositive, sourceNegative],
          parameters: const <String, Object?>{'voltageV': 24.0},
        ),
      ],
      connections: <Connection>[
        _wire('w1', sourcePositive.id, block[0].id),
        _wire('w2', block[5].id, loadA.id),
        _wire('w3', loadB.id, sourceNegative.id),
      ],
    );

    final TopologyGraph topology = const TopologyEngine().compile(circuit);
    final DcSolveResult result = const SolverDC().solve(circuit, topology);

    expect(result.status, DcSolveStatus.solved);
    expect(result.branch('component:load').currentA, closeTo(1.0, 1e-9));
    expect(
      result.diagnostics.where(
        (DcSolverDiagnostic item) =>
            item.code == DcDiagnosticCode.floatingElectricalIsland,
      ),
      isNotEmpty,
    );
  });
}

Connection _wire(String id, TerminalId from, TerminalId to) => Connection(
  id: ConnectionId(id),
  fromTerminalId: from,
  toTerminalId: to,
);
