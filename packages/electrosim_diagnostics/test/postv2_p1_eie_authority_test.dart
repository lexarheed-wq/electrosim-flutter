import 'package:electrosim_diagnostics/electrosim_diagnostics.dart';
import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:electrosim_solver_dc/electrosim_solver_dc.dart';
import 'package:electrosim_topology/electrosim_topology.dart';
import 'package:test/test.dart';

void main() {
  test('P1.5 EIE reports source conflict without mutating electrical state', () {
    final CircuitState circuit = _incompatibleParallelSources();
    final Object before = circuit.toJson();
    final TopologyGraph topology = const TopologyEngine().compile(circuit);
    final DcSolveResult result = const SolverDC().solve(circuit, topology);

    expect(result.status, DcSolveStatus.invalid);
    expect(
      result.diagnostics.map((DcSolverDiagnostic item) => item.code),
      contains(DcDiagnosticCode.contradictoryIdealSource),
    );

    final DiagnosticReport report = const DiagnosticEngine().analyze(
      topology: topology,
      simulation: result,
    );
    expect(
      report.advice.map((EieAdvice item) => item.code),
      contains(EieAdviceCode.contradictorySource),
    );
    expect(circuit.toJson(), before);
  });
}

CircuitState _incompatibleParallelSources() => CircuitState(
  circuitId: CircuitId('p1-eie-conflicting-parallel'),
  revision: 0,
  mode: ElectricalMode.dc,
  components: <ComponentInstance>[
    ComponentInstance(
      id: ComponentId('load'),
      modelType: 'resistor',
      terminals: <Terminal>[
        Terminal(id: TerminalId('la'), name: 'A'),
        Terminal(id: TerminalId('lb'), name: 'B'),
      ],
      parameters: const <String, Object?>{'resistanceOhm': 12.0},
    ),
  ],
  sources: <SourceInstance>[
    _source('v1', 12.0),
    _source('v2', 24.0),
  ],
  connections: <Connection>[
    _w('p12', 'v1p', 'v2p'),
    _w('pl', 'v1p', 'la'),
    _w('n12', 'v1n', 'v2n'),
    _w('nl', 'v1n', 'lb'),
  ],
);

SourceInstance _source(String id, double voltageV) => SourceInstance(
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
  parameters: <String, Object?>{'voltageV': voltageV},
);

Connection _w(String id, String from, String to) => Connection(
  id: ConnectionId(id),
  fromTerminalId: TerminalId(from),
  toTerminalId: TerminalId(to),
);
