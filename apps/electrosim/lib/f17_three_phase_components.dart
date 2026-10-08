import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:electrosim_canvas/electrosim_canvas.dart';

enum F17ThreePhaseDevice { motor6t, wyeLoad, deltaLoad }

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
  const _F17ThreePhasePainter({required this.device, required this.state});

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
    ..color = const Color(0xFF365463)
    ..strokeWidth = math.max(.8, s * .006)
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  Paint grad(Rect target, List<Color> colors) => Paint()
    ..shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: colors,
    ).createShader(target);

  void text(
    String value,
    Offset center, {
    double? size,
    Color color = const Color(0xFF24343B),
  }) {
    final TextPainter tp = TextPainter(
      text: TextSpan(
        text: value,
        style: TextStyle(
          fontFamily: 'Roboto',
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
    final shell = Rect.fromLTWH(
      rect.left + w * .17,
      rect.top + h * .37,
      w * .65,
      h * .43,
    );
    final body = RRect.fromRectAndRadius(shell, Radius.circular(h * .10));
    canvas.drawRRect(
      body.shift(Offset(0, h * .018)),
      Paint()..color = const Color(0x35000000),
    );
    // Cast mounting feet and their fixing holes.
    for (final x in [shell.left + w * .08, shell.right - w * .14]) {
      final foot = Rect.fromLTWH(x, shell.bottom - h * .03, w * .14, h * .10);
      canvas.drawRRect(
        RRect.fromRectAndRadius(foot, Radius.circular(h * .016)),
        grad(foot, const [Color(0xFF2C79AC), Color(0xFF0B3353)]),
      );
      canvas.drawOval(
        Rect.fromCenter(
          center: foot.center.translate(0, h * .025),
          width: w * .045,
          height: h * .018,
        ),
        Paint()..color = const Color(0xFF142C3F),
      );
    }
    canvas.drawRRect(
      body,
      grad(shell, const [
        Color(0xFF3D91BE),
        Color(0xFF1C6698),
        Color(0xFF0C355A),
      ]),
    );
    canvas.drawRRect(body, outline);
    // Longitudinal cooling fins retain the silhouette of a horizontal motor.
    for (var i = 0; i < 7; i++) {
      final y = shell.top + shell.height * (.14 + i * .115);
      canvas.drawLine(
        Offset(shell.left + w * .10, y),
        Offset(shell.right - w * .06, y),
        Paint()
          ..color = const Color(0xFF0B3A60)
          ..strokeWidth = h * .012,
      );
      canvas.drawLine(
        Offset(shell.left + w * .10, y - h * .004),
        Offset(shell.right - w * .06, y - h * .004),
        Paint()
          ..color = const Color(0xFF5799C2)
          ..strokeWidth = h * .004,
      );
    }
    // Fan cover on the rear and bearing flange at the shaft end.
    final cover = Rect.fromCenter(
      center: Offset(shell.left + w * .03, shell.center.dy),
      width: w * .15,
      height: shell.height,
    );
    canvas.drawOval(
      cover,
      grad(cover, const [Color(0xFF4B96BF), Color(0xFF123E63)]),
    );
    canvas.drawOval(cover, outline);
    for (var i = -2; i <= 2; i++) {
      final x = cover.center.dx + i * w * .014;
      canvas.drawLine(
        Offset(x, cover.top + h * .10),
        Offset(x, cover.bottom - h * .10),
        Paint()
          ..color = const Color(0xFF153C59)
          ..strokeWidth = w * .008,
      );
    }
    final flange = Rect.fromCenter(
      center: Offset(shell.right, shell.center.dy),
      width: w * .09,
      height: shell.height * .9,
    );
    canvas.drawOval(
      flange,
      grad(flange, const [Color(0xFF5899BE), Color(0xFF0E385A)]),
    );
    canvas.drawOval(flange, outline);
    final shaft = Rect.fromLTWH(
      shell.right + w * .015,
      shell.center.dy - h * .04,
      w * .105,
      h * .08,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(shaft, Radius.circular(h * .01)),
      grad(shaft, const [
        Color(0xFFEEEEEA),
        Color(0xFF8B969C),
        Color(0xFFD9E0E3),
      ]),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(shaft, Radius.circular(h * .01)),
      outline,
    );
    if (state.energized) {
      final y =
          shaft.center.dy +
          math.sin(state.animationValue * math.pi * 2) * shaft.height * .3;
      canvas.drawLine(
        Offset(shaft.left + 2, y),
        Offset(shaft.right - 2, y),
        Paint()
          ..color = const Color(0xFF5C6870)
          ..strokeWidth = 1,
      );
    }
    // Open terminal box, shared exactly with interactive canvas anchors.
    final box = Rect.fromLTWH(
      rect.left + w * .22,
      rect.top + h * .055,
      w * .56,
      h * .32,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        box.shift(Offset(0, h * .015)),
        Radius.circular(h * .018),
      ),
      Paint()..color = const Color(0x35000000),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(box, Radius.circular(h * .018)),
      grad(box, const [Color(0xFF477F9F), Color(0xFF163F5B)]),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(box, Radius.circular(h * .018)),
      outline,
    );
    const labels = ['U1', 'V1', 'W1', 'U2', 'V2', 'W2'];
    final terminals = SixTerminalMotorGeometry.offsets(rect.size);
    for (var i = 0; i < terminals.length; i++) {
      terminal(c + terminals[i], labels[i], const Color(0xFFB69A5C));
    }
    final plate = Rect.fromLTWH(
      shell.left + w * .16,
      shell.top + h * .055,
      w * .26,
      h * .065,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(plate, Radius.circular(2)),
      Paint()..color = const Color(0xFFDFE7E8),
    );
    text('M 3~', plate.center, size: h * .04);
  }

  void wyeLoad() {
    final Rect body = Rect.fromCenter(
      center: c,
      width: w * .66,
      height: h * .62,
    );
    final RRect rr = RRect.fromRectAndRadius(body, Radius.circular(h * .04));
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
      terminal(
        Offset(nodes[i].dx, rect.top + h * .08),
        <String>['L1', 'L2', 'L3'][i],
        phase(i),
      );
      canvas.drawLine(
        Offset(nodes[i].dx, rect.top + h * .11),
        nodes[i],
        outline,
      );
    }
    terminal(Offset(c.dx, rect.bottom - h * .08), 'N', const Color(0xFF2563EB));
    canvas.drawLine(star, Offset(c.dx, rect.bottom - h * .11), outline);
    canvas.drawCircle(star, s * .025, Paint()..color = const Color(0xFF34434B));
    text('Y', Offset(c.dx, body.top + h * .08), size: h * .12);
  }

  void deltaLoad() {
    final Rect body = Rect.fromCenter(
      center: c,
      width: w * .66,
      height: h * .62,
    );
    final RRect rr = RRect.fromRectAndRadius(body, Radius.circular(h * .04));
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
      canvas.drawLine(terminals[i].translate(0, h * .035), nodes[i], outline);
    }
    text('Δ', Offset(c.dx, body.bottom - h * .08), size: h * .14);
  }
}
