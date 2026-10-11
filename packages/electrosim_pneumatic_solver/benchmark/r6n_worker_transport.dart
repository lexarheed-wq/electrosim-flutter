import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:electrosim_pneumatic_solver/electrosim_pneumatic_solver.dart';

import 'r6_scale_fixture.dart';

/// Observed host-side latency for a persistent NATIVE isolate transport.
/// Not PERF-01: no Flutter frames, Web Worker load, ISO 1219, or Mac Intel.
Future<void> main() async {
  const List<int> counts = <int>[30, 100, 200, 400];
  const int warmupRuns = 2;
  const int measuredRuns = 5;
  const double durationS = .04;
  const double maxStepS = .004;

  final R6Worker worker = await createR6Worker();
  final List<Map<String, Object?>> results = <Map<String, Object?>>[];
  int requestId = 0;
  try {
    for (final int count in counts) {
      final R6PhysicalScaleCase fixture = R6PhysicalScaleCase(count);
      final IsothermalAirSnapshot baseline = fixture.solver.initialSnapshot;
      final IsothermalAirSnapshot direct = fixture.simulate(
        durationS: durationS,
        maxStepS: maxStepS,
      );

      Future<R6NetworkOutcome> invoke() => worker.solve(
        R6NetworkJob(
          projectRevision: 0,
          requestId: ++requestId,
          engineVersion: 'r6n-native-transport-v1',
          network: fixture.solver,
          before: baseline,
          durationS: durationS,
          maxStepS: maxStepS,
        ),
      );

      for (int run = 0; run < warmupRuns; run++) {
        await invoke();
      }
      final List<int> timingsUs = <int>[];
      for (int run = 0; run < measuredRuns; run++) {
        final Stopwatch stopwatch = Stopwatch()..start();
        final R6NetworkOutcome response = await invoke();
        stopwatch.stop();
        timingsUs.add(stopwatch.elapsedMicroseconds);
        final IsothermalAirSnapshot after = response.snapshot;
        if (after.chambers.length != count ||
            after.passageMassFlowKgPerS.length != count - 1 ||
            after.timeS != durationS ||
            !after.totalMassKg.isFinite ||
            (after.totalMassKg - baseline.totalMassKg).abs() >
                math.max(1e-11, baseline.totalMassKg * 1e-9)) {
          throw StateError('R6/N invalid transported physics: $count');
        }
        for (final MapEntry<String, FixedAirChamber> entry
            in after.chambers.entries) {
          final FixedAirChamber? fromDirect = direct.chambers[entry.key];
          if (fromDirect == null ||
              (entry.value.massKg - fromDirect.massKg).abs() > 1e-12) {
            throw StateError(
              'R6/N worker and direct engine disagree: ${entry.key}',
            );
          }
        }
      }
      timingsUs.sort();
      if (timingsUs.last > 30000000) {
        throw StateError('R6/N native isolate transport > 30s at $count');
      }
      results.add(<String, Object?>{
        'physicalVolumes': count,
        'calibratedPassages': fixture.passageCount,
        'measuredRoundtripUs': timingsUs,
        'p50Ms': timingsUs[2] / 1000,
        'p95Ms': timingsUs[4] / 1000,
        'conservedMassKg': baseline.totalMassKg,
        'directEngineParity': true,
      });
    }
  } finally {
    await worker.close();
  }
  final String sha = Platform.environment['GITHUB_SHA'] ?? 'LOCAL_UNVERIFIED';
  stdout.writeln(
    jsonEncode(<String, Object?>{
      'schema': 'electrosim.pneumatic.r6n.native-transport-observed.v1',
      'sourceSha': sha,
      'timeSource': 'Stopwatch (observed wall clock)',
      'platform': Platform.operatingSystem,
      'processorCount': Platform.numberOfProcessors,
      'dart': Platform.version,
      'solver': 'canonical IsothermalAirNetwork',
      'worker': 'persistent Dart isolate',
      'warmupRuns': warmupRuns,
      'measuredRuns': measuredRuns,
      'durationSPerRun': durationS,
      'notPerf01': true,
      'scopeExclusions': <String>[
        'flutter_frames',
        'chromium_rendering_fps',
        'mac_intel_release_runtime',
        'three_by_sixty_second_profile',
        'electrical_and_mixed_networks',
      ],
      'observations': results,
    }),
  );
}
