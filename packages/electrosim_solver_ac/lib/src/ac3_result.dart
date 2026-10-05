import 'dart:math' as math;

import 'package:electrosim_domain/electrosim_domain.dart';

import 'ac1_complex.dart';
import 'ac3_diagnostic.dart';

enum Ac3SolveStatus { solved, singular, invalid }

enum Ac3PhaseSequence { positive, negative, indeterminate }

enum Ac3BranchKind {
  resistor,
  inductor,
  capacitor,
  impedance,
  voltageSource,
  currentSource,
  openCircuit,
  idealShort,
  idealSwitch,
  idealProtection,
  controlCoil,
  contactorContact,
}

final class Ac3BranchResult {
  const Ac3BranchResult({
    required this.id,
    required this.modelType,
    required this.kind,
    required this.fromNodeId,
    required this.toNodeId,
    required this.voltage,
    required this.current,
    this.phase,
  });

  final String id;
  final String modelType;
  final Ac3BranchKind kind;
  final String fromNodeId;
  final String toNodeId;
  final AcComplex voltage;
  final AcComplex? current;
  final PhaseTag? phase;

  AcComplex? get complexPower =>
      current == null ? null : voltage * current!.conjugate;
  double? get activePowerW => complexPower?.real;
  double? get reactivePowerVar => complexPower?.imaginary;
  double? get apparentPowerVA => complexPower?.magnitude;
  double? get powerFactor {
    final AcComplex? power = complexPower;
    if (power == null) {
      return null;
    }
    final double apparent = power.magnitude;
    if (apparent <= 1e-15) {
      return 1.0;
    }
    return math.max(-1.0, math.min(1.0, power.real / apparent)).toDouble();
  }
}

final class Ac3PhaseOrderObservation {
  Ac3PhaseOrderObservation({
    required this.componentId,
    required this.sequence,
    required Iterable<AcComplex> terminalVoltages,
  }) : terminalVoltages = List<AcComplex>.unmodifiable(terminalVoltages);

  final ComponentId componentId;
  final Ac3PhaseSequence sequence;
  final List<AcComplex> terminalVoltages;
}

final class Ac3SolveResult {
  Ac3SolveResult({
    required this.circuitId,
    required this.circuitRevision,
    required this.engineVersion,
    required this.status,
    required this.frequencyHz,
    required this.referenceNodeId,
    required Map<String, AcComplex> nodeVoltages,
    required Iterable<Ac3BranchResult> branchResults,
    required Iterable<Ac3SolverDiagnostic> diagnostics,
    required this.maxMatrixResidual,
    required Map<String, double> kclResiduals,
    required Map<PhaseTag, AcComplex> phaseVoltages,
    required Map<PhaseTag, AcComplex> lineCurrents,
    required Map<String, AcComplex> lineToLineVoltages,
    required this.neutralCurrent,
    required Iterable<PhaseTag> missingPhases,
    required this.sourceSequence,
    required this.voltageBalanced,
    required this.currentBalanced,
    required this.neutralConnected,
    required Iterable<Ac3PhaseOrderObservation> phaseOrderObservations,
  }) : nodeVoltages = Map<String, AcComplex>.unmodifiable(nodeVoltages),
       branchResults = List<Ac3BranchResult>.unmodifiable(branchResults),
       diagnostics = List<Ac3SolverDiagnostic>.unmodifiable(diagnostics),
       kclResiduals = Map<String, double>.unmodifiable(kclResiduals),
       phaseVoltages = Map<PhaseTag, AcComplex>.unmodifiable(phaseVoltages),
       lineCurrents = Map<PhaseTag, AcComplex>.unmodifiable(lineCurrents),
       lineToLineVoltages = Map<String, AcComplex>.unmodifiable(
         lineToLineVoltages,
       ),
       missingPhases = List<PhaseTag>.unmodifiable(missingPhases),
       phaseOrderObservations = List<Ac3PhaseOrderObservation>.unmodifiable(
         phaseOrderObservations,
       );

  final CircuitId circuitId;
  final int circuitRevision;
  final String engineVersion;
  final Ac3SolveStatus status;
  final double? frequencyHz;
  final String? referenceNodeId;
  final Map<String, AcComplex> nodeVoltages;
  final List<Ac3BranchResult> branchResults;
  final List<Ac3SolverDiagnostic> diagnostics;
  final double? maxMatrixResidual;
  final Map<String, double> kclResiduals;
  final Map<PhaseTag, AcComplex> phaseVoltages;
  final Map<PhaseTag, AcComplex> lineCurrents;
  final Map<String, AcComplex> lineToLineVoltages;
  final AcComplex neutralCurrent;
  final List<PhaseTag> missingPhases;
  final Ac3PhaseSequence sourceSequence;
  final bool voltageBalanced;
  final bool currentBalanced;
  final bool neutralConnected;
  final List<Ac3PhaseOrderObservation> phaseOrderObservations;

  bool get isSolved => status == Ac3SolveStatus.solved;
  bool get isDegradedThreePhase => missingPhases.isNotEmpty;

  Ac3BranchResult branch(String id) =>
      branchResults.firstWhere((Ac3BranchResult branch) => branch.id == id);

  AcComplex lineCurrent(PhaseTag phase) =>
      lineCurrents[phase] ?? AcComplex.zero;

  AcComplex? phaseVoltage(PhaseTag phase) => phaseVoltages[phase];
}
