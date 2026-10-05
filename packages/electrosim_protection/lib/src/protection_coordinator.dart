
import 'package:electrosim_controls/electrosim_controls.dart';
import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:electrosim_measurements/electrosim_measurements.dart';
import 'package:electrosim_solver_ac/electrosim_solver_ac.dart';
import 'package:electrosim_solver_dc/electrosim_solver_dc.dart';
import 'package:electrosim_topology/electrosim_topology.dart';

enum ProtectionTripCause {
  none,
  preexisting,
  magneticInstantaneous,
  timeCurrent,
}

enum ProtectionCoordinationIssueCode {
  solveFailed,
  missingBranchCurrent,
}

final class ProtectionCoordinationIssue {
  const ProtectionCoordinationIssue({
    required this.code,
    required this.message,
    this.componentId,
  });

  final ProtectionCoordinationIssueCode code;
  final String message;
  final ComponentId? componentId;
}

final class ProtectionDeviceState {
  const ProtectionDeviceState({
    required this.componentId,
    required this.exposure,
    required this.tripped,
    required this.tripCause,
    required this.lastObservedCurrentA,
  });

  final ComponentId componentId;
  final ProtectionExposureState exposure;
  final bool tripped;
  final ProtectionTripCause tripCause;
  final double lastObservedCurrentA;

  ProtectionDeviceState reset() => ProtectionDeviceState(
        componentId: componentId,
        exposure: const ProtectionExposureState.zero(),
        tripped: false,
        tripCause: ProtectionTripCause.none,
        lastObservedCurrentA: 0.0,
      );
}

final class ProtectionRuntimeState {
  ProtectionRuntimeState({
    Map<ComponentId, ProtectionDeviceState> devices =
        const <ComponentId, ProtectionDeviceState>{},
  }) : devices = Map<ComponentId, ProtectionDeviceState>.unmodifiable(devices);

  factory ProtectionRuntimeState.empty() => ProtectionRuntimeState();

  final Map<ComponentId, ProtectionDeviceState> devices;

  ProtectionDeviceState? operator [](ComponentId id) => devices[id];

  bool isTripped(ComponentId id) => devices[id]?.tripped ?? false;

  ProtectionRuntimeState reset(ComponentId id) {
    final ProtectionDeviceState? current = devices[id];
    if (current == null) return this;
    return ProtectionRuntimeState(
      devices: <ComponentId, ProtectionDeviceState>{
        ...devices,
        id: current.reset(),
      },
    );
  }
}

final class ProtectionDcOutcome {
  ProtectionDcOutcome({
    required this.result,
    required this.effectiveCircuit,
    required this.state,
    required Map<ComponentId, ContactorActuationState> relays,
    required Iterable<ElectromechanicalControlIssue> controlIssues,
    required Iterable<ProtectionCoordinationIssue> issues,
  })  : relays =
            Map<ComponentId, ContactorActuationState>.unmodifiable(relays),
        controlIssues =
            List<ElectromechanicalControlIssue>.unmodifiable(controlIssues),
        issues = List<ProtectionCoordinationIssue>.unmodifiable(issues);

  final DcSolveResult result;
  final CircuitState effectiveCircuit;
  final ProtectionRuntimeState state;
  final Map<ComponentId, ContactorActuationState> relays;
  final List<ElectromechanicalControlIssue> controlIssues;
  final List<ProtectionCoordinationIssue> issues;
}

final class ProtectionAc1Outcome {
  ProtectionAc1Outcome({
    required this.result,
    required this.effectiveCircuit,
    required this.state,
    required Map<ComponentId, ContactorActuationState> contactors,
    required Iterable<ElectromechanicalControlIssue> controlIssues,
    required Iterable<ProtectionCoordinationIssue> issues,
  })  : contactors =
            Map<ComponentId, ContactorActuationState>.unmodifiable(contactors),
        controlIssues =
            List<ElectromechanicalControlIssue>.unmodifiable(controlIssues),
        issues = List<ProtectionCoordinationIssue>.unmodifiable(issues);

  final Ac1SolveResult result;
  final CircuitState effectiveCircuit;
  final ProtectionRuntimeState state;
  final Map<ComponentId, ContactorActuationState> contactors;
  final List<ElectromechanicalControlIssue> controlIssues;
  final List<ProtectionCoordinationIssue> issues;
}

final class ProtectionAc3Outcome {
  ProtectionAc3Outcome({
    required this.result,
    required this.effectiveCircuit,
    required this.state,
    required Map<ComponentId, ContactorActuationState> contactors,
    required Iterable<ElectromechanicalControlIssue> controlIssues,
    required Iterable<ProtectionCoordinationIssue> issues,
  })  : contactors =
            Map<ComponentId, ContactorActuationState>.unmodifiable(contactors),
        controlIssues =
            List<ElectromechanicalControlIssue>.unmodifiable(controlIssues),
        issues = List<ProtectionCoordinationIssue>.unmodifiable(issues);

  final Ac3SolveResult result;
  final CircuitState effectiveCircuit;
  final ProtectionRuntimeState state;
  final Map<ComponentId, ContactorActuationState> contactors;
  final List<ElectromechanicalControlIssue> controlIssues;
  final List<ProtectionCoordinationIssue> issues;
}

final class ProtectionCoordinator {
  const ProtectionCoordinator({
    this.dynamics = const ProtectionDynamicsEngine(),
    this.controls = const ElectromechanicalControlEngine(),
  });

  final ProtectionDynamicsEngine dynamics;
  final ElectromechanicalControlEngine controls;

  ProtectionDcOutcome advanceDc({
    required CircuitState circuit,
    required TopologyGraph topology,
    required Duration elapsed,
    ProtectionRuntimeState? previous,
    SolverDC solver = const SolverDC(),
    ElectromechanicalControlEngine? controlsEngine,
    Map<ComponentId, bool> previousRelayStates =
        const <ComponentId, bool>{},
  }) {
    _validateElapsed(elapsed);
    final ElectromechanicalControlEngine controlEngine =
        controlsEngine ?? controls;
    final ProtectionRuntimeState baseline =
        _seedState(circuit, previous ?? ProtectionRuntimeState.empty());
    CircuitState effective = _applyTrips(circuit, baseline);
    ElectromechanicalDcOutcome control = controlEngine.solveDc(
      circuit: effective,
      topology: topology,
      solver: solver,
      previousStates: previousRelayStates,
    );
    DcSolveResult result = control.result;
    final List<ProtectionCoordinationIssue> issues =
        <ProtectionCoordinationIssue>[];

    if (!result.isSolved) {
      issues.add(
        const ProtectionCoordinationIssue(
          code: ProtectionCoordinationIssueCode.solveFailed,
          message:
              'DC solve failed before relay/protection exposure could advance.',
        ),
      );
      return ProtectionDcOutcome(
        result: result,
        effectiveCircuit: control.effectiveCircuit,
        state: baseline,
        relays: control.relays,
        controlIssues: control.issues,
        issues: issues,
      );
    }

    final ProtectionRuntimeState next = _advanceState(
      circuit: circuit,
      previous: baseline,
      elapsed: elapsed,
      currentFor: (ComponentInstance component) =>
          _dcProtectionCurrent(component, result, issues),
    );

    if (_tripSetChanged(baseline, next)) {
      effective = _applyTrips(circuit, next);
      control = controlEngine.solveDc(
        circuit: effective,
        topology: topology,
        solver: solver,
        previousStates: <ComponentId, bool>{
          for (final MapEntry<ComponentId, ContactorActuationState> entry
              in control.relays.entries)
            entry.key: entry.value.actuated,
        },
      );
      result = control.result;
      if (!result.isSolved) {
        issues.add(
          const ProtectionCoordinationIssue(
            code: ProtectionCoordinationIssueCode.solveFailed,
            message:
                'DC solve failed after applying protection trip state.',
          ),
        );
      }
    }

    return ProtectionDcOutcome(
      result: result,
      effectiveCircuit: control.effectiveCircuit,
      state: next,
      relays: control.relays,
      controlIssues: control.issues,
      issues: issues,
    );
  }

  ProtectionAc1Outcome advanceAc1({
    required CircuitState circuit,
    required TopologyGraph topology,
    required Duration elapsed,
    ProtectionRuntimeState? previous,
    SolverAC1 solver = const SolverAC1(),
    ElectromechanicalControlEngine? controlsEngine,
    Map<ComponentId, bool> previousContactorStates =
        const <ComponentId, bool>{},
  }) {
    _validateElapsed(elapsed);
    final ElectromechanicalControlEngine controlEngine =
        controlsEngine ?? controls;
    final ProtectionRuntimeState baseline =
        _seedState(circuit, previous ?? ProtectionRuntimeState.empty());
    CircuitState effective = _applyTrips(circuit, baseline);
    ElectromechanicalAc1Outcome control = controlEngine.solveAc1(
      circuit: effective,
      topology: topology,
      solver: solver,
      previousStates: previousContactorStates,
    );
    Ac1SolveResult result = control.result;
    final List<ProtectionCoordinationIssue> issues =
        <ProtectionCoordinationIssue>[];

    if (!result.isSolved) {
      issues.add(
        const ProtectionCoordinationIssue(
          code: ProtectionCoordinationIssueCode.solveFailed,
          message: 'AC1 solve failed before protection exposure could advance.',
        ),
      );
      return ProtectionAc1Outcome(
        result: result,
        effectiveCircuit: control.effectiveCircuit,
        state: baseline,
        contactors: control.contactors,
        controlIssues: control.issues,
        issues: issues,
      );
    }

    final ProtectionRuntimeState next = _advanceState(
      circuit: circuit,
      previous: baseline,
      elapsed: elapsed,
      currentFor: (ComponentInstance component) =>
          _ac1ProtectionCurrent(component, result, issues),
    );

    if (_tripSetChanged(baseline, next)) {
      effective = _applyTrips(circuit, next);
      control = controlEngine.solveAc1(
        circuit: effective,
        topology: topology,
        solver: solver,
        previousStates: <ComponentId, bool>{
          for (final MapEntry<ComponentId, ContactorActuationState> entry
              in control.contactors.entries)
            entry.key: entry.value.actuated,
        },
      );
      result = control.result;
      if (!result.isSolved) {
        issues.add(
          const ProtectionCoordinationIssue(
            code: ProtectionCoordinationIssueCode.solveFailed,
            message: 'AC1 solve failed after applying protection trip state.',
          ),
        );
      }
    }

    return ProtectionAc1Outcome(
      result: result,
      effectiveCircuit: control.effectiveCircuit,
      state: next,
      contactors: control.contactors,
      controlIssues: control.issues,
      issues: issues,
    );
  }

  ProtectionAc3Outcome advanceAc3({
    required CircuitState circuit,
    required TopologyGraph topology,
    required Duration elapsed,
    ProtectionRuntimeState? previous,
    SolverAC3 solver = const SolverAC3(),
    ElectromechanicalControlEngine? controlsEngine,
    Map<ComponentId, bool> previousContactorStates =
        const <ComponentId, bool>{},
  }) {
    _validateElapsed(elapsed);
    final ElectromechanicalControlEngine controlEngine =
        controlsEngine ?? controls;
    final ProtectionRuntimeState baseline =
        _seedState(circuit, previous ?? ProtectionRuntimeState.empty());
    CircuitState effective = _applyTrips(circuit, baseline);
    ElectromechanicalAc3Outcome control = controlEngine.solveAc3(
      circuit: effective,
      topology: topology,
      solver: solver,
      previousStates: previousContactorStates,
    );
    Ac3SolveResult result = control.result;
    final List<ProtectionCoordinationIssue> issues =
        <ProtectionCoordinationIssue>[];

    if (!result.isSolved) {
      issues.add(
        const ProtectionCoordinationIssue(
          code: ProtectionCoordinationIssueCode.solveFailed,
          message: 'AC3 solve failed before protection exposure could advance.',
        ),
      );
      return ProtectionAc3Outcome(
        result: result,
        effectiveCircuit: control.effectiveCircuit,
        state: baseline,
        contactors: control.contactors,
        controlIssues: control.issues,
        issues: issues,
      );
    }

    final ProtectionRuntimeState next = _advanceState(
      circuit: circuit,
      previous: baseline,
      elapsed: elapsed,
      currentFor: (ComponentInstance component) =>
          _ac3ProtectionCurrent(component, result, issues),
    );

    if (_tripSetChanged(baseline, next)) {
      effective = _applyTrips(circuit, next);
      control = controlEngine.solveAc3(
        circuit: effective,
        topology: topology,
        solver: solver,
        previousStates: <ComponentId, bool>{
          for (final MapEntry<ComponentId, ContactorActuationState> entry
              in control.contactors.entries)
            entry.key: entry.value.actuated,
        },
      );
      result = control.result;
      if (!result.isSolved) {
        issues.add(
          const ProtectionCoordinationIssue(
            code: ProtectionCoordinationIssueCode.solveFailed,
            message: 'AC3 solve failed after applying protection trip state.',
          ),
        );
      }
    }

    return ProtectionAc3Outcome(
      result: result,
      effectiveCircuit: control.effectiveCircuit,
      state: next,
      contactors: control.contactors,
      controlIssues: control.issues,
      issues: issues,
    );
  }

  ProtectionRuntimeState _advanceState({
    required CircuitState circuit,
    required ProtectionRuntimeState previous,
    required Duration elapsed,
    required double? Function(ComponentInstance component) currentFor,
  }) {
    final Map<ComponentId, ProtectionDeviceState> next =
        <ComponentId, ProtectionDeviceState>{};

    for (final ComponentInstance component in circuit.components) {
      if (!_isProtection(component.modelType)) continue;
      final ProtectionDeviceState prior = previous[component.id] ??
          ProtectionDeviceState(
            componentId: component.id,
            exposure: const ProtectionExposureState.zero(),
            tripped: false,
            tripCause: ProtectionTripCause.none,
            lastObservedCurrentA: 0.0,
          );

      if (prior.tripped) {
        next[component.id] = prior;
        continue;
      }

      final double? currentA = currentFor(component);
      if (currentA == null) {
        next[component.id] = prior;
        continue;
      }

      ProtectionExposureState exposure = dynamics.advance(
        component: component,
        currentA: currentA,
        elapsed: elapsed,
        previous: prior.exposure,
      );
      final bool instantaneous =
          dynamics.shouldOpenInstantaneously(component, currentA);
      if (instantaneous && exposure.exposure < 1.0) {
        exposure = ProtectionExposureState(
          exposure: 1.0,
          ratio: exposure.ratio,
          tripTimeSeconds: exposure.tripTimeSeconds,
          zone: exposure.zone,
        );
      }
      final bool tripped = instantaneous || exposure.shouldTrip;
      next[component.id] = ProtectionDeviceState(
        componentId: component.id,
        exposure: exposure,
        tripped: tripped,
        tripCause: instantaneous
            ? ProtectionTripCause.magneticInstantaneous
            : tripped
                ? ProtectionTripCause.timeCurrent
                : ProtectionTripCause.none,
        lastObservedCurrentA: currentA.abs(),
      );
    }

    return ProtectionRuntimeState(devices: next);
  }

  ProtectionRuntimeState _seedState(
    CircuitState circuit,
    ProtectionRuntimeState previous,
  ) {
    final Map<ComponentId, ProtectionDeviceState> seeded =
        <ComponentId, ProtectionDeviceState>{};

    for (final ComponentInstance component in circuit.components) {
      if (!_isProtection(component.modelType)) continue;
      final ProtectionDeviceState? remembered = previous[component.id];
      if (remembered != null) {
        seeded[component.id] = remembered;
        continue;
      }
      final bool preexisting = component.controlState['tripped'] == true;
      seeded[component.id] = ProtectionDeviceState(
        componentId: component.id,
        exposure: preexisting
            ? const ProtectionExposureState(
                exposure: 1.0,
                ratio: 0.0,
                tripTimeSeconds: double.infinity,
                zone: ProtectionZone.normal,
              )
            : const ProtectionExposureState.zero(),
        tripped: preexisting,
        tripCause: preexisting
            ? ProtectionTripCause.preexisting
            : ProtectionTripCause.none,
        lastObservedCurrentA: 0.0,
      );
    }

    return ProtectionRuntimeState(devices: seeded);
  }

  CircuitState _applyTrips(
    CircuitState circuit,
    ProtectionRuntimeState state,
  ) {
    final List<ComponentInstance> components = circuit.components
        .map((ComponentInstance component) {
      if (!_isProtection(component.modelType)) return component;
      final ProtectionDeviceState? device = state[component.id];
      if (device == null) return component;
      return ComponentInstance(
        id: component.id,
        modelType: component.modelType,
        terminals: component.terminals,
        parameters: component.parameters,
        condition: component.condition,
        controlState: <String, Object?>{
          ...component.controlState,
          'tripped': device.tripped,
        },
      );
    }).toList(growable: false);

    return CircuitState(
      circuitId: circuit.circuitId,
      revision: circuit.revision,
      mode: circuit.mode,
      components: components,
      connections: circuit.connections,
      sources: circuit.sources,
      settings: circuit.settings,
      metadata: circuit.metadata,
    );
  }

  double? _dcProtectionCurrent(
    ComponentInstance component,
    DcSolveResult result,
    List<ProtectionCoordinationIssue> issues,
  ) {
    if (component.modelType != 'breaker_dc' &&
        component.modelType != 'fuse_dc') {
      return null;
    }
    DcBranchResult? branch;
    for (final DcBranchResult candidate in result.branchResults) {
      if (candidate.id == 'component:' + component.id.value) {
        branch = candidate;
        break;
      }
    }
    final double? current = branch?.currentA;
    if (current == null) {
      issues.add(_missingCurrent(component));
    }
    return current?.abs();
  }

  double? _ac1ProtectionCurrent(
    ComponentInstance component,
    Ac1SolveResult result,
    List<ProtectionCoordinationIssue> issues,
  ) {
    if (component.modelType != 'breaker_ac1' &&
        component.modelType != 'fuse_ac1') {
      return null;
    }
    Ac1BranchResult? branch;
    for (final Ac1BranchResult candidate in result.branchResults) {
      if (candidate.id == 'component:' + component.id.value) {
        branch = candidate;
        break;
      }
    }
    final double? current = branch?.current?.magnitude;
    if (current == null) {
      issues.add(_missingCurrent(component));
    }
    return current;
  }

  double? _ac3ProtectionCurrent(
    ComponentInstance component,
    Ac3SolveResult result,
    List<ProtectionCoordinationIssue> issues,
  ) {
    if (component.modelType != 'breaker_3p' &&
        component.modelType != 'breaker_4p' &&
        component.modelType != 'thermal_overload_3p') {
      return null;
    }
    double maximum = 0.0;
    var found = false;
    final List<String> poles = component.modelType == 'breaker_4p'
        ? <String>['L1', 'L2', 'L3', 'N']
        : <String>['L1', 'L2', 'L3'];
    for (final String phase in poles) {
      final String id =
          'component:' + component.id.value + ':power:' + phase;
      for (final Ac3BranchResult candidate in result.branchResults) {
        if (candidate.id != id) continue;
        final double? current = candidate.current?.magnitude;
        if (current != null) {
          found = true;
          if (current > maximum) maximum = current;
        }
        break;
      }
    }
    if (!found) {
      issues.add(_missingCurrent(component));
      return null;
    }
    return maximum;
  }

  ProtectionCoordinationIssue _missingCurrent(
    ComponentInstance component,
  ) =>
      ProtectionCoordinationIssue(
        code: ProtectionCoordinationIssueCode.missingBranchCurrent,
        message:
            'Protection ' + component.id.value + ' has no resolved branch current.',
        componentId: component.id,
      );

  bool _tripSetChanged(
    ProtectionRuntimeState before,
    ProtectionRuntimeState after,
  ) {
    final Set<ComponentId> ids = <ComponentId>{
      ...before.devices.keys,
      ...after.devices.keys,
    };
    for (final ComponentId id in ids) {
      if (before.isTripped(id) != after.isTripped(id)) return true;
    }
    return false;
  }

  bool _isProtection(String modelType) => switch (modelType) {
        'breaker_dc' ||
        'fuse_dc' ||
        'breaker_ac1' ||
        'fuse_ac1' ||
        'breaker_3p' ||
        'breaker_4p' ||
        'thermal_overload_3p' =>
          true,
        _ => false,
      };

  void _validateElapsed(Duration elapsed) {
    if (elapsed.isNegative) {
      throw ArgumentError.value(
        elapsed,
        'elapsed',
        'Protection simulation time cannot be negative.',
      );
    }
  }
}
