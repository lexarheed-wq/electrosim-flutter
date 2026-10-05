import 'dart:math' as math;

import 'package:flutter/material.dart';

enum F17ThreePhaseDevice {
  motor6t,
  wyeLoad,
  deltaLoad,
}

@immutable
final class F17ThreePhaseState {
  const F17ThreePhaseState({
    this.energized = false,
    this.currentA = 0,
    this.voltageV = 0,
    this.animationValue = 0,
  });

  final bool energized;
  final double currentA;
  final double voltageV;
  final double animationValue;
}

abstract final class F17ThreePhaseGeometry {
  static Size boardSizeFor(F17ThreePhaseDevice device) => switch (device) {
        F17ThreePhaseDevice.motor6t => const Size(260, 240),
        F17ThreePhaseDevice.wyeLoad => const Size(210, 200),
        F17ThreePhaseDevice.deltaLoad => const Size(210, 200),
      };
}

class F17ThreePhaseComponentView extends StatelessWidget {
  const F17ThreePhaseComponentView({
    super.key,
    required this.device,
    required this.size,
    this.state = const F17ThreePhaseState(),
  });

  final F17ThreePhaseDevice device;
  final Size size;
  final F17ThreePhaseState state;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size.width,
        height: size.height,
        child: CustomPaint(
          painter: _F17ThreePhasePainter(device: device, state: state),
        ),
      );
}

final class _F17ThreePhasePainter extends CustomPainter {
  const _F17ThreePhasePainter({
    required this.device,
    required this.state,
  });

  final F17ThreePhaseDevice device;
  final F17ThreePhaseState state;

  @override
  void paint(Canvas canvas, Size size) {
    final _P p = _P(canvas, Offset.zero & size, state);
    switch (device) {
      case F17ThreePhaseDevice.motor6t:
        p.motor6t();
        return;
      case F17ThreePhaseDevice.wyeLoad:
        p.wyeLoad();
        return;
      case F17ThreePhaseDevice.deltaLoad:
        p.deltaLoad();
        return;
    }
  }

  @override
  bool shouldRepaint(_F17ThreePhasePainter oldDelegate) =>
      oldDelegate.device != device ||
      oldDelegate.state.energized != state.energized ||
      oldDelegate.state.currentA != state.currentA ||
      oldDelegate.state.voltageV != state.voltageV ||
      oldDelegate.state.animationValue != state.animationValue;
}

final class _P {
  _P(this.canvas, this.rect, this.state);

  final Canvas canvas;
  final Rect rect;
  final F17ThreePhaseState state;

  Offset get c => rect.center;
  double get w => rect.width;
  double get h => rect.height;
  double get s => rect.shortestSide;

  Paint get outline => Paint()
    ..color = const Color(0xFF2D3A42)
    ..strokeWidth = math.max(1.2, s * .016)
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  Paint grad(Rect target, List<Color> colors) => Paint()
    ..shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: colors,
    ).createShader(target);

  void text(String value, Offset center,
      {double? size, Color color = const Color(0xFF24343B)}) {
    final TextPainter tp = TextPainter(
      text: TextSpan(
        text: value,
        style: TextStyle(
          fontSize: size ?? math.max(7, h * .055),
          fontWeight: FontWeight.w700,
          color: color,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(
      canvas,
      Offset(center.dx - tp.width / 2, center.dy - tp.height / 2),
    );
  }

  void terminal(Offset p, String label, Color phaseColor) {
    final double r = math.max(4, s * .030);
    canvas.drawCircle(
      p.translate(0, r * .18),
      r * 1.1,
      Paint()..color = const Color(0x22000000),
    );
    canvas.drawCircle(
      p,
      r,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-.35, -.35),
          colors: <Color>[
            Color.lerp(phaseColor, Colors.white, .45)!,
            phaseColor,
            Color.lerp(phaseColor, Colors.black, .32)!,
          ],
        ).createShader(Rect.fromCircle(center: p, radius: r)),
    );
    canvas.drawCircle(p, r, outline);
    canvas.drawLine(
      Offset(p.dx - r * .48, p.dy),
      Offset(p.dx + r * .48, p.dy),
      Paint()
        ..color = const Color(0xFF35434B)
        ..strokeWidth = math.max(.8, r * .18),
    );
    text(
      label,
      p.translate(0, p.dy < c.dy ? r + 8 : -(r + 8)),
      size: math.max(6, s * .043),
    );
  }

  Color phase(int index) => switch (index) {
        0 => const Color(0xFF8B5A2B),
        1 => const Color(0xFF242A30),
        _ => const Color(0xFF777F86),
      };

  void motor6t() {
    final Rect shell = Rect.fromCenter(
      center: Offset(c.dx, c.dy - h * .01),
      width: w * .60,
      height: h * .54,
    );
    final RRect rr =
        RRect.fromRectAndRadius(shell, Radius.circular(h * .17));
    canvas.drawRRect(
      rr.shift(Offset(0, h * .018)),
      Paint()..color = const Color(0x26000000),
    );
    canvas.drawRRect(
      rr,
      grad(
        shell,
        const <Color>[
          Color(0xFFE7ECEF),
          Color(0xFF9AA8B0),
          Color(0xFF687780),
        ],
      ),
    );
    canvas.drawRRect(rr, outline);

    for (var i = 0; i < 8; i++) {
      final double x = shell.left + shell.width * (.11 + i * .11);
      canvas.drawLine(
        Offset(x, shell.top + h * .045),
        Offset(x, shell.bottom - h * .045),
        Paint()
          ..color = const Color(0xFF718088)
          ..strokeWidth = math.max(.8, s * .009),
      );
    }

    final Offset rotor = shell.center;
    canvas.drawCircle(
      rotor,
      h * .125,
      Paint()..color = const Color(0xFF354149),
    );
    final double angle = state.energized
        ? state.animationValue * math.pi * 2 * 2.3
        : 0;
    canvas.save();
    canvas.translate(rotor.dx, rotor.dy);
    canvas.rotate(angle);
    for (var i = 0; i < 4; i++) {
      canvas.rotate(math.pi / 2);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(h * .02, -h * .018, h * .09, h * .036),
          Radius.circular(h * .01),
        ),
        Paint()
          ..color = state.energized
              ? const Color(0xFFD6A24E)
              : const Color(0xFF849198),
      );
    }
    canvas.restore();
    canvas.drawCircle(
      rotor,
      h * .035,
      Paint()..color = const Color(0xFFD5DEE3),
    );

    final List<double> xs = <double>[
      c.dx - w * .20,
      c.dx,
      c.dx + w * .20,
    ];
    const List<String> upper = <String>['U1', 'V1', 'W1'];
    const List<String> lower = <String>['U2', 'V2', 'W2'];
    for (var i = 0; i < 3; i++) {
      terminal(Offset(xs[i], rect.top + h * .08), upper[i], phase(i));
      terminal(Offset(xs[i], rect.bottom - h * .08), lower[i], phase(i));
    }

    final Rect plate = Rect.fromCenter(
      center: Offset(c.dx, shell.bottom - h * .06),
      width: shell.width * .34,
      height: h * .08,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(plate, Radius.circular(h * .012)),
      Paint()..color = const Color(0xFFE8EDEE),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(plate, Radius.circular(h * .012)),
      outline,
    );
    text(
      state.energized
          ? 'M 3~  ${state.currentA.toStringAsFixed(1)} A'
          : 'M 3~',
      plate.center,
      size: h * .043,
    );
  }

  void wyeLoad() {
    final Rect body = Rect.fromCenter(
      center: c,
      width: w * .66,
      height: h * .62,
    );
    final RRect rr =
        RRect.fromRectAndRadius(body, Radius.circular(h * .04));
    canvas.drawRRect(
      rr,
      grad(body, const <Color>[Color(0xFFF3F5F6), Color(0xFFBCC5CA)]),
    );
    canvas.drawRRect(rr, outline);

    final Offset star = Offset(c.dx, c.dy + h * .07);
    final List<Offset> nodes = <Offset>[
      Offset(c.dx - w * .20, c.dy - h * .14),
      Offset(c.dx, c.dy - h * .19),
      Offset(c.dx + w * .20, c.dy - h * .14),
    ];
    for (var i = 0; i < 3; i++) {
      canvas.drawLine(
        nodes[i],
        star,
        Paint()
          ..color = state.energized ? phase(i) : const Color(0xFF5B6870)
          ..strokeWidth = math.max(3, s * .024)
          ..strokeCap = StrokeCap.round,
      );
      terminal(Offset(nodes[i].dx, rect.top + h * .08),
          <String>['L1', 'L2', 'L3'][i], phase(i));
      canvas.drawLine(
        Offset(nodes[i].dx, rect.top + h * .11),
        nodes[i],
        outline,
      );
    }
    terminal(
      Offset(c.dx, rect.bottom - h * .08),
      'N',
      const Color(0xFF2563EB),
    );
    canvas.drawLine(
      star,
      Offset(c.dx, rect.bottom - h * .11),
      outline,
    );
    canvas.drawCircle(star, s * .025, Paint()..color = const Color(0xFF34434B));
    text('Y', Offset(c.dx, body.top + h * .08), size: h * .12);
  }

  void deltaLoad() {
    final Rect body = Rect.fromCenter(
      center: c,
      width: w * .66,
      height: h * .62,
    );
    final RRect rr =
        RRect.fromRectAndRadius(body, Radius.circular(h * .04));
    canvas.drawRRect(
      rr,
      grad(body, const <Color>[Color(0xFFF3F5F6), Color(0xFFBCC5CA)]),
    );
    canvas.drawRRect(rr, outline);

    final List<Offset> nodes = <Offset>[
      Offset(c.dx, c.dy - h * .19),
      Offset(c.dx - w * .22, c.dy + h * .16),
      Offset(c.dx + w * .22, c.dy + h * .16),
    ];
    final Path triangle = Path()
      ..moveTo(nodes[0].dx, nodes[0].dy)
      ..lineTo(nodes[1].dx, nodes[1].dy)
      ..lineTo(nodes[2].dx, nodes[2].dy)
      ..close();
    canvas.drawPath(
      triangle,
      Paint()
        ..color = state.energized
            ? const Color(0xFFD28735)
            : const Color(0xFF56656D)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(4, s * .027)
        ..strokeJoin = StrokeJoin.round,
    );
    final List<Offset> terminals = <Offset>[
      Offset(c.dx - w * .20, rect.top + h * .08),
      Offset(c.dx, rect.top + h * .08),
      Offset(c.dx + w * .20, rect.top + h * .08),
    ];
    for (var i = 0; i < 3; i++) {
      terminal(terminals[i], <String>['L1', 'L2', 'L3'][i], phase(i));
      canvas.drawLine(
        terminals[i].translate(0, h * .035),
        nodes[i],
        outline,
      );
    }
    text('Δ', Offset(c.dx, body.bottom - h * .08), size: h * .14);
  }
}
