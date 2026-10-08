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

/// Clean native V2 wave rebuilt on CORE-UNIFY canonical contracts.
/// No V1 drawings, scenarios or fixture references enter the product.
V2ProductLibrary buildV2ProductLibrary() => V2ProductLibrary(
  version: '3.1.0-core-unify',
  schemas: buildV2ProductExampleRepository().all,
  faultScenarios: buildV2ProductFaultRepository().all,
);
