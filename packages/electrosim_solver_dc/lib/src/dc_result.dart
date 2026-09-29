import 'package:electrosim_domain/electrosim_domain.dart';

import 'dc_diagnostic.dart';

enum DcSolveStatus { solved, singular, invalid }

enum DcBranchKind {
  resistor,
  idealSwitch,
  idealShort,
  voltageSource,
  currentSource,
  openCircuit,
}

final class DcBranchResult {
  const DcBranchResult({
    required this.id,
    required this.modelType,
    required this.kind,
    required this.fromNodeId,
    required this.toNodeId,
    required this.voltageV,
    required this.currentA,
    required this.powerW,
  });

  final String id;
  final String modelType;
  final DcBranchKind kind;
  final String fromNodeId;
  final String toNodeId;
  final double voltageV;
  final double? currentA;
  final double? powerW;
}

final class DcSolveResult {
  DcSolveResult({
    required this.circuitId,
    required this.circuitRevision,
    required this.engineVersion,
    required this.status,
    required this.referenceNodeId,
    required Map<String, double> nodeVoltages,
    required Iterable<DcBranchResult> branchResults,
    required Iterable<DcSolverDiagnostic> diagnostics,
    required this.maxMatrixResidual,
    required Map<String, double> kclResiduals,
    required Map<String, double> kvlResiduals,
  }) : nodeVoltages = Map<String, double>.unmodifiable(nodeVoltages),
       branchResults = List<DcBranchResult>.unmodifiable(branchResults),
       diagnostics = List<DcSolverDiagnostic>.unmodifiable(diagnostics),
       kclResiduals = Map<String, double>.unmodifiable(kclResiduals),
       kvlResiduals = Map<String, double>.unmodifiable(kvlResiduals);

  final CircuitId circuitId;
  final int circuitRevision;
  final String engineVersion;
  final DcSolveStatus status;
  final String? referenceNodeId;
  final Map<String, double> nodeVoltages;
  final List<DcBranchResult> branchResults;
  final List<DcSolverDiagnostic> diagnostics;
  final double? maxMatrixResidual;
  final Map<String, double> kclResiduals;
  final Map<String, double> kvlResiduals;

  bool get isSolved => status == DcSolveStatus.solved;

  DcBranchResult branch(String id) =>
      branchResults.firstWhere((DcBranchResult branch) => branch.id == id);
}
