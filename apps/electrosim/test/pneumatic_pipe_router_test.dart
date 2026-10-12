import 'package:electrosim/pneumatics/pneumatic_pipe_router.dart';
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
