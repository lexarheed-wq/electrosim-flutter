import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:electrosim_solver_dc/electrosim_solver_dc.dart';
import 'package:electrosim_topology/electrosim_topology.dart';

/// R0: a reproducible, electrically active DC solver-only reference.
///
/// This is NOT a whole-app, frame, worker or pneumatic benchmark.
/// By default: 10 s warmup, 60 s measurement, 3 independent repeats at 10 Hz
/// for four circuits containing exactly 30, 100, 200 or 400 apparatuses.
/// Captures every measured iteration in separate CSV files.
Future<void> main(List<String> args) async {
  final int warm = _option(args, '--warmup-seconds', 10);
  final int measure = _option(args, '--measure-seconds', 60);
  final int repeats = _option(args, '--repeats', 3);
  final String outDir = _stringOption(args, '--out-dir', 'build/pneumatics-r0');
  if (warm < 0 || measure <= 0 || repeats <= 0) {
    throw ArgumentError('Invalid warmup, measurement or repetition settings.');
  }
  final Directory destination = Directory(outDir)..createSync(recursive: true);
  const TopologyEngine compiler = TopologyEngine();
  const SolverDC engine = SolverDC();
  final List<Map<String, Object?>> summaries = <Map<String, Object?>>[];
  for (final int apparatusCount in <int>[30, 100, 200, 400]) {
    final CircuitState circuit = buildReferenceCircuit(apparatusCount);
    final TopologyGraph topology = compiler.compile(circuit);
    _verify(engine.solve(circuit, topology), apparatusCount);
    for (var repetition = 1; repetition <= repeats; repetition++) {
      final int warmTicks = warm * 10;
      final int measurementTicks = measure * 10;
      for (var tick = 0; tick < warmTicks; tick++) {
        _verify(engine.solve(circuit, topology), apparatusCount);
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
      final Stopwatch cadence = Stopwatch()..start();
      final List<Map<String, Object?>> raw = <Map<String, Object?>>[];
      final List<int> samples = <int>[];
      for (var tick = 0; tick < measurementTicks; tick++) {
        final Stopwatch solveWatch = Stopwatch()..start();
        final DcSolveResult result = engine.solve(circuit, topology);
        solveWatch.stop();
        _verify(result, apparatusCount);
        samples.add(solveWatch.elapsedMicroseconds);
        raw.add(<String, Object?>{
          'sample': tick,
          'tWallMicros': cadence.elapsedMicroseconds,
          'solverMicros': solveWatch.elapsedMicroseconds,
          'sourceCurrentA': result.branch('source:v1').currentA,
          'maxMatrixResidual': result.maxMatrixResidual,
        });
        final int dueUs = (tick + 1) * 100000;
        final int remainingUs = dueUs - cadence.elapsedMicroseconds;
        if (remainingUs > 0) {
          await Future<void>.delayed(Duration(microseconds: remainingUs));
        }
      }
      cadence.stop();
      samples.sort();
      final String stem = 'dc_' + apparatusCount.toString() +
          '_rep_' + repetition.toString();
      final String csv = 'sample,tWallMicros,solverMicros,sourceCurrentA,maxMatrixResidual\n' +
          raw.map((r) => <Object?>[
            r['sample'], r['tWallMicros'], r['solverMicros'],
            r['sourceCurrentA'], r['maxMatrixResidual'],
          ].join(',')).join('\n') + '\n';
      File(destination.path + '/' + stem + '.csv').writeAsStringSync(csv);
      summaries.add(<String, Object?>{
        'apparatusCount': apparatusCount,
        'sourceCount': 1,
        'resistorCount': apparatusCount - 1,
        'connectionCount': 2 * (apparatusCount - 1),
        'independentLoadBanks': 4,
        'repetition': repetition,
        'warmupSeconds': warm,
        'measurementSeconds': measure,
        'samplePeriodMillis': 100,
        'samples': samples.length,
        'p50SolverMicros': _percentile(samples, 0.5),
        'p95SolverMicros': _percentile(samples, 0.95),
        'maxSolverMicros': samples.last,
        'elapsedWallMicros': cadence.elapsedMicroseconds,
        'rawCsv': stem + '.csv',
      });
    }
  }
  final Map<String, Object?> report = <String, Object?>{
    'purpose': 'R0 DC solve-only baseline; NOT pneumatic, mixed or UI results',
    'dateUtc': DateTime.now().toUtc().toIso8601String(),
    'engineVersion': SolverDC.engineVersion,
    'operatingSystem': Platform.operatingSystem,
    'operatingSystemVersion': Platform.operatingSystemVersion,
    'numberOfProcessors': Platform.numberOfProcessors,
    'dartVersion': Platform.version,
    'localeName': Platform.localeName,
    'schemaVersion': 1,
    'science': <String, Object?>{
      'topology': 'one 24 V source and four banks of parallel 24000-ohm loads',
      'expectedCurrentEachResistorA': 0.001,
      'expectedTotalCurrentA': '0.001 * (apparatusCount - 1)',
      'physicalScope': 'linear steady-state DC; no transients',
      'sampling': '10 Hz with absolute target times, no frame coupling',
    },
    'results': summaries,
  };
  final String json = const JsonEncoder.withIndent('  ').convert(report);
  File(destination.path + '/SUMMARY.json').writeAsStringSync(json + '\n');
  stdout.writeln(json);
}

int _option(List<String> args, String name, int defaultValue) {
  final int i = args.indexOf(name);
  if (i < 0) return defaultValue;
  if (i + 1 >= args.length) throw ArgumentError('Value missing for ' + name);
  return int.parse(args[i + 1]);
}

String _stringOption(List<String> args, String name, String defaultValue) {
  final int i = args.indexOf(name);
  if (i < 0) return defaultValue;
  if (i + 1 >= args.length) throw ArgumentError('Value missing for ' + name);
  return args[i + 1];
}

int _percentile(List<int> sorted, double q) =>
    sorted[math.max(0, math.min(sorted.length - 1, (sorted.length * q).ceil() - 1))];

void _verify(DcSolveResult result, int count) {
  if (!result.isSolved) {
    throw StateError('Reference DC circuit failed at apparatus count ' + count.toString());
  }
  final double? current = result.branch('source:v1').currentA;
  final double expected = (count - 1) * 0.001;
  if (current == null || !current.isFinite || (current.abs() - expected).abs() > 1e-7) {
    throw StateError('Unexpected 24 V source current at ' + count.toString() +
        ': ' + current.toString() + ', expected absolute ' + expected.toString());
  }
}

CircuitState buildReferenceCircuit(int apparatusCount) {
  if (apparatusCount < 5) throw ArgumentError.value(apparatusCount);
  final List<ComponentInstance> components = <ComponentInstance>[];
  final List<Connection> connections = <Connection>[];
  for (var i = 0; i < apparatusCount - 1; i++) {
    final String id = 'r' + i.toString();
    final String a = id + '-a';
    final String b = id + '-b';
    components.add(ComponentInstance(
      id: ComponentId(id),
      modelType: 'resistor',
      terminals: <Terminal>[
        Terminal(id: TerminalId(a), name: 'A'),
        Terminal(id: TerminalId(b), name: 'B'),
      ],
      parameters: const <String, Object?>{'resistanceOhm': 24000.0},
    ));
    connections.add(Connection(
      id: ConnectionId('w-p-' + id),
      fromTerminalId: const TerminalId('vp'),
      toTerminalId: TerminalId(a),
    ));
    connections.add(Connection(
      id: ConnectionId('w-n-' + id),
      fromTerminalId: TerminalId(b),
      toTerminalId: const TerminalId('vn'),
    ));
  }
  return CircuitState(
    circuitId: CircuitId('pneumatic-r0-dc-' + apparatusCount.toString()),
    revision: 0,
    mode: ElectricalMode.dc,
    components: components,
    connections: connections,
    sources: <SourceInstance>[
      SourceInstance(
        id: const SourceId('v1'),
        modelType: 'dc_voltage_source',
        terminals: <Terminal>[
          Terminal(id: const TerminalId('vp'), name: '+', role: TerminalRole.positive, phase: PhaseTag.dcPositive),
          Terminal(id: const TerminalId('vn'), name: '-', role: TerminalRole.negative, phase: PhaseTag.dcNegative),
        ],
        parameters: const <String, Object?>{'voltageV': 24.0},
      ),
    ],
  );
}
