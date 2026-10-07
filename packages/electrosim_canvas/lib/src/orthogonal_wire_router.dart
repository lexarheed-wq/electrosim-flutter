import 'dart:ui';

import 'wire_geometry.dart';

enum WireRouteFailure { noCrossingFreeRoute }

final class WireRouteResult {
  const WireRouteResult._({
    required this.path,
    required this.failure,
    required this.usesBridgedCrossing,
  });

  factory WireRouteResult.resolved(
    OrthogonalWirePath path, {
    bool usesBridgedCrossing = false,
  }) => WireRouteResult._(
    path: path,
    failure: null,
    usesBridgedCrossing: usesBridgedCrossing,
  );

  const WireRouteResult.unresolved(WireRouteFailure failure)
    : this._(path: null, failure: failure, usesBridgedCrossing: false);

  final OrthogonalWirePath? path;
  final WireRouteFailure? failure;
  final bool usesBridgedCrossing;

  bool get isResolved => path != null;
}

abstract final class WireRouteSafety {
  static bool hasDifferentNetCrossing({
    required OrthogonalWirePath candidate,
    required List<OrthogonalWirePath> occupiedDifferentNetPaths,
  }) =>
      countPerpendicularCrossings(
            candidate: candidate,
            occupiedDifferentNetPaths: occupiedDifferentNetPaths,
          ) >
          0 ||
      hasCollinearOverlap(
        candidate: candidate,
        occupiedDifferentNetPaths: occupiedDifferentNetPaths,
      );

  static int countPerpendicularCrossings({
    required OrthogonalWirePath candidate,
    required List<OrthogonalWirePath> occupiedDifferentNetPaths,
  }) {
    var count = 0;
    for (final OrthogonalSegment candidateSegment in candidate.segments) {
      for (final OrthogonalWirePath occupied in occupiedDifferentNetPaths) {
        for (final OrthogonalSegment occupiedSegment in occupied.segments) {
          if (candidateSegment.axis == occupiedSegment.axis) continue;
          if (candidateSegment.intersectionWith(occupiedSegment) != null) {
            count++;
          }
        }
      }
    }
    return count;
  }

  static bool hasCollinearOverlap({
    required OrthogonalWirePath candidate,
    required List<OrthogonalWirePath> occupiedDifferentNetPaths,
  }) {
    for (final OrthogonalSegment candidateSegment in candidate.segments) {
      for (final OrthogonalWirePath occupied in occupiedDifferentNetPaths) {
        for (final OrthogonalSegment occupiedSegment in occupied.segments) {
          if (_hasPositiveCollinearOverlap(candidateSegment, occupiedSegment)) {
            return true;
          }
        }
      }
    }
    return false;
  }

  static bool _hasPositiveCollinearOverlap(
    OrthogonalSegment first,
    OrthogonalSegment second,
  ) {
    if (first.axis != second.axis) return false;
    const double epsilon = 0.001;
    if (first.axis == WireAxis.horizontal) {
      if ((first.start.dy - second.start.dy).abs() > epsilon) return false;
      final double overlap =
          _min(first.maxX, second.maxX) - _max(first.minX, second.minX);
      return overlap > epsilon;
    }
    if ((first.start.dx - second.start.dx).abs() > epsilon) return false;
    final double overlap =
        _min(first.maxY, second.maxY) - _max(first.minY, second.minY);
    return overlap > epsilon;
  }

  static double _min(double a, double b) => a < b ? a : b;
  static double _max(double a, double b) => a > b ? a : b;
}

final class OrthogonalWireRouter {
  const OrthogonalWireRouter({
    required this.grid,
    required this.obstacleClearance,
    required this.envelopePadding,
    this.bendPenalty = 30,
    this.crossingPenalty = 600,
  }) : assert(grid > 0),
       assert(obstacleClearance >= 0),
       assert(envelopePadding >= 0),
       assert(bendPenalty >= 0),
       assert(crossingPenalty > 0);

  final double grid;
  final double obstacleClearance;
  final double envelopePadding;
  final double bendPenalty;
  final double crossingPenalty;

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
    final Rect envelope = _routingEnvelope(
      start: start,
      end: end,
      obstacles: expandedObstacles,
      occupied: occupiedDifferentNetPaths,
    );
    final List<List<Offset>> candidates = _candidatePolylines(
      start: start,
      end: end,
      envelope: envelope,
      obstacles: expandedObstacles,
      occupied: occupiedDifferentNetPaths,
    );

    final OrthogonalWirePath? clean = _bestCandidate(
      candidates,
      obstacles: expandedObstacles,
      occupiedDifferentNetPaths: occupiedDifferentNetPaths,
      allowBridgedCrossings: false,
    );
    if (clean != null) return WireRouteResult.resolved(clean);

    final OrthogonalWirePath? cleanAStar = _routeManhattanAStar(
      start: start,
      end: end,
      envelope: envelope,
      obstacles: expandedObstacles,
      occupiedDifferentNetPaths: occupiedDifferentNetPaths,
      allowBridgedCrossings: false,
    );
    if (cleanAStar != null) return WireRouteResult.resolved(cleanAStar);

    final OrthogonalWirePath? bridged = _bestCandidate(
      candidates,
      obstacles: expandedObstacles,
      occupiedDifferentNetPaths: occupiedDifferentNetPaths,
      allowBridgedCrossings: true,
    );
    if (bridged != null) {
      return WireRouteResult.resolved(
        bridged,
        usesBridgedCrossing: WireRouteSafety.countPerpendicularCrossings(
              candidate: bridged,
              occupiedDifferentNetPaths: occupiedDifferentNetPaths,
            ) >
            0,
      );
    }

    final OrthogonalWirePath? bridgedAStar = _routeManhattanAStar(
      start: start,
      end: end,
      envelope: envelope,
      obstacles: expandedObstacles,
      occupiedDifferentNetPaths: occupiedDifferentNetPaths,
      allowBridgedCrossings: true,
    );
    if (bridgedAStar != null) {
      return WireRouteResult.resolved(
        bridgedAStar,
        usesBridgedCrossing: WireRouteSafety.countPerpendicularCrossings(
              candidate: bridgedAStar,
              occupiedDifferentNetPaths: occupiedDifferentNetPaths,
            ) >
            0,
      );
    }

    return const WireRouteResult.unresolved(
      WireRouteFailure.noCrossingFreeRoute,
    );
  }

  Rect _routingEnvelope({
    required Offset start,
    required Offset end,
    required List<RoutingObstacle> obstacles,
    required List<OrthogonalWirePath> occupied,
  }) {
    Rect bounds = Rect.fromLTRB(
      _min(start.dx, end.dx),
      _min(start.dy, end.dy),
      _max(start.dx, end.dx),
      _max(start.dy, end.dy),
    );
    for (final RoutingObstacle obstacle in obstacles) {
      bounds = bounds.expandToInclude(obstacle.bounds);
    }
    for (final OrthogonalWirePath path in occupied) {
      for (final Offset point in path.points) {
        bounds = bounds.expandToInclude(
          Rect.fromLTWH(point.dx, point.dy, 0, 0),
        );
      }
    }
    return bounds.inflate(envelopePadding);
  }

  List<List<Offset>> _candidatePolylines({
    required Offset start,
    required Offset end,
    required Rect envelope,
    required List<RoutingObstacle> obstacles,
    required List<OrthogonalWirePath> occupied,
  }) {
    final List<List<Offset>> candidates = <List<Offset>>[];
    if (start.dx == end.dx || start.dy == end.dy) {
      candidates.add(<Offset>[start, end]);
    } else {
      candidates
        ..add(<Offset>[start, Offset(end.dx, start.dy), end])
        ..add(<Offset>[start, Offset(start.dx, end.dy), end]);
    }

    final List<double> horizontalChannels = <double>[
      _snap(envelope.top),
      _snap(envelope.bottom),
      _snap((start.dy + end.dy) / 2),
    ];
    final List<double> verticalChannels = <double>[
      _snap(envelope.left),
      _snap(envelope.right),
      _snap((start.dx + end.dx) / 2),
    ];

    for (final RoutingObstacle obstacle in obstacles) {
      horizontalChannels
        ..add(_snap(obstacle.bounds.top - grid))
        ..add(_snap(obstacle.bounds.bottom + grid));
      verticalChannels
        ..add(_snap(obstacle.bounds.left - grid))
        ..add(_snap(obstacle.bounds.right + grid));
    }
    for (final OrthogonalWirePath path in occupied) {
      for (final OrthogonalSegment segment in path.segments) {
        horizontalChannels
          ..add(_snap(segment.minY - grid))
          ..add(_snap(segment.maxY + grid));
        verticalChannels
          ..add(_snap(segment.minX - grid))
          ..add(_snap(segment.maxX + grid));
      }
    }

    for (final double y in _dedupeSorted(horizontalChannels)) {
      if (y < envelope.top || y > envelope.bottom) continue;
      candidates.add(<Offset>[
        start,
        Offset(start.dx, y),
        Offset(end.dx, y),
        end,
      ]);
    }
    for (final double x in _dedupeSorted(verticalChannels)) {
      if (x < envelope.left || x > envelope.right) continue;
      candidates.add(<Offset>[
        start,
        Offset(x, start.dy),
        Offset(x, end.dy),
        end,
      ]);
    }
    return candidates;
  }

  OrthogonalWirePath? _bestCandidate(
    List<List<Offset>> candidates, {
    required List<RoutingObstacle> obstacles,
    required List<OrthogonalWirePath> occupiedDifferentNetPaths,
    required bool allowBridgedCrossings,
  }) {
    OrthogonalWirePath? best;
    double? bestCost;
    for (final List<Offset> raw in candidates) {
      final List<Offset> points = _normalize(raw);
      if (points.length < 2) continue;

      OrthogonalWirePath candidate;
      try {
        candidate = OrthogonalWirePath(points: points);
      } on ArgumentError {
        continue;
      }
      if (_hitsObstacle(candidate, obstacles)) continue;

      if (allowBridgedCrossings) {
        if (WireRouteSafety.hasCollinearOverlap(
          candidate: candidate,
          occupiedDifferentNetPaths: occupiedDifferentNetPaths,
        )) {
          continue;
        }
      } else if (WireRouteSafety.hasDifferentNetCrossing(
        candidate: candidate,
        occupiedDifferentNetPaths: occupiedDifferentNetPaths,
      )) {
        continue;
      }

      final int crossings = allowBridgedCrossings
          ? WireRouteSafety.countPerpendicularCrossings(
              candidate: candidate,
              occupiedDifferentNetPaths: occupiedDifferentNetPaths,
            )
          : 0;
      final double cost = _cost(candidate) + crossings * crossingPenalty;
      if (bestCost == null || cost < bestCost) {
        best = candidate;
        bestCost = cost;
      }
    }
    return best;
  }

  OrthogonalWirePath? _routeManhattanAStar({
    required Offset start,
    required Offset end,
    required Rect envelope,
    required List<RoutingObstacle> obstacles,
    required List<OrthogonalWirePath> occupiedDifferentNetPaths,
    required bool allowBridgedCrossings,
  }) {
    final List<double> xs = _gridCoordinates(
      envelope.left,
      envelope.right,
      extras: <double>[start.dx, end.dx],
    );
    final List<double> ys = _gridCoordinates(
      envelope.top,
      envelope.bottom,
      extras: <double>[start.dy, end.dy],
    );
    final int startX = xs.indexOf(start.dx);
    final int startY = ys.indexOf(start.dy);
    final int endX = xs.indexOf(end.dx);
    final int endY = ys.indexOf(end.dy);
    if (startX < 0 || startY < 0 || endX < 0 || endY < 0) return null;

    final List<_SearchNode> open = <_SearchNode>[
      _SearchNode(
        xIndex: startX,
        yIndex: startY,
        previousAxis: null,
        g: 0,
        f: _manhattanDistance(start, end),
      ),
    ];
    final Map<String, double> bestG = <String, double>{
      _stateKey(startX, startY, null): 0,
    };
    final Map<String, String?> previous = <String, String?>{
      _stateKey(startX, startY, null): null,
    };
    final Map<String, _SearchNode> nodes = <String, _SearchNode>{
      _stateKey(startX, startY, null): open.first,
    };

    _SearchNode? goal;
    while (open.isNotEmpty) {
      open.sort(_compareSearchNodes);
      final _SearchNode current = open.removeAt(0);
      final String currentKey = _stateKey(
        current.xIndex,
        current.yIndex,
        current.previousAxis,
      );
      final double? knownBest = bestG[currentKey];
      if (knownBest == null || current.g > knownBest + 0.0001) continue;
      if (current.xIndex == endX && current.yIndex == endY) {
        goal = current;
        break;
      }

      final List<(int, int, WireAxis)> neighbors = <(int, int, WireAxis)>[
        if (current.xIndex > 0)
          (current.xIndex - 1, current.yIndex, WireAxis.horizontal),
        if (current.xIndex + 1 < xs.length)
          (current.xIndex + 1, current.yIndex, WireAxis.horizontal),
        if (current.yIndex > 0)
          (current.xIndex, current.yIndex - 1, WireAxis.vertical),
        if (current.yIndex + 1 < ys.length)
          (current.xIndex, current.yIndex + 1, WireAxis.vertical),
      ];

      for (final (int nextX, int nextY, WireAxis axis) in neighbors) {
        final Offset from = Offset(xs[current.xIndex], ys[current.yIndex]);
        final Offset to = Offset(xs[nextX], ys[nextY]);
        final OrthogonalSegment segment = OrthogonalSegment(
          start: from,
          end: to,
        );
        if (!_segmentIsLegal(
          segment,
          obstacles: obstacles,
          occupiedDifferentNetPaths: occupiedDifferentNetPaths,
          allowBridgedCrossings: allowBridgedCrossings,
        )) {
          continue;
        }

        final int crossings = allowBridgedCrossings
            ? _segmentCrossingCount(segment, occupiedDifferentNetPaths)
            : 0;
        final double nextG =
            current.g +
            segment.length +
            (current.previousAxis != null && current.previousAxis != axis
                ? bendPenalty
                : 0) +
            crossings * crossingPenalty;
        final String nextKey = _stateKey(nextX, nextY, axis);
        final double? existing = bestG[nextKey];
        if (existing != null && nextG >= existing - 0.0001) continue;

        final Offset nextPoint = Offset(xs[nextX], ys[nextY]);
        final _SearchNode nextNode = _SearchNode(
          xIndex: nextX,
          yIndex: nextY,
          previousAxis: axis,
          g: nextG,
          f: nextG + _manhattanDistance(nextPoint, end),
        );
        bestG[nextKey] = nextG;
        previous[nextKey] = currentKey;
        nodes[nextKey] = nextNode;
        open.add(nextNode);
      }
    }

    if (goal == null) return null;
    final List<Offset> reversed = <Offset>[];
    String? key = _stateKey(goal.xIndex, goal.yIndex, goal.previousAxis);
    while (key != null) {
      final _SearchNode? node = nodes[key];
      if (node == null) return null;
      reversed.add(Offset(xs[node.xIndex], ys[node.yIndex]));
      key = previous[key];
    }
    final List<Offset> points = _normalize(reversed.reversed.toList());
    if (points.length < 2) return null;
    return OrthogonalWirePath(points: points);
  }

  bool _segmentIsLegal(
    OrthogonalSegment segment, {
    required List<RoutingObstacle> obstacles,
    required List<OrthogonalWirePath> occupiedDifferentNetPaths,
    required bool allowBridgedCrossings,
  }) {
    for (final RoutingObstacle obstacle in obstacles) {
      if (_segmentHitsRect(segment, obstacle.bounds)) return false;
    }
    final OrthogonalWirePath oneSegment = OrthogonalWirePath(
      points: <Offset>[segment.start, segment.end],
    );
    if (allowBridgedCrossings) {
      return !WireRouteSafety.hasCollinearOverlap(
        candidate: oneSegment,
        occupiedDifferentNetPaths: occupiedDifferentNetPaths,
      );
    }
    return !WireRouteSafety.hasDifferentNetCrossing(
      candidate: oneSegment,
      occupiedDifferentNetPaths: occupiedDifferentNetPaths,
    );
  }

  int _segmentCrossingCount(
    OrthogonalSegment segment,
    List<OrthogonalWirePath> occupiedDifferentNetPaths,
  ) => WireRouteSafety.countPerpendicularCrossings(
    candidate: OrthogonalWirePath(
      points: <Offset>[segment.start, segment.end],
    ),
    occupiedDifferentNetPaths: occupiedDifferentNetPaths,
  );

  double _cost(OrthogonalWirePath path) {
    final double length = path.segments.fold<double>(
      0,
      (double sum, OrthogonalSegment segment) => sum + segment.length,
    );
    return length + path.bends.length * bendPenalty;
  }

  bool _hitsObstacle(OrthogonalWirePath path, List<RoutingObstacle> obstacles) {
    for (final OrthogonalSegment segment in path.segments) {
      for (final RoutingObstacle obstacle in obstacles) {
        if (_segmentHitsRect(segment, obstacle.bounds)) return true;
      }
    }
    return false;
  }

  static bool _segmentHitsRect(OrthogonalSegment segment, Rect rect) {
    if (segment.axis == WireAxis.horizontal) {
      final double y = segment.start.dy;
      if (y < rect.top || y > rect.bottom) return false;
      return segment.maxX >= rect.left && segment.minX <= rect.right;
    }
    final double x = segment.start.dx;
    if (x < rect.left || x > rect.right) return false;
    return segment.maxY >= rect.top && segment.minY <= rect.bottom;
  }

  List<double> _gridCoordinates(
    double minValue,
    double maxValue, {
    required List<double> extras,
  }) {
    final Set<double> values = <double>{...extras};
    final double first = (minValue / grid).floorToDouble() * grid;
    final double last = (maxValue / grid).ceilToDouble() * grid;
    for (double value = first; value <= last + 0.0001; value += grid) {
      values.add(value);
    }
    return _dedupeSorted(values.toList(growable: false));
  }

  double _snap(double value) => (value / grid).roundToDouble() * grid;

  static List<double> _dedupeSorted(List<double> values) {
    final List<double> sorted = <double>[...values]..sort();
    final List<double> result = <double>[];
    for (final double value in sorted) {
      if (result.isEmpty || result.last != value) result.add(value);
    }
    return result;
  }

  static List<Offset> _normalize(List<Offset> points) {
    final List<Offset> result = <Offset>[];
    for (final Offset point in points) {
      if (result.isEmpty || result.last != point) result.add(point);
    }
    var index = 1;
    while (index < result.length - 1) {
      final Offset before = result[index - 1];
      final Offset current = result[index];
      final Offset after = result[index + 1];
      final bool horizontal = before.dy == current.dy && current.dy == after.dy;
      final bool vertical = before.dx == current.dx && current.dx == after.dx;
      if (horizontal || vertical) {
        result.removeAt(index);
      } else {
        index++;
      }
    }
    return result;
  }

  static double _manhattanDistance(Offset first, Offset second) =>
      (first.dx - second.dx).abs() + (first.dy - second.dy).abs();

  static String _stateKey(int x, int y, WireAxis? axis) =>
      '$x:$y:' + (axis?.index ?? -1).toString();

  static int _compareSearchNodes(_SearchNode first, _SearchNode second) {
    final int byF = first.f.compareTo(second.f);
    if (byF != 0) return byF;
    final int byG = first.g.compareTo(second.g);
    if (byG != 0) return byG;
    final int byY = first.yIndex.compareTo(second.yIndex);
    if (byY != 0) return byY;
    final int byX = first.xIndex.compareTo(second.xIndex);
    if (byX != 0) return byX;
    return (first.previousAxis?.index ?? -1).compareTo(
      second.previousAxis?.index ?? -1,
    );
  }

  static double _min(double a, double b) => a < b ? a : b;
  static double _max(double a, double b) => a > b ? a : b;
}

final class _SearchNode {
  const _SearchNode({
    required this.xIndex,
    required this.yIndex,
    required this.previousAxis,
    required this.g,
    required this.f,
  });

  final int xIndex;
  final int yIndex;
  final WireAxis? previousAxis;
  final double g;
  final double f;
}
