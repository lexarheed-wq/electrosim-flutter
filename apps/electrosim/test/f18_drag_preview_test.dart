import 'dart:ui' show Offset, Size;

import 'package:electrosim/f18_drag_preview.dart';
import 'package:electrosim_canvas/electrosim_canvas.dart';
import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:flutter_test/flutter_test.dart';

ComponentInstance twoTerminal(String id) => ComponentInstance(
  id: ComponentId(id),
  modelType: 'resistor',
  terminals: <Terminal>[
    Terminal(id: TerminalId('$id-a'), name: 'A'),
    Terminal(id: TerminalId('$id-b'), name: 'B'),
  ],
);

void main() {
  test('disconnected drag preserves every existing wire route', () {
    final ComponentInstance a = twoTerminal('a');
    final ComponentInstance b = twoTerminal('b');
    final ComponentInstance moving = twoTerminal('moving');
    final CircuitState circuit = CircuitState(
      circuitId: CircuitId('drag-disconnected'),
      revision: 1,
      mode: ElectricalMode.dc,
      components: <ComponentInstance>[a, b, moving],
      connections: <Connection>[
        Connection(
          id: ConnectionId('wire-ab'),
          fromTerminalId: a.terminals[1].id,
          toTerminalId: b.terminals[0].id,
        ),
      ],
    );
    final CircuitVisualLayout layout = CircuitVisualLayout(
      elementPositions: const <String, Offset>{
        'a': Offset(100, 100),
        'b': Offset(500, 100),
        'moving': Offset(280, 360),
      },
      elementSizes: const <String, Size>{
        'a': Size(280, 110),
        'b': Size(280, 110),
        'moving': Size(280, 110),
      },
      wireRoutes: const <String, List<Offset>>{
        'wire-ab': <Offset>[Offset(180, 40), Offset(420, 40)],
      },
    );

    final F18DragSession session = F18DragSession.begin(
      circuit: circuit,
      baseLayout: layout,
      elementId: 'moving',
    );
    final CircuitVisualLayout preview = session.previewAt(
      const Offset(360, 420),
    );

    expect(preview.positionOf('moving'), const Offset(360, 420));
    expect(preview.wireRoutes, equals(layout.wireRoutes));
  });

  test('connected drag updates only directly attached wire previews', () {
    final ComponentInstance moving = twoTerminal('moving');
    final ComponentInstance target = twoTerminal('target');
    final ComponentInstance c = twoTerminal('c');
    final ComponentInstance d = twoTerminal('d');
    final CircuitState circuit = CircuitState(
      circuitId: CircuitId('drag-attached'),
      revision: 1,
      mode: ElectricalMode.dc,
      components: <ComponentInstance>[moving, target, c, d],
      connections: <Connection>[
        Connection(
          id: ConnectionId('wire-moving'),
          fromTerminalId: moving.terminals[1].id,
          toTerminalId: target.terminals[0].id,
        ),
        Connection(
          id: ConnectionId('wire-unrelated'),
          fromTerminalId: c.terminals[1].id,
          toTerminalId: d.terminals[0].id,
        ),
      ],
    );
    final CircuitVisualLayout layout = CircuitVisualLayout(
      elementPositions: const <String, Offset>{
        'moving': Offset(100, 100),
        'target': Offset(500, 300),
        'c': Offset(100, 600),
        'd': Offset(500, 600),
      },
      elementSizes: const <String, Size>{
        'moving': Size(280, 110),
        'target': Size(280, 110),
        'c': Size(280, 110),
        'd': Size(280, 110),
      },
      wireRoutes: const <String, List<Offset>>{
        'wire-moving': <Offset>[Offset(220, 120), Offset(380, 280)],
        'wire-unrelated': <Offset>[Offset(220, 540), Offset(380, 540)],
      },
    );

    final F18DragSession session = F18DragSession.begin(
      circuit: circuit,
      baseLayout: layout,
      elementId: 'moving',
    );
    final CircuitVisualLayout preview = session.previewAt(
      const Offset(220, 180),
    );

    expect(preview.positionOf('moving'), const Offset(220, 180));
    expect(
      preview.routeFor('wire-unrelated'),
      equals(layout.routeFor('wire-unrelated')),
    );
    expect(
      preview.routeFor('wire-moving'),
      isNot(equals(layout.routeFor('wire-moving'))),
    );
    expect(preview.routeFor('wire-moving').length, lessThanOrEqualTo(1));
  });

  test('200-element drag preview stays comfortably inside one frame', () {
    const int count = 200;
    final List<ComponentInstance> components = <ComponentInstance>[
      for (var i = 0; i < count; i++) twoTerminal('stress-$i'),
    ];
    final List<Connection> connections = <Connection>[
      for (var i = 0; i < count - 1; i++)
        Connection(
          id: ConnectionId('stress-wire-$i'),
          fromTerminalId: components[i].terminals[1].id,
          toTerminalId: components[i + 1].terminals[0].id,
        ),
    ];
    final CircuitState circuit = CircuitState(
      circuitId: CircuitId('drag-stress-200'),
      revision: 1,
      mode: ElectricalMode.dc,
      components: components,
      connections: connections,
    );
    final CircuitVisualLayout layout = CircuitVisualLayout(
      elementPositions: <String, Offset>{
        for (var i = 0; i < count; i++)
          components[i].id.value: Offset(
            100 + (i % 10) * 150.0,
            100 + (i ~/ 10) * 100.0,
          ),
      },
      wireRoutes: <String, List<Offset>>{
        for (final Connection connection in connections)
          connection.id.value: const <Offset>[],
      },
      defaultElementSize: const Size(92, 56),
    );

    final F18DragSession session = F18DragSession.begin(
      circuit: circuit,
      baseLayout: layout,
      elementId: 'stress-100',
    );

    for (var i = 0; i < 20; i++) {
      session.previewAt(Offset(400 + i.toDouble(), 500));
    }

    final List<int> samples = <int>[];
    for (var i = 0; i < 160; i++) {
      final Stopwatch stopwatch = Stopwatch()..start();
      session.previewAt(Offset(400 + i.toDouble(), 500 + (i % 7)));
      stopwatch.stop();
      samples.add(stopwatch.elapsedMicroseconds);
    }
    samples.sort();
    final int p95 = samples[((samples.length - 1) * .95).round()];
    // ignore: avoid_print
    print('CANVAS_PERF01_DRAG_P95_US:$p95');
    expect(
      p95,
      lessThan(8000),
      reason:
          '200-element pointer-move preview must leave headroom inside a 16.67 ms frame',
    );
  });

}
