import 'dart:ui';

import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:electrosim_topology/electrosim_topology.dart';

import 'canvas_geometry.dart';
import 'circuit_visual_layout.dart';
import 'orthogonal_wire_router.dart';
import 'wire_geometry.dart';

final class CircuitWireLayoutEngine {
  const CircuitWireLayoutEngine({
    required this.router,
    this.topologyEngine = const TopologyEngine(),
  });

  final OrthogonalWireRouter router;
  final TopologyEngine topologyEngine;

  /// Routes only the added connection. Other conductors remain fixed and act
  /// as obstacles, classified against the NEW topology (nets may have merged).
  /// Call [routeAll] when component geometry changes or global optimization
  /// is explicitly requested, not after each electrical connection.
  CircuitVisualLayout routeConnection({
    required CircuitState circuit,
    required CircuitVisualLayout layout,
    required ConnectionId connectionId,
  }) {
    final connection = circuit.connections.firstWhere(
      (item) => item.id == connectionId,
      orElse: () => throw ArgumentError.value(connectionId, 'connectionId'),
    );
    final geometry = CircuitGeometryIndex.build(circuit, layout);
    final topology = topologyEngine.compile(circuit);
    final occupied = <_OccupiedRoute>[];
    for (final item in circuit.connections) {
      if (item.id == connectionId) continue;
      final start = geometry.terminalPositions[item.fromTerminalId];
      final end = geometry.terminalPositions[item.toTerminalId];
      if (start == null || end == null || start == end) continue;
      final path = _orthogonalPathOrNull([
        start,
        ...layout.routeFor(item.id.value),
        end,
      ]);
      if (path != null) {
        occupied.add(
          _OccupiedRoute(netId: _connectionNetId(item, topology), path: path),
        );
      }
    }
    return _routePass(
      circuit: circuit,
      layout: layout,
      geometry: geometry,
      topology: topology,
      orderedConnections: [connection],
      initialOccupied: occupied,
    ).layout;
  }

  CircuitVisualLayout routeAll({
    required CircuitState circuit,
    required CircuitVisualLayout layout,
  }) {
    final CircuitGeometryIndex geometry = CircuitGeometryIndex.build(
      circuit,
      layout,
    );
    final TopologyGraph topology = topologyEngine.compile(circuit);
    final List<Connection> original = List<Connection>.unmodifiable(
      circuit.connections,
    );

    final List<List<Connection>> orders = <List<Connection>>[
      original,
      original.reversed.toList(growable: false),
      <Connection>[...original]..sort((Connection a, Connection b) {
        final double aDistance = _routingDistance(a, geometry);
        final double bDistance = _routingDistance(b, geometry);
        final int byDistance = bDistance.compareTo(aDistance);
        if (byDistance != 0) return byDistance;
        return a.id.value.compareTo(b.id.value);
      }),
    ];

    _RoutePass? best;
    for (final List<Connection> order in orders) {
      final _RoutePass candidate = _routePass(
        circuit: circuit,
        layout: layout,
        geometry: geometry,
        topology: topology,
        orderedConnections: order,
      );
      if (best == null || candidate.isBetterThan(best)) {
        best = candidate;
      }
    }
    return best?.layout ?? layout;
  }

  _RoutePass _routePass({
    required CircuitState circuit,
    required CircuitVisualLayout layout,
    required CircuitGeometryIndex geometry,
    required TopologyGraph topology,
    required List<Connection> orderedConnections,
    List<_OccupiedRoute> initialOccupied = const [],
  }) {
    final Map<String, List<Offset>> nextRoutes = <String, List<Offset>>{
      ...layout.wireRoutes,
    };
    final List<_OccupiedRoute> occupied = <_OccupiedRoute>[...initialOccupied];
    var eligibleCount = 0;
    var resolvedCount = 0;
    var differentNetCrossingCount = 0;
    var differentNetOverlapCount = 0;
    var totalRouteLength = 0.0;
    var totalBendCount = 0;

    final List<RoutingObstacle> obstacles = geometry.elementRects.values
        .map((Rect rect) => RoutingObstacle(bounds: rect))
        .toList(growable: false);

    for (final Connection connection in orderedConnections) {
      final Offset? start =
          geometry.terminalPositions[connection.fromTerminalId];
      final Offset? end = geometry.terminalPositions[connection.toTerminalId];
      final Offset? startRouting =
          geometry.terminalRoutingPositions[connection.fromTerminalId];
      final Offset? endRouting =
          geometry.terminalRoutingPositions[connection.toTerminalId];
      if (start == null ||
          end == null ||
          startRouting == null ||
          endRouting == null ||
          start == end) {
        continue;
      }
      eligibleCount++;

      final String netId = _connectionNetId(connection, topology);
      final List<OrthogonalWirePath> differentNetPaths = occupied
          .where((_OccupiedRoute item) => item.netId != netId)
          .map((_OccupiedRoute item) => item.path)
          .toList(growable: false);

      final String? fromOwner =
          geometry.terminalOwners[connection.fromTerminalId];
      final String? toOwner = geometry.terminalOwners[connection.toTerminalId];
      final Rect? fromRect = fromOwner == null
          ? null
          : geometry.elementRects[fromOwner];
      final Rect? toRect = toOwner == null
          ? null
          : geometry.elementRects[toOwner];
      final Offset startStub = fromRect == null
          ? startRouting
          : _terminalStubPoint(startRouting, fromRect);
      final Offset endStub = toRect == null
          ? endRouting
          : _terminalStubPoint(endRouting, toRect);

      WireRouteResult result = router.route(
        start: startStub,
        end: endStub,
        obstacles: obstacles,
        occupiedDifferentNetPaths: differentNetPaths,
      );

      // Conductors must never make a valid electrical connection impossible.
      // If congestion defeats the preferred search, retry without conductor
      // occupancy. Components remain hard obstacles; wire crossings become a
      // renderer concern rather than an electrical refusal.
      if (!result.isResolved) {
        result = router.route(
          start: startStub,
          end: endStub,
          obstacles: obstacles,
        );
      }

      OrthogonalWirePath? path;
      if (result.isResolved) {
        path = _composeStubbedPath(
          start: start,
          startRouting: startRouting,
          startStub: startStub,
          routed: result.path!,
          endStub: endStub,
          endRouting: endRouting,
          end: end,
        );
      }

      path ??= _existingOrthogonalPath(
        start: start,
        startRouting: startRouting,
        endRouting: endRouting,
        end: end,
        intermediate: layout.routeFor(connection.id.value),
      );

      // Absolute visual fallback. It preserves orthogonality and connectivity;
      // normal routing should make this branch exceptional.
      path ??= _emergencyOrthogonalPath(start, end);

      differentNetCrossingCount += WireRouteSafety.countPerpendicularCrossings(
        candidate: path,
        occupiedDifferentNetPaths: differentNetPaths,
      );
      if (WireRouteSafety.hasCollinearOverlap(
        candidate: path,
        occupiedDifferentNetPaths: differentNetPaths,
      )) {
        differentNetOverlapCount += 1;
      }
      totalRouteLength += path.segments.fold<double>(
        0,
        (double sum, OrthogonalSegment segment) => sum + segment.length,
      );
      totalBendCount += path.bends.length;

      nextRoutes[connection.id.value] = path.points.length <= 2
          ? const <Offset>[]
          : List<Offset>.unmodifiable(
              path.points.sublist(1, path.points.length - 1),
            );
      occupied.add(_OccupiedRoute(netId: netId, path: path));
      resolvedCount++;
    }

    return _RoutePass(
      layout: CircuitVisualLayout(
        elementPositions: layout.elementPositions,
        elementSizes: layout.elementSizes,
        wireRoutes: nextRoutes,
        elementQuarterTurns: layout.elementQuarterTurns,
        defaultElementSize: layout.defaultElementSize,
      ),
      resolvedCount: resolvedCount,
      eligibleCount: eligibleCount,
      differentNetCrossingCount: differentNetCrossingCount,
      differentNetOverlapCount: differentNetOverlapCount,
      totalRouteLength: totalRouteLength,
      totalBendCount: totalBendCount,
    );
  }

  static String _connectionNetId(
    Connection connection,
    TopologyGraph topology,
  ) {
    final String? from = topology.terminalToNode[connection.fromTerminalId];
    final String? to = topology.terminalToNode[connection.toTerminalId];
    if (connection.enabled && from != null && from == to) return from;
    return 'connection:${connection.id.value}';
  }

  static double _routingDistance(
    Connection connection,
    CircuitGeometryIndex geometry,
  ) {
    final Offset? start =
        geometry.terminalRoutingPositions[connection.fromTerminalId];
    final Offset? end =
        geometry.terminalRoutingPositions[connection.toTerminalId];
    if (start == null || end == null) return 0;
    return (start.dx - end.dx).abs() + (start.dy - end.dy).abs();
  }

  Offset _terminalStubPoint(Offset terminal, Rect ownerRect) {
    final Offset direction = _terminalOutwardDirection(terminal, ownerRect);
    final double distance = router.obstacleClearance + router.grid;
    return terminal + direction * distance;
  }

  static Offset _terminalOutwardDirection(Offset terminal, Rect rect) {
    const double epsilon = 0.001;
    if ((terminal.dx - rect.left).abs() <= epsilon) {
      return const Offset(-1, 0);
    }
    if ((terminal.dx - rect.right).abs() <= epsilon) {
      return const Offset(1, 0);
    }
    if ((terminal.dy - rect.top).abs() <= epsilon) {
      return const Offset(0, -1);
    }
    if ((terminal.dy - rect.bottom).abs() <= epsilon) {
      return const Offset(0, 1);
    }

    final Map<Offset, double> distances = <Offset, double>{
      const Offset(-1, 0): (terminal.dx - rect.left).abs(),
      const Offset(1, 0): (terminal.dx - rect.right).abs(),
      const Offset(0, -1): (terminal.dy - rect.top).abs(),
      const Offset(0, 1): (terminal.dy - rect.bottom).abs(),
    };
    return distances.entries
        .reduce(
          (MapEntry<Offset, double> a, MapEntry<Offset, double> b) =>
              a.value <= b.value ? a : b,
        )
        .key;
  }

  static OrthogonalWirePath? _composeStubbedPath({
    required Offset start,
    required Offset startRouting,
    required Offset startStub,
    required OrthogonalWirePath routed,
    required Offset endStub,
    required Offset endRouting,
    required Offset end,
  }) {
    final List<Offset> raw = <Offset>[
      start,
      if (startRouting != start) startRouting,
      if (startStub != startRouting) startStub,
      ...routed.points
          .skip(1)
          .take(routed.points.length > 2 ? routed.points.length - 2 : 0),
      if (endStub != endRouting) endStub,
      if (endRouting != end) endRouting,
      end,
    ];
    return _orthogonalPathOrNull(raw);
  }

  static OrthogonalWirePath? _existingOrthogonalPath({
    required Offset start,
    required Offset startRouting,
    required Offset endRouting,
    required Offset end,
    required List<Offset> intermediate,
  }) => _orthogonalPathOrNull(<Offset>[
    start,
    if (startRouting != start) startRouting,
    ...intermediate,
    if (endRouting != end) endRouting,
    end,
  ]);

  static OrthogonalWirePath _emergencyOrthogonalPath(Offset start, Offset end) {
    if (start.dx == end.dx || start.dy == end.dy) {
      return OrthogonalWirePath(points: <Offset>[start, end]);
    }
    return OrthogonalWirePath(
      points: <Offset>[start, Offset(end.dx, start.dy), end],
    );
  }

  static OrthogonalWirePath? _orthogonalPathOrNull(List<Offset> raw) {
    final List<Offset> points = <Offset>[];
    for (final Offset point in raw) {
      if (points.isEmpty || points.last != point) points.add(point);
    }
    var index = 1;
    while (index < points.length - 1) {
      final Offset before = points[index - 1];
      final Offset current = points[index];
      final Offset after = points[index + 1];
      final bool horizontal = before.dy == current.dy && current.dy == after.dy;
      final bool vertical = before.dx == current.dx && current.dx == after.dx;
      if (horizontal || vertical) {
        points.removeAt(index);
      } else {
        index++;
      }
    }
    if (points.length < 2) return null;
    try {
      return OrthogonalWirePath(points: points);
    } on ArgumentError {
      return null;
    }
  }
}

final class _OccupiedRoute {
  const _OccupiedRoute({required this.netId, required this.path});

  final String netId;
  final OrthogonalWirePath path;
}

final class _RoutePass {
  const _RoutePass({
    required this.layout,
    required this.resolvedCount,
    required this.eligibleCount,
    required this.differentNetCrossingCount,
    required this.differentNetOverlapCount,
    required this.totalRouteLength,
    required this.totalBendCount,
  });

  final CircuitVisualLayout layout;
  final int resolvedCount;
  final int eligibleCount;
  final int differentNetCrossingCount;
  final int differentNetOverlapCount;
  final double totalRouteLength;
  final int totalBendCount;

  bool get complete => resolvedCount >= eligibleCount;

  bool isBetterThan(_RoutePass other) {
    if (resolvedCount != other.resolvedCount) {
      return resolvedCount > other.resolvedCount;
    }
    if (differentNetOverlapCount != other.differentNetOverlapCount) {
      return differentNetOverlapCount < other.differentNetOverlapCount;
    }
    if (differentNetCrossingCount != other.differentNetCrossingCount) {
      return differentNetCrossingCount < other.differentNetCrossingCount;
    }
    if (totalBendCount != other.totalBendCount) {
      return totalBendCount < other.totalBendCount;
    }
    return totalRouteLength < other.totalRouteLength;
  }
}
