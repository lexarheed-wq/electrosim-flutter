import 'dart:ui';

import 'package:electrosim_canvas/electrosim_canvas.dart';
import 'package:electrosim_domain/electrosim_domain.dart';

abstract final class F18WorkspaceWireSafety {
  static bool isCrossingFree({
    required CircuitState circuit,
    required CircuitVisualLayout layout,
  }) {
    final CircuitGeometryIndex geometry = CircuitGeometryIndex.build(
      circuit,
      layout,
    );
    final List<OrthogonalWirePath> accepted = <OrthogonalWirePath>[];

    for (final Connection connection in circuit.connections) {
      final Offset? start =
          geometry.terminalPositions[connection.fromTerminalId];
      final Offset? end = geometry.terminalPositions[connection.toTerminalId];
      if (start == null || end == null || start == end) {
        return false;
      }

      OrthogonalWirePath path;
      try {
        path = OrthogonalWirePath(
          points: <Offset>[start, ...layout.routeFor(connection.id.value), end],
        );
      } on ArgumentError {
        return false;
      }

      final List<OrthogonalWirePath> differentNetPaths = accepted
          .where(
            (OrthogonalWirePath existing) =>
                !_sharesEndpoint(existing, path.points.first) &&
                !_sharesEndpoint(existing, path.points.last),
          )
          .toList(growable: false);

      if (WireRouteSafety.hasDifferentNetCrossing(
        candidate: path,
        occupiedDifferentNetPaths: differentNetPaths,
      )) {
        return false;
      }
      accepted.add(path);
    }
    return true;
  }

  static bool _sharesEndpoint(OrthogonalWirePath path, Offset point) {
    return path.points.first == point || path.points.last == point;
  }
}
