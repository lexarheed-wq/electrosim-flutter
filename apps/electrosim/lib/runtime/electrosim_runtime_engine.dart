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

/// Solver-backed current evidence for one physical wire connection.
///
/// [signedCurrentA] is positive from Connection.fromTerminalId to
/// Connection.toTerminalId. For AC/PV only magnitude evidence is currently
/// available and [directionKnown] is false, preventing a fake one-way flow.
final class ConnectionCurrentEvidence {
  const ConnectionCurrentEvidence({
    required this.signedCurrentA,
    required this.directionKnown,
    required this.alternating,
  });

  const ConnectionCurrentEvidence.zero()
    : signedCurrentA = 0.0,
      directionKnown = true,
      alternating = false;

  final double signedCurrentA;
  final bool directionKnown;
  final bool alternating;

  double get magnitudeA => signedCurrentA.abs();
}

final class ElectroSimRuntimeSnapshot {
  // Expando associates a cache with this immutable snapshot without changing
  // the const constructor or retaining old snapshots after their disposal.
  static final _wireEvidence =
      Expando<Map<Connection, ConnectionCurrentEvidence>>();
  static final _dcContexts = Expando<_DcWireCurrentContext>();
  const ElectroSimRuntimeSnapshot({
    required this.circuit,
    required this.effectiveCircuit,
    required this.topology,
    required this.diagnostics,
    required this.solverKind,
    this.dcResult,
    this.ac1Result,
    this.ac3Result,
    this.pvResult,
    this.dcBatterySocs = const <ComponentId, double>{},
    this.motorAngularSpeedsRadS = const <ComponentId, double>{},
    this.contactorStates = const <ComponentId, ContactorActuationState>{},
    this.controlIssues = const <ElectromechanicalControlIssue>[],
    this.protectionState,
    this.protectionIssues = const <ProtectionCoordinationIssue>[],
    this.componentHealthStates = const <ComponentId, ComponentHealthState>{},
    this.measurementEngine = const MeasurementEngine(),
    this.deviceStateEngine = const DeviceStateEngine(),
    this.energyEngine = const EnergyEngine(),
  });

  /// User-authored circuit. Runtime failures never mutate this design model.
  final CircuitState circuit;

  /// Projected circuit actually consumed by the current solver step.
  /// Persistent runtime failures are represented here as physical conditions.
  final CircuitState effectiveCircuit;
  final TopologyGraph topology;
  final DiagnosticReport diagnostics;
  final ElectroSimRuntimeSolverKind solverKind;
  final DcSolveResult? dcResult;
  final Ac1SolveResult? ac1Result;
  final Ac3SolveResult? ac3Result;
  final PvSolveResult? pvResult;

  /// Physical state of autonomous DC batteries, not an invented PV reading.
  final Map<ComponentId, double> dcBatterySocs;
  /// Rotor angular velocity obtained from the coupled electrical/mechanical step.
  final Map<ComponentId, double> motorAngularSpeedsRadS;
  final Map<ComponentId, ContactorActuationState> contactorStates;
  final List<ElectromechanicalControlIssue> controlIssues;
  final ProtectionRuntimeState? protectionState;
  final List<ProtectionCoordinationIssue> protectionIssues;
  final Map<ComponentId, ComponentHealthState> componentHealthStates;
  final MeasurementEngine measurementEngine;
  final DeviceStateEngine deviceStateEngine;
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

  bool get diagnosticsAvailable => true;
  bool get dcMeasurementsAvailable =>
      solverKind == ElectroSimRuntimeSolverKind.dc &&
      (dcResult?.isSolved ?? false);
  bool get energyAvailable =>
      solverKind == ElectroSimRuntimeSolverKind.pv &&
      (pvResult?.isSolved ?? false);

  ConnectionCurrentEvidence connectionCurrentEvidence(Connection connection) {
    final cache = _wireEvidence[this] ??=
        <Connection, ConnectionCurrentEvidence>{};
    return cache.putIfAbsent(
      connection,
      () => _calculateConnectionCurrentEvidence(connection),
    );
  }

  ConnectionCurrentEvidence _calculateConnectionCurrentEvidence(
    Connection connection,
  ) {
    if (!connection.enabled ||
        !topology.enabledConnectionIds.contains(connection.id) ||
        !solved) {
      return const ConnectionCurrentEvidence.zero();
    }

    final DcSolveResult? dcLocal = dcResult;
    if (dcLocal != null && dcLocal.isSolved) {
      return _resolveDcConnectionCurrent(
        circuit: effectiveCircuit,
        topology: topology,
        simulation: dcLocal,
        context: _dcContexts[this] ??= _prepareDcWireCurrentContext(
          effectiveCircuit,
          topology,
          dcLocal,
        ),
        connection: connection,
      );
    }

    final String? nodeId = topology.terminalToNode[connection.fromTerminalId];
    if (nodeId == null) return const ConnectionCurrentEvidence.zero();
    double magnitude = 0.0;
    final Ac1SolveResult? ac1Local = ac1Result;
    if (ac1Local != null && ac1Local.isSolved) {
      for (final Ac1BranchResult branch in ac1Local.branchResults) {
        if (branch.fromNodeId != nodeId && branch.toNodeId != nodeId) continue;
        final double? current = branch.current?.magnitude;
        if (current != null && current.isFinite && current > magnitude) {
          magnitude = current;
        }
      }
      return ConnectionCurrentEvidence(
        signedCurrentA: magnitude,
        directionKnown: false,
        alternating: true,
      );
    }
    final Ac3SolveResult? ac3Local = ac3Result;
    if (ac3Local != null && ac3Local.isSolved) {
      for (final Ac3BranchResult branch in ac3Local.branchResults) {
        if (branch.fromNodeId != nodeId && branch.toNodeId != nodeId) continue;
        final double? current = branch.current?.magnitude;
        if (current != null && current.isFinite && current > magnitude) {
          magnitude = current;
        }
      }
      return ConnectionCurrentEvidence(
        signedCurrentA: magnitude,
        directionKnown: false,
        alternating: true,
      );
    }
    final PvSolveResult? pvLocal = pvResult;
    if (pvLocal != null && pvLocal.isSolved) {
      magnitude = switch (connection.phase) {
        PhaseTag.dcPositive ||
        PhaseTag.dcNegative => pvLocal.pvDrawnCurrentA.abs(),
        PhaseTag.l1 ||
        PhaseTag.neutral => pvLocal.inverterOutputCurrentRmsA.abs(),
        _ =>
          pvLocal.pvDrawnCurrentA.abs() >
                  pvLocal.inverterOutputCurrentRmsA.abs()
              ? pvLocal.pvDrawnCurrentA.abs()
              : pvLocal.inverterOutputCurrentRmsA.abs(),
      };
      return ConnectionCurrentEvidence(
        signedCurrentA: magnitude,
        directionKnown: false,
        alternating:
            connection.phase == PhaseTag.l1 ||
            connection.phase == PhaseTag.neutral,
      );
    }
    return const ConnectionCurrentEvidence.zero();
  }

  ComponentHealthState componentHealthState(ComponentId componentId) =>
      componentHealthStates[componentId] ?? const ComponentHealthState.normal();

  ComponentOperatingState? componentOperatingState(ComponentId componentId) {
    ComponentInstance? component;
    for (final ComponentInstance candidate in effectiveCircuit.components) {
      if (candidate.id == componentId) {
        component = candidate;
        break;
      }
    }
    if (component == null) return null;

    switch (solverKind) {
      case ElectroSimRuntimeSolverKind.dc:
        final DcSolveResult? result = dcResult;
        if (result == null) return null;
        return deviceStateEngine.evaluate(
          component: component,
          circuit: effectiveCircuit,
          simulation: result,
        );
      case ElectroSimRuntimeSolverKind.ac1:
        final Ac1SolveResult? result = ac1Result;
        if (result == null) return null;
        return deviceStateEngine.evaluateAc1(
          component: component,
          circuit: effectiveCircuit,
          simulation: result,
        );
      case ElectroSimRuntimeSolverKind.ac3:
        final Ac3SolveResult? result = ac3Result;
        if (result == null) return null;
        return deviceStateEngine.evaluateAc3(
          component: component,
          circuit: effectiveCircuit,
          simulation: result,
        );
      case ElectroSimRuntimeSolverKind.pv:
        final PvSolveResult? result = pvResult;
        if (result == null) return null;
        return deviceStateEngine.evaluatePv(
          component: component,
          circuit: effectiveCircuit,
          simulation: result,
        );
    }
  }

  ElectroSimRuntimeSnapshot withComponentHealthStates(
    Map<ComponentId, ComponentHealthState> states,
  ) => ElectroSimRuntimeSnapshot(
    circuit: circuit,
    effectiveCircuit: effectiveCircuit,
    topology: topology,
    diagnostics: diagnostics,
    solverKind: solverKind,
    dcResult: dcResult,
    ac1Result: ac1Result,
    ac3Result: ac3Result,
    pvResult: pvResult,
    dcBatterySocs: dcBatterySocs,
    motorAngularSpeedsRadS: motorAngularSpeedsRadS,
    contactorStates: contactorStates,
    controlIssues: controlIssues,
    protectionState: protectionState,
    protectionIssues: protectionIssues,
    componentHealthStates: Map<ComponentId, ComponentHealthState>.unmodifiable(
      states,
    ),
    measurementEngine: measurementEngine,
    deviceStateEngine: deviceStateEngine,
    energyEngine: energyEngine,
  );

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

final class _DcWireCurrentContext {
  const _DcWireCurrentContext(this.byConnection, this.connections);
  final Map<ConnectionId, ConnectionCurrentEvidence> byConnection;
  final Map<ConnectionId, Connection> connections;
}

final class _WireNeighbor {
  const _WireNeighbor(this.connection, this.other);
  final Connection connection;
  final TerminalId other;
}

/// O(V+E) snapshot preparation: each wire is handled once using bridge
/// detection. A wire within an ideal parallel loop has indeterminate current;
/// never invent a signed flow or claim a physical magnitude for it.
_DcWireCurrentContext _prepareDcWireCurrentContext(
  CircuitState circuit,
  TopologyGraph topology,
  DcSolveResult simulation,
) {
  final Map<String, DcBranchResult> resultsById = <String, DcBranchResult>{
    for (final DcBranchResult branch in simulation.branchResults)
      branch.id: branch,
  };
  final Map<TerminalId, double> externalLeavingA = <TerminalId, double>{};
  void add(TerminalId terminal, double current) {
    if (!current.isFinite) return;
    externalLeavingA.update(
      terminal,
      (value) => value + current,
      ifAbsent: () => current,
    );
  }

  for (final ComponentInstance component in circuit.components) {
    final List<TopologyBranch> branches = topology.branchesForComponent(
      component.id,
    );
    for (final TopologyBranch branch in branches) {
      final String resultId = branches.length == 1
          ? 'component:${component.id.value}'
          : 'component:${component.id.value}:${branch.branchId}';
      final double? current = resultsById[resultId]?.currentA;
      if (current == null) continue;
      add(branch.fromTerminalId, current);
      add(branch.toTerminalId, -current);
    }
  }
  for (final SourceInstance source in circuit.sources) {
    if (source.terminals.length < 2) continue;
    final double? current = resultsById['source:${source.id.value}']?.currentA;
    if (current == null) continue;
    add(source.terminals[0].id, current);
    add(source.terminals[1].id, -current);
  }

  final Map<TerminalId, List<_WireNeighbor>> adjacency =
      <TerminalId, List<_WireNeighbor>>{};
  final Map<ConnectionId, ConnectionCurrentEvidence> readings =
      <ConnectionId, ConnectionCurrentEvidence>{};
  for (final Connection connection in circuit.connections) {
    if (!connection.enabled ||
        !topology.enabledConnectionIds.contains(connection.id)) {
      continue;
    }
    final String? fromNode = topology.terminalToNode[connection.fromTerminalId];
    if (fromNode == null ||
        fromNode != topology.terminalToNode[connection.toTerminalId]) {
      continue;
    }
    adjacency
        .putIfAbsent(connection.fromTerminalId, () => <_WireNeighbor>[])
        .add(_WireNeighbor(connection, connection.toTerminalId));
    adjacency
        .putIfAbsent(connection.toTerminalId, () => <_WireNeighbor>[])
        .add(_WireNeighbor(connection, connection.fromTerminalId));
    readings[connection.id] = const ConnectionCurrentEvidence(
      signedCurrentA: 0.0,
      directionKnown: false,
      alternating: false,
    );
  }

  final Map<TerminalId, int> discovery = <TerminalId, int>{};
  final Map<TerminalId, int> low = <TerminalId, int>{};
  final Map<TerminalId, double> subtree = <TerminalId, double>{};
  var sequence = 0;
  void visit(TerminalId terminal, ConnectionId? incoming) {
    final int index = ++sequence;
    discovery[terminal] = index;
    low[terminal] = index;
    subtree[terminal] = externalLeavingA[terminal] ?? 0.0;
    for (final _WireNeighbor edge in adjacency[terminal]!) {
      if (edge.connection.id == incoming) continue;
      final TerminalId target = edge.other;
      if (!discovery.containsKey(target)) {
        visit(target, edge.connection.id);
        subtree[terminal] = subtree[terminal]! + subtree[target]!;
        if (low[target]! < low[terminal]!) low[terminal] = low[target]!;
        if (low[target]! > index) {
          final double current = edge.connection.fromTerminalId == terminal
              ? subtree[target]!
              : -subtree[target]!;
          readings[edge.connection.id] = ConnectionCurrentEvidence(
            signedCurrentA: current.abs() < 1e-12 ? 0.0 : current,
            directionKnown: true,
            alternating: false,
          );
        }
      } else if (discovery[target]! < low[terminal]!) {
        low[terminal] = discovery[target]!;
      }
    }
  }

  for (final TerminalId terminal in adjacency.keys) {
    if (!discovery.containsKey(terminal)) visit(terminal, null);
  }
  return _DcWireCurrentContext(
    Map<ConnectionId, ConnectionCurrentEvidence>.unmodifiable(readings),
    <ConnectionId, Connection>{
      for (final Connection item in circuit.connections) item.id: item,
    },
  );
}

ConnectionCurrentEvidence _resolveDcConnectionCurrent({
  required CircuitState circuit,
  required TopologyGraph topology,
  required DcSolveResult simulation,
  required Connection connection,
  required _DcWireCurrentContext context,
}) {
  final ConnectionCurrentEvidence? evidence =
      context.byConnection[connection.id];
  final Connection? physical = context.connections[connection.id];
  if (evidence == null || physical == null) {
    return const ConnectionCurrentEvidence.zero();
  }
  if (physical.fromTerminalId == connection.fromTerminalId &&
      physical.toTerminalId == connection.toTerminalId) {
    return evidence;
  }
  if (physical.fromTerminalId == connection.toTerminalId &&
      physical.toTerminalId == connection.fromTerminalId) {
    return ConnectionCurrentEvidence(
      signedCurrentA: -evidence.signedCurrentA,
      directionKnown: evidence.directionKnown,
      alternating: evidence.alternating,
    );
  }
  return const ConnectionCurrentEvidence.zero();
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
    this.deviceStateEngine = const DeviceStateEngine(),
    this.componentHealthEngine = const ComponentHealthEngine(),
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
  final DeviceStateEngine deviceStateEngine;
  final ComponentHealthEngine componentHealthEngine;
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
    Map<ComponentId, ComponentHealthState> previousComponentHealthStates =
        const <ComponentId, ComponentHealthState>{},
    double? previousPvBatterySoc,
    Map<ComponentId, double> previousDcBatterySocs =
        const <ComponentId, double>{},
    Map<ComponentId, double> previousMotorAngularSpeedsRadS =
        const <ComponentId, double>{},
  }) {
    if (elapsed.isNegative) {
      throw ArgumentError.value(
        elapsed,
        'elapsed',
        'Runtime elapsed time cannot be negative.',
      );
    }

    final CircuitState firstEffective = _projectRuntimeFailures(
      circuit,
      previousComponentHealthStates,
    );
    ElectroSimRuntimeSnapshot snapshot = _solveOnce(
      designCircuit: circuit,
      effectiveCircuit: firstEffective,
      elapsed: elapsed,
      previousProtectionState: previousProtectionState,
      previousContactorStates: previousContactorStates,
      previousPvBatterySoc: previousPvBatterySoc,
      previousDcBatterySocs: previousDcBatterySocs,
      previousMotorAngularSpeedsRadS: previousMotorAngularSpeedsRadS,
      componentHealthStates: previousComponentHealthStates,
    );

    final Map<ComponentId, ComponentHealthState> nextHealth =
        _advanceComponentHealth(
          designCircuit: circuit,
          snapshot: snapshot,
          elapsed: elapsed,
          previous: previousComponentHealthStates,
        );
    snapshot = snapshot.withComponentHealthStates(nextHealth);

    final bool newFailure = circuit.components.any((
      ComponentInstance component,
    ) {
      final bool wasFailed =
          previousComponentHealthStates[component.id]?.failedOpen ?? false;
      final bool isFailed = nextHealth[component.id]?.failedOpen ?? false;
      return !wasFailed && isFailed;
    });
    if (!newFailure) return snapshot;

    // A newly destroyed receiver is opened electrically in the same runtime
    // tick. The second solve is zero-time: dynamics are not integrated twice.
    final CircuitState failedEffective = _projectRuntimeFailures(
      circuit,
      nextHealth,
    );
    return _solveOnce(
      designCircuit: circuit,
      effectiveCircuit: failedEffective,
      elapsed: Duration.zero,
      previousProtectionState: snapshot.protectionState,
      previousContactorStates: <ComponentId, bool>{
        for (final MapEntry<ComponentId, ContactorActuationState> entry
            in snapshot.contactorStates.entries)
          entry.key: entry.value.actuated,
      },
      previousPvBatterySoc: snapshot.pvResult?.batteryPresent == true
          ? snapshot.pvResult!.batterySoc
          : previousPvBatterySoc,
      previousDcBatterySocs: snapshot.dcBatterySocs,
      previousMotorAngularSpeedsRadS: snapshot.motorAngularSpeedsRadS,
      componentHealthStates: nextHealth,
    );
  }

  ElectroSimRuntimeSnapshot _solveOnce({
    required CircuitState designCircuit,
    required CircuitState effectiveCircuit,
    required Duration elapsed,
    required ProtectionRuntimeState? previousProtectionState,
    required Map<ComponentId, bool> previousContactorStates,
    required double? previousPvBatterySoc,
    required Map<ComponentId, double> previousDcBatterySocs,
    required Map<ComponentId, double> previousMotorAngularSpeedsRadS,
    required Map<ComponentId, ComponentHealthState> componentHealthStates,
  }) {
    final CircuitState projected = _projectAutonomousStorageDc(
      effectiveCircuit,
    );
    final CircuitState solverCircuit = projected.mode == ElectricalMode.dc
        ? _projectMotorDynamics(
            _projectDcBatteryState(projected, previousDcBatterySocs),
            previousMotorAngularSpeedsRadS,
            elapsed,
          )
        : projected;
    final TopologyGraph topology = topologyEngine.compile(solverCircuit);
    switch (solverCircuit.mode) {
      case ElectricalMode.dc:
        final ProtectionDcOutcome coordinated = protectionCoordinator.advanceDc(
          circuit: solverCircuit,
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
          circuit: designCircuit,
          effectiveCircuit: solverCircuit,
          topology: topology,
          diagnostics: diagnostics,
          solverKind: ElectroSimRuntimeSolverKind.dc,
          dcResult: dc,
          dcBatterySocs: _advanceDcBatterySoc(
            solverCircuit,
            dc,
            previousDcBatterySocs,
            elapsed,
          ),
          motorAngularSpeedsRadS: _advanceDcMotorSpeeds(
            solverCircuit, dc, previousMotorAngularSpeedsRadS, elapsed,
          ),
          contactorStates: coordinated.relays,
          controlIssues: coordinated.controlIssues,
          protectionState: coordinated.state,
          protectionIssues: coordinated.issues,
          componentHealthStates: componentHealthStates,
          measurementEngine: measurementEngine,
          deviceStateEngine: deviceStateEngine,
          energyEngine: energyEngine,
        );
      case ElectricalMode.ac1:
        final ProtectionAc1Outcome coordinated = protectionCoordinator
            .advanceAc1(
              circuit: solverCircuit,
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
          circuit: designCircuit,
          effectiveCircuit: solverCircuit,
          topology: topology,
          diagnostics: diagnostics,
          solverKind: ElectroSimRuntimeSolverKind.ac1,
          ac1Result: ac1,
          contactorStates: coordinated.contactors,
          controlIssues: coordinated.controlIssues,
          protectionState: coordinated.state,
          protectionIssues: coordinated.issues,
          componentHealthStates: componentHealthStates,
          measurementEngine: measurementEngine,
          deviceStateEngine: deviceStateEngine,
          energyEngine: energyEngine,
        );
      case ElectricalMode.ac3:
        final ProtectionAc3Outcome coordinated = protectionCoordinator
            .advanceAc3(
              circuit: solverCircuit,
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
          circuit: designCircuit,
          effectiveCircuit: solverCircuit,
          topology: topology,
          diagnostics: diagnostics,
          solverKind: ElectroSimRuntimeSolverKind.ac3,
          ac3Result: ac3,
          contactorStates: coordinated.contactors,
          controlIssues: coordinated.controlIssues,
          protectionState: coordinated.state,
          protectionIssues: coordinated.issues,
          componentHealthStates: componentHealthStates,
          measurementEngine: measurementEngine,
          deviceStateEngine: deviceStateEngine,
          energyEngine: energyEngine,
        );
      case ElectricalMode.pv:
        final PvSolveResult pv = solverPV.solve(
          effectiveCircuit,
          topology,
          previousBatterySoc: previousPvBatterySoc,
          elapsed: elapsed,
        );
        final DiagnosticReport diagnostics = diagnosticEngine.analyzePv(
          topology: topology,
          simulation: pv,
        );
        return ElectroSimRuntimeSnapshot(
          circuit: designCircuit,
          effectiveCircuit: solverCircuit,
          topology: topology,
          diagnostics: diagnostics,
          solverKind: ElectroSimRuntimeSolverKind.pv,
          pvResult: pv,
          componentHealthStates: componentHealthStates,
          measurementEngine: measurementEngine,
          deviceStateEngine: deviceStateEngine,
          energyEngine: energyEngine,
        );
    }
  }

  /// Project the persisted SOC into the next DC solve without mutating the
  /// user's circuit. The existing DC storage law enforces the minSOC cutoff.
  CircuitState _projectDcBatteryState(
    CircuitState circuit,
    Map<ComponentId, double> previous,
  ) {
    if (previous.isEmpty) return circuit;
    final List<ComponentInstance> components = <ComponentInstance>[];
    var changed = false;
    for (final ComponentInstance component in circuit.components) {
      final double? soc = previous[component.id];
      if (soc == null || component.modelType != 'pv_battery') {
        components.add(component);
        continue;
      }
      if (!soc.isFinite) throw StateError('Non-finite battery SOC.');
      changed = true;
      components.add(
        ComponentInstance(
          id: component.id,
          modelType: component.modelType,
          terminals: component.terminals,
          parameters: <String, Object?>{
            ...component.parameters,
            ComponentParameterKeys.storageInitialSoc: soc,
          },
          condition: component.condition,
          controlState: component.controlState,
        ),
      );
    }
    if (!changed) return circuit;
    return CircuitState(
      circuitId: circuit.circuitId,
      revision: circuit.revision,
      mode: circuit.mode,
      components: components,
      connections: circuit.connections,
      sources: circuit.sources,
      instruments: circuit.instruments,
      probes: circuit.probes,
      settings: circuit.settings,
      metadata: circuit.metadata,
    );
  }

  /// Physical rotor state is runtime data. Project parameters for one solver
  /// revision without mutating the teacher's authored CircuitState.
  CircuitState _projectMotorDynamics(
    CircuitState circuit,
    Map<ComponentId, double> previous,
    Duration elapsed,
  ) {
    if (!circuit.components.any((c) => c.modelType == 'motor_dc')) {
      return circuit;
    }
    final double seconds = elapsed.inMicroseconds / 1e6;
    return CircuitState(
      circuitId: circuit.circuitId,
      revision: circuit.revision,
      mode: circuit.mode,
      sources: circuit.sources,
      components: <ComponentInstance>[
        for (final ComponentInstance c in circuit.components)
          if (c.modelType == 'motor_dc')
            ComponentInstance(
              id: c.id,
              modelType: c.modelType,
              terminals: c.terminals,
              condition: c.condition,
              controlState: c.controlState,
              parameters: <String, Object?>{
                ...c.parameters,
                ComponentParameterKeys.motorAngularSpeedRadS:
                    previous[c.id] ??
                    (c.parameters[ComponentParameterKeys.motorAngularSpeedRadS]
                        as num?)?.toDouble() ?? 0.0,
                ComponentParameterKeys.motorTimeStepSeconds: seconds,
              },
            )
          else
            c,
      ],
      connections: circuit.connections,
      instruments: circuit.instruments,
      probes: circuit.probes,
      settings: circuit.settings,
      metadata: circuit.metadata,
    );
  }

  Map<ComponentId, double> _advanceDcMotorSpeeds(
    CircuitState circuit,
    DcSolveResult dc,
    Map<ComponentId, double> previous,
    Duration elapsed,
  ) {
    final double seconds = elapsed.inMicroseconds / 1e6;
    final Map<String, DcBranchResult> branches = <String, DcBranchResult>{
      if (dc.isSolved)
        for (final DcBranchResult b in dc.branchResults) b.id: b,
    };
    final Map<ComponentId, double> speeds = <ComponentId, double>{};
    for (final ComponentInstance motor in circuit.components) {
      if (motor.modelType != 'motor_dc') continue;
      double param(String key, double fallback) =>
          (motor.parameters[key] as num?)?.toDouble() ?? fallback;
      final double prior = previous[motor.id] ??
          param(ComponentParameterKeys.motorAngularSpeedRadS, 0.0);
      if (seconds <= 0.0 || !dc.isSolved) {
        speeds[motor.id] = prior;
        continue;
      }
      final double kt = param(ComponentParameterKeys.motorTorqueNmPerA, 0.1);
      final double inertia = param(ComponentParameterKeys.motorInertiaKgM2, 0.01);
      final double friction =
          param(ComponentParameterKeys.motorFrictionNmPerRadS, 0.002);
      final double load = param(ComponentParameterKeys.motorLoadTorqueNm, 0.0);
      final double current =
          branches['component:${motor.id.value}']?.currentA ?? 0.0;
      final double inertiaOverTime = inertia / seconds;
      final double denominator = inertiaOverTime + friction;
      final double next =
          (inertiaOverTime * prior + kt * current - load) / denominator;
      // Never propagate NaN/Infinity into the next solver revision.
      speeds[motor.id] = next.isFinite ? next : prior;
    }
    return Map<ComponentId, double>.unmodifiable(speeds);
  }

  Map<ComponentId, double> _advanceDcBatterySoc(
    CircuitState circuit,
    DcSolveResult dc,
    Map<ComponentId, double> previous,
    Duration elapsed,
  ) {
    final double hours = elapsed.inMicroseconds / 3600000000.0;
    final Map<ComponentId, double> next = <ComponentId, double>{};
    for (final ComponentInstance component in circuit.components) {
      if (component.modelType != 'pv_battery') continue;
      double param(String key, double fallback) =>
          (component.parameters[key] as num?)?.toDouble() ?? fallback;
      final double nominalV = param(
        ComponentParameterKeys.storageNominalVoltageV,
        48.0,
      );
      final double capacityAh = param('capacityAh', 100.0);
      final double capacityWh = nominalV * capacityAh;
      final double minSoc = param(ComponentParameterKeys.storageMinSoc, 0.0);
      final double maxSoc = param('maxSoc', 1.0);
      final double soc =
          (previous[component.id] ??
                  param(ComponentParameterKeys.storageInitialSoc, 1.0))
              .clamp(minSoc, maxSoc)
              .toDouble();
      final DcBranchResult? branch = dc.isSolved
          ? dc.branchResults
                .where(
                  (DcBranchResult b) =>
                      b.id == 'component:${component.id.value}',
                )
                .firstOrNull
          : null;
      final double branchPowerW = branch?.powerW ?? 0.0;
      final double chargeEff = param('chargeEfficiency', 0.95);
      final double dischargeEff = param('dischargeEfficiency', 0.95);
      final double netStoredPowerW = branchPowerW >= 0.0
          ? branchPowerW * chargeEff
          : branchPowerW / dischargeEff;
      final double updated = capacityWh <= 0.0
          ? soc
          : (soc + netStoredPowerW * hours / capacityWh)
                .clamp(minSoc, maxSoc)
                .toDouble();
      next[component.id] = updated;
    }
    return Map<ComponentId, double>.unmodifiable(next);
  }

  CircuitState _projectAutonomousStorageDc(CircuitState circuit) {
    if (circuit.mode != ElectricalMode.pv) return circuit;

    final bool hasPvArray = circuit.sources.any(
      (SourceInstance source) => source.modelType == 'pv_array',
    );
    if (hasPvArray) return circuit;

    var hasStorage = false;
    for (final ComponentInstance component in circuit.components) {
      final ComponentPhysicsContract? physics =
          CoreComponentPhysicsContracts.resolve(component.modelType);
      final ComponentModelContract? structure = CoreComponentModelContracts
          .registry
          .resolve(component.modelType);
      if (physics?.electricalLaw == ComponentElectricalLaw.converter) {
        return circuit;
      }
      if (physics?.electricalLaw == ComponentElectricalLaw.storage) {
        hasStorage = true;
      }
      if (structure == null || !structure.supportsMode(ElectricalMode.dc)) {
        return circuit;
      }
    }
    if (!hasStorage) return circuit;

    final bool dcSourcesOnly = circuit.sources.every(
      (SourceInstance source) =>
          source.modelType == 'dc_voltage_source' ||
          source.modelType == 'voltage_source' ||
          source.modelType == 'dc_current_source' ||
          source.modelType == 'current_source',
    );
    if (!dcSourcesOnly) return circuit;

    return CircuitState(
      circuitId: circuit.circuitId,
      revision: circuit.revision,
      mode: ElectricalMode.dc,
      components: circuit.components,
      connections: circuit.connections,
      sources: circuit.sources,
      instruments: circuit.instruments,
      probes: circuit.probes,
      settings: circuit.settings,
      metadata: <String, Object?>{
        ...circuit.metadata,
        'runtimeProjectedFromMode': circuit.mode.name,
        'runtimeProjection': 'autonomous-storage-dc',
      },
    );
  }

  Map<ComponentId, ComponentHealthState> _advanceComponentHealth({
    required CircuitState designCircuit,
    required ElectroSimRuntimeSnapshot snapshot,
    required Duration elapsed,
    required Map<ComponentId, ComponentHealthState> previous,
  }) {
    final Map<ComponentId, ComponentHealthState> next =
        <ComponentId, ComponentHealthState>{};
    for (final ComponentInstance component in designCircuit.components) {
      final ComponentOperatingState? operating = snapshot
          .componentOperatingState(component.id);
      final ComponentHealthState prior =
          previous[component.id] ?? const ComponentHealthState.normal();
      if (operating == null) {
        next[component.id] = prior;
        continue;
      }
      next[component.id] = componentHealthEngine.advance(
        component: component,
        operatingState: operating,
        elapsed: elapsed,
        previous: prior,
      );
    }
    return Map<ComponentId, ComponentHealthState>.unmodifiable(next);
  }

  CircuitState _projectRuntimeFailures(
    CircuitState circuit,
    Map<ComponentId, ComponentHealthState> healthStates,
  ) {
    bool changed = false;
    final List<ComponentInstance> components = circuit.components
        .map<ComponentInstance>((ComponentInstance component) {
          final ComponentHealthState? health = healthStates[component.id];
          if (health?.failedOpen != true ||
              component.condition != ComponentCondition.normal) {
            return component;
          }
          changed = true;
          return ComponentInstance(
            id: component.id,
            modelType: component.modelType,
            terminals: component.terminals,
            parameters: component.parameters,
            condition: ComponentCondition.openCircuit,
            controlState: component.controlState,
          );
        })
        .toList(growable: false);
    if (!changed) return circuit;
    return CircuitState(
      circuitId: circuit.circuitId,
      revision: circuit.revision,
      mode: circuit.mode,
      components: components,
      connections: circuit.connections,
      sources: circuit.sources,
      instruments: circuit.instruments,
      probes: circuit.probes,
      settings: circuit.settings,
      metadata: circuit.metadata,
    );
  }
}
