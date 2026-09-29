import 'package:electrosim_domain/electrosim_domain.dart';

enum Ac1DiagnosticSeverity { info, warning, error }

enum Ac1DiagnosticCode {
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
  floatingElectricalIsland,
  singularMatrix,
  numericalResidualExceeded,
}

final class Ac1SolverDiagnostic {
  Ac1SolverDiagnostic({
    required this.code,
    required this.severity,
    required this.message,
    this.componentId,
    this.sourceId,
    Iterable<String> nodeIds = const <String>[],
  }) : nodeIds = List<String>.unmodifiable(nodeIds);

  final Ac1DiagnosticCode code;
  final Ac1DiagnosticSeverity severity;
  final String message;
  final ComponentId? componentId;
  final SourceId? sourceId;
  final List<String> nodeIds;
}
