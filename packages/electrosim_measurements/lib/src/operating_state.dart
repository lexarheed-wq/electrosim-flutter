import 'package:electrosim_domain/electrosim_domain.dart';

enum ComponentOperatingCode {
  deenergized,
  energized,
  open,
  closed,
  disabled,
  faulted,
  overloaded,
  undetermined,
}

enum OperatingWarningCode {
  simulationNotSolved,
  missingBranchResult,
  currentIndeterminate,
  invalidNominalLimit,
  overVoltage,
  overCurrent,
  overPower,
  invalidMotorCoupling,
}

final class OperatingWarning {
  const OperatingWarning({required this.code, required this.message});

  final OperatingWarningCode code;
  final String message;
}

final class ComponentOperatingState {
  ComponentOperatingState({
    required this.componentId,
    required this.code,
    required this.voltageV,
    required this.currentA,
    required this.powerW,
    required Iterable<OperatingWarning> warnings,
    required Iterable<String> evidenceIds,
  }) : warnings = List<OperatingWarning>.unmodifiable(warnings),
       evidenceIds = List<String>.unmodifiable(evidenceIds);

  final ComponentId componentId;
  final ComponentOperatingCode code;
  final double? voltageV;
  final double? currentA;
  final double? powerW;
  final List<OperatingWarning> warnings;
  final List<String> evidenceIds;
}
