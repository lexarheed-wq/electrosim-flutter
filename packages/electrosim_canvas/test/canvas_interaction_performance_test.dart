import 'dart:ui' as ui;

import 'package:electrosim_canvas/electrosim_canvas.dart';
import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final int count in <int>[25, 50, 100, 200]) {
    test('CANVAS-PERF03 prepared terminal hover remains sub-frame for $count components', () {
      final CircuitState circuit = _circuit(count);
      final CircuitVisualLayout layout = _layout(circuit);
      const HitTestEngine engine = HitTestEngine();
      final HitTestSession session = engine.prepare(circuit: circuit, layout: layout);
      final List<ui.Offset> terminals =
          session.geometry.terminalPositions.values.toList(growable: false);
      final Stopwatch sw = Stopwatch()..start();
      for (var round = 0; round < 80; round++) {
        for (var i = 0; i < terminals.length; i += 4) {
          engine.hitTestTerminalPrepared(
            worldPoint: terminals[i] + const ui.Offset(1, 1),
            session: session,
            viewportScale: 1,
          );
        }
      }
      sw.stop();
      final int calls = 80 * ((terminals.length + 3) ~/ 4);
      final double averageUs = sw.elapsedMicroseconds / calls;
      // Wide enough for shared CI jitter, strict enough to prevent rebuilding
      // full scene geometry in the pointer hot path.
      expect(averageUs, lessThan(1500.0));
    });
  }
}

CircuitState _circuit(int count) {
  final List<ComponentInstance> components = <ComponentInstance>[];
  for (var i = 0; i < count; i++) {
    components.add(ComponentInstance(
      id: ComponentId('c$i'),
      modelType: 'resistor',
      terminals: <Terminal>[
        Terminal(id: TerminalId('c$i-a'), name: 'A'),
        Terminal(id: TerminalId('c$i-b'), name: 'B'),
      ],
      parameters: const <String,Object?>{'resistanceOhm':100.0},
    ));
  }
  return CircuitState(
    circuitId: CircuitId('perf-$count'),
    revision: 0,
    mode: ElectricalMode.dc,
    components: components,
  );
}

CircuitVisualLayout _layout(CircuitState circuit) {
  final Map<String, ui.Offset> positions = <String, ui.Offset>{};
  for (var i = 0; i < circuit.components.length; i++) {
    positions[circuit.components[i].id.value] =
        ui.Offset(80 + (i % 10) * 120, 80 + (i ~/ 10) * 90);
  }
  return CircuitVisualLayout(elementPositions: positions);
}
