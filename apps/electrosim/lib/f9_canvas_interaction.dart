import 'dart:math' as math;

import 'package:electrosim_canvas/electrosim_canvas.dart';
import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:flutter/material.dart';

/// F9-only visual routing. Electrical truth remains entirely in [CircuitState].
/// This layer only derives display waypoints from the current visual layout.
final class F9OrthogonalRouter {
  const F9OrthogonalRouter._();

  static const double clearance = 24;
  static const double _bendPenalty = 18;
  static const double _wireCrossPenalty = 240;
  static const double _obstaclePenalty = 100000;

  static CircuitVisualLayout reroute(
    CircuitState circuit,
    CircuitVisualLayout layout,
  ) {
    final CircuitGeometryIndex geometry = CircuitGeometryIndex.build(
      circuit,
      layout,
    );
    final Map<String, List<Offset>> routes = <String, List<Offset>>{};
    final List<_F9Segment> occupied = <_F9Segment>[];

    for (final Connection connection in circuit.connections) {
      final Offset? start =
          geometry.terminalPositions[connection.fromTerminalId];
      final Offset? end = geometry.terminalPositions[connection.toTerminalId];
      if (start == null || end == null) {
        continue;
      }
      final List<Offset> waypoints = _bestRoute(
        start,
        end,
        geometry.elementRects.values,
        occupied,
      );
      routes[connection.id.value] = waypoints;
      final List<Offset> points = <Offset>[start, ...waypoints, end];
      for (var i = 0; i < points.length - 1; i++) {
        occupied.add(_F9Segment(points[i], points[i + 1]));
      }
    }

    return CircuitVisualLayout(
      elementPositions: layout.elementPositions,
      elementSizes: layout.elementSizes,
      wireRoutes: routes,
      defaultElementSize: layout.defaultElementSize,
      elementQuarterTurns: layout.elementQuarterTurns,
      cabinetLayout: layout.cabinetLayout,
    );
  }

  static List<Offset> _bestRoute(
    Offset start,
    Offset end,
    Iterable<Rect> elementRects,
    List<_F9Segment> occupied,
  ) {
    final List<Rect> obstacles = elementRects
        .where(
          (Rect rect) =>
              !rect.inflate(2).contains(start) &&
              !rect.inflate(2).contains(end),
        )
        .map((Rect rect) => rect.inflate(clearance))
        .toList(growable: false);

    final List<List<Offset>> candidates = <List<Offset>>[];

    // Prefer the fewest bends first. A straight route is ideal when aligned.
    if ((start.dx - end.dx).abs() < 0.5 || (start.dy - end.dy).abs() < 0.5) {
      candidates.add(const <Offset>[]);
    }

    // One-bend L routes are shorter and visually cleaner than a dog-leg.
    candidates.add(<Offset>[Offset(end.dx, start.dy)]);
    candidates.add(<Offset>[Offset(start.dx, end.dy)]);

    // Stable two-bend channels. Candidate coordinates come from the midpoint and
    // obstacle clearance edges; deterministic ordering prevents route flicker
    // while an element is dragged.
    final List<double> xChannels = <double>{
      (start.dx + end.dx) / 2,
      start.dx - clearance,
      start.dx + clearance,
      end.dx - clearance,
      end.dx + clearance,
      for (final Rect rect in obstacles) rect.left - 8,
      for (final Rect rect in obstacles) rect.right + 8,
    }.toList()..sort();
    final List<double> yChannels = <double>{
      (start.dy + end.dy) / 2,
      start.dy - clearance,
      start.dy + clearance,
      end.dy - clearance,
      end.dy + clearance,
      for (final Rect rect in obstacles) rect.top - 8,
      for (final Rect rect in obstacles) rect.bottom + 8,
    }.toList()..sort();

    for (final double x in xChannels) {
      candidates.add(<Offset>[Offset(x, start.dy), Offset(x, end.dy)]);
    }
    for (final double y in yChannels) {
      candidates.add(<Offset>[Offset(start.dx, y), Offset(end.dx, y)]);
    }

    List<Offset>? best;
    double bestScore = double.infinity;
    for (final List<Offset> rawCandidate in candidates) {
      final List<Offset> candidate = _simplify(rawCandidate);
      final List<Offset> points = <Offset>[start, ...candidate, end];
      if (!_isOrthogonal(points)) {
        continue;
      }
      double score = _polylineLength(points) + candidate.length * _bendPenalty;
      bool blocked = false;
      for (var i = 0; i < points.length - 1; i++) {
        final _F9Segment segment = _F9Segment(points[i], points[i + 1]);
        for (final Rect obstacle in obstacles) {
          if (_orthogonalSegmentIntersectsRect(
            segment.a,
            segment.b,
            obstacle,
          )) {
            score += _obstaclePenalty;
            blocked = true;
          }
        }
        for (final _F9Segment existing in occupied) {
          if (_segmentsCross(segment, existing)) {
            score += _wireCrossPenalty;
          }
        }
      }
      // A blocked path remains a last-resort candidate so routing is total, but
      // every clear route wins decisively.
      if (blocked) {
        score += _obstaclePenalty;
      }
      if (score < bestScore - 0.001) {
        bestScore = score;
        best = candidate;
      }
    }

    return best ?? const <Offset>[];
  }

  static bool _isOrthogonal(List<Offset> points) {
    for (var i = 0; i < points.length - 1; i++) {
      final Offset a = points[i];
      final Offset b = points[i + 1];
      if ((a.dx - b.dx).abs() >= 0.5 && (a.dy - b.dy).abs() >= 0.5) {
        return false;
      }
    }
    return true;
  }

  static bool _segmentsCross(_F9Segment first, _F9Segment second) {
    final bool firstVertical = (first.a.dx - first.b.dx).abs() < 0.5;
    final bool secondVertical = (second.a.dx - second.b.dx).abs() < 0.5;
    if (firstVertical == secondVertical) {
      return false;
    }
    final _F9Segment vertical = firstVertical ? first : second;
    final _F9Segment horizontal = firstVertical ? second : first;
    final double vx = vertical.a.dx;
    final double hy = horizontal.a.dy;
    final double vTop = math.min(vertical.a.dy, vertical.b.dy);
    final double vBottom = math.max(vertical.a.dy, vertical.b.dy);
    final double hLeft = math.min(horizontal.a.dx, horizontal.b.dx);
    final double hRight = math.max(horizontal.a.dx, horizontal.b.dx);
    return vx > hLeft + 0.5 &&
        vx < hRight - 0.5 &&
        hy > vTop + 0.5 &&
        hy < vBottom - 0.5;
  }

  static bool _orthogonalSegmentIntersectsRect(Offset a, Offset b, Rect rect) {
    if ((a.dx - b.dx).abs() < 0.5) {
      if (a.dx <= rect.left || a.dx >= rect.right) {
        return false;
      }
      final double top = math.min(a.dy, b.dy);
      final double bottom = math.max(a.dy, b.dy);
      return bottom > rect.top && top < rect.bottom;
    }
    if ((a.dy - b.dy).abs() < 0.5) {
      if (a.dy <= rect.top || a.dy >= rect.bottom) {
        return false;
      }
      final double left = math.min(a.dx, b.dx);
      final double right = math.max(a.dx, b.dx);
      return right > rect.left && left < rect.right;
    }
    return true;
  }

  static double _polylineLength(List<Offset> points) {
    double total = 0;
    for (var i = 0; i < points.length - 1; i++) {
      total += (points[i + 1] - points[i]).distance;
    }
    return total;
  }

  static List<Offset> _simplify(List<Offset> points) {
    final List<Offset> result = <Offset>[];
    for (final Offset point in points) {
      if (result.isNotEmpty && (result.last - point).distance <= 0.5) {
        continue;
      }
      result.add(point);
      while (result.length >= 3) {
        final Offset a = result[result.length - 3];
        final Offset b = result[result.length - 2];
        final Offset c = result[result.length - 1];
        final bool sameX =
            (a.dx - b.dx).abs() < 0.5 && (b.dx - c.dx).abs() < 0.5;
        final bool sameY =
            (a.dy - b.dy).abs() < 0.5 && (b.dy - c.dy).abs() < 0.5;
        if (!sameX && !sameY) {
          break;
        }
        result.removeAt(result.length - 2);
      }
    }
    return result;
  }
}

final class _F9Segment {
  const _F9Segment(this.a, this.b);

  final Offset a;
  final Offset b;
}

final class F9ViewportBounds {
  const F9ViewportBounds._();

  static Offset clampTranslation({
    required CircuitState circuit,
    required CircuitVisualLayout layout,
    required Size viewportSize,
    required double scale,
    required Offset translation,
    double minimumVisiblePixels = 88,
  }) {
    if (viewportSize.isEmpty) {
      return translation;
    }
    final CircuitGeometryIndex geometry = CircuitGeometryIndex.build(
      circuit,
      layout,
    );
    if (geometry.elementRects.isEmpty) {
      return translation;
    }
    Rect worldBounds = geometry.elementRects.values.first;
    for (final Rect rect in geometry.elementRects.values.skip(1)) {
      worldBounds = worldBounds.expandToInclude(rect);
    }
    worldBounds = worldBounds.inflate(24);

    final double minTx = minimumVisiblePixels - worldBounds.right * scale;
    final double maxTx =
        viewportSize.width - minimumVisiblePixels - worldBounds.left * scale;
    final double minTy = minimumVisiblePixels - worldBounds.bottom * scale;
    final double maxTy =
        viewportSize.height - minimumVisiblePixels - worldBounds.top * scale;

    return Offset(
      _clampAxis(translation.dx, minTx, maxTx),
      _clampAxis(translation.dy, minTy, maxTy),
    );
  }

  static double _clampAxis(double value, double minValue, double maxValue) {
    if (minValue <= maxValue) {
      return value.clamp(minValue, maxValue).toDouble();
    }
    return (minValue + maxValue) / 2;
  }
}
