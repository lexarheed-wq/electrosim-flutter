import 'dart:math' as math;

import 'package:flutter/material.dart';

const Set<String> f18IndustrialV2ModelTypes = <String>{
  'dc_voltage_source',
  'voltage_source',
  'switch',
  'switch_spst',
  'lamp',
  'resistor',
  'breaker_dc',
  'breaker_ac1',
  'breaker',
  'push_button_no',
  'push_button_nc',
  'buzzer',
  'fuse_dc',
  'fuse_ac1',
  'fuse',
  'diode',
  'fan_dc',
  'motor_dc',
  'relay_coil',
};

bool isF18IndustrialV2Model(String modelType) =>
    f18IndustrialV2ModelTypes.contains(modelType.toLowerCase());

bool paintF18IndustrialComponentV2(
  Canvas canvas,
  Rect rect,
  String modelType,
  Color foreground,
) {
  final String type = modelType.toLowerCase();
  if (!isF18IndustrialV2Model(type)) {
    return false;
  }

  final _IndustrialPainter p = _IndustrialPainter(
    canvas: canvas,
    rect: rect,
    foreground: foreground,
  );

  switch (type) {
    case 'dc_voltage_source':
    case 'voltage_source':
      p.powerSupply();
      return true;
    case 'switch':
    case 'switch_spst':
      p.rockerSwitch();
      return true;
    case 'lamp':
      p.indicatorLamp();
      return true;
    case 'resistor':
      p.axialResistor();
      return true;
    case 'breaker_dc':
    case 'breaker_ac1':
    case 'breaker':
      p.miniatureCircuitBreaker();
      return true;
    case 'push_button_no':
      p.pushButton(normallyClosed: false);
      return true;
    case 'push_button_nc':
      p.pushButton(normallyClosed: true);
      return true;
    case 'buzzer':
      p.buzzer();
      return true;
    case 'fuse_dc':
    case 'fuse_ac1':
    case 'fuse':
      p.cartridgeFuse();
      return true;
    case 'diode':
      p.axialDiode();
      return true;
    case 'fan_dc':
      p.coolingFan();
      return true;
    case 'motor_dc':
      p.dcMotor();
      return true;
    case 'relay_coil':
      p.relayCoil();
      return true;
  }
  return false;
}

final class _IndustrialPainter {
  _IndustrialPainter({
    required this.canvas,
    required this.rect,
    required this.foreground,
  });

  final Canvas canvas;
  final Rect rect;
  final Color foreground;

  Offset get c => rect.center;
  double get w => rect.width;
  double get h => rect.height;
  double get s => rect.shortestSide;

  Paint get outline => Paint()
    ..color = const Color(0xFF263746)
    ..strokeWidth = math.max(1.1, s * .025)
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  void _shadowRRect(RRect rrect, {double dy = 2.5}) {
    final RRect shifted = rrect.shift(Offset(0, dy));
    canvas.drawRRect(
      shifted,
      Paint()
        ..color = const Color(0x24000000)
        ..style = PaintingStyle.fill,
    );
  }

  Paint _verticalGradient(
    Rect target,
    List<Color> colors, {
    List<double>? stops,
  }) {
    return Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: colors,
        stops: stops,
      ).createShader(target)
      ..style = PaintingStyle.fill;
  }

  Paint _horizontalGradient(Rect target, List<Color> colors) {
    return Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: colors,
      ).createShader(target)
      ..style = PaintingStyle.fill;
  }

  void _housing(
    Rect body, {
    Color top = const Color(0xFFF9FBFC),
    Color bottom = const Color(0xFFD7E0E7),
    double radiusFactor = .08,
  }) {
    final RRect rr = RRect.fromRectAndRadius(
      body,
      Radius.circular(math.max(2.5, h * radiusFactor)),
    );
    _shadowRRect(rr, dy: math.max(1.5, h * .035));
    canvas.drawRRect(rr, _verticalGradient(body, <Color>[top, bottom]));
    canvas.drawRRect(rr, outline);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        body.deflate(math.max(.7, s * .018)),
        Radius.circular(math.max(2, h * radiusFactor * .8)),
      ),
      Paint()
        ..color = const Color(0x55FFFFFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(.8, s * .012),
    );
  }

  void _metalTerminal(Offset center, {double scale = 1}) {
    final double r = math.max(2.2, s * .055 * scale);
    canvas.drawCircle(
      center.translate(0, r * .26),
      r * 1.05,
      Paint()..color = const Color(0x26000000),
    );
    canvas.drawCircle(
      center,
      r,
      _verticalGradient(
        Rect.fromCircle(center: center, radius: r),
        const <Color>[Color(0xFFFFE29C), Color(0xFFC69136)],
      ),
    );
    canvas.drawCircle(center, r, outline);
    canvas.drawCircle(
      center,
      r * .34,
      Paint()..color = const Color(0xFF5A4321),
    );
  }

  void _lead(Offset from, Offset to, {double? width}) {
    canvas.drawLine(
      from,
      to,
      Paint()
        ..color = const Color(0xFF647582)
        ..strokeWidth = width ?? math.max(1.2, s * .025)
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      from.translate(0, -math.max(.5, s * .008)),
      to.translate(0, -math.max(.5, s * .008)),
      Paint()
        ..color = const Color(0xFFC9D3DA)
        ..strokeWidth = math.max(.6, s * .01)
        ..strokeCap = StrokeCap.round,
    );
  }

  void _screw(Offset center, {double scale = 1}) {
    final double r = math.max(1.7, s * .038 * scale);
    canvas.drawCircle(
      center,
      r,
      _verticalGradient(
        Rect.fromCircle(center: center, radius: r),
        const <Color>[Color(0xFFF3F6F7), Color(0xFF8F9BA4)],
      ),
    );
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..color = const Color(0xFF52616B)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(.7, s * .012),
    );
    canvas.drawLine(
      Offset(center.dx - r * .55, center.dy),
      Offset(center.dx + r * .55, center.dy),
      Paint()
        ..color = const Color(0xFF5A6570)
        ..strokeWidth = math.max(.7, s * .012),
    );
  }

  void _text(
    String value,
    Offset center, {
    double? size,
    Color color = const Color(0xFF243447),
    FontWeight weight = FontWeight.w700,
  }) {
    final TextPainter tp = TextPainter(
      text: TextSpan(
        text: value,
        style: TextStyle(
          color: color,
          fontSize: size ?? math.max(6, h * .12),
          fontWeight: weight,
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

  void _sideTerminals(Rect body) {
    final Offset left = Offset(rect.left + s * .07, c.dy);
    final Offset right = Offset(rect.right - s * .07, c.dy);
    _lead(left, Offset(body.left, c.dy));
    _lead(Offset(body.right, c.dy), right);
    _metalTerminal(left);
    _metalTerminal(right);
  }

  void powerSupply() {
    final Rect body = Rect.fromCenter(
      center: c,
      width: w * .78,
      height: h * .78,
    );
    _housing(
      body,
      top: const Color(0xFFEEF3F6),
      bottom: const Color(0xFFB8C4CD),
      radiusFactor: .09,
    );
    _sideTerminals(body);

    final Rect face = Rect.fromLTWH(
      body.left + body.width * .07,
      body.top + body.height * .10,
      body.width * .86,
      body.height * .70,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(face, Radius.circular(h * .055)),
      _verticalGradient(face, const <Color>[
        Color(0xFF2A3943),
        Color(0xFF101820),
      ]),
    );

    final Rect display = Rect.fromLTWH(
      face.left + face.width * .12,
      face.top + face.height * .12,
      face.width * .76,
      face.height * .34,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(display, Radius.circular(h * .035)),
      Paint()..color = const Color(0xFF061E25),
    );
    _text(
      '24.0 V',
      display.center,
      size: math.max(7, h * .15),
      color: const Color(0xFF8FF7D4),
    );

    final double postR = h * .055;
    final Offset red = Offset(
      face.left + face.width * .31,
      face.bottom - h * .12,
    );
    final Offset black = Offset(
      face.right - face.width * .31,
      face.bottom - h * .12,
    );
    canvas.drawCircle(
      red,
      postR * 1.35,
      Paint()..color = const Color(0xFF202A31),
    );
    canvas.drawCircle(red, postR, Paint()..color = const Color(0xFFE65353));
    canvas.drawCircle(
      black,
      postR * 1.35,
      Paint()..color = const Color(0xFF202A31),
    );
    canvas.drawCircle(black, postR, Paint()..color = const Color(0xFF10151A));
    _text(
      '+',
      red.translate(0, -h * .105),
      size: h * .09,
      color: const Color(0xFFF7D5D5),
    );
    _text(
      '−',
      black.translate(0, -h * .105),
      size: h * .09,
      color: Colors.white,
    );

    for (var i = 0; i < 4; i++) {
      final double x = body.left + body.width * (.18 + i * .16);
      canvas.drawLine(
        Offset(x, body.bottom - h * .045),
        Offset(x + body.width * .07, body.bottom - h * .045),
        Paint()
          ..color = const Color(0xFF788995)
          ..strokeWidth = math.max(.8, s * .013),
      );
    }
  }

  void rockerSwitch() {
    final Rect body = Rect.fromCenter(
      center: c,
      width: w * .55,
      height: h * .78,
    );
    _housing(body);
    _sideTerminals(body);

    final Rect bezel = Rect.fromCenter(
      center: c,
      width: body.width * .60,
      height: body.height * .74,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(bezel, Radius.circular(h * .11)),
      Paint()..color = const Color(0xFF1E2A33),
    );

    final Rect rocker = Rect.fromCenter(
      center: Offset(c.dx, c.dy - h * .035),
      width: bezel.width * .73,
      height: bezel.height * .72,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rocker, Radius.circular(h * .08)),
      _verticalGradient(rocker, const <Color>[
        Color(0xFF7C8B96),
        Color(0xFF34424D),
      ]),
    );
    canvas.drawLine(
      Offset(
        rocker.left + rocker.width * .25,
        rocker.top + rocker.height * .22,
      ),
      Offset(
        rocker.right - rocker.width * .25,
        rocker.top + rocker.height * .22,
      ),
      Paint()
        ..color = const Color(0x88FFFFFF)
        ..strokeWidth = math.max(.8, s * .012),
    );
    _text(
      'I',
      Offset(c.dx, rocker.top + rocker.height * .24),
      size: h * .09,
      color: Colors.white,
    );
    _text(
      'O',
      Offset(c.dx, rocker.bottom - rocker.height * .20),
      size: h * .085,
      color: const Color(0xFFD5DEE4),
    );
  }

  void indicatorLamp() {
    final double lensR = h * .27;
    final Offset lens = Offset(c.dx, c.dy - h * .04);
    _lead(
      Offset(rect.left + s * .07, c.dy),
      Offset(lens.dx - lensR * 1.08, c.dy),
    );
    _lead(
      Offset(lens.dx + lensR * 1.08, c.dy),
      Offset(rect.right - s * .07, c.dy),
    );
    _metalTerminal(Offset(rect.left + s * .07, c.dy));
    _metalTerminal(Offset(rect.right - s * .07, c.dy));

    canvas.drawCircle(
      lens.translate(0, h * .03),
      lensR * 1.18,
      Paint()..color = const Color(0x22000000),
    );
    canvas.drawCircle(
      lens,
      lensR * 1.14,
      _verticalGradient(
        Rect.fromCircle(center: lens, radius: lensR * 1.14),
        const <Color>[Color(0xFFDCE3E7), Color(0xFF8997A1)],
      ),
    );
    canvas.drawCircle(
      lens,
      lensR,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-.35, -.4),
          radius: 1.0,
          colors: const <Color>[
            Color(0xFFFFFBE0),
            Color(0xFFFFD95A),
            Color(0xFFE5A800),
          ],
        ).createShader(Rect.fromCircle(center: lens, radius: lensR)),
    );
    canvas.drawCircle(lens, lensR * 1.14, outline);
    canvas.drawArc(
      Rect.fromCircle(center: lens, radius: lensR * .72),
      -math.pi * .85,
      math.pi * .75,
      false,
      Paint()
        ..color = const Color(0xAAFFFFFF)
        ..strokeWidth = math.max(1, s * .017)
        ..style = PaintingStyle.stroke,
    );

    final Rect base = Rect.fromCenter(
      center: Offset(c.dx, rect.bottom - h * .13),
      width: w * .32,
      height: h * .12,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(base, Radius.circular(h * .025)),
      _horizontalGradient(base, const <Color>[
        Color(0xFF788690),
        Color(0xFFD9E1E5),
        Color(0xFF788690),
      ]),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(base, Radius.circular(h * .025)),
      outline,
    );
  }

  void axialResistor() {
    final Rect body = Rect.fromCenter(
      center: c,
      width: w * .48,
      height: h * .30,
    );
    _lead(
      Offset(rect.left + s * .07, c.dy),
      Offset(body.left, c.dy),
      width: s * .035,
    );
    _lead(
      Offset(body.right, c.dy),
      Offset(rect.right - s * .07, c.dy),
      width: s * .035,
    );
    _metalTerminal(Offset(rect.left + s * .07, c.dy), scale: .9);
    _metalTerminal(Offset(rect.right - s * .07, c.dy), scale: .9);

    final RRect rr = RRect.fromRectAndRadius(
      body,
      Radius.circular(body.height / 2),
    );
    _shadowRRect(rr, dy: h * .035);
    canvas.drawRRect(
      rr,
      _verticalGradient(
        body,
        const <Color>[Color(0xFFF3DFB8), Color(0xFFD1AE73), Color(0xFFE8C995)],
        stops: <double>[0, .62, 1],
      ),
    );
    canvas.drawRRect(rr, outline);

    const List<Color> bands = <Color>[
      Color(0xFF7A3E1D),
      Color(0xFF1B1B1B),
      Color(0xFFD24C3A),
      Color(0xFFC69A3A),
    ];
    for (var i = 0; i < bands.length; i++) {
      final double x = body.left + body.width * (.25 + i * .15);
      canvas.drawRect(
        Rect.fromLTWH(
          x,
          body.top + body.height * .06,
          body.width * .035,
          body.height * .88,
        ),
        Paint()..color = bands[i],
      );
    }
    canvas.drawLine(
      Offset(body.left + body.width * .12, body.top + body.height * .18),
      Offset(body.right - body.width * .12, body.top + body.height * .18),
      Paint()
        ..color = const Color(0x88FFFFFF)
        ..strokeWidth = math.max(.7, s * .012),
    );
  }

  void miniatureCircuitBreaker() {
    final Rect body = Rect.fromCenter(
      center: c,
      width: w * .58,
      height: h * .86,
    );
    _housing(
      body,
      top: const Color(0xFFFDFDFB),
      bottom: const Color(0xFFD9DEE1),
      radiusFactor: .05,
    );
    _sideTerminals(body);

    final Rect topBand = Rect.fromLTWH(
      body.left + body.width * .08,
      body.top + body.height * .08,
      body.width * .84,
      body.height * .18,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(topBand, Radius.circular(h * .022)),
      Paint()..color = const Color(0xFFE9ECEF),
    );
    _text('C10', topBand.center, size: h * .09, color: const Color(0xFF263746));

    final Rect slot = Rect.fromCenter(
      center: Offset(c.dx, c.dy + h * .015),
      width: body.width * .23,
      height: body.height * .45,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(slot, Radius.circular(h * .04)),
      Paint()..color = const Color(0xFFB9C0C5),
    );
    final Rect lever = Rect.fromCenter(
      center: Offset(c.dx, c.dy - h * .025),
      width: slot.width * .78,
      height: slot.height * .72,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(lever, Radius.circular(h * .035)),
      _verticalGradient(lever, const <Color>[
        Color(0xFF4D5A64),
        Color(0xFF1A2329),
      ]),
    );
    canvas.drawLine(
      Offset(lever.left + lever.width * .2, lever.top + lever.height * .18),
      Offset(lever.right - lever.width * .2, lever.top + lever.height * .18),
      Paint()
        ..color = const Color(0x99FFFFFF)
        ..strokeWidth = math.max(.7, s * .012),
    );

    final Offset indicator = Offset(c.dx, body.bottom - h * .12);
    canvas.drawCircle(
      indicator,
      h * .045,
      Paint()..color = const Color(0xFF2BAE66),
    );
    canvas.drawCircle(indicator, h * .045, outline);
    _screw(
      Offset(body.left + body.width * .16, body.top + body.height * .10),
      scale: .75,
    );
    _screw(
      Offset(body.right - body.width * .16, body.bottom - body.height * .10),
      scale: .75,
    );
  }

  void pushButton({required bool normallyClosed}) {
    final Rect body = Rect.fromCenter(
      center: Offset(c.dx, c.dy + h * .06),
      width: w * .54,
      height: h * .53,
    );
    _housing(
      body,
      top: const Color(0xFFE8EEF1),
      bottom: const Color(0xFFB3C0C8),
      radiusFactor: .06,
    );
    _sideTerminals(body);

    final double ringR = h * .24;
    final Offset headCenter = Offset(c.dx, c.dy - h * .07);
    canvas.drawCircle(
      headCenter.translate(0, h * .035),
      ringR * 1.15,
      Paint()..color = const Color(0x26000000),
    );
    canvas.drawCircle(
      headCenter,
      ringR * 1.18,
      _verticalGradient(
        Rect.fromCircle(center: headCenter, radius: ringR * 1.18),
        const <Color>[Color(0xFFDCE4E8), Color(0xFF6F7F8A)],
      ),
    );
    canvas.drawCircle(headCenter, ringR * 1.18, outline);

    final Color top = normallyClosed
        ? const Color(0xFFFF5A55)
        : const Color(0xFF55D67A);
    final Color bottom = normallyClosed
        ? const Color(0xFFA81E25)
        : const Color(0xFF147A3C);
    canvas.drawCircle(
      headCenter,
      ringR * .76,
      Paint()
        ..shader =
            RadialGradient(
              center: const Alignment(-.35, -.38),
              radius: 1,
              colors: <Color>[const Color(0xFFF8FFFF), top, bottom],
              stops: const <double>[0, .22, 1],
            ).createShader(
              Rect.fromCircle(center: headCenter, radius: ringR * .76),
            ),
    );
    canvas.drawCircle(headCenter, ringR * .76, outline);

    if (normallyClosed) {
      _text(
        'NC',
        Offset(c.dx, body.bottom - h * .10),
        size: h * .075,
        color: const Color(0xFF6E1C21),
      );
    } else {
      _text(
        'NO',
        Offset(c.dx, body.bottom - h * .10),
        size: h * .075,
        color: const Color(0xFF166534),
      );
    }
    _screw(
      Offset(body.left + body.width * .16, body.bottom - body.height * .14),
      scale: .65,
    );
    _screw(
      Offset(body.right - body.width * .16, body.bottom - body.height * .14),
      scale: .65,
    );
  }

  void buzzer() {
    final Rect body = Rect.fromCenter(
      center: c,
      width: w * .52,
      height: h * .58,
    );
    _sideTerminals(body);
    final double r = body.shortestSide * .48;
    final Offset center = body.center;

    canvas.drawCircle(
      center.translate(0, h * .035),
      r * 1.06,
      Paint()..color = const Color(0x26000000),
    );
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-.3, -.35),
          radius: 1,
          colors: const <Color>[
            Color(0xFF758590),
            Color(0xFF27343D),
            Color(0xFF10171C),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: r)),
    );
    canvas.drawCircle(center, r, outline);

    final double inner = r * .58;
    canvas.drawCircle(center, inner, Paint()..color = const Color(0xFF11191F));
    for (var ring = 0; ring < 2; ring++) {
      final double rr = inner * (.42 + ring * .34);
      for (var i = 0; i < 8; i++) {
        final double a = i * math.pi / 4;
        final Offset dot = Offset(
          center.dx + math.cos(a) * rr,
          center.dy + math.sin(a) * rr,
        );
        canvas.drawCircle(
          dot,
          math.max(1.1, s * .018),
          Paint()..color = const Color(0xFF71818C),
        );
      }
    }
    canvas.drawCircle(
      center,
      math.max(1.6, s * .027),
      Paint()..color = const Color(0xFF71818C),
    );
    _text(
      '+',
      Offset(center.dx, body.top - h * .055),
      size: h * .09,
      color: const Color(0xFFD84A4A),
    );
  }

  void cartridgeFuse() {
    final Rect tube = Rect.fromCenter(
      center: c,
      width: w * .50,
      height: h * .25,
    );
    _lead(
      Offset(rect.left + s * .07, c.dy),
      Offset(tube.left, c.dy),
      width: s * .04,
    );
    _lead(
      Offset(tube.right, c.dy),
      Offset(rect.right - s * .07, c.dy),
      width: s * .04,
    );
    _metalTerminal(Offset(rect.left + s * .07, c.dy), scale: .9);
    _metalTerminal(Offset(rect.right - s * .07, c.dy), scale: .9);

    final Rect glass = Rect.fromLTWH(
      tube.left + tube.width * .12,
      tube.top,
      tube.width * .76,
      tube.height,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(glass, Radius.circular(tube.height * .45)),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: const <Color>[
            Color(0xFFE9FBFF),
            Color(0x99B6E0E7),
            Color(0xFFF6FFFF),
          ],
        ).createShader(glass),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(glass, Radius.circular(tube.height * .45)),
      outline,
    );
    final double capW = tube.width * .16;
    for (final Rect cap in <Rect>[
      Rect.fromLTWH(tube.left, tube.top, capW, tube.height),
      Rect.fromLTWH(tube.right - capW, tube.top, capW, tube.height),
    ]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(cap, Radius.circular(tube.height * .18)),
        _horizontalGradient(cap, const <Color>[
          Color(0xFF65757F),
          Color(0xFFDDE4E8),
          Color(0xFF65757F),
        ]),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(cap, Radius.circular(tube.height * .18)),
        outline,
      );
    }
    canvas.drawLine(
      Offset(glass.left + glass.width * .08, c.dy),
      Offset(glass.right - glass.width * .08, c.dy),
      Paint()
        ..color = const Color(0xFF9D6C31)
        ..strokeWidth = math.max(1.2, s * .021),
    );
  }

  void axialDiode() {
    final Rect body = Rect.fromCenter(
      center: c,
      width: w * .42,
      height: h * .24,
    );
    _lead(
      Offset(rect.left + s * .07, c.dy),
      Offset(body.left, c.dy),
      width: s * .04,
    );
    _lead(
      Offset(body.right, c.dy),
      Offset(rect.right - s * .07, c.dy),
      width: s * .04,
    );
    _metalTerminal(Offset(rect.left + s * .07, c.dy), scale: .9);
    _metalTerminal(Offset(rect.right - s * .07, c.dy), scale: .9);

    final RRect rr = RRect.fromRectAndRadius(
      body,
      Radius.circular(body.height / 2),
    );
    _shadowRRect(rr, dy: h * .025);
    canvas.drawRRect(
      rr,
      _verticalGradient(body, const <Color>[
        Color(0xFF4F5960),
        Color(0xFF14191D),
        Color(0xFF2C3338),
      ]),
    );
    canvas.drawRRect(rr, outline);

    final Rect band = Rect.fromLTWH(
      body.right - body.width * .20,
      body.top + body.height * .04,
      body.width * .08,
      body.height * .92,
    );
    canvas.drawRect(
      band,
      _horizontalGradient(band, const <Color>[
        Color(0xFFD7DEE2),
        Color(0xFFFFFFFF),
        Color(0xFF9AA6AD),
      ]),
    );
    canvas.drawLine(
      Offset(body.left + body.width * .10, body.top + body.height * .18),
      Offset(body.right - body.width * .26, body.top + body.height * .18),
      Paint()
        ..color = const Color(0x55FFFFFF)
        ..strokeWidth = math.max(.7, s * .012),
    );
  }

  void coolingFan() {
    final Rect body = Rect.fromCenter(
      center: c,
      width: h * .78,
      height: h * .78,
    );
    _sideTerminals(body);
    _housing(
      body,
      top: const Color(0xFF394954),
      bottom: const Color(0xFF182228),
      radiusFactor: .08,
    );

    final double fanR = body.shortestSide * .38;
    canvas.drawCircle(c, fanR, Paint()..color = const Color(0xFF0C151A));
    canvas.drawCircle(c, fanR, outline);

    for (var i = 0; i < 5; i++) {
      final double a = -math.pi / 2 + i * 2 * math.pi / 5;
      final double a2 = a + .72;
      final Path blade = Path()
        ..moveTo(c.dx, c.dy)
        ..quadraticBezierTo(
          c.dx + math.cos(a + .28) * fanR * .42,
          c.dy + math.sin(a + .28) * fanR * .42,
          c.dx + math.cos(a) * fanR * .87,
          c.dy + math.sin(a) * fanR * .87,
        )
        ..quadraticBezierTo(
          c.dx + math.cos(a2) * fanR * .68,
          c.dy + math.sin(a2) * fanR * .68,
          c.dx,
          c.dy,
        )
        ..close();
      canvas.drawPath(
        blade,
        _verticalGradient(blade.getBounds(), const <Color>[
          Color(0xFF71838E),
          Color(0xFF2D3A42),
        ]),
      );
    }
    canvas.drawCircle(
      c,
      fanR * .19,
      _verticalGradient(
        Rect.fromCircle(center: c, radius: fanR * .19),
        const <Color>[Color(0xFFD5DEE3), Color(0xFF667781)],
      ),
    );
    canvas.drawCircle(c, fanR * .19, outline);

    for (final Offset corner in <Offset>[
      body.topLeft + Offset(body.width * .12, body.height * .12),
      body.topRight + Offset(-body.width * .12, body.height * .12),
      body.bottomLeft + Offset(body.width * .12, -body.height * .12),
      body.bottomRight + Offset(-body.width * .12, -body.height * .12),
    ]) {
      _screw(corner, scale: .6);
    }
  }

  void dcMotor() {
    final Rect body = Rect.fromCenter(
      center: Offset(c.dx - w * .03, c.dy),
      width: w * .52,
      height: h * .56,
    );
    _sideTerminals(body);

    final RRect rr = RRect.fromRectAndRadius(body, Radius.circular(h * .15));
    _shadowRRect(rr, dy: h * .035);
    canvas.drawRRect(
      rr,
      _verticalGradient(
        body,
        const <Color>[Color(0xFFE4EAED), Color(0xFF9EAAB2), Color(0xFF75838C)],
        stops: <double>[0, .55, 1],
      ),
    );
    canvas.drawRRect(rr, outline);

    for (var i = 0; i < 6; i++) {
      final double x = body.left + body.width * (.16 + i * .12);
      canvas.drawLine(
        Offset(x, body.top + h * .055),
        Offset(x, body.bottom - h * .055),
        Paint()
          ..color = const Color(0xFF7E8D96)
          ..strokeWidth = math.max(.8, s * .012),
      );
    }

    final Rect endBell = Rect.fromLTWH(
      body.right - body.width * .08,
      body.top + body.height * .07,
      body.width * .15,
      body.height * .86,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(endBell, Radius.circular(h * .08)),
      Paint()..color = const Color(0xFF5E6D76),
    );
    final double shaftY = c.dy;
    final double shaftStart = body.right + body.width * .02;
    final double shaftEnd = rect.right - s * .08;
    canvas.drawLine(
      Offset(shaftStart, shaftY),
      Offset(shaftEnd, shaftY),
      Paint()
        ..color = const Color(0xFF7C8991)
        ..strokeWidth = math.max(3, s * .07)
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      Offset(shaftStart, shaftY - s * .018),
      Offset(shaftEnd, shaftY - s * .018),
      Paint()
        ..color = const Color(0xFFD9E1E5)
        ..strokeWidth = math.max(1, s * .018)
        ..strokeCap = StrokeCap.round,
    );

    final Rect plate = Rect.fromCenter(
      center: Offset(body.center.dx, body.center.dy),
      width: body.width * .34,
      height: body.height * .33,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(plate, Radius.circular(h * .03)),
      Paint()..color = const Color(0xFFE9EEF0),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(plate, Radius.circular(h * .03)),
      outline,
    );
    _text('24V', plate.center.translate(0, -h * .03), size: h * .075);
    _text('M', plate.center.translate(0, h * .05), size: h * .11);
  }

  void relayCoil() {
    final Rect body = Rect.fromCenter(
      center: c,
      width: w * .56,
      height: h * .64,
    );
    _sideTerminals(body);
    final RRect rr = RRect.fromRectAndRadius(body, Radius.circular(h * .07));
    _shadowRRect(rr, dy: h * .035);

    canvas.drawRRect(
      rr,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: const <Color>[
            Color(0xFFDDECF4),
            Color(0xFF9DB5C5),
            Color(0xFF6F8796),
          ],
        ).createShader(body),
    );
    canvas.drawRRect(rr, outline);

    final Rect window = Rect.fromLTWH(
      body.left + body.width * .13,
      body.top + body.height * .15,
      body.width * .74,
      body.height * .50,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(window, Radius.circular(h * .035)),
      Paint()..color = const Color(0xAA20303A),
    );

    final Rect coil = Rect.fromCenter(
      center: window.center,
      width: window.width * .66,
      height: window.height * .62,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(coil, Radius.circular(h * .045)),
      Paint()..color = const Color(0xFF613A24),
    );
    for (var i = 0; i < 7; i++) {
      final double x = coil.left + coil.width * (.12 + i * .12);
      canvas.drawLine(
        Offset(x, coil.top + coil.height * .12),
        Offset(x, coil.bottom - coil.height * .12),
        Paint()
          ..color = const Color(0xFFE08A45)
          ..strokeWidth = math.max(.8, s * .014),
      );
    }
    final Rect armature = Rect.fromLTWH(
      window.left + window.width * .08,
      window.top + window.height * .12,
      window.width * .12,
      window.height * .76,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(armature, Radius.circular(h * .02)),
      Paint()..color = const Color(0xFFB8C5CC),
    );
    _text(
      'A1',
      Offset(body.left + body.width * .18, body.bottom - h * .08),
      size: h * .07,
    );
    _text(
      'A2',
      Offset(body.right - body.width * .18, body.bottom - h * .08),
      size: h * .07,
    );
  }
}
