import 'dart:ui';

import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:electrosim_topology/electrosim_topology.dart';

import 'canvas_geometry.dart';
import 'circuit_visual_layout.dart';
import 'wire_geometry.dart';

final class NonJunctionWireCrossing {
  const NonJunctionWireCrossing({
    required this.point,
    required this.firstConnectionId,
    required this.secondConnectionId,
  });

  final Offset point;
  final ConnectionId firstConnectionId;
  final ConnectionId secondConnectionId;
}

final class WireSemantics {
  WireSemantics({
    required Set<TerminalId> junctionTerminalIds,
    required Set<Offset> interiorJunctionPoints,
    required List<NonJunctionWireCrossing> nonJunctionCrossings,
  }) : junctionTerminalIds = Set<TerminalId>.unmodifiable(junctionTerminalIds),
       interiorJunctionPoints = Set<Offset>.unmodifiable(
         interiorJunctionPoints,
       ),
       nonJunctionCrossings = List<NonJunctionWireCrossing>.unmodifiable(
         nonJunctionCrossings,
       );

  final Set<TerminalId> junctionTerminalIds;

  /// Visual intersections between conductors that belong to the same
  /// electrical net. They may be rendered as filled junction dots.
  final Set<Offset> interiorJunctionPoints;

  /// Visual intersections between different electrical nets. They must be
  /// rendered as bridge/gap crossings and never become topology junctions.
  final List<NonJunctionWireCrossing> nonJunctionCrossings;
}

final class WireSemanticsAnalyzer {
  const WireSemanticsAnalyzer({
    this.topologyEngine = const TopologyEngine(),
  });

  final TopologyEngine topologyEngine;

  WireSemantics analyze({
    required CircuitState circuit,
    required CircuitVisualLayout layout,
  }) {
    final CircuitGeometryIndex geometry = CircuitGeometryIndex.build(
      circuit,
      layout,
    );
    final TopologyGraph topology = topologyEngine.compile(circuit);

    final Map<TerminalId, int> degree = <TerminalId, int>{};
    for (final Connection connection in circuit.connections) {
      if (!connection.enabled) continue;
      degree.update(
        connection.fromTerminalId,
        (int value) => value + 1,
        ifAbsent: () => 1,
      );
      degree.update(
        connection.toTerminalId,
        (int value) => value + 1,
        ifAbsent: () => 1,
      );
    }
    final Set<TerminalId> junctions = degree.entries
        .where((MapEntry<TerminalId, int> entry) => entry.value > 1)
        .map((MapEntry<TerminalId, int> entry) => entry.key)
        .toSet();

    final Map<ConnectionId, OrthogonalWirePath> paths =
        <ConnectionId, OrthogonalWirePath>{};
    for (final Connection connection in circuit.connections) {
      final Offset? start =
          geometry.terminalPositions[connection.fromTerminalId];
      final Offset? end = geometry.terminalPositions[connection.toTerminalId];
      if (start == null || end == null || start == end) continue;
      try {
        paths[connection.id] = OrthogonalWirePath(
          points: <Offset>[start, ...layout.routeFor(connection.id.value), end],
        );
      } on ArgumentError {
        // Historical diagonal geometry is not interpreted as smart routing.
      }
    }

    final Set<Offset> interiorJunctions = <Offset>{};
    final List<NonJunctionWireCrossing> crossings = <NonJunctionWireCrossing>[];
    final List<Connection> connections = circuit.connections;

    for (var firstIndex = 0; firstIndex < connections.length; firstIndex++) {
      final Connection first = connections[firstIndex];
      final OrthogonalWirePath? firstPath = paths[first.id];
      if (firstPath == null) continue;
      final String firstNet = _connectionNetId(first, topology);

      for (
        var secondIndex = firstIndex + 1;
        secondIndex < connections.length;
        secondIndex++
      ) {
        final Connection second = connections[secondIndex];
        final OrthogonalWirePath? secondPath = paths[second.id];
        if (secondPath == null) continue;
        final String secondNet = _connectionNetId(second, topology);
        final bool sameNet = firstNet == secondNet;

        final Set<Offset> pairCrossings = <Offset>{};
        for (final OrthogonalSegment firstSegment in firstPath.segments) {
          for (final OrthogonalSegment secondSegment in secondPath.segments) {
            if (firstSegment.axis == secondSegment.axis) continue;
            final Offset? point = firstSegment.intersectionWith(secondSegment);
            if (point == null ||
                _isSharedTerminalPoint(
                  first: first,
                  second: second,
                  point: point,
                  geometry: geometry,
                )) {
              continue;
            }
            pairCrossings.add(point);
          }
        }

        if (sameNet) {
          interiorJunctions.addAll(pairCrossings);
        } else {
          for (final Offset point in pairCrossings) {
            crossings.add(
              NonJunctionWireCrossing(
                point: point,
                firstConnectionId: first.id,
                secondConnectionId: second.id,
              ),
            );
          }
        }
      }
    }

    return WireSemantics(
      junctionTerminalIds: junctions,
      interiorJunctionPoints: interiorJunctions,
      nonJunctionCrossings: crossings,
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

  static bool _isSharedTerminalPoint({
    required Connection first,
    required Connection second,
    required Offset point,
    required CircuitGeometryIndex geometry,
  }) {
    final Set<TerminalId> firstTerminals = <TerminalId>{
      first.fromTerminalId,
      first.toTerminalId,
    };
    final Set<TerminalId> secondTerminals = <TerminalId>{
      second.fromTerminalId,
      second.toTerminalId,
    };
    for (final TerminalId terminalId in firstTerminals.intersection(
      secondTerminals,
    )) {
      if (geometry.terminalPositions[terminalId] == point) return true;
    }
    return false;
  }
}
