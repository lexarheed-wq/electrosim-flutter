import 'dart:ui';

import 'package:electrosim_canvas/electrosim_canvas.dart';
import 'package:electrosim_domain/electrosim_domain.dart';

/// Lightweight drag preview used while a pointer is moving.
///
/// This path deliberately performs no global routing. It moves only the
/// selected element and updates only the directly attached wire previews with
/// one Manhattan corner. The authoritative G2A routing is deferred until the
/// pointer is released.
abstract final class F18DragPreviewPolicy {
  static CircuitVisualLayout previewMove({
    required CircuitState circuit,
    required CircuitVisualLayout baseLayout,
    required String elementId,
    required Offset position,
  }) {
    final CircuitVisualLayout moved = baseLayout.moveElement(
      elementId,
      position,
    );
    final Set<TerminalId> terminals = terminalIdsFor(circuit, elementId);
    if (terminals.isEmpty) {
      return moved;
    }

    final CircuitGeometryIndex geometry = CircuitGeometryIndex.build(
      circuit,
      moved,
    );
    final Map<String, List<Offset>> routes = <String, List<Offset>>{
      ...baseLayout.wireRoutes,
    };

    for (final Connection connection in circuit.connections) {
      final bool attached =
          terminals.contains(connection.fromTerminalId) ||
          terminals.contains(connection.toTerminalId);
      if (!attached) {
        continue;
      }

      final Offset? start =
          geometry.terminalPositions[connection.fromTerminalId];
      final Offset? end = geometry.terminalPositions[connection.toTerminalId];
      if (start == null || end == null) {
        continue;
      }

      routes[connection.id.value] =
          start.dx == end.dx || start.dy == end.dy
          ? const <Offset>[]
          : <Offset>[Offset(end.dx, start.dy)];
    }

    return CircuitVisualLayout(
      elementPositions: moved.elementPositions,
      elementSizes: moved.elementSizes,
      wireRoutes: routes,
      elementQuarterTurns: moved.elementQuarterTurns,
      defaultElementSize: moved.defaultElementSize,
    );
  }

  static Set<TerminalId> terminalIdsFor(
    CircuitState circuit,
    String elementId,
  ) {
    for (final ComponentInstance component in circuit.components) {
      if (component.id.value == elementId) {
        return component.terminals
            .map((Terminal terminal) => terminal.id)
            .toSet();
      }
    }
    for (final SourceInstance source in circuit.sources) {
      if (source.id.value == elementId) {
        return source.terminals.map((Terminal terminal) => terminal.id).toSet();
      }
    }
    return const <TerminalId>{};
  }
}
