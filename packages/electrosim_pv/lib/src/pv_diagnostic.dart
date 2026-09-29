import 'package:electrosim_domain/electrosim_domain.dart';

enum PvDiagnosticSeverity { info, warning, error }

enum PvDiagnosticCode {
  wrongElectricalMode,
  topologyIdentityMismatch,
  topologyError,
  missingPvArray,
  multiplePvArrays,
  missingInverter,
  multipleInverters,
  invalidPvParameter,
  invalidInverterParameter,
  invalidLoadParameter,
  invalidTerminalContract,
  dcInputDisconnected,
  acOutputDisconnected,
  inputVoltageOutOfRange,
  inverterFaulted,
  inverterDerated,
  powerLimited,
}

final class PvSolverDiagnostic {
  const PvSolverDiagnostic({
    required this.code,
    required this.severity,
    required this.message,
    this.componentId,
    this.sourceId,
  });

  final PvDiagnosticCode code;
  final PvDiagnosticSeverity severity;
  final String message;
  final ComponentId? componentId;
  final SourceId? sourceId;
}
