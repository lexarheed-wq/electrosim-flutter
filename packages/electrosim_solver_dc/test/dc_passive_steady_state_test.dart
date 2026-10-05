import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:electrosim_solver_dc/electrosim_solver_dc.dart';
import 'package:electrosim_topology/electrosim_topology.dart';
import 'package:test/test.dart';

void main() {
  const SolverDC solver = SolverDC();
  const TopologyEngine topology = TopologyEngine();

  DcSolveResult solve(CircuitState circuit) =>
      solver.solve(circuit, topology.compile(circuit));

  test('steady-state DC inductor behaves as ideal short', () {
    final CircuitState circuit = _series(
      modelType: 'inductor',
      parameters: const <String, Object?>{'inductanceH': 0.1},
    );
    final DcSolveResult result = solve(circuit);
    expect(result.isSolved, isTrue);
    expect(result.branch('component:x').voltageV, closeTo(0, 1e-10));
    expect(result.branch('component:r').currentA?.abs(), closeTo(.24, 1e-9));
  });

  test('steady-state DC capacitor behaves as open circuit', () {
    final CircuitState circuit = _series(
      modelType: 'capacitor',
      parameters: const <String, Object?>{'capacitanceF': .001},
    );
    final DcSolveResult result = solve(circuit);
    expect(result.isSolved, isTrue);
    expect(result.branch('component:x').kind, DcBranchKind.openCircuit);
    expect(result.branch('component:x').currentA, 0.0);
    expect(result.branch('component:r').currentA, 0.0);
  });
}

CircuitState _series({
  required String modelType,
  required Map<String, Object?> parameters,
}) =>
    CircuitState(
      circuitId: CircuitId('dc-$modelType'),
      revision: 0,
      mode: ElectricalMode.dc,
      sources: <SourceInstance>[
        SourceInstance(
          id: SourceId('v'),
          modelType: 'dc_voltage_source',
          terminals: <Terminal>[_t('vp', '+'), _t('vn', '−')],
          parameters: const <String, Object?>{'voltageV': 24.0},
        ),
      ],
      components: <ComponentInstance>[
        ComponentInstance(
          id: ComponentId('x'),
          modelType: modelType,
          terminals: <Terminal>[_t('x1', '1'), _t('x2', '2')],
          parameters: parameters,
        ),
        ComponentInstance(
          id: ComponentId('r'),
          modelType: 'resistor',
          terminals: <Terminal>[_t('r1', '1'), _t('r2', '2')],
          parameters: const <String, Object?>{'resistanceOhm': 100.0},
        ),
      ],
      connections: <Connection>[
        _w('w1', 'vp', 'x1'),
        _w('w2', 'x2', 'r1'),
        _w('w3', 'r2', 'vn'),
      ],
    );

Terminal _t(String id, String name) =>
    Terminal(id: TerminalId(id), name: name);

Connection _w(String id, String from, String to) => Connection(
      id: ConnectionId(id),
      fromTerminalId: TerminalId(from),
      toTerminalId: TerminalId(to),
    );
