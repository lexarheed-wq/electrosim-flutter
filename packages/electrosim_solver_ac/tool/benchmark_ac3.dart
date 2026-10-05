import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:electrosim_solver_ac/electrosim_solver_ac.dart';
import 'package:electrosim_topology/electrosim_topology.dart';

Future<void> main(List<String> args) async {
  String? output;
  for (var i = 0; i < args.length - 1; i++) {
    if (args[i] == '--output') {
      output = args[i + 1];
    }
  }
  final CircuitState circuit = _benchmarkCircuit(48);
  const TopologyEngine topologyEngine = TopologyEngine();
  const SolverAC3 solver = SolverAC3();
  final TopologyGraph topology = topologyEngine.compile(circuit);
  final List<int> micros = <int>[];
  for (var i = 0; i < 30; i++) {
    final Stopwatch stopwatch = Stopwatch()..start();
    final Ac3SolveResult result = solver.solve(circuit, topology);
    stopwatch.stop();
    if (!result.isSolved) {
      stderr.writeln('AC3 benchmark circuit failed to solve.');
      exitCode = 2;
      return;
    }
    micros.add(stopwatch.elapsedMicroseconds);
  }
  micros.sort();
  final Map<String, Object?> report = <String, Object?>{
    'phase': 'F6',
    'engineVersion': SolverAC3.engineVersion,
    'iterations': micros.length,
    'branches': circuit.components.length,
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

CircuitState _benchmarkCircuit(int branchesPerPhase) {
  final List<ComponentInstance> components = <ComponentInstance>[];
  final List<Connection> connections = <Connection>[
    _wire('sn12', 's1n', 's2n', PhaseTag.neutral),
    _wire('sn23', 's2n', 's3n', PhaseTag.neutral),
  ];
  final List<PhaseTag> phases = <PhaseTag>[
    PhaseTag.l1,
    PhaseTag.l2,
    PhaseTag.l3,
  ];
  for (var phaseIndex = 0; phaseIndex < phases.length; phaseIndex++) {
    final PhaseTag phase = phases[phaseIndex];
    final String phaseKey = '${phaseIndex + 1}';
    for (var i = 0; i < branchesPerPhase; i++) {
      final String id = 'r$phaseKey-$i';
      components.add(
        ComponentInstance(
          id: ComponentId(id),
          modelType: 'resistor',
          terminals: <Terminal>[
            Terminal(id: TerminalId('${id}p'), name: phase.name, phase: phase),
            Terminal(
              id: TerminalId('${id}n'),
              name: 'N',
              phase: PhaseTag.neutral,
              role: TerminalRole.neutral,
            ),
          ],
          parameters: <String, Object?>{'resistanceOhm': 20.0 + (i % 7)},
        ),
      );
      connections.add(_wire('p-$id', 's${phaseIndex + 1}p', '${id}p', phase));
      connections.add(_wire('n-$id', 's1n', '${id}n', PhaseTag.neutral));
    }
  }
  return CircuitState(
    circuitId: CircuitId('ac3-benchmark-$branchesPerPhase'),
    revision: 0,
    mode: ElectricalMode.ac3,
    components: components,
    connections: connections,
    sources: <SourceInstance>[
      _source(1, PhaseTag.l1),
      _source(2, PhaseTag.l2),
      _source(3, PhaseTag.l3),
    ],
    settings: const <String, Object?>{'frequencyHz': 50.0},
  );
}

SourceInstance _source(int index, PhaseTag phase) => SourceInstance(
  id: SourceId('s$index'),
  modelType: 'ac_voltage_source',
  terminals: <Terminal>[
    Terminal(id: TerminalId('s${index}p'), name: phase.name, phase: phase),
    Terminal(
      id: TerminalId('s${index}n'),
      name: 'N',
      phase: PhaseTag.neutral,
      role: TerminalRole.neutral,
    ),
  ],
  parameters: const <String, Object?>{'voltageRmsV': 230.0},
);

Connection _wire(String id, String from, String to, PhaseTag phase) =>
    Connection(
      id: ConnectionId(id),
      fromTerminalId: TerminalId(from),
      toTerminalId: TerminalId(to),
      phase: phase,
    );
