import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The same component artwork is used in both locations. Only its *camera*
/// changes: palette items have a shallow product perspective; the board stays
/// strictly frontal so its saved terminal geometry and hit testing do not move.
///
/// This is a visual projection, not a new electrical component or solver model.
enum F18IndustrialPresentation { palettePerspective, boardFront }

enum F18IndustrialFamily {
  modularProtection,
  switching,
  drive,
  solar,
  enclosure,
  instrument,
  passive,
}

abstract final class F18IndustrialIdentity {
  static F18IndustrialFamily familyOf(String modelType) {
    final type = modelType.toLowerCase();
    if (type.startsWith('physical_') ||
        type.contains('voltmeter') ||
        type.contains('ammeter')) {
      return F18IndustrialFamily.instrument;
    }
    if (type.contains('breaker') ||
        type.contains('fuse') ||
        type.contains('isolator') ||
        type.contains('thermal_overload') ||
        type.contains('terminal_block')) {
      return F18IndustrialFamily.modularProtection;
    }
    if (type.contains('contactor') ||
        type.contains('relay') ||
        type.contains('switch') ||
        type.contains('push_button')) {
      return F18IndustrialFamily.switching;
    }
    if (type.contains('motor') || type.contains('fan') ||
        type.contains('generator')) {
      return F18IndustrialFamily.drive;
    }
    if (type.startsWith('pv_')) return F18IndustrialFamily.solar;
    if (type.contains('source') ||
        type.contains('battery') ||
        type.contains('controller') ||
        type.contains('inverter') ||
        type.contains('appliance') ||
        type.contains('sensor') ||
        type.contains('actuator')) {
      return F18IndustrialFamily.enclosure;
    }
    return F18IndustrialFamily.passive;
  }
}

/// Visual-only adapter for the complete ElectroSim catalogue.
///
/// [child] MUST be an existing canonical component painter. In boardFront
/// mode this widget does not touch its pixels or positions. In the palette a
/// fixed camera makes the exact same front-facing identity look three-quarter.
/// No manufacturer or invented electrical specification is rendered here.
class F18IndustrialDualView extends StatelessWidget {
  const F18IndustrialDualView({
    super.key,
    required this.modelType,
    required this.size,
    required this.presentation,
    required this.child,
  });

  final String modelType;
  final Size size;
  final F18IndustrialPresentation presentation;
  final Widget child;

  static const double paletteYawDegrees = 10;
  static const double palettePitchDegrees = -12;
  static const double boardYawDegrees = 0;
  static const double boardPitchDegrees = 0;

  @visibleForTesting
  static Matrix4 paletteCamera() => Matrix4.identity()
    ..setEntry(3, 2, 0.0008)
    ..rotateX(palettePitchDegrees * math.pi / 180)
    ..rotateY(paletteYawDegrees * math.pi / 180);

  @override
  Widget build(BuildContext context) {
    if (presentation == F18IndustrialPresentation.boardFront) {
      // No transform whatsoever: identical board pixels, hit regions and
      // terminal coordinates, including quarter-turn rotations.
      return child;
    }

    final family = F18IndustrialIdentity.familyOf(modelType);
    // The artwork remains the source of truth; the extrusion is a subtle
    // backdrop only for box-shaped equipment. Motors and passive parts never
    // receive a fake rectangular casing.
    return SizedBox(
      width: size.width,
      height: size.height,
      child: RepaintBoundary(
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            CustomPaint(painter: _F18IndustrialDepthPainter(family)),
            Center(
              child: Transform(
                alignment: Alignment.center,
                transform: paletteCamera(),
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: SizedBox(
                    width: size.width * .88,
                    height: size.height * .86,
                    child: FittedBox(fit: BoxFit.contain, child: child),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

final class _F18IndustrialDepthPainter extends CustomPainter {
  const _F18IndustrialDepthPainter(this.family);

  final F18IndustrialFamily family;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final w = size.width;
    final h = size.height;
    final shadow = Rect.fromCenter(
      center: Offset(w * .52, h * .88),
      width: w * .66,
      height: h * .09,
    );
    canvas.drawOval(
      shadow,
      Paint()
        ..color = const Color(0x220C1827)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );

    // These families have a meaningful rectangular enclosure or DIN housing.
    final boxed = family == F18IndustrialFamily.modularProtection ||
        family == F18IndustrialFamily.switching ||
        family == F18IndustrialFamily.enclosure ||
        family == F18IndustrialFamily.instrument ||
        family == F18IndustrialFamily.solar;
    if (!boxed) return;

    final front = Rect.fromLTWH(w * .12, h * .14, w * .70, h * .69);
    final depth = math.min(w, h) * .085;
    final backShift = Offset(depth * .78, -depth * .65);
    final top = Path()
      ..moveTo(front.left, front.top)
      ..lineTo(front.left + backShift.dx, front.top + backShift.dy)
      ..lineTo(front.right + backShift.dx, front.top + backShift.dy)
      ..lineTo(front.right, front.top)
      ..close();
    final right = Path()
      ..moveTo(front.right, front.top)
      ..lineTo(front.right + backShift.dx, front.top + backShift.dy)
      ..lineTo(front.right + backShift.dx, front.bottom + backShift.dy)
      ..lineTo(front.right, front.bottom)
      ..close();

    final colors = switch (family) {
      F18IndustrialFamily.instrument =>
        (const Color(0xFF334459), const Color(0xFF1F2D3C)),
      F18IndustrialFamily.solar =>
        (const Color(0xFFE5EDF0), const Color(0xFF889DAB)),
      _ => (const Color(0xFFF6F8F5), const Color(0xFFB5BEC2)),
    };

    canvas.drawPath(
      top,
      Paint()
        ..shader = LinearGradient(
          colors: [colors.$1, colors.$2],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(top.getBounds()),
    );
    canvas.drawPath(
      right,
      Paint()
        ..shader = LinearGradient(
          colors: [colors.$1, colors.$2],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ).createShader(right.getBounds()),
    );
  }

  @override
  bool shouldRepaint(covariant _F18IndustrialDepthPainter old) =>
      old.family != family;
}
