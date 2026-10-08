import 'package:electrosim/runtime/electrosim_runtime_engine.dart';
import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:flutter_test/flutter_test.dart';

CircuitState _largeParallelCircuit(int count) {
  final Terminal positive = Terminal(id: TerminalId('source-p'), name: '+');
  final Terminal negative = Terminal(id: TerminalId('source-n'), name: '-');
  final List<ComponentInstance> components = <ComponentInstance>[];
  final List<Connection> wires = <Connection>[];
  for (var index = 0; index < count; index++) {
    final Terminal a = Terminal(id: TerminalId('r$index-a'), name: '1');
    final Terminal b = Terminal(id: TerminalId('r$index-b'), name: '2');
    components.add(ComponentInstance(
      id: ComponentId('r$index'),
      modelType: 'resistor',
      terminals: <Terminal>[a, b],
      parameters: const <String, Object?>{'resistanceOhm': 24000.0},
    ));
    wires.add(Connection(
      id: ConnectionId('pos-$index'),
      fromTerminalId: positive.id,
      toTerminalId: a.id,
    ));
    wires.add(Connection(
      id: ConnectionId('neg-$index'),
      fromTerminalId: b.id,
      toTerminalId: negative.id,
    ));
  }
  return CircuitState(
    circuitId: CircuitId('current-batch-400'),
    revision: 0,
    mode: ElectricalMode.dc,
    sources: <SourceInstance>[
      SourceInstance(
        id: SourceId('voltage'),
        modelType: 'dc_voltage_source',
        terminals: <Terminal>[positive, negative],
        parameters: const <String, Object?>{'voltageV': 24.0},
      ),
    ],
    components: components,
    connections: wires,
  );
}

void main() {
  test('AUDIT-400: 800 wire readings per snapshot are physical and reusable',
      () {
    final CircuitState circuit = _largeParallelCircuit(400);
    final ElectroSimRuntimeSnapshot snapshot =
        const ElectroSimRuntimeEngine().evaluate(circuit);
    expect(snapshot.solved, isTrue);
    final Stopwatch first = Stopwatch()..start();
    final List<ConnectionCurrentEvidence> measured = <ConnectionCurrentEvidence>[
      for (final Connection wire in circuit.connections)
        snapshot.connectionCurrentEvidence(wire),
    ];
    first.stop();
    final Stopwatch cached = Stopwatch()..start();
    for (var i = 0; i < circuit.connections.length; i++) {
      expect(snapshot.connectionCurrentEvidence(circuit.connections[i]),
          same(measured[i]));
    }
    cached.stop();
    expect(measured.length, 800);
    for (final ConnectionCurrentEvidence evidence in measured) {
      expect(evidence.directionKnown, isTrue);
      expect(evidence.magnitudeA, closeTo(0.001, 1e-6));
    }
    // Times are evidence, not a cross-platform release performance promise.
    print('AUDIT400_BATCH firstUs=${first.elapsedMicroseconds} '
          'cachedUs=${cached.elapsedMicroseconds} wires=${measured.length}');
  });
}
