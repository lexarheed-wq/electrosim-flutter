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
    required this.occupiedExcludingStartNet,
    required this.terminalBuckets,
    required this.bucketSize,
  });

  final CircuitState circuit;
  final CircuitVisualLayout layout;
  final TerminalId startTerminalId;
  final CircuitGeometryIndex geometry;
  final TopologyGraph topology;
  final Offset? start;
  final String? startOwner;
  final String? startNetId;
  final List<RoutingObstacle> baseObstacles;
  final List<_NetWirePath> occupiedExcludingStartNet;
  final Map<_TerminalBucket, List<MapEntry<TerminalId, Offset>>> terminalBuckets;
  final double bucketSize;
}

final class _NetWirePath {
  const _NetWirePath(this.netId, this.path);

  final String netId;
  final OrthogonalWirePath path;
}

final class _TerminalBucket {
  const _TerminalBucket(this.x, this.y);

  final int x;
  final int y;

  @override
  bool operator ==(Object other) =>
      other is _TerminalBucket && other.x == x && other.y == y;

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

    final List<_NetWirePath> occupied = <_NetWirePath>[];
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
          _NetWirePath(
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
    final Map<_TerminalBucket, List<MapEntry<TerminalId, Offset>>> buckets =
        <_TerminalBucket, List<MapEntry<TerminalId, Offset>>>{};
    for (final MapEntry<TerminalId, Offset> entry
        in geometry.terminalPositions.entries) {
      if (entry.key == startTerminalId) continue;
      final _TerminalBucket bucket = _bucketFor(entry.value, bucketSize);
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
      occupiedExcludingStartNet: List<_NetWirePath>.unmodifiable(occupied),
      terminalBuckets: Map<_TerminalBucket,
          List<MapEntry<TerminalId, Offset>>>.unmodifiable(
        <_TerminalBucket, List<MapEntry<TerminalId, Offset>>>{
          for (final MapEntry<
              _TerminalBucket,
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

    Iterable<_NetWirePath> occupiedCandidates =
        session.occupiedExcludingStartNet;
    if (targetNetId != null && targetNetId != session.startNetId) {
      occupiedCandidates = occupiedCandidates.where(
        (_NetWirePath entry) => entry.netId != targetNetId,
      );
    }
    final List<OrthogonalWirePath> occupiedDifferentNetPaths =
        occupiedCandidates
            .where(
              (_NetWirePath entry) =>
                  _pathOverlapsRect(entry.path, localEnvelope),
            )
            .map((_NetWirePath entry) => entry.path)
            .toList(growable: false);

    return WirePreviewPlan(
      route: router.route(
        start: start,
        end: end,
        obstacles: localObstacles,
        occupiedDifferentNetPaths: occupiedDifferentNetPaths,
      ),
      snappedTargetTerminalId: targetId,
      endPoint: end,
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

  MapEntry<TerminalId, Offset>? _nearestTerminalPrepared({
    required WirePreviewSession session,
    required Offset pointer,
  }) {
    MapEntry<TerminalId, Offset>? best;
    double? bestDistance;
    final _TerminalBucket center = _bucketFor(pointer, session.bucketSize);
    for (var dx = -1; dx <= 1; dx++) {
      for (var dy = -1; dy <= 1; dy++) {
        final List<MapEntry<TerminalId, Offset>> candidates =
            session.terminalBuckets[
                  _TerminalBucket(center.x + dx, center.y + dy)
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

  static _TerminalBucket _bucketFor(Offset point, double bucketSize) =>
      _TerminalBucket(
        (point.dx / bucketSize).floor(),
        (point.dy / bucketSize).floor(),
      );
}
