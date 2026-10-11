import 'package:flutter/material.dart';
import 'f18_crusher_3d_assets.dart';

/// Buttons intentionally inert. Selection exposes only the maintenance cover.
class F18CrusherVisual extends StatelessWidget {
  const F18CrusherVisual({
    super.key,
    required this.size,
    this.serviceOpen = false,
  });
  final Size size;
  final bool serviceOpen;
  @override
  Widget build(BuildContext context) => SizedBox.fromSize(
    size: size,
    child: F18Crusher3dAssets.ready
        ? RawImage(
            image: serviceOpen
                ? F18Crusher3dAssets.service
                : F18Crusher3dAssets.front,
            fit: BoxFit.fill,
            filterQuality: FilterQuality.high,
          )
        : CustomPaint(painter: _Fallback(serviceOpen)),
  );
}

class _Fallback extends CustomPainter {
  const _Fallback(this.open);
  final bool open;
  @override
  void paint(Canvas c, Size s) {
    c.save();
    c.scale(s.width / 240, s.height / 220);
    final paint = Paint()..color = const Color(0xff46535b);
    c.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(51, 75, 116, 130),
        const Radius.circular(2),
      ),
      paint,
    );
    final hopper = Path()
      ..moveTo(53, 13)
      ..lineTo(166, 13)
      ..lineTo(140, 56)
      ..lineTo(140, 80)
      ..lineTo(79, 80)
      ..lineTo(79, 56)
      ..close();
    c.drawPath(hopper, paint..color = const Color(0xffe5e6e2));
    c.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(136, 70, 57, 98),
        const Radius.circular(20),
      ),
      paint,
    );
    c.drawRect(
      const Rect.fromLTWH(87, 161, 52, 38),
      paint..color = const Color(0xff34424a),
    );
    if (open) {
      c.drawRect(
        const Rect.fromLTWH(90.5, 167.5, 45, 25),
        paint..color = const Color(0xff151c22),
      );
      for (final p in const [
        Offset(97, 174),
        Offset(107, 174),
        Offset(117, 174),
        Offset(107, 187),
        Offset(117, 187),
        Offset(97, 187),
        Offset(130, 187),
      ]) {
        c.drawCircle(p, 2.4, paint..color = const Color(0xffa7adb0));
      }
    }
    c.restore();
  }

  @override
  bool shouldRepaint(_Fallback old) => old.open != open;
}
