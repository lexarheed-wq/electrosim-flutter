import 'package:electrosim_pneumatic_solver/electrosim_pneumatic_solver.dart';
import 'package:test/test.dart';

void main() {
  const R6PerfQualification audit = R6PerfQualification();
  const String sha = '1234567890abcdef1234567890abcdef12345678';
  const String artifact =
      '1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef';

  R6PerfObservation fixture(
    R6PerfScenario scenario,
    R6PerfPlatform platform,
    int count, {
    double latencyMs = 25,
  }) => R6PerfObservation(
    sourceSha: sha,
    runner: 'test-fixture-not-real-runner',
    toolchain: 'synthetic-unit-test-data',
    rawArtifactSha256: artifact,
    scenario: scenario,
    platform: platform,
    activeComponents: count,
    warmupSeconds: 10,
    measuredSeconds: <int>[60, 60, 60],
    connectionP95Ms: latencyMs,
    fractionFramesAt16ms7: .99,
    clockDriftMsPer60s: 5,
    solveP95MsPer100ms: 30,
    electricalRegressionFraction: .03,
    nativeOrWebWorkerMeasured: true,
    memoryTrendLeakFree: true,
    iso1219Reviewed: true,
    productPngSha256: artifact,
  );

  test('R6/N PERF-01 missing 23 real runner cells is fail closed', () {
    final List<String> problems = audit.errors(<R6PerfObservation>[
      fixture(R6PerfScenario.pneumatic, R6PerfPlatform.chromium, 30),
    ], integratedG5Sha: sha);
    expect(problems.where((String p) => p.contains('Missing release')).length,
        23);
  });

  test('R6/N proof validator enforces all 24 scenario/platform cells', () {
    final List<R6PerfObservation> synthetic = <R6PerfObservation>[
      for (final R6PerfPlatform platform in R6PerfPlatform.values)
        for (final R6PerfScenario scenario in R6PerfScenario.values)
          for (final int count in <int>[30, 100, 200, 400])
            fixture(scenario, platform, count),
    ];
    // This test verifies only the schema's acceptance logic; these are
    // synthetic fixtures and never constitute real PERF-01 evidence.
    expect(audit.errors(synthetic, integratedG5Sha: sha), isEmpty);
    final List<R6PerfObservation> bad = <R6PerfObservation>[
      ...synthetic.take(23),
      fixture(R6PerfScenario.mixed, R6PerfPlatform.macIntel, 400,
          latencyMs: 101),
    ];
    expect(audit.errors(bad, integratedG5Sha: sha),
        contains(contains('Performance threshold failed')));
    expect(audit.errors(synthetic, integratedG5Sha: 'other'),
        isNotEmpty);
  });
}
