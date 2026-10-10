import 'dart:ui';

import 'cabinet_layout.dart';

/// Purely graphical orthogonal wire routing through connected authored ducts.
/// Physical wires and the electrical circuit remain unchanged.
///
/// It returns intermediate world-space vertices. No diagonal segment is ever
/// emitted. Routes are deterministic and reject device obstacles when supplied.
abstract final class CabinetDuctWirePlanner {
  static List<Offset>? route({
    required Offset start,
    required Offset end,
    required CabinetLayout cabinet,
    Iterable<Rect> obstacles = const [],
  }) {
    if (start == end ||
        !start.dx.isFinite ||
        !start.dy.isFinite ||
        !end.dx.isFinite ||
        !end.dy.isFinite) {
      return null;
    }

    final ducts =
        cabinet.fixtures
            .where((f) => f.kind == CabinetFixtureKind.wireDuct)
            .toList()
          ..sort((a, b) => a.id.compareTo(b.id));
    if (ducts.isEmpty) return null;
    Offset project(Offset p, CabinetFixture d) {
      final r = d.bounds;
      return r.width >= r.height
          ? Offset(p.dx.clamp(r.left, r.right).toDouble(), r.center.dy)
          : Offset(r.center.dx, p.dy.clamp(r.top, r.bottom).toDouble());
    }

    double distance(Offset a, Offset b) =>
        (a.dx - b.dx).abs() + (a.dy - b.dy).abs();
    int nearest(Offset p) {
      var result = 0;
      for (var i = 1; i < ducts.length; i++) {
        if (distance(p, project(p, ducts[i])) <
            distance(p, project(p, ducts[result]))) {
          result = i;
        }
      }
      return result;
    }

    final source = nearest(start), target = nearest(end);
    final entry = project(start, ducts[source]);
    final exit = project(end, ducts[target]);
    final nodes = <Offset>[];
    final edges = <int, Map<int, double>>{};
    final members = List.generate(ducts.length, (_) => <int>[]);
    int node(Offset p) {
      final existing = nodes.indexOf(p);
      if (existing >= 0) return existing;
      nodes.add(p);
      return nodes.length - 1;
    }

    void link(int a, int b) {
      if (!isClear([nodes[a], nodes[b]], obstacles: obstacles)) return;
      (edges[a] ??= {})[b] = distance(nodes[a], nodes[b]);
      (edges[b] ??= {})[a] = distance(nodes[a], nodes[b]);
    }

    members[source].add(node(entry));
    members[target].add(node(exit));
    for (var i = 0; i < ducts.length; i++) {
      for (var j = i + 1; j < ducts.length; j++) {
        final a = ducts[i].bounds, b = ducts[j].bounds;
        // Placement forbids overlaps, so closed rectangle contact also joins.
        if (a.right < b.left ||
            b.right < a.left ||
            a.bottom < b.top ||
            b.bottom < a.top) {
          continue;
        }
        // Project the actual shared rectangle onto both centerlines. A
        // perpendicular join may need two bends at an end/corner; extending
        // either centerline to their imaginary intersection can exit both
        // duct rectangles.
        final contact = a.intersect(b).center;
        final pa = project(contact, ducts[i]);
        final pb = project(contact, ducts[j]);
        final na = node(pa), nb = node(pb), nc = node(contact);
        members[i].add(na);
        members[j].add(nb);
        link(na, nc);
        link(nc, nb);
      }
    }
    for (final group in members) {
      for (var i = 0; i < group.length; i++) {
        for (var j = i + 1; j < group.length; j++) {
          link(group[i], group[j]);
        }
      }
    }
    final first = node(entry), last = node(exit);
    final costs = <int, double>{first: 0};
    final previous = <int, int>{};
    final visited = <int>{};
    while (true) {
      int? current;
      for (final n in costs.keys) {
        if (!visited.contains(n) &&
            (current == null || costs[n]! < costs[current]!)) {
          current = n;
        }
      }
      if (current == null) return null;
      if (current == last) break;
      visited.add(current);
      for (final edge in (edges[current] ?? <int, double>{}).entries) {
        final cost = costs[current]! + edge.value;
        if (cost < (costs[edge.key] ?? double.infinity)) {
          costs[edge.key] = cost;
          previous[edge.key] = current;
        }
      }
    }
    final middle = <Offset>[exit];
    var cursor = last;
    while (cursor != first) {
      cursor = previous[cursor]!;
      middle.insert(0, nodes[cursor]);
    }
    List<Offset>? lead(Offset a, Offset b) {
      for (final elbow in [Offset(a.dx, b.dy), Offset(b.dx, a.dy)]) {
        final points = _simplify([a, elbow, b]);
        if (isClear(points, obstacles: obstacles)) return points;
      }
      return null;
    }

    final incoming = lead(start, entry), outgoing = lead(exit, end);
    if (incoming == null || outgoing == null) return null;
    final result = _simplify([...incoming, ...middle, ...outgoing]);
    if (!_isOrthogonal(result)) return null;
    return result.sublist(1, result.length - 1);
  }

  /// Boundary contact is allowed; entering any device interior is rejected.
  static bool isClear(
    List<Offset> points, {
    Iterable<Rect> obstacles = const [],
  }) {
    for (var i = 1; i < points.length; i++) {
      final a = points[i - 1], b = points[i];
      for (final r in obstacles) {
        if (a.dx == b.dx &&
            a.dx > r.left &&
            a.dx < r.right &&
            (a.dy < b.dy ? a.dy : b.dy) < r.bottom &&
            (a.dy > b.dy ? a.dy : b.dy) > r.top) {
          return false;
        }
        if (a.dy == b.dy &&
            a.dy > r.top &&
            a.dy < r.bottom &&
            (a.dx < b.dx ? a.dx : b.dx) < r.right &&
            (a.dx > b.dx ? a.dx : b.dx) > r.left) {
          return false;
        }
      }
    }
    return true;
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
        if ((a.dx == b.dx && b.dx == c.dx) || (a.dy == b.dy && b.dy == c.dy)) {
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
      if (points[i].dx != points[i - 1].dx &&
          points[i].dy != points[i - 1].dy) {
        return false;
      }
    }
    return true;
  }
}
