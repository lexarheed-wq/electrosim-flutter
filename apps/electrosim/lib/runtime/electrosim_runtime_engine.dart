import 'package:electrosim_diagnostics/electrosim_diagnostics.dart';
import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:electrosim_energy/electrosim_energy.dart';
import 'package:electrosim_measurements/electrosim_measurements.dart';
import 'package:electrosim_pv/electrosim_pv.dart';
import 'package:electrosim_solver_ac/electrosim_solver_ac.dart';
import 'package:electrosim_solver_dc/electrosim_solver_dc.dart';
import 'package:electrosim_topology/electrosim_topology.dart';

enum ElectroSimRuntimeSolverKind { dc, ac1, ac3, pv }

final class ElectroSimRuntimeSnapshot {
  const ElectroSimRuntimeSnapshot({
    required this.circuit,
    required this.topology,
    required this.diagnostics,
    required this.solverKind,
    this.dcResult,
    this.ac1Result,
    this.ac3Result,
    this.pvResult,
    this.energyPowerSample,
    this.measurementEngine = const MeasurementEngine(),
  });

  final CircuitState circuit;
  final TopologyGraph topology;
  final DiagnosticReport diagnostics;
  final ElectroSimRuntimeSolverKind solverKind;
  final DcSolveResult? dcResult;
  final Ac1SolveResult? ac1Result;
  final Ac3SolveResult? ac3Result;
  final PvSolveResult? pvResult;
  final EnergyPowerSample? energyPowerSample;
  final MeasurementEngine measurementEngine;

  DcSolveResult get dc =>
      dcResult ?? (throw StateError('Current runtime result is not DC.'));
  Ac1SolveResult get ac1 =>
      ac1Result ?? (throw StateError('Current runtime result is not AC1.'));
  Ac3SolveResult get ac3 =>
      ac3Result ?? (throw StateError('Current runtime result is not AC3.'));
  PvSolveResult get pv =>
      pvResult ?? (throw StateError('Current runtime result is not PV.'));

  bool get solved => switch (solverKind) {
        ElectroSimRuntimeSolverKind.dc => dcResult?.isSolved ?? false,
        ElectroSimRuntimeSolverKind.ac1 => ac1Result?.isSolved ?? false,
        ElectroSimRuntimeSolverKind.ac3 => ac3Result?.isSolved ?? false,
        ElectroSimRuntimeSolverKind.pv => pvResult?.isSolved ?? false,
      };

  bool get diagnosticsAvailable => solverKind == ElectroSimRuntimeSolverKind.dc;
  bool get dcMeasurementsAvailable =>
      solverKind == ElectroSimRuntimeSolverKind.dc && (dcResult?.isSolved ?? false);
  bool get energyAvailable =>
      solverKind == ElectroSimRuntimeSolverKind.pv &&
      energyPowerSample != null;

  MeasurementResult measureVoltage({
    required TerminalId positiveProbe,
    required TerminalId negativeProbe,
  }) {
    final DcSolveResult? result = dcResult;
    if (result == null) {
      return MeasurementResult.invalid(
        kind: MeasurementKind.voltageDc,
        errorCode: MeasurementErrorCode.wrongElectricalMode,
        message:
            'Les mesures CC ne sont pas disponibles en mode ${circuit.mode.name.toUpperCase()}.',
      );
    }
    return measurementEngine.measure(
      request: MeasurementRequest.voltage(
        positiveProbe: positiveProbe,
        negativeProbe: negativeProbe,
      ),
      circuit: circuit,
      topology: topology,
      simulation: result,
    );
  }

  MeasurementResult measureCurrent({required String branchId}) {
    final DcSolveResult? result = dcResult;
    if (result == null) {
      return MeasurementResult.invalid(
        kind: MeasurementKind.currentDc,
        errorCode: MeasurementErrorCode.wrongElectricalMode,
        message:
            'Les mesures CC ne sont pas disponibles en mode ${circuit.mode.name.toUpperCase()}.',
      );
    }
    return measurementEngine.measure(
      request: MeasurementRequest.current(branchId: branchId),
      circuit: circuit,
      topology: topology,
      simulation: result,
    );
  }

  MeasurementResult measureResistance({required ComponentId componentId}) {
    final DcSolveResult? result = dcResult;
    if (result == null) {
      return MeasurementResult.invalid(
        kind: MeasurementKind.resistance,
        errorCode: MeasurementErrorCode.wrongElectricalMode,
        message:
            'La mesure de résistance n’est pas routée pour le mode ${circuit.mode.name.toUpperCase()}.',
      );
    }
    return measurementEngine.measure(
      request: MeasurementRequest.resistance(componentId: componentId),
      circuit: circuit,
      topology: topology,
      simulation: result,
    );
  }
}

final class ElectroSimRuntimeEngine {
  const ElectroSimRuntimeEngine({
    this.topologyEngine = const TopologyEngine(),
    this.solverDC = const SolverDC(),
    this.solverAC1 = const SolverAC1(),
    this.solverAC3 = const SolverAC3(),
    this.solverPV = const SolverPV(),
    this.energyEngine = const EnergyEngine(),
    this.diagnosticEngine = const DiagnosticEngine(),
    this.measurementEngine = const MeasurementEngine(),
  });

  final TopologyEngine topologyEngine;
  final SolverDC solverDC;
  final SolverAC1 solverAC1;
  final SolverAC3 solverAC3;
  final SolverPV solverPV;
  final EnergyEngine energyEngine;
  final DiagnosticEngine diagnosticEngine;
  final MeasurementEngine measurementEngine;

  ElectroSimRuntimeSnapshot evaluate(CircuitState circuit) {
    final TopologyGraph topology = topologyEngine.compile(circuit);
    switch (circuit.mode) {
      case ElectricalMode.dc:
        final DcSolveResult dc = solverDC.solve(circuit, topology);
        final DiagnosticReport diagnostics = diagnosticEngine.analyze(
          topology: topology,
          simulation: dc,
        );
        return ElectroSimRuntimeSnapshot(
          circuit: circuit,
          topology: topology,
          diagnostics: diagnostics,
          solverKind: ElectroSimRuntimeSolverKind.dc,
          dcResult: dc,
          measurementEngine: measurementEngine,
        );
      case ElectricalMode.ac1:
        final Ac1SolveResult ac1 = solverAC1.solve(circuit, topology);
        return ElectroSimRuntimeSnapshot(
          circuit: circuit,
          topology: topology,
          diagnostics: _noDcDiagnostics(circuit),
          solverKind: ElectroSimRuntimeSolverKind.ac1,
          ac1Result: ac1,
          measurementEngine: measurementEngine,
        );
      case ElectricalMode.ac3:
        final Ac3SolveResult ac3 = solverAC3.solve(circuit, topology);
        return ElectroSimRuntimeSnapshot(
          circuit: circuit,
          topology: topology,
          diagnostics: _noDcDiagnostics(circuit),
          solverKind: ElectroSimRuntimeSolverKind.ac3,
          ac3Result: ac3,
          measurementEngine: measurementEngine,
        );
      case ElectricalMode.pv:
        final PvSolveResult pv = solverPV.solve(circuit, topology);
        final EnergyPowerSample? sample =
            pv.isSolved ? EnergyPowerSample.fromPvResult(pv) : null;
        return ElectroSimRuntimeSnapshot(
          circuit: circuit,
          topology: topology,
          diagnostics: _noDcDiagnostics(circuit),
          solverKind: ElectroSimRuntimeSolverKind.pv,
          pvResult: pv,
          energyPowerSample: sample,
          measurementEngine: measurementEngine,
        );
    }
  }

  EnergySnapshot zeroEnergy(ElectroSimRuntimeSnapshot snapshot) {
    final EnergyPowerSample? sample = snapshot.energyPowerSample;
    if (snapshot.solverKind != ElectroSimRuntimeSolverKind.pv || sample == null) {
      throw StateError(
        'Energy accumulation requires a solved PV runtime snapshot.',
      );
    }
    return EnergySnapshot.zero(
      circuitId: sample.circuitId,
      circuitRevision: sample.circuitRevision,
      sourceEngineVersion: sample.engineVersion,
    );
  }

  EnergySnapshot advanceEnergy({
    required ElectroSimRuntimeSnapshot snapshot,
    required EnergySnapshot previous,
    required Duration elapsed,
  }) {
    final EnergyPowerSample? sample = snapshot.energyPowerSample;
    if (snapshot.solverKind != ElectroSimRuntimeSolverKind.pv || sample == null) {
      throw StateError(
        'Energy accumulation requires a solved PV runtime snapshot.',
      );
    }
    return energyEngine.advance(
      previous: previous,
      sample: sample,
      elapsed: elapsed,
    );
  }

  DiagnosticReport _noDcDiagnostics(CircuitState circuit) => DiagnosticReport(
        circuitId: circuit.circuitId,
        circuitRevision: circuit.revision,
        status: DiagnosticReportStatus.insufficientEvidence,
        evidence: const <DiagnosticEvidence>[],
        advice: const <EieAdvice>[],
      );
}
