import 'dart:math' as math;

import 'package:flutter/painting.dart';

/// A thin zinc-plated mounting sheet. Coordinates, grain and mounting holes
/// belong to the world, so they stay attached to the plate during pan/zoom.
/// This artwork carries no electrical or placement constraints.
const metalWorkspaceColor = Color(0xFFE3E7EB);

Paint mountingPlateSurfacePaint(Rect rect) =>
    Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFFD7DCDE),
          Color(0xFFE7EAEA),
          Color(0xFFD1D7D9),
          Color(0xFFE0E4E5),
          Color(0xFFCDD3D6),
        ],
        stops: [0, .24, .52, .78, 1],
      ).createShader(rect);

Rect mountingPlateBounds(Iterable<Rect> contents) {
  Rect? bounds;
  for (final rect in contents) {
    bounds = bounds == null ? rect : bounds.expandToInclude(rect);
  }
  if (bounds == null) return const Rect.fromLTWH(-80, -80, 1280, 840);
  final padded = bounds.inflate(48);
  return Rect.fromLTWH(
    padded.left,
    padded.top,
    math.max(960, padded.width),
    math.max(640, padded.height),
  );
}

void paintMetalMountingPlate(
  Canvas canvas, {
  required Size viewportSize,
  required Rect screenBounds,
  required double scale,
}) {
  canvas.drawRect(
    Offset.zero & viewportSize,
    Paint()..color = metalWorkspaceColor,
  );
  final sheet = RRect.fromRectAndRadius(
    screenBounds,
    Radius.circular(2 * scale),
  );
  // A slight edge shadow suggests thin sheet metal, rather than a thick case.
  canvas.drawRRect(
    sheet.shift(Offset(0, 2 * scale)),
    Paint()..color = const Color(0x240F1C25),
  );
  canvas.drawRRect(sheet, mountingPlateSurfacePaint(screenBounds));
  canvas.save();
  canvas.clipRRect(sheet);
  if (scale >= .35) {
    // Bounded, deterministic horizontal grain. No noise bitmap or per-frame
    // random generation; at most 192 strokes, including on very large boards.
    final step = math.max(4 * scale, screenBounds.height / 192);
    final light = Paint()
      ..color = const Color(0x0CFFFFFF)
      ..strokeWidth = .7;
    final dark = Paint()
      ..color = const Color(0x0454656F)
      ..strokeWidth = .6;
    for (var i = 1; i < 192; i++) {
      final y = screenBounds.top + i * step;
      if (y >= screenBounds.bottom) break;
      if (y < 0 || y > viewportSize.height) continue;
      final inset = ((i * 37) % 101) / 101 * screenBounds.width * .12;
      canvas.drawLine(
        Offset(screenBounds.left + inset, y),
        Offset(screenBounds.right - inset * .6, y),
        i.isEven ? light : dark,
      );
    }
  }
  canvas.restore();
  canvas.drawRRect(
    sheet,
    Paint()
      ..color = const Color(0xFF89969E)
      ..style = PaintingStyle.stroke
      ..strokeWidth = (1.1 * scale).clamp(.6, 2).toDouble(),
  );
  canvas.drawLine(
    screenBounds.topLeft + Offset(2 * scale, scale),
    screenBounds.topRight + Offset(-2 * scale, scale),
    Paint()
      ..color = const Color(0xBAFFFFFF)
      ..strokeWidth = scale.clamp(.6, 2).toDouble(),
  );
  if (scale < .25) return;
  final inset = 22 * scale;
  for (final center in [
    screenBounds.topLeft + Offset(inset, inset),
    screenBounds.topRight + Offset(-inset, inset),
    screenBounds.bottomLeft + Offset(inset, -inset),
    screenBounds.bottomRight + Offset(-inset, -inset),
  ]) {
    _paintMountingFixing(canvas, center, scale);
  }
}

void _paintMountingFixing(Canvas canvas, Offset center, double scale) {
  final rim = Rect.fromCenter(
    center: center,
    width: 14 * scale,
    height: 14 * scale,
  );
  canvas.drawOval(
    rim.shift(Offset(0, scale)),
    Paint()..color = const Color(0x30000000),
  );
  canvas.drawOval(
    rim,
    Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFF5F6F6), Color(0xFF8B969C), Color(0xFFE3E7E8)],
      ).createShader(rim),
  );
  canvas.drawOval(
    rim.deflate(2 * scale),
    Paint()
      ..shader = const RadialGradient(
        center: Alignment(-.35, -.4),
        colors: [Color(0xFFE7EBEB), Color(0xFFAFB8BD), Color(0xFF76858D)],
      ).createShader(rim),
  );
  final slot = Paint()
    ..color = const Color(0xFF4E5B62)
    ..strokeWidth = 1.5 * scale
    ..strokeCap = StrokeCap.round;
  canvas.drawLine(
    center - Offset(3 * scale, 0),
    center + Offset(3 * scale, 0),
    slot,
  );
  canvas.drawLine(
    center - Offset(0, 3 * scale),
    center + Offset(0, 3 * scale),
    slot,
  );
}
