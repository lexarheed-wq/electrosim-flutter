
import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:electrosim_solver_ac/electrosim_solver_ac.dart';
import 'package:electrosim_topology/electrosim_topology.dart';

enum ElectromechanicalControlIssueCode {
  invalidControlState,
  invalidCoilThreshold,
  missingCoilBranch,
  missingLinkedContactor,
  solveFailed,
  iterationLimitExceeded,
}

final class ElectromechanicalControlIssue {
  const ElectromechanicalControlIssue({
    required this.code,
    required this.message,
    this.componentId,
  });

  final ElectromechanicalControlIssueCode code;
  final String message;
  final ComponentId? componentId;
}

final class ContactorActuationState {
  const ContactorActuationState({
    required this.componentId,
    required this.actuated,
    required this.coilVoltageV,
    required this.pickupVoltageV,
    required this.dropoutVoltageV,
  });

  final ComponentId componentId;
  final bool actuated;
  final double coilVoltageV;
  final double pickupVoltageV;
  final double dropoutVoltageV;
}

final class ElectromechanicalAc1Outcome {
  ElectromechanicalAc1Outcome({
    required this.result,
    required this.effectiveCircuit,
    required Map<ComponentId, ContactorActuationState> contactors,
    required Iterable<ElectromechanicalControlIssue> issues,
    required this.iterations,
    required this.converged,
  })  : contactors =
            Map<ComponentId, ContactorActuationState>.unmodifiable(contactors),
        issues = List<ElectromechanicalControlIssue>.unmodifiable(issues);

  final Ac1SolveResult result;
  final CircuitState effectiveCircuit;
  final Map<ComponentId, ContactorActuationState> contactors;
  final List<ElectromechanicalControlIssue> issues;
  final int iterations;
  final bool converged;
}

final class ElectromechanicalAc3Outcome {
  ElectromechanicalAc3Outcome({
    required this.result,
    required this.effectiveCircuit,
    required Map<ComponentId, ContactorActuationState> contactors,
    required Iterable<ElectromechanicalControlIssue> issues,
    required this.iterations,
    required this.converged,
  })  : contactors =
            Map<ComponentId, ContactorActuationState>.unmodifiable(contactors),
        issues = List<ElectromechanicalControlIssue>.unmodifiable(issues);

  final Ac3SolveResult result;
  final CircuitState effectiveCircuit;
  final Map<ComponentId, ContactorActuationState> contactors;
  final List<ElectromechanicalControlIssue> issues;
  final int iterations;
  final bool converged;
}

/// Coordinates electromechanical control without putting state transitions
/// inside the linear AC solvers.
///
/// The electrical solvers remain deterministic for a given CircuitState.
/// This controller performs a bounded fixed-point iteration:
/// 1. apply current contactor states to transient controlState,
/// 2. solve the AC network,
/// 3. derive contactor state from measured coil RMS voltage,
/// 4. synchronize linked NO/NC auxiliary contacts,
/// 5. repeat until stable or maxIterations is reached.
final class ElectromechanicalControlEngine {
  const ElectromechanicalControlEngine({this.maxIterations = 4})
      : assert(maxIterations > 0);

  final int maxIterations;

  ElectromechanicalAc1Outcome solveAc1({
    required CircuitState circuit,
    required TopologyGraph topology,
    SolverAC1 solver = const SolverAC1(),
    Map<ComponentId, bool> previousStates = const <ComponentId, bool>{},
  }) {
    if (circuit.mode != ElectricalMode.ac1 ||
        topology.mode != ElectricalMode.ac1) {
      throw ArgumentError('Electromechanical AC1 coordination requires AC1.');
    }

    final List<ElectromechanicalControlIssue> issues =
        <ElectromechanicalControlIssue>[];
    Map<ComponentId, bool> states = _initialStates(
      circuit,
      'contactor_ac1',
      issues,
      previousStates,
    );
    CircuitState effective = _applyStates(circuit, states, issues);
    Ac1SolveResult result = solver.solve(effective, topology);

    for (var iteration = 1; iteration <= maxIterations; iteration++) {
      if (!result.isSolved) {
        issues.add(
          const ElectromechanicalControlIssue(
            code: ElectromechanicalControlIssueCode.solveFailed,
            message:
                'AC1 solve failed before electromechanical state could stabilize.',
          ),
        );
        return ElectromechanicalAc1Outcome(
          result: result,
          effectiveCircuit: effective,
          contactors: _statesFromAc1(circuit, states, result, issues),
          issues: issues,
          iterations: iteration,
          converged: false,
        );
      }

      final Map<ComponentId, bool> next = _deriveAc1States(
        circuit,
        states,
        result,
        issues,
      );
      final bool stable = _sameStates(states, next);
      if (stable) {
        return ElectromechanicalAc1Outcome(
          result: result,
          effectiveCircuit: effective,
          contactors: _statesFromAc1(circuit, states, result, issues),
          issues: issues,
          iterations: iteration,
          converged: true,
        );
      }

      if (iteration == maxIterations) {
        issues.add(
          const ElectromechanicalControlIssue(
            code:
                ElectromechanicalControlIssueCode.iterationLimitExceeded,
            message:
                'Electromechanical AC1 state did not stabilize within the bounded iteration limit.',
          ),
        );
        return ElectromechanicalAc1Outcome(
          result: result,
          effectiveCircuit: effective,
          contactors: _statesFromAc1(circuit, states, result, issues),
          issues: issues,
          iterations: iteration,
          converged: false,
        );
      }

      states = next;
      effective = _applyStates(circuit, states, issues);
      result = solver.solve(effective, topology);
    }

    throw StateError('Unreachable electromechanical AC1 loop termination.');
  }

  ElectromechanicalAc3Outcome solveAc3({
    required CircuitState circuit,
    required TopologyGraph topology,
    SolverAC3 solver = const SolverAC3(),
    Map<ComponentId, bool> previousStates = const <ComponentId, bool>{},
  }) {
    if (circuit.mode != ElectricalMode.ac3 ||
        topology.mode != ElectricalMode.ac3) {
      throw ArgumentError('Electromechanical AC3 coordination requires AC3.');
    }

    final List<ElectromechanicalControlIssue> issues =
        <ElectromechanicalControlIssue>[];
    Map<ComponentId, bool> states = _initialStates(
      circuit,
      'contactor_3p',
      issues,
      previousStates,
    );
    CircuitState effective = _applyStates(circuit, states, issues);
    Ac3SolveResult result = solver.solve(effective, topology);

    for (var iteration = 1; iteration <= maxIterations; iteration++) {
      if (!result.isSolved) {
        issues.add(
          const ElectromechanicalControlIssue(
            code: ElectromechanicalControlIssueCode.solveFailed,
            message:
                'AC3 solve failed before electromechanical state could stabilize.',
          ),
        );
        return ElectromechanicalAc3Outcome(
          result: result,
          effectiveCircuit: effective,
          contactors: _statesFromAc3(circuit, states, result, issues),
          issues: issues,
          iterations: iteration,
          converged: false,
        );
      }

      final Map<ComponentId, bool> next = _deriveAc3States(
        circuit,
        states,
        result,
        issues,
      );
      final bool stable = _sameStates(states, next);
      if (stable) {
        return ElectromechanicalAc3Outcome(
          result: result,
          effectiveCircuit: effective,
          contactors: _statesFromAc3(circuit, states, result, issues),
          issues: issues,
          iterations: iteration,
          converged: true,
        );
      }

      if (iteration == maxIterations) {
        issues.add(
          const ElectromechanicalControlIssue(
            code:
                ElectromechanicalControlIssueCode.iterationLimitExceeded,
            message:
                'Electromechanical AC3 state did not stabilize within the bounded iteration limit.',
          ),
        );
        return ElectromechanicalAc3Outcome(
          result: result,
          effectiveCircuit: effective,
          contactors: _statesFromAc3(circuit, states, result, issues),
          issues: issues,
          iterations: iteration,
          converged: false,
        );
      }

      states = next;
      effective = _applyStates(circuit, states, issues);
      result = solver.solve(effective, topology);
    }

    throw StateError('Unreachable electromechanical AC3 loop termination.');
  }
}

Map<ComponentId, bool> _initialStates(
  CircuitState circuit,
  String contactorModel,
  List<ElectromechanicalControlIssue> issues,
  Map<ComponentId, bool> previousStates,
) {
  final Map<ComponentId, bool> states = <ComponentId, bool>{};
  for (final ComponentInstance component in circuit.components) {
    if (component.modelType != contactorModel) continue;
    final Object? raw = component.controlState['actuated'];
    if (raw != null && raw is! bool) {
      issues.add(
        ElectromechanicalControlIssue(
          code: ElectromechanicalControlIssueCode.invalidControlState,
          message:
              'Contactor ${component.id.value} has a non-boolean actuated state; released state is used.',
          componentId: component.id,
        ),
      );
    }
    states[component.id] = previousStates.containsKey(component.id)
        ? previousStates[component.id]!
        : raw is bool
            ? raw
            : false;
  }
  return states;
}

CircuitState _applyStates(
  CircuitState circuit,
  Map<ComponentId, bool> states,
  List<ElectromechanicalControlIssue> issues,
) {
  final Set<String> known =
      states.keys.map((ComponentId id) => id.value).toSet();
  final List<ComponentInstance> components = <ComponentInstance>[];

  for (final ComponentInstance component in circuit.components) {
    bool? actuated;
    if (states.containsKey(component.id)) {
      actuated = states[component.id]!;
    } else if (component.modelType == 'contactor_aux_no' ||
        component.modelType == 'contactor_aux_nc') {
      final Object? linked = component.parameters['linkedContactorId'];
      if (linked is String && known.contains(linked)) {
        actuated = states[ComponentId(linked)];
      } else {
        issues.add(
          ElectromechanicalControlIssue(
            code:
                ElectromechanicalControlIssueCode.missingLinkedContactor,
            message:
                'Auxiliary contact ${component.id.value} does not reference a known contactor.',
            componentId: component.id,
          ),
        );
        final Object? raw = component.controlState['actuated'];
        actuated = raw is bool ? raw : false;
      }
    }

    if (actuated == null) {
      components.add(component);
      continue;
    }

    components.add(
      ComponentInstance(
        id: component.id,
        modelType: component.modelType,
        terminals: component.terminals,
        parameters: component.parameters,
        condition: component.condition,
        controlState: <String, Object?>{
          ...component.controlState,
          'actuated': actuated,
        },
      ),
    );
  }

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

Map<ComponentId, bool> _deriveAc1States(
  CircuitState circuit,
  Map<ComponentId, bool> previous,
  Ac1SolveResult result,
  List<ElectromechanicalControlIssue> issues,
) {
  final Map<ComponentId, bool> next = <ComponentId, bool>{};
  for (final ComponentInstance component in circuit.components) {
    if (component.modelType != 'contactor_ac1') continue;
    final _CoilThresholds? thresholds = _thresholds(component, issues);
    final Ac1BranchResult? coil = _findAc1Branch(
      result,
      'component:${component.id.value}:control:coil',
    );
    if (thresholds == null || coil == null) {
      if (coil == null) {
        issues.add(
          ElectromechanicalControlIssue(
            code: ElectromechanicalControlIssueCode.missingCoilBranch,
            message:
                'No AC1 coil branch result exists for contactor ${component.id.value}.',
            componentId: component.id,
          ),
        );
      }
      next[component.id] = false;
      continue;
    }
    final double voltage = coil.voltage.magnitude;
    next[component.id] = _nextActuation(
      previous: previous[component.id] ?? false,
      voltageV: voltage,
      thresholds: thresholds,
    );
  }
  return next;
}

Map<ComponentId, bool> _deriveAc3States(
  CircuitState circuit,
  Map<ComponentId, bool> previous,
  Ac3SolveResult result,
  List<ElectromechanicalControlIssue> issues,
) {
  final Map<ComponentId, bool> next = <ComponentId, bool>{};
  for (final ComponentInstance component in circuit.components) {
    if (component.modelType != 'contactor_3p') continue;
    final _CoilThresholds? thresholds = _thresholds(component, issues);
    final Ac3BranchResult? coil = _findAc3Branch(
      result,
      'component:${component.id.value}:control:coil',
    );
    if (thresholds == null || coil == null) {
      if (coil == null) {
        issues.add(
          ElectromechanicalControlIssue(
            code: ElectromechanicalControlIssueCode.missingCoilBranch,
            message:
                'No AC3 coil branch result exists for contactor ${component.id.value}.',
            componentId: component.id,
          ),
        );
      }
      next[component.id] = false;
      continue;
    }
    final double voltage = coil.voltage.magnitude;
    next[component.id] = _nextActuation(
      previous: previous[component.id] ?? false,
      voltageV: voltage,
      thresholds: thresholds,
    );
  }
  return next;
}

Map<ComponentId, ContactorActuationState> _statesFromAc1(
  CircuitState circuit,
  Map<ComponentId, bool> states,
  Ac1SolveResult result,
  List<ElectromechanicalControlIssue> issues,
) {
  final Map<ComponentId, ContactorActuationState> output =
      <ComponentId, ContactorActuationState>{};
  for (final ComponentInstance component in circuit.components) {
    if (component.modelType != 'contactor_ac1') continue;
    final _CoilThresholds? thresholds = _thresholds(component, issues);
    if (thresholds == null) continue;
    final Ac1BranchResult? coil = _findAc1Branch(
      result,
      'component:${component.id.value}:control:coil',
    );
    output[component.id] = ContactorActuationState(
      componentId: component.id,
      actuated: states[component.id] ?? false,
      coilVoltageV: coil?.voltage.magnitude ?? 0.0,
      pickupVoltageV: thresholds.pickup,
      dropoutVoltageV: thresholds.dropout,
    );
  }
  return output;
}

Map<ComponentId, ContactorActuationState> _statesFromAc3(
  CircuitState circuit,
  Map<ComponentId, bool> states,
  Ac3SolveResult result,
  List<ElectromechanicalControlIssue> issues,
) {
  final Map<ComponentId, ContactorActuationState> output =
      <ComponentId, ContactorActuationState>{};
  for (final ComponentInstance component in circuit.components) {
    if (component.modelType != 'contactor_3p') continue;
    final _CoilThresholds? thresholds = _thresholds(component, issues);
    if (thresholds == null) continue;
    final Ac3BranchResult? coil = _findAc3Branch(
      result,
      'component:${component.id.value}:control:coil',
    );
    output[component.id] = ContactorActuationState(
      componentId: component.id,
      actuated: states[component.id] ?? false,
      coilVoltageV: coil?.voltage.magnitude ?? 0.0,
      pickupVoltageV: thresholds.pickup,
      dropoutVoltageV: thresholds.dropout,
    );
  }
  return output;
}

_CoilThresholds? _thresholds(
  ComponentInstance component,
  List<ElectromechanicalControlIssue> issues,
) {
  final Object? pickupRaw = component.parameters['coilPickupVoltageV'];
  final Object? dropoutRaw = component.parameters['coilDropoutVoltageV'];
  if (pickupRaw is! num || dropoutRaw is! num) {
    issues.add(
      ElectromechanicalControlIssue(
        code: ElectromechanicalControlIssueCode.invalidCoilThreshold,
        message:
            'Contactor ${component.id.value} requires explicit coilPickupVoltageV and coilDropoutVoltageV.',
        componentId: component.id,
      ),
    );
    return null;
  }
  final double pickup = pickupRaw.toDouble();
  final double dropout = dropoutRaw.toDouble();
  if (!pickup.isFinite ||
      !dropout.isFinite ||
      pickup <= 0 ||
      dropout < 0 ||
      dropout >= pickup) {
    issues.add(
      ElectromechanicalControlIssue(
        code: ElectromechanicalControlIssueCode.invalidCoilThreshold,
        message:
            'Contactor ${component.id.value} requires 0 <= dropout < pickup.',
        componentId: component.id,
      ),
    );
    return null;
  }
  return _CoilThresholds(pickup, dropout);
}

bool _nextActuation({
  required bool previous,
  required double voltageV,
  required _CoilThresholds thresholds,
}) =>
    previous
        ? voltageV > thresholds.dropout
        : voltageV >= thresholds.pickup;

bool _sameStates(
  Map<ComponentId, bool> left,
  Map<ComponentId, bool> right,
) {
  if (left.length != right.length) return false;
  for (final MapEntry<ComponentId, bool> entry in left.entries) {
    if (right[entry.key] != entry.value) return false;
  }
  return true;
}

Ac1BranchResult? _findAc1Branch(Ac1SolveResult result, String id) {
  for (final Ac1BranchResult branch in result.branchResults) {
    if (branch.id == id) return branch;
  }
  return null;
}

Ac3BranchResult? _findAc3Branch(Ac3SolveResult result, String id) {
  for (final Ac3BranchResult branch in result.branchResults) {
    if (branch.id == id) return branch;
  }
  return null;
}

final class _CoilThresholds {
  const _CoilThresholds(this.pickup, this.dropout);

  final double pickup;
  final double dropout;
}
