import 'package:electrosim_domain/electrosim_domain.dart';

enum MeasurementKind {
  voltageDc,
  currentDc,
  resistance,
  voltageAcRms,
  currentAcRms,
  frequency,
  activePower,
  reactivePower,
  apparentPower,
  phaseSequence,
}

enum MeasurementStatus { valid, invalid }

enum MeasurementErrorCode {
  simulationNotSolved,
  identityMismatch,
  wrongElectricalMode,
  unknownTerminal,
  unknownBranch,
  branchCurrentUnavailable,
  energizedResistanceMeasurement,
  unknownComponent,
  unsupportedResistanceTarget,
  invalidResistanceParameter,
}

final class MeasurementRequest {
  const MeasurementRequest._({
    required this.kind,
    this.positiveProbe,
    this.negativeProbe,
    this.branchId,
    this.componentId,
  });

  factory MeasurementRequest.voltage({
    required TerminalId positiveProbe,
    required TerminalId negativeProbe,
  }) => MeasurementRequest._(
    kind: MeasurementKind.voltageDc,
    positiveProbe: positiveProbe,
    negativeProbe: negativeProbe,
  );

  factory MeasurementRequest.current({required String branchId}) =>
      MeasurementRequest._(kind: MeasurementKind.currentDc, branchId: branchId);

  factory MeasurementRequest.resistance({required ComponentId componentId}) =>
      MeasurementRequest._(
        kind: MeasurementKind.resistance,
        componentId: componentId,
      );

  factory MeasurementRequest.voltageAcRms({
    required TerminalId positiveProbe,
    required TerminalId negativeProbe,
  }) => MeasurementRequest._(
    kind: MeasurementKind.voltageAcRms,
    positiveProbe: positiveProbe,
    negativeProbe: negativeProbe,
  );

  factory MeasurementRequest.currentAcRms({required String branchId}) =>
      MeasurementRequest._(
        kind: MeasurementKind.currentAcRms,
        branchId: branchId,
      );

  factory MeasurementRequest.frequency() =>
      const MeasurementRequest._(kind: MeasurementKind.frequency);

  factory MeasurementRequest.activePower({String? branchId}) =>
      MeasurementRequest._(
        kind: MeasurementKind.activePower,
        branchId: branchId,
      );

  factory MeasurementRequest.reactivePower({String? branchId}) =>
      MeasurementRequest._(
        kind: MeasurementKind.reactivePower,
        branchId: branchId,
      );

  factory MeasurementRequest.apparentPower({String? branchId}) =>
      MeasurementRequest._(
        kind: MeasurementKind.apparentPower,
        branchId: branchId,
      );

  factory MeasurementRequest.phaseSequence() =>
      const MeasurementRequest._(kind: MeasurementKind.phaseSequence);

  final MeasurementKind kind;
  final TerminalId? positiveProbe;
  final TerminalId? negativeProbe;
  final String? branchId;
  final ComponentId? componentId;
}

final class MeasurementResult {
  MeasurementResult._({
    required this.kind,
    required this.status,
    required this.reading,
    required this.errorCode,
    required this.message,
    required this.displayText,
    required Iterable<String> evidenceIds,
  }) : evidenceIds = List<String>.unmodifiable(evidenceIds);

  factory MeasurementResult.valid({
    required MeasurementKind kind,
    required double value,
    required ElectricalUnit unit,
    required Iterable<String> evidenceIds,
  }) => MeasurementResult._(
    kind: kind,
    status: MeasurementStatus.valid,
    reading: ElectricalQuantity(value: value, unit: unit),
    errorCode: null,
    message: null,
    displayText: null,
    evidenceIds: evidenceIds,
  );

  factory MeasurementResult.text({
    required MeasurementKind kind,
    required String value,
    required Iterable<String> evidenceIds,
  }) => MeasurementResult._(
    kind: kind,
    status: MeasurementStatus.valid,
    reading: null,
    errorCode: null,
    message: null,
    displayText: value,
    evidenceIds: evidenceIds,
  );

  factory MeasurementResult.invalid({
    required MeasurementKind kind,
    required MeasurementErrorCode errorCode,
    required String message,
    Iterable<String> evidenceIds = const <String>[],
  }) => MeasurementResult._(
    kind: kind,
    status: MeasurementStatus.invalid,
    reading: null,
    errorCode: errorCode,
    message: message,
    displayText: null,
    evidenceIds: evidenceIds,
  );

  final MeasurementKind kind;
  final MeasurementStatus status;
  final ElectricalQuantity? reading;
  final MeasurementErrorCode? errorCode;
  final String? message;
  final String? displayText;
  final List<String> evidenceIds;

  bool get isValid => status == MeasurementStatus.valid;
}
