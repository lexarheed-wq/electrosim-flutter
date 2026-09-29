import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:electrosim_scenarios/electrosim_scenarios.dart';
import 'package:electrosim_solver_dc/electrosim_solver_dc.dart';
import 'package:electrosim_topology/electrosim_topology.dart';

import 'tp_models.dart';

final class VerificationEngine {
  const VerificationEngine({
    TopologyEngine topology = const TopologyEngine(),
    SolverDC solver = const SolverDC(),
  }) : _topology = topology, _solver = solver;

  final TopologyEngine _topology;
  final SolverDC _solver;

  TpEvaluation evaluateWiring(TpDefinition definition, CircuitState circuit) {
    if (definition.mode != TpMode.wiring) throw StateError('Not a wiring TP.');
    final result = _solver.solve(circuit, _topology.compile(circuit));
    final functional = result.status == DcSolveStatus.solved && _criticalConditionsNormal(circuit);
    final structureMatches = definition.referenceCircuit != null &&
        circuit.components.length == definition.referenceCircuit!.components.length &&
        circuit.sources.length == definition.referenceCircuit!.sources.length &&
        circuit.connections.length == definition.referenceCircuit!.connections.length;
    final passed = functional && structureMatches;
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
    if (definition.mode != TpMode.troubleshooting) throw StateError('Not a troubleshooting TP.');
    final result = _solver.solve(circuit, _topology.compile(circuit));
    final solved = result.status == DcSolveStatus.solved;
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
      circuit.components.every((item) => item.condition == ComponentCondition.normal) &&
      circuit.sources.every((item) => item.enabled);

  static bool _rootCausesRemoved(FaultScenarioDefinition scenario, CircuitState repaired) {
    for (final cause in scenario.teacherTruth.rootCauses) {
      switch (cause.kind) {
        case RootCauseKind.missingConnection:
          if (!repaired.connections.any((item) => item.id.value == cause.targetId && item.enabled)) return false;
          break;
        case RootCauseKind.componentOpen:
          final matches = repaired.components.where((item) => item.id.value == cause.targetId);
          if (matches.length != 1 || matches.single.condition != ComponentCondition.normal) return false;
          break;
      }
    }
    return true;
  }
}
