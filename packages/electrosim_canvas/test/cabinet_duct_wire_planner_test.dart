import 'dart:ui';
import 'package:electrosim_canvas/electrosim_canvas.dart';
import 'package:flutter_test/flutter_test.dart';

CabinetFixture duct(String id, Rect bounds) =>
    CabinetFixture(id: id, kind: CabinetFixtureKind.wireDuct, bounds: bounds);
void main() {
  const a = Offset(50, -50), b = Offset(250, 250);
  final h = duct('h', const Rect.fromLTWH(0, 0, 240, 40));
  final v = duct('v', const Rect.fromLTWH(200, 0, 40, 300));
  test('end-to-corner joint stays in connected duct rectangles', () {
    final cabinet = CabinetLayout([
      h,
      duct('corner', const Rect.fromLTWH(240, 40, 40, 260)),
    ]);
    const end = Offset(310, 250);
    final route = CabinetDuctWirePlanner.route(
      start: a,
      end: end,
      cabinet: cabinet,
    )!;
    // Crossing the right end of h must first reach the shared corner.
    expect(route, contains(const Offset(240, 20)));
    expect(route, contains(const Offset(240, 40)));
    expect(route, contains(const Offset(260, 40)));
  });
  test(
    'joined perpendicular ducts preserve endpoints and deterministic centerlines',
    () {
      final route = CabinetDuctWirePlanner.route(
        start: a,
        end: b,
        cabinet: CabinetLayout([h, v]),
      )!;
      expect(route, contains(const Offset(220, 20)));
      expect(route, contains(const Offset(220, 250)));
      expect(
        CabinetDuctWirePlanner.route(
          start: a,
          end: b,
          cabinet: CabinetLayout([v, h]),
        ),
        route,
      );
      final full = [a, ...route, b];
      expect(full.first, a);
      expect(full.last, b);
      for (var i = 1; i < full.length; i++) {
        expect(
          full[i].dx == full[i - 1].dx || full[i].dy == full[i - 1].dy,
          isTrue,
        );
      }
    },
  );
  test('perpendicular ducts joined at their rectangle boundaries connect', () {
    final route = CabinetDuctWirePlanner.route(
      start: a,
      end: b,
      cabinet: CabinetLayout([
        h,
        duct('v', const Rect.fromLTWH(200, 40, 40, 260)),
      ]),
    )!;
    expect(route, contains(const Offset(220, 20)));
    expect(route, contains(const Offset(220, 250)));
  });
  test('disconnected nearest ducts reject routing', () {
    expect(
      CabinetDuctWirePlanner.route(
        start: a,
        end: b,
        cabinet: CabinetLayout([
          h,
          duct('v', const Rect.fromLTWH(300, 100, 40, 300)),
        ]),
      ),
      isNull,
    );
  });
  test('corner contact keeps every network segment inside the duct union', () {
    final bounds = [
      const Rect.fromLTWH(0, 0, 240, 40),
      const Rect.fromLTWH(240, 40, 40, 260),
    ];
    const start = Offset(50, 20), end = Offset(260, 250);
    final route = CabinetDuctWirePlanner.route(
      start: start,
      end: end,
      cabinet: CabinetLayout([duct('h', bounds[0]), duct('v', bounds[1])]),
    );
    expect(route, isNotNull);
    final points = [start, ...route!, end];
    for (var i = 1; i < points.length; i++) {
      final a = points[i - 1], b = points[i];
      expect(a.dx == b.dx || a.dy == b.dy, isTrue);
      // Split each segment at every rectangle boundary; testing each interval
      // midpoint proves that even a short excursion outside the union fails.
      final vertical = a.dx == b.dx;
      final lo = vertical ? a.dy : a.dx;
      final hi = vertical ? b.dy : b.dx;
      final cuts = <double>[0, 1];
      for (final rect in bounds) {
        for (final edge
            in vertical ? [rect.top, rect.bottom] : [rect.left, rect.right]) {
          final t = (edge - lo) / (hi - lo);
          if (t > 0 && t < 1) cuts.add(t);
        }
      }
      cuts.sort();
      for (var j = 1; j < cuts.length; j++) {
        final point = Offset.lerp(a, b, (cuts[j - 1] + cuts[j]) / 2)!;
        expect(
          bounds.any(
            (r) =>
                point.dx >= r.left &&
                point.dx <= r.right &&
                point.dy >= r.top &&
                point.dy <= r.bottom,
          ),
          isTrue,
          reason: 'Network segment $a → $b exits the duct union at $point',
        );
      }
    }
  });
  test('device blocking duct centerline rejects the route', () {
    expect(
      CabinetDuctWirePlanner.route(
        start: a,
        end: b,
        cabinet: CabinetLayout([h, v]),
        obstacles: [const Rect.fromLTWH(100, 0, 30, 40)],
      ),
      isNull,
    );
  });
  test(
    'lead chooses an unobstructed elbow and rejects both blocked elbows',
    () {
      final cabinet = CabinetLayout([h]);
      const start = Offset(-50, -50), end = Offset(150, -50);
      const block = Rect.fromLTWH(-60, -10, 20, 40);
      final route = CabinetDuctWirePlanner.route(
        start: start,
        end: end,
        cabinet: cabinet,
        obstacles: [block],
      );
      expect(route, isNotNull);
      expect(
        CabinetDuctWirePlanner.isClear(
          [start, ...route!, end],
          obstacles: [block],
        ),
        isTrue,
      );
      expect(
        CabinetDuctWirePlanner.route(
          start: start,
          end: end,
          cabinet: cabinet,
          obstacles: [block, const Rect.fromLTWH(-30, -60, 20, 20)],
        ),
        isNull,
      );
    },
  );
  test(
    'collision validator allows boundary travel but rejects interior travel',
    () {
      const r = Rect.fromLTWH(0, 0, 100, 100);
      expect(
        CabinetDuctWirePlanner.isClear(
          [const Offset(-10, 0), const Offset(110, 0)],
          obstacles: [r],
        ),
        isTrue,
      );
      expect(
        CabinetDuctWirePlanner.isClear(
          [const Offset(-10, 50), const Offset(110, 50)],
          obstacles: [r],
        ),
        isFalse,
      );
    },
  );
}
