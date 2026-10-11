import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:electrosim_canvas/electrosim_canvas.dart';
import 'f18_native_appliance_assets.dart';

/// Presentation follows resolved electrical state; never generates physics.
class F18NativeApplianceVisual extends StatelessWidget {
  const F18NativeApplianceVisual({
    super.key,
    required this.spec,
    required this.size,
    this.serviceOpen = false,
    this.energized = false,
    this.phase = 0,
  });
  final NativeApplianceGeometry spec;
  final Size size;
  final bool serviceOpen, energized;
  final double phase;
  @override
  Widget build(BuildContext context) {
    final images = F18NativeApplianceAssets.images(spec.key);
    return SizedBox.fromSize(
      size: size,
      child: RepaintBoundary(
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (images != null)
              RepaintBoundary(
                child: RawImage(
                  image: serviceOpen ? images.service : images.front,
                  fit: BoxFit.fill,
                  filterQuality: FilterQuality.high,
                ),
              )
            else
              CustomPaint(painter: _NativeFallback(spec, serviceOpen)),
            CustomPaint(painter: _OperatingDetails(spec, energized, phase)),
          ],
        ),
      ),
    );
  }
}

class _NativeFallback extends CustomPainter {
  const _NativeFallback(this.spec, this.open);
  final NativeApplianceGeometry spec;
  final bool open;
  @override
  void paint(Canvas c, Size s) {
    c.save();
    c.scale(s.width / spec.designSize.width, s.height / spec.designSize.height);
    final p = Paint()..color = const Color(0xffc4cdd1);
    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          10,
          10,
          spec.designSize.width - 20,
          spec.designSize.height - 20,
        ),
        const Radius.circular(6),
      ),
      p,
    );
    c.drawRRect(
      RRect.fromRectAndRadius(spec.serviceBox, const Radius.circular(2)),
      p..color = const Color(0xff253037),
    );
    if (open) {
      for (final point in spec.ports) {
        c.drawCircle(point, 2, p..color = const Color(0xffb8ac77));
      }
    }
    c.restore();
  }

  @override
  bool shouldRepaint(_NativeFallback old) =>
      old.spec != spec || old.open != open;
}

class _OperatingDetails extends CustomPainter {
  const _OperatingDetails(this.spec, this.on, this.phase);
  final NativeApplianceGeometry spec;
  final bool on;
  final double phase;
  @override
  void paint(Canvas c, Size s) {
    if (!on) return;
    c.save();
    c.scale(s.width / spec.designSize.width, s.height / spec.designSize.height);
    final paint = Paint();
    switch (spec.key) {
      case 'external-air-conditioner':
        for (var i = 0; i < 3; i++) {
          final y = 119 + (phase * 14 + i * 5) % 16;
          c.drawLine(
            Offset(75 + i * 60, y),
            Offset(106 + i * 60, y),
            paint
              ..color = const Color(0xff85c4dd).withValues(alpha: .25)
              ..strokeWidth = 1.2,
          );
        }
        c.drawCircle(
          const Offset(276, 88),
          1.2,
          paint..color = const Color(0xff55b983),
        );
      case 'external-compressor':
        c.drawCircle(
          const Offset(41, 43),
          1,
          paint..color = const Color(0xff55b983),
        );
      case 'external-freezer':
        c.drawRect(
          const Rect.fromLTWH(255, 135, 16, 8),
          paint..color = const Color(0xff306957),
        );
        // Status bars, no invented thermostat temperature.
        for (var i = 0; i < 3; i++) {
          c.drawRect(
            Rect.fromLTWH(257 + i * 4, 137, 2, 4),
            paint..color = const Color(0xff90d9ba),
          );
        }
      case 'external-conveyor':
        for (var i = 0; i < 4; i++) {
          final x = 28 + (phase * 294 + i * 73.5) % 294;
          c.drawLine(
            Offset(x, 64),
            Offset(x, 69),
            paint
              ..color = const Color(0xffaab2ae)
              ..strokeWidth = .7,
          );
        }
      case 'external-iron':
        c.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(165.5, 89.5, 5, 3),
            const Radius.circular(1),
          ),
          paint..color = const Color(0xffec9952),
        );
      case 'external-computer':
        final screen = const Rect.fromLTWH(23, 29, 232, 126);
        c.drawRect(
          screen,
          paint
            ..shader = const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xff102a45), Color(0xff237f9b), Color(0xff153c61)],
            ).createShader(screen),
        );
        paint.shader = null;
        // Abstract active desktop; no embedded OS or unsupported application.
        c.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(90, 61, 112, 59),
            const Radius.circular(3),
          ),
          paint..color = const Color(0xffd3e3e7),
        );
        c.drawRect(
          const Rect.fromLTWH(90, 61, 112, 7),
          paint..color = const Color(0xff364f64),
        );
        for (var i = 0; i < 3; i++) {
          c.drawRect(
            Rect.fromLTWH(100, 77 + i * 12, 73 - i * 14, 3),
            paint..color = const Color(0xff6e939f),
          );
        }
      // The mixer workhead's outer stator is stationary. Its hidden rotor
      // does not justify rotating the housing or the external perforations.
      default:
        break;
    }
    // Software activity marker, deliberately outside the hardware surfaces.
    // It is neither a real LED nor a pressure/temperature measurement.
    final p = Offset(spec.designSize.width - 10, 10);
    c.drawCircle(p, 4, paint..color = const Color(0xff168a69));
    c.drawArc(
      Rect.fromCircle(center: p, radius: 6),
      phase * (math.pi * 2),
      math.pi * 1.35,
      false,
      paint
        ..color = const Color(0xff168a69)
        ..style = PaintingStyle.stroke
        ..strokeWidth = .8,
    );
    c.restore();
  }

  @override
  bool shouldRepaint(_OperatingDetails old) =>
      old.spec != spec || old.on != on || (on && old.phase != phase);
}
