import 'dart:convert';

import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:electrosim_scenarios/electrosim_scenarios.dart';
import 'package:electrosim_solver_dc/electrosim_solver_dc.dart';
import 'package:electrosim_topology/electrosim_topology.dart';
import 'package:test/test.dart';

void main() {
  group('F11 FaultScenarioRepository', () {
    final FaultScenarioRepository repository = buildF11FaultScenarioRepository();
    const FaultScenarioValidator validator = FaultScenarioValidator();

    test('starts small with two autonomous fault scenarios', () {
      expect(repository.all, hasLength(2));
      expect(repository.all.map((FaultScenarioDefinition item) => item.id.value).toSet(), hasLength(2));
    });

    test('every published scenario validates and is repairable', () {
      final results = repository.validateAll();
      expect(results, hasLength(repository.all.length));
      expect(results.every((FaultScenarioValidationResult item) => item.isValid), isTrue);
      expect(results.every((FaultScenarioValidationResult item) => item.repairable), isTrue);
    });

    test('teacherTruth never leaks into student payload', () {
      for (final FaultScenarioDefinition scenario in repository.all) {
        final String payload = jsonEncode(scenario.studentPayload());
        expect(payload, isNot(contains('teacherTruth')));
        expect(payload, isNot(contains('rootCauses')));
        expect(payload, isNot(contains('expectedMeasurements')));
        expect(payload, isNot(contains('acceptableRepairs')));
        expect(payload.toLowerCase(), isNot(contains('example' 'id')));
      }
    });

    test('no scenario carries an example reference', () {
      for (final FaultScenarioDefinition scenario in repository.all) {
        expect(scenario.canonicalPrivatePayload().toLowerCase(), isNot(contains('example' 'id')));
        expect(scenario.canonicalPrivatePayload().toLowerCase(), isNot(contains('example' 'circuit')));
      }
    });

    test('validation stamps are deterministic unsigned 64-bit hex', () {
      for (final FaultScenarioDefinition scenario in repository.all) {
        expect(scenario.validationStamp, isNotNull);
        expect(scenario.validationStamp!.validatorVersion, FaultScenarioValidator.validatorVersion);
        expect(scenario.validationStamp!.contentDigestFnv1a64, matches(RegExp(r'^[0-9a-f]{16}$')));
        final first = validator.validate(scenario).stamp.contentDigestFnv1a64;
        final second = validator.validate(scenario).stamp.contentDigestFnv1a64;
        expect(second, first);
      }
    });

    test('reference repairs are real CircuitState mutations and solve electrically', () {
      const TopologyEngine topology = TopologyEngine();
      const SolverDC solver = SolverDC();
      for (final FaultScenarioDefinition scenario in repository.all) {
        final CircuitState faulty = scenario.faultyCircuit;
        final RepairAction repair = scenario.teacherTruth.acceptableRepairs.first;
        final CircuitState repaired = repair.apply(faulty);
        expect(repaired.revision, faulty.revision + 1);
        expect(repaired, isNot(faulty));
        final result = solver.solve(repaired, topology.compile(repaired));
        expect(result.status, DcSolveStatus.solved);
        expect(repaired.components.every((ComponentInstance item) => item.condition == ComponentCondition.normal), isTrue);
      }
    });
  });
}
