import 'dart:convert';
import 'dart:io';

import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:electrosim_solver_dc/electrosim_solver_dc.dart';
import 'package:electrosim_topology/electrosim_topology.dart';

void main(List<String> args) {
  String? outputPath;
  for (var i = 0; i < args.length; i++) {
    if (args[i] == '--output' && i + 1 < args.length) {
      outputPath = args[++i];
    }
  }
  const TopologyEngine topologyEngine = TopologyEngine();
  const SolverDC solver = SolverDC();
  final CircuitState circuit = _benchmarkCircuit(40);
  final TopologyGraph topology = topologyEngine.compile(circuit);
  for (var i = 0; i < 20; i++) {
    solver.solve(circuit, topology);
  }
  final List<int> samples = <int>[];
  for (var i = 0; i < 200; i++) {
    final Stopwatch stopwatch = Stopwatch()..start();
    final DcSolveResult result = solver.solve(circuit, topology);
    stopwatch.stop();
    if (!result.isSolved) {
      stderr.writeln('benchmark circuit did not solve');
      exitCode = 1;
      return;
    }
    samples.add(stopwatch.elapsedMicroseconds);
  }
  samples.sort();
  final Map<String, Object?> report = <String, Object?>{
    'phase': 'F3',
    'engineVersion': SolverDC.engineVersion,
    'status': 'PASS',
    'circuit': '40-resistor-series',
    'iterations': samples.length,
    'minMicros': samples.first,
    'p50Micros': samples[(samples.length * 0.50).floor()],
    'p95Micros': samples[(samples.length * 0.95).floor().clamp(0, samples.length - 1).toInt()],
    'maxMicros': samples.last,
  };
  final String encoded = const JsonEncoder.withIndent('  ').convert(report);
  stdout.writeln(encoded);
  if (outputPath != null) {
    File(outputPath).writeAsStringSync('$encoded\n');
  }
}

CircuitState _benchmarkCircuit(int count) {
  final List<ComponentInstance> components = <ComponentInstance>[];
  final List<Connection> connections = <Connection>[];
  for (var i = 0; i < count; i++) {
    components.add(
      ComponentInstance(
        id: ComponentId('r$i'),
        modelType: 'resistor',
        terminals: <Terminal>[
          Terminal(id: TerminalId('r${i}a'), name: 'A'),
          Terminal(id: TerminalId('r${i}b'), name: 'B'),
        ],
        parameters: const <String, Object?>{'resistanceOhm': 10.0},
      ),
    );
    if (i == 0) {
      connections.add(
        Connection(id: ConnectionId('w-start'), fromTerminalId: TerminalId('vp'), toTerminalId: TerminalId('r0a')),
      );
    } else {
      connections.add(
        Connection(
          id: ConnectionId('w-$i'),
          fromTerminalId: TerminalId('r${i - 1}b'),
          toTerminalId: TerminalId('r${i}a'),
        ),
      );
    }
  }
  connections.add(
    Connection(
      id: ConnectionId('w-end'),
      fromTerminalId: TerminalId('r${count - 1}b'),
      toTerminalId: TerminalId('vn'),
    ),
  );
  return CircuitState(
    circuitId: CircuitId('benchmark-$count'),
    revision: 0,
    mode: ElectricalMode.dc,
    components: components,
    connections: connections,
    sources: <SourceInstance>[
      SourceInstance(
        id: SourceId('v1'),
        modelType: 'dc_voltage_source',
        terminals: <Terminal>[
          Terminal(id: TerminalId('vp'), name: '+', role: TerminalRole.positive, phase: PhaseTag.dcPositive),
          Terminal(id: TerminalId('vn'), name: '-', role: TerminalRole.negative, phase: PhaseTag.dcNegative),
        ],
        parameters: const <String, Object?>{'voltageV': 400.0},
      ),
    ],
  );
}
