import 'package:electrosim/runtime/electrosim_runtime_engine.dart';
import 'package:electrosim_scenarios/electrosim_scenarios.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final QualifiedCatalog catalog = buildF16QualifiedCatalog();
  const ElectroSimRuntimeEngine runtime = ElectroSimRuntimeEngine();

  test('F17-R2 every qualified healthy F16 example reaches a solved runtime state', () {
    expect(catalog.examples, isNotEmpty);
    for (final ExampleDefinition example in catalog.examples) {
      final ElectroSimRuntimeSnapshot snapshot = runtime.evaluate(example.circuit);
      expect(
        snapshot.solved,
        isTrue,
        reason: 'Healthy example ${example.id.value} must solve in application runtime.',
      );
      expect(snapshot.topology.circuitId, example.circuit.circuitId);
      expect(snapshot.dc.circuitRevision, example.circuit.revision);
    }
  });

  test('F17-R2 every qualified fault scenario is consumable by runtime without identity drift', () {
    expect(catalog.faultScenarios, isNotEmpty);
    for (final FaultScenarioDefinition scenario in catalog.faultScenarios) {
      final ElectroSimRuntimeSnapshot snapshot = runtime.evaluate(scenario.faultyCircuit);
      expect(snapshot.topology.circuitId, scenario.faultyCircuit.circuitId);
      expect(snapshot.topology.circuitRevision, scenario.faultyCircuit.revision);
      expect(snapshot.dc.circuitId, scenario.faultyCircuit.circuitId);
      expect(snapshot.dc.circuitRevision, scenario.faultyCircuit.revision);
      expect(snapshot.diagnostics.circuitId, scenario.faultyCircuit.circuitId);
      expect(snapshot.diagnostics.circuitRevision, scenario.faultyCircuit.revision);
    }
  });

  test('F17-R2 catalog remains signed before UI exposure', () {
    expect(catalog.allItemsSigned, isTrue);
  });
}
