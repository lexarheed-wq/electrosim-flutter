import 'example_definition.dart';
import 'fault_scenario_definition.dart';
import 'v2_product_examples.dart';
import 'v2_product_faults.dart';

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

V2ProductLibrary buildV2ProductLibrary() {
  final examples = buildV2ProductExampleRepository().all;
  final faults = buildV2ProductFaultRepository().all;

  return V2ProductLibrary(
    version: '2.0.0',
    schemas: examples,
    faultScenarios: faults,
  );
}
