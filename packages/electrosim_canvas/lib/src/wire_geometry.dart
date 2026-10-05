import 'dart:ui';

enum WireAxis { horizontal, vertical }

final class OrthogonalSegment {
  const OrthogonalSegment({required this.start, required this.end});

  final Offset start;
  final Offset end;

  bool get isHorizontal => start.dy == end.dy && start.dx != end.dx;
  bool get isVertical => start.dx == end.dx && start.dy != end.dy;

  WireAxis get axis {
    if (isHorizontal) {
      return WireAxis.horizontal;
    }
    if (isVertical) {
      return WireAxis.vertical;
    }
    throw ArgumentError.value(
      <Offset>[start, end],
      'segment',
      'Orthogonal segment must be non-zero and axis-aligned.',
    );
  }

  double get length => (end - start).distance;

  double get minX => start.dx < end.dx ? start.dx : end.dx;
  double get maxX => start.dx > end.dx ? start.dx : end.dx;
  double get minY => start.dy < end.dy ? start.dy : end.dy;
  double get maxY => start.dy > end.dy ? start.dy : end.dy;

  Offset? intersectionWith(OrthogonalSegment other) {
    final WireAxis thisAxis = axis;
    final WireAxis otherAxis = other.axis;

    if (thisAxis == otherAxis) {
      return null;
    }

    final OrthogonalSegment horizontal = thisAxis == WireAxis.horizontal
        ? this
        : other;
    final OrthogonalSegment vertical = thisAxis == WireAxis.vertical
        ? this
        : other;

    final double x = vertical.start.dx;
    final double y = horizontal.start.dy;

    final bool onHorizontal = x >= horizontal.minX && x <= horizontal.maxX;
    final bool onVertical = y >= vertical.minY && y <= vertical.maxY;
    if (!onHorizontal || !onVertical) {
      return null;
    }
    return Offset(x, y);
  }
}

final class OrthogonalWirePath {
  OrthogonalWirePath({required List<Offset> points})
    : points = List<Offset>.unmodifiable(points) {
    if (points.length < 2) {
      throw ArgumentError.value(
        points,
        'points',
        'An orthogonal wire path requires at least two points.',
      );
    }

    final List<OrthogonalSegment> built = <OrthogonalSegment>[];
    for (var index = 0; index < points.length - 1; index++) {
      final OrthogonalSegment segment = OrthogonalSegment(
        start: points[index],
        end: points[index + 1],
      );
      // Accessing axis validates that the segment is non-zero and orthogonal.
      segment.axis;
      built.add(segment);
    }
    segments = List<OrthogonalSegment>.unmodifiable(built);

    final List<Offset> bendPoints = <Offset>[];
    for (var index = 1; index < built.length; index++) {
      if (built[index - 1].axis != built[index].axis) {
        bendPoints.add(points[index]);
      }
    }
    bends = List<Offset>.unmodifiable(bendPoints);
  }

  final List<Offset> points;
  late final List<OrthogonalSegment> segments;
  late final List<Offset> bends;
}

final class RoutingObstacle {
  const RoutingObstacle({required this.bounds});

  final Rect bounds;

  RoutingObstacle expanded(double margin) {
    if (margin < 0) {
      throw ArgumentError.value(
        margin,
        'margin',
        'Margin must be non-negative.',
      );
    }
    return RoutingObstacle(
      bounds: Rect.fromLTRB(
        bounds.left - margin,
        bounds.top - margin,
        bounds.right + margin,
        bounds.bottom + margin,
      ),
    );
  }
}
