import 'dart:math' as math;
import 'dart:ui';

import 'package:electrosim_domain/electrosim_domain.dart';

import 'circuit_visual_layout.dart';
import 'motor_terminal_geometry.dart';
import 'premium_rcd2p_terminal_geometry.dart';

/// Presentation-only terminal anchors for component drawings.
///
/// Electrical topology still uses the same [TerminalId] objects; this profile
/// only determines where those terminals are drawn and hit-tested on the
/// canvas. The Point 5 V1 pilot uses model-specific anchors so a terminal is
/// located at the physical connection lug instead of at the edge of a generic
/// 104x64 bounding box.
abstract final class TerminalVisualProfile {
  /// Physical front-view anchors expressed from the center of the component
  /// envelope. The uploaded V2 five use their exact Dart design coordinates;
  /// the remaining reference components retain their existing horizontal lugs.
  static List<Offset>? _physicalOffsets(
    String modelType, {
    required Size size,
  }) {
    final String type = modelType.toLowerCase();
    final double w = size.width;
    final double h = size.height;
    return switch (type) {
      // Uploaded V2 geometry:
      // supply 140x160 -> (42,127) / (94,127)
      'dc_voltage_source' || 'voltage_source' => <Offset>[
        Offset(w * -0.20, h * 0.29375),
        Offset(w * 0.1714285714, h * 0.29375),
      ],
      // 2-pole premium breaker: four screws match Disjoncteur3D precisely.
      'rcd_2p_ac1' => PremiumRcd2pTerminalGeometry.offsets(size),
      // breaker 72x160 -> (36,23) / (36,137)
      'breaker_dc' ||
      'breaker_ac1' ||
      'breaker' => <Offset>[Offset(0, h * -0.35625), Offset(0, h * 0.35625)],
      // toggle 90x140 -> (45,20) / (45,120)
      'switch' || 'switch_spst' => <Offset>[
        Offset(0, h * -0.3571428571),
        Offset(0, h * 0.3571428571),
      ],
      // button 90x140 -> (31,119) / (59,119)
      'push_button_no' => <Offset>[
        Offset(w * -0.1555555556, h * 0.35),
        Offset(w * 0.1555555556, h * 0.35),
      ],
      // lamp 130x160 -> (40,139) / (90,139)
      'lamp' => <Offset>[
        Offset(w * -0.1923076923, h * 0.36875),
        Offset(w * 0.1923076923, h * 0.36875),
      ],

      // Eight additional V2 front-view components. Physical terminals stay
      // close to the actual housing instead of floating at the layout edge.
      'resistor' => <Offset>[
        Offset(w * -0.2785714286, 0),
        Offset(w * 0.2785714286, 0),
      ],
      'push_button_nc' => <Offset>[
        Offset(w * -0.1555555556, h * 0.35),
        Offset(w * 0.1555555556, h * 0.35),
      ],
      'buzzer' => <Offset>[
        Offset(w * -0.1315789474, h * 0.3421052632),
        Offset(w * 0.1315789474, h * 0.3421052632),
      ],
      'fuse_dc' ||
      'fuse_ac1' ||
      'fuse' => <Offset>[Offset(w * -0.34, 0), Offset(w * 0.34, 0)],
      'diode' => <Offset>[
        Offset(w * -0.2777777778, 0),
        Offset(w * 0.2777777778, 0),
      ],
      'fan_dc' => <Offset>[
        Offset(w * -0.1095238095, h * 0.3904761905),
        Offset(w * 0.1095238095, h * 0.3904761905),
      ],
      'motor_dc' => <Offset>[
        Offset(w * -0.1086956522, h * 0.3473684211),
        Offset(w * 0.1086956522, h * 0.3473684211),
      ],
      'relay_coil' => <Offset>[
        Offset(w * -0.1578947368, h * 0.3782608696),
        Offset(w * 0.1578947368, h * 0.3782608696),
      ],

      // C14 library wave 1. Multi-pole devices use the exact terminal order
      // from their ComponentModelContract / palette definition.
      'capacitor' ||
      'inductor' ||
      'impedance' => <Offset>[Offset(w * -0.28, 0), Offset(w * 0.28, 0)],
      'contactor_aux_no' ||
      'contactor_aux_nc' ||
      'relay_contact_no' ||
      'relay_contact_nc' => <Offset>[Offset(0, h * -0.38), Offset(0, h * 0.38)],
      'contactor_ac1' => <Offset>[
        Offset(w * -0.1224, h * -0.42),
        Offset(w * -0.1224, h * 0.42),
        Offset(w * -0.42, h * 0.08),
        Offset(w * 0.42, h * 0.08),
      ],
      'contactor_3p' => <Offset>[
        Offset(w * -0.2016, h * -0.42),
        Offset(0, h * -0.42),
        Offset(w * 0.2016, h * -0.42),
        Offset(w * -0.2016, h * 0.42),
        Offset(0, h * 0.42),
        Offset(w * 0.2016, h * 0.42),
        Offset(w * -0.42, h * 0.08),
        Offset(w * 0.42, h * 0.08),
      ],
      'breaker_3p' => <Offset>[
        Offset(w * -0.2016, h * -0.42),
        Offset(0, h * -0.42),
        Offset(w * 0.2016, h * -0.42),
        Offset(w * -0.2016, h * 0.42),
        Offset(0, h * 0.42),
        Offset(w * 0.2016, h * 0.42),
      ],
      'thermal_overload_3p' => <Offset>[
        Offset(w * -0.2072, h * -0.42),
        Offset(0, h * -0.42),
        Offset(w * 0.2072, h * -0.42),
        Offset(w * -0.2072, h * 0.42),
        Offset(0, h * 0.42),
        Offset(w * 0.2072, h * 0.42),
      ],
      'dc_current_source' || 'ac_voltage_source' || 'ac_current_source' =>
        <Offset>[Offset(w * -0.18, h * 0.40), Offset(w * 0.18, h * 0.40)],
      'ac3_voltage_source' => <Offset>[
        Offset(w * -0.27, h * 0.42),
        Offset(w * -0.09, h * 0.42),
        Offset(w * 0.09, h * 0.42),
        Offset(w * 0.27, h * 0.42),
      ],
      'pv_array' => <Offset>[
        Offset(w * -0.14, h * 0.42),
        Offset(w * 0.14, h * 0.42),
      ],
      'pv_controller' => <Offset>[
        Offset(w * -0.19, h * -0.42),
        Offset(w * 0.19, h * -0.42),
        Offset(w * -0.19, h * 0.42),
        Offset(w * 0.19, h * 0.42),
      ],
      'pv_battery' => <Offset>[
        Offset(w * -0.17, h * 0.42),
        Offset(w * 0.17, h * 0.42),
      ],
      'pv_inverter' => <Offset>[
        Offset(w * -0.19, h * -0.42),
        Offset(w * 0.19, h * -0.42),
        Offset(w * -0.19, h * 0.42),
        Offset(w * 0.19, h * 0.42),
      ],
      'pv_resistive_load' => <Offset>[
        Offset(w * -0.16, h * 0.41),
        Offset(w * 0.16, h * 0.41),
      ],
      'motor_3p_6t' => SixTerminalMotorGeometry.offsets(Size(w, h)),
      'load_wye_3p' => <Offset>[
        Offset(w * -0.20, h * -0.42),
        Offset(0, h * -0.42),
        Offset(w * 0.20, h * -0.42),
        Offset(0, h * 0.42),
      ],
      'load_delta_3p' => <Offset>[
        Offset(w * -0.20, h * -0.42),
        Offset(0, h * -0.42),
        Offset(w * 0.20, h * -0.42),
      ],
      'catalog_battery' ||
      'catalog_generator' ||
      'catalog_appliance_2t' ||
      'catalog_motor_driven_2t' ||
      'catalog_heater' ||
      'catalog_actuator_2t' ||
      'catalog_sensor_2t' ||
      'catalog_indicator_2t' => <Offset>[
        Offset(w * -0.17, h * 0.42),
        Offset(w * 0.17, h * 0.42),
      ],
      'catalog_motor_driven_6t' => <Offset>[
        Offset(w * -0.20, h * -0.42),
        Offset(0, h * -0.42),
        Offset(w * 0.20, h * -0.42),
        Offset(w * -0.20, h * 0.42),
        Offset(0, h * 0.42),
        Offset(w * 0.20, h * 0.42),
      ],
      'isolator_3p' => <Offset>[
        Offset(w * -0.2466666667, h * -0.425),
        Offset(0, h * -0.425),
        Offset(w * 0.2466666667, h * -0.425),
        Offset(w * -0.2466666667, h * 0.425),
        Offset(0, h * 0.425),
        Offset(w * 0.2466666667, h * 0.425),
      ],
      'isolator_4p' || 'breaker_4p' => <Offset>[
        Offset(w * -0.2775, h * -0.425),
        Offset(w * -0.0925, h * -0.425),
        Offset(w * 0.0925, h * -0.425),
        Offset(w * 0.2775, h * -0.425),
        Offset(w * -0.2775, h * 0.425),
        Offset(w * -0.0925, h * 0.425),
        Offset(w * 0.0925, h * 0.425),
        Offset(w * 0.2775, h * 0.425),
      ],
      'terminal_block_5' => <Offset>[
        Offset(w * -0.328, h * -0.425),
        Offset(w * -0.164, h * -0.425),
        Offset(0, h * -0.425),
        Offset(w * 0.164, h * -0.425),
        Offset(w * 0.328, h * -0.425),
        Offset(w * -0.328, h * 0.425),
        Offset(w * -0.164, h * 0.425),
        Offset(0, h * 0.425),
        Offset(w * 0.164, h * 0.425),
        Offset(w * 0.328, h * 0.425),
      ],
      _ => null,
    };
  }

  static bool hasPhysicalPilotAnchor(String modelType) =>
      _physicalOffsets(modelType, size: const Size(100, 100)) != null;

  /// Retained for compatibility with contracts that only need a symmetric
  /// horizontal pair. V2 devices with top/bottom or asymmetric terminals
  /// intentionally return null here.
  static double? horizontalHalfSpanForModel(
    String modelType, {
    required Size size,
  }) {
    final List<Offset>? offsets = _physicalOffsets(modelType, size: size);
    if (offsets == null || offsets.length != 2) return null;
    final Offset a = offsets[0];
    final Offset b = offsets[1];
    if (a.dy.abs() > 1e-9 || b.dy.abs() > 1e-9) return null;
    if ((a.dx + b.dx).abs() > 1e-6) return null;
    return b.dx.abs();
  }

  static Offset terminalOffset({
    required String modelType,
    required Size size,
    required int index,
    required int count,
  }) {
    final List<Offset>? candidate = _physicalOffsets(modelType, size: size);
    final List<Offset>? offsets = candidate != null && candidate.length == count
        ? candidate
        : null;
    if (offsets != null && index >= 0 && index < offsets.length) {
      return offsets[index];
    }
    return _genericTerminalOffset(size, index, count);
  }

  /// Invisible routing ports follow the natural exit side of the uploaded V2
  /// terminals so the visible terminal-to-route stub remains orthogonal.
  /// Other component families keep the generic left/right envelope ports.
  static Offset routingOffset({
    String? modelType,
    required Size size,
    required int index,
    required int count,
  }) {
    if (modelType != null) {
      final List<Offset>? candidate = _physicalOffsets(
        modelType.toLowerCase(),
        size: size,
      );
      if (candidate != null &&
          candidate.length == count &&
          index >= 0 &&
          index < candidate.length) {
        return _projectToNearestEdge(candidate[index], size);
      }
    }
    return _genericTerminalOffset(size, index, count);
  }

  static Offset _projectToNearestEdge(Offset point, Size size) {
    final Rect rect = Rect.fromCenter(
      center: Offset.zero,
      width: size.width,
      height: size.height,
    );
    final double left = (point.dx - rect.left).abs();
    final double right = (rect.right - point.dx).abs();
    final double top = (point.dy - rect.top).abs();
    final double bottom = (rect.bottom - point.dy).abs();
    final double minimum = math.min(
      math.min(left, right),
      math.min(top, bottom),
    );
    if (minimum == left) return Offset(rect.left, point.dy);
    if (minimum == right) return Offset(rect.right, point.dy);
    if (minimum == top) return Offset(point.dx, rect.top);
    return Offset(point.dx, rect.bottom);
  }

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

    void indexElement(String id, String modelType, List<Terminal> terminals) {
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
          modelType: modelType,
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
      indexElement(
        source.id.value,
        (source.parameters['_visualModelType'] as String?) ?? source.modelType,
        source.terminals,
      );
    }
    for (final ComponentInstance component in circuit.components) {
      indexElement(
        component.id.value,
        (component.parameters['_visualModelType'] as String?) ??
            component.modelType,
        component.terminals,
      );
    }
    for (final InstrumentInstance instrument in circuit.instruments) {
      // Instruments occupy actual canvas geometry but never create implicit
      // electrical terminals or alter circuit-node connectivity.
      indexElement(
        instrument.id.value,
        'physical-instrument',
        const <Terminal>[],
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
      terminalPositions: Map<TerminalId, Offset>.unmodifiable(
        terminalPositions,
      ),
      terminalRoutingPositions: Map<TerminalId, Offset>.unmodifiable(
        terminalRoutingPositions,
      ),
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
