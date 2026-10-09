import 'dart:ui';

import 'cabinet_layout.dart';

/// Purely graphical orthogonal wire routing via an authored wiring duct.
/// Physical wires and the electrical circuit remain unchanged.
///
/// It returns intermediate world-space vertices. No diagonal segment is ever
/// emitted. Routes are deterministic and may be rejected by the caller's
/// wire-safety validator if they obstruct another device.
abstract final class CabinetDuctWirePlanner {
  static List<Offset>? route({
    required Offset start,
    required Offset end,
    required CabinetLayout cabinet,
  }) {
    if (!start.dx.isFinite || !start.dy.isFinite ||
        !end.dx.isFinite || !end.dy.isFinite) return null;

    List<Offset>? best;
    double bestScore = double.infinity;
    for (final fixture in cabinet.fixtures) {
      if (fixture.kind != CabinetFixtureKind.wireDuct) continue;
      final r = fixture.bounds;
      final horizontal = r.width >= r.height;
      final List<Offset> candidate;
      if (horizontal) {
        final entryX = start.dx.clamp(r.left, r.right).toDouble();
        final exitX = end.dx.clamp(r.left, r.right).toDouble();
        final ductY = r.center.dy;
        candidate = [
          start,
          Offset(entryX, start.dy),
          Offset(entryX, ductY),
          Offset(exitX, ductY),
          Offset(exitX, end.dy),
          end,
        ];
      } else {
        final entryY = start.dy.clamp(r.top, r.bottom).toDouble();
        final exitY = end.dy.clamp(r.top, r.bottom).toDouble();
        final ductX = r.center.dx;
        candidate = [
          start,
          Offset(start.dx, entryY),
          Offset(ductX, entryY),
          Offset(ductX, exitY),
          Offset(end.dx, exitY),
          end,
        ];
      }
      final cleaned = _simplify(candidate);
      if (cleaned.length < 3 || !_isOrthogonal(cleaned)) continue;
      var score = 0.0;
      for (var i = 1; i < cleaned.length; i++) {
        score += (cleaned[i].dx - cleaned[i-1].dx).abs() +
            (cleaned[i].dy - cleaned[i-1].dy).abs();
      }
      if (score < bestScore) {
        bestScore = score;
        best = cleaned.sublist(1, cleaned.length - 1);
      }
    }
    return best;
  }

  static List<Offset> _simplify(List<Offset> points) {
    final output = <Offset>[];
    for (final p in points) {
      if (output.isNotEmpty && output.last == p) continue;
      output.add(p);
      while (output.length >= 3) {
        final a = output[output.length - 3];
        final b = output[output.length - 2];
        final c = output.last;
        if ((a.dx == b.dx && b.dx == c.dx) ||
            (a.dy == b.dy && b.dy == c.dy)) {
          output.removeAt(output.length - 2);
        } else {
          break;
        }
      }
    }
    return output;
  }

  static bool _isOrthogonal(List<Offset> points) {
    for (var i = 1; i < points.length; i++) {
      if (points[i].dx != points[i-1].dx &&
          points[i].dy != points[i-1].dy) return false;
    }
    return true;
  }
}
