
import 'package:flutter/painting.dart';

import 'cabinet_layout.dart';
import 'din_rail_visual.dart';

/// Draws cabinet furniture beneath wires and physical devices.
/// Furniture has no terminals, current, voltage or solver identity.
void paintCabinetFixtures(
  Canvas canvas, {
  required CabinetLayout cabinet,
  required Offset Function(Offset) worldToScreen,
  required double scale,
}) {
  for (final fixture in cabinet.fixtures) {
    final leftTop = worldToScreen(fixture.bounds.topLeft);
    final bounds = Rect.fromLTWH(
      leftTop.dx,
      leftTop.dy,
      fixture.bounds.width * scale,
      fixture.bounds.height * scale,
    );
    switch (fixture.kind) {
      case CabinetFixtureKind.dinRail:
        paintDinRail(canvas, bounds, scale: scale);
      case CabinetFixtureKind.wireDuct:
        _paintDuct(canvas, bounds, scale);
      case CabinetFixtureKind.terminalZone:
        _paintTerminalZone(canvas, bounds, scale);
    }
  }
}

void _paintDuct(Canvas canvas, Rect rect, double scale) {
  final body = RRect.fromRectAndRadius(rect, Radius.circular(3 * scale));
  canvas.drawRRect(body, Paint()..color = const Color(0xFFE0E5EB));
  canvas.drawRRect(
    body,
    Paint()
      ..color = const Color(0xFF667583)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1 * scale,
  );
  // Slots visually communicate a real wiring duct, not a generic rectangle.
  final horizontal = rect.width >= rect.height;
  final span = horizontal ? rect.width : rect.height;
  final step = 13.0 * scale;
  for (var distance = step; distance < span - step; distance += step) {
    final slot = horizontal
        ? Rect.fromLTWH(
            rect.left + distance,
            rect.top + 3 * scale,
            4 * scale,
            (rect.height - 6 * scale).clamp(0, double.infinity).toDouble(),
          )
        : Rect.fromLTWH(
            rect.left + 3 * scale,
            rect.top + distance,
            (rect.width - 6 * scale).clamp(0, double.infinity).toDouble(),
            4 * scale,
          );
    canvas.drawRRect(
      RRect.fromRectAndRadius(slot, Radius.circular(1.2 * scale)),
      Paint()..color = const Color(0xFF98A6B2),
    );
  }
}

void _paintTerminalZone(Canvas canvas, Rect rect, double scale) {
  canvas.drawRRect(
    RRect.fromRectAndRadius(rect, Radius.circular(3 * scale)),
    Paint()..color = const Color(0x0C4B647B),
  );
  canvas.drawRRect(
    RRect.fromRectAndRadius(rect, Radius.circular(3 * scale)),
    Paint()
      ..color = const Color(0xFF74899A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1 * scale,
  );
  final paint = Paint()
    ..color = const Color(0xFF9BA9B6)
    ..strokeWidth = scale;
  final centerY = rect.center.dy;
  canvas.drawLine(
    Offset(rect.left + 5 * scale, centerY),
    Offset(rect.right - 5 * scale, centerY),
    paint,
  );
}

void paintCabinetSelection(
  Canvas canvas, {
  required CabinetFixture? fixture,
  required Offset Function(Offset) worldToScreen,
  required double scale,
}) {
  if (fixture == null) return;
  final topLeft = worldToScreen(fixture.bounds.topLeft);
  final bounds =
      topLeft &
      Size(fixture.bounds.width * scale, fixture.bounds.height * scale);
  canvas.drawRect(
    bounds.inflate(2),
    Paint()
      ..color = const Color(0xFF2563EB)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2,
  );
  final handleSize = 12.0;
  canvas.drawRect(
    Rect.fromCenter(
      center: bounds.bottomRight,
      width: handleSize,
      height: handleSize,
    ),
    Paint()..color = const Color(0xFF2563EB),
  );
}

/// Frontal open enclosure and its usable mounting plate, in authored mm.
void paintCabinetEnvelope(
  Canvas canvas, {
  required CabinetLayout cabinet,
  required Offset Function(Offset) worldToScreen,
  required double scale,
}) {
  final envelope = cabinet.envelope;
  if (envelope == null) return;
  Rect screen(Rect r) => Rect.fromLTWH(
    worldToScreen(r.topLeft).dx,
    worldToScreen(r.topLeft).dy,
    r.width * scale,
    r.height * scale,
  );
  final r = screen(envelope.bounds), plate = screen(envelope.plateBounds);
  canvas.drawRect(
    r.shift(Offset(5 * scale, 5 * scale)),
    Paint()..color = const Color(0x350F172A),
  );
  canvas.drawRect(
    r,
    Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF9DAAB6), Color(0xFFE2E8EF), Color(0xFF98A7B5)],
      ).createShader(r),
  );
  canvas.drawRect(
    r,
    Paint()
      ..color = const Color(0xFF64748B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2 * scale,
  );
  canvas.drawRect(plate, Paint()..color = const Color(0xFFF2F4F6));
  canvas.drawRect(
    plate,
    Paint()
      ..color = const Color(0xFFBAC5CF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = scale,
  );
  for (final p in [
    plate.topLeft,
    plate.topRight,
    plate.bottomLeft,
    plate.bottomRight,
  ]) {
    canvas.drawCircle(p, 3 * scale, Paint()..color = const Color(0xFF64748B));
  }
}
