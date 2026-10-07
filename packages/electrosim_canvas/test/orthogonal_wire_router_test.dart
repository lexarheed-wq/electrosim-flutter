import 'dart:ui' show Rect;

import 'package:electrosim_canvas/electrosim_canvas.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const OrthogonalWireRouter router = OrthogonalWireRouter(
    grid: 24,
    obstacleClearance: 24,
    envelopePadding: 96,
  );

  test('uses a direct straight route when it is clean', () {
    final WireRouteResult result = router.route(
      start: const Offset(24, 120),
      end: const Offset(312, 120),
    );

    expect(result.isResolved, isTrue);
    expect(result.path!.points, const <Offset>[
      Offset(24, 120),
      Offset(312, 120),
    ]);
  });

  test('detours orthogonally around a component obstacle', () {
    final WireRouteResult result = router.route(
      start: const Offset(24, 120),
      end: const Offset(312, 120),
      obstacles: const <RoutingObstacle>[
        RoutingObstacle(bounds: Rect.fromLTWH(120, 72, 72, 96)),
      ],
    );

    expect(result.isResolved, isTrue);
    expect(
      result.path!.segments.every(
        (s) => s.axis == WireAxis.horizontal || s.axis == WireAxis.vertical,
      ),
      isTrue,
    );
    expect(
      result.path!.segments.any(
        (segment) => segment.isHorizontal && segment.start.dy != 120,
      ),
      isTrue,
    );
  });

  test('routes around an occupied different-net path without crossing it', () {
    final OrthogonalWirePath occupied = OrthogonalWirePath(
      points: const <Offset>[Offset(168, 24), Offset(168, 168)],
    );

    final WireRouteResult result = router.route(
      start: const Offset(24, 120),
      end: const Offset(312, 120),
      occupiedDifferentNetPaths: <OrthogonalWirePath>[occupied],
    );

    expect(result.isResolved, isTrue);
    expect(
      WireRouteSafety.hasDifferentNetCrossing(
        candidate: result.path!,
        occupiedDifferentNetPaths: <OrthogonalWirePath>[occupied],
      ),
      isFalse,
    );
  });

  test(
    'detours beyond a long finite conductor barrier instead of refusing a valid connection',
    () {
      final OrthogonalWirePath barrier = OrthogonalWirePath(
        points: const <Offset>[Offset(168, -500), Offset(168, 500)],
      );

      final WireRouteResult result = router.route(
        start: const Offset(24, 120),
        end: const Offset(312, 120),
        occupiedDifferentNetPaths: <OrthogonalWirePath>[barrier],
      );

      expect(result.isResolved, isTrue);
      expect(
        WireRouteSafety.hasDifferentNetCrossing(
          candidate: result.path!,
          occupiedDifferentNetPaths: <OrthogonalWirePath>[barrier],
        ),
        isFalse,
      );
      expect(
        result.path!.points.any(
          (Offset point) => point.dy < -500 || point.dy > 500,
        ),
        isTrue,
        reason:
            'A finite existing net must be bypassed using free workspace rather than treated as an infinite wall.',
      );
    },
  );

  test('routes a staggered corridor with a valid orthogonal detour', () {
    const OrthogonalWireRouter mazeRouter = OrthogonalWireRouter(
      grid: 24,
      obstacleClearance: 24,
      envelopePadding: 96,
    );

    final WireRouteResult result = mazeRouter.route(
      start: const Offset(24, 120),
      end: const Offset(312, 120),
      obstacles: const <RoutingObstacle>[
        RoutingObstacle(bounds: Rect.fromLTWH(96, -24, 24, 144)),
        RoutingObstacle(bounds: Rect.fromLTWH(216, 120, 24, 144)),
      ],
    );

    expect(result.isResolved, isTrue);
    expect(result.path!.bends.length, greaterThanOrEqualTo(2));
    expect(
      result.path!.segments.every(
        (OrthogonalSegment segment) =>
            segment.axis == WireAxis.horizontal ||
            segment.axis == WireAxis.vertical,
      ),
      isTrue,
    );
  });


  test(
    'uses an explicit bridged crossing only when a different-net barrier cannot be bypassed',
    () {
      final OrthogonalWirePath closedBarrier = OrthogonalWirePath(
        points: const <Offset>[
          Offset(0, 0),
          Offset(240, 0),
          Offset(240, 240),
          Offset(0, 240),
          Offset(0, 0),
        ],
      );

      final WireRouteResult result = router.route(
        start: const Offset(120, 120),
        end: const Offset(360, 120),
        occupiedDifferentNetPaths: <OrthogonalWirePath>[closedBarrier],
      );

      expect(result.isResolved, isTrue);
      expect(result.usesBridgedCrossing, isTrue);
      expect(
        WireRouteSafety.countPerpendicularCrossings(
          candidate: result.path!,
          occupiedDifferentNetPaths: <OrthogonalWirePath>[closedBarrier],
        ),
        greaterThan(0),
      );
      expect(
        WireRouteSafety.hasCollinearOverlap(
          candidate: result.path!,
          occupiedDifferentNetPaths: <OrthogonalWirePath>[closedBarrier],
        ),
        isFalse,
      );
    },
  );

  test('routing is deterministic for identical inputs', () {
    const List<RoutingObstacle> obstacles = <RoutingObstacle>[
      RoutingObstacle(bounds: Rect.fromLTWH(120, 72, 72, 96)),
    ];

    final WireRouteResult first = router.route(
      start: const Offset(24, 120),
      end: const Offset(312, 120),
      obstacles: obstacles,
    );
    final WireRouteResult second = router.route(
      start: const Offset(24, 120),
      end: const Offset(312, 120),
      obstacles: obstacles,
    );

    expect(first.isResolved, isTrue);
    expect(second.path!.points, first.path!.points);
  });
}
