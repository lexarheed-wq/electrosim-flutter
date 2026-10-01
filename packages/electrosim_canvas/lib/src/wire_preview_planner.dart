import 'dart:ui';

import 'package:electrosim_domain/electrosim_domain.dart';

import 'canvas_geometry.dart';
import 'circuit_visual_layout.dart';
import 'orthogonal_wire_router.dart';
import 'wire_geometry.dart';

final class WirePreviewPlan {
  const WirePreviewPlan({
    required this.route,
    required this.snappedTargetTerminalId,
    required this.endPoint,
  });

  final WireRouteResult route;
  final TerminalId? snappedTargetTerminalId;
  final Offset endPoint;
}

final class WirePreviewPlanner {
  const WirePreviewPlanner({
    required this.router,
    required this.terminalSnapRadius,
  }) : assert(terminalSnapRadius > 0);

  final OrthogonalWireRouter router;
  final double terminalSnapRadius;

  WirePreviewPlan plan({
    required CircuitState circuit,
    required CircuitVisualLayout layout,
    required TerminalId startTerminalId,
    required Offset pointerWorldPosition,
  }) {
    final CircuitGeometryIndex geometry = CircuitGeometryIndex.build(
      circuit,
      layout,
    );
    final Offset? start = geometry.terminalPositions[startTerminalId];
    if (start == null) {
      return WirePreviewPlan(
        route: const WireRouteResult.unresolved(
          WireRouteFailure.noCrossingFreeRoute,
        ),
        snappedTargetTerminalId: null,
        endPoint: pointerWorldPosition,
      );
    }

    final MapEntry<TerminalId, Offset>? target = _nearestTerminal(
      geometry: geometry,
      startTerminalId: startTerminalId,
      pointer: pointerWorldPosition,
    );
    final TerminalId? targetId = target?.key;
    final Offset end = target?.value ?? pointerWorldPosition;

    if (start == end) {
      return WirePreviewPlan(
        route: const WireRouteResult.unresolved(
          WireRouteFailure.noCrossingFreeRoute,
        ),
        snappedTargetTerminalId: targetId,
        endPoint: end,
      );
    }

    final String? fromOwner = geometry.terminalOwners[startTerminalId];
    final String? targetOwner =
        targetId == null ? null : geometry.terminalOwners[targetId];

    final List<RoutingObstacle> obstacles = geometry.elementRects.entries
        .where(
          (MapEntry<String, Rect> entry) =>
              entry.key != fromOwner && entry.key != targetOwner,
        )
        .map(
          (MapEntry<String, Rect> entry) =>
              RoutingObstacle(bounds: entry.value),
        )
        .toList(growable: false);

    final List<OrthogonalWirePath> occupied = <OrthogonalWirePath>[];
    for (final Connection connection in circuit.connections) {
      final Offset? connectionStart =
          geometry.terminalPositions[connection.fromTerminalId];
      final Offset? connectionEnd =
          geometry.terminalPositions[connection.toTerminalId];
      if (connectionStart == null || connectionEnd == null) {
        continue;
      }
      final List<Offset> points = <Offset>[
        connectionStart,
        ...layout.routeFor(connection.id.value),
        connectionEnd,
      ];
      OrthogonalWirePath path;
      try {
        path = OrthogonalWirePath(points: points);
      } on ArgumentError {
        continue;
      }
      if (_sharesEndpoint(path, start) || _sharesEndpoint(path, end)) {
        continue;
      }
      occupied.add(path);
    }

    return WirePreviewPlan(
      route: router.route(
        start: start,
        end: end,
        obstacles: obstacles,
        occupiedDifferentNetPaths: occupied,
      ),
      snappedTargetTerminalId: targetId,
      endPoint: end,
    );
  }

  MapEntry<TerminalId, Offset>? _nearestTerminal({
    required CircuitGeometryIndex geometry,
    required TerminalId startTerminalId,
    required Offset pointer,
  }) {
    MapEntry<TerminalId, Offset>? best;
    double? bestDistance;
    for (final MapEntry<TerminalId, Offset> entry
        in geometry.terminalPositions.entries) {
      if (entry.key == startTerminalId) {
        continue;
      }
      final double distance = (entry.value - pointer).distance;
      if (distance > terminalSnapRadius) {
        continue;
      }
      final bool betterDistance =
          bestDistance == null || distance < bestDistance - 0.0001;
      final bool deterministicTie =
          bestDistance != null &&
          (distance - bestDistance).abs() <= 0.0001 &&
          (best == null || entry.key.value.compareTo(best.key.value) < 0);
      if (betterDistance || deterministicTie) {
        best = entry;
        bestDistance = distance;
      }
    }
    return best;
  }

  static bool _sharesEndpoint(OrthogonalWirePath path, Offset point) {
    return path.points.first == point || path.points.last == point;
  }
}
