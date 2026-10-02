import 'dart:math' as math;

import 'package:flutter/material.dart';

/// G4-R1 production visual registry.
///
/// Every common product component gets its own physical identity. The older
/// eight-family archetype renderer remains a fallback for unknown models only.
abstract final class F18ComponentVisualRegistry {
  static const Set<String> dedicatedModels = <String>{
    'dc_voltage_source',
    'breaker',
    'switch',
    'push_button_no',
    'lamp',
    'multimeter',
    'voltmeter',
    'ammeter',
    'resistor',
    'fuse',
    'buzzer',
    'diode',
    'motor_dc',
    'fan_dc',
    'relay_coil',
    'contactor',
    'inverter',
    'transformer',
    'pv_panel',
    'battery_storage',
    'regulator',
  };

  static bool hasDedicatedVisual(String modelType) {
    final String t = modelType.toLowerCase();
    if (dedicatedModels.contains(t)) return true;
    return t.contains('contactor') ||
        t.contains('contacteur') ||
        t.contains('voltmeter') ||
        t.contains('ammeter') ||
        t.contains('multimeter') ||
        t.contains('inverter') ||
        t.contains('transformer') ||
        t.contains('pv_panel') ||
        t.contains('battery') ||
        t.contains('regulator');
  }

  static bool paint(
    Canvas canvas,
    Rect rect,
    String modelType,
    Color accent,
  ) {
    final String t = modelType.toLowerCase();
    if (t == 'dc_voltage_source') {
      _paintPowerSupply(canvas, rect, accent);
      return true;
    }
    if (t == 'breaker' || t.contains('disjoncteur')) {
      _paintBreaker(canvas, rect, accent);
      return true;
    }
    if (t == 'switch' || t.contains('interrupteur')) {
      _paintSwitch(canvas, rect, accent);
      return true;
    }
    if (t.contains('push_button')) {
      _paintPushButton(canvas, rect, accent);
      return true;
    }
    if (t == 'lamp' || t.contains('lampe')) {
      _paintLamp(canvas, rect, accent);
      return true;
    }
    if (t.contains('multimeter') ||
        t.contains('voltmeter') ||
        t.contains('ammeter')) {
      _paintMeter(canvas, rect, t, accent);
      return true;
    }
    if (t == 'resistor') {
      _paintResistor(canvas, rect, accent);
      return true;
    }
    if (t == 'fuse') {
      _paintFuse(canvas, rect, accent);
      return true;
    }
    if (t == 'buzzer') {
      _paintBuzzer(canvas, rect, accent);
      return true;
    }
    if (t == 'diode') {
      _paintDiode(canvas, rect, accent);
      return true;
    }
    if (t.contains('motor')) {
      _paintMotor(canvas, rect, accent);
      return true;
    }
    if (t.contains('fan')) {
      _paintFan(canvas, rect, accent);
      return true;
    }
    if (t.contains('relay_coil')) {
      _paintRelay(canvas, rect, accent);
      return true;
    }
    if (t.contains('contactor') || t.contains('contacteur')) {
      _paintContactor(canvas, rect, accent);
      return true;
    }
    if (t.contains('inverter')) {
      _paintInverter(canvas, rect, accent);
      return true;
    }
    if (t.contains('transformer')) {
      _paintTransformer(canvas, rect, accent);
      return true;
    }
    if (t.contains('pv_panel')) {
      _paintPvPanel(canvas, rect, accent);
      return true;
    }
    if (t.contains('battery')) {
      _paintBattery(canvas, rect, accent);
      return true;
    }
    if (t.contains('regulator')) {
      _paintRegulator(canvas, rect, accent);
      return true;
    }
    return false;
  }

  static Rect _inset(Rect rect, double factor) =>
      rect.deflate(math.max(2, rect.shortestSide * factor));

  static Paint _stroke(Color color, double width) => Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  static void _shadow(Canvas canvas, RRect rr) {
    canvas.drawRRect(
      rr.shift(const Offset(1.8, 2.4)),
      Paint()..color = const Color(0x180F172A),
    );
  }

  static void _tiny(
    Canvas canvas,
    String text,
    Offset center,
    double size, {
    Color color = const Color(0xFF334155),
    FontWeight weight = FontWeight.w800,
  }) {
    final TextPainter p = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: math.max(5.5, size),
          fontWeight: weight,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    p.paint(
      canvas,
      Offset(center.dx - p.width / 2, center.dy - p.height / 2),
    );
  }

  static void _screw(Canvas canvas, Offset c, double r) {
    final Paint edge = _stroke(const Color(0xFF52677B), math.max(.8, r * .3));
    canvas.drawCircle(c, r, Paint()..color = const Color(0xFFDCE4EC));
    canvas.drawCircle(c, r, edge);
    canvas.drawLine(
      Offset(c.dx - r * .55, c.dy),
      Offset(c.dx + r * .55, c.dy),
      edge,
    );
  }

  static void _paintPowerSupply(Canvas canvas, Rect rect, Color accent) {
    final Rect b = _inset(rect, .04);
    final RRect caseRect =
        RRect.fromRectAndRadius(b, Radius.circular(b.shortestSide * .10));
    _shadow(canvas, caseRect);
    canvas.drawRRect(caseRect, Paint()..color = const Color(0xFFCCD6E0));
    canvas.drawRRect(caseRect, _stroke(const Color(0xFF72859A), 1.2));

    final Rect face = Rect.fromLTWH(
      b.left + b.width * .10,
      b.top + b.height * .12,
      b.width * .80,
      b.height * .70,
    );
    final RRect faceR =
        RRect.fromRectAndRadius(face, Radius.circular(b.shortestSide * .06));
    canvas.drawRRect(faceR, Paint()..color = const Color(0xFFEFF3F7));
    canvas.drawRRect(faceR, _stroke(const Color(0xFFA6B4C2), 1));

    final Rect screen = Rect.fromLTWH(
      face.left + face.width * .16,
      face.top + face.height * .12,
      face.width * .68,
      face.height * .26,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(screen, const Radius.circular(3)),
      Paint()..color = const Color(0xFF173B58),
    );
    _tiny(
      canvas,
      '24.0 V',
      screen.center,
      screen.height * .42,
      color: const Color(0xFFD9F7E8),
    );

    final double knobR = b.shortestSide * .07;
    canvas.drawCircle(
      Offset(face.left + face.width * .30, face.bottom - face.height * .20),
      knobR,
      Paint()..color = const Color(0xFF52677B),
    );
    canvas.drawCircle(
      Offset(face.right - face.width * .30, face.bottom - face.height * .20),
      knobR,
      Paint()..color = const Color(0xFF52677B),
    );
    _tiny(
      canvas,
      '+',
      Offset(face.left + face.width * .22, face.bottom - face.height * .06),
      b.height * .09,
      color: const Color(0xFFB42318),
    );
    _tiny(
      canvas,
      '−',
      Offset(face.right - face.width * .22, face.bottom - face.height * .06),
      b.height * .09,
    );

    for (var i = 0; i < 5; i++) {
      final double x = b.left + b.width * (.16 + i * .14);
      canvas.drawLine(
        Offset(x, b.bottom - b.height * .07),
        Offset(x + b.width * .05, b.bottom - b.height * .07),
        _stroke(const Color(0xFF93A4B5), 1),
      );
    }
  }

  static void _paintBreaker(Canvas canvas, Rect rect, Color accent) {
    final Rect b = Rect.fromCenter(
      center: rect.center,
      width: rect.width * .78,
      height: rect.height * .94,
    );
    final RRect outer =
        RRect.fromRectAndRadius(b, Radius.circular(b.shortestSide * .09));
    _shadow(canvas, outer);
    canvas.drawRRect(outer, Paint()..color = const Color(0xFFDFE7E8));
    canvas.drawRRect(outer, _stroke(const Color(0xFF65777C), 1.2));

    final Rect label = Rect.fromLTWH(
      b.left + b.width * .13,
      b.top + b.height * .08,
      b.width * .74,
      b.height * .18,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(label, const Radius.circular(3)),
      Paint()..color = const Color(0xFFF7F9FA),
    );
    _tiny(
      canvas,
      'C10',
      Offset(label.center.dx, label.center.dy - label.height * .08),
      b.height * .075,
      color: const Color(0xFF253235),
    );

    final Rect slot = Rect.fromLTWH(
      b.left + b.width * .32,
      b.top + b.height * .31,
      b.width * .36,
      b.height * .40,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(slot, const Radius.circular(3)),
      Paint()..color = const Color(0xFFBBC6CC),
    );
    final Rect lever = Rect.fromLTWH(
      slot.left + slot.width * .16,
      slot.top + slot.height * .08,
      slot.width * .68,
      slot.height * .55,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(lever, const Radius.circular(3)),
      Paint()..color = const Color(0xFF232D31),
    );
    canvas.drawLine(
      Offset(lever.left + lever.width * .16, lever.top + lever.height * .20),
      Offset(lever.right - lever.width * .16, lever.top + lever.height * .20),
      _stroke(const Color(0x33FFFFFF), 1),
    );

    final Offset stateDot = Offset(b.center.dx, b.bottom - b.height * .12);
    canvas.drawCircle(
      stateDot,
      b.shortestSide * .055,
      Paint()..color = const Color(0xFF5CBD79),
    );
    _tiny(
      canvas,
      'I',
      Offset(b.center.dx, b.top + b.height * .25),
      b.height * .075,
      color: const Color(0xFF253235),
    );
  }

  static void _paintSwitch(Canvas canvas, Rect rect, Color accent) {
    final Rect b = Rect.fromCenter(
      center: rect.center,
      width: rect.width * .68,
      height: rect.height * .94,
    );
    final RRect outer =
        RRect.fromRectAndRadius(b, Radius.circular(b.shortestSide * .12));
    _shadow(canvas, outer);
    canvas.drawRRect(outer, Paint()..color = const Color(0xFFDFE7E8));
    canvas.drawRRect(outer, _stroke(const Color(0xFF667B81), 1.2));

    final Rect well = Rect.fromCenter(
      center: b.center,
      width: b.width * .52,
      height: b.height * .74,
    );
    final RRect wellR =
        RRect.fromRectAndRadius(well, Radius.circular(well.shortestSide * .18));
    canvas.drawRRect(wellR, Paint()..color = const Color(0xFF26363B));

    final Rect rocker = Rect.fromCenter(
      center: Offset(well.center.dx, well.center.dy + well.height * .22),
      width: well.width * .72,
      height: well.height * .33,
    );
    final RRect rockerR =
        RRect.fromRectAndRadius(rocker, Radius.circular(rocker.shortestSide * .25));
    canvas.drawRRect(rockerR, Paint()..color = const Color(0xFF5CBD79));
    canvas.drawRRect(
      rockerR,
      _stroke(const Color(0xFF386A49), 1),
    );
    canvas.drawLine(
      Offset(rocker.left + rocker.width * .18, rocker.top + rocker.height * .28),
      Offset(rocker.right - rocker.width * .18, rocker.top + rocker.height * .28),
      _stroke(const Color(0x55FFFFFF), 1),
    );
    _tiny(
      canvas,
      'I',
      Offset(b.center.dx, b.bottom - b.height * .07),
      b.height * .10,
      color: const Color(0xFF263237),
    );
  }

  static void _paintPushButton(Canvas canvas, Rect rect, Color accent) {
    final Rect b = Rect.fromCenter(
      center: rect.center,
      width: rect.width * .82,
      height: rect.height * .86,
    );
    final RRect rr =
        RRect.fromRectAndRadius(b, Radius.circular(b.shortestSide * .10));
    _shadow(canvas, rr);
    canvas.drawRRect(rr, Paint()..color = const Color(0xFFCCD6E0));
    canvas.drawRRect(rr, _stroke(const Color(0xFF8192A4), 1));

    final Offset c = Offset(b.center.dx, b.top + b.height * .34);
    canvas.drawCircle(c, b.shortestSide * .22, Paint()..color = const Color(0xFFCC3C2F));
    canvas.drawCircle(c, b.shortestSide * .22, _stroke(const Color(0xFF8D251D), 1.2));
    canvas.drawCircle(
      Offset(c.dx - b.width * .05, c.dy - b.height * .05),
      b.shortestSide * .055,
      Paint()..color = const Color(0x55FFFFFF),
    );

    final Rect block = Rect.fromLTWH(
      b.left + b.width * .18,
      b.top + b.height * .62,
      b.width * .64,
      b.height * .22,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(block, const Radius.circular(3)),
      Paint()..color = const Color(0xFFF4F6F8),
    );
    _tiny(canvas, 'NO', block.center, b.height * .08);
  }

  static void _paintLamp(Canvas canvas, Rect rect, Color accent) {
    final Rect b = Rect.fromCenter(
      center: rect.center,
      width: rect.width * .82,
      height: rect.height * .88,
    );
    final RRect rr =
        RRect.fromRectAndRadius(b, Radius.circular(b.shortestSide * .10));
    _shadow(canvas, rr);
    canvas.drawRRect(rr, Paint()..color = const Color(0xFFD3DCE5));
    canvas.drawRRect(rr, _stroke(const Color(0xFF8798A9), 1));

    final Offset c = Offset(b.center.dx, b.top + b.height * .43);
    final double bezelR = b.shortestSide * .29;
    canvas.drawCircle(c, bezelR, Paint()..color = const Color(0xFF6F7F90));
    canvas.drawCircle(c, bezelR * .82, Paint()..color = const Color(0xFFFFC928));
    canvas.drawCircle(c, bezelR * .82, _stroke(const Color(0xFFC19115), 1));
    canvas.drawCircle(
      Offset(c.dx - bezelR * .22, c.dy - bezelR * .26),
      bezelR * .18,
      Paint()..color = const Color(0x70FFFFFF),
    );

    final Rect label = Rect.fromLTWH(
      b.left + b.width * .20,
      b.bottom - b.height * .20,
      b.width * .60,
      b.height * .11,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(label, const Radius.circular(2)),
      Paint()..color = const Color(0xFFF6F8FA),
    );
    _tiny(canvas, '24 V', label.center, b.height * .065);
  }

  static void _paintMeter(Canvas canvas, Rect rect, String t, Color accent) {
    final Rect b = Rect.fromCenter(
      center: rect.center,
      width: rect.width * .78,
      height: rect.height * .96,
    );
    final RRect rr =
        RRect.fromRectAndRadius(b, Radius.circular(b.shortestSide * .12));
    _shadow(canvas, rr);
    canvas.drawRRect(rr, Paint()..color = const Color(0xFF26313B));
    canvas.drawRRect(rr, _stroke(const Color(0xFF111820), 1.2));

    final Rect screen = Rect.fromLTWH(
      b.left + b.width * .12,
      b.top + b.height * .10,
      b.width * .76,
      b.height * .25,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(screen, const Radius.circular(3)),
      Paint()..color = const Color(0xFFCDE5BC),
    );
    final String reading = t.contains('amp') ? '1.00 A' : t.contains('volt') ? '24.0 V' : 'AUTO';
    _tiny(canvas, reading, screen.center, b.height * .09, color: const Color(0xFF173E29));

    final Offset dial = Offset(b.center.dx, b.top + b.height * .60);
    final double dialR = b.shortestSide * .21;
    canvas.drawCircle(dial, dialR, Paint()..color = const Color(0xFF0F1720));
    canvas.drawCircle(dial, dialR, _stroke(const Color(0xFF75869A), 1));
    canvas.drawLine(
      dial,
      Offset(dial.dx + dialR * .15, dial.dy - dialR * .72),
      _stroke(const Color(0xFFE6EDF3), 1.4),
    );

    canvas.drawCircle(
      Offset(b.left + b.width * .32, b.bottom - b.height * .10),
      b.shortestSide * .055,
      Paint()..color = const Color(0xFF111820),
    );
    canvas.drawCircle(
      Offset(b.right - b.width * .32, b.bottom - b.height * .10),
      b.shortestSide * .055,
      Paint()..color = const Color(0xFFC02A22),
    );
  }

  static void _paintResistor(Canvas canvas, Rect rect, Color accent) {
    final Rect b = Rect.fromCenter(
      center: rect.center,
      width: rect.width * .88,
      height: rect.height * .44,
    );
    canvas.drawLine(
      Offset(rect.left + 2, rect.center.dy),
      Offset(b.left, rect.center.dy),
      _stroke(const Color(0xFF52677B), 1.4),
    );
    canvas.drawLine(
      Offset(b.right, rect.center.dy),
      Offset(rect.right - 2, rect.center.dy),
      _stroke(const Color(0xFF52677B), 1.4),
    );
    final RRect rr =
        RRect.fromRectAndRadius(b, Radius.circular(b.height * .45));
    _shadow(canvas, rr);
    canvas.drawRRect(rr, Paint()..color = const Color(0xFFE4C58E));
    canvas.drawRRect(rr, _stroke(const Color(0xFF9B7640), 1));
    const List<Color> bands = <Color>[
      Color(0xFF6B3E1E),
      Color(0xFF111827),
      Color(0xFFD92D20),
      Color(0xFFD4A72C),
    ];
    for (var i = 0; i < bands.length; i++) {
      final double x = b.left + b.width * (.24 + i * .15);
      canvas.drawRect(
        Rect.fromLTWH(x, b.top + 2, math.max(2, b.width * .035), b.height - 4),
        Paint()..color = bands[i],
      );
    }
  }

  static void _paintFuse(Canvas canvas, Rect rect, Color accent) {
    final Rect tube = Rect.fromCenter(
      center: rect.center,
      width: rect.width * .76,
      height: rect.height * .30,
    );
    final RRect glass =
        RRect.fromRectAndRadius(tube, Radius.circular(tube.height * .45));
    _shadow(canvas, glass);
    canvas.drawRRect(glass, Paint()..color = const Color(0xFFE9F3F6));
    canvas.drawRRect(glass, _stroke(const Color(0xFF8AA1B1), 1));
    final double cap = tube.width * .14;
    canvas.drawRect(
      Rect.fromLTWH(tube.left, tube.top, cap, tube.height),
      Paint()..color = const Color(0xFF8797A6),
    );
    canvas.drawRect(
      Rect.fromLTWH(tube.right - cap, tube.top, cap, tube.height),
      Paint()..color = const Color(0xFF8797A6),
    );
    canvas.drawLine(
      Offset(tube.left + cap, tube.center.dy),
      Offset(tube.right - cap, tube.center.dy),
      _stroke(const Color(0xFFB7791F), 1.2),
    );
  }

  static void _paintBuzzer(Canvas canvas, Rect rect, Color accent) {
    final Offset c = rect.center;
    final double r = rect.shortestSide * .36;
    canvas.drawCircle(c, r, Paint()..color = const Color(0xFF273746));
    canvas.drawCircle(c, r, _stroke(const Color(0xFF0F172A), 1.1));
    canvas.drawCircle(c, r * .42, Paint()..color = const Color(0xFF111820));
    for (var i = 0; i < 8; i++) {
      final double a = math.pi * 2 * i / 8;
      final Offset p = Offset(
        c.dx + math.cos(a) * r * .68,
        c.dy + math.sin(a) * r * .68,
      );
      canvas.drawCircle(p, r * .055, Paint()..color = const Color(0xFF8AA0B2));
    }
  }

  static void _paintDiode(Canvas canvas, Rect rect, Color accent) {
    final Rect b = Rect.fromCenter(
      center: rect.center,
      width: rect.width * .68,
      height: rect.height * .32,
    );
    final RRect rr =
        RRect.fromRectAndRadius(b, Radius.circular(b.height * .48));
    _shadow(canvas, rr);
    canvas.drawRRect(rr, Paint()..color = const Color(0xFF222A32));
    canvas.drawRRect(rr, _stroke(const Color(0xFF0F172A), 1));
    canvas.drawRect(
      Rect.fromLTWH(
        b.right - b.width * .23,
        b.top,
        b.width * .07,
        b.height,
      ),
      Paint()..color = const Color(0xFFE8E8E8),
    );
    canvas.drawLine(
      Offset(rect.left + 2, rect.center.dy),
      Offset(b.left, rect.center.dy),
      _stroke(const Color(0xFF697C8E), 1.2),
    );
    canvas.drawLine(
      Offset(b.right, rect.center.dy),
      Offset(rect.right - 2, rect.center.dy),
      _stroke(const Color(0xFF697C8E), 1.2),
    );
  }

  static void _paintMotor(Canvas canvas, Rect rect, Color accent) {
    final Rect body = Rect.fromCenter(
      center: Offset(rect.center.dx - rect.width * .04, rect.center.dy),
      width: rect.width * .68,
      height: rect.height * .72,
    );
    final RRect rr =
        RRect.fromRectAndRadius(body, Radius.circular(body.height * .22));
    _shadow(canvas, rr);
    canvas.drawRRect(rr, Paint()..color = const Color(0xFF9EAFBF));
    canvas.drawRRect(rr, _stroke(const Color(0xFF667A8E), 1.1));
    for (var i = 0; i < 5; i++) {
      final double x = body.left + body.width * (.18 + i * .13);
      canvas.drawLine(
        Offset(x, body.top + body.height * .12),
        Offset(x, body.bottom - body.height * .12),
        _stroke(const Color(0xFF788B9E), 1),
      );
    }
    final Rect shaft = Rect.fromLTWH(
      body.right,
      body.center.dy - body.height * .07,
      rect.right - body.right - 2,
      body.height * .14,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(shaft, const Radius.circular(2)),
      Paint()..color = const Color(0xFF6E7E8C),
    );
    _tiny(canvas, 'M', body.center, body.height * .28, color: const Color(0xFFF8FAFC));
  }

  static void _paintFan(Canvas canvas, Rect rect, Color accent) {
    final Offset c = rect.center;
    final double r = rect.shortestSide * .36;
    canvas.drawCircle(c, r, Paint()..color = const Color(0xFFE3E8ED));
    canvas.drawCircle(c, r, _stroke(const Color(0xFF8797A6), 1));
    for (var i = 0; i < 4; i++) {
      final double a = math.pi / 2 * i;
      final Path blade = Path()
        ..moveTo(c.dx, c.dy)
        ..quadraticBezierTo(
          c.dx + math.cos(a + .4) * r * .55,
          c.dy + math.sin(a + .4) * r * .55,
          c.dx + math.cos(a) * r * .82,
          c.dy + math.sin(a) * r * .82,
        )
        ..quadraticBezierTo(
          c.dx + math.cos(a - .55) * r * .38,
          c.dy + math.sin(a - .55) * r * .38,
          c.dx,
          c.dy,
        );
      canvas.drawPath(blade, Paint()..color = const Color(0xFF73879A));
    }
    canvas.drawCircle(c, r * .13, Paint()..color = const Color(0xFF334155));
  }

  static void _paintRelay(Canvas canvas, Rect rect, Color accent) {
    final Rect b = Rect.fromCenter(
      center: rect.center,
      width: rect.width * .82,
      height: rect.height * .72,
    );
    final RRect rr =
        RRect.fromRectAndRadius(b, Radius.circular(b.shortestSide * .08));
    _shadow(canvas, rr);
    canvas.drawRRect(rr, Paint()..color = const Color(0xFFDDE5EC));
    canvas.drawRRect(rr, _stroke(const Color(0xFF8293A5), 1));
    final Rect coil = Rect.fromLTWH(
      b.left + b.width * .12,
      b.top + b.height * .24,
      b.width * .36,
      b.height * .50,
    );
    for (var i = 0; i < 5; i++) {
      final double x = coil.left + coil.width * i / 4;
      canvas.drawArc(
        Rect.fromCenter(
          center: Offset(x, coil.center.dy),
          width: coil.width * .28,
          height: coil.height * .75,
        ),
        -math.pi / 2,
        math.pi,
        false,
        _stroke(accent, 1.2),
      );
    }
    _tiny(
      canvas,
      'A1  A2',
      Offset(b.right - b.width * .24, b.center.dy),
      b.height * .10,
    );
  }

  static void _paintContactor(Canvas canvas, Rect rect, Color accent) {
    final Rect b = Rect.fromCenter(
      center: rect.center,
      width: rect.width * .82,
      height: rect.height * .94,
    );
    final RRect outer =
        RRect.fromRectAndRadius(b, Radius.circular(b.shortestSide * .10));
    _shadow(canvas, outer);
    canvas.drawRRect(outer, Paint()..color = const Color(0xFFDFE7E8));
    canvas.drawRRect(outer, _stroke(const Color(0xFF5C7177), 1.2));

    final Rect darkPanel = Rect.fromLTWH(
      b.left + b.width * .09,
      b.top + b.height * .10,
      b.width * .82,
      b.height * .48,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(darkPanel, const Radius.circular(4)),
      Paint()..color = const Color(0xFF36464B),
    );

    for (var i = 0; i < 3; i++) {
      final double x = darkPanel.left + darkPanel.width * (.22 + i * .28);
      final Rect channel = Rect.fromCenter(
        center: Offset(x, darkPanel.center.dy),
        width: darkPanel.width * .15,
        height: darkPanel.height * .64,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(channel, const Radius.circular(2)),
        Paint()..color = const Color(0xFF1B292E),
      );
      final Rect indicator = Rect.fromLTWH(
        channel.left + channel.width * .25,
        channel.top + channel.height * .14,
        channel.width * .50,
        channel.height * .58,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(indicator, const Radius.circular(1.5)),
        Paint()..color = const Color(0xFF7A888B),
      );
    }

    _tiny(
      canvas,
      'KM',
      Offset(b.center.dx, b.bottom - b.height * .20),
      b.height * .10,
      color: const Color(0xFF263237),
    );
    _tiny(
      canvas,
      'A1   A2',
      Offset(b.center.dx, b.bottom - b.height * .08),
      b.height * .065,
      color: const Color(0xFF52677B),
    );
    canvas.drawCircle(
      Offset(b.right - b.width * .14, b.bottom - b.height * .18),
      b.shortestSide * .05,
      Paint()..color = const Color(0xFF7A888B),
    );
  }

  static void _paintInverter(Canvas canvas, Rect rect, Color accent) {
    final Rect b = Rect.fromCenter(
      center: rect.center,
      width: rect.width * .78,
      height: rect.height * .90,
    );
    final RRect rr =
        RRect.fromRectAndRadius(b, Radius.circular(b.shortestSide * .08));
    _shadow(canvas, rr);
    canvas.drawRRect(rr, Paint()..color = const Color(0xFFD7E0E8));
    canvas.drawRRect(rr, _stroke(const Color(0xFF71869A), 1));
    final Rect screen = Rect.fromLTWH(
      b.left + b.width * .18,
      b.top + b.height * .12,
      b.width * .64,
      b.height * .24,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(screen, const Radius.circular(3)),
      Paint()..color = const Color(0xFF153C5D),
    );
    _tiny(canvas, '230 V', screen.center, b.height * .085, color: Colors.white);
    for (var i = 0; i < 5; i++) {
      final double y = b.top + b.height * (.48 + i * .07);
      canvas.drawLine(
        Offset(b.left + b.width * .18, y),
        Offset(b.right - b.width * .18, y),
        _stroke(const Color(0xFF93A4B5), 1),
      );
    }
  }

  static void _paintTransformer(Canvas canvas, Rect rect, Color accent) {
    final Rect b = _inset(rect, .08);
    final double coilW = b.width * .23;
    for (var side = 0; side < 2; side++) {
      final double x = side == 0
          ? b.left + b.width * .28
          : b.right - b.width * .28;
      for (var i = 0; i < 4; i++) {
        canvas.drawArc(
          Rect.fromCenter(
            center: Offset(x, b.top + b.height * (.30 + i * .12)),
            width: coilW,
            height: b.height * .20,
          ),
          -math.pi / 2,
          math.pi,
          false,
          _stroke(accent, 1.2),
        );
      }
    }
    for (final double dx in <double>[-.035, .035]) {
      canvas.drawLine(
        Offset(b.center.dx + b.width * dx, b.top + b.height * .15),
        Offset(b.center.dx + b.width * dx, b.bottom - b.height * .15),
        _stroke(const Color(0xFF52677B), 1.2),
      );
    }
  }

  static void _paintPvPanel(Canvas canvas, Rect rect, Color accent) {
    final Rect p = Rect.fromCenter(
      center: rect.center,
      width: rect.width * .88,
      height: rect.height * .72,
    );
    final RRect rr =
        RRect.fromRectAndRadius(p, Radius.circular(p.shortestSide * .04));
    _shadow(canvas, rr);
    canvas.drawRRect(rr, Paint()..color = const Color(0xFF174B76));
    canvas.drawRRect(rr, _stroke(const Color(0xFF92A9BC), 1.2));
    final Paint grid = _stroke(const Color(0xFF6CA0C9), .8);
    for (var i = 1; i < 6; i++) {
      final double x = p.left + p.width * i / 6;
      canvas.drawLine(Offset(x, p.top), Offset(x, p.bottom), grid);
    }
    for (var i = 1; i < 3; i++) {
      final double y = p.top + p.height * i / 3;
      canvas.drawLine(Offset(p.left, y), Offset(p.right, y), grid);
    }
    canvas.drawLine(
      Offset(p.left + p.width * .08, p.bottom),
      Offset(p.left - p.width * .02, rect.bottom),
      _stroke(const Color(0xFF71869A), 1.3),
    );
    canvas.drawLine(
      Offset(p.right - p.width * .08, p.bottom),
      Offset(p.right + p.width * .02, rect.bottom),
      _stroke(const Color(0xFF71869A), 1.3),
    );
  }

  static void _paintBattery(Canvas canvas, Rect rect, Color accent) {
    final Rect b = Rect.fromCenter(
      center: rect.center,
      width: rect.width * .74,
      height: rect.height * .68,
    );
    final RRect rr =
        RRect.fromRectAndRadius(b, Radius.circular(b.shortestSide * .08));
    _shadow(canvas, rr);
    canvas.drawRRect(rr, Paint()..color = const Color(0xFF3A4652));
    canvas.drawRRect(rr, _stroke(const Color(0xFF17212B), 1.1));
    for (final double dx in <double>[.28, .72]) {
      final Rect tab = Rect.fromCenter(
        center: Offset(b.left + b.width * dx, b.top - b.height * .06),
        width: b.width * .13,
        height: b.height * .12,
      );
      canvas.drawRect(tab, Paint()..color = const Color(0xFF8597A8));
    }
    _tiny(canvas, '12 V', b.center, b.height * .20, color: Colors.white);
  }

  static void _paintRegulator(Canvas canvas, Rect rect, Color accent) {
    final Rect b = Rect.fromCenter(
      center: rect.center,
      width: rect.width * .80,
      height: rect.height * .82,
    );
    final RRect rr =
        RRect.fromRectAndRadius(b, Radius.circular(b.shortestSide * .08));
    _shadow(canvas, rr);
    canvas.drawRRect(rr, Paint()..color = const Color(0xFFDDE6EE));
    canvas.drawRRect(rr, _stroke(const Color(0xFF71869A), 1));
    final Rect screen = Rect.fromLTWH(
      b.left + b.width * .16,
      b.top + b.height * .14,
      b.width * .68,
      b.height * .24,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(screen, const Radius.circular(3)),
      Paint()..color = const Color(0xFF214E6D),
    );
    _tiny(canvas, 'MPPT', screen.center, b.height * .09, color: Colors.white);
    for (var i = 0; i < 3; i++) {
      canvas.drawCircle(
        Offset(
          b.left + b.width * (.28 + i * .22),
          b.bottom - b.height * .18,
        ),
        b.shortestSide * .045,
        Paint()..color = const Color(0xFF53687B),
      );
    }
  }
}
