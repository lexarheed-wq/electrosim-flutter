import 'dart:ui';

import 'package:electrosim_domain/electrosim_domain.dart';

import 'circuit_visual_layout.dart';

/// Presentation-only terminal anchors for component drawings.
///
/// Electrical topology still uses the same [TerminalId] objects; this profile
/// only determines where those terminals are drawn and hit-tested on the
/// canvas. The Point 5 V1 pilot uses model-specific anchors so a terminal is
/// located at the physical connection lug instead of at the edge of a generic
/// 104x64 bounding box.
abstract final class TerminalVisualProfile {
  /// Physical terminal position as a fraction of each model's own width.
  ///
  /// The pilot no longer shares one 104x64 visible geometry: each component
  /// may have its own aspect ratio while the terminal remains attached to its
  /// real front-view silhouette.
  static const Map<String, double> _pilotHalfSpanFractions = <String, double>{
    'dc_voltage_source': 0.48,
    'voltage_source': 0.48,
    'switch': 0.46,
    'switch_spst': 0.46,
    'lamp': 0.44,
    'breaker_dc': 0.46,
    'breaker_ac1': 0.46,
    'breaker': 0.46,
    'push_button_no': 0.44,
  };

  static bool hasPhysicalPilotAnchor(String modelType) =>
      _pilotHalfSpanFractions.containsKey(modelType.toLowerCase());

  static double? horizontalHalfSpanForModel(
    String modelType, {
    required Size size,
  }) {
    final double? fraction =
        _pilotHalfSpanFractions[modelType.toLowerCase()];
    if (fraction == null) return null;
    return size.width * fraction;
  }

  static Offset terminalOffset({
    required String modelType,
    required Size size,
    required int index,
    required int count,
  }) {
    final double? halfSpan = count == 2
        ? horizontalHalfSpanForModel(modelType, size: size)
        : null;
    if (halfSpan != null) {
      return Offset(index == 0 ? -halfSpan : halfSpan, 0);
    }
    return _genericTerminalOffset(size, index, count);
  }

  /// Invisible routing port remains on the logical element envelope.
  static Offset routingOffset({
    required Size size,
    required int index,
    required int count,
  }) =>
      _genericTerminalOffset(size, index, count);

  static Offset _genericTerminalOffset(Size size, int index, int count) {
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
}

final class CircuitGeometryIndex {
  CircuitGeometryIndex._({
    required this.elementRects,
    required this.terminalPositions,
    required this.terminalRoutingPositions,
    required this.terminalOwners,
  });

  factory CircuitGeometryIndex.build(
    CircuitState circuit,
    CircuitVisualLayout layout, {
    Map<String, Offset> previewPositions = const <String, Offset>{},
  }) {
    final Map<String, Rect> elementRects = <String, Rect>{};
    final Map<TerminalId, Offset> terminalPositions = <TerminalId, Offset>{};
    final Map<TerminalId, Offset> terminalRoutingPositions =
        <TerminalId, Offset>{};
    final Map<TerminalId, String> terminalOwners = <TerminalId, String>{};
    final Set<String> seenElementIds = <String>{};

    void indexElement(
      String id,
      String modelType,
      List<Terminal> terminals,
    ) {
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
        final Offset physicalLocal = TerminalVisualProfile.terminalOffset(
          modelType: modelType,
          size: baseSize,
          index: index,
          count: terminals.length,
        );
        final Offset routingLocal = TerminalVisualProfile.routingOffset(
          size: baseSize,
          index: index,
          count: terminals.length,
        );
        terminalPositions[terminal.id] =
            center + _rotateQuarterTurns(physicalLocal, quarterTurns);
        terminalRoutingPositions[terminal.id] =
            center + _rotateQuarterTurns(routingLocal, quarterTurns);
        terminalOwners[terminal.id] = id;
      }
    }

    for (final SourceInstance source in circuit.sources) {
      indexElement(source.id.value, source.modelType, source.terminals);
    }
    for (final ComponentInstance component in circuit.components) {
      indexElement(
        component.id.value,
        component.modelType,
        component.terminals,
      );
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
      terminalRoutingPositions:
          Map<TerminalId, Offset>.unmodifiable(terminalRoutingPositions),
      terminalOwners: Map<TerminalId, String>.unmodifiable(terminalOwners),
    );
  }

  final Map<String, Rect> elementRects;
  /// Physical terminal positions used for painting, hit testing and the
  /// visible endpoints of wires.
  final Map<TerminalId, Offset> terminalPositions;

  /// Invisible routing-envelope ports used only by the orthogonal router.
  ///
  /// A pilot component may therefore expose a real terminal inside its generic
  /// element rectangle without destabilising routing around that rectangle.
  final Map<TerminalId, Offset> terminalRoutingPositions;

  final Map<TerminalId, String> terminalOwners;

  static Offset _rotateQuarterTurns(Offset offset, int quarterTurns) {
    return switch (quarterTurns % 4) {
      0 => offset,
      1 => Offset(-offset.dy, offset.dx),
      2 => Offset(-offset.dx, -offset.dy),
      _ => Offset(offset.dy, -offset.dx),
    };
  }

}
