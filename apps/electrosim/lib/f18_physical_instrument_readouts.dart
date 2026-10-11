import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:electrosim_canvas/electrosim_canvas.dart';
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
    this.voltmeter3dIds = const <String>{},
    this.voltmeterFront,
    this.selectedElementId,
  });

  final CircuitVisualLayout layout;
  final ViewportController viewport;
  final Map<String, String> readouts;
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

  @override
  void paint(Canvas canvas, Size size) {
    final ui.Image? front = voltmeterFront;
    if (front != null) {
      // Draw first, independent of the reading map (OFF/ERR may be absent).
      for (final String id in voltmeter3dIds) {
        final Rect? rect = screenRect(id);
        if (rect == null || !rect.overlaps(Offset.zero & size)) continue;
        canvas.drawImageRect(
          front,
          Rect.fromLTWH(0, 0, front.width.toDouble(), front.height.toDouble()),
          rect,
          Paint()..filterQuality = FilterQuality.medium,
        );
        if (id == selectedElementId) {
          final Rect inner = rect.deflate(2 * viewport.scale);
          canvas.drawRRect(
            RRect.fromRectAndRadius(inner, Radius.circular(8 * viewport.scale)),
            Paint()
              ..color = const Color(0xFF2563EB)
              ..strokeWidth = (2 * viewport.scale).clamp(1.5, 5.0).toDouble()
              ..style = PaintingStyle.stroke,
          );
        }
      }
    }

    for (final MapEntry<String, String> item in readouts.entries) {
      final Rect? rect = screenRect(item.key);
      if (rect == null || !rect.overlaps(Offset.zero & size)) continue;
      final bool original3d =
          front != null && voltmeter3dIds.contains(item.key);
      final Rect display = original3d
          ? F18Voltmeter3dAssets.projectReadout(rect)
          : Rect.fromLTWH(
              rect.left + rect.width * 0.10,
              rect.top + rect.height * 0.11,
              rect.width * 0.80,
              rect.height * 0.38,
            );
      if (display.width <= 0 || display.height <= 0) continue;
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
          text: item.value,
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
  }

  @override
  bool shouldRepaint(covariant F18PhysicalInstrumentReadouts old) =>
      !identical(layout, old.layout) ||
      !identical(viewport, old.viewport) ||
      !identical(readouts, old.readouts) ||
      !identical(voltmeterFront, old.voltmeterFront) ||
      !setEquals(voltmeter3dIds, old.voltmeter3dIds) ||
      selectedElementId != old.selectedElementId;
}
