import 'example_definition.dart';
import 'fault_scenario_definition.dart';

final class V2ProductLibrary {
  V2ProductLibrary({
    required this.version,
    required List<ExampleDefinition> schemas,
    required List<FaultScenarioDefinition> faultScenarios,
  }) : schemas = List<ExampleDefinition>.unmodifiable(schemas),
       faultScenarios = List<FaultScenarioDefinition>.unmodifiable(
         faultScenarios,
       );

  final String version;
  final List<ExampleDefinition> schemas;
  final List<FaultScenarioDefinition> faultScenarios;

  bool get allValidated =>
      schemas.every((ExampleDefinition item) => item.validationStamp != null) &&
      faultScenarios.every(
        (FaultScenarioDefinition item) => item.validationStamp != null,
      );

  bool get allNativeV2 =>
      schemas.every(
        (ExampleDefinition item) =>
            item.metadata['origin'] == 'v2-native' &&
            item.circuit.metadata['origin'] == 'v2-native',
      ) &&
      faultScenarios.every(
        (FaultScenarioDefinition item) =>
            item.faultyCircuit.metadata['origin'] == 'v2-native',
      );
}

/// Product libraries intentionally restart empty after CORE-UNIFY.
///
/// Historical bootstrap examples and fault scenarios used component instances
/// created before the canonical physics/runtime contracts and must not leak
/// into the product. New libraries will be authored from the current palette.
V2ProductLibrary buildV2ProductLibrary() => V2ProductLibrary(
  version: '3.0.0-core-unify',
  schemas: const <ExampleDefinition>[],
  faultScenarios: const <FaultScenarioDefinition>[],
);
