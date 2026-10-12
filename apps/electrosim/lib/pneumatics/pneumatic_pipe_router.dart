import 'dart:math' as math;

import 'package:flutter/painting.dart';

/// Orthogonal routes from real port centres, outside component footprints.
///
/// This concerns only the graphic route. It never edits a PneumaticPipe,
/// swaps a port, or changes the canonical gas/electrical topology.
final class PneumaticPipeRouter {
  const PneumaticPipeRouter._();

  static List<Offset>? route({
    required Offset start,
    required Offset end,
    required Rect fromTile,
    required Rect toTile,
    required Iterable<Rect> tiles,
    Iterable<List<Offset>> previousRoutes = const <List<Offset>>[],
  }) {
    const double clearance = 10;
    final List<Rect> obstacles = tiles
        .map((Rect tile) => tile.inflate(6))
        .toList(growable: false);
    final Offset out = Offset(start.dx, fromTile.bottom + clearance);
    final Offset incoming = Offset(end.dx, toTile.bottom + clearance);
    final double baseline = math.max(out.dy, incoming.dy) + 12;
    final double outsideLeft = obstacles.isEmpty
        ? math.min(out.dx, incoming.dx) - 24
        : obstacles.map((Rect r) => r.left).reduce(math.min) - 24;
    final double outsideRight = obstacles.isEmpty
        ? math.max(out.dx, incoming.dx) + 24
        : obstacles.map((Rect r) => r.right).reduce(math.max) + 24;
    final double outsideBottom = obstacles.isEmpty
        ? baseline + 24
        : math.max(
            baseline,
            obstacles.map((Rect r) => r.bottom).reduce(math.max) + 18,
          );

    // Common case: three bends below the relevant row, with a choice of
    // independent horizontal lanes. Fallback: escape around tiles on either
    // side, without permitting a segment through an occupied tile.
    final List<double> lanes = <double>[
      baseline,
      baseline + 12,
      baseline + 24,
      outsideBottom,
      outsideBottom + 12,
    ];
    final List<double> startXs = <double>[
      out.dx,
      fromTile.left - 14,
      fromTile.right + 14,
      outsideLeft,
      outsideRight,
    ];
    final List<double> endXs = <double>[
      incoming.dx,
      toTile.left - 14,
      toTile.right + 14,
      outsideLeft,
      outsideRight,
    ];

    List<Offset>? selected;
    double best = double.infinity;
    for (final double y in lanes.toSet()) {
      for (final double sx in startXs.toSet()) {
        for (final double ex in endXs.toSet()) {
          final List<Offset> path = _compress(<Offset>[
            start,
            out,
            Offset(sx, out.dy),
            Offset(sx, y),
            Offset(ex, y),
            Offset(ex, incoming.dy),
            incoming,
            end,
          ]);
          if (!_isClear(path, obstacles, fromTile, toTile)) continue;
          double score = 0;
          for (int i = 1; i < path.length; i++) {
            score += (path[i] - path[i - 1]).distance;
          }
          // Prefer simpler routes when two routes are equally short.
          score += (path.length - 2) * 11;
          for (final List<Offset> previous in previousRoutes) {
            score += _interference(path, previous);
          }
          if (score < best) {
            best = score;
            selected = path;
          }
        }
      }
    }
    // A missing route must not be replaced with an apparently connected,
    // but physically misleading, straight line through another device.
    return selected;
  }

  static List<Offset> _compress(List<Offset> points) {
    final List<Offset> result = <Offset>[];
    for (final Offset point in points) {
      if (result.isNotEmpty && result.last == point) continue;
      while (result.length >= 2) {
        final Offset a = result[result.length - 2];
        final Offset b = result.last;
        if ((a.dx == b.dx && b.dx == point.dx) ||
            (a.dy == b.dy && b.dy == point.dy)) {
          result.removeLast();
        } else {
          break;
        }
      }
      result.add(point);
    }
    return result;
  }

  static bool _isClear(
    List<Offset> path,
    List<Rect> obstacles,
    Rect fromTile,
    Rect toTile,
  ) {
    if (path.length < 2) return false;
    for (int i = 1; i < path.length; i++) {
      final Offset a = path[i - 1];
      final Offset b = path[i];
      if (a.dx != b.dx && a.dy != b.dy) return false;
      for (final Rect tile in obstacles) {
        // Only the initial and final port stems may cross their own box.
        if (i == 1 && tile == fromTile.inflate(6)) continue;
        if (i == path.length - 1 && tile == toTile.inflate(6)) continue;
        if (_crosses(tile, a, b)) return false;
      }
    }
    return true;
  }

  static bool _crosses(Rect rect, Offset a, Offset b) {
    if (a.dx == b.dx) {
      return a.dx > rect.left &&
          a.dx < rect.right &&
          math.min(a.dy, b.dy) < rect.bottom &&
          math.max(a.dy, b.dy) > rect.top;
    }
    return a.dy > rect.top &&
        a.dy < rect.bottom &&
        math.min(a.dx, b.dx) < rect.right &&
        math.max(a.dx, b.dx) > rect.left;
  }

  static double _interference(List<Offset> route, List<Offset> previous) {
    double penalty = 0;
    for (int i = 1; i < route.length; i++) {
      final Offset a = route[i - 1];
      final Offset b = route[i];
      for (int j = 1; j < previous.length; j++) {
        final Offset c = previous[j - 1];
        final Offset d = previous[j];
        if (a.dy == b.dy && c.dy == d.dy && a.dy == c.dy) {
          final double common = math.min(math.max(a.dx, b.dx), math.max(c.dx, d.dx)) -
              math.max(math.min(a.dx, b.dx), math.min(c.dx, d.dx));
          if (common > 0) penalty += common * 3;
        } else if (a.dx == b.dx && c.dx == d.dx && a.dx == c.dx) {
          final double common = math.min(math.max(a.dy, b.dy), math.max(c.dy, d.dy)) -
              math.max(math.min(a.dy, b.dy), math.min(c.dy, d.dy));
          if (common > 0) penalty += common * 3;
        } else if (a.dy == b.dy && c.dx == d.dx) {
          if (c.dx > math.min(a.dx, b.dx) &&
              c.dx < math.max(a.dx, b.dx) &&
              a.dy > math.min(c.dy, d.dy) &&
              a.dy < math.max(c.dy, d.dy)) {
            penalty += 45;
          }
        } else if (a.dx == b.dx && c.dy == d.dy) {
          if (a.dx > math.min(c.dx, d.dx) &&
              a.dx < math.max(c.dx, d.dx) &&
              c.dy > math.min(a.dy, b.dy) &&
              c.dy < math.max(a.dy, b.dy)) {
            penalty += 45;
          }
        }
      }
    }
    return penalty;
  }
}
