import 'package:electrosim_domain/electrosim_domain.dart';

enum Ac3DiagnosticSeverity { info, warning, error }

enum Ac3DiagnosticCode {
  wrongElectricalMode,
  topologyIdentityMismatch,
  topologyError,
  emptyCircuit,
  missingFrequency,
  invalidFrequency,
  invalidTerminalCount,
  invalidParameter,
  unsupportedComponentModel,
  unsupportedSourceModel,
  unsupportedComponentCondition,
  missingSourcePhaseTag,
  duplicatePhaseSource,
  phaseLoss,
  invalidMotorCoupling,
  floatingElectricalIsland,
  singularMatrix,
  numericalResidualExceeded,
}

final class Ac3SolverDiagnostic {
  Ac3SolverDiagnostic({
    required this.code,
    required this.severity,
    required this.message,
    this.componentId,
    this.sourceId,
    this.phase,
    Iterable<String> nodeIds = const <String>[],
  }) : nodeIds = List<String>.unmodifiable(nodeIds);

  final Ac3DiagnosticCode code;
  final Ac3DiagnosticSeverity severity;
  final String message;
  final ComponentId? componentId;
  final SourceId? sourceId;
  final PhaseTag? phase;
  final List<String> nodeIds;
}
