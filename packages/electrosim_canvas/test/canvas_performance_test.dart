import 'dart:convert';
import 'dart:ui' as ui;

import 'package:electrosim_canvas/electrosim_canvas.dart';
import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('nominal scene painter p95 stays inside a 60 fps frame budget', () {
    final CircuitState circuit = _nominalCircuit();
    final CircuitVisualLayout layout = _nominalLayout(circuit);
    final ViewportController viewport = ViewportController(
      scale: 0.9,
      translation: const ui.Offset(24, 28),
    );
    final CircuitScenePainter painter = CircuitScenePainter(
      circuit: circuit,
      layout: layout,
      viewport: viewport,
    );
    const ui.Size size = ui.Size(1280, 800);

    void renderOnce() {
      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final ui.Canvas canvas = ui.Canvas(recorder);
      painter.paint(canvas, size);
      final ui.Picture picture = recorder.endRecording();
      picture.dispose();
    }

    for (var i = 0; i < 12; i++) {
      renderOnce();
    }

    final List<int> samples = <int>[];
    for (var i = 0; i < 120; i++) {
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
      'phase': 'F8',
      'sceneElements': circuit.components.length + circuit.sources.length,
      'sceneConnections': circuit.connections.length,
      'iterations': samples.length,
      'medianMicroseconds': median,
      'p95Microseconds': p95,
      'maxMicroseconds': maximum,
      'frameBudgetMicroseconds': 16667,
    };
    // Gate parser consumes this exact prefix.
    // ignore: avoid_print
    print('F8_PERF_JSON:${jsonEncode(result)}');
    expect(p95, lessThan(16667));
  });
}

CircuitState _nominalCircuit() {
  final List<ComponentInstance> components = <ComponentInstance>[];
  final List<Connection> connections = <Connection>[];
  for (var i = 0; i < 24; i++) {
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
        modelType: i.isEven ? 'Resistor' : 'Switch',
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
    circuitId: CircuitId('f8-performance'),
    revision: 1,
    mode: ElectricalMode.dc,
    components: components,
    connections: connections,
  );
}

CircuitVisualLayout _nominalLayout(CircuitState circuit) {
  final Map<String, ui.Offset> positions = <String, ui.Offset>{};
  for (var i = 0; i < circuit.components.length; i++) {
    final int column = i % 6;
    final int row = i ~/ 6;
    positions[circuit.components[i].id.value] = ui.Offset(
      130 + column * 180,
      120 + row * 150,
    );
  }
  return CircuitVisualLayout(elementPositions: positions);
}
