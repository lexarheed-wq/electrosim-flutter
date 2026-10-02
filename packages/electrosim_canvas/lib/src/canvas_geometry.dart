import 'dart:ui';

import 'package:electrosim_domain/electrosim_domain.dart';

import 'circuit_visual_layout.dart';

final class CircuitGeometryIndex {
  CircuitGeometryIndex._({
    required this.elementRects,
    required this.terminalPositions,
    required this.terminalOwners,
  });

  factory CircuitGeometryIndex.build(
    CircuitState circuit,
    CircuitVisualLayout layout, {
    Map<String, Offset> previewPositions = const <String, Offset>{},
  }) {
    final Map<String, Rect> elementRects = <String, Rect>{};
    final Map<TerminalId, Offset> terminalPositions = <TerminalId, Offset>{};
    final Map<TerminalId, String> terminalOwners = <TerminalId, String>{};
    final Set<String> seenElementIds = <String>{};

    void indexElement(String id, List<Terminal> terminals) {
      if (!seenElementIds.add(id)) {
        throw StateError(
          'Canvas requires globally unique source/component visual IDs; duplicate: $id',
        );
      }
      final Offset? center = previewPositions[id] ?? layout.positionOf(id);
      if (center == null) {
        return;
      }
      final Size baseSize = layout.sizeOf(id);
      final int quarterTurns = layout.quarterTurnsOf(id);
      final Size displaySize = quarterTurns.isOdd
          ? Size(baseSize.height, baseSize.width)
          : baseSize;
      final Rect rect = Rect.fromCenter(
        center: center,
        width: displaySize.width,
        height: displaySize.height,
      );
      elementRects[id] = rect;
      for (var index = 0; index < terminals.length; index++) {
        final Terminal terminal = terminals[index];
        final Offset local = _terminalOffset(
          baseSize,
          index,
          terminals.length,
        );
        terminalPositions[terminal.id] =
            center + _rotateQuarterTurns(local, quarterTurns);
        terminalOwners[terminal.id] = id;
      }
    }

    for (final SourceInstance source in circuit.sources) {
      indexElement(source.id.value, source.terminals);
    }
    for (final ComponentInstance component in circuit.components) {
      indexElement(component.id.value, component.terminals);
    }
    for (final Connection connection in circuit.connections) {
      if (!seenElementIds.add(connection.id.value)) {
        throw StateError(
          'Canvas requires globally unique visual IDs across sources, components, and connections; duplicate: ${connection.id.value}',
        );
      }
    }

    return CircuitGeometryIndex._(
      elementRects: Map<String, Rect>.unmodifiable(elementRects),
      terminalPositions: Map<TerminalId, Offset>.unmodifiable(terminalPositions),
      terminalOwners: Map<TerminalId, String>.unmodifiable(terminalOwners),
    );
  }

  final Map<String, Rect> elementRects;
  final Map<TerminalId, Offset> terminalPositions;
  final Map<TerminalId, String> terminalOwners;

  static Offset _terminalOffset(Size size, int index, int count) {
    final Rect rect = Rect.fromCenter(
      center: Offset.zero,
      width: size.width,
      height: size.height,
    );
    if (count <= 1) {
      return Offset(rect.right, rect.center.dy);
    }
    if (count == 2) {
      return index == 0
          ? Offset(rect.left, rect.center.dy)
          : Offset(rect.right, rect.center.dy);
    }
    if (count == 3) {
      return switch (index) {
        0 => Offset(rect.left, rect.center.dy),
        1 => Offset(rect.right, rect.top + rect.height * 0.35),
        _ => Offset(rect.right, rect.bottom - rect.height * 0.35),
      };
    }
    final int side = index % 4;
    final int ring = index ~/ 4;
    final double inset = 10.0 + ring * 8.0;
    return switch (side) {
      0 => Offset(
          rect.left,
          (rect.top + inset).clamp(rect.top, rect.bottom).toDouble(),
        ),
      1 => Offset(
          rect.right,
          (rect.top + inset).clamp(rect.top, rect.bottom).toDouble(),
        ),
      2 => Offset(
          (rect.left + inset).clamp(rect.left, rect.right).toDouble(),
          rect.top,
        ),
      _ => Offset(
          (rect.left + inset).clamp(rect.left, rect.right).toDouble(),
          rect.bottom,
        ),
    };
  }

  static Offset _rotateQuarterTurns(Offset offset, int quarterTurns) {
    return switch (quarterTurns % 4) {
      0 => offset,
      1 => Offset(-offset.dy, offset.dx),
      2 => Offset(-offset.dx, -offset.dy),
      _ => Offset(offset.dy, -offset.dx),
    };
  }

}
