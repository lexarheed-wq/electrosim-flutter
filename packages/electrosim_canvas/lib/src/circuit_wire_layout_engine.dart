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
      if (start == null || end == null || start == end) {
        continue;
      }

      final String? fromOwner =
          geometry.terminalOwners[connection.fromTerminalId];
      final String? toOwner =
          geometry.terminalOwners[connection.toTerminalId];

      final List<RoutingObstacle> obstacles = geometry.elementRects.entries
          .where(
            (MapEntry<String, Rect> entry) =>
                entry.key != fromOwner && entry.key != toOwner,
          )
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
        start: start,
        end: end,
        obstacles: obstacles,
        occupiedDifferentNetPaths: crossingObstacles,
      );

      if (result.isResolved) {
        final OrthogonalWirePath path = result.path!;
        nextRoutes[connection.id.value] = path.points.length <= 2
            ? const <Offset>[]
            : List<Offset>.unmodifiable(
                path.points.sublist(1, path.points.length - 1),
              );
        occupied.add(path);
        continue;
      }

      final OrthogonalWirePath? existing = _existingOrthogonalPath(
        start: start,
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
      defaultElementSize: layout.defaultElementSize,
    );
  }

  static bool _sharesEndpoint(OrthogonalWirePath path, Offset point) {
    return path.points.first == point || path.points.last == point;
  }

  static OrthogonalWirePath? _existingOrthogonalPath({
    required Offset start,
    required Offset end,
    required List<Offset> intermediate,
  }) {
    final List<Offset> points = <Offset>[start, ...intermediate, end];
    try {
      return OrthogonalWirePath(points: points);
    } on ArgumentError {
      return null;
    }
  }
}
