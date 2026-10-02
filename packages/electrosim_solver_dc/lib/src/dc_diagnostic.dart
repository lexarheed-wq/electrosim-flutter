import 'package:electrosim_domain/electrosim_domain.dart';

enum DcDiagnosticSeverity { info, warning, error }

enum DcDiagnosticCode {
  wrongElectricalMode,
  topologyIdentityMismatch,
  topologyError,
  emptyCircuit,
  invalidTerminalCount,
  invalidParameter,
  unsupportedComponentModel,
  unsupportedSourceModel,
  unsupportedComponentCondition,
  contradictoryIdealSource,
  redundantIdealConstraint,
  floatingElectricalIsland,
  singularMatrix,
  numericalResidualExceeded,
  sourceCurrentLimited,
  currentLimitIterationExceeded,
}

final class DcSolverDiagnostic {
  DcSolverDiagnostic({
    required this.code,
    required this.severity,
    required this.message,
    this.componentId,
    this.sourceId,
    Iterable<String> nodeIds = const <String>[],
  }) : nodeIds = List<String>.unmodifiable(nodeIds);

  final DcDiagnosticCode code;
  final DcDiagnosticSeverity severity;
  final String message;
  final ComponentId? componentId;
  final SourceId? sourceId;
  final List<String> nodeIds;
}
