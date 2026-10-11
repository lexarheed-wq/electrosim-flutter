import 'package:flutter/material.dart';

/// Separate supply and mating contacts; shared with TerminalVisualProfile.
class F18PowerSocketVisual extends StatelessWidget {
  const F18PowerSocketVisual({super.key, required this.size, this.dc = false});
  final Size size;
  final bool dc;
  @override
  Widget build(BuildContext context) => SizedBox.fromSize(
    size: size,
    child: CustomPaint(painter: _SocketPainter(dc)),
  );
}

class _SocketPainter extends CustomPainter {
  const _SocketPainter(this.dc);
  final bool dc;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 120, size.height / 120);
    final body = RRect.fromRectAndRadius(
      const Rect.fromLTWH(10, 8, 100, 104),
      const Radius.circular(9),
    );
    canvas.drawShadow(Path()..addRRect(body), Colors.black, 4, true);
    canvas.drawRRect(
      body,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFFF6F5ED), Color(0xFFB1B5B2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(body.outerRect),
    );
    canvas.drawRRect(
      body,
      Paint()
        ..color = const Color(0xFF747A78)
        ..style = PaintingStyle.stroke,
    );
    if (dc) {
      final slot = RRect.fromRectAndRadius(
        const Rect.fromLTWH(34, 72, 52, 30),
        const Radius.circular(4),
      );
      canvas.drawRRect(slot, Paint()..color = const Color(0xFF4C5350));
      canvas.drawRect(
        const Rect.fromLTWH(56, 72, 8, 5),
        Paint()..color = const Color(0xFFE0E3DB),
      );
    } else {
      canvas.drawCircle(
        const Offset(60, 70),
        32,
        Paint()
          ..shader = const RadialGradient(
            colors: [Color(0xFFBDC1BC), Color(0xFF737976), Color(0xFFE3E4DC)],
            stops: [0, .82, 1],
          ).createShader(const Rect.fromLTWH(28, 38, 64, 64)),
      );
    }
    final outputs = dc
        ? const [Offset(45.6, 90), Offset(74.4, 90)]
        : const [Offset(38.4, 78), Offset(81.6, 78), Offset(60, 54)];
    final labels = dc ? const ['+', '−'] : const ['L', 'N', 'PE'];
    for (var i = 0; i < labels.length; i++) {
      final x = dc ? 45.6 + i * 28.8 : 31.2 + i * 28.8;
      canvas.drawCircle(
        Offset(x, 12),
        4,
        Paint()..color = const Color(0xFF4E5452),
      );
      canvas.drawCircle(
        outputs[i],
        i == 2 ? 3 : 5,
        Paint()
          ..color = i == 2 ? const Color(0xFFB8BFBD) : const Color(0xFF252B29),
      );
      final tp = TextPainter(
        text: TextSpan(
          text: labels[i],
          style: const TextStyle(fontSize: 9, color: Color(0xFF303834)),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x - tp.width / 2, 19));
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_SocketPainter old) => old.dc != dc;
}
