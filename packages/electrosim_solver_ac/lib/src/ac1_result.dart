import 'dart:math' as math;

import 'package:electrosim_domain/electrosim_domain.dart';

import 'ac1_complex.dart';
import 'ac1_diagnostic.dart';

enum Ac1SolveStatus { solved, singular, invalid }

enum Ac1BranchKind {
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

final class Ac1BranchResult {
  const Ac1BranchResult({
    required this.id,
    required this.modelType,
    required this.kind,
    required this.fromNodeId,
    required this.toNodeId,
    required this.voltage,
    required this.current,
  });

  final String id;
  final String modelType;
  final Ac1BranchKind kind;
  final String fromNodeId;
  final String toNodeId;
  final AcComplex voltage;
  final AcComplex? current;

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

final class Ac1SolveResult {
  Ac1SolveResult({
    required this.circuitId,
    required this.circuitRevision,
    required this.engineVersion,
    required this.status,
    required this.frequencyHz,
    required this.referenceNodeId,
    required Map<String, AcComplex> nodeVoltages,
    required Iterable<Ac1BranchResult> branchResults,
    required Iterable<Ac1SolverDiagnostic> diagnostics,
    required this.maxMatrixResidual,
    required Map<String, double> kclResiduals,
  }) : nodeVoltages = Map<String, AcComplex>.unmodifiable(nodeVoltages),
       branchResults = List<Ac1BranchResult>.unmodifiable(branchResults),
       diagnostics = List<Ac1SolverDiagnostic>.unmodifiable(diagnostics),
       kclResiduals = Map<String, double>.unmodifiable(kclResiduals);

  final CircuitId circuitId;
  final int circuitRevision;
  final String engineVersion;
  final Ac1SolveStatus status;
  final double? frequencyHz;
  final String? referenceNodeId;
  final Map<String, AcComplex> nodeVoltages;
  final List<Ac1BranchResult> branchResults;
  final List<Ac1SolverDiagnostic> diagnostics;
  final double? maxMatrixResidual;
  final Map<String, double> kclResiduals;

  bool get isSolved => status == Ac1SolveStatus.solved;

  Ac1BranchResult branch(String id) =>
      branchResults.firstWhere((Ac1BranchResult branch) => branch.id == id);
}
