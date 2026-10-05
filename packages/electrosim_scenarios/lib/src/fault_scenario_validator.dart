import 'dart:convert';
import 'dart:math' as math;

import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:electrosim_solver_dc/electrosim_solver_dc.dart';
import 'package:electrosim_topology/electrosim_topology.dart';

import 'fault_scenario_definition.dart';

final class FaultScenarioValidationIssue {
  const FaultScenarioValidationIssue(this.code, this.message);
  final String code;
  final String message;
}

final class FaultScenarioValidationResult {
  const FaultScenarioValidationResult({
    required this.scenarioId,
    required this.issues,
    required this.stamp,
    required this.repairable,
  });

  final FaultScenarioId scenarioId;
  final List<FaultScenarioValidationIssue> issues;
  final FaultScenarioValidationStamp stamp;
  final bool repairable;
  bool get isValid => issues.isEmpty && repairable;
}

final class FaultScenarioValidator {
  const FaultScenarioValidator({
    TopologyEngine topologyEngine = const TopologyEngine(),
    SolverDC solverDC = const SolverDC(),
  })  : _topologyEngine = topologyEngine,
        _solverDC = solverDC;

  static const String validatorVersion = 'F11-FAULT-VALIDATOR-1';

  final TopologyEngine _topologyEngine;
  final SolverDC _solverDC;

  FaultScenarioValidationResult validate(FaultScenarioDefinition scenario) {
    final List<FaultScenarioValidationIssue> issues = <FaultScenarioValidationIssue>[];
    final CircuitState faulty = scenario.faultyCircuit;

    if (faulty.revision != 0) {
      issues.add(const FaultScenarioValidationIssue('revision-not-zero', 'Published fault scenarios must start at revision 0.'));
    }
    if (faulty.mode != ElectricalMode.dc) {
      issues.add(const FaultScenarioValidationIssue('unsupported-f11-mode', 'F11-R1 intentionally starts with DC fault scenarios only.'));
    }
    if (_containsForbiddenExampleReference(scenario.canonicalPrivatePayload())) {
      issues.add(const FaultScenarioValidationIssue('example-reference', 'Fault scenarios must never contain a legacy example linkage.'));
    }
    if (!_faultIsMaterialized(scenario)) {
      issues.add(const FaultScenarioValidationIssue('fault-not-materialized', 'The scenario fault must exist in CircuitState, not as hidden injection metadata.'));
    }

    DcSolveResult? faultyResult;
    if (faulty.mode == ElectricalMode.dc) {
      faultyResult = _solverDC.solve(faulty, _topologyEngine.compile(faulty));
      if (faultyResult.status != DcSolveStatus.solved) {
        issues.add(FaultScenarioValidationIssue('faulty-circuit-not-solvable', 'Faulty circuit must produce deterministic DC evidence in F11-R1: ${faultyResult.status.name}.'));
      } else {
        _validateExpectedMeasurements(scenario, faultyResult, issues);
      }
    }

    var repairable = false;
    for (final RepairAction repair in scenario.teacherTruth.acceptableRepairs) {
      try {
        final CircuitState repaired = repair.apply(faulty);
        if (repaired == faulty) {
          issues.add(FaultScenarioValidationIssue('repair-no-op', 'Repair ${repair.id} did not change the circuit.'));
          continue;
        }
        final DcSolveResult repairedResult = _solverDC.solve(repaired, _topologyEngine.compile(repaired));
        if (repairedResult.status == DcSolveStatus.solved &&
            _criticalConditionsNormal(repaired) &&
            _rootCausesRemoved(scenario, repaired) &&
            faultyResult != null &&
            _electricalBehaviorChanged(faultyResult, repairedResult)) {
          repairable = true;
        }
      } catch (error) {
        issues.add(FaultScenarioValidationIssue('repair-error', 'Repair ${repair.id} failed: $error'));
      }
    }
    if (!repairable) {
      issues.add(const FaultScenarioValidationIssue('not-repairable', 'At least one reference repair must restore a solved functional circuit.'));
    }

    final FaultScenarioValidationStamp stamp = FaultScenarioValidationStamp(
      validatorVersion: validatorVersion,
      circuitSchemaVersion: CircuitState.currentSchemaVersion,
      contentDigestFnv1a64: _fnv1a64(scenario.canonicalPrivatePayload()),
    );
    return FaultScenarioValidationResult(
      scenarioId: scenario.id,
      issues: List<FaultScenarioValidationIssue>.unmodifiable(issues),
      stamp: stamp,
      repairable: repairable,
    );
  }

  static void _validateExpectedMeasurements(
    FaultScenarioDefinition scenario,
    DcSolveResult result,
    List<FaultScenarioValidationIssue> issues,
  ) {
    for (final ExpectedBranchMeasurement expected in scenario.teacherTruth.expectedMeasurements) {
      final matches = result.branchResults.where((DcBranchResult item) => item.id == expected.branchId).toList(growable: false);
      if (matches.length != 1 || matches.single.currentA == null) {
        issues.add(FaultScenarioValidationIssue('measurement-missing', 'Expected branch measurement ${expected.branchId} is unavailable.'));
        continue;
      }
      final double delta = (matches.single.currentA! - expected.currentA).abs();
      if (delta > math.max(expected.toleranceA, 1e-12)) {
        issues.add(FaultScenarioValidationIssue(
          'measurement-mismatch',
          '${expected.branchId} current ${matches.single.currentA} A differs from ${expected.currentA} A.',
        ));
      }
    }
  }

  static bool _faultIsMaterialized(FaultScenarioDefinition scenario) {
    for (final RootCause cause in scenario.teacherTruth.rootCauses) {
      switch (cause.kind) {
        case RootCauseKind.missingConnection:
          if (scenario.faultyCircuit.connections.any((Connection item) => item.id.value == cause.targetId)) return false;
          break;
        case RootCauseKind.componentOpen:
          final matches = scenario.faultyCircuit.components.where((ComponentInstance item) => item.id.value == cause.targetId);
          if (matches.length != 1 || matches.single.condition != ComponentCondition.openCircuit) return false;
          break;
      }
    }
    return true;
  }

  static bool _rootCausesRemoved(FaultScenarioDefinition scenario, CircuitState repaired) {
    for (final RootCause cause in scenario.teacherTruth.rootCauses) {
      switch (cause.kind) {
        case RootCauseKind.missingConnection:
          if (!repaired.connections.any((Connection item) => item.id.value == cause.targetId && item.enabled)) {
            return false;
          }
          break;
        case RootCauseKind.componentOpen:
          final matches = repaired.components.where((ComponentInstance item) => item.id.value == cause.targetId);
          if (matches.length != 1 || matches.single.condition != ComponentCondition.normal) return false;
          break;
      }
    }
    return true;
  }

  static bool _electricalBehaviorChanged(DcSolveResult before, DcSolveResult after) {
    final Map<String, double?> a = <String, double?>{for (final DcBranchResult branch in before.branchResults) branch.id: branch.currentA};
    for (final DcBranchResult branch in after.branchResults) {
      final double? previous = a[branch.id];
      final double? current = branch.currentA;
      if (previous != null && current != null && (previous - current).abs() > 1e-9) return true;
    }
    return false;
  }

  static bool _criticalConditionsNormal(CircuitState circuit) =>
      circuit.components.every((ComponentInstance item) => item.condition == ComponentCondition.normal) &&
      circuit.sources.every((SourceInstance item) => item.enabled);

  static bool _containsForbiddenExampleReference(String payload) {
    final String lower = payload.toLowerCase();
    const List<String> forbidden = <String>[
      'example' 'id',
      'example' '_id',
      'example' 'circuit',
    ];
    return forbidden.any(lower.contains);
  }

  static String _fnv1a64(String value) {
    final BigInt offset = BigInt.parse('cbf29ce484222325', radix: 16);
    final BigInt prime = BigInt.parse('100000001b3', radix: 16);
    final BigInt mask = BigInt.parse('ffffffffffffffff', radix: 16);
    BigInt hash = offset;
    for (final int byte in utf8.encode(value)) {
      hash = ((hash ^ BigInt.from(byte)) * prime) & mask;
    }
    return hash.toRadixString(16).padLeft(16, '0');
  }
}
