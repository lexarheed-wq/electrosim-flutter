import 'package:electrosim_canvas/electrosim_canvas.dart';
import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:electrosim/f9_canvas_interaction.dart';

void main() {
  test('F9 router emits orthogonal display segments', () {
    final CircuitState circuit = CircuitState(
      circuitId: CircuitId('route-test'),
      revision: 1,
      mode: ElectricalMode.dc,
      components: <ComponentInstance>[
        ComponentInstance(
          id: ComponentId('a'),
          modelType: 'Résistance',
          terminals: <Terminal>[
            Terminal(
              id: TerminalId('a-in'),
              name: '1',
              role: TerminalRole.input,
            ),
            Terminal(
              id: TerminalId('a-out'),
              name: '2',
              role: TerminalRole.output,
            ),
          ],
        ),
        ComponentInstance(
          id: ComponentId('b'),
          modelType: 'Lampe',
          terminals: <Terminal>[
            Terminal(
              id: TerminalId('b-in'),
              name: '1',
              role: TerminalRole.input,
            ),
            Terminal(
              id: TerminalId('b-out'),
              name: '2',
              role: TerminalRole.output,
            ),
          ],
        ),
      ],
      connections: <Connection>[
        Connection(
          id: ConnectionId('wire-a'),
          fromTerminalId: TerminalId('a-out'),
          toTerminalId: TerminalId('b-in'),
        ),
      ],
    );
    final CircuitVisualLayout layout = CircuitVisualLayout(
      elementPositions: const <String, Offset>{
        'a': Offset(120, 100),
        'b': Offset(420, 260),
      },
    );

    final CircuitVisualLayout routed = F9OrthogonalRouter.reroute(
      circuit,
      layout,
    );
    final CircuitGeometryIndex geometry = CircuitGeometryIndex.build(
      circuit,
      routed,
    );
    final Offset start = geometry.terminalPositions[TerminalId('a-out')]!;
    final Offset end = geometry.terminalPositions[TerminalId('b-in')]!;
    final List<Offset> points = <Offset>[
      start,
      ...routed.routeFor('wire-a'),
      end,
    ];

    for (var i = 0; i < points.length - 1; i++) {
      final Offset a = points[i];
      final Offset b = points[i + 1];
      expect((a.dx - b.dx).abs() < 0.5 || (a.dy - b.dy).abs() < 0.5, isTrue);
    }
  });

  test('F9 viewport bounds keep some circuit visible', () {
    final CircuitState circuit = CircuitState(
      circuitId: CircuitId('bounds-test'),
      revision: 1,
      mode: ElectricalMode.dc,
      components: <ComponentInstance>[
        ComponentInstance(
          id: ComponentId('a'),
          modelType: 'Lampe',
          terminals: <Terminal>[
            Terminal(
              id: TerminalId('a-in'),
              name: '1',
              role: TerminalRole.input,
            ),
            Terminal(
              id: TerminalId('a-out'),
              name: '2',
              role: TerminalRole.output,
            ),
          ],
        ),
      ],
    );
    final CircuitVisualLayout layout = CircuitVisualLayout(
      elementPositions: const <String, Offset>{'a': Offset(200, 150)},
    );

    final Offset bounded = F9ViewportBounds.clampTranslation(
      circuit: circuit,
      layout: layout,
      viewportSize: const Size(600, 400),
      scale: 1,
      translation: const Offset(-10000, -10000),
    );

    expect(bounded.dx, greaterThan(-10000));
    expect(bounded.dy, greaterThan(-10000));
  });

  test('F9 router prefers the shortest one-bend path when unobstructed', () {
    final CircuitState circuit = CircuitState(
      circuitId: CircuitId('short-route-test'),
      revision: 1,
      mode: ElectricalMode.dc,
      components: <ComponentInstance>[
        ComponentInstance(
          id: ComponentId('a'),
          modelType: 'Résistance',
          terminals: <Terminal>[
            Terminal(
              id: TerminalId('a-in'),
              name: '1',
              role: TerminalRole.input,
            ),
            Terminal(
              id: TerminalId('a-out'),
              name: '2',
              role: TerminalRole.output,
            ),
          ],
        ),
        ComponentInstance(
          id: ComponentId('b'),
          modelType: 'Lampe',
          terminals: <Terminal>[
            Terminal(
              id: TerminalId('b-in'),
              name: '1',
              role: TerminalRole.input,
            ),
            Terminal(
              id: TerminalId('b-out'),
              name: '2',
              role: TerminalRole.output,
            ),
          ],
        ),
      ],
      connections: <Connection>[
        Connection(
          id: ConnectionId('wire-short'),
          fromTerminalId: TerminalId('a-out'),
          toTerminalId: TerminalId('b-in'),
        ),
      ],
    );
    final CircuitVisualLayout layout = CircuitVisualLayout(
      elementPositions: const <String, Offset>{
        'a': Offset(120, 100),
        'b': Offset(420, 260),
      },
    );

    final CircuitVisualLayout routed = F9OrthogonalRouter.reroute(
      circuit,
      layout,
    );
    expect(routed.routeFor('wire-short').length, lessThanOrEqualTo(1));
  });

  test(
    'F9 router keeps configured clearance from an intermediate component',
    () {
      final CircuitState circuit = CircuitState(
        circuitId: CircuitId('clearance-route-test'),
        revision: 1,
        mode: ElectricalMode.dc,
        components: <ComponentInstance>[
          ComponentInstance(
            id: ComponentId('a'),
            modelType: 'Résistance',
            terminals: <Terminal>[
              Terminal(
                id: TerminalId('a-in'),
                name: '1',
                role: TerminalRole.input,
              ),
              Terminal(
                id: TerminalId('a-out'),
                name: '2',
                role: TerminalRole.output,
              ),
            ],
          ),
          ComponentInstance(
            id: ComponentId('block'),
            modelType: 'Disjoncteur',
            terminals: <Terminal>[
              Terminal(
                id: TerminalId('block-in'),
                name: 'IN',
                role: TerminalRole.input,
              ),
              Terminal(
                id: TerminalId('block-out'),
                name: 'OUT',
                role: TerminalRole.output,
              ),
            ],
          ),
          ComponentInstance(
            id: ComponentId('b'),
            modelType: 'Lampe',
            terminals: <Terminal>[
              Terminal(
                id: TerminalId('b-in'),
                name: '1',
                role: TerminalRole.input,
              ),
              Terminal(
                id: TerminalId('b-out'),
                name: '2',
                role: TerminalRole.output,
              ),
            ],
          ),
        ],
        connections: <Connection>[
          Connection(
            id: ConnectionId('wire-clear'),
            fromTerminalId: TerminalId('a-out'),
            toTerminalId: TerminalId('b-in'),
          ),
        ],
      );
      final CircuitVisualLayout layout = CircuitVisualLayout(
        elementPositions: const <String, Offset>{
          'a': Offset(80, 180),
          'block': Offset(320, 180),
          'b': Offset(560, 180),
        },
      );

      final CircuitVisualLayout routed = F9OrthogonalRouter.reroute(
        circuit,
        layout,
      );
      final CircuitGeometryIndex geometry = CircuitGeometryIndex.build(
        circuit,
        routed,
      );
      final Offset start = geometry.terminalPositions[TerminalId('a-out')]!;
      final Offset end = geometry.terminalPositions[TerminalId('b-in')]!;
      final Rect blocked = geometry.elementRects['block']!.inflate(
        F9OrthogonalRouter.clearance - 0.5,
      );
      final List<Offset> points = <Offset>[
        start,
        ...routed.routeFor('wire-clear'),
        end,
      ];

      bool intersects(Rect rect, Offset first, Offset second) {
        if ((first.dx - second.dx).abs() < 0.5) {
          if (first.dx <= rect.left || first.dx >= rect.right) return false;
          final double top = first.dy < second.dy ? first.dy : second.dy;
          final double bottom = first.dy > second.dy ? first.dy : second.dy;
          return bottom > rect.top && top < rect.bottom;
        }
        if ((first.dy - second.dy).abs() < 0.5) {
          if (first.dy <= rect.top || first.dy >= rect.bottom) return false;
          final double left = first.dx < second.dx ? first.dx : second.dx;
          final double right = first.dx > second.dx ? first.dx : second.dx;
          return right > rect.left && left < rect.right;
        }
        return true;
      }

      for (var i = 0; i < points.length - 1; i++) {
        expect(intersects(blocked, points[i], points[i + 1]), isFalse);
      }
    },
  );

  test(
    'F9 viewport bounds remain recoverable at maximum zoom in every direction',
    () {
      final CircuitState circuit = CircuitState(
        circuitId: CircuitId('bounds-max-zoom'),
        revision: 1,
        mode: ElectricalMode.dc,
        components: <ComponentInstance>[
          ComponentInstance(
            id: ComponentId('a'),
            modelType: 'Lampe',
            terminals: <Terminal>[
              Terminal(
                id: TerminalId('a-in'),
                name: '1',
                role: TerminalRole.input,
              ),
              Terminal(
                id: TerminalId('a-out'),
                name: '2',
                role: TerminalRole.output,
              ),
            ],
          ),
          ComponentInstance(
            id: ComponentId('b'),
            modelType: 'Interrupteur',
            terminals: <Terminal>[
              Terminal(
                id: TerminalId('b-in'),
                name: '1',
                role: TerminalRole.input,
              ),
              Terminal(
                id: TerminalId('b-out'),
                name: '2',
                role: TerminalRole.output,
              ),
            ],
          ),
        ],
      );
      final CircuitVisualLayout layout = CircuitVisualLayout(
        elementPositions: const <String, Offset>{
          'a': Offset(120, 100),
          'b': Offset(520, 300),
        },
      );

      for (final Offset extreme in const <Offset>[
        Offset(-100000, -100000),
        Offset(100000, -100000),
        Offset(-100000, 100000),
        Offset(100000, 100000),
      ]) {
        final Offset bounded = F9ViewportBounds.clampTranslation(
          circuit: circuit,
          layout: layout,
          viewportSize: const Size(900, 600),
          scale: 4,
          translation: extreme,
        );
        expect(bounded.dx.abs(), lessThan(100000));
        expect(bounded.dy.abs(), lessThan(100000));
      }
    },
  );

  test(
    'F9 viewport bounds are stable when the circuit is smaller than the viewport',
    () {
      final CircuitState circuit = CircuitState(
        circuitId: CircuitId('bounds-small-circuit'),
        revision: 1,
        mode: ElectricalMode.dc,
        components: <ComponentInstance>[
          ComponentInstance(
            id: ComponentId('a'),
            modelType: 'Lampe',
            terminals: <Terminal>[
              Terminal(
                id: TerminalId('a-in'),
                name: '1',
                role: TerminalRole.input,
              ),
              Terminal(
                id: TerminalId('a-out'),
                name: '2',
                role: TerminalRole.output,
              ),
            ],
          ),
        ],
      );
      final CircuitVisualLayout layout = CircuitVisualLayout(
        elementPositions: const <String, Offset>{'a': Offset(200, 150)},
      );
      final Offset bounded = F9ViewportBounds.clampTranslation(
        circuit: circuit,
        layout: layout,
        viewportSize: const Size(1200, 800),
        scale: 0.35,
        translation: const Offset(99999, -99999),
      );
      expect(bounded.dx.isFinite, isTrue);
      expect(bounded.dy.isFinite, isTrue);
    },
  );
}
