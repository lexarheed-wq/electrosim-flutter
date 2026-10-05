import 'dart:math';
import 'dart:ui' show Offset, Rect;

import 'package:electrosim_canvas/electrosim_canvas.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const OrthogonalWireRouter router = OrthogonalWireRouter(
    grid: 24,
    obstacleClearance: 24,
    envelopePadding: 120,
  );

  test('router is deterministic across 100 seeded obstacle fixtures', () {
    for (var seed = 0; seed < 100; seed++) {
      final Random random = Random(seed);
      final Offset start = Offset(24, 48 + 24.0 * random.nextInt(8));
      final Offset end = Offset(480, 48 + 24.0 * random.nextInt(8));

      final List<RoutingObstacle> obstacles = <RoutingObstacle>[];
      for (var index = 0; index < 4; index++) {
        final double left = 120 + 48.0 * index;
        final double top = 24.0 * random.nextInt(9);
        final double height = 48 + 24.0 * random.nextInt(4);
        obstacles.add(
          RoutingObstacle(bounds: Rect.fromLTWH(left, top, 24, height)),
        );
      }

      final WireRouteResult first = router.route(
        start: start,
        end: end,
        obstacles: obstacles,
      );
      final WireRouteResult second = router.route(
        start: start,
        end: end,
        obstacles: obstacles,
      );

      expect(
        second.isResolved,
        first.isResolved,
        reason: 'seed=$seed resolution must be deterministic',
      );
      expect(
        second.failure,
        first.failure,
        reason: 'seed=$seed failure must be deterministic',
      );

      if (!first.isResolved) {
        continue;
      }

      expect(
        second.path!.points,
        first.path!.points,
        reason: 'seed=$seed points must be deterministic',
      );
      expect(
        first.path!.segments.every(
          (OrthogonalSegment segment) =>
              segment.axis == WireAxis.horizontal ||
              segment.axis == WireAxis.vertical,
        ),
        isTrue,
        reason: 'seed=$seed must remain orthogonal',
      );
    }
  });

  test('different-net barriers are never crossed in 60 seeded fixtures', () {
    for (var seed = 1000; seed < 1060; seed++) {
      final Random random = Random(seed);
      final double barrierX = 144 + 24.0 * random.nextInt(6);
      final double gapTop = 48 + 24.0 * random.nextInt(5);
      final double gapHeight = 48;

      final OrthogonalWirePath upperBarrier = OrthogonalWirePath(
        points: <Offset>[Offset(barrierX, -240), Offset(barrierX, gapTop)],
      );
      final OrthogonalWirePath lowerBarrier = OrthogonalWirePath(
        points: <Offset>[
          Offset(barrierX, gapTop + gapHeight),
          Offset(barrierX, 480),
        ],
      );
      final List<OrthogonalWirePath> occupied = <OrthogonalWirePath>[
        upperBarrier,
        lowerBarrier,
      ];

      final WireRouteResult result = router.route(
        start: const Offset(24, 120),
        end: const Offset(480, 120),
        occupiedDifferentNetPaths: occupied,
      );

      if (!result.isResolved) {
        expect(result.failure, WireRouteFailure.noCrossingFreeRoute);
        continue;
      }

      expect(
        WireRouteSafety.hasDifferentNetCrossing(
          candidate: result.path!,
          occupiedDifferentNetPaths: occupied,
        ),
        isFalse,
        reason: 'seed=$seed must never cross a different net',
      );
    }
  });

  test(
    'resolved route rerouting is stable when reused as a visual constraint',
    () {
      final WireRouteResult first = router.route(
        start: const Offset(24, 120),
        end: const Offset(480, 120),
        obstacles: const <RoutingObstacle>[
          RoutingObstacle(bounds: Rect.fromLTWH(144, 72, 48, 96)),
          RoutingObstacle(bounds: Rect.fromLTWH(264, 120, 48, 96)),
        ],
      );

      expect(first.isResolved, isTrue);

      final WireRouteResult second = router.route(
        start: const Offset(24, 120),
        end: const Offset(480, 120),
        obstacles: const <RoutingObstacle>[
          RoutingObstacle(bounds: Rect.fromLTWH(144, 72, 48, 96)),
          RoutingObstacle(bounds: Rect.fromLTWH(264, 120, 48, 96)),
        ],
      );

      expect(second.path!.points, first.path!.points);
    },
  );
}
