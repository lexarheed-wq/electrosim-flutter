import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:electrosim_canvas/electrosim_canvas.dart';
import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'f18_voltmeter_3d_assets.dart';

/// LCD readouts are projected from the electrical runtime: invalid/disconnected
/// devices never manufacture a zero. The optional Cycles body is painted by
/// this same top overlay to keep the LCD and its texture in ONE transform.
final class F18PhysicalInstrumentReadouts extends CustomPainter {
  const F18PhysicalInstrumentReadouts({
    required this.layout,
    required this.viewport,
    required this.readouts,
    this.circuit,
    this.voltmeter3dIds = const <String>{},
    this.voltmeterFront,
    this.selectedElementId,
  });

  final CircuitVisualLayout layout;
  final ViewportController viewport;
  final Map<String, String> readouts;
  final CircuitState? circuit;
  final Set<String> voltmeter3dIds;
  final ui.Image? voltmeterFront;
  final String? selectedElementId;

  Rect? screenRect(String id) {
    final Offset? center = layout.positionOf(id);
    if (center == null) return null;
    final Size base = layout.sizeOf(id);
    final Offset screen = viewport.worldToScreen(center);
    return Rect.fromCenter(
      center: screen,
      width: base.width * viewport.scale,
      height: base.height * viewport.scale,
    );
  }

  /// The board footprint rotates with layout.quarterTurnsOf; transform both
  /// the image and its live LCD together, never the probe connections.
  void _paint3dRotated(
    Canvas canvas,
    String id,
    Rect screen,
    void Function(Rect localBody) paintLocal,
  ) {
    canvas.save();
    canvas.translate(screen.center.dx, screen.center.dy);
    canvas.rotate(layout.quarterTurnsOf(id) * math.pi / 2);
    paintLocal(Rect.fromCenter(
      center: Offset.zero,
      width: screen.width,
      height: screen.height,
    ));
    canvas.restore();
  }

  bool _inView(String id, Rect screen, Size viewportSize) {
    final Rect visualBounds = layout.quarterTurnsOf(id).isOdd
        ? Rect.fromCenter(
            center: screen.center,
            width: screen.height,
            height: screen.width,
          )
        : screen;
    return visualBounds.overlaps(Offset.zero & viewportSize);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final ui.Image? front = voltmeterFront;
    if (front != null) {
      // Draw first, independent of the reading map (OFF/ERR may be absent).
      for (final String id in voltmeter3dIds) {
        final Rect? rect = screenRect(id);
        if (rect == null || !_inView(id, rect, size)) continue;
        _paint3dRotated(canvas, id, rect, (Rect local) {
          canvas.drawImageRect(
            front,
            Rect.fromLTWH(
              0, 0, front.width.toDouble(), front.height.toDouble(),
            ),
            local,
            Paint()..filterQuality = FilterQuality.medium,
          );
          if (id == selectedElementId) {
            final Rect inner = local.deflate(2 * viewport.scale);
            canvas.drawRRect(
              RRect.fromRectAndRadius(
                inner, Radius.circular(8 * viewport.scale),
              ),
              Paint()
                ..color = const Color(0xFF2563EB)
                ..strokeWidth =
                    (2 * viewport.scale).clamp(1.5, 5.0).toDouble()
                ..style = PaintingStyle.stroke,
            );
          }
        });
      }
    }

    for (final MapEntry<String, String> item in readouts.entries) {
      final Rect? rect = screenRect(item.key);
      if (rect == null) continue;
      final bool original3d =
          front != null && voltmeter3dIds.contains(item.key);
      if (original3d && !_inView(item.key, rect, size)) continue;
      if (!original3d && !rect.overlaps(Offset.zero & size)) continue;
      if (original3d) {
        _paint3dRotated(canvas, item.key, rect, (Rect local) {
          _drawReading(
            canvas, F18Voltmeter3dAssets.projectReadout(local), item.value,
          );
        });
      } else {
        _drawReading(
          canvas,
          Rect.fromLTWH(
            rect.left + rect.width * 0.10,
            rect.top + rect.height * 0.11,
            rect.width * 0.80,
            rect.height * 0.38,
          ),
          item.value,
        );
      }
    }
    // These are graphical leads sourced EXCLUSIVELY from the real ProbeConnection
    // objects. Drawing them adds no electrical edges and cannot fake a reading.
    _paintConnectedProbes(canvas, front);
  }

  void _paintConnectedProbes(Canvas canvas, ui.Image? front) {
    final CircuitState? active = circuit;
    if (active == null || front == null || voltmeter3dIds.isEmpty) return;
    final CircuitGeometryIndex geometry =
        CircuitGeometryIndex.build(active, layout);
    for (final ProbeConnection probe in active.probes) {
      final String id = probe.instrumentId.value;
      if (!voltmeter3dIds.contains(id)) continue;
      if (probe.port != InstrumentPort.common &&
          probe.port != InstrumentPort.voltOhm) continue;
      final Rect? meter = screenRect(id);
      final Offset? targetWorld = geometry.terminalPositions[probe.terminalId];
      if (meter == null || targetWorld == null) continue;
      final bool common = probe.port == InstrumentPort.common;
      final Offset local = Offset(
        meter.width * (common ? 42 / 112 : 70 / 112) - meter.width / 2,
        meter.height * (128 / 152) - meter.height / 2,
      );
      final double angle = layout.quarterTurnsOf(id) * math.pi / 2;
      final Offset socket = meter.center + Offset(
        local.dx * math.cos(angle) - local.dy * math.sin(angle),
        local.dx * math.sin(angle) + local.dy * math.cos(angle),
      );
      final Offset target = viewport.worldToScreen(targetWorld);
      final double slack = 25 * viewport.scale;
      final double lane = socket.dy + slack;
      final Path cable = Path()
        ..moveTo(socket.dx, socket.dy)
        ..lineTo(socket.dx, lane)
        ..lineTo(target.dx, lane)
        ..lineTo(target.dx, target.dy);
      final Color color =
          common ? const Color(0xFF172027) : const Color(0xFFC92330);
      final Paint paint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(2, viewport.scale * 3.2)
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      canvas.drawPath(cable, paint);
      canvas.drawCircle(target, math.max(3, viewport.scale * 3), Paint()..color = color);
    }
  }

  void _drawReading(Canvas canvas, Rect display, String reading) {
    if (display.width <= 0 || display.height <= 0) return;
      final double radius = (3 * viewport.scale).clamp(1.0, 6.0).toDouble();
      canvas.save();
      canvas.clipRRect(
        RRect.fromRectAndRadius(display, Radius.circular(radius)),
      );
      canvas.drawRect(
        display,
        Paint()..color = const Color(0xFFD5E5D6),
      );
      final TextPainter text = TextPainter(
        text: TextSpan(
          text: reading,
          style: TextStyle(
            fontSize: (13 * viewport.scale).clamp(7, 22).toDouble(),
            fontWeight: FontWeight.w700,
            color: const Color(0xFF142C1F),
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout();
      // Shrink, don't clip, values such as 230.00 V / FUSE at low zoom.
      final double targetW = math.max(1, display.width - 4 * viewport.scale);
      final double targetH = math.max(1, display.height - 2 * viewport.scale);
      final double fit = math.min(
        1,
        math.min(targetW / math.max(1, text.width),
                 targetH / math.max(1, text.height)),
      );
      canvas.translate(display.center.dx, display.center.dy);
      canvas.scale(fit);
      text.paint(
        canvas,
        Offset(-text.width / 2, -text.height / 2),
      );
      canvas.restore();
      text.dispose();
  }

  @override
  bool shouldRepaint(covariant F18PhysicalInstrumentReadouts old) =>
      !identical(layout, old.layout) ||
      !identical(viewport, old.viewport) ||
      !identical(readouts, old.readouts) ||
      !identical(circuit, old.circuit) ||
      !identical(voltmeterFront, old.voltmeterFront) ||
      !setEquals(voltmeter3dIds, old.voltmeter3dIds) ||
      selectedElementId != old.selectedElementId;
}
