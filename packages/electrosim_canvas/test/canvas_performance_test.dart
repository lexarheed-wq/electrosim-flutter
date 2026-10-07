import 'dart:convert';
import 'dart:ui' as ui;

import 'package:electrosim_canvas/electrosim_canvas.dart';
import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final int elementCount in <int>[25, 50, 100, 200]) {
    test(
      'scene painter p95 stays inside 60 fps budget with $elementCount elements',
      () {
        final CircuitState circuit = _nominalCircuit(elementCount);
        final CircuitVisualLayout layout = _nominalLayout(circuit);
        final ViewportController viewport = ViewportController(
          scale: 0.72,
          translation: const ui.Offset(24, 28),
        );
        final CircuitScenePainter painter = CircuitScenePainter(
          circuit: circuit,
          layout: layout,
          viewport: viewport,
        );
        const ui.Size size = ui.Size(1440, 900);

        void renderOnce() {
          final ui.PictureRecorder recorder = ui.PictureRecorder();
          final ui.Canvas canvas = ui.Canvas(recorder);
          painter.paint(canvas, size);
          final ui.Picture picture = recorder.endRecording();
          picture.dispose();
        }

        for (var i = 0; i < 8; i++) {
          renderOnce();
        }

        final List<int> samples = <int>[];
        for (var i = 0; i < 80; i++) {
          final Stopwatch stopwatch = Stopwatch()..start();
          renderOnce();
          stopwatch.stop();
          samples.add(stopwatch.elapsedMicroseconds);
        }
        samples.sort();
        final int median = samples[samples.length ~/ 2];
        final int p95 = samples[((samples.length - 1) * 0.95).round()];
        final int maximum = samples.last;
        final Map<String, Object> result = <String, Object>{
          'phase': 'CANVAS-PERF01',
          'sceneElements': circuit.components.length,
          'sceneConnections': circuit.connections.length,
          'iterations': samples.length,
          'medianMicroseconds': median,
          'p95Microseconds': p95,
          'maxMicroseconds': maximum,
          'frameBudgetMicroseconds': 16667,
        };
        // Gate parser consumes this exact prefix.
        // ignore: avoid_print
        print('CANVAS_PERF01_JSON:${jsonEncode(result)}');
        expect(
          p95,
          lessThan(16667),
          reason:
              '$elementCount element scene must retain a 60 fps paint budget',
        );
      },
    );
  }
}

CircuitState _nominalCircuit(int elementCount) {
  final List<ComponentInstance> components = <ComponentInstance>[];
  final List<Connection> connections = <Connection>[];
  for (var i = 0; i < elementCount; i++) {
    final Terminal a = Terminal(
      id: TerminalId('c$i-a'),
      name: 'A',
      role: TerminalRole.input,
    );
    final Terminal b = Terminal(
      id: TerminalId('c$i-b'),
      name: 'B',
      role: TerminalRole.output,
    );
    components.add(
      ComponentInstance(
        id: ComponentId('component-$i'),
        modelType: i.isEven ? 'resistor' : 'switch',
        terminals: <Terminal>[a, b],
      ),
    );
  }
  for (var i = 0; i < components.length - 1; i++) {
    connections.add(
      Connection(
        id: ConnectionId('wire-$i'),
        fromTerminalId: components[i].terminals[1].id,
        toTerminalId: components[i + 1].terminals[0].id,
      ),
    );
  }
  return CircuitState(
    circuitId: CircuitId('canvas-perf-$elementCount'),
    revision: 1,
    mode: ElectricalMode.dc,
    components: components,
    connections: connections,
  );
}

CircuitVisualLayout _nominalLayout(CircuitState circuit) {
  final Map<String, ui.Offset> positions = <String, ui.Offset>{};
  const int columns = 10;
  for (var i = 0; i < circuit.components.length; i++) {
    final int column = i % columns;
    final int row = i ~/ columns;
    positions[circuit.components[i].id.value] = ui.Offset(
      90 + column * 140,
      90 + row * 105,
    );
  }
  return CircuitVisualLayout(
    elementPositions: positions,
    defaultElementSize: const ui.Size(92, 56),
  );
}
