/// R6/N release evidence schema. Measurements are captured by real runners;
/// this class must never fabricate observed FPS, timings or mass conservation.
enum R6PerfScenario { electrical, pneumatic, mixed }
enum R6PerfPlatform { chromium, macIntel }

final class R6PerfObservation {
  R6PerfObservation({
    required this.sourceSha,
    required this.runner,
    required this.toolchain,
    required this.rawArtifactSha256,
    required this.scenario,
    required this.platform,
    required this.activeComponents,
    required this.warmupSeconds,
    required List<int> measuredSeconds,
    required this.connectionP95Ms,
    required this.fractionFramesAt16ms7,
    required this.clockDriftMsPer60s,
    required this.solveP95MsPer100ms,
    required this.electricalRegressionFraction,
    required this.nativeOrWebWorkerMeasured,
    required this.memoryTrendLeakFree,
    required this.iso1219Reviewed,
    required this.productPngSha256,
  }) : measuredSeconds = List<int>.unmodifiable(measuredSeconds);

  final String sourceSha;
  final String runner;
  final String toolchain;
  final String rawArtifactSha256;
  final R6PerfScenario scenario;
  final R6PerfPlatform platform;
  final int activeComponents;
  final int warmupSeconds;
  final List<int> measuredSeconds;
  final double connectionP95Ms;
  final double fractionFramesAt16ms7;
  final double clockDriftMsPer60s;
  final double solveP95MsPer100ms;
  final double electricalRegressionFraction;
  final bool nativeOrWebWorkerMeasured;
  final bool memoryTrendLeakFree;
  final bool iso1219Reviewed;
  final String productPngSha256;

  String get key => '${platform.name}/${scenario.name}/$activeComponents';
}

final class R6PerfQualification {
  const R6PerfQualification();

  /// Completeness is checked before numerical thresholds. Intentional
  /// failure of unobserved release/profile cells is the required behavior.
  List<String> errors(
    Iterable<R6PerfObservation> observations, {
    required String integratedG5Sha,
  }) {
    final List<String> problems = <String>[];
    final Map<String, R6PerfObservation> byKey =
        <String, R6PerfObservation>{};
    final RegExp hash = RegExp(r'^[0-9a-f]{40}$');
    final RegExp checksum = RegExp(r'^[0-9a-f]{64}$');
    if (!hash.hasMatch(integratedG5Sha)) {
      problems.add('Invalid final G5 source SHA');
    }
    for (final R6PerfObservation result in observations) {
      if (byKey.containsKey(result.key)) {
        problems.add('Duplicate PERF-01 cell: ${result.key}');
      }
      byKey[result.key] = result;
      if (result.sourceSha != integratedG5Sha ||
          result.runner.trim().isEmpty ||
          result.toolchain.trim().isEmpty ||
          !checksum.hasMatch(result.rawArtifactSha256) ||
          !checksum.hasMatch(result.productPngSha256)) {
        problems.add('Unverifiable provenance: ${result.key}');
      }
      if (result.activeComponents != 30 &&
          result.activeComponents != 100 &&
          result.activeComponents != 200 &&
          result.activeComponents != 400) {
        problems.add('Invalid active component count: ${result.key}');
      }
      if (result.warmupSeconds != 10 ||
          result.measuredSeconds.length != 3 ||
          result.measuredSeconds.any((int seconds) => seconds != 60)) {
        problems.add('Incomplete 10s + 3x60s run: ${result.key}');
      }
      final List<double> observed = <double>[
        result.connectionP95Ms,
        result.fractionFramesAt16ms7,
        result.clockDriftMsPer60s,
        result.solveP95MsPer100ms,
        result.electricalRegressionFraction,
      ];
      if (observed.any((double v) => !v.isFinite || v < 0)) {
        problems.add('Nonfinite or negative measurement: ${result.key}');
        continue;
      }
      if (result.connectionP95Ms > 100 ||
          result.fractionFramesAt16ms7 < .95 ||
          result.fractionFramesAt16ms7 > 1 ||
          result.clockDriftMsPer60s > 100 ||
          (result.scenario == R6PerfScenario.mixed &&
              result.activeComponents == 400 &&
              result.solveP95MsPer100ms > 80) ||
          (result.scenario == R6PerfScenario.electrical &&
              result.electricalRegressionFraction > .10)) {
        problems.add('Performance threshold failed: ${result.key}');
      }
      if (!result.nativeOrWebWorkerMeasured ||
          !result.memoryTrendLeakFree ||
          !result.iso1219Reviewed) {
        problems.add('Missing worker/memory/ISO proof: ${result.key}');
      }
    }
    for (final R6PerfPlatform platform in R6PerfPlatform.values) {
      for (final R6PerfScenario scenario in R6PerfScenario.values) {
        for (final int count in <int>[30, 100, 200, 400]) {
          final String key = '${platform.name}/${scenario.name}/$count';
          if (!byKey.containsKey(key)) {
            problems.add('Missing release PERF-01 observation: $key');
          }
        }
      }
    }
    return List<String>.unmodifiable(problems);
  }
}
