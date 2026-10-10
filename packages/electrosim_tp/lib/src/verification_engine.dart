import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:electrosim_scenarios/electrosim_scenarios.dart';
import 'package:electrosim_solver_dc/electrosim_solver_dc.dart';
import 'package:electrosim_topology/electrosim_topology.dart';

import 'tp_models.dart';
import 'wiring_topology_matcher.dart';

final class VerificationEngine {
  const VerificationEngine({
    TopologyEngine topology = const TopologyEngine(),
    SolverDC solver = const SolverDC(),
    this.qualifiedSolve,
  }) : _topology = topology,
       _solver = solver;

  final TopologyEngine _topology;
  final SolverDC _solver;

  /// Production supplies the same CC/AC1/AC3/PV runtime used by the simulator.
  /// Standalone domain tests use the historic DC solver as a fallback.
  final bool Function(CircuitState)? qualifiedSolve;

  bool _isSolved(CircuitState circuit) =>
      qualifiedSolve?.call(circuit) ??
      (circuit.mode == ElectricalMode.dc &&
          _solver.solve(circuit, _topology.compile(circuit)).status ==
              DcSolveStatus.solved);

  TpEvaluation evaluateWiring(TpDefinition definition, CircuitState circuit) {
    if (definition.mode != TpMode.wiring) throw StateError('Not a wiring TP.');
    final bool functional =
        _isSolved(circuit) && _criticalConditionsNormal(circuit);
    final reference = definition.referenceCircuit;
    final bool matches =
        reference != null &&
        reference.sources.isNotEmpty &&
        reference.components.isNotEmpty &&
        reference.connections.isNotEmpty &&
        WiringTopologyMatcher.equivalent(definition.referenceCircuit!, circuit);
    final bool passed = functional && matches;
    return TpEvaluation(
      score: passed ? definition.maxScore : 0,
      functional: functional,
      safetyOk: _criticalConditionsNormal(circuit),
      measurementsOk: passed,
    );
  }

  TpEvaluation evaluateTroubleshooting(
    TpDefinition definition,
    CircuitState circuit,
    FaultScenarioDefinition scenario,
  ) {
    if (definition.mode != TpMode.troubleshooting)
      throw StateError('Not a troubleshooting TP.');
    final solved = _isSolved(circuit);
    final causesRemoved = _rootCausesRemoved(scenario, circuit);
    final safetyOk = _criticalConditionsNormal(circuit);
    final passed = solved && causesRemoved && safetyOk;
    return TpEvaluation(
      score: passed ? definition.maxScore : 0,
      functional: solved && causesRemoved,
      safetyOk: safetyOk,
      measurementsOk: passed,
    );
  }

  static bool _criticalConditionsNormal(CircuitState circuit) =>
      circuit.components.every(
        (item) => item.condition == ComponentCondition.normal,
      ) &&
      circuit.sources.every((item) => item.enabled);

  static bool _rootCausesRemoved(
    FaultScenarioDefinition scenario,
    CircuitState repaired,
  ) {
    for (final cause in scenario.teacherTruth.rootCauses) {
      switch (cause.kind) {
        case RootCauseKind.missingConnection:
          if (!repaired.connections.any(
            (item) => item.id.value == cause.targetId && item.enabled,
          ))
            return false;
          break;
        case RootCauseKind.componentOpen:
          final matches = repaired.components.where(
            (item) => item.id.value == cause.targetId,
          );
          if (matches.length != 1 ||
              matches.single.condition != ComponentCondition.normal)
            return false;
          break;
      }
    }
    return true;
  }
}
