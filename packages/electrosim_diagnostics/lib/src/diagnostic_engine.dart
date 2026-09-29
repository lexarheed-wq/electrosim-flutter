import 'package:electrosim_solver_dc/electrosim_solver_dc.dart';
import 'package:electrosim_topology/electrosim_topology.dart';

import 'diagnostic_models.dart';

final class DiagnosticEngine {
  const DiagnosticEngine();

  DiagnosticReport analyze({
    required TopologyGraph topology,
    required DcSolveResult simulation,
  }) {
    if (topology.circuitId != simulation.circuitId ||
        topology.circuitRevision != simulation.circuitRevision) {
      throw StateError('Diagnostic inputs must refer to the same circuit revision.');
    }

    final List<DiagnosticEvidence> evidence = <DiagnosticEvidence>[];
    final List<EieAdvice> advice = <EieAdvice>[];
    final Set<EieAdviceCode> emittedCodes = <EieAdviceCode>{};

    for (final TopologyFinding finding in topology.findings) {
      final _MappedEvidence? mapped = _fromTopology(finding);
      if (mapped == null) continue;
      evidence.add(mapped.evidence);
      if (mapped.advice != null && emittedCodes.add(mapped.advice!.code)) {
        advice.add(mapped.advice!);
      }
    }

    for (final DcSolverDiagnostic diagnostic in simulation.diagnostics) {
      final _MappedEvidence? mapped = _fromSolver(diagnostic);
      if (mapped == null) continue;
      evidence.add(mapped.evidence);
      if (mapped.advice != null && emittedCodes.add(mapped.advice!.code)) {
        advice.add(mapped.advice!);
      }
    }

    for (final DcBranchResult branch in simulation.branchResults) {
      if (branch.kind != DcBranchKind.openCircuit) continue;
      final String id = 'simulation:openBranch:${branch.id}';
      final DiagnosticEvidence item = DiagnosticEvidence(
        id: id,
        source: DiagnosticEvidenceSource.simulation,
        summary: 'The solver models branch ${branch.id} as an open circuit.',
        targetIds: <String>[branch.id],
      );
      evidence.add(item);
      if (emittedCodes.add(EieAdviceCode.openBranch)) {
        advice.add(EieAdvice(
          code: EieAdviceCode.openBranch,
          title: 'Branche ouverte observée',
          explanation: 'Le solveur confirme une branche ouverte. Localiser cette branche et vérifier son composant ou sa continuité.',
          evidenceIds: <String>[id],
          highlightTargetIds: <String>[branch.id],
        ));
      }
    }

    evidence.sort((DiagnosticEvidence a, DiagnosticEvidence b) => a.id.compareTo(b.id));
    advice.sort((EieAdvice a, EieAdvice b) => a.code.name.compareTo(b.code.name));
    final DiagnosticReportStatus status = advice.isEmpty
        ? DiagnosticReportStatus.insufficientEvidence
        : DiagnosticReportStatus.evidenceAvailable;
    return DiagnosticReport(
      circuitId: simulation.circuitId,
      circuitRevision: simulation.circuitRevision,
      status: status,
      evidence: evidence,
      advice: advice,
    );
  }
}

final class _MappedEvidence {
  const _MappedEvidence(this.evidence, this.advice);
  final DiagnosticEvidence evidence;
  final EieAdvice? advice;
}

_MappedEvidence? _fromTopology(TopologyFinding finding) {
  final EieAdviceCode? code = switch (finding.code) {
    TopologyFindingCode.floatingNode => EieAdviceCode.floatingNode,
    TopologyFindingCode.isolatedComponent => EieAdviceCode.isolatedComponent,
    TopologyFindingCode.isolatedSource => EieAdviceCode.isolatedSource,
    TopologyFindingCode.conflictingPhases => EieAdviceCode.conflictingPhases,
    TopologyFindingCode.disabledConnection => null,
  };
  if (code == null) return null;
  final String key = finding.nodeId ??
      finding.connectionId?.value ??
      finding.componentId?.value ??
      finding.sourceId?.value ??
      finding.terminalIds.map((item) => item.value).join(',');
  final String id = 'topology:${finding.code.name}:$key';
  final List<String> targets = <String>[
    if (finding.nodeId != null) finding.nodeId!,
    if (finding.connectionId != null) finding.connectionId!.value,
    if (finding.componentId != null) finding.componentId!.value,
    if (finding.sourceId != null) finding.sourceId!.value,
    ...finding.terminalIds.map((item) => item.value),
  ];
  return _MappedEvidence(
    DiagnosticEvidence(
      id: id,
      source: DiagnosticEvidenceSource.topology,
      summary: finding.message,
      targetIds: targets,
    ),
    EieAdvice(
      code: code,
      title: _topologyTitle(code),
      explanation: '${finding.message} Vérifier uniquement la zone signalée avant de conclure à une cause.',
      evidenceIds: <String>[id],
      highlightTargetIds: targets,
    ),
  );
}

_MappedEvidence? _fromSolver(DcSolverDiagnostic diagnostic) {
  final EieAdviceCode? code = switch (diagnostic.code) {
    DcDiagnosticCode.contradictoryIdealSource => EieAdviceCode.contradictorySource,
    DcDiagnosticCode.floatingElectricalIsland => EieAdviceCode.floatingElectricalIsland,
    DcDiagnosticCode.singularMatrix => EieAdviceCode.singularNetwork,
    DcDiagnosticCode.numericalResidualExceeded => EieAdviceCode.numericalResidual,
    _ => null,
  };
  if (code == null) return null;
  final String key = diagnostic.componentId?.value ??
      diagnostic.sourceId?.value ??
      (diagnostic.nodeIds.isEmpty ? 'global' : diagnostic.nodeIds.join(','));
  final String id = 'solver:${diagnostic.code.name}:$key';
  final List<String> targets = <String>[
    if (diagnostic.componentId != null) diagnostic.componentId!.value,
    if (diagnostic.sourceId != null) diagnostic.sourceId!.value,
    ...diagnostic.nodeIds,
  ];
  return _MappedEvidence(
    DiagnosticEvidence(
      id: id,
      source: DiagnosticEvidenceSource.solver,
      summary: diagnostic.message,
      targetIds: targets,
    ),
    EieAdvice(
      code: code,
      title: _solverTitle(code),
      explanation: '${diagnostic.message} Cette indication provient directement du solveur.',
      evidenceIds: <String>[id],
      highlightTargetIds: targets,
    ),
  );
}

String _topologyTitle(EieAdviceCode code) => switch (code) {
  EieAdviceCode.floatingNode => 'Nœud flottant détecté',
  EieAdviceCode.isolatedComponent => 'Composant isolé détecté',
  EieAdviceCode.isolatedSource => 'Source isolée détectée',
  EieAdviceCode.conflictingPhases => 'Conducteurs incompatibles réunis',
  _ => throw StateError('Not a topology advice code: $code'),
};

String _solverTitle(EieAdviceCode code) => switch (code) {
  EieAdviceCode.contradictorySource => 'Sources idéales contradictoires',
  EieAdviceCode.floatingElectricalIsland => 'Îlot électrique flottant',
  EieAdviceCode.singularNetwork => 'Réseau non résoluble',
  EieAdviceCode.numericalResidual => 'Résidu numérique hors tolérance',
  _ => throw StateError('Not a solver advice code: $code'),
};
