import 'dart:ui';

import 'package:electrosim_canvas/electrosim_canvas.dart';
import 'package:electrosim_domain/electrosim_domain.dart';

/// Immutable drag session prepared once at pointer-down.
///
/// Geometry and attachment discovery are intentionally done once. Pointer-move
/// updates only translate the selected element and its directly attached wire
/// endpoints. Global G2A routing remains deferred until pointer-up.
final class F18DragSession {
  F18DragSession._({
    required this.baseLayout,
    required this.elementId,
    required this.basePosition,
    required List<_AttachedWire> attachedWires,
  }) : attachedWires = List<_AttachedWire>.unmodifiable(attachedWires);

  factory F18DragSession.begin({
    required CircuitState circuit,
    required CircuitVisualLayout baseLayout,
    required String elementId,
  }) {
    final Offset? basePosition = baseLayout.positionOf(elementId);
    if (basePosition == null) {
      throw ArgumentError.value(
        elementId,
        'elementId',
        'Dragged element has no visual position.',
      );
    }

    final Set<TerminalId> movingTerminals = _terminalIdsFor(
      circuit,
      elementId,
    );
    final CircuitGeometryIndex geometry = CircuitGeometryIndex.build(
      circuit,
      baseLayout,
    );
    final List<_AttachedWire> attached = <_AttachedWire>[];

    for (final Connection connection in circuit.connections) {
      final bool startMoves = movingTerminals.contains(
        connection.fromTerminalId,
      );
      final bool endMoves = movingTerminals.contains(connection.toTerminalId);
      if (!startMoves && !endMoves) continue;

      final Offset? start =
          geometry.terminalPositions[connection.fromTerminalId];
      final Offset? end = geometry.terminalPositions[connection.toTerminalId];
      if (start == null || end == null) continue;
      attached.add(
        _AttachedWire(
          connectionId: connection.id.value,
          baseStart: start,
          baseEnd: end,
          startMoves: startMoves,
          endMoves: endMoves,
        ),
      );
    }

    return F18DragSession._(
      baseLayout: baseLayout,
      elementId: elementId,
      basePosition: basePosition,
      attachedWires: attached,
    );
  }

  final CircuitVisualLayout baseLayout;
  final String elementId;
  final Offset basePosition;
  final List<_AttachedWire> attachedWires;

  CircuitVisualLayout previewAt(Offset position) {
    final Offset delta = position - basePosition;
    final CircuitVisualLayout moved = baseLayout.moveElement(
      elementId,
      position,
    );
    if (attachedWires.isEmpty) return moved;

    final Map<String, List<Offset>> routes = <String, List<Offset>>{
      ...baseLayout.wireRoutes,
    };
    for (final _AttachedWire wire in attachedWires) {
      final Offset start = wire.startMoves
          ? wire.baseStart + delta
          : wire.baseStart;
      final Offset end = wire.endMoves ? wire.baseEnd + delta : wire.baseEnd;
      routes[wire.connectionId] =
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

  static Set<TerminalId> _terminalIdsFor(
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

final class _AttachedWire {
  const _AttachedWire({
    required this.connectionId,
    required this.baseStart,
    required this.baseEnd,
    required this.startMoves,
    required this.endMoves,
  });

  final String connectionId;
  final Offset baseStart;
  final Offset baseEnd;
  final bool startMoves;
  final bool endMoves;
}
