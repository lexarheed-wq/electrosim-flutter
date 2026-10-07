import 'dart:ui';

import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:electrosim_topology/electrosim_topology.dart';

import 'canvas_geometry.dart';
import 'circuit_visual_layout.dart';
import 'orthogonal_wire_router.dart';
import 'wire_geometry.dart';

final class WirePreviewPlan {
  const WirePreviewPlan({
    required this.route,
    required this.snappedTargetTerminalId,
    required this.endPoint,
  });

  final WireRouteResult route;
  final TerminalId? snappedTargetTerminalId;
  final Offset endPoint;
}

/// Immutable routing context prepared once when a wiring gesture starts.
///
/// Dense canvases must not rebuild geometry, topology, obstacle lists and every
/// existing wire path on every pointer event. This session owns that stable
/// data and exposes only the pointer-dependent work to [WirePreviewPlanner].
final class WirePreviewSession {
  WirePreviewSession._({
    required this.circuit,
    required this.layout,
    required this.startTerminalId,
    required this.geometry,
    required this.topology,
    required this.start,
    required this.startOwner,
    required this.startNetId,
    required this.baseObstacles,
    required List<NetWirePath> occupiedExcludingStartNet,
    required Map<TerminalBucket, List<MapEntry<TerminalId, Offset>>>
        terminalBuckets,
    required this.bucketSize,
  }) : _occupiedExcludingStartNet = occupiedExcludingStartNet,
       _terminalBuckets = terminalBuckets;

  final CircuitState circuit;
  final CircuitVisualLayout layout;
  final TerminalId startTerminalId;
  final CircuitGeometryIndex geometry;
  final TopologyGraph topology;
  final Offset? start;
  final String? startOwner;
  final String? startNetId;
  final List<RoutingObstacle> baseObstacles;
  final List<NetWirePath> _occupiedExcludingStartNet;
  final Map<TerminalBucket, List<MapEntry<TerminalId, Offset>>> _terminalBuckets;
  final double bucketSize;
}

final class NetWirePath {
  const NetWirePath(this.netId, this.path);

  final String netId;
  final OrthogonalWirePath path;
}

final class TerminalBucket {
  const TerminalBucket(this.x, this.y);

  final int x;
  final int y;

  @override
  bool operator ==(Object other) =>
      other is TerminalBucket && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);
}

final class WirePreviewPlanner {
  const WirePreviewPlanner({
    required this.router,
    required this.terminalSnapRadius,
    this.topologyEngine = const TopologyEngine(),
  }) : assert(terminalSnapRadius > 0);

  final OrthogonalWireRouter router;
  final double terminalSnapRadius;
  final TopologyEngine topologyEngine;

  /// Builds the stable part of a wire-preview gesture once.
  WirePreviewSession prepare({
    required CircuitState circuit,
    required CircuitVisualLayout layout,
    required TerminalId startTerminalId,
  }) {
    final CircuitGeometryIndex geometry = CircuitGeometryIndex.build(
      circuit,
      layout,
    );
    final TopologyGraph topology = topologyEngine.compile(circuit);
    final Offset? start = geometry.terminalPositions[startTerminalId];
    final String? startOwner = geometry.terminalOwners[startTerminalId];
    final String? startNetId = topology.terminalToNode[startTerminalId];

    final List<RoutingObstacle> baseObstacles = geometry.elementRects.entries
        .where((MapEntry<String, Rect> entry) => entry.key != startOwner)
        .map(
          (MapEntry<String, Rect> entry) => RoutingObstacle(bounds: entry.value),
        )
        .toList(growable: false);

    final List<NetWirePath> occupied = <NetWirePath>[];
    for (final Connection connection in circuit.connections) {
      final String connectionNet = _connectionNetId(connection, topology);
      if (startNetId != null && connectionNet == startNetId) continue;

      final Offset? connectionStart =
          geometry.terminalPositions[connection.fromTerminalId];
      final Offset? connectionEnd =
          geometry.terminalPositions[connection.toTerminalId];
      if (connectionStart == null || connectionEnd == null) continue;

      try {
        occupied.add(
          NetWirePath(
            connectionNet,
            OrthogonalWirePath(
              points: <Offset>[
                connectionStart,
                ...layout.routeFor(connection.id.value),
                connectionEnd,
              ],
            ),
          ),
        );
      } on ArgumentError {
        // Legacy diagonal routes are ignored by the new orthogonal preview.
      }
    }

    final double bucketSize = terminalSnapRadius;
    final Map<TerminalBucket, List<MapEntry<TerminalId, Offset>>> buckets =
        <TerminalBucket, List<MapEntry<TerminalId, Offset>>>{};
    for (final MapEntry<TerminalId, Offset> entry
        in geometry.terminalPositions.entries) {
      if (entry.key == startTerminalId) continue;
      final TerminalBucket bucket = _bucketFor(entry.value, bucketSize);
      buckets.putIfAbsent(
        bucket,
        () => <MapEntry<TerminalId, Offset>>[],
      ).add(entry);
    }

    return WirePreviewSession._(
      circuit: circuit,
      layout: layout,
      startTerminalId: startTerminalId,
      geometry: geometry,
      topology: topology,
      start: start,
      startOwner: startOwner,
      startNetId: startNetId,
      baseObstacles: List<RoutingObstacle>.unmodifiable(baseObstacles),
      occupiedExcludingStartNet: List<NetWirePath>.unmodifiable(occupied),
      terminalBuckets: Map<TerminalBucket,
          List<MapEntry<TerminalId, Offset>>>.unmodifiable(
        <TerminalBucket, List<MapEntry<TerminalId, Offset>>>{
          for (final MapEntry<
              TerminalBucket,
              List<MapEntry<TerminalId, Offset>>> entry in buckets.entries)
            entry.key: List<MapEntry<TerminalId, Offset>>.unmodifiable(entry.value),
        },
      ),
      bucketSize: bucketSize,
    );
  }

  WirePreviewPlan plan({
    required CircuitState circuit,
    required CircuitVisualLayout layout,
    required TerminalId startTerminalId,
    required Offset pointerWorldPosition,
  }) => planPrepared(
    session: prepare(
      circuit: circuit,
      layout: layout,
      startTerminalId: startTerminalId,
    ),
    pointerWorldPosition: pointerWorldPosition,
  );

  /// Pointer-hot-path plan using a precomputed [WirePreviewSession].
  WirePreviewPlan planPrepared({
    required WirePreviewSession session,
    required Offset pointerWorldPosition,
  }) {
    final Offset? start = session.start;
    if (start == null) {
      return WirePreviewPlan(
        route: const WireRouteResult.unresolved(
          WireRouteFailure.noCrossingFreeRoute,
        ),
        snappedTargetTerminalId: null,
        endPoint: pointerWorldPosition,
      );
    }

    final MapEntry<TerminalId, Offset>? target = _nearestTerminalPrepared(
      session: session,
      pointer: pointerWorldPosition,
    );
    final TerminalId? targetId = target?.key;
    final Offset end = target?.value ?? pointerWorldPosition;
    if (start == end) {
      return WirePreviewPlan(
        route: const WireRouteResult.unresolved(
          WireRouteFailure.noCrossingFreeRoute,
        ),
        snappedTargetTerminalId: targetId,
        endPoint: end,
      );
    }

    final String? targetOwner = targetId == null
        ? null
        : session.geometry.terminalOwners[targetId];
    final String? targetNetId = targetId == null
        ? null
        : session.topology.terminalToNode[targetId];

    final List<RoutingObstacle> obstacles = targetOwner == null ||
            targetOwner == session.startOwner
        ? session.baseObstacles
        : session.geometry.elementRects.entries
            .where(
              (MapEntry<String, Rect> entry) =>
                  entry.key != session.startOwner && entry.key != targetOwner,
            )
            .map(
              (MapEntry<String, Rect> entry) =>
                  RoutingObstacle(bounds: entry.value),
            )
            .toList(growable: false);

    // Only geometry near the active start/end corridor can influence this
    // preview. Feeding the router every component and every established wire
    // makes pointer cost grow with the entire board and was the main dense-
    // canvas regression observed on physical Mac hardware.
    final double localPadding =
        router.envelopePadding + router.obstacleClearance + router.grid * 2;
    final Rect localEnvelope = Rect.fromLTRB(
      start.dx < end.dx ? start.dx : end.dx,
      start.dy < end.dy ? start.dy : end.dy,
      start.dx > end.dx ? start.dx : end.dx,
      start.dy > end.dy ? start.dy : end.dy,
    ).inflate(localPadding);
    final List<RoutingObstacle> localObstacles = obstacles
        .where(
          (RoutingObstacle obstacle) =>
              obstacle.bounds.inflate(router.obstacleClearance).overlaps(
                localEnvelope,
              ) ||
              localEnvelope.contains(obstacle.bounds.center),
        )
        .toList(growable: false);

    Iterable<NetWirePath> occupiedCandidates =
        session._occupiedExcludingStartNet;
    if (targetNetId != null && targetNetId != session.startNetId) {
      occupiedCandidates = occupiedCandidates.where(
        (NetWirePath entry) => entry.netId != targetNetId,
      );
    }
    final List<OrthogonalWirePath> occupiedDifferentNetPaths =
        occupiedCandidates
            .where(
              (NetWirePath entry) =>
                  _pathOverlapsRect(entry.path, localEnvelope),
            )
            .map((NetWirePath entry) => entry.path)
            .toList(growable: false);

    return WirePreviewPlan(
      route: _fastPreviewRoute(
        start: start,
        end: end,
        envelope: localEnvelope,
        obstacles: localObstacles,
        occupiedDifferentNetPaths: occupiedDifferentNetPaths,
      ),
      snappedTargetTerminalId: targetId,
      endPoint: end,
    );
  }

  WireRouteResult _fastPreviewRoute({
    required Offset start,
    required Offset end,
    required Rect envelope,
    required List<RoutingObstacle> obstacles,
    required List<OrthogonalWirePath> occupiedDifferentNetPaths,
  }) {
    final List<RoutingObstacle> expanded = obstacles
        .map(
          (RoutingObstacle obstacle) =>
              obstacle.expanded(router.obstacleClearance),
        )
        .toList(growable: false);
    final List<List<Offset>> candidates = <List<Offset>>[];

    void addCandidate(List<Offset> raw) {
      final List<Offset> normalized = _normalizePreviewPoints(raw);
      if (normalized.length >= 2) candidates.add(normalized);
    }

    if (start.dx == end.dx || start.dy == end.dy) {
      addCandidate(<Offset>[start, end]);
    } else {
      addCandidate(<Offset>[start, Offset(end.dx, start.dy), end]);
      addCandidate(<Offset>[start, Offset(start.dx, end.dy), end]);
    }

    final double middleX = _snapPreview((start.dx + end.dx) / 2);
    final double middleY = _snapPreview((start.dy + end.dy) / 2);
    addCandidate(<Offset>[
      start,
      Offset(middleX, start.dy),
      Offset(middleX, end.dy),
      end,
    ]);
    addCandidate(<Offset>[
      start,
      Offset(start.dx, middleY),
      Offset(end.dx, middleY),
      end,
    ]);

    final List<double> xs = <double>[
      _snapPreview(envelope.left),
      _snapPreview(envelope.right),
    ];
    final List<double> ys = <double>[
      _snapPreview(envelope.top),
      _snapPreview(envelope.bottom),
    ];
    for (final RoutingObstacle obstacle in expanded) {
      xs
        ..add(_snapPreview(obstacle.bounds.left - router.grid))
        ..add(_snapPreview(obstacle.bounds.right + router.grid));
      ys
        ..add(_snapPreview(obstacle.bounds.top - router.grid))
        ..add(_snapPreview(obstacle.bounds.bottom + router.grid));
    }

    for (final double x in xs.toSet()) {
      addCandidate(<Offset>[
        start,
        Offset(x, start.dy),
        Offset(x, end.dy),
        end,
      ]);
    }
    for (final double y in ys.toSet()) {
      addCandidate(<Offset>[
        start,
        Offset(start.dx, y),
        Offset(end.dx, y),
        end,
      ]);
    }

    final OrthogonalWirePath? clean = _bestPreviewCandidate(
      candidates,
      obstacles: expanded,
      occupiedDifferentNetPaths: occupiedDifferentNetPaths,
      allowBridgedCrossings: false,
    );
    if (clean != null) return WireRouteResult.resolved(clean);

    final OrthogonalWirePath? bridged = _bestPreviewCandidate(
      candidates,
      obstacles: expanded,
      occupiedDifferentNetPaths: occupiedDifferentNetPaths,
      allowBridgedCrossings: true,
    );
    if (bridged != null) {
      return WireRouteResult.resolved(
        bridged,
        usesBridgedCrossing: WireRouteSafety.countPerpendicularCrossings(
              candidate: bridged,
              occupiedDifferentNetPaths: occupiedDifferentNetPaths,
            ) >
            0,
      );
    }

    return const WireRouteResult.unresolved(
      WireRouteFailure.noCrossingFreeRoute,
    );
  }

  OrthogonalWirePath? _bestPreviewCandidate(
    List<List<Offset>> candidates, {
    required List<RoutingObstacle> obstacles,
    required List<OrthogonalWirePath> occupiedDifferentNetPaths,
    required bool allowBridgedCrossings,
  }) {
    OrthogonalWirePath? best;
    double? bestCost;
    for (final List<Offset> points in candidates) {
      OrthogonalWirePath candidate;
      try {
        candidate = OrthogonalWirePath(points: points);
      } on ArgumentError {
        continue;
      }
      if (_previewHitsObstacle(candidate, obstacles)) continue;

      if (allowBridgedCrossings) {
        if (WireRouteSafety.hasCollinearOverlap(
          candidate: candidate,
          occupiedDifferentNetPaths: occupiedDifferentNetPaths,
        )) {
          continue;
        }
      } else if (WireRouteSafety.hasDifferentNetCrossing(
        candidate: candidate,
        occupiedDifferentNetPaths: occupiedDifferentNetPaths,
      )) {
        continue;
      }

      final int crossings = allowBridgedCrossings
          ? WireRouteSafety.countPerpendicularCrossings(
              candidate: candidate,
              occupiedDifferentNetPaths: occupiedDifferentNetPaths,
            )
          : 0;
      double length = 0;
      for (final OrthogonalSegment segment in candidate.segments) {
        length += segment.length;
      }
      final double cost =
          length +
          candidate.bends.length * router.bendPenalty +
          crossings * router.crossingPenalty;
      if (bestCost == null || cost < bestCost) {
        best = candidate;
        bestCost = cost;
      }
    }
    return best;
  }

  static bool _previewHitsObstacle(
    OrthogonalWirePath path,
    List<RoutingObstacle> obstacles,
  ) {
    const double epsilon = 0.001;
    for (final OrthogonalSegment segment in path.segments) {
      for (final RoutingObstacle obstacle in obstacles) {
        final Rect rect = obstacle.bounds;
        if (segment.axis == WireAxis.horizontal) {
          final bool yInside =
              segment.start.dy > rect.top + epsilon &&
              segment.start.dy < rect.bottom - epsilon;
          final bool xOverlap =
              segment.maxX > rect.left + epsilon &&
              segment.minX < rect.right - epsilon;
          if (yInside && xOverlap) return true;
        } else {
          final bool xInside =
              segment.start.dx > rect.left + epsilon &&
              segment.start.dx < rect.right - epsilon;
          final bool yOverlap =
              segment.maxY > rect.top + epsilon &&
              segment.minY < rect.bottom - epsilon;
          if (xInside && yOverlap) return true;
        }
      }
    }
    return false;
  }

  List<Offset> _normalizePreviewPoints(List<Offset> raw) {
    final List<Offset> points = <Offset>[];
    for (final Offset point in raw) {
      if (points.isEmpty || points.last != point) points.add(point);
    }
    var changed = true;
    while (changed && points.length > 2) {
      changed = false;
      for (var i = 1; i < points.length - 1; i++) {
        final Offset a = points[i - 1];
        final Offset b = points[i];
        final Offset d = points[i + 1];
        if ((a.dx == b.dx && b.dx == d.dx) ||
            (a.dy == b.dy && b.dy == d.dy)) {
          points.removeAt(i);
          changed = true;
          break;
        }
      }
    }
    return points;
  }

  double _snapPreview(double value) =>
      (value / router.grid).roundToDouble() * router.grid;

  static String _connectionNetId(
    Connection connection,
    TopologyGraph topology,
  ) {
    final String? from = topology.terminalToNode[connection.fromTerminalId];
    final String? to = topology.terminalToNode[connection.toTerminalId];
    if (connection.enabled && from != null && from == to) return from;
    return 'connection:${connection.id.value}';
  }

  MapEntry<TerminalId, Offset>? _nearestTerminalPrepared({
    required WirePreviewSession session,
    required Offset pointer,
  }) {
    MapEntry<TerminalId, Offset>? best;
    double? bestDistance;
    final TerminalBucket center = _bucketFor(pointer, session.bucketSize);
    for (var dx = -1; dx <= 1; dx++) {
      for (var dy = -1; dy <= 1; dy++) {
        final List<MapEntry<TerminalId, Offset>> candidates =
            session._terminalBuckets[
                  TerminalBucket(center.x + dx, center.y + dy)
                ] ??
                const <MapEntry<TerminalId, Offset>>[];
        for (final MapEntry<TerminalId, Offset> entry in candidates) {
          final double distance = (entry.value - pointer).distance;
          if (distance > terminalSnapRadius) continue;
          final bool betterDistance =
              bestDistance == null || distance < bestDistance - 0.0001;
          final bool deterministicTie =
              bestDistance != null &&
              (distance - bestDistance).abs() <= 0.0001 &&
              (best == null || entry.key.value.compareTo(best.key.value) < 0);
          if (betterDistance || deterministicTie) {
            best = entry;
            bestDistance = distance;
          }
        }
      }
    }
    return best;
  }


  static bool _pathOverlapsRect(OrthogonalWirePath path, Rect rect) {
    for (final OrthogonalSegment segment in path.segments) {
      final Rect bounds = Rect.fromLTRB(
        segment.minX,
        segment.minY,
        segment.maxX,
        segment.maxY,
      ).inflate(0.5);
      if (bounds.overlaps(rect) || rect.contains(bounds.center)) return true;
    }
    return false;
  }

  static TerminalBucket _bucketFor(Offset point, double bucketSize) =>
      TerminalBucket(
        (point.dx / bucketSize).floor(),
        (point.dy / bucketSize).floor(),
      );
}
