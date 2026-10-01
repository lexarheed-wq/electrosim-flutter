import 'dart:ui';

import 'package:electrosim_domain/electrosim_domain.dart';

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
    required List<NonJunctionWireCrossing> nonJunctionCrossings,
  }) : junctionTerminalIds = Set<TerminalId>.unmodifiable(junctionTerminalIds),
       nonJunctionCrossings =
           List<NonJunctionWireCrossing>.unmodifiable(nonJunctionCrossings);

  final Set<TerminalId> junctionTerminalIds;
  final List<NonJunctionWireCrossing> nonJunctionCrossings;
}

final class WireSemanticsAnalyzer {
  const WireSemanticsAnalyzer();

  WireSemantics analyze({
    required CircuitState circuit,
    required CircuitVisualLayout layout,
  }) {
    final CircuitGeometryIndex geometry = CircuitGeometryIndex.build(
      circuit,
      layout,
    );
    final Map<TerminalId, int> degree = <TerminalId, int>{};
    for (final Connection connection in circuit.connections) {
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
      final Offset? end =
          geometry.terminalPositions[connection.toTerminalId];
      if (start == null || end == null || start == end) {
        continue;
      }
      try {
        paths[connection.id] = OrthogonalWirePath(
          points: <Offset>[
            start,
            ...layout.routeFor(connection.id.value),
            end,
          ],
        );
      } on ArgumentError {
        // Historical/manual diagonal routes are not classified by the
        // orthogonal G2A semantics layer.
      }
    }

    final List<NonJunctionWireCrossing> crossings =
        <NonJunctionWireCrossing>[];
    final List<Connection> connections = circuit.connections;
    for (var firstIndex = 0;
        firstIndex < connections.length;
        firstIndex++) {
      final Connection first = connections[firstIndex];
      final OrthogonalWirePath? firstPath = paths[first.id];
      if (firstPath == null) {
        continue;
      }
      for (var secondIndex = firstIndex + 1;
          secondIndex < connections.length;
          secondIndex++) {
        final Connection second = connections[secondIndex];
        final OrthogonalWirePath? secondPath = paths[second.id];
        if (secondPath == null) {
          continue;
        }
        final Set<Offset> pairCrossings = <Offset>{};
        for (final OrthogonalSegment firstSegment in firstPath.segments) {
          for (final OrthogonalSegment secondSegment in secondPath.segments) {
            if (firstSegment.axis == secondSegment.axis) {
              continue;
            }
            final Offset? point =
                firstSegment.intersectionWith(secondSegment);
            if (point == null ||
                _isElectricalJunctionPoint(
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

    return WireSemantics(
      junctionTerminalIds: junctions,
      nonJunctionCrossings: crossings,
    );
  }

  static bool _isElectricalJunctionPoint({
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
    for (final TerminalId terminalId
        in firstTerminals.intersection(secondTerminals)) {
      if (geometry.terminalPositions[terminalId] == point) {
        return true;
      }
    }
    return false;
  }
}
