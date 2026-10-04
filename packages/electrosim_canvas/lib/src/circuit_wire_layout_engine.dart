import 'dart:ui';

import 'package:electrosim_domain/electrosim_domain.dart';

import 'canvas_geometry.dart';
import 'circuit_visual_layout.dart';
import 'orthogonal_wire_router.dart';
import 'wire_geometry.dart';

final class CircuitWireLayoutEngine {
  const CircuitWireLayoutEngine({
    required this.router,
  });

  final OrthogonalWireRouter router;

  CircuitVisualLayout routeAll({
    required CircuitState circuit,
    required CircuitVisualLayout layout,
  }) {
    final CircuitGeometryIndex geometry = CircuitGeometryIndex.build(
      circuit,
      layout,
    );
    final Map<String, List<Offset>> nextRoutes =
        <String, List<Offset>>{...layout.wireRoutes};
    final List<OrthogonalWirePath> occupied = <OrthogonalWirePath>[];

    for (final Connection connection in circuit.connections) {
      final Offset? start =
          geometry.terminalPositions[connection.fromTerminalId];
      final Offset? end =
          geometry.terminalPositions[connection.toTerminalId];
      final Offset? startRouting =
          geometry.terminalRoutingPositions[connection.fromTerminalId];
      final Offset? endRouting =
          geometry.terminalRoutingPositions[connection.toTerminalId];
      if (start == null ||
          end == null ||
          startRouting == null ||
          endRouting == null ||
          start == end) {
        continue;
      }

      final String? fromOwner =
          geometry.terminalOwners[connection.fromTerminalId];
      final String? toOwner =
          geometry.terminalOwners[connection.toTerminalId];
      final Rect? fromRect =
          fromOwner == null ? null : geometry.elementRects[fromOwner];
      final Rect? toRect =
          toOwner == null ? null : geometry.elementRects[toOwner];

      final Offset startStub = fromRect == null
          ? startRouting
          : _terminalStubPoint(startRouting, fromRect);
      final Offset endStub = toRect == null
          ? endRouting
          : _terminalStubPoint(endRouting, toRect);

      final List<RoutingObstacle> obstacles = geometry.elementRects.entries
          .map(
            (MapEntry<String, Rect> entry) =>
                RoutingObstacle(bounds: entry.value),
          )
          .toList(growable: false);

      final List<OrthogonalWirePath> crossingObstacles = occupied
          .where(
            (OrthogonalWirePath path) =>
                !_sharesEndpoint(path, start) &&
                !_sharesEndpoint(path, end),
          )
          .toList(growable: false);

      final WireRouteResult result = router.route(
        start: startStub,
        end: endStub,
        obstacles: obstacles,
        occupiedDifferentNetPaths: crossingObstacles,
      );

      if (result.isResolved) {
        final OrthogonalWirePath? path = _composeStubbedPath(
          start: start,
          startRouting: startRouting,
          startStub: startStub,
          routed: result.path!,
          endStub: endStub,
          endRouting: endRouting,
          end: end,
        );
        if (path != null &&
            !WireRouteSafety.hasDifferentNetCrossing(
              candidate: path,
              occupiedDifferentNetPaths: crossingObstacles,
            )) {
          nextRoutes[connection.id.value] = path.points.length <= 2
              ? const <Offset>[]
              : List<Offset>.unmodifiable(
                  path.points.sublist(1, path.points.length - 1),
                );
          occupied.add(path);
          continue;
        }
      }

      final OrthogonalWirePath? existing = _existingOrthogonalPath(
        start: start,
        startRouting: startRouting,
        endRouting: endRouting,
        end: end,
        intermediate: layout.routeFor(connection.id.value),
      );
      if (existing != null) {
        occupied.add(existing);
      }
    }

    return CircuitVisualLayout(
      elementPositions: layout.elementPositions,
      elementSizes: layout.elementSizes,
      wireRoutes: nextRoutes,
      elementQuarterTurns: layout.elementQuarterTurns,
      defaultElementSize: layout.defaultElementSize,
    );
  }

  Offset _terminalStubPoint(Offset terminal, Rect ownerRect) {
    final Offset direction = _terminalOutwardDirection(terminal, ownerRect);
    final double distance = router.obstacleClearance + router.grid;
    return terminal + direction * distance;
  }

  static Offset _terminalOutwardDirection(Offset terminal, Rect rect) {
    const double epsilon = 0.001;
    if ((terminal.dx - rect.left).abs() <= epsilon) {
      return const Offset(-1, 0);
    }
    if ((terminal.dx - rect.right).abs() <= epsilon) {
      return const Offset(1, 0);
    }
    if ((terminal.dy - rect.top).abs() <= epsilon) {
      return const Offset(0, -1);
    }
    if ((terminal.dy - rect.bottom).abs() <= epsilon) {
      return const Offset(0, 1);
    }

    final Map<Offset, double> distances = <Offset, double>{
      const Offset(-1, 0): (terminal.dx - rect.left).abs(),
      const Offset(1, 0): (terminal.dx - rect.right).abs(),
      const Offset(0, -1): (terminal.dy - rect.top).abs(),
      const Offset(0, 1): (terminal.dy - rect.bottom).abs(),
    };
    return distances.entries
        .reduce(
          (MapEntry<Offset, double> a, MapEntry<Offset, double> b) =>
              a.value <= b.value ? a : b,
        )
        .key;
  }

  static OrthogonalWirePath? _composeStubbedPath({
    required Offset start,
    required Offset startRouting,
    required Offset startStub,
    required OrthogonalWirePath routed,
    required Offset endStub,
    required Offset endRouting,
    required Offset end,
  }) {
    final List<Offset> raw = <Offset>[
      start,
      if (startRouting != start) startRouting,
      if (startStub != startRouting) startStub,
      ...routed.points.skip(1).take(
        routed.points.length > 2 ? routed.points.length - 2 : 0,
      ),
      if (endStub != endRouting) endStub,
      if (endRouting != end) endRouting,
      end,
    ];
    final List<Offset> normalized = <Offset>[];
    for (final Offset point in raw) {
      if (normalized.isEmpty || normalized.last != point) {
        normalized.add(point);
      }
    }

    var index = 1;
    while (index < normalized.length - 1) {
      final Offset before = normalized[index - 1];
      final Offset current = normalized[index];
      final Offset after = normalized[index + 1];
      final bool horizontal =
          before.dy == current.dy && current.dy == after.dy;
      final bool vertical =
          before.dx == current.dx && current.dx == after.dx;
      if (horizontal || vertical) {
        normalized.removeAt(index);
      } else {
        index++;
      }
    }

    if (normalized.length < 2) {
      return null;
    }
    try {
      return OrthogonalWirePath(points: normalized);
    } on ArgumentError {
      return null;
    }
  }

  static bool _sharesEndpoint(OrthogonalWirePath path, Offset point) {
    return path.points.first == point || path.points.last == point;
  }

  static OrthogonalWirePath? _existingOrthogonalPath({
    required Offset start,
    required Offset startRouting,
    required Offset endRouting,
    required Offset end,
    required List<Offset> intermediate,
  }) {
    final List<Offset> raw = <Offset>[
      start,
      if (startRouting != start) startRouting,
      ...intermediate,
      if (endRouting != end) endRouting,
      end,
    ];
    final List<Offset> points = <Offset>[];
    for (final Offset point in raw) {
      if (points.isEmpty || points.last != point) {
        points.add(point);
      }
    }
    var index = 1;
    while (index < points.length - 1) {
      final Offset before = points[index - 1];
      final Offset current = points[index];
      final Offset after = points[index + 1];
      final bool horizontal =
          before.dy == current.dy && current.dy == after.dy;
      final bool vertical =
          before.dx == current.dx && current.dx == after.dx;
      if (horizontal || vertical) {
        points.removeAt(index);
      } else {
        index++;
      }
    }
    try {
      return OrthogonalWirePath(points: points);
    } on ArgumentError {
      return null;
    }
  }
}
