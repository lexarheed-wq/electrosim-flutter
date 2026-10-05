import 'package:electrosim_controls/electrosim_controls.dart';
import 'package:electrosim_diagnostics/electrosim_diagnostics.dart';
import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:electrosim_energy/electrosim_energy.dart';
import 'package:electrosim_measurements/electrosim_measurements.dart';
import 'package:electrosim_pv/electrosim_pv.dart';
import 'package:electrosim_protection/electrosim_protection.dart';
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
    this.contactorStates = const <ComponentId, ContactorActuationState>{},
    this.controlIssues = const <ElectromechanicalControlIssue>[],
    this.protectionState,
    this.protectionIssues = const <ProtectionCoordinationIssue>[],
    this.measurementEngine = const MeasurementEngine(),
    this.energyEngine = const EnergyEngine(),
  });

  final CircuitState circuit;
  final TopologyGraph topology;
  final DiagnosticReport diagnostics;
  final ElectroSimRuntimeSolverKind solverKind;
  final DcSolveResult? dcResult;
  final Ac1SolveResult? ac1Result;
  final Ac3SolveResult? ac3Result;
  final PvSolveResult? pvResult;
  final Map<ComponentId, ContactorActuationState> contactorStates;
  final List<ElectromechanicalControlIssue> controlIssues;
  final ProtectionRuntimeState? protectionState;
  final List<ProtectionCoordinationIssue> protectionIssues;
  final MeasurementEngine measurementEngine;
  final EnergyEngine energyEngine;

  DcSolveResult get dc =>
      dcResult ?? (throw StateError('Current runtime result is not DC.'));
  Ac1SolveResult get ac1 =>
      ac1Result ?? (throw StateError('Current runtime result is not AC1.'));
  Ac3SolveResult get ac3 =>
      ac3Result ?? (throw StateError('Current runtime result is not AC3.'));
  PvSolveResult get pv =>
      pvResult ?? (throw StateError('Current runtime result is not PV.'));

  bool contactorActuated(ComponentId componentId) =>
      contactorStates[componentId]?.actuated ?? false;

  bool protectionTripped(ComponentId componentId) =>
      protectionState?.isTripped(componentId) ?? false;

  bool get solved => switch (solverKind) {
    ElectroSimRuntimeSolverKind.dc => dcResult?.isSolved ?? false,
    ElectroSimRuntimeSolverKind.ac1 => ac1Result?.isSolved ?? false,
    ElectroSimRuntimeSolverKind.ac3 => ac3Result?.isSolved ?? false,
    ElectroSimRuntimeSolverKind.pv => pvResult?.isSolved ?? false,
  };

  bool get diagnosticsAvailable =>
      solverKind == ElectroSimRuntimeSolverKind.dc ||
      solverKind == ElectroSimRuntimeSolverKind.ac1 ||
      solverKind == ElectroSimRuntimeSolverKind.ac3;
  bool get dcMeasurementsAvailable =>
      solverKind == ElectroSimRuntimeSolverKind.dc &&
      (dcResult?.isSolved ?? false);
  bool get energyAvailable =>
      solverKind == ElectroSimRuntimeSolverKind.pv &&
      (pvResult?.isSolved ?? false);

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

  MeasurementResult measureAcVoltage({
    required TerminalId positiveProbe,
    required TerminalId negativeProbe,
  }) {
    final MeasurementRequest request = MeasurementRequest.voltageAcRms(
      positiveProbe: positiveProbe,
      negativeProbe: negativeProbe,
    );
    final Ac1SolveResult? ac1ResultLocal = ac1Result;
    if (ac1ResultLocal != null) {
      return measurementEngine.measureAc1(
        request: request,
        circuit: circuit,
        topology: topology,
        simulation: ac1ResultLocal,
      );
    }
    final Ac3SolveResult? ac3ResultLocal = ac3Result;
    if (ac3ResultLocal != null) {
      return measurementEngine.measureAc3(
        request: request,
        circuit: circuit,
        topology: topology,
        simulation: ac3ResultLocal,
      );
    }
    return MeasurementResult.invalid(
      kind: MeasurementKind.voltageAcRms,
      errorCode: MeasurementErrorCode.wrongElectricalMode,
      message:
          'La mesure de tension AC n’est pas disponible en mode ${circuit.mode.name.toUpperCase()}.',
    );
  }

  MeasurementResult measureAcCurrent({required String branchId}) {
    final MeasurementRequest request = MeasurementRequest.currentAcRms(
      branchId: branchId,
    );
    final Ac1SolveResult? ac1ResultLocal = ac1Result;
    if (ac1ResultLocal != null) {
      return measurementEngine.measureAc1(
        request: request,
        circuit: circuit,
        topology: topology,
        simulation: ac1ResultLocal,
      );
    }
    final Ac3SolveResult? ac3ResultLocal = ac3Result;
    if (ac3ResultLocal != null) {
      return measurementEngine.measureAc3(
        request: request,
        circuit: circuit,
        topology: topology,
        simulation: ac3ResultLocal,
      );
    }
    return MeasurementResult.invalid(
      kind: MeasurementKind.currentAcRms,
      errorCode: MeasurementErrorCode.wrongElectricalMode,
      message:
          'La mesure de courant AC n’est pas disponible en mode ${circuit.mode.name.toUpperCase()}.',
    );
  }

  MeasurementResult measureFrequency() {
    final MeasurementRequest request = MeasurementRequest.frequency();
    final Ac1SolveResult? ac1ResultLocal = ac1Result;
    if (ac1ResultLocal != null) {
      return measurementEngine.measureAc1(
        request: request,
        circuit: circuit,
        topology: topology,
        simulation: ac1ResultLocal,
      );
    }
    final Ac3SolveResult? ac3ResultLocal = ac3Result;
    if (ac3ResultLocal != null) {
      return measurementEngine.measureAc3(
        request: request,
        circuit: circuit,
        topology: topology,
        simulation: ac3ResultLocal,
      );
    }
    return MeasurementResult.invalid(
      kind: MeasurementKind.frequency,
      errorCode: MeasurementErrorCode.wrongElectricalMode,
      message:
          'La mesure de fréquence n’est pas disponible en mode ${circuit.mode.name.toUpperCase()}.',
    );
  }

  MeasurementResult measureActivePower({String? branchId}) =>
      _measureAcPower(MeasurementRequest.activePower(branchId: branchId));

  MeasurementResult measureReactivePower({String? branchId}) =>
      _measureAcPower(MeasurementRequest.reactivePower(branchId: branchId));

  MeasurementResult measureApparentPower({String? branchId}) =>
      _measureAcPower(MeasurementRequest.apparentPower(branchId: branchId));

  MeasurementResult measurePhaseSequence() {
    final Ac3SolveResult? result = ac3Result;
    if (result == null) {
      return MeasurementResult.invalid(
        kind: MeasurementKind.phaseSequence,
        errorCode: MeasurementErrorCode.wrongElectricalMode,
        message: 'L’ordre des phases nécessite un résultat AC3.',
      );
    }
    return measurementEngine.measureAc3(
      request: MeasurementRequest.phaseSequence(),
      circuit: circuit,
      topology: topology,
      simulation: result,
    );
  }

  MeasurementResult _measureAcPower(MeasurementRequest request) {
    final Ac1SolveResult? ac1Local = ac1Result;
    if (ac1Local != null) {
      return measurementEngine.measureAc1(
        request: request,
        circuit: circuit,
        topology: topology,
        simulation: ac1Local,
      );
    }
    final Ac3SolveResult? ac3Local = ac3Result;
    if (ac3Local != null) {
      return measurementEngine.measureAc3(
        request: request,
        circuit: circuit,
        topology: topology,
        simulation: ac3Local,
      );
    }
    return MeasurementResult.invalid(
      kind: request.kind,
      errorCode: MeasurementErrorCode.wrongElectricalMode,
      message: 'La mesure de puissance nécessite un résultat AC.',
    );
  }

  EnergyPowerSample energyPowerSample() {
    final PvSolveResult? result = pvResult;
    if (result == null) {
      throw StateError(
        'Energy routing currently requires a PV runtime result.',
      );
    }
    return EnergyPowerSample.fromPvResult(result);
  }

  /// Integrates energy only from explicit simulation time.
  ///
  /// No wall-clock or UI rebuild time is consulted here. The caller owns the
  /// simulation clock and decides exactly how much simulated time has elapsed.
  EnergySnapshot advanceEnergy({
    EnergySnapshot? previous,
    required Duration elapsed,
  }) {
    final PvSolveResult result = pv;
    final EnergyPowerSample sample = EnergyPowerSample.fromPvResult(result);
    final EnergySnapshot baseline =
        previous ??
        EnergySnapshot.zero(
          circuitId: result.circuitId,
          circuitRevision: result.circuitRevision,
          sourceEngineVersion: result.engineVersion,
        );
    return energyEngine.advance(
      previous: baseline,
      sample: sample,
      elapsed: elapsed,
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
    this.diagnosticEngine = const DiagnosticEngine(),
    this.measurementEngine = const MeasurementEngine(),
    this.energyEngine = const EnergyEngine(),
    this.electromechanicalControlEngine =
        const ElectromechanicalControlEngine(),
    this.protectionCoordinator = const ProtectionCoordinator(),
  });

  final TopologyEngine topologyEngine;
  final SolverDC solverDC;
  final SolverAC1 solverAC1;
  final SolverAC3 solverAC3;
  final SolverPV solverPV;
  final DiagnosticEngine diagnosticEngine;
  final MeasurementEngine measurementEngine;
  final EnergyEngine energyEngine;
  final ElectromechanicalControlEngine electromechanicalControlEngine;
  final ProtectionCoordinator protectionCoordinator;

  ElectroSimRuntimeSnapshot evaluate(CircuitState circuit) =>
      advance(circuit, elapsed: Duration.zero);

  ElectroSimRuntimeSnapshot advance(
    CircuitState circuit, {
    required Duration elapsed,
    ProtectionRuntimeState? previousProtectionState,
    Map<ComponentId, bool> previousContactorStates =
        const <ComponentId, bool>{},
    double? previousPvBatterySoc,
  }) {
    final TopologyGraph topology = topologyEngine.compile(circuit);
    switch (circuit.mode) {
      case ElectricalMode.dc:
        final ProtectionDcOutcome coordinated = protectionCoordinator.advanceDc(
          circuit: circuit,
          topology: topology,
          elapsed: elapsed,
          previous: previousProtectionState,
          solver: solverDC,
          controlsEngine: electromechanicalControlEngine,
          previousRelayStates: previousContactorStates,
        );
        final DcSolveResult dc = coordinated.result;
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
          contactorStates: coordinated.relays,
          controlIssues: coordinated.controlIssues,
          protectionState: coordinated.state,
          protectionIssues: coordinated.issues,
          measurementEngine: measurementEngine,
          energyEngine: energyEngine,
        );
      case ElectricalMode.ac1:
        final ProtectionAc1Outcome coordinated = protectionCoordinator
            .advanceAc1(
              circuit: circuit,
              topology: topology,
              elapsed: elapsed,
              previous: previousProtectionState,
              solver: solverAC1,
              controlsEngine: electromechanicalControlEngine,
              previousContactorStates: previousContactorStates,
            );
        final Ac1SolveResult ac1 = coordinated.result;
        final DiagnosticReport diagnostics = diagnosticEngine.analyzeAc1(
          topology: topology,
          simulation: ac1,
        );
        return ElectroSimRuntimeSnapshot(
          circuit: circuit,
          topology: topology,
          diagnostics: diagnostics,
          solverKind: ElectroSimRuntimeSolverKind.ac1,
          ac1Result: ac1,
          contactorStates: coordinated.contactors,
          controlIssues: coordinated.controlIssues,
          protectionState: coordinated.state,
          protectionIssues: coordinated.issues,
          measurementEngine: measurementEngine,
          energyEngine: energyEngine,
        );
      case ElectricalMode.ac3:
        final ProtectionAc3Outcome coordinated = protectionCoordinator
            .advanceAc3(
              circuit: circuit,
              topology: topology,
              elapsed: elapsed,
              previous: previousProtectionState,
              solver: solverAC3,
              controlsEngine: electromechanicalControlEngine,
            );
        final Ac3SolveResult ac3 = coordinated.result;
        final DiagnosticReport diagnostics = diagnosticEngine.analyzeAc3(
          topology: topology,
          simulation: ac3,
        );
        return ElectroSimRuntimeSnapshot(
          circuit: circuit,
          topology: topology,
          diagnostics: diagnostics,
          solverKind: ElectroSimRuntimeSolverKind.ac3,
          ac3Result: ac3,
          contactorStates: coordinated.contactors,
          controlIssues: coordinated.controlIssues,
          protectionState: coordinated.state,
          protectionIssues: coordinated.issues,
          measurementEngine: measurementEngine,
          energyEngine: energyEngine,
        );
      case ElectricalMode.pv:
        final PvSolveResult pv = solverPV.solve(
          circuit,
          topology,
          previousBatterySoc: previousPvBatterySoc,
          elapsed: elapsed,
        );
        return ElectroSimRuntimeSnapshot(
          circuit: circuit,
          topology: topology,
          diagnostics: _noDcDiagnostics(circuit),
          solverKind: ElectroSimRuntimeSolverKind.pv,
          pvResult: pv,
          measurementEngine: measurementEngine,
          energyEngine: energyEngine,
        );
    }
  }

  DiagnosticReport _noDcDiagnostics(CircuitState circuit) => DiagnosticReport(
    circuitId: circuit.circuitId,
    circuitRevision: circuit.revision,
    status: DiagnosticReportStatus.insufficientEvidence,
    evidence: const <DiagnosticEvidence>[],
    advice: const <EieAdvice>[],
  );
}
