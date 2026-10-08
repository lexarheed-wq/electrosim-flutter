import 'dart:async';
import 'dart:ui';

import 'package:electrosim_canvas/electrosim_canvas.dart';
import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:flutter/foundation.dart';

const _engine = CircuitWireLayoutEngine(
  router: OrthogonalWireRouter(
    grid: 24,
    obstacleClearance: 24,
    envelopePadding: 120,
  ),
);

final class _Request {
  const _Request(this.circuit, this.layout, this.connectionIds);
  final CircuitState circuit;
  final CircuitVisualLayout layout;
  final List<ConnectionId> connectionIds;
}

CircuitVisualLayout _route(_Request request) {
  var layout = request.layout;
  final present = request.circuit.connections.map((item) => item.id).toSet();
  for (final id in request.connectionIds) {
    if (!present.contains(id)) continue;
    layout = _engine.routeConnection(
      circuit: request.circuit,
      layout: layout,
      connectionId: id,
    );
  }
  return layout;
}

final class _Job {
  _Job(this.request);
  final _Request request;
  final completer = Completer<CircuitVisualLayout?>();
}

/// One active job and at most one queued latest request. On native Flutter,
/// compute performs expensive path finding outside the UI isolate. Superseded
/// queued requests are discarded rather than spawning an unbounded worker set.
final class ElectroSimConnectionRouter {
  bool _busy = false;
  bool _disposed = false;
  _Job? _pending;
  final Set<ConnectionId> _dirty = {};

  Future<CircuitVisualLayout?> route({
    required CircuitState circuit,
    required CircuitVisualLayout layout,
    required ConnectionId connectionId,
  }) => _enqueue(circuit, layout, <ConnectionId>[connectionId]);

  /// Geometry changes are not topology edits: only attached or newly
  /// obstructed wires need new paths. All pathfinding runs off the UI isolate.
  Future<CircuitVisualLayout?> routeChangedElement({
    required CircuitState circuit,
    required CircuitVisualLayout layout,
    required String elementId,
  }) {
    if (_disposed) return Future<CircuitVisualLayout?>.value(null);
    final CircuitGeometryIndex geometry =
        CircuitGeometryIndex.build(circuit, layout);
    final Rect? obstacle = geometry.elementRects[elementId]?.inflate(28);
    final List<ConnectionId> affected = <ConnectionId>[];
    for (final Connection wire in circuit.connections) {
      if (geometry.terminalOwners[wire.fromTerminalId] == elementId ||
          geometry.terminalOwners[wire.toTerminalId] == elementId) {
        affected.add(wire.id);
        continue;
      }
      if (obstacle == null) continue;
      final Offset? start = geometry.terminalPositions[wire.fromTerminalId];
      final Offset? end = geometry.terminalPositions[wire.toTerminalId];
      if (start == null || end == null) continue;
      final List<Offset> path = <Offset>[
        start,
        ...layout.routeFor(wire.id.value),
        end,
      ];
      for (var i = 1; i < path.length; i++) {
        if (Rect.fromPoints(path[i - 1], path[i])
            .inflate(1)
            .overlaps(obstacle)) {
          affected.add(wire.id);
          break;
        }
      }
    }
    return _enqueue(circuit, layout, affected);
  }

  Future<CircuitVisualLayout?> _enqueue(
    CircuitState circuit,
    CircuitVisualLayout layout,
    List<ConnectionId> ids,
  ) {
    if (_disposed) return Future<CircuitVisualLayout?>.value(null);
    if (ids.isEmpty) return Future<CircuitVisualLayout?>.value(layout);
    _dirty.addAll(ids);
    final _Job job = _Job(_Request(circuit, layout, ids));
    _pending?.completer.complete(null);
    _pending = job;
    unawaited(_drain());
    return job.completer.future;
  }

  Future<void> _drain() async {
    if (_busy) return;
    _busy = true;
    try {
      while (!_disposed && _pending != null) {
        final job = _pending!;
        _pending = null;
        try {
          // Carry all unfinished wires into the latest request. Replacing a
          // queued job must not leave its connection permanently provisional.
          final request = _Request(
            job.request.circuit,
            job.request.layout,
            List<ConnectionId>.of(_dirty),
          );
          final result = await compute(
            _route,
            request,
            debugLabel: 'electrosim-connection-route',
          );
          final obsolete = _disposed || _pending != null;
          if (!obsolete) _dirty.removeAll(request.connectionIds);
          job.completer.complete(obsolete ? null : result);
        } catch (error, stack) {
          job.completer.completeError(error, stack);
        }
      }
    } finally {
      _busy = false;
    }
  }

  void dispose() {
    _disposed = true;
    _pending?.completer.complete(null);
    _pending = null;
    _dirty.clear();
  }
}

/// Immediate, explicitly provisional display; no global search is performed.
/// The final router still accounts for port stubs, component obstacles and nets.
CircuitVisualLayout provisionalConnectionLayout({
  required CircuitState circuit,
  required CircuitVisualLayout layout,
  required Connection connection,
}) {
  final geometry = CircuitGeometryIndex.build(circuit, layout);
  final start = geometry.terminalPositions[connection.fromTerminalId];
  final end = geometry.terminalPositions[connection.toTerminalId];
  if (start == null || end == null) return layout;
  return CircuitVisualLayout(
    elementPositions: layout.elementPositions,
    elementSizes: layout.elementSizes,
    elementQuarterTurns: layout.elementQuarterTurns,
    defaultElementSize: layout.defaultElementSize,
    wireRoutes: {
      ...layout.wireRoutes,
      connection.id.value: start.dx == end.dx || start.dy == end.dy
          ? const <Offset>[]
          : <Offset>[Offset(end.dx, start.dy)],
    },
  );
}
