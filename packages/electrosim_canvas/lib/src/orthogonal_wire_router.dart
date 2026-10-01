import 'dart:ui';

import 'wire_geometry.dart';

enum WireRouteFailure {
  noCrossingFreeRoute,
}

final class WireRouteResult {
  const WireRouteResult._({
    required this.path,
    required this.failure,
  });

  factory WireRouteResult.resolved(OrthogonalWirePath path) {
    return WireRouteResult._(path: path, failure: null);
  }

  const WireRouteResult.unresolved(WireRouteFailure failure)
      : this._(path: null, failure: failure);

  final OrthogonalWirePath? path;
  final WireRouteFailure? failure;

  bool get isResolved => path != null;
}

abstract final class WireRouteSafety {
  static bool hasDifferentNetCrossing({
    required OrthogonalWirePath candidate,
    required List<OrthogonalWirePath> occupiedDifferentNetPaths,
  }) {
    for (final OrthogonalSegment candidateSegment in candidate.segments) {
      for (final OrthogonalWirePath occupied in occupiedDifferentNetPaths) {
        for (final OrthogonalSegment occupiedSegment in occupied.segments) {
          if (_segmentsConflict(candidateSegment, occupiedSegment)) {
            return true;
          }
        }
      }
    }
    return false;
  }

  static bool _segmentsConflict(
    OrthogonalSegment first,
    OrthogonalSegment second,
  ) {
    if (first.axis != second.axis) {
      return first.intersectionWith(second) != null;
    }

    if (first.axis == WireAxis.horizontal) {
      if (first.start.dy != second.start.dy) {
        return false;
      }
      return _rangesOverlap(first.minX, first.maxX, second.minX, second.maxX);
    }

    if (first.start.dx != second.start.dx) {
      return false;
    }
    return _rangesOverlap(first.minY, first.maxY, second.minY, second.maxY);
  }

  static bool _rangesOverlap(
    double firstMin,
    double firstMax,
    double secondMin,
    double secondMax,
  ) {
    return firstMax >= secondMin && secondMax >= firstMin;
  }
}

final class OrthogonalWireRouter {
  const OrthogonalWireRouter({
    required this.grid,
    required this.obstacleClearance,
    required this.envelopePadding,
    this.bendPenalty = 30,
  }) : assert(grid > 0),
       assert(obstacleClearance >= 0),
       assert(envelopePadding >= 0),
       assert(bendPenalty >= 0);

  final double grid;
  final double obstacleClearance;
  final double envelopePadding;
  final double bendPenalty;

  WireRouteResult route({
    required Offset start,
    required Offset end,
    List<RoutingObstacle> obstacles = const <RoutingObstacle>[],
    List<OrthogonalWirePath> occupiedDifferentNetPaths =
        const <OrthogonalWirePath>[],
  }) {
    if (start == end) {
      return const WireRouteResult.unresolved(
        WireRouteFailure.noCrossingFreeRoute,
      );
    }

    final List<RoutingObstacle> expandedObstacles = obstacles
        .map((RoutingObstacle obstacle) => obstacle.expanded(obstacleClearance))
        .toList(growable: false);

    final Rect envelope = Rect.fromLTRB(
      _min(start.dx, end.dx) - envelopePadding,
      _min(start.dy, end.dy) - envelopePadding,
      _max(start.dx, end.dx) + envelopePadding,
      _max(start.dy, end.dy) + envelopePadding,
    );

    final List<List<Offset>> candidatePoints = <List<Offset>>[];

    if (start.dx == end.dx || start.dy == end.dy) {
      candidatePoints.add(<Offset>[start, end]);
    } else {
      candidatePoints
        ..add(<Offset>[start, Offset(end.dx, start.dy), end])
        ..add(<Offset>[start, Offset(start.dx, end.dy), end]);
    }

    final List<double> horizontalChannels = <double>[
      _snap(envelope.top),
      _snap(envelope.bottom),
    ];
    final List<double> verticalChannels = <double>[
      _snap(envelope.left),
      _snap(envelope.right),
    ];

    for (final RoutingObstacle obstacle in expandedObstacles) {
      horizontalChannels
        ..add(_snap(obstacle.bounds.top - grid))
        ..add(_snap(obstacle.bounds.bottom + grid));
      verticalChannels
        ..add(_snap(obstacle.bounds.left - grid))
        ..add(_snap(obstacle.bounds.right + grid));
    }

    for (final OrthogonalWirePath occupied in occupiedDifferentNetPaths) {
      for (final OrthogonalSegment segment in occupied.segments) {
        horizontalChannels
          ..add(_snap(segment.minY - grid))
          ..add(_snap(segment.maxY + grid));
        verticalChannels
          ..add(_snap(segment.minX - grid))
          ..add(_snap(segment.maxX + grid));
      }
    }

    for (final double y in _dedupeSorted(horizontalChannels)) {
      if (y < envelope.top || y > envelope.bottom) {
        continue;
      }
      candidatePoints.add(
        <Offset>[
          start,
          Offset(start.dx, y),
          Offset(end.dx, y),
          end,
        ],
      );
    }

    for (final double x in _dedupeSorted(verticalChannels)) {
      if (x < envelope.left || x > envelope.right) {
        continue;
      }
      candidatePoints.add(
        <Offset>[
          start,
          Offset(x, start.dy),
          Offset(x, end.dy),
          end,
        ],
      );
    }

    OrthogonalWirePath? best;
    double? bestCost;

    for (final List<Offset> raw in candidatePoints) {
      final List<Offset> normalized = _normalize(raw);
      if (normalized.length < 2) {
        continue;
      }

      OrthogonalWirePath candidate;
      try {
        candidate = OrthogonalWirePath(points: normalized);
      } on ArgumentError {
        continue;
      }

      if (_hitsObstacle(candidate, expandedObstacles)) {
        continue;
      }
      if (WireRouteSafety.hasDifferentNetCrossing(
        candidate: candidate,
        occupiedDifferentNetPaths: occupiedDifferentNetPaths,
      )) {
        continue;
      }

      final double cost = _cost(candidate);
      if (bestCost == null || cost < bestCost) {
        best = candidate;
        bestCost = cost;
      }
    }

    if (best == null) {
      return const WireRouteResult.unresolved(
        WireRouteFailure.noCrossingFreeRoute,
      );
    }
    return WireRouteResult.resolved(best);
  }

  double _cost(OrthogonalWirePath path) {
    final double length = path.segments.fold<double>(
      0,
      (double sum, OrthogonalSegment segment) => sum + segment.length,
    );
    return length + path.bends.length * bendPenalty;
  }

  bool _hitsObstacle(
    OrthogonalWirePath path,
    List<RoutingObstacle> obstacles,
  ) {
    for (final OrthogonalSegment segment in path.segments) {
      for (final RoutingObstacle obstacle in obstacles) {
        if (_segmentHitsRect(segment, obstacle.bounds)) {
          return true;
        }
      }
    }
    return false;
  }

  static bool _segmentHitsRect(OrthogonalSegment segment, Rect rect) {
    if (segment.axis == WireAxis.horizontal) {
      final double y = segment.start.dy;
      if (y < rect.top || y > rect.bottom) {
        return false;
      }
      return segment.maxX >= rect.left && segment.minX <= rect.right;
    }

    final double x = segment.start.dx;
    if (x < rect.left || x > rect.right) {
      return false;
    }
    return segment.maxY >= rect.top && segment.minY <= rect.bottom;
  }

  double _snap(double value) => (value / grid).roundToDouble() * grid;

  static List<double> _dedupeSorted(List<double> values) {
    final List<double> sorted = <double>[...values]..sort();
    final List<double> result = <double>[];
    for (final double value in sorted) {
      if (result.isEmpty || result.last != value) {
        result.add(value);
      }
    }
    return result;
  }

  static List<Offset> _normalize(List<Offset> points) {
    final List<Offset> result = <Offset>[];
    for (final Offset point in points) {
      if (result.isEmpty || result.last != point) {
        result.add(point);
      }
    }

    var index = 1;
    while (index < result.length - 1) {
      final Offset before = result[index - 1];
      final Offset current = result[index];
      final Offset after = result[index + 1];
      final bool horizontal =
          before.dy == current.dy && current.dy == after.dy;
      final bool vertical =
          before.dx == current.dx && current.dx == after.dx;
      if (horizontal || vertical) {
        result.removeAt(index);
      } else {
        index++;
      }
    }
    return result;
  }

  static double _min(double a, double b) => a < b ? a : b;
  static double _max(double a, double b) => a > b ? a : b;
}
