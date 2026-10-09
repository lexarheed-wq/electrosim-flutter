import 'package:electrosim_canvas/electrosim_canvas.dart';
import 'package:flutter/material.dart';

/// LCD readouts are painted above the physical meter bodies. Invalid or
/// disconnected devices show a state, never a fabricated zero-voltage reading.
/// Projection is performed outside paint() and cached by the workspace.
final class F18PhysicalInstrumentReadouts extends CustomPainter {
  const F18PhysicalInstrumentReadouts({
    required this.layout,
    required this.viewport,
    required this.readouts,
  });

  final CircuitVisualLayout layout;
  final ViewportController viewport;
  final Map<String, String> readouts;

  @override
  void paint(Canvas canvas, Size size) {
    for (final MapEntry<String, String> item in readouts.entries) {
      final Offset? center = layout.positionOf(item.key);
      if (center == null) continue;
      final Size base = layout.sizeOf(item.key);
      final Offset screen = viewport.worldToScreen(center);
      final Rect rect = Rect.fromCenter(
        center: screen,
        width: base.width * viewport.scale,
        height: base.height * viewport.scale,
      );
      if (rect.right < 0 ||
          rect.bottom < 0 ||
          rect.left > size.width ||
          rect.top > size.height) {
        continue;
      }
      final Rect display = Rect.fromLTWH(
        rect.left + rect.width * 0.10,
        rect.top + rect.height * 0.11,
        rect.width * 0.80,
        rect.height * 0.38,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(display, Radius.circular(3 * viewport.scale)),
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
      )..layout(maxWidth: display.width);
      text.paint(
        canvas,
        Offset(
          display.center.dx - text.width / 2,
          display.center.dy - text.height / 2,
        ),
      );
    }
  }

  @override
  bool shouldRepaint(covariant F18PhysicalInstrumentReadouts old) =>
      !identical(layout, old.layout) ||
      !identical(viewport, old.viewport) ||
      !identical(readouts, old.readouts);
}
