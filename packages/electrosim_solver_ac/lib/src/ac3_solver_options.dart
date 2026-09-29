final class Ac3SolverOptions {
  const Ac3SolverOptions({
    this.pivotTolerance = 1e-12,
    this.residualTolerance = 1e-9,
    this.balanceRelativeTolerance = 1e-6,
    this.phaseAngleToleranceDegrees = 5.0,
  });

  final double pivotTolerance;
  final double residualTolerance;
  final double balanceRelativeTolerance;
  final double phaseAngleToleranceDegrees;
}
