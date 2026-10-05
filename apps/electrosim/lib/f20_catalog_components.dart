import 'dart:math' as math;

import 'package:flutter/material.dart';

enum F20CatalogDevice {
  battery,
  generator,
  appliance2t,
  motorDriven2t,
  motorDriven6t,
  heater,
  actuator2t,
  sensor2t,
  indicator2t,
}

@immutable
final class F20CatalogState {
  const F20CatalogState({
    this.energized = false,
    this.actuated = false,
    this.currentA = 0,
    this.voltageV = 0,
    this.animationValue = 0,
    this.variantKey,
  });

  final bool energized;
  final bool actuated;
  final double currentA;
  final double voltageV;
  final double animationValue;
  final String? variantKey;
}

abstract final class F20CatalogGeometry {
  static Size boardSizeFor(F20CatalogDevice device) => switch (device) {
    F20CatalogDevice.battery => const Size(170, 160),
    F20CatalogDevice.generator => const Size(180, 180),
    F20CatalogDevice.appliance2t => const Size(180, 190),
    F20CatalogDevice.motorDriven2t => const Size(210, 180),
    F20CatalogDevice.motorDriven6t => const Size(240, 220),
    F20CatalogDevice.heater => const Size(190, 170),
    F20CatalogDevice.actuator2t => const Size(180, 180),
    F20CatalogDevice.sensor2t => const Size(150, 170),
    F20CatalogDevice.indicator2t => const Size(150, 160),
  };
}

class F20CatalogComponentView extends StatelessWidget {
  const F20CatalogComponentView({
    super.key,
    required this.device,
    required this.size,
    this.state = const F20CatalogState(),
  });

  final F20CatalogDevice device;
  final Size size;
  final F20CatalogState state;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size.width,
    height: size.height,
    child: CustomPaint(
      painter: _F20Painter(device: device, state: state),
    ),
  );
}

final class _F20Painter extends CustomPainter {
  const _F20Painter({required this.device, required this.state});

  final F20CatalogDevice device;
  final F20CatalogState state;

  @override
  void paint(Canvas canvas, Size size) {
    final _P p = _P(canvas, Offset.zero & size, state);
    switch (device) {
      case F20CatalogDevice.battery:
        p.battery();
        return;
      case F20CatalogDevice.generator:
        p.generator();
        return;
      case F20CatalogDevice.appliance2t:
        p.appliance();
        return;
      case F20CatalogDevice.motorDriven2t:
        p.motorDriven(sixTerminals: false);
        return;
      case F20CatalogDevice.motorDriven6t:
        p.motorDriven(sixTerminals: true);
        return;
      case F20CatalogDevice.heater:
        p.heater();
        return;
      case F20CatalogDevice.actuator2t:
        p.actuator();
        return;
      case F20CatalogDevice.sensor2t:
        p.sensor();
        return;
      case F20CatalogDevice.indicator2t:
        p.indicator();
        return;
    }
  }

  @override
  bool shouldRepaint(_F20Painter oldDelegate) =>
      oldDelegate.device != device ||
      oldDelegate.state.energized != state.energized ||
      oldDelegate.state.actuated != state.actuated ||
      oldDelegate.state.currentA != state.currentA ||
      oldDelegate.state.voltageV != state.voltageV ||
      oldDelegate.state.animationValue != state.animationValue ||
      oldDelegate.state.variantKey != state.variantKey;
}

final class _P {
  _P(this.canvas, this.rect, this.state);

  final Canvas canvas;
  final Rect rect;
  final F20CatalogState state;

  Offset get c => rect.center;
  double get w => rect.width;
  double get h => rect.height;
  double get s => rect.shortestSide;
  String get variant => state.variantKey ?? '';

  Paint get outline => Paint()
    ..color = const Color(0xFF293943)
    ..strokeWidth = math.max(1.2, s * .018)
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  Paint grad(Rect r, List<Color> colors) => Paint()
    ..shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: colors,
    ).createShader(r);

  void box(
    Rect body, {
    Color top = const Color(0xFFF7FAFB),
    Color bottom = const Color(0xFFC8D2D8),
  }) {
    final RRect rr = RRect.fromRectAndRadius(
      body,
      Radius.circular(math.max(5, h * .035)),
    );
    canvas.drawRRect(
      rr.shift(Offset(0, h * .018)),
      Paint()..color = const Color(0x24000000),
    );
    canvas.drawRRect(rr, grad(body, <Color>[top, bottom]));
    canvas.drawRRect(rr, outline);
  }

  void text(
    String value,
    Offset center, {
    double? size,
    Color color = const Color(0xFF273943),
  }) {
    final TextPainter tp = TextPainter(
      text: TextSpan(
        text: value,
        style: TextStyle(
          color: color,
          fontSize: size ?? math.max(7, h * .06),
          fontWeight: FontWeight.w700,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    tp.paint(
      canvas,
      Offset(center.dx - tp.width / 2, center.dy - tp.height / 2),
    );
  }

  void terminal(
    Offset p,
    String label, {
    Color color = const Color(0xFFC99A3A),
  }) {
    final double r = math.max(3.5, s * .033);
    canvas.drawCircle(p, r, Paint()..color = color);
    canvas.drawCircle(p, r, outline);
    canvas.drawLine(
      Offset(p.dx - r * .5, p.dy),
      Offset(p.dx + r * .5, p.dy),
      Paint()
        ..color = const Color(0xFF59451F)
        ..strokeWidth = math.max(.8, r * .18),
    );
    text(label, p.translate(0, -r - 8), size: math.max(6, s * .045));
  }

  List<Offset> bottomPair() => <Offset>[
    Offset(c.dx - w * .17, rect.bottom - h * .08),
    Offset(c.dx + w * .17, rect.bottom - h * .08),
  ];

  String shortLabel() => switch (variant) {
    'air-conditioner' => 'CLIM',
    'freezer' => 'CONGÉL.',
    'computer' => 'PC',
    'refrigerator' => 'FRIGO',
    'refrigerator-dc' => 'FRIGO DC',
    'television' => 'TV',
    'iron' => 'FER',
    'pump' => 'POMPE',
    'compressor' => 'COMP.',
    'conveyor' => 'CONVOY.',
    'mixer' => 'MÉLANGEUR',
    'crusher' => 'BROYEUR',
    'fan' => 'VENTIL.',
    'horn' => 'KLAXON',
    'siren' => 'SIRÈNE',
    'bell' => 'SONNERIE',
    'speaker' => 'HP',
    'solenoid' => 'SOLÉNOÏDE',
    'valve' => 'ÉLECTROV.',
    'brake' => 'FREIN',
    'electromagnet' => 'ÉLECTRO.',
    'ldr' => 'LDR',
    'ntc' => 'NTC',
    'ptc' => 'PTC',
    'shunt' => 'SHUNT',
    'rheostat' => 'RÉOSTAT',
    'beacon-red' => 'ROUGE',
    'beacon-green' => 'VERT',
    'neon' => 'NÉON',
    _ => variant.isEmpty ? 'APPAREIL' : variant.toUpperCase(),
  };

  void battery() {
    final Rect body = Rect.fromCenter(
      center: Offset(c.dx, c.dy - h * .03),
      width: w * .62,
      height: h * .62,
    );
    box(body, top: const Color(0xFF333D43), bottom: const Color(0xFF151C20));
    final Rect label = Rect.fromLTWH(
      body.left + body.width * .12,
      body.top + body.height * .18,
      body.width * .76,
      body.height * .42,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(label, Radius.circular(h * .025)),
      Paint()..color = const Color(0xFFF0C84B),
    );
    text(
      variant.replaceAll('battery-', '').replaceAll('cell-', ''),
      label.center,
      size: h * .10,
      color: const Color(0xFF1A242A),
    );
    final List<Offset> t = bottomPair();
    terminal(t[0], '+', color: const Color(0xFFE35050));
    terminal(t[1], '−', color: const Color(0xFF171D21));
  }

  void generator() {
    final double r = h * .29;
    final Offset center = Offset(c.dx, c.dy - h * .035);
    canvas.drawCircle(
      center.translate(0, h * .02),
      r * 1.06,
      Paint()..color = const Color(0x25000000),
    );
    canvas.drawCircle(
      center,
      r,
      grad(Rect.fromCircle(center: center, radius: r), const <Color>[
        Color(0xFFE7ECEF),
        Color(0xFF7B8992),
      ]),
    );
    canvas.drawCircle(center, r, outline);
    text(variant.contains('ac') ? 'G~' : 'G⎓', center, size: h * .15);
    final List<Offset> t = bottomPair();
    terminal(t[0], variant.contains('ac') ? 'L' : '+');
    terminal(t[1], variant.contains('ac') ? 'N' : '−');
  }

  void appliance() {
    final Rect body = Rect.fromCenter(
      center: Offset(c.dx, c.dy - h * .03),
      width: w * .66,
      height: h * .67,
    );
    final Color top = state.energized
        ? const Color(0xFFF3F7F8)
        : const Color(0xFFE3E8EA);
    box(body, top: top, bottom: const Color(0xFFB3BFC6));
    final Rect face = Rect.fromLTWH(
      body.left + body.width * .12,
      body.top + body.height * .13,
      body.width * .76,
      body.height * .48,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(face, Radius.circular(h * .035)),
      Paint()..color = const Color(0xFF33434C),
    );
    text(shortLabel(), face.center, size: h * .075, color: Colors.white);
    canvas.drawCircle(
      Offset(body.right - body.width * .16, body.bottom - body.height * .15),
      h * .022,
      Paint()
        ..color = state.energized
            ? const Color(0xFF4DCE73)
            : const Color(0xFF78858C),
    );
    final List<Offset> t = bottomPair();
    terminal(t[0], '1');
    terminal(t[1], '2');
  }

  void motorDriven({required bool sixTerminals}) {
    final Rect body = Rect.fromCenter(
      center: Offset(c.dx - w * .06, c.dy),
      width: w * .46,
      height: h * .48,
    );
    final RRect rr = RRect.fromRectAndRadius(body, Radius.circular(h * .12));
    canvas.drawRRect(
      rr,
      grad(body, const <Color>[Color(0xFFE4EAED), Color(0xFF77868F)]),
    );
    canvas.drawRRect(rr, outline);

    final Offset shaft = Offset(body.right + w * .12, c.dy);
    canvas.drawLine(
      Offset(body.right, c.dy),
      shaft,
      Paint()
        ..color = const Color(0xFF87939A)
        ..strokeWidth = math.max(4, s * .045)
        ..strokeCap = StrokeCap.round,
    );

    final double rotorR = h * .075;
    canvas.save();
    canvas.translate(shaft.dx, shaft.dy);
    canvas.rotate(
      state.energized ? state.animationValue * math.pi * 2 * 2.2 : 0,
    );
    for (var i = 0; i < 4; i++) {
      canvas.rotate(math.pi / 2);
      canvas.drawLine(
        Offset.zero,
        Offset(rotorR, 0),
        Paint()
          ..color = const Color(0xFF465660)
          ..strokeWidth = math.max(2, s * .018),
      );
    }
    canvas.restore();

    text(shortLabel(), body.center, size: h * .06);
    if (sixTerminals) {
      final List<double> xs = <double>[c.dx - w * .20, c.dx, c.dx + w * .20];
      for (var i = 0; i < 3; i++) {
        terminal(
          Offset(xs[i], rect.top + h * .08),
          <String>['U1', 'V1', 'W1'][i],
        );
        terminal(
          Offset(xs[i], rect.bottom - h * .08),
          <String>['U2', 'V2', 'W2'][i],
        );
      }
    } else {
      final List<Offset> t = bottomPair();
      terminal(t[0], '1');
      terminal(t[1], '2');
    }
  }

  void heater() {
    final Rect body = Rect.fromCenter(
      center: c,
      width: w * .66,
      height: h * .52,
    );
    box(body, top: const Color(0xFFF4E6D8), bottom: const Color(0xFFBE9B7D));
    final Path coil = Path();
    for (var i = 0; i <= 40; i++) {
      final double t = i / 40;
      final Offset p = Offset(
        body.left + body.width * (.12 + .76 * t),
        c.dy + math.sin(t * math.pi * 8) * h * .10,
      );
      if (i == 0) {
        coil.moveTo(p.dx, p.dy);
      } else {
        coil.lineTo(p.dx, p.dy);
      }
    }
    canvas.drawPath(
      coil,
      Paint()
        ..color = state.energized
            ? const Color(0xFFEF5E34)
            : const Color(0xFF6E5748)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(2.2, s * .022),
    );
    text(shortLabel(), Offset(c.dx, body.top + h * .07), size: h * .055);
    final List<Offset> t = bottomPair();
    terminal(t[0], '1');
    terminal(t[1], '2');
  }

  void actuator() {
    final Rect coil = Rect.fromCenter(
      center: Offset(c.dx - w * .08, c.dy),
      width: w * .45,
      height: h * .42,
    );
    box(coil, top: const Color(0xFFB06C3C), bottom: const Color(0xFF5B3523));
    for (var i = 0; i < 6; i++) {
      final double x = coil.left + coil.width * (.14 + i * .13);
      canvas.drawLine(
        Offset(x, coil.top + coil.height * .14),
        Offset(x, coil.bottom - coil.height * .14),
        Paint()
          ..color = const Color(0xFFF0A45E)
          ..strokeWidth = math.max(1, s * .012),
      );
    }
    final double shift = state.energized || state.actuated ? w * .05 : 0;
    final Rect plunger = Rect.fromLTWH(
      coil.right - w * .01 + shift,
      c.dy - h * .055,
      w * .20,
      h * .11,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(plunger, Radius.circular(h * .025)),
      Paint()..color = const Color(0xFF9DA9AF),
    );
    text(shortLabel(), Offset(c.dx, coil.top - h * .065), size: h * .055);
    final List<Offset> t = bottomPair();
    terminal(t[0], 'A1');
    terminal(t[1], 'A2');
  }

  void sensor() {
    final Rect body = Rect.fromCenter(
      center: c,
      width: w * .56,
      height: h * .55,
    );
    box(body, top: const Color(0xFFE9F0F3), bottom: const Color(0xFF9EB0B9));
    final double r = h * .13;
    canvas.drawCircle(
      Offset(c.dx, c.dy - h * .035),
      r,
      Paint()..color = const Color(0xFF32464F),
    );
    if (variant == 'ldr') {
      for (var i = 0; i < 4; i++) {
        final double y = c.dy - h * .08 + i * h * .035;
        canvas.drawLine(
          Offset(c.dx - r * .55, y),
          Offset(c.dx + r * .55, y),
          Paint()
            ..color = const Color(0xFFE8C64F)
            ..strokeWidth = math.max(1.1, s * .012),
        );
      }
    } else {
      text(
        shortLabel(),
        Offset(c.dx, c.dy - h * .035),
        size: h * .075,
        color: Colors.white,
      );
    }
    final List<Offset> t = bottomPair();
    terminal(t[0], '1');
    terminal(t[1], '2');
  }

  void indicator() {
    final double r = h * .23;
    final Offset lens = Offset(c.dx, c.dy - h * .04);
    final Color color = variant.contains('green')
        ? const Color(0xFF41C96B)
        : variant.contains('red')
        ? const Color(0xFFE54A4A)
        : const Color(0xFFE1C24A);
    if (state.energized) {
      canvas.drawCircle(
        lens,
        r * 1.35,
        Paint()
          ..color = color.withValues(alpha: .20)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
      );
    }
    canvas.drawCircle(
      lens,
      r,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-.35, -.35),
          colors: <Color>[
            Color.lerp(color, Colors.white, .5)!,
            color,
            Color.lerp(color, Colors.black, .3)!,
          ],
        ).createShader(Rect.fromCircle(center: lens, radius: r)),
    );
    canvas.drawCircle(lens, r, outline);
    text(shortLabel(), Offset(c.dx, lens.dy + r + h * .07), size: h * .05);
    final List<Offset> t = bottomPair();
    terminal(t[0], '1');
    terminal(t[1], '2');
  }
}
