import 'package:electrosim_domain/electrosim_domain.dart';

enum DiagnosticReportStatus { evidenceAvailable, insufficientEvidence }

enum DiagnosticEvidenceSource { topology, solver, simulation }

enum EieAdviceCode {
  floatingNode,
  isolatedComponent,
  isolatedSource,
  conflictingPhases,
  contradictorySource,
  floatingElectricalIsland,
  singularNetwork,
  numericalResidual,
  openBranch,
  componentContractMismatch,
  componentModeMismatch,
  sourceCurrentLimited,
  sourceLimitConvergence,
  receiverOverload,
  severeReceiverOverload,
  phaseLoss,
  invalidFrequency,
  pvWrongElectricalMode,
  pvTopologyIdentityMismatch,
  pvTopologyError,
  pvMissingArray,
  pvMultipleArrays,
  pvMissingInverter,
  pvMultipleInverters,
  pvInvalidArrayParameter,
  pvInvalidInverterParameter,
  pvInvalidLoadParameter,
  pvInvalidTerminalContract,
  pvDcInputDisconnected,
  pvAcOutputDisconnected,
  pvInputVoltageOutOfRange,
  pvInverterFaulted,
  pvInverterDerated,
  pvPowerLimited,
  pvInvalidControllerParameter,
  pvInvalidBatteryParameter,
  pvStorageTopologyInvalid,
  pvControllerFaulted,
  pvBatteryEmpty,
  pvBatteryFull,
}

final class DiagnosticEvidence {
  DiagnosticEvidence({
    required this.id,
    required this.source,
    required this.summary,
    Iterable<String> targetIds = const <String>[],
  }) : targetIds = List<String>.unmodifiable(targetIds);

  final String id;
  final DiagnosticEvidenceSource source;
  final String summary;
  final List<String> targetIds;
}

final class EieAdvice {
  EieAdvice({
    required this.code,
    required this.title,
    required this.explanation,
    required Iterable<String> evidenceIds,
    Iterable<String> highlightTargetIds = const <String>[],
  }) : evidenceIds = List<String>.unmodifiable(evidenceIds),
       highlightTargetIds = List<String>.unmodifiable(highlightTargetIds) {
    if (this.evidenceIds.isEmpty) {
      throw ArgumentError('An EIE advice must cite at least one evidenceId.');
    }
  }

  final EieAdviceCode code;
  final String title;
  final String explanation;
  final List<String> evidenceIds;
  final List<String> highlightTargetIds;
}

final class DiagnosticReport {
  DiagnosticReport({
    required this.circuitId,
    required this.circuitRevision,
    required this.status,
    required Iterable<DiagnosticEvidence> evidence,
    required Iterable<EieAdvice> advice,
  }) : evidence = List<DiagnosticEvidence>.unmodifiable(evidence),
       advice = List<EieAdvice>.unmodifiable(advice) {
    final Set<String> ids = this.evidence
        .map((DiagnosticEvidence e) => e.id)
        .toSet();
    if (ids.length != this.evidence.length) {
      throw StateError('Diagnostic evidence IDs must be unique.');
    }
    for (final EieAdvice item in this.advice) {
      if (!item.evidenceIds.every(ids.contains)) {
        throw StateError(
          'Every EIE advice must reference evidence present in the report.',
        );
      }
    }
    if (status == DiagnosticReportStatus.insufficientEvidence &&
        this.advice.isNotEmpty) {
      throw StateError(
        'Insufficient evidence cannot produce diagnostic advice.',
      );
    }
  }

  final CircuitId circuitId;
  final int circuitRevision;
  final DiagnosticReportStatus status;
  final List<DiagnosticEvidence> evidence;
  final List<EieAdvice> advice;
}
