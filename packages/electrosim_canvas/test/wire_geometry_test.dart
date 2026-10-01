import 'dart:ui' show Rect;

import 'package:electrosim_canvas/electrosim_canvas.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('OrthogonalWirePath', () {
    test('accepts horizontal and vertical segments only', () {
      final OrthogonalWirePath path = OrthogonalWirePath(
        points: const <Offset>[
          Offset(24, 24),
          Offset(120, 24),
          Offset(120, 144),
          Offset(264, 144),
        ],
      );

      expect(path.segments, hasLength(3));
      expect(path.segments[0].axis, WireAxis.horizontal);
      expect(path.segments[1].axis, WireAxis.vertical);
      expect(path.segments[2].axis, WireAxis.horizontal);
      expect(path.bends, const <Offset>[Offset(120, 24), Offset(120, 144)]);
    });

    test('rejects diagonal automatic geometry', () {
      expect(
        () => OrthogonalWirePath(
          points: const <Offset>[Offset(24, 24), Offset(48, 48)],
        ),
        throwsArgumentError,
      );
    });

    test('rejects zero-length segments', () {
      expect(
        () => OrthogonalWirePath(
          points: const <Offset>[Offset(24, 24), Offset(24, 24)],
        ),
        throwsArgumentError,
      );
    });
  });

  group('OrthogonalSegment intersection', () {
    test('detects perpendicular crossing', () {
      const OrthogonalSegment horizontal = OrthogonalSegment(
        start: Offset(24, 96),
        end: Offset(216, 96),
      );
      const OrthogonalSegment vertical = OrthogonalSegment(
        start: Offset(120, 24),
        end: Offset(120, 192),
      );

      expect(horizontal.intersectionWith(vertical), const Offset(120, 96));
    });

    test('does not report separated segments', () {
      const OrthogonalSegment horizontal = OrthogonalSegment(
        start: Offset(24, 96),
        end: Offset(96, 96),
      );
      const OrthogonalSegment vertical = OrthogonalSegment(
        start: Offset(120, 24),
        end: Offset(120, 192),
      );

      expect(horizontal.intersectionWith(vertical), isNull);
    });
  });

  test('routing obstacle expands by component keep-out', () {
    const RoutingObstacle obstacle = RoutingObstacle(
      bounds: Rect.fromLTWH(100, 100, 80, 60),
    );

    expect(
      obstacle.expanded(24).bounds,
      const Rect.fromLTWH(76, 76, 128, 108),
    );
  });
}
