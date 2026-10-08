import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:electrosim_measurements/electrosim_measurements.dart';
import 'package:electrosim_pv/electrosim_pv.dart';
import 'package:electrosim_solver_ac/electrosim_solver_ac.dart';
import 'package:electrosim_solver_dc/electrosim_solver_dc.dart';
import 'package:electrosim_topology/electrosim_topology.dart';

import 'diagnostic_models.dart';

final class DiagnosticEngine {
  const DiagnosticEngine();

  DiagnosticReport analyze({
    required TopologyGraph topology,
    required DcSolveResult simulation,
    Iterable<ReceiverLoadState> receiverLoadStates =
        const <ReceiverLoadState>[],
  }) {
    _requireIdentity(
      topology,
      simulation.circuitId,
      simulation.circuitRevision,
    );
    final _ReportBuilder builder = _ReportBuilder(
      circuitId: simulation.circuitId,
      circuitRevision: simulation.circuitRevision,
    );
    builder.addTopology(topology);
    for (final DcSolverDiagnostic diagnostic in simulation.diagnostics) {
      builder.addMapped(_fromDcSolver(diagnostic));
    }
    for (final DcBranchResult branch in simulation.branchResults) {
      if (branch.kind == DcBranchKind.openCircuit &&
          _shouldReportOpenBranch(branch.modelType)) {
        builder.addOpenBranch(branch.id);
      }
    }
    builder.addReceiverStates(receiverLoadStates);
    return builder.build();
  }

  DiagnosticReport analyzeAc1({
    required TopologyGraph topology,
    required Ac1SolveResult simulation,
    Iterable<ReceiverLoadState> receiverLoadStates =
        const <ReceiverLoadState>[],
  }) {
    _requireIdentity(
      topology,
      simulation.circuitId,
      simulation.circuitRevision,
    );
    final _ReportBuilder builder = _ReportBuilder(
      circuitId: simulation.circuitId,
      circuitRevision: simulation.circuitRevision,
    );
    builder.addTopology(topology);
    for (final Ac1SolverDiagnostic diagnostic in simulation.diagnostics) {
      builder.addMapped(_fromAc1Solver(diagnostic));
    }
    for (final Ac1BranchResult branch in simulation.branchResults) {
      if (branch.kind == Ac1BranchKind.openCircuit &&
          _shouldReportOpenBranch(branch.modelType)) {
        builder.addOpenBranch(branch.id);
      }
    }
    builder.addReceiverStates(receiverLoadStates);
    return builder.build();
  }

  DiagnosticReport analyzeAc3({
    required TopologyGraph topology,
    required Ac3SolveResult simulation,
    Iterable<ReceiverLoadState> receiverLoadStates =
        const <ReceiverLoadState>[],
  }) {
    _requireIdentity(
      topology,
      simulation.circuitId,
      simulation.circuitRevision,
    );
    final _ReportBuilder builder = _ReportBuilder(
      circuitId: simulation.circuitId,
      circuitRevision: simulation.circuitRevision,
    );
    builder.addTopology(topology);
    for (final Ac3SolverDiagnostic diagnostic in simulation.diagnostics) {
      builder.addMapped(_fromAc3Solver(diagnostic));
    }
    for (final Ac3BranchResult branch in simulation.branchResults) {
      if (branch.kind == Ac3BranchKind.openCircuit &&
          _shouldReportOpenBranch(branch.modelType)) {
        builder.addOpenBranch(branch.id);
      }
    }
    builder.addReceiverStates(receiverLoadStates);
    return builder.build();
  }

  DiagnosticReport analyzePv({
    required TopologyGraph topology,
    required PvSolveResult simulation,
  }) {
    _requireIdentity(
      topology,
      simulation.circuitId,
      simulation.circuitRevision,
    );
    final _ReportBuilder builder = _ReportBuilder(
      circuitId: simulation.circuitId,
      circuitRevision: simulation.circuitRevision,
    );
    builder.addTopology(topology);
    for (final PvSolverDiagnostic diagnostic in simulation.diagnostics) {
      builder.addMapped(_fromPvSolver(diagnostic));
    }
    return builder.build();
  }
}

bool _shouldReportOpenBranch(String modelType) {
  final String type = modelType.toLowerCase();
  return type != 'switch' && type != 'switch_spst' && type != 'push_button_no';
}

void _requireIdentity(
  TopologyGraph topology,
  CircuitId circuitId,
  int circuitRevision,
) {
  if (topology.circuitId != circuitId ||
      topology.circuitRevision != circuitRevision) {
    throw StateError(
      'Diagnostic inputs must refer to the same circuit revision.',
    );
  }
}

final class _ReportBuilder {
  _ReportBuilder({required this.circuitId, required this.circuitRevision});

  final CircuitId circuitId;
  final int circuitRevision;
  final List<DiagnosticEvidence> _evidence = <DiagnosticEvidence>[];
  final List<EieAdvice> _advice = <EieAdvice>[];
  final Set<String> _evidenceIds = <String>{};
  final Set<EieAdviceCode> _emittedCodes = <EieAdviceCode>{};

  void addTopology(TopologyGraph topology) {
    for (final TopologyFinding finding in topology.findings) {
      addMapped(_fromTopology(finding));
    }
  }

  void addMapped(_MappedEvidence? mapped) {
    if (mapped == null) return;
    if (_evidenceIds.add(mapped.evidence.id)) {
      _evidence.add(mapped.evidence);
    }
    final EieAdvice? advice = mapped.advice;
    if (advice != null && _emittedCodes.add(advice.code)) {
      _advice.add(advice);
    }
  }

  void addOpenBranch(String branchId) {
    final String id = 'simulation:openBranch:$branchId';
    addMapped(
      _MappedEvidence(
        DiagnosticEvidence(
          id: id,
          source: DiagnosticEvidenceSource.simulation,
          summary: 'The solver models branch $branchId as an open circuit.',
          targetIds: <String>[branchId],
        ),
        EieAdvice(
          code: EieAdviceCode.openBranch,
          title: 'Branche ouverte observée',
          explanation:
              'Le solveur confirme une branche ouverte. Vérifier le composant ou la continuité de cette branche.',
          evidenceIds: <String>[id],
          highlightTargetIds: <String>[branchId],
        ),
      ),
    );
  }

  void addReceiverStates(Iterable<ReceiverLoadState> states) {
    for (final ReceiverLoadState state in states) {
      if (!state.isOverloaded) continue;
      final bool severe = state.code == ReceiverLoadCode.severeOverload;
      final String target = state.componentId.value;
      final String id = 'device:receiverLoad:$target';
      addMapped(
        _MappedEvidence(
          DiagnosticEvidence(
            id: id,
            source: DiagnosticEvidenceSource.simulation,
            summary:
                'Receiver $target carries ${state.currentA.toStringAsFixed(3)} A for ${state.ratedCurrentA.toStringAsFixed(3)} A nominal (${state.loadPercent.toStringAsFixed(0)} %).',
            targetIds: <String>[target],
          ),
          EieAdvice(
            code: severe
                ? EieAdviceCode.severeReceiverOverload
                : EieAdviceCode.receiverOverload,
            title: severe
                ? 'Surcharge sévère du récepteur'
                : 'Récepteur en surcharge',
            explanation:
                'Le courant réel dépasse le courant nominal du récepteur. Le calibre de protection reste une grandeur distincte.',
            evidenceIds: <String>[id],
            highlightTargetIds: <String>[target],
          ),
        ),
      );
    }
  }

  DiagnosticReport build() {
    _evidence.sort(
      (DiagnosticEvidence a, DiagnosticEvidence b) => a.id.compareTo(b.id),
    );
    _advice.sort(
      (EieAdvice a, EieAdvice b) => a.code.name.compareTo(b.code.name),
    );
    return DiagnosticReport(
      circuitId: circuitId,
      circuitRevision: circuitRevision,
      status: _advice.isEmpty
          ? DiagnosticReportStatus.insufficientEvidence
          : DiagnosticReportStatus.evidenceAvailable,
      evidence: _evidence,
      advice: _advice,
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
    TopologyFindingCode.componentContractMismatch =>
      EieAdviceCode.componentContractMismatch,
    TopologyFindingCode.componentModeMismatch =>
      EieAdviceCode.componentModeMismatch,
    TopologyFindingCode.disabledConnection => null,
  };
  if (code == null) return null;
  final String key =
      finding.nodeId ??
      finding.connectionId?.value ??
      finding.componentId?.value ??
      finding.sourceId?.value ??
      finding.terminalIds.map((TerminalId item) => item.value).join(',');
  final String id = 'topology:${finding.code.name}:$key';
  final List<String> targets = <String>[
    if (finding.nodeId != null) finding.nodeId!,
    if (finding.connectionId != null) finding.connectionId!.value,
    if (finding.componentId != null) finding.componentId!.value,
    if (finding.sourceId != null) finding.sourceId!.value,
    ...finding.terminalIds.map((TerminalId item) => item.value),
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
      title: _title(code),
      explanation:
          '${finding.message} Vérifier uniquement la zone signalée avant de conclure à une cause.',
      evidenceIds: <String>[id],
      highlightTargetIds: targets,
    ),
  );
}

_MappedEvidence? _fromDcSolver(DcSolverDiagnostic diagnostic) {
  final EieAdviceCode? code = switch (diagnostic.code) {
    DcDiagnosticCode.contradictoryIdealSource =>
      EieAdviceCode.contradictorySource,
    DcDiagnosticCode.floatingElectricalIsland =>
      EieAdviceCode.floatingElectricalIsland,
    DcDiagnosticCode.singularMatrix => EieAdviceCode.singularNetwork,
    DcDiagnosticCode.numericalResidualExceeded =>
      EieAdviceCode.numericalResidual,
    DcDiagnosticCode.sourceCurrentLimited => EieAdviceCode.sourceCurrentLimited,
    DcDiagnosticCode.currentLimitIterationExceeded =>
      EieAdviceCode.sourceLimitConvergence,
    _ => null,
  };
  return _solverEvidence(
    code: code,
    diagnosticCode: diagnostic.code.name,
    message: diagnostic.message,
    componentId: diagnostic.componentId?.value,
    sourceId: diagnostic.sourceId?.value,
    nodeIds: diagnostic.nodeIds,
  );
}

_MappedEvidence? _fromAc1Solver(Ac1SolverDiagnostic diagnostic) {
  final EieAdviceCode? code = switch (diagnostic.code) {
    Ac1DiagnosticCode.floatingElectricalIsland =>
      EieAdviceCode.floatingElectricalIsland,
    Ac1DiagnosticCode.singularMatrix => EieAdviceCode.singularNetwork,
    Ac1DiagnosticCode.numericalResidualExceeded =>
      EieAdviceCode.numericalResidual,
    Ac1DiagnosticCode.missingFrequency ||
    Ac1DiagnosticCode.invalidFrequency => EieAdviceCode.invalidFrequency,
    _ => null,
  };
  return _solverEvidence(
    code: code,
    diagnosticCode: diagnostic.code.name,
    message: diagnostic.message,
    componentId: diagnostic.componentId?.value,
    sourceId: diagnostic.sourceId?.value,
    nodeIds: diagnostic.nodeIds,
  );
}

_MappedEvidence? _fromAc3Solver(Ac3SolverDiagnostic diagnostic) {
  final EieAdviceCode? code = switch (diagnostic.code) {
    Ac3DiagnosticCode.floatingElectricalIsland =>
      EieAdviceCode.floatingElectricalIsland,
    Ac3DiagnosticCode.singularMatrix => EieAdviceCode.singularNetwork,
    Ac3DiagnosticCode.numericalResidualExceeded =>
      EieAdviceCode.numericalResidual,
    Ac3DiagnosticCode.missingFrequency ||
    Ac3DiagnosticCode.invalidFrequency => EieAdviceCode.invalidFrequency,
    Ac3DiagnosticCode.phaseLoss => EieAdviceCode.phaseLoss,
    _ => null,
  };
  final List<String> nodes = <String>[
    ...diagnostic.nodeIds,
    if (diagnostic.phase != null) 'phase:${diagnostic.phase!.name}',
  ];
  return _solverEvidence(
    code: code,
    diagnosticCode: diagnostic.code.name,
    message: diagnostic.message,
    componentId: diagnostic.componentId?.value,
    sourceId: diagnostic.sourceId?.value,
    nodeIds: nodes,
  );
}

_MappedEvidence? _fromPvSolver(PvSolverDiagnostic diagnostic) {
  final EieAdviceCode code = switch (diagnostic.code) {
    PvDiagnosticCode.wrongElectricalMode => EieAdviceCode.pvWrongElectricalMode,
    PvDiagnosticCode.topologyIdentityMismatch =>
      EieAdviceCode.pvTopologyIdentityMismatch,
    PvDiagnosticCode.topologyError => EieAdviceCode.pvTopologyError,
    PvDiagnosticCode.missingPvArray => EieAdviceCode.pvMissingArray,
    PvDiagnosticCode.multiplePvArrays => EieAdviceCode.pvMultipleArrays,
    PvDiagnosticCode.missingInverter => EieAdviceCode.pvMissingInverter,
    PvDiagnosticCode.multipleInverters => EieAdviceCode.pvMultipleInverters,
    PvDiagnosticCode.invalidPvParameter =>
      EieAdviceCode.pvInvalidArrayParameter,
    PvDiagnosticCode.invalidInverterParameter =>
      EieAdviceCode.pvInvalidInverterParameter,
    PvDiagnosticCode.invalidLoadParameter =>
      EieAdviceCode.pvInvalidLoadParameter,
    PvDiagnosticCode.invalidTerminalContract =>
      EieAdviceCode.pvInvalidTerminalContract,
    PvDiagnosticCode.dcInputDisconnected => EieAdviceCode.pvDcInputDisconnected,
    PvDiagnosticCode.acOutputDisconnected =>
      EieAdviceCode.pvAcOutputDisconnected,
    PvDiagnosticCode.inputVoltageOutOfRange =>
      EieAdviceCode.pvInputVoltageOutOfRange,
    PvDiagnosticCode.inverterFaulted => EieAdviceCode.pvInverterFaulted,
    PvDiagnosticCode.inverterDerated => EieAdviceCode.pvInverterDerated,
    PvDiagnosticCode.powerLimited => EieAdviceCode.pvPowerLimited,
    PvDiagnosticCode.invalidControllerParameter =>
      EieAdviceCode.pvInvalidControllerParameter,
    PvDiagnosticCode.controllerInputVoltageOutOfRange =>
      EieAdviceCode.pvControllerInputVoltageOutOfRange,
    PvDiagnosticCode.invalidBatteryParameter =>
      EieAdviceCode.pvInvalidBatteryParameter,
    PvDiagnosticCode.storageTopologyInvalid =>
      EieAdviceCode.pvStorageTopologyInvalid,
    PvDiagnosticCode.controllerFaulted => EieAdviceCode.pvControllerFaulted,
    PvDiagnosticCode.batteryEmpty => EieAdviceCode.pvBatteryEmpty,
    PvDiagnosticCode.batteryFull => EieAdviceCode.pvBatteryFull,
  };
  return _solverEvidence(
    code: code,
    diagnosticCode: diagnostic.code.name,
    message: diagnostic.message,
    componentId: diagnostic.componentId?.value,
    sourceId: diagnostic.sourceId?.value,
    nodeIds: const <String>[],
  );
}

_MappedEvidence? _solverEvidence({
  required EieAdviceCode? code,
  required String diagnosticCode,
  required String message,
  String? componentId,
  String? sourceId,
  required Iterable<String> nodeIds,
}) {
  if (code == null) return null;
  final List<String> nodes = nodeIds.toList(growable: false);
  final String key =
      componentId ?? sourceId ?? (nodes.isEmpty ? 'global' : nodes.join(','));
  final String id = 'solver:$diagnosticCode:$key';
  final List<String> targets = <String>[
    if (componentId != null) componentId,
    if (sourceId != null) sourceId,
    ...nodes,
  ];
  return _MappedEvidence(
    DiagnosticEvidence(
      id: id,
      source: DiagnosticEvidenceSource.solver,
      summary: message,
      targetIds: targets,
    ),
    EieAdvice(
      code: code,
      title: _title(code),
      explanation:
          '$message Cette indication provient directement du moteur de calcul.',
      evidenceIds: <String>[id],
      highlightTargetIds: targets,
    ),
  );
}

String _title(EieAdviceCode code) => switch (code) {
  EieAdviceCode.floatingNode => 'Nœud flottant détecté',
  EieAdviceCode.isolatedComponent => 'Composant isolé détecté',
  EieAdviceCode.isolatedSource => 'Source isolée détectée',
  EieAdviceCode.conflictingPhases => 'Conducteurs incompatibles réunis',
  EieAdviceCode.contradictorySource => 'Sources idéales contradictoires',
  EieAdviceCode.floatingElectricalIsland => 'Îlot électrique flottant',
  EieAdviceCode.singularNetwork => 'Réseau non résoluble',
  EieAdviceCode.numericalResidual => 'Résidu numérique hors tolérance',
  EieAdviceCode.openBranch => 'Branche ouverte observée',
  EieAdviceCode.componentContractMismatch => 'Contrat de composant incohérent',
  EieAdviceCode.componentModeMismatch => 'Composant incompatible avec le mode',
  EieAdviceCode.sourceCurrentLimited => 'Source en limitation de courant',
  EieAdviceCode.sourceLimitConvergence =>
    'Convergence de limitation source impossible',
  EieAdviceCode.receiverOverload => 'Récepteur en surcharge',
  EieAdviceCode.severeReceiverOverload => 'Surcharge sévère du récepteur',
  EieAdviceCode.phaseLoss => 'Perte de phase détectée',
  EieAdviceCode.invalidFrequency => 'Fréquence AC invalide',
  EieAdviceCode.pvWrongElectricalMode => 'Mode électrique PV incohérent',
  EieAdviceCode.pvTopologyIdentityMismatch => 'Résultat PV hors révision',
  EieAdviceCode.pvTopologyError => 'Topologie PV invalide',
  EieAdviceCode.pvMissingArray => 'Champ photovoltaïque absent',
  EieAdviceCode.pvMultipleArrays => 'Plusieurs champs PV non pris en charge',
  EieAdviceCode.pvMissingInverter => 'Onduleur absent',
  EieAdviceCode.pvMultipleInverters => 'Plusieurs onduleurs non pris en charge',
  EieAdviceCode.pvInvalidArrayParameter => 'Paramètre du champ PV invalide',
  EieAdviceCode.pvInvalidInverterParameter => 'Paramètre onduleur invalide',
  EieAdviceCode.pvInvalidLoadParameter => 'Paramètre de charge PV invalide',
  EieAdviceCode.pvInvalidTerminalContract => 'Contrat de bornes PV invalide',
  EieAdviceCode.pvDcInputDisconnected => 'Entrée CC onduleur déconnectée',
  EieAdviceCode.pvAcOutputDisconnected => 'Sortie AC onduleur déconnectée',
  EieAdviceCode.pvInputVoltageOutOfRange =>
    'Tension d’entrée onduleur hors plage',
  EieAdviceCode.pvInverterFaulted => 'Onduleur PV en défaut',
  EieAdviceCode.pvInverterDerated => 'Onduleur PV déclassé',
  EieAdviceCode.pvPowerLimited => 'Puissance PV limitée',
  EieAdviceCode.pvInvalidControllerParameter =>
    'Paramètre régulateur PV invalide',
  EieAdviceCode.pvControllerInputVoltageOutOfRange =>
    'Tension d’entrée régulateur PV hors plage',
  EieAdviceCode.pvInvalidBatteryParameter => 'Paramètre batterie PV invalide',
  EieAdviceCode.pvStorageTopologyInvalid => 'Topologie de stockage PV invalide',
  EieAdviceCode.pvControllerFaulted => 'Régulateur PV en défaut',
  EieAdviceCode.pvBatteryEmpty => 'Batterie PV vide',
  EieAdviceCode.pvBatteryFull => 'Batterie PV pleine',
};
