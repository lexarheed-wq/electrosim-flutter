import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:electrosim_pv/electrosim_pv.dart';
import 'package:electrosim_topology/electrosim_topology.dart';

Future<void> main(List<String> args) async {
  String? output;
  for (var i = 0; i < args.length - 1; i++) {
    if (args[i] == '--output') {
      output = args[i + 1];
    }
  }
  final CircuitState circuit = _circuit();
  const TopologyEngine topologyEngine = TopologyEngine();
  const SolverPV solver = SolverPV();
  final TopologyGraph topology = topologyEngine.compile(circuit);
  final List<int> micros = <int>[];
  for (var i = 0; i < 2000; i++) {
    final Stopwatch stopwatch = Stopwatch()..start();
    final PvSolveResult result = solver.solve(circuit, topology);
    stopwatch.stop();
    if (!result.isSolved) {
      stderr.writeln('PV benchmark circuit failed to solve.');
      exitCode = 2;
      return;
    }
    micros.add(stopwatch.elapsedMicroseconds);
  }
  micros.sort();
  final Map<String, Object?> report = <String, Object?>{
    'phase': 'F7',
    'engineVersion': SolverPV.engineVersion,
    'iterations': micros.length,
    'medianMicroseconds': _percentile(micros, 0.50),
    'p95Microseconds': _percentile(micros, 0.95),
    'maxMicroseconds': micros.last,
  };
  final String encoded = const JsonEncoder.withIndent('  ').convert(report);
  if (output == null) {
    stdout.writeln(encoded);
  } else {
    await File(output).writeAsString('$encoded\n');
    stdout.writeln(encoded);
  }
}

int _percentile(List<int> sorted, double fraction) {
  final int index = math.min(
    sorted.length - 1,
    math.max(0, (sorted.length * fraction).ceil() - 1),
  );
  return sorted[index];
}

CircuitState _circuit() => CircuitState(
  circuitId: CircuitId('pv-benchmark'),
  revision: 0,
  mode: ElectricalMode.pv,
  components: <ComponentInstance>[
    ComponentInstance(
      id: ComponentId('inv'),
      modelType: 'pv_inverter',
      terminals: <Terminal>[
        Terminal(id: TerminalId('idp'), name: 'DC+', phase: PhaseTag.dcPositive),
        Terminal(id: TerminalId('idn'), name: 'DC-', phase: PhaseTag.dcNegative),
        Terminal(id: TerminalId('il'), name: 'L', phase: PhaseTag.l1),
        Terminal(id: TerminalId('in'), name: 'N', phase: PhaseTag.neutral),
      ],
      parameters: const <String, Object?>{
        'minDcVoltageV': 300.0,
        'maxDcVoltageV': 500.0,
        'nominalAcVoltageV': 230.0,
        'ratedAcPowerW': 3500.0,
        'efficiency': 0.95,
      },
    ),
    ComponentInstance(
      id: ComponentId('load'),
      modelType: 'pv_resistive_load',
      terminals: <Terminal>[
        Terminal(id: TerminalId('ll'), name: 'L', phase: PhaseTag.l1),
        Terminal(id: TerminalId('ln'), name: 'N', phase: PhaseTag.neutral),
      ],
      parameters: const <String, Object?>{'resistanceOhm': 20.0},
    ),
  ],
  connections: <Connection>[
    _wire('dcp', 'pvp', 'idp', PhaseTag.dcPositive),
    _wire('dcn', 'pvn', 'idn', PhaseTag.dcNegative),
    _wire('acl', 'il', 'll', PhaseTag.l1),
    _wire('acn', 'in', 'ln', PhaseTag.neutral),
  ],
  sources: <SourceInstance>[
    SourceInstance(
      id: SourceId('pv'),
      modelType: 'pv_array',
      terminals: <Terminal>[
        Terminal(id: TerminalId('pvp'), name: '+', phase: PhaseTag.dcPositive),
        Terminal(id: TerminalId('pvn'), name: '-', phase: PhaseTag.dcNegative),
      ],
      parameters: const <String, Object?>{
        'mppVoltageV': 400.0,
        'mppCurrentA': 10.0,
      },
    ),
  ],
  settings: const <String, Object?>{
    'irradianceWm2': 1000.0,
    'cellTemperatureC': 25.0,
  },
);

Connection _wire(String id, String from, String to, PhaseTag phase) => Connection(
  id: ConnectionId(id),
  fromTerminalId: TerminalId(from),
  toTerminalId: TerminalId(to),
  phase: phase,
);
