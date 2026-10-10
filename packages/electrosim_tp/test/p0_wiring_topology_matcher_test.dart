import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:electrosim_scenarios/electrosim_scenarios.dart';
import 'package:electrosim_tp/src/wiring_topology_matcher.dart';
import 'package:test/test.dart';

void main() {
  final CircuitState reference = buildF10ExampleRepository().all.first.circuit;
  test('P0 exact reference topology is accepted', () {
    expect(WiringTopologyMatcher.equivalent(reference, reference), isTrue);
  });

  test('P0 equal wire/component counts cannot hide wrong connections', () {
    final original = reference.connections;
    final wrong = CircuitState(
      circuitId: reference.circuitId,
      revision: reference.revision + 1,
      mode: reference.mode,
      components: reference.components,
      sources: reference.sources,
      connections: <Connection>[
        original.first,
        Connection(
          id: original.last.id,
          fromTerminalId: original.last.fromTerminalId,
          toTerminalId: original.first.fromTerminalId,
        ),
      ],
    );
    expect(wrong.connections.length, reference.connections.length);
    expect(WiringTopologyMatcher.equivalent(reference, wrong), isFalse);
  });

  test('P0 extra or missing components never match', () {
    final circuit = CircuitState(
      circuitId: reference.circuitId,
      revision: 1,
      mode: reference.mode,
      sources: reference.sources,
      connections: const <Connection>[],
    );
    expect(WiringTopologyMatcher.equivalent(reference, circuit), isFalse);
  });
}
