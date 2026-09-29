import 'package:electrosim_canvas/electrosim_canvas.dart';
import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:electrosim_ui_kit/electrosim_ui_kit.dart';
import 'package:flutter/material.dart';

import 'f9_wiring_policy.dart';

class F9ComponentGlyph extends StatelessWidget {
  const F9ComponentGlyph({
    super.key,
    required this.modelType,
    this.size = 26,
    this.active = true,
  });

  final String modelType;
  final double size;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _F9GlyphPainter(
        modelType: modelType,
        foreground: active ? ElectroSimColors.primary : ElectroSimColors.textSecondary,
      ),
    );
  }
}

class F9CanvasVisualOverlay extends StatelessWidget {
  const F9CanvasVisualOverlay({
    super.key,
    required this.circuit,
    required this.layout,
    required this.viewport,
    this.pendingTerminalId,
    this.hoverTerminalId,
  });

  final CircuitState circuit;
  final CircuitVisualLayout layout;
  final ViewportController viewport;
  final TerminalId? pendingTerminalId;
  final TerminalId? hoverTerminalId;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: _F9CanvasOverlayPainter(
          circuit: circuit,
          layout: layout,
          viewport: viewport,
          pendingTerminalId: pendingTerminalId,
          hoverTerminalId: hoverTerminalId,
        ),
        size: Size.infinite,
      ),
    );
  }
}

class _F9CanvasOverlayPainter extends CustomPainter {
  const _F9CanvasOverlayPainter({
    required this.circuit,
    required this.layout,
    required this.viewport,
    required this.pendingTerminalId,
    required this.hoverTerminalId,
  });

  final CircuitState circuit;
  final CircuitVisualLayout layout;
  final ViewportController viewport;
  final TerminalId? pendingTerminalId;
  final TerminalId? hoverTerminalId;

  @override
  void paint(Canvas canvas, Size size) {
    final CircuitGeometryIndex geometry = CircuitGeometryIndex.build(circuit, layout);
    for (final SourceInstance source in circuit.sources) {
      final Rect? rect = geometry.elementRects[source.id.value];
      if (rect == null) {
        continue;
      }
      _paintElementGlyph(canvas, rect, source.modelType, source.enabled);
    }
    for (final ComponentInstance component in circuit.components) {
      final Rect? rect = geometry.elementRects[component.id.value];
      if (rect == null) {
        continue;
      }
      final Object? closed = component.controlState['closed'];
      final bool active = component.condition != ComponentCondition.disabled && closed != false;
      _paintElementGlyph(canvas, rect, component.modelType, active);
    }
    _paintWiringTargets(canvas, geometry);
  }

  void _paintWiringTargets(Canvas canvas, CircuitGeometryIndex geometry) {
    final TerminalId? pending = pendingTerminalId;
    if (pending == null) {
      return;
    }
    for (final MapEntry<TerminalId, Offset> entry in geometry.terminalPositions.entries) {
      final Offset screen = viewport.worldToScreen(entry.value);
      if (entry.key == pending) {
        canvas.drawCircle(
          screen,
          10,
          Paint()
            ..color = ElectroSimColors.primary
            ..strokeWidth = 3
            ..style = PaintingStyle.stroke,
        );
        continue;
      }
      final F9WiringDecision decision = F9WiringPolicy.evaluateAndBuild(circuit, pending, entry.key);
      final bool hovered = entry.key == hoverTerminalId;
      if (!decision.accepted && !hovered) {
        continue;
      }
      final Color color = decision.accepted ? ElectroSimColors.success : ElectroSimColors.danger;
      canvas.drawCircle(
        screen,
        hovered ? 12 : 9,
        Paint()
          ..color = color
          ..strokeWidth = hovered ? 3 : 2
          ..style = PaintingStyle.stroke,
      );
      if (hovered) {
        final TextPainter marker = TextPainter(
          text: TextSpan(
            text: decision.accepted ? '✓' : '×',
            style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w800),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        marker.paint(canvas, Offset(screen.dx + 10, screen.dy - 16));
      }
    }
  }

  void _paintElementGlyph(Canvas canvas, Rect worldRect, String modelType, bool active) {
    final Offset center = viewport.worldToScreen(worldRect.center);
    final double scale = viewport.scale.clamp(0.65, 1.5).toDouble();
    final double glyphSize = 20 * scale;
    final Rect glyphRect = Rect.fromCenter(
      center: Offset(center.dx, center.dy - (18 * scale)),
      width: glyphSize,
      height: glyphSize,
    );
    final Color color = active ? ElectroSimColors.primary : ElectroSimColors.textSecondary;
    paintF9Glyph(canvas, glyphRect, modelType, color);
  }

  @override
  bool shouldRepaint(_F9CanvasOverlayPainter oldDelegate) => true;
}

class _F9GlyphPainter extends CustomPainter {
  const _F9GlyphPainter({required this.modelType, required this.foreground});

  final String modelType;
  final Color foreground;

  @override
  void paint(Canvas canvas, Size size) {
    paintF9Glyph(canvas, Offset.zero & size, modelType, foreground);
  }

  @override
  bool shouldRepaint(_F9GlyphPainter oldDelegate) =>
      oldDelegate.modelType != modelType || oldDelegate.foreground != foreground;
}

void paintF9Glyph(Canvas canvas, Rect rect, String modelType, Color color) {
  final Paint stroke = Paint()
    ..color = color
    ..strokeWidth = (rect.shortestSide * 0.08).clamp(1.4, 2.4).toDouble()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;
  final Paint fill = Paint()..color = color;
  final String type = modelType.toLowerCase();
  final Offset c = rect.center;
  final double w = rect.width;
  final double h = rect.height;

  if (type.contains('lampe')) {
    canvas.drawCircle(c, rect.shortestSide * 0.28, stroke);
    canvas.drawLine(Offset(c.dx - w * 0.18, c.dy - h * 0.18), Offset(c.dx + w * 0.18, c.dy + h * 0.18), stroke);
    canvas.drawLine(Offset(c.dx + w * 0.18, c.dy - h * 0.18), Offset(c.dx - w * 0.18, c.dy + h * 0.18), stroke);
    return;
  }
  if (type.contains('résistance') || type.contains('resistance')) {
    final Path path = Path()..moveTo(rect.left + w * 0.08, c.dy);
    for (var i = 0; i < 6; i++) {
      final double x = rect.left + w * (0.2 + i * 0.1);
      final double y = c.dy + (i.isEven ? -h * 0.18 : h * 0.18);
      path.lineTo(x, y);
    }
    path.lineTo(rect.right - w * 0.08, c.dy);
    canvas.drawPath(path, stroke);
    return;
  }
  if (type.contains('interrupteur') || type.contains('disjoncteur') || type.contains('bouton')) {
    canvas.drawCircle(Offset(rect.left + w * 0.2, c.dy), w * 0.07, fill);
    canvas.drawCircle(Offset(rect.right - w * 0.2, c.dy), w * 0.07, fill);
    canvas.drawLine(Offset(rect.left + w * 0.26, c.dy), Offset(rect.right - w * 0.24, rect.top + h * 0.25), stroke);
    return;
  }
  if (type.contains('source') || type.contains('dc 24')) {
    canvas.drawLine(Offset(c.dx - w * 0.14, rect.top + h * 0.2), Offset(c.dx - w * 0.14, rect.bottom - h * 0.2), stroke);
    canvas.drawLine(Offset(c.dx + w * 0.12, rect.top + h * 0.32), Offset(c.dx + w * 0.12, rect.bottom - h * 0.32), stroke);
    return;
  }
  if (type.contains('moteur') || type.contains('ventilateur')) {
    canvas.drawCircle(c, rect.shortestSide * 0.3, stroke);
    final TextPainter tp = TextPainter(
      text: TextSpan(text: type.contains('ventilateur') ? 'F' : 'M', style: TextStyle(color: color, fontSize: rect.shortestSide * 0.34, fontWeight: FontWeight.w700)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(c.dx - tp.width / 2, c.dy - tp.height / 2));
    return;
  }
  if (type.contains('buzzer')) {
    final Path horn = Path()
      ..moveTo(rect.left + w * 0.18, c.dy - h * 0.12)
      ..lineTo(c.dx, c.dy - h * 0.12)
      ..lineTo(rect.right - w * 0.18, rect.top + h * 0.18)
      ..lineTo(rect.right - w * 0.18, rect.bottom - h * 0.18)
      ..lineTo(c.dx, c.dy + h * 0.12)
      ..lineTo(rect.left + w * 0.18, c.dy + h * 0.12)
      ..close();
    canvas.drawPath(horn, stroke);
    return;
  }
  if (type.contains('fusible')) {
    canvas.drawLine(Offset(rect.left + w * 0.12, c.dy), Offset(rect.left + w * 0.32, c.dy), stroke);
    canvas.drawRect(Rect.fromCenter(center: c, width: w * 0.36, height: h * 0.22), stroke);
    canvas.drawLine(Offset(rect.right - w * 0.32, c.dy), Offset(rect.right - w * 0.12, c.dy), stroke);
    return;
  }
  if (type.contains('diode')) {
    final Path tri = Path()
      ..moveTo(rect.left + w * 0.25, rect.top + h * 0.2)
      ..lineTo(rect.left + w * 0.25, rect.bottom - h * 0.2)
      ..lineTo(rect.right - w * 0.32, c.dy)
      ..close();
    canvas.drawPath(tri, stroke);
    canvas.drawLine(Offset(rect.right - w * 0.28, rect.top + h * 0.18), Offset(rect.right - w * 0.28, rect.bottom - h * 0.18), stroke);
    return;
  }
  if (type.contains('relais') || type.contains('bobine')) {
    final Rect coil = Rect.fromCenter(center: c, width: w * 0.48, height: h * 0.42);
    canvas.drawRRect(RRect.fromRectAndRadius(coil, Radius.circular(h * 0.12)), stroke);
    return;
  }

  canvas.drawRRect(
    RRect.fromRectAndRadius(rect.deflate(rect.shortestSide * 0.16), Radius.circular(rect.shortestSide * 0.14)),
    stroke,
  );
}
