import 'dart:convert';

import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:electrosim_scenarios/electrosim_scenarios.dart';
import 'package:electrosim_solver_dc/electrosim_solver_dc.dart';
import 'package:electrosim_topology/electrosim_topology.dart';
import 'package:test/test.dart';

void main() {
  group('F16 qualified catalog batch', () {
    final QualifiedCatalog catalog = buildF16QualifiedCatalog();

    test('catalog grows progressively from F10/F11 baselines', () {
      expect(catalog.catalogVersion, '16.1.0');
      expect(catalog.examples, hasLength(5));
      expect(catalog.faultScenarios, hasLength(3));
      expect(catalog.allItemsSigned, isTrue);
    });

    test('all examples remain healthy and validator-green', () {
      const ExampleValidator validator = ExampleValidator();
      for (final ExampleDefinition example in catalog.examples) {
        expect(example.circuit.metadata['healthy'], isTrue);
        expect(
          example.circuit.components.every(
            (ComponentInstance item) => item.condition == ComponentCondition.normal,
          ),
          isTrue,
        );
        expect(validator.validate(example).isValid, isTrue);
      }
    });

    test('all fault scenarios are autonomous, private and repairable', () {
      const FaultScenarioValidator validator = FaultScenarioValidator();
      for (final FaultScenarioDefinition scenario in catalog.faultScenarios) {
        final String student = jsonEncode(scenario.studentPayload()).toLowerCase();
        expect(student, isNot(contains('teachertruth')));
        expect(student, isNot(contains('rootcauses')));
        expect(student, isNot(contains('acceptablerepairs')));
        expect(student, isNot(contains('example' 'id')));
        final FaultScenarioValidationResult result = validator.validate(scenario);
        expect(result.isValid, isTrue);
        expect(result.repairable, isTrue);
      }
    });

    test('catalog has unique ids across each content family', () {
      expect(
        catalog.examples.map((ExampleDefinition item) => item.id.value).toSet(),
        hasLength(catalog.examples.length),
      );
      expect(
        catalog.faultScenarios
            .map((FaultScenarioDefinition item) => item.id.value)
            .toSet(),
        hasLength(catalog.faultScenarios.length),
      );
    });

    test('new batch reference repairs restore solved circuits', () {
      const TopologyEngine topology = TopologyEngine();
      const SolverDC solver = SolverDC();
      final FaultScenarioDefinition scenario = catalog.faultScenarios
          .singleWhere((FaultScenarioDefinition item) => item.id.value == 'FAULT-DC-003');
      final CircuitState repaired =
          scenario.teacherTruth.acceptableRepairs.first.apply(scenario.faultyCircuit);
      final DcSolveResult result = solver.solve(repaired, topology.compile(repaired));
      expect(result.status, DcSolveStatus.solved);
      expect(repaired.revision, scenario.faultyCircuit.revision + 1);
    });

    test('no legacy content marker is published', () {
      for (final ExampleDefinition example in catalog.examples) {
        expect(example.canonicalPayload().toLowerCase(), isNot(contains('legacy')));
      }
      for (final FaultScenarioDefinition scenario in catalog.faultScenarios) {
        expect(
          scenario.canonicalPrivatePayload().toLowerCase(),
          isNot(contains('legacy')),
        );
      }
    });
  });
}
