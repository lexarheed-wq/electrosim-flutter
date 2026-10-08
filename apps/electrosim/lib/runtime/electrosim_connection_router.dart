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
  }) {
    if (_disposed) return Future.value(null);
    _dirty.add(connectionId);
    final job = _Job(_Request(circuit, layout, [connectionId]));
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
