import 'dart:ui';

import 'package:electrosim_domain/electrosim_domain.dart';

import 'canvas_geometry.dart';
import 'circuit_visual_layout.dart';

enum CanvasHitKind { terminal, component, source, wire, background }

final class CanvasHitResult {
  const CanvasHitResult({
    required this.kind,
    required this.worldPosition,
    this.elementId,
    this.terminalId,
    this.connectionId,
  });

  const CanvasHitResult.background(Offset worldPosition)
    : this(kind: CanvasHitKind.background, worldPosition: worldPosition);

  final CanvasHitKind kind;
  final Offset worldPosition;
  final String? elementId;
  final TerminalId? terminalId;
  final ConnectionId? connectionId;
}

final class HitTestEngine {
  const HitTestEngine({this.terminalRadius = 11, this.wireTolerance = 7});

  final double terminalRadius;
  final double wireTolerance;

  CanvasHitResult hitTest({
    required Offset worldPoint,
    required CircuitState circuit,
    required CircuitVisualLayout layout,
    Map<String, Offset> previewPositions = const <String, Offset>{},
    double viewportScale = 1,
  }) {
    final double safeScale = viewportScale.isFinite && viewportScale > 0
        ? viewportScale
        : 1;
    final double terminalWorldRadius = terminalRadius / safeScale;
    final double wireWorldTolerance = wireTolerance / safeScale;
    final CircuitGeometryIndex geometry = CircuitGeometryIndex.build(
      circuit,
      layout,
      previewPositions: previewPositions,
    );

    for (final MapEntry<TerminalId, Offset> entry
        in geometry.terminalPositions.entries) {
      if ((entry.value - worldPoint).distance <= terminalWorldRadius) {
        return CanvasHitResult(
          kind: CanvasHitKind.terminal,
          worldPosition: worldPoint,
          elementId: geometry.terminalOwners[entry.key],
          terminalId: entry.key,
        );
      }
    }

    for (final ComponentInstance component in circuit.components.reversed) {
      final Rect? rect = geometry.elementRects[component.id.value];
      if (rect?.contains(worldPoint) ?? false) {
        return CanvasHitResult(
          kind: CanvasHitKind.component,
          worldPosition: worldPoint,
          elementId: component.id.value,
        );
      }
    }
    for (final SourceInstance source in circuit.sources.reversed) {
      final Rect? rect = geometry.elementRects[source.id.value];
      if (rect?.contains(worldPoint) ?? false) {
        return CanvasHitResult(
          kind: CanvasHitKind.source,
          worldPosition: worldPoint,
          elementId: source.id.value,
        );
      }
    }

    for (final Connection connection in circuit.connections.reversed) {
      final Offset? start =
          geometry.terminalPositions[connection.fromTerminalId];
      final Offset? end = geometry.terminalPositions[connection.toTerminalId];
      if (start == null || end == null) {
        continue;
      }
      final List<Offset> points = <Offset>[
        start,
        ...layout.routeFor(connection.id.value),
        end,
      ];
      for (var index = 0; index < points.length - 1; index++) {
        if (_distanceToSegment(worldPoint, points[index], points[index + 1]) <=
            wireWorldTolerance) {
          return CanvasHitResult(
            kind: CanvasHitKind.wire,
            worldPosition: worldPoint,
            connectionId: connection.id,
          );
        }
      }
    }

    return CanvasHitResult.background(worldPoint);
  }

  static double _distanceToSegment(Offset point, Offset a, Offset b) {
    final double dx = b.dx - a.dx;
    final double dy = b.dy - a.dy;
    final double lengthSquared = dx * dx + dy * dy;
    if (lengthSquared == 0) {
      return (point - a).distance;
    }
    final double t =
        (((point.dx - a.dx) * dx + (point.dy - a.dy) * dy) / lengthSquared)
            .clamp(0.0, 1.0);
    final Offset projection = Offset(a.dx + t * dx, a.dy + t * dy);
    return (point - projection).distance;
  }
}
