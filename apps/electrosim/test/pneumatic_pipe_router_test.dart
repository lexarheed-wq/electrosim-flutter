import 'dart:math' as math;

import 'package:electrosim/pneumatics/pneumatic_pipe_router.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const Rect source = Rect.fromLTWH(60, 95, 170, 140);
  const Rect valve = Rect.fromLTWH(780, 95, 170, 140);
  const Rect cylinder = Rect.fromLTWH(60, 305, 170, 140);
  const Rect blocker = Rect.fromLTWH(300, 280, 170, 140);

  test('R6/L+M no pipe goes through any intermediate component box', () {
    final List<Offset>? result = PneumaticPipeRouter.route(
      start: const Offset(145, 218),
      end: const Offset(175, 428),
      fromTile: source,
      toTile: cylinder,
      tiles: const <Rect>[source, valve, cylinder, blocker],
    );
    expect(result, isNotNull);
    expect(result!.first, const Offset(145, 218));
    expect(result.last, const Offset(175, 428));
    for (int i = 1; i < result.length; i++) {
      final Offset a = result[i - 1];
      final Offset b = result[i];
      expect(a.dx == b.dx || a.dy == b.dy, isTrue);
      for (final Rect box in const <Rect>[valve, blocker]) {
        if (a.dy == b.dy) {
          expect(
            a.dy > box.top &&
                a.dy < box.bottom &&
                a.dx < box.right &&
                b.dx > box.left,
            isFalse,
          );
        }
      }
    }
  });

  test('R6/L+M top escape recovers a blocked lower port stem', () {
    const Rect lowerBlocker = Rect.fromLTWH(115, 238, 60, 80);
    final List<Offset>? route = PneumaticPipeRouter.route(
      start: const Offset(145, 218),
      end: const Offset(835, 218),
      fromTile: source,
      toTile: valve,
      tiles: const <Rect>[source, valve, lowerBlocker],
    );
    expect(route, isNotNull);
    expect(route!.first, const Offset(145, 218));
    expect(route.last, const Offset(835, 218));
    expect(route[1].dy, lessThan(source.top));
    for (int i = 1; i < route.length; i++) {
      final Offset a = route[i - 1];
      final Offset b = route[i];
      expect(a.dx == b.dx || a.dy == b.dy, isTrue);
      if (a.dx == b.dx) {
        expect(
          a.dx > lowerBlocker.left &&
              a.dx < lowerBlocker.right &&
              math.min(a.dy, b.dy) < lowerBlocker.bottom &&
              math.max(a.dy, b.dy) > lowerBlocker.top,
          isFalse,
        );
      } else {
        expect(
          a.dy > lowerBlocker.top &&
              a.dy < lowerBlocker.bottom &&
              math.min(a.dx, b.dx) < lowerBlocker.right &&
              math.max(a.dx, b.dx) > lowerBlocker.left,
          isFalse,
        );
      }
    }
  });

  test('R6/L+M deterministic route and ports remain physically identical', () {
    List<Offset>? connect() => PneumaticPipeRouter.route(
      start: const Offset(835, 218),
      end: const Offset(175, 428),
      fromTile: valve,
      toTile: cylinder,
      tiles: const <Rect>[source, valve, cylinder, blocker],
    );
    expect(connect(), connect());
    expect(connect()!.first, const Offset(835, 218));
    expect(connect()!.last, const Offset(175, 428));
  });

  test('R6/L+M no route is invented if another device encloses the port', () {
    final List<Offset>? result = PneumaticPipeRouter.route(
      start: const Offset(145, 218),
      end: const Offset(175, 428),
      fromTile: source,
      toTile: cylinder,
      tiles: const <Rect>[
        source,
        valve,
        cylinder,
        Rect.fromLTWH(110, 195, 80, 85),
      ],
    );
    expect(result, isNull);
  });

  test('R6/L+M orphan port anchors fail closed', () {
    List<Offset>? connect(Offset start, Offset end) =>
        PneumaticPipeRouter.route(
          start: start,
          end: end,
          fromTile: source,
          toTile: valve,
          tiles: const <Rect>[source, valve],
        );
    expect(connect(const Offset(59, 218), const Offset(835, 218)), isNull);
    expect(connect(const Offset(145, 218), const Offset(951, 218)), isNull);
    expect(
      connect(const Offset(double.nan, 218), const Offset(835, 218)),
      isNull,
    );
    expect(
      connect(const Offset(145, 218), const Offset(double.infinity, 218)),
      isNull,
    );
  });

  test('R6/L+M invalid footprint fails closed', () {
    final List<Offset>? route = PneumaticPipeRouter.route(
      start: const Offset(145, 218),
      end: const Offset(835, 218),
      fromTile: source,
      toTile: valve,
      tiles: const <Rect>[
        source,
        valve,
        Rect.fromLTWH(320, 260, double.nan, 140),
      ],
    );
    expect(route, isNull);
  });

  test('R6/L+M 400-device orthogonal pipe microbenchmark', () {
    final List<Rect> devices = <Rect>[
      for (int row = 0; row < 20; row++)
        for (int col = 0; col < 20; col++)
          Rect.fromLTWH(col * 210.0, row * 180.0, 170, 140),
    ];
    int resolved = 0;
    final Stopwatch timer = Stopwatch()..start();
    for (int row = 0; row < 20; row++) {
      for (int col = 0; col < 19; col++) {
        final Rect origin = devices[row * 20 + col];
        final Rect destination = devices[row * 20 + col + 1];
        final Offset start = Offset(origin.left + 85, origin.top + 123);
        final Offset end = Offset(destination.left + 85, destination.top + 123);
        final List<Offset>? path = PneumaticPipeRouter.route(
          start: start,
          end: end,
          fromTile: origin,
          toTile: destination,
          tiles: devices,
        );
        expect(path, isNotNull);
        expect(path!.first, start);
        expect(path.last, end);
        resolved++;
      }
    }
    timer.stop();
    debugPrint(
      'R6LMN_DEVELOPMENT_ROUTING_BENCHMARK '
      'activeTiles=${devices.length} connectedPipes=$resolved '
      'durationMicroseconds=${timer.elapsedMicroseconds}',
    );
    expect(resolved, 380);
    // This structural microbenchmark is not release-frame PERF-01 evidence.
  });

  test('R6/L+M uses a clear lane instead of crossing an existing hose', () {
    // A direct lane at y=257 is slightly shorter but crosses this existing
    // vertical hose. The unobstructed y=281 lane must take precedence.
    final List<Offset>? route = PneumaticPipeRouter.route(
      start: const Offset(145, 218),
      end: const Offset(835, 218),
      fromTile: source,
      toTile: valve,
      tiles: const <Rect>[source, valve],
      previousRoutes: const <List<Offset>>[
        <Offset>[Offset(500, 240), Offset(500, 274)],
      ],
    );
    expect(route, isNotNull);
    expect(route!.first, const Offset(145, 218));
    expect(route.last, const Offset(835, 218));
    for (int i = 1; i < route.length; i++) {
      final Offset a = route[i - 1];
      final Offset b = route[i];
      expect(a.dx == b.dx || a.dy == b.dy, isTrue);
      if (a.dy == b.dy) {
        final double left = math.min(a.dx, b.dx);
        final double right = math.max(a.dx, b.dx);
        expect(
          a.dy > 240 && a.dy < 274 && left < 500 && right > 500,
          isFalse,
          reason: 'The path must bypass the existing vertical hose',
        );
      }
    }
  });

  test('R6/L+M reserved lanes are deterministic for adjacent circuits', () {
    final List<Offset> first = PneumaticPipeRouter.route(
      start: const Offset(145, 218),
      end: const Offset(835, 218),
      fromTile: source,
      toTile: valve,
      tiles: const <Rect>[source, valve],
    )!;
    final List<Offset>? second = PneumaticPipeRouter.route(
      start: const Offset(155, 218),
      end: const Offset(845, 218),
      fromTile: source,
      toTile: valve,
      tiles: const <Rect>[source, valve],
      previousRoutes: <List<Offset>>[first],
    );
    expect(second, isNotNull);
    expect(second!.first, const Offset(155, 218));
    expect(second.last, const Offset(845, 218));
    expect(second, isNot(first));
  });
}
