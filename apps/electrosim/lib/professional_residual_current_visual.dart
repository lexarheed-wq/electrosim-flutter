import 'package:flutter/material.dart';

/// Front-view artwork only. This widget does not evaluate residual currents,
/// trip a circuit or register a simulation model. Bind a qualified electrical
/// model before adding a differential device to a functioning circuit palette.
class ResidualCurrentVisual extends StatelessWidget {
  const ResidualCurrentVisual({
    super.key,
    this.size = const Size(108, 180),
    this.poles = 2,
    this.closed = true,
    this.tripped = false,
    this.ratedCurrentA = 40,
    this.residualCurrentMa = 30,
  }) : assert(poles == 2 || poles == 4),
       assert(ratedCurrentA > 0),
       assert(residualCurrentMa > 0);

  final Size size;
  final int poles;
  final bool closed;
  final bool tripped;
  final double ratedCurrentA;
  final double residualCurrentMa;

  /// Offsets from the housing centre, ordered top row then bottom row.
  static List<Offset> terminalOffsets(Size size, {required int poles}) => [
    for (final y in [-.42, .42])
      for (var i = 0; i < poles; i++)
        Offset(size.width * .72 * ((i + .5) / poles - .5), size.height * y),
  ];

  @override
  Widget build(BuildContext context) => Semantics(
    label:
        'Différentiel $poles pôles, rendu visuel, modèle électrique non intégré',
    child: SizedBox.fromSize(
      size: size,
      child: CustomPaint(painter: _ResidualCurrentPainter(this)),
    ),
  );
}

class _ResidualCurrentPainter extends CustomPainter {
  const _ResidualCurrentPainter(this.device);
  final ResidualCurrentVisual device;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final body = Rect.fromLTWH(w * .04, h * .025, w * .92, h * .95);
    final shape = RRect.fromRectAndRadius(body, Radius.circular(h * .025));
    canvas.drawRRect(
      shape.shift(Offset(0, h * .012)),
      Paint()..color = const Color(0x35000000),
    );
    canvas.drawRRect(
      shape,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFDFDF8), Color(0xFFE2E4DD), Color(0xFFBFC5BE)],
        ).createShader(body),
    );
    canvas.drawRRect(
      shape,
      Paint()
        ..color = const Color(0xFF7D8982)
        ..style = PaintingStyle.stroke
        ..strokeWidth = .8,
    );
    final face = Rect.fromLTWH(w * .11, h * .23, w * .78, h * .48);
    canvas.drawRRect(
      RRect.fromRectAndRadius(face, const Radius.circular(2)),
      Paint()..color = const Color(0xFFEFF1E9),
    );
    canvas.drawRect(
      Rect.fromLTWH(face.left, face.top, face.width, h * .025),
      Paint()..color = const Color(0xFF496875),
    );
    void text(String value, Offset centre, double fontSize) {
      final p = TextPainter(
        text: TextSpan(
          text: value,
          style: TextStyle(
            fontFamily: 'Roboto',
            color: const Color(0xFF34443B),
            fontSize: fontSize,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      p.paint(canvas, centre - Offset(p.width / 2, p.height / 2));
    }

    text('DIFFÉRENTIEL', Offset(w * .5, h * .30), h * .044);
    text(
      '${device.ratedCurrentA.toStringAsFixed(0)} A',
      Offset(w * .29, h * .38),
      h * .055,
    );
    text(
      'IΔn ${device.residualCurrentMa.toStringAsFixed(0)} mA',
      Offset(w * .5, h * .76),
      h * .045,
    );
    // Physical test button is artwork, not a fake functional control.
    final testButton = Rect.fromCenter(
      center: Offset(w * .28, h * .52),
      width: w * .23,
      height: h * .10,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(testButton, const Radius.circular(3)),
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFFEAF0E6), Color(0xFF8C9B8B)],
        ).createShader(testButton),
    );
    text('T', testButton.center, h * .065);
    final slot = Rect.fromLTWH(w * .56, h * .37, w * .24, h * .27);
    canvas.drawRRect(
      RRect.fromRectAndRadius(slot, const Radius.circular(3)),
      Paint()..color = const Color(0xFF202B32),
    );
    final handle = Rect.fromCenter(
      center: Offset(
        slot.center.dx,
        device.tripped
            ? slot.center.dy
            : device.closed
            ? slot.top + h * .07
            : slot.bottom - h * .07,
      ),
      width: slot.width * .86,
      height: h * .095,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(handle, const Radius.circular(2)),
      Paint()
        ..shader = LinearGradient(
          colors: device.tripped
              ? const [Color(0xFFEAB265), Color(0xFF8C581D)]
              : const [Color(0xFF647078), Color(0xFF192731)],
        ).createShader(handle),
    );
    final terminals = ResidualCurrentVisual.terminalOffsets(
      size,
      poles: device.poles,
    );
    for (var i = 0; i < terminals.length; i++) {
      final relative = terminals[i];
      final centre = size.center(Offset.zero) + relative;
      final recess = Rect.fromCenter(
        center: centre,
        width: w * .65 / device.poles,
        height: h * .07,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(recess, const Radius.circular(2)),
        Paint()..color = const Color(0xFF49565B),
      );
      final radius = (w / device.poles * .12).clamp(3.0, 6.0).toDouble();
      canvas.drawCircle(
        centre,
        radius,
        Paint()
          ..shader = const RadialGradient(
            center: Alignment(-.4, -.4),
            colors: [Color(0xFFF4F7F7), Color(0xFF89989F), Color(0xFF45545D)],
          ).createShader(Rect.fromCircle(center: centre, radius: radius)),
      );
      final screw = Paint()
        ..color = const Color(0xFF273740)
        ..strokeWidth = 1;
      canvas.drawLine(
        centre + Offset(-radius * .6, 0),
        centre + Offset(radius * .6, 0),
        screw,
      );
      canvas.drawLine(
        centre + Offset(0, -radius * .6),
        centre + Offset(0, radius * .6),
        screw,
      );
      final pole = i % device.poles;
      final label = pole == device.poles - 1
          ? 'N'
          : '${pole * 2 + (i < device.poles ? 1 : 2)}';
      text(
        label,
        centre.translate(0, i < device.poles ? h * .075 : -h * .075),
        h * .039,
      );
    }
  }

  @override
  bool shouldRepaint(_ResidualCurrentPainter old) =>
      old.device.poles != device.poles ||
      old.device.closed != device.closed ||
      old.device.tripped != device.tripped ||
      old.device.ratedCurrentA != device.ratedCurrentA ||
      old.device.residualCurrentMa != device.residualCurrentMa;
}
