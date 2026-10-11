import 'dart:convert';

import 'package:electrosim_pneumatic_solver/electrosim_pneumatic_solver.dart';

import 'r6_scale_fixture.dart';

/// Machine-readable observed times only. Never substitute generated timings.
/// 30/100/200/400 *physical gas fitting volumes*, not UI widgets.
/// The harness includes deterministic mass and graph integrity checks.
void main() {
  const List<int> counts = <int>[30, 100, 200, 400];
  const int warmups = 2;
  const int measuredRuns = 5;
  final Map<String, Object> report = <String, Object>{
    'schema': 'electrosim.pneumatic.r6.performance.v1',
    'measurementKind': 'observed_wall_clock',
    'physicalModel': 'isothermal_closed_orifice_network',
    'scopeExclusions': <String>[
      'flutter_widget_interaction',
      'iso1219_rendering',
      'electropneumatic_valve52',
      'macos_end_user_frame_rate',
    ],
    'warmupRuns': warmups,
    'measuredRuns': measuredRuns,
    'cases': <Map<String, Object>>[],
  };

  for (final int count in counts) {
    final R6PhysicalScaleCase fixture = R6PhysicalScaleCase(count);
    for (int i = 0; i < warmups; i++) {
      fixture.simulate();
    }
    final List<int> measuredMicroseconds = <int>[];
    IsothermalAirSnapshot? last;
    for (int i = 0; i < measuredRuns; i++) {
      final Stopwatch timer = Stopwatch()..start();
      last = fixture.simulate();
      timer.stop();
      measuredMicroseconds.add(timer.elapsedMicroseconds);
    }
    measuredMicroseconds.sort();
    final double p50Ms = measuredMicroseconds[2] / 1000;
    final double p95Ms = measuredMicroseconds[4] / 1000;
    final double sourceMass = fixture.solver.initialSnapshot.totalMassKg;
    final double residualKg = last!.totalMassKg - sourceMass;
    final Map<String, Object> measured = <String, Object>{
      'fittingDevices': count,
      'calibratedPassages': fixture.passageCount,
      'acceptedSubsteps': last.acceptedSubsteps,
      'simulationTimeS': last.timeS,
      'p50Ms': p50Ms,
      'p95Ms': p95Ms,
      'samplesMicroseconds': measuredMicroseconds,
      'closedMassResidualKg': residualKg,
      'massConserved': residualKg.abs() <= sourceMass * 1e-9,
    };
    (report['cases']! as List<Map<String, Object>>).add(measured);
    if (p95Ms > 30000) {
      throw StateError(
        'R6 performance upper safety limit of 30 seconds violated: '
        '$count fittings, p95Ms=$p95Ms',
      );
    }
  }
  print(jsonEncode(report));
}
