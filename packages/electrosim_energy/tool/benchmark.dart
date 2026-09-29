import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:electrosim_energy/electrosim_energy.dart';

Future<void> main(List<String> args) async {
  String? output;
  for (var i = 0; i < args.length - 1; i++) {
    if (args[i] == '--output') {
      output = args[i + 1];
    }
  }
  const EnergyEngine engine = EnergyEngine();
  final CircuitId id = CircuitId('energy-benchmark');
  final EnergyPowerSample sample = EnergyPowerSample(
    circuitId: id,
    circuitRevision: 0,
    engineVersion: 'benchmark',
    inputPowerW: 1000.0,
    outputPowerW: 950.0,
    lossPowerW: 50.0,
  );
  final List<int> micros = <int>[];
  for (var run = 0; run < 100; run++) {
    EnergySnapshot state = EnergySnapshot.zero(
      circuitId: id,
      circuitRevision: 0,
      sourceEngineVersion: 'benchmark',
    );
    final Stopwatch stopwatch = Stopwatch()..start();
    for (var i = 0; i < 1000; i++) {
      state = engine.advance(
        previous: state,
        sample: sample,
        elapsed: const Duration(seconds: 1),
      );
    }
    stopwatch.stop();
    if (state.outputEnergyWh <= 0.0) {
      stderr.writeln('Energy benchmark failed to accumulate energy.');
      exitCode = 2;
      return;
    }
    micros.add(stopwatch.elapsedMicroseconds);
  }
  micros.sort();
  final Map<String, Object?> report = <String, Object?>{
    'phase': 'F7',
    'engineVersion': EnergyEngine.engineVersion,
    'runs': micros.length,
    'stepsPerRun': 1000,
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
