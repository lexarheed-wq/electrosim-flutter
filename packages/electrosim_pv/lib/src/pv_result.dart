import 'package:electrosim_domain/electrosim_domain.dart';

import 'pv_diagnostic.dart';

enum PvSolveStatus { solved, invalid }

enum PvInverterState {
  running,
  idle,
  powerLimited,
  inputOutOfRange,
  faulted,
}

final class PvLoadResult {
  const PvLoadResult({
    required this.componentId,
    required this.resistanceOhm,
    required this.voltageRmsV,
    required this.currentRmsA,
    required this.activePowerW,
  });

  final ComponentId componentId;
  final double resistanceOhm;
  final double voltageRmsV;
  final double currentRmsA;
  final double activePowerW;
}

final class PvSolveResult {
  PvSolveResult({
    required this.circuitId,
    required this.circuitRevision,
    required this.engineVersion,
    required this.status,
    required this.irradianceWm2,
    required this.cellTemperatureC,
    required this.pvOperatingVoltageV,
    required this.pvAvailableCurrentA,
    required this.pvAvailablePowerW,
    required this.pvDrawnCurrentA,
    required this.pvDrawnPowerW,
    required this.curtailedPowerW,
    required this.inverterState,
    required this.inverterEfficiency,
    required this.inverterOutputVoltageRmsV,
    required this.inverterOutputCurrentRmsA,
    required this.inverterOutputPowerW,
    required this.inverterConversionLossW,
    required Iterable<PvLoadResult> loadResults,
    required Iterable<PvSolverDiagnostic> diagnostics,
  }) : loadResults = List<PvLoadResult>.unmodifiable(loadResults),
       diagnostics = List<PvSolverDiagnostic>.unmodifiable(diagnostics);

  final CircuitId circuitId;
  final int circuitRevision;
  final String engineVersion;
  final PvSolveStatus status;
  final double irradianceWm2;
  final double cellTemperatureC;
  final double pvOperatingVoltageV;
  final double pvAvailableCurrentA;
  final double pvAvailablePowerW;
  final double pvDrawnCurrentA;
  final double pvDrawnPowerW;
  final double curtailedPowerW;
  final PvInverterState inverterState;
  final double inverterEfficiency;
  final double inverterOutputVoltageRmsV;
  final double inverterOutputCurrentRmsA;
  final double inverterOutputPowerW;
  final double inverterConversionLossW;
  final List<PvLoadResult> loadResults;
  final List<PvSolverDiagnostic> diagnostics;

  bool get isSolved => status == PvSolveStatus.solved;

  PvLoadResult load(ComponentId id) =>
      loadResults.firstWhere((PvLoadResult item) => item.componentId == id);
}
