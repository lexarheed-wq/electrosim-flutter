import 'dart:convert';

import 'package:electrosim_scenarios/electrosim_scenarios.dart';
import 'package:electrosim_solver_dc/electrosim_solver_dc.dart';
import 'package:electrosim_topology/electrosim_topology.dart';
import 'package:test/test.dart';

void main() {
  group('F18-G10 pure V2 product libraries', () {
    final V2ProductLibrary library = buildV2ProductLibrary();

    test('product library is native V2 and validator-signed', () {
      expect(library.version, '2.0.0');
      expect(library.schemas, hasLength(2));
      expect(library.faultScenarios, hasLength(2));
      expect(library.allValidated, isTrue);
      expect(library.allNativeV2, isTrue);
    });

    test('product IDs do not reuse bootstrap fixture IDs', () {
      final QualifiedCatalog fixtures = buildF16QualifiedCatalog();
      final Set<String> fixtureSchemaIds = fixtures.examples
          .map((ExampleDefinition item) => item.id.value)
          .toSet();
      final Set<String> fixtureFaultIds = fixtures.faultScenarios
          .map((FaultScenarioDefinition item) => item.id.value)
          .toSet();

      expect(
        library.schemas
            .map((ExampleDefinition item) => item.id.value)
            .where(fixtureSchemaIds.contains),
        isEmpty,
      );
      expect(
        library.faultScenarios
            .map((FaultScenarioDefinition item) => item.id.value)
            .where(fixtureFaultIds.contains),
        isEmpty,
      );
    });

    test('healthy product schemas solve with expected currents', () {
      const TopologyEngine topology = TopologyEngine();
      const SolverDC solver = SolverDC();

      final ExampleDefinition lamp = library.schemas.singleWhere(
        (ExampleDefinition item) => item.id.value == 'V2-SCHEMA-DC-LAMP-01',
      );
      final ExampleDefinition motor = library.schemas.singleWhere(
        (ExampleDefinition item) => item.id.value == 'V2-SCHEMA-DC-MOTOR-01',
      );

      final DcSolveResult lampResult = solver.solve(
        lamp.circuit,
        topology.compile(lamp.circuit),
      );
      final DcSolveResult motorResult = solver.solve(
        motor.circuit,
        topology.compile(motor.circuit),
      );

      expect(lampResult.isSolved, isTrue);
      expect(
        lampResult.branch('component:v2sl1-lamp').currentA,
        closeTo(1.0, 1e-9),
      );
      expect(motorResult.isSolved, isTrue);
      expect(
        motorResult.branch('component:v2sm1-motor').currentA,
        closeTo(3.0, 1e-9),
      );
    });

    test('fault scenarios are autonomous and keep teacher truth private', () {
      const FaultScenarioValidator validator = FaultScenarioValidator();

      for (final FaultScenarioDefinition scenario in library.faultScenarios) {
        final FaultScenarioValidationResult result = validator.validate(
          scenario,
        );
        expect(result.isValid, isTrue);
        expect(result.repairable, isTrue);

        final String student = jsonEncode(scenario.studentPayload())
            .toLowerCase();
        final String privatePayload = scenario.canonicalPrivatePayload()
            .toLowerCase();

        expect(student, isNot(contains('teachertruth')));
        expect(student, isNot(contains('rootcauses')));
        expect(student, isNot(contains('acceptablerepairs')));
        expect(privatePayload, isNot(contains('exampleid')));
        expect(privatePayload, isNot(contains('example_id')));
        expect(privatePayload, isNot(contains('examplecircuit')));
      }
    });

    test('fault circuits are independent from healthy product circuits', () {
      final Set<String> healthyCircuitIds = library.schemas
          .map((ExampleDefinition item) => item.circuit.circuitId.value)
          .toSet();
      final Set<String> healthyComponentIds = library.schemas
          .expand((ExampleDefinition item) => item.circuit.components)
          .map((item) => item.id.value)
          .toSet();

      for (final FaultScenarioDefinition scenario in library.faultScenarios) {
        expect(
          healthyCircuitIds,
          isNot(contains(scenario.faultyCircuit.circuitId.value)),
        );
        expect(
          scenario.faultyCircuit.components
              .map((item) => item.id.value)
              .where(healthyComponentIds.contains),
          isEmpty,
        );
      }
    });
  });
}
