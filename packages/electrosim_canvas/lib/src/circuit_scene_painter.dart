import 'dart:math' as math;

import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:flutter/material.dart';

import 'canvas_geometry.dart';
import 'circuit_visual_layout.dart';
import 'viewport_controller.dart';

final class CircuitScenePainter extends CustomPainter {
  CircuitScenePainter({
    required this.circuit,
    required this.layout,
    required this.viewport,
    this.selectedElementId,
    this.pendingTerminalId,
    this.pointerWorldPosition,
    this.previewPositions = const <String, Offset>{},
  });

  final CircuitState circuit;
  final CircuitVisualLayout layout;
  final ViewportController viewport;
  final String? selectedElementId;
  final TerminalId? pendingTerminalId;
  final Offset? pointerWorldPosition;
  final Map<String, Offset> previewPositions;

  static const Color boardColor = Color(0xFFF6F8FB);
  static const Color gridColor = Color(0xFFE3E8EF);
  static const Color elementFill = Color(0xFFFFFFFF);
  static const Color elementStroke = Color(0xFF334155);
  static const Color sourceFill = Color(0xFFEFF6FF);
  static const Color terminalFill = Color(0xFFFFFFFF);
  static const Color terminalStroke = Color(0xFF0F172A);
  static const Color selectionColor = Color(0xFF2563EB);
  static const Color pendingColor = Color(0xFFF59E0B);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = boardColor);
    _paintGrid(canvas, size);

    final CircuitGeometryIndex geometry = CircuitGeometryIndex.build(
      circuit,
      layout,
      previewPositions: previewPositions,
    );
    _paintWires(canvas, geometry);
    _paintSources(canvas, geometry);
    _paintComponents(canvas, geometry);
    _paintTerminals(canvas, geometry);
    _paintWiringPreview(canvas, geometry);
  }

  void _paintGrid(Canvas canvas, Size size) {
    const double worldStep = 24;
    final double step = worldStep * viewport.scale;
    if (step < 9) {
      return;
    }
    final Paint paint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    final double xStart = viewport.translation.dx % step;
    final double yStart = viewport.translation.dy % step;
    for (double x = xStart; x <= size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = yStart; y <= size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  void _paintWires(Canvas canvas, CircuitGeometryIndex geometry) {
    for (final Connection connection in circuit.connections) {
      final Offset? start = geometry.terminalPositions[connection.fromTerminalId];
      final Offset? end = geometry.terminalPositions[connection.toTerminalId];
      if (start == null || end == null) {
        continue;
      }
      final List<Offset> worldPoints = <Offset>[
        start,
        ...layout.routeFor(connection.id.value),
        end,
      ];
      final Path path = Path()..moveTo(
        viewport.worldToScreen(worldPoints.first).dx,
        viewport.worldToScreen(worldPoints.first).dy,
      );
      for (final Offset worldPoint in worldPoints.skip(1)) {
        final Offset point = viewport.worldToScreen(worldPoint);
        path.lineTo(point.dx, point.dy);
      }
      final bool selected = selectedElementId == connection.id.value;
      canvas.drawPath(
        path,
        Paint()
          ..color = selected ? selectionColor : _phaseColor(connection.phase)
          ..strokeWidth = selected ? 5 : 3
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }
  }

  void _paintSources(Canvas canvas, CircuitGeometryIndex geometry) {
    for (final SourceInstance source in circuit.sources) {
      final Rect? rect = geometry.elementRects[source.id.value];
      if (rect != null) {
        _paintElement(canvas, rect, source.id.value, source.modelType, true);
      }
    }
  }

  void _paintComponents(Canvas canvas, CircuitGeometryIndex geometry) {
    for (final ComponentInstance component in circuit.components) {
      final Rect? rect = geometry.elementRects[component.id.value];
      if (rect != null) {
        _paintElement(canvas, rect, component.id.value, component.modelType, false);
      }
    }
  }

  void _paintElement(
    Canvas canvas,
    Rect worldRect,
    String elementId,
    String modelType,
    bool source,
  ) {
    final Rect rect = Rect.fromCenter(
      center: viewport.worldToScreen(worldRect.center),
      width: worldRect.width * viewport.scale,
      height: worldRect.height * viewport.scale,
    );
    final bool selected = selectedElementId == elementId;
    final RRect rrect = RRect.fromRectAndRadius(rect, const Radius.circular(10));
    canvas.drawRRect(rrect, Paint()..color = source ? sourceFill : elementFill);
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = selected ? selectionColor : elementStroke
        ..strokeWidth = selected ? 3 : 1.5
        ..style = PaintingStyle.stroke,
    );

    final TextPainter label = TextPainter(
      text: TextSpan(
        text: _displayModelLabel(modelType),
        style: TextStyle(
          color: const Color(0xFF0F172A),
          fontSize: (13 * viewport.scale).clamp(10, 18).toDouble(),
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: math.max(32.0, rect.width - 14).toDouble());
    label.paint(
      canvas,
      Offset(rect.center.dx - label.width / 2, rect.center.dy - label.height / 2),
    );
  }

  void _paintTerminals(Canvas canvas, CircuitGeometryIndex geometry) {
    for (final MapEntry<TerminalId, Offset> entry in geometry.terminalPositions.entries) {
      final Offset screen = viewport.worldToScreen(entry.value);
      final bool pending = entry.key == pendingTerminalId;
      final double radius = pending ? 7 : 5;
      canvas.drawCircle(screen, radius, Paint()..color = pending ? pendingColor : terminalFill);
      canvas.drawCircle(
        screen,
        radius,
        Paint()
          ..color = pending ? pendingColor : terminalStroke
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke,
      );
    }
  }

  void _paintWiringPreview(Canvas canvas, CircuitGeometryIndex geometry) {
    if (pendingTerminalId == null || pointerWorldPosition == null) {
      return;
    }
    final Offset? start = geometry.terminalPositions[pendingTerminalId];
    if (start == null) {
      return;
    }
    canvas.drawLine(
      viewport.worldToScreen(start),
      viewport.worldToScreen(pointerWorldPosition!),
      Paint()
        ..color = pendingColor
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke,
    );
  }

  static Color _phaseColor(PhaseTag phase) => switch (phase) {
    PhaseTag.dcPositive => const Color(0xFFDC2626),
    PhaseTag.dcNegative => const Color(0xFF111827),
    PhaseTag.l1 => const Color(0xFF92400E),
    PhaseTag.l2 => const Color(0xFF111827),
    PhaseTag.l3 => const Color(0xFF6B7280),
    PhaseTag.neutral => const Color(0xFF2563EB),
    PhaseTag.protectiveEarth => const Color(0xFF15803D),
    PhaseTag.none => const Color(0xFF475569),
  };

  @override
  bool shouldRepaint(CircuitScenePainter oldDelegate) => !identical(oldDelegate, this);
}


String _displayModelLabel(String modelType) {
  return switch (modelType) {
    'dc_voltage_source' => 'Source CC',
    'switch' || 'switch_spst' => 'Interrupteur',
    'lamp' => 'Lampe',
    'resistor' => 'Résistance',
    'breaker' => 'Disjoncteur',
    'push_button_no' => 'BP NO',
    'buzzer' => 'Buzzer',
    'fuse' => 'Fusible',
    'diode' => 'Diode',
    'fan_dc' => 'Ventilateur',
    'motor_dc' => 'Moteur CC',
    'relay_coil' => 'Bobine relais',
    _ => 'Composant',
  };
}
