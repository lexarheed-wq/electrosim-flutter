import 'package:electrosim_pneumatic_domain/electrosim_pneumatic_domain.dart';
import 'package:flutter/material.dart';

/// Original, vector-only pneumatic pictograms. They are not photos or claims
/// of manufacturer-specific certified ISO 1219 symbol sets.
class PneumaticDeviceGlyph extends StatelessWidget {
  const PneumaticDeviceGlyph({
    super.key,
    required this.kind,
    required this.schematic,
    this.width = 118,
    this.height = 42,
  });

  final PneumaticDeviceKind kind;
  final bool schematic;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    height: height,
    child: CustomPaint(
      painter: _GlyphPainter(kind: kind, schematic: schematic),
    ),
  );
}

class _GlyphPainter extends CustomPainter {
  const _GlyphPainter({required this.kind, required this.schematic});

  final PneumaticDeviceKind kind;
  final bool schematic;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint line = Paint()
      ..color = const Color(0xff243340)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    final Paint fill = Paint()
      ..color = schematic
          ? const Color(0xfff9fafb)
          : const Color(0xffb7c3c9)
      ..style = PaintingStyle.fill;
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    final double scale = (size.width / 110 < size.height / 42
            ? size.width / 110
            : size.height / 42)
        .clamp(.1, 2.0);
    canvas.scale(scale);
    switch (kind) {
      case PneumaticDeviceKind.valve32:
      case PneumaticDeviceKind.valve52:
        final bool five = kind == PneumaticDeviceKind.valve52;
        canvas.drawRect(const Rect.fromLTWH(-35, -15, 35, 30), fill);
        canvas.drawRect(const Rect.fromLTWH(0, -15, 35, 30), fill);
        canvas.drawRect(const Rect.fromLTWH(-35, -15, 70, 30), line);
        canvas.drawLine(const Offset(0, -15), const Offset(0, 15), line);
        canvas.drawLine(const Offset(-26, 7), const Offset(-8, -7), line);
        canvas.drawLine(const Offset(-15, -7), const Offset(-8, -7), line);
        canvas.drawLine(const Offset(-8, -7), const Offset(-10, 1), line);
        canvas.drawLine(const Offset(7, -7), const Offset(27, 7), line);
        canvas.drawLine(const Offset(27, 7), const Offset(20, 6), line);
        canvas.drawLine(const Offset(27, 7), const Offset(25, 0), line);
        for (final double x in <double>[-22, five ? 20 : 15]) {
          canvas.drawLine(Offset(x, -21), Offset(x, -15), line);
          canvas.drawLine(Offset(x, 15), Offset(x, 21), line);
        }
        if (five) {
          canvas.drawLine(
            const Offset(0, 15),
            const Offset(0, 21),
            line,
          );
        }
        if (!schematic) {
          canvas.drawRect(const Rect.fromLTWH(-46, -12, 10, 24), fill);
          canvas.drawRect(const Rect.fromLTWH(-46, -12, 10, 24), line);
          canvas.drawCircle(const Offset(-41, 0), 3, line);
        }
      case PneumaticDeviceKind.doubleActingCylinder:
      case PneumaticDeviceKind.singleActingCylinder:
        canvas.drawRect(const Rect.fromLTWH(-39, -15, 66, 30), fill);
        canvas.drawRect(const Rect.fromLTWH(-39, -15, 66, 30), line);
        canvas.drawLine(const Offset(8, -15), const Offset(8, 15), line);
        canvas.drawLine(const Offset(8, 0), const Offset(49, 0), line);
        canvas.drawLine(const Offset(-25, 15), const Offset(-25, 21), line);
        if (kind == PneumaticDeviceKind.doubleActingCylinder) {
          canvas.drawLine(const Offset(21, 15), const Offset(21, 21), line);
        } else {
          canvas.drawLine(const Offset(-15, 0), const Offset(-10, -7), line);
          canvas.drawLine(const Offset(-10, -7), const Offset(-4, 7), line);
          canvas.drawLine(const Offset(-4, 7), const Offset(3, 0), line);
        }
      case PneumaticDeviceKind.idealSource:
        canvas.drawCircle(Offset.zero, 16, fill);
        canvas.drawCircle(Offset.zero, 16, line);
        canvas.drawLine(const Offset(-7, 5), const Offset(0, -8), line);
        canvas.drawLine(const Offset(0, -8), const Offset(7, 5), line);
        canvas.drawLine(const Offset(-7, 5), const Offset(7, 5), line);
        canvas.drawLine(const Offset(0, -16), const Offset(0, -21), line);
      case PneumaticDeviceKind.manometer:
        canvas.drawCircle(Offset.zero, 17, fill);
        canvas.drawCircle(Offset.zero, 17, line);
        canvas.drawLine(const Offset(-9, 7), const Offset(5, -9), line);
        canvas.drawCircle(const Offset(0, 0), 2, line);
        canvas.drawLine(const Offset(0, 17), const Offset(0, 22), line);
      case PneumaticDeviceKind.tee:
        canvas.drawLine(const Offset(-27, 0), const Offset(27, 0), line);
        canvas.drawLine(const Offset(0, 0), const Offset(0, 22), line);
        canvas.drawCircle(Offset.zero, 3, line);
      case PneumaticDeviceKind.checkValve:
        canvas.drawLine(const Offset(-35, 0), const Offset(35, 0), line);
        canvas.drawLine(const Offset(0, -13), const Offset(0, 13), line);
        canvas.drawLine(const Offset(-18, -12), const Offset(-18, 12), line);
        canvas.drawLine(const Offset(-18, -12), const Offset(0, 0), line);
        canvas.drawLine(const Offset(-18, 12), const Offset(0, 0), line);
      case PneumaticDeviceKind.restrictor:
        canvas.drawLine(const Offset(-35, 0), const Offset(35, 0), line);
        canvas.drawLine(const Offset(-16, -10), const Offset(0, 0), line);
        canvas.drawLine(const Offset(-16, 10), const Offset(0, 0), line);
        canvas.drawLine(const Offset(16, -10), const Offset(0, 0), line);
        canvas.drawLine(const Offset(16, 10), const Offset(0, 0), line);
        canvas.drawLine(const Offset(-20, 18), const Offset(20, -18), line);
      case PneumaticDeviceKind.silencer:
        canvas.drawRect(const Rect.fromLTWH(-15, -14, 30, 28), fill);
        canvas.drawRect(const Rect.fromLTWH(-15, -14, 30, 28), line);
        for (int i = -10; i <= 10; i += 5) {
          canvas.drawLine(Offset(i.toDouble(), -12), Offset(i.toDouble() + 6, 12), line);
        }
      default:
        canvas.drawCircle(Offset.zero, 16, fill);
        canvas.drawCircle(Offset.zero, 16, line);
        canvas.drawLine(const Offset(-8, 0), const Offset(8, 0), line);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _GlyphPainter previous) =>
      previous.kind != kind || previous.schematic != schematic;
}
