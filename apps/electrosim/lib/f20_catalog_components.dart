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

enum F20ApplianceSilhouette {
  airConditioner,
  freezer,
  computer,
  refrigerator,
  refrigeratorDc,
  television,
  generic,
}

abstract final class F20CatalogVisualIdentity {
  static F20ApplianceSilhouette applianceSilhouette(String? variantKey) =>
      switch (variantKey) {
        'air-conditioner' => F20ApplianceSilhouette.airConditioner,
        'freezer' => F20ApplianceSilhouette.freezer,
        'computer' => F20ApplianceSilhouette.computer,
        'refrigerator' => F20ApplianceSilhouette.refrigerator,
        'refrigerator-dc' => F20ApplianceSilhouette.refrigeratorDc,
        'television' => F20ApplianceSilhouette.television,
        _ => F20ApplianceSilhouette.generic,
      };
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
    switch (F20CatalogVisualIdentity.applianceSilhouette(variant)) {
      case F20ApplianceSilhouette.airConditioner:
        _airConditioner();
      case F20ApplianceSilhouette.freezer:
        _freezer();
      case F20ApplianceSilhouette.computer:
        _computer();
      case F20ApplianceSilhouette.refrigerator:
        _refrigerator(dc: false);
      case F20ApplianceSilhouette.refrigeratorDc:
        _refrigerator(dc: true);
      case F20ApplianceSilhouette.television:
        _television();
      case F20ApplianceSilhouette.generic:
        _genericAppliance();
    }
    final List<Offset> t = bottomPair();
    terminal(t[0], '1');
    terminal(t[1], '2');
  }

  void _statusLed(Offset position) {
    canvas.drawCircle(
      position,
      math.max(2.2, s * .018),
      Paint()
        ..color = state.energized
            ? const Color(0xFF43B96B)
            : const Color(0xFF7B878D),
    );
  }

  void _airConditioner() {
    final Rect body = Rect.fromCenter(
      center: Offset(c.dx, c.dy - h * .08),
      width: w * .78,
      height: h * .34,
    );
    box(body, top: const Color(0xFFF7FAFB), bottom: const Color(0xFFC9D4D9));
    final Rect outlet = Rect.fromLTWH(
      body.left + body.width * .08,
      body.bottom - body.height * .25,
      body.width * .84,
      body.height * .13,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(outlet, Radius.circular(h * .012)),
      Paint()..color = const Color(0xFF42535C),
    );
    for (var i = 0; i < 8; i++) {
      final double x = outlet.left + outlet.width * (i + .5) / 8;
      canvas.drawLine(
        Offset(x, outlet.top + 2),
        Offset(x, outlet.bottom - 2),
        Paint()
          ..color = const Color(0xFF9FB0B8)
          ..strokeWidth = 1,
      );
    }
    canvas.drawLine(
      Offset(body.left + body.width * .10, body.top + body.height * .32),
      Offset(body.right - body.width * .10, body.top + body.height * .32),
      Paint()
        ..color = const Color(0xFFB2C0C6)
        ..strokeWidth = math.max(1, s * .008),
    );
    _statusLed(Offset(body.right - body.width * .12, body.top + h * .055));
    text('CLIM', Offset(c.dx, body.top + h * .08), size: h * .055);
  }

  void _freezer() {
    final Rect body = Rect.fromCenter(
      center: Offset(c.dx, c.dy + h * .005),
      width: w * .72,
      height: h * .48,
    );
    box(body, top: const Color(0xFFF3F7F8), bottom: const Color(0xFFB9C8CF));
    final Rect lid = Rect.fromLTWH(
      body.left - w * .015,
      body.top - h * .055,
      body.width + w * .03,
      h * .11,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(lid, Radius.circular(h * .025)),
      grad(lid, const <Color>[Color(0xFFFFFFFF), Color(0xFFCAD5DA)]),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(lid, Radius.circular(h * .025)),
      outline,
    );
    final Rect handle = Rect.fromCenter(
      center: Offset(c.dx, lid.bottom + h * .018),
      width: w * .18,
      height: h * .035,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(handle, Radius.circular(h * .01)),
      Paint()..color = const Color(0xFF53636B),
    );
    _statusLed(Offset(body.right - w * .08, body.bottom - h * .07));
    text('CONGÉL.', Offset(c.dx, body.center.dy), size: h * .055);
  }

  void _computer() {
    final Rect screen = Rect.fromCenter(
      center: Offset(c.dx - w * .07, c.dy - h * .08),
      width: w * .62,
      height: h * .43,
    );
    box(screen, top: const Color(0xFF3D4C54), bottom: const Color(0xFF151C20));
    final Rect display = screen.deflate(math.max(5, s * .035));
    canvas.drawRRect(
      RRect.fromRectAndRadius(display, Radius.circular(h * .02)),
      Paint()
        ..color = state.energized
            ? const Color(0xFF7DC4DE)
            : const Color(0xFF26353C),
    );
    final Offset stemTop = Offset(screen.center.dx, screen.bottom);
    final Offset stemBottom = stemTop.translate(0, h * .13);
    canvas.drawLine(
      stemTop,
      stemBottom,
      Paint()
        ..color = const Color(0xFF65747B)
        ..strokeWidth = math.max(4, s * .025),
    );
    canvas.drawLine(
      stemBottom.translate(-w * .13, 0),
      stemBottom.translate(w * .13, 0),
      Paint()
        ..color = const Color(0xFF65747B)
        ..strokeWidth = math.max(4, s * .025)
        ..strokeCap = StrokeCap.round,
    );
    final Rect tower = Rect.fromCenter(
      center: Offset(c.dx + w * .31, c.dy + h * .01),
      width: w * .16,
      height: h * .46,
    );
    box(tower, top: const Color(0xFF505E65), bottom: const Color(0xFF252E33));
    _statusLed(Offset(tower.center.dx, tower.top + h * .055));
  }

  void _refrigerator({required bool dc}) {
    final Rect body = Rect.fromCenter(
      center: Offset(c.dx, c.dy - h * .035),
      width: w * .48,
      height: h * .68,
    );
    box(body, top: const Color(0xFFF5F8F9), bottom: const Color(0xFFB9C6CC));
    final double splitY = body.top + body.height * .38;
    canvas.drawLine(
      Offset(body.left + w * .015, splitY),
      Offset(body.right - w * .015, splitY),
      Paint()
        ..color = const Color(0xFF788990)
        ..strokeWidth = math.max(1.2, s * .012),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          body.right - w * .075,
          body.top + h * .10,
          w * .018,
          body.height * .20,
        ),
        Radius.circular(h * .008),
      ),
      Paint()..color = const Color(0xFF5C6B72),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          body.right - w * .075,
          splitY + h * .08,
          w * .018,
          body.height * .31,
        ),
        Radius.circular(h * .008),
      ),
      Paint()..color = const Color(0xFF5C6B72),
    );
    if (dc) {
      final Rect badge = Rect.fromCenter(
        center: Offset(body.center.dx, body.top + h * .075),
        width: w * .20,
        height: h * .065,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(badge, Radius.circular(h * .012)),
        Paint()..color = const Color(0xFF2E7D5A),
      );
      text('DC', badge.center, size: h * .042, color: Colors.white);
    } else {
      _statusLed(Offset(body.left + w * .07, body.top + h * .075));
    }
  }

  void _television() {
    final Rect body = Rect.fromCenter(
      center: Offset(c.dx, c.dy - h * .08),
      width: w * .78,
      height: h * .45,
    );
    box(body, top: const Color(0xFF303D44), bottom: const Color(0xFF111719));
    final Rect display = body.deflate(math.max(6, s * .04));
    canvas.drawRRect(
      RRect.fromRectAndRadius(display, Radius.circular(h * .025)),
      Paint()
        ..color = state.energized
            ? const Color(0xFF5C90A8)
            : const Color(0xFF172228),
    );
    if (state.energized) {
      canvas.drawPath(
        Path()
          ..moveTo(display.left, display.bottom)
          ..lineTo(display.right, display.top)
          ..lineTo(display.right, display.bottom)
          ..close(),
        Paint()..color = const Color(0x335BD0E6),
      );
    }
    final Offset standTop = Offset(c.dx, body.bottom);
    final Offset standBottom = standTop.translate(0, h * .10);
    canvas.drawLine(
      standTop,
      standBottom,
      Paint()
        ..color = const Color(0xFF4C5B62)
        ..strokeWidth = math.max(4, s * .022),
    );
    canvas.drawLine(
      standBottom.translate(-w * .16, 0),
      standBottom.translate(w * .16, 0),
      Paint()
        ..color = const Color(0xFF4C5B62)
        ..strokeWidth = math.max(4, s * .022)
        ..strokeCap = StrokeCap.round,
    );
    _statusLed(Offset(body.right - w * .055, body.bottom - h * .025));
  }

  void _genericAppliance() {
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
    _statusLed(Offset(body.right - body.width * .16, body.bottom - body.height * .15));
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
