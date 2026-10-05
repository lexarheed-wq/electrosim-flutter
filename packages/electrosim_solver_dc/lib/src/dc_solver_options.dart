final class DcSolverOptions {
  const DcSolverOptions({
    this.pivotTolerance = 1e-12,
    this.residualTolerance = 1e-9,
    this.maxCurrentLimitIterations = 8,
    this.maxNonlinearIterations = 16,
  }) : assert(pivotTolerance > 0),
       assert(residualTolerance > 0),
       assert(maxCurrentLimitIterations > 0),
       assert(maxNonlinearIterations > 0);

  final double pivotTolerance;
  final double residualTolerance;
  final int maxCurrentLimitIterations;
  final int maxNonlinearIterations;
}
