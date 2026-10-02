import 'dart:math' as math;

import 'package:electrosim_canvas/electrosim_canvas.dart';
import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:electrosim_ui_kit/electrosim_ui_kit.dart';
import 'package:flutter/material.dart';

import 'f18_component_archetypes.dart';
import 'f9_wiring_policy.dart';

class F9CanvasVisualOverlay extends StatelessWidget {
  const F9CanvasVisualOverlay({
    super.key,
    required this.circuit,
    required this.layout,
    required this.viewport,
    this.pendingTerminalId,
    this.hoverTerminalId,
    this.pointerWorldPosition,
    this.wirePreviewPlanner,
    this.paintElementGlyphs = true,
  });

  final CircuitState circuit;
  final CircuitVisualLayout layout;
  final ViewportController viewport;
  final TerminalId? pendingTerminalId;
  final TerminalId? hoverTerminalId;
  final Offset? pointerWorldPosition;
  final WirePreviewPlanner? wirePreviewPlanner;
  final bool paintElementGlyphs;

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
          pointerWorldPosition: pointerWorldPosition,
          wirePreviewPlanner: wirePreviewPlanner,
          paintElementGlyphs: paintElementGlyphs,
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
    required this.pointerWorldPosition,
    required this.wirePreviewPlanner,
    required this.paintElementGlyphs,
  });

  final CircuitState circuit;
  final CircuitVisualLayout layout;
  final ViewportController viewport;
  final TerminalId? pendingTerminalId;
  final TerminalId? hoverTerminalId;
  final Offset? pointerWorldPosition;
  final WirePreviewPlanner? wirePreviewPlanner;
  final bool paintElementGlyphs;

  @override
  void paint(Canvas canvas, Size size) {
    final CircuitGeometryIndex geometry = CircuitGeometryIndex.build(circuit, layout);
    _paintSmartWirePreview(canvas);
    if (paintElementGlyphs) {
      for (final SourceInstance source in circuit.sources) {
        final Rect? rect = geometry.elementRects[source.id.value];
        if (rect == null) {
          continue;
        }
        _paintElementGlyph(
          canvas,
          rect,
          source.modelType,
          source.enabled,
          layout.quarterTurnsOf(source.id.value),
        );
      }
      for (final ComponentInstance component in circuit.components) {
        final Rect? rect = geometry.elementRects[component.id.value];
        if (rect == null) {
          continue;
        }
        final Object? closed = component.controlState['closed'];
        final bool active =
            component.condition != ComponentCondition.disabled &&
                closed != false;
        _paintElementGlyph(
          canvas,
          rect,
          component.modelType,
          active,
          layout.quarterTurnsOf(component.id.value),
        );
      }
    }
    _paintFaultMarkers(canvas, geometry);
    _paintWiringTargets(canvas, geometry);
  }

  void _paintSmartWirePreview(Canvas canvas) {
    final TerminalId? pending = pendingTerminalId;
    final Offset? pointer = pointerWorldPosition;
    final WirePreviewPlanner? planner = wirePreviewPlanner;
    if (pending == null || pointer == null || planner == null) {
      return;
    }

    final WirePreviewPlan plan = planner.plan(
      circuit: circuit,
      layout: layout,
      startTerminalId: pending,
      pointerWorldPosition: pointer,
    );
    if (!plan.route.isResolved) {
      return;
    }

    final List<Offset> points = plan.route.path!.points;
    if (points.length < 2) {
      return;
    }
    final Path path = Path();
    final Offset first = viewport.worldToScreen(points.first);
    path.moveTo(first.dx, first.dy);
    for (final Offset point in points.skip(1)) {
      final Offset screen = viewport.worldToScreen(point);
      path.lineTo(screen.dx, screen.dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = ElectroSimColors.primary
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  void _paintFaultMarkers(
    Canvas canvas,
    CircuitGeometryIndex geometry,
  ) {
    for (final ComponentInstance component in circuit.components) {
      if (component.condition == ComponentCondition.normal) {
        continue;
      }
      final Rect? worldRect = geometry.elementRects[component.id.value];
      if (worldRect == null) {
        continue;
      }
      final Offset topLeft = viewport.worldToScreen(worldRect.topLeft);
      final Offset bottomRight = viewport.worldToScreen(worldRect.bottomRight);
      final Rect screenRect = Rect.fromPoints(topLeft, bottomRight).inflate(7);
      final RRect outline = RRect.fromRectAndRadius(
        screenRect,
        const Radius.circular(14),
      );
      canvas.drawRRect(
        outline,
        Paint()
          ..color = const Color(0xFFF59E0B)
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke,
      );
      final Offset badgeCenter = Offset(
        screenRect.right - 3,
        screenRect.top + 3,
      );
      canvas.drawCircle(
        badgeCenter,
        10,
        Paint()..color = const Color(0xFFC2410C),
      );
      final TextPainter warning = TextPainter(
        text: const TextSpan(
          text: '!',
          style: TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      warning.paint(
        canvas,
        Offset(
          badgeCenter.dx - warning.width / 2,
          badgeCenter.dy - warning.height / 2,
        ),
      );
    }
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

  void _paintElementGlyph(
    Canvas canvas,
    Rect worldRect,
    String modelType,
    bool active,
    int quarterTurns,
  ) {
    final Offset center = viewport.worldToScreen(worldRect.center);
    final double scale = viewport.scale.clamp(0.65, 1.5).toDouble();
    final double visualWidth = 46 * scale;
    final double visualHeight = 32 * scale;
    final Offset visualCenter =
        Offset(center.dx, center.dy - (10 * scale));
    final Color color =
        active ? ElectroSimColors.primary : ElectroSimColors.textSecondary;

    canvas.save();
    canvas.translate(visualCenter.dx, visualCenter.dy);
    canvas.rotate(math.pi / 2 * quarterTurns);
    paintF18ElectricalArchetype(
      canvas,
      Rect.fromCenter(
        center: Offset.zero,
        width: visualWidth,
        height: visualHeight,
      ),
      modelType,
      color,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_F9CanvasOverlayPainter oldDelegate) => true;
}
