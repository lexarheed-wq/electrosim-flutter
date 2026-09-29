final class PvSolverOptions {
  const PvSolverOptions({
    this.referenceIrradianceWm2 = 1000.0,
    this.referenceCellTemperatureC = 25.0,
    this.numericTolerance = 1e-9,
  });

  final double referenceIrradianceWm2;
  final double referenceCellTemperatureC;
  final double numericTolerance;
}
