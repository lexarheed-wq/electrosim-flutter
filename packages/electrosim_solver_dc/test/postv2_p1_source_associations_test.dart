import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:electrosim_solver_dc/electrosim_solver_dc.dart';
import 'package:electrosim_topology/electrosim_topology.dart';
import 'package:test/test.dart';

void main() {
  const TopologyEngine topologyEngine = TopologyEngine();
  const SolverDC solver = SolverDC();

  ({TopologyGraph topology, DcSolveResult result}) solve(CircuitState circuit) {
    final TopologyGraph topology = topologyEngine.compile(circuit);
    return (
      topology: topology,
      result: solver.solve(circuit, topology),
    );
  }

  group('Post-V2 P1.3 DC source associations', () {
    test('P1-DC-SERIES-01: two 12 V sources add to 24 V', () {
      final (:topology, :result) = solve(
        _seriesSources(
          id: 'p1-series-12-12',
          voltages: const <double>[12, 12],
          loadOhm: 12,
        ),
      );

      expect(result.status, DcSolveStatus.solved);
      expect(result.branch('component:load').voltageV.abs(), closeTo(24, 1e-9));
      expect(result.branch('component:load').currentA?.abs(), closeTo(2, 1e-9));
      _expectResiduals(result);
      _expectNoTopologyErrors(topology);
    });

    test('P1-DC-SERIES-02: 24 V + 12 V add to 36 V', () {
      final (:topology, :result) = solve(
        _seriesSources(
          id: 'p1-series-24-12',
          voltages: const <double>[24, 12],
          loadOhm: 12,
        ),
      );

      expect(result.status, DcSolveStatus.solved);
      expect(result.branch('component:load').voltageV.abs(), closeTo(36, 1e-9));
      expect(result.branch('component:load').currentA?.abs(), closeTo(3, 1e-9));
      _expectResiduals(result);
      _expectNoTopologyErrors(topology);
    });

    test('P1-DC-SERIES-03: three 12 V sources add to 36 V', () {
      final (:topology, :result) = solve(
        _seriesSources(
          id: 'p1-series-12-12-12',
          voltages: const <double>[12, 12, 12],
          loadOhm: 12,
        ),
      );

      expect(result.status, DcSolveStatus.solved);
      expect(result.branch('component:load').voltageV.abs(), closeTo(36, 1e-9));
      expect(result.branch('component:load').currentA?.abs(), closeTo(3, 1e-9));
      _expectResiduals(result);
      _expectNoTopologyErrors(topology);
    });

    test('P1-DC-OPPOSED-01: opposed 24 V and 12 V yield 12 V algebraically', () {
      final CircuitState circuit = _opposedSources();
      final (:topology, :result) = solve(circuit);

      expect(result.status, DcSolveStatus.solved);
      expect(result.branch('component:load').voltageV.abs(), closeTo(12, 1e-9));
      expect(result.branch('component:load').currentA?.abs(), closeTo(1, 1e-9));
      _expectResiduals(result);
      _expectNoTopologyErrors(topology);
    });

    test('P1-DC-MIDPOINT-01: series midpoint exposes +12 / 0 / -12 structure', () {
      final CircuitState circuit = _seriesSources(
        id: 'p1-midpoint',
        voltages: const <double>[12, 12],
        loadOhm: 24,
      );
      final (:topology, :result) = solve(circuit);

      expect(result.status, DcSolveStatus.solved);
      final double positive = _nodeVoltage(result, topology, 'v1p');
      final double midpoint = _nodeVoltage(result, topology, 'v1n');
      final double negative = _nodeVoltage(result, topology, 'v2n');

      expect((positive - midpoint).abs(), closeTo(12, 1e-9));
      expect((midpoint - negative).abs(), closeTo(12, 1e-9));
      expect((positive - negative).abs(), closeTo(24, 1e-9));
      _expectResiduals(result);
      _expectNoTopologyErrors(topology);
    });

    test('P1-DC-PARALLEL-01: compatible ideal 12 V sources are representable', () {
      final (:topology, :result) = solve(
        _parallelSources(voltageA: 12, voltageB: 12),
      );

      expect(result.status, DcSolveStatus.solved);
      expect(result.branch('component:load').voltageV.abs(), closeTo(12, 1e-9));
      expect(result.branch('component:load').currentA?.abs(), closeTo(1, 1e-9));
      expect(
        result.diagnostics.map((DcSolverDiagnostic d) => d.code),
        isNot(contains(DcDiagnosticCode.contradictoryIdealSource)),
      );
      _expectResiduals(result);
      _expectNoTopologyErrors(topology);
    });

    test(
      'P1-DC-PARALLEL-02: incompatible ideal 12 V / 24 V sources are diagnosed',
      () {
        final (:topology, :result) = solve(
          _parallelSources(voltageA: 12, voltageB: 24),
        );

        expect(result.status, DcSolveStatus.invalid);
        expect(
          result.diagnostics.map((DcSolverDiagnostic d) => d.code),
          contains(DcDiagnosticCode.contradictoryIdealSource),
        );
        expect(
          topology.findings.where(
            (TopologyFinding f) =>
                f.severity == TopologyFindingSeverity.error,
          ),
          isEmpty,
        );
      },
    );
  });
}

CircuitState _seriesSources({
  required String id,
  required List<double> voltages,
  required double loadOhm,
}) {
  assert(voltages.isNotEmpty);
  final List<SourceInstance> sources = <SourceInstance>[
    for (var i = 0; i < voltages.length; i++)
      _source('v${i + 1}', voltages[i]),
  ];

  final List<Connection> connections = <Connection>[
    Connection(
      id: ConnectionId('load-positive'),
      fromTerminalId: TerminalId('v1p'),
      toTerminalId: TerminalId('load-a'),
    ),
    Connection(
      id: ConnectionId('load-negative'),
      fromTerminalId: TerminalId('load-b'),
      toTerminalId: TerminalId('v${voltages.length}n'),
    ),
    for (var i = 1; i < voltages.length; i++)
      Connection(
        id: ConnectionId('series-$i'),
        fromTerminalId: TerminalId('v${i + 1}p'),
        toTerminalId: TerminalId('v${i}n'),
      ),
  ];

  return CircuitState(
    circuitId: CircuitId(id),
    revision: 0,
    mode: ElectricalMode.dc,
    components: <ComponentInstance>[
      _resistor('load', loadOhm),
    ],
    connections: connections,
    sources: sources,
  );
}

CircuitState _opposedSources() => CircuitState(
  circuitId: CircuitId('p1-opposed-24-12'),
  revision: 0,
  mode: ElectricalMode.dc,
  components: <ComponentInstance>[_resistor('load', 12)],
  connections: <Connection>[
    Connection(
      id: ConnectionId('common-negative'),
      fromTerminalId: TerminalId('v1n'),
      toTerminalId: TerminalId('v2n'),
    ),
    Connection(
      id: ConnectionId('load-a'),
      fromTerminalId: TerminalId('v1p'),
      toTerminalId: TerminalId('load-a'),
    ),
    Connection(
      id: ConnectionId('load-b'),
      fromTerminalId: TerminalId('load-b'),
      toTerminalId: TerminalId('v2p'),
    ),
  ],
  sources: <SourceInstance>[
    _source('v1', 24),
    _source('v2', 12),
  ],
);

CircuitState _parallelSources({
  required double voltageA,
  required double voltageB,
}) => CircuitState(
  circuitId: CircuitId('p1-parallel-$voltageA-$voltageB'),
  revision: 0,
  mode: ElectricalMode.dc,
  components: <ComponentInstance>[_resistor('load', 12)],
  connections: <Connection>[
    Connection(
      id: ConnectionId('positive-bus-source'),
      fromTerminalId: TerminalId('v1p'),
      toTerminalId: TerminalId('v2p'),
    ),
    Connection(
      id: ConnectionId('positive-bus-load'),
      fromTerminalId: TerminalId('v1p'),
      toTerminalId: TerminalId('load-a'),
    ),
    Connection(
      id: ConnectionId('negative-bus-source'),
      fromTerminalId: TerminalId('v1n'),
      toTerminalId: TerminalId('v2n'),
    ),
    Connection(
      id: ConnectionId('negative-bus-load'),
      fromTerminalId: TerminalId('v1n'),
      toTerminalId: TerminalId('load-b'),
    ),
  ],
  sources: <SourceInstance>[
    _source('v1', voltageA),
    _source('v2', voltageB),
  ],
);

SourceInstance _source(String id, double voltage) => SourceInstance(
  id: SourceId(id),
  modelType: 'dc_voltage_source',
  terminals: <Terminal>[
    Terminal(
      id: TerminalId('${id}p'),
      name: '+',
      role: TerminalRole.positive,
      phase: PhaseTag.dcPositive,
    ),
    Terminal(
      id: TerminalId('${id}n'),
      name: '-',
      role: TerminalRole.negative,
      phase: PhaseTag.dcNegative,
    ),
  ],
  parameters: <String, Object?>{'voltageV': voltage},
);

ComponentInstance _resistor(String id, double resistanceOhm) => ComponentInstance(
  id: ComponentId(id),
  modelType: 'resistor',
  terminals: <Terminal>[
    Terminal(id: TerminalId('${id}-a'), name: 'A'),
    Terminal(id: TerminalId('${id}-b'), name: 'B'),
  ],
  parameters: <String, Object?>{'resistanceOhm': resistanceOhm},
);

double _nodeVoltage(
  DcSolveResult result,
  TopologyGraph topology,
  String terminalId,
) {
  final String nodeId = topology.terminalToNode[TerminalId(terminalId)]!;
  return result.nodeVoltages[nodeId]!;
}

void _expectResiduals(DcSolveResult result) {
  expect(result.maxMatrixResidual, isNotNull);
  expect(result.maxMatrixResidual!, lessThan(1e-9));
  for (final double residual in result.kclResiduals.values) {
    expect(residual.abs(), lessThan(1e-9));
  }
  for (final double residual in result.kvlResiduals.values) {
    expect(residual.abs(), lessThan(1e-9));
  }
}

void _expectNoTopologyErrors(TopologyGraph topology) {
  expect(
    topology.findings.where(
      (TopologyFinding finding) =>
          finding.severity == TopologyFindingSeverity.error,
    ),
    isEmpty,
  );
}
