import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:electrosim_solver_dc/electrosim_solver_dc.dart';
import 'package:electrosim_topology/electrosim_topology.dart';
import 'package:test/test.dart';

CircuitState _circuit({required bool q0, required bool supplyValid}) {
  final plc = ComponentInstance(
    id: ComponentId('plc'), modelType: 'plc_dc',
    terminals: <Terminal>[
      for (int i = 0; i < 10; i++) Terminal(id: TerminalId('p$i'), name: switch (i) {
        0 => 'L+', 1 => 'M', >= 2 && <= 5 => 'I${i - 2}', _ => 'Q${i - 6}',
      }),
    ],
    controlState: <String, Object?>{'Q0': q0, 'plcSupplyValid': supplyValid},
  );
  return CircuitState(
    circuitId: CircuitId('plc-test'), revision: 0, mode: ElectricalMode.dc,
    components: <ComponentInstance>[
      plc,
      ComponentInstance(id: ComponentId('load'), modelType: 'resistor',
        terminals: <Terminal>[
          Terminal(id: TerminalId('load-a'), name: 'A'),
          Terminal(id: TerminalId('load-b'), name: 'B'),
        ], parameters: const <String, Object?>{'resistanceOhm': 1000.0}),
    ],
    sources: <SourceInstance>[
      SourceInstance(id: SourceId('v24'), modelType: 'dc_voltage_source',
        terminals: <Terminal>[
          Terminal(id: TerminalId('v+'), name: '+', phase: PhaseTag.dcPositive),
          Terminal(id: TerminalId('v-'), name: '-', phase: PhaseTag.dcNegative),
        ], parameters: const <String, Object?>{'voltageV': 24.0}),
    ],
    connections: <Connection>[
      Connection(id: ConnectionId('w1'), fromTerminalId: TerminalId('v+'), toTerminalId: TerminalId('p0')),
      Connection(id: ConnectionId('w2'), fromTerminalId: TerminalId('v-'), toTerminalId: TerminalId('p1')),
      Connection(id: ConnectionId('w3'), fromTerminalId: TerminalId('p6'), toTerminalId: TerminalId('load-a')),
      Connection(id: ConnectionId('w4'), fromTerminalId: TerminalId('load-b'), toTerminalId: TerminalId('v-')),
    ],
  );
}

void main() {
  const TopologyEngine topology = TopologyEngine();
  const SolverDC solver = SolverDC();

  test('PLC has four open output branches until Q and valid supply are projected', () {
    final result = solver.solve(_circuit(q0: true, supplyValid: false), topology.compile(_circuit(q0: true, supplyValid: false)));
    expect(result.status, DcSolveStatus.solved);
    expect(result.branch('component:plc:output:Q0').kind, DcBranchKind.openCircuit);
  });

  test('closed Q delivers solved 24 V output under load; isolated input remains nonconductive', () {
    final circuit = _circuit(q0: true, supplyValid: true);
    final result = solver.solve(circuit, topology.compile(circuit));
    expect(result.status, DcSolveStatus.solved);
    expect(result.branch('component:plc:output:Q0').kind, DcBranchKind.idealShort);
    expect(result.branch('component:load').currentA, closeTo(0.024, 1e-9));
    expect(result.branch('component:plc:output:Q1').kind, DcBranchKind.openCircuit);
    expect(result.branch('component:plc:output:Q2').kind, DcBranchKind.openCircuit);
    expect(result.branch('component:plc:output:Q3').kind, DcBranchKind.openCircuit);
  });
}
