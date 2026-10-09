import 'dart:ui';

import 'package:electrosim_canvas/electrosim_canvas.dart';
import 'package:electrosim_domain/electrosim_domain.dart';

/// Final visual integrity check.
///
/// Different electrical nets are allowed to cross: the smart-wire renderer
/// represents those intersections explicitly as non-junction bridge/gaps.
/// Therefore a visual crossing is never a reason to reject an electrically
/// valid connection or component move.
abstract final class F18WorkspaceWireSafety {
  static bool isRenderable({
    required CircuitState circuit,
    required CircuitVisualLayout layout,
  }) {
    final CircuitGeometryIndex geometry = CircuitGeometryIndex.build(
      circuit,
      layout,
    );

    for (final Connection connection in circuit.connections) {
      final Offset? start =
          geometry.terminalPositions[connection.fromTerminalId];
      final Offset? end = geometry.terminalPositions[connection.toTerminalId];
      if (start == null || end == null || start == end) return false;
      try {
        OrthogonalWirePath(
          points: <Offset>[start, ...layout.routeFor(connection.id.value), end],
        );
      } on ArgumentError {
        return false;
      }
    }
    return true;
  }
}
