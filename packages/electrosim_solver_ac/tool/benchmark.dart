import 'dart:convert';
import 'dart:io';

import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:electrosim_solver_ac/electrosim_solver_ac.dart';
import 'package:electrosim_topology/electrosim_topology.dart';

void main(List<String> args) {
  String? output;
  for (var i = 0; i < args.length - 1; i++) {
    if (args[i] == '--output') {
      output = args[i + 1];
    }
  }
  final CircuitState circuit = _benchmarkCircuit(80);
  const TopologyEngine topologyEngine = TopologyEngine();
  const SolverAC1 solver = SolverAC1();
  final TopologyGraph topology = topologyEngine.compile(circuit);
  final Stopwatch stopwatch = Stopwatch()..start();
  Ac1SolveResult? result;
  const int iterations = 50;
  for (var i = 0; i < iterations; i++) {
    result = solver.solve(circuit, topology);
  }
  stopwatch.stop();
  if (result == null || !result.isSolved) {
    stderr.writeln('AC1 benchmark failed to solve.');
    exitCode = 1;
    return;
  }
  final Map<String, Object?> payload = <String, Object?>{
    'phase': 'F5',
    'engineVersion': SolverAC1.engineVersion,
    'branches': 80,
    'iterations': iterations,
    'elapsedMicroseconds': stopwatch.elapsedMicroseconds,
    'averageMicroseconds': stopwatch.elapsedMicroseconds / iterations,
    'maxMatrixResidual': result.maxMatrixResidual,
  };
  final String encoded = const JsonEncoder.withIndent('  ').convert(payload);
  if (output != null) {
    File(output).writeAsStringSync('$encoded\n');
  }
  stdout.writeln(encoded);
}

CircuitState _benchmarkCircuit(int branches) {
  final List<ComponentInstance> components = <ComponentInstance>[];
  final List<Connection> connections = <Connection>[];
  for (var i = 0; i < branches; i++) {
    final String id = 'r$i';
    components.add(
      ComponentInstance(
        id: ComponentId(id),
        modelType: 'resistor',
        terminals: <Terminal>[
          Terminal(id: TerminalId('${id}a'), name: 'A'),
          Terminal(id: TerminalId('${id}b'), name: 'B'),
        ],
        parameters: <String, Object?>{'resistanceOhm': 100.0 + i},
      ),
    );
    connections.addAll(<Connection>[
      Connection(
        id: ConnectionId('p$i'),
        fromTerminalId: TerminalId('vp'),
        toTerminalId: TerminalId('${id}a'),
      ),
      Connection(
        id: ConnectionId('n$i'),
        fromTerminalId: TerminalId('${id}b'),
        toTerminalId: TerminalId('vn'),
      ),
    ]);
  }
  return CircuitState(
    circuitId: CircuitId('ac1-benchmark'),
    revision: 0,
    mode: ElectricalMode.ac1,
    components: components,
    connections: connections,
    sources: <SourceInstance>[
      SourceInstance(
        id: SourceId('v'),
        modelType: 'ac_voltage_source',
        terminals: <Terminal>[
          Terminal(id: TerminalId('vp'), name: 'L'),
          Terminal(id: TerminalId('vn'), name: 'N'),
        ],
        parameters: const <String, Object?>{'voltageRmsV': 230.0, 'phaseDeg': 0.0},
      ),
    ],
    settings: const <String, Object?>{'frequencyHz': 50.0},
  );
}
