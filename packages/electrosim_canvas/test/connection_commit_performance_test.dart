import 'dart:convert';

import 'package:electrosim_canvas/electrosim_canvas.dart';
import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:flutter_test/flutter_test.dart';

const engine = CircuitWireLayoutEngine(
  router: OrthogonalWireRouter(
    grid: 24,
    obstacleClearance: 24,
    envelopePadding: 120,
  ),
);

({CircuitState circuit, CircuitVisualLayout layout}) fixture(int count) {
  final components = <ComponentInstance>[];
  final connections = <Connection>[];
  final positions = <String, Offset>{};
  for (var i = 0; i < count; i++) {
    components.add(
      ComponentInstance(
        id: ComponentId('r$i'),
        modelType: 'resistor',
        parameters: const {'resistanceOhm': 100.0},
        terminals: [
          Terminal(id: TerminalId('r$i-a'), name: 'A'),
          Terminal(id: TerminalId('r$i-b'), name: 'B'),
        ],
      ),
    );
    positions['r$i'] = Offset(120 + (i % 2) * 400.0, 120 + (i ~/ 2) * 180.0);
    if (i.isOdd) {
      connections.add(
        Connection(
          id: ConnectionId('w${i ~/ 2}'),
          fromTerminalId: TerminalId('r${i - 1}-b'),
          toTerminalId: TerminalId('r$i-a'),
        ),
      );
    }
  }
  return (
    circuit: CircuitState(
      circuitId: CircuitId('commit-$count'),
      revision: 1,
      mode: ElectricalMode.dc,
      components: components,
      connections: connections,
    ),
    layout: CircuitVisualLayout(elementPositions: positions),
  );
}

void main() {
  for (final count in [30, 60, 100, 200]) {
    test('connection commit benchmark with $count components', () {
      final input = fixture(count);
      final existing = engine.routeAll(
        circuit: input.circuit,
        layout: input.layout,
      );
      final last = input.circuit.connections.last;
      final samples = <int>[];
      for (var i = 0; i < 8; i++) {
        final watch = Stopwatch()..start();
        final routed = engine.routeConnection(
          circuit: input.circuit,
          layout: existing,
          connectionId: last.id,
        );
        watch.stop();
        samples.add(watch.elapsedMicroseconds);
        final geometry = CircuitGeometryIndex.build(input.circuit, routed);
        expect(
          OrthogonalWirePath(
            points: [
              geometry.terminalPositions[last.fromTerminalId]!,
              ...routed.routeFor(last.id.value),
              geometry.terminalPositions[last.toTerminalId]!,
            ],
          ).segments,
          isNotEmpty,
        );
      }
      samples.sort();
      expect(
        samples[samples.length ~/ 2],
        lessThan(50000),
        reason:
            'Single-wire routing must not regress to a global three-pass search.',
      );
      // ignore: avoid_print
      print(
        'CONNECTION_COMMIT_PERF ${jsonEncode({'components': count, 'connections': input.circuit.connections.length, 'medianUs': samples[samples.length ~/ 2], 'maxUs': samples.last})}',
      );
    });
  }
}
