final class DcSolverOptions {
  const DcSolverOptions({
    this.pivotTolerance = 1e-12,
    this.residualTolerance = 1e-9,
  }) : assert(pivotTolerance > 0),
       assert(residualTolerance > 0);

  final double pivotTolerance;
  final double residualTolerance;
}
