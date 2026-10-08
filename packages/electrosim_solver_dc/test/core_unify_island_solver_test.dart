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

  test('CORE-ISLAND01 battery is an autonomous non-ideal DC source', () {
    final Terminal bp = Terminal(
      id: TerminalId('bat-pos'),
      name: '+',
      role: TerminalRole.positive,
      phase: PhaseTag.dcPositive,
    );
    final Terminal bn = Terminal(
      id: TerminalId('bat-neg'),
      name: '-',
      role: TerminalRole.negative,
      phase: PhaseTag.dcNegative,
    );
    final Terminal la = Terminal(id: TerminalId('lamp-a'), name: 'A');
    final Terminal lb = Terminal(id: TerminalId('lamp-b'), name: 'B');

    final CircuitState circuit = CircuitState(
      circuitId: CircuitId('battery-autonomous-dc'),
      revision: 0,
      mode: ElectricalMode.dc,
      components: <ComponentInstance>[
        ComponentInstance(
          id: ComponentId('battery'),
          modelType: 'pv_battery',
          terminals: <Terminal>[bp, bn],
          parameters: const <String, Object?>{
            'nominalVoltageV': 48.0,
            'internalResistanceOhm': 0.08,
            'capacityAh': 100.0,
            'initialSoc': 0.60,
            'minSoc': 0.10,
            'maxDischargeCurrentA': 60.0,
          },
        ),
        ComponentInstance(
          id: ComponentId('lamp'),
          modelType: 'lamp',
          terminals: <Terminal>[la, lb],
          parameters: const <String, Object?>{
            'resistanceOhm': 48.0,
            ReceiverNominalRating.voltageKey: 48.0,
            ReceiverNominalRating.currentKey: 1.0,
            ReceiverNominalRating.powerKey: 48.0,
          },
        ),
      ],
      connections: <Connection>[
        _wire('bat-plus', bp.id, la.id),
        _wire('bat-minus', lb.id, bn.id),
      ],
    );

    final TopologyGraph topology = const TopologyEngine().compile(circuit);
    final DcSolveResult result = const SolverDC().solve(circuit, topology);

    expect(result.status, DcSolveStatus.solved);
    final double expectedCurrent = 48.0 / (48.0 + 0.08);
    expect(
      result.branch('component:lamp').currentA,
      closeTo(expectedCurrent, 1e-6),
    );
    expect(
      result.branch('component:battery').currentA!.abs(),
      closeTo(expectedCurrent, 1e-6),
    );
    expect(
      result.branch('component:lamp').voltageV.abs(),
      closeTo(48.0 * 48.0 / 48.08, 1e-6),
    );
  });

}

Connection _wire(String id, TerminalId from, TerminalId to) => Connection(
  id: ConnectionId(id),
  fromTerminalId: from,
  toTerminalId: to,
);
