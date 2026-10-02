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
    Color accent, {
    bool active = true,
    bool fault = false,
  }) {
    final String t = modelType.toLowerCase();
    if (t == 'dc_voltage_source') {
      _paintPowerSupply(canvas, rect, accent, active: active, fault: fault);
      return true;
    }
    if (t == 'breaker' || t.contains('disjoncteur')) {
      _paintBreaker(canvas, rect, accent, active: active, fault: fault);
      return true;
    }
    if (t == 'switch' || t.contains('interrupteur')) {
      _paintSwitch(canvas, rect, accent, active: active, fault: fault);
      return true;
    }
    if (t.contains('push_button')) {
      _paintPushButton(canvas, rect, accent);
      return true;
    }
    if (t == 'lamp' || t.contains('lampe')) {
      _paintLamp(canvas, rect, accent, active: active, fault: fault);
      return true;
    }
    if (t.contains('multimeter') ||
        t.contains('voltmeter') ||
        t.contains('ammeter')) {
      _paintMeter(canvas, rect, t, accent, active: active);
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
      _paintMotor(canvas, rect, accent, active: active);
      return true;
    }
    if (t.contains('fan')) {
      _paintFan(canvas, rect, accent, active: active);
      return true;
    }
    if (t.contains('relay_coil')) {
      _paintRelay(canvas, rect, accent, active: active);
      return true;
    }
    if (t.contains('contactor') || t.contains('contacteur')) {
      _paintContactor(canvas, rect, accent, active: active, fault: fault);
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

  static Paint _gradient(
    Rect rect,
    List<Color> colors, {
    Alignment begin = Alignment.topLeft,
    Alignment end = Alignment.bottomRight,
  }) =>
      Paint()
        ..shader = LinearGradient(
          begin: begin,
          end: end,
          colors: colors,
        ).createShader(rect);

  static Paint _radial(
    Rect rect,
    List<Color> colors, {
    List<double>? stops,
  }) =>
      Paint()
        ..shader = RadialGradient(
          colors: colors,
          stops: stops,
        ).createShader(rect);

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

  static void _paintPowerSupply(Canvas canvas, Rect rect, Color accent, {required bool active, required bool fault}) {
    final Rect b = _inset(rect, .025);
    final RRect caseRect =
        RRect.fromRectAndRadius(b, Radius.circular(b.shortestSide * .10));
    _shadow(canvas, caseRect);
    canvas.drawRRect(
      caseRect,
      _gradient(
        b,
        const <Color>[
          Color(0xFFF5F8FA),
          Color(0xFFD6E0E8),
          Color(0xFF9CADBA),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    );
    canvas.drawRRect(caseRect, _stroke(const Color(0xFF5D7284), 1.25));

    final Rect topBevel = Rect.fromLTWH(
      b.left + b.width * .08,
      b.top + b.height * .05,
      b.width * .84,
      b.height * .08,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(topBevel, const Radius.circular(3)),
      Paint()..color = const Color(0x80FFFFFF),
    );

    final Rect face = Rect.fromLTWH(
      b.left + b.width * .09,
      b.top + b.height * .16,
      b.width * .82,
      b.height * .66,
    );
    final RRect faceR =
        RRect.fromRectAndRadius(face, Radius.circular(b.shortestSide * .055));
    canvas.drawRRect(
      faceR,
      _gradient(
        face,
        const <Color>[
          Color(0xFFF7F9FB),
          Color(0xFFE3EAF0),
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ),
    );
    canvas.drawRRect(faceR, _stroke(const Color(0xFF9DAAB7), 1));

    final Rect screenFrame = Rect.fromLTWH(
      face.left + face.width * .17,
      face.top + face.height * .10,
      face.width * .66,
      face.height * .28,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(screenFrame, const Radius.circular(4)),
      Paint()..color = const Color(0xFF23313A),
    );
    final Rect screen = screenFrame.deflate(math.max(2, screenFrame.height * .13));
    canvas.drawRRect(
      RRect.fromRectAndRadius(screen, const Radius.circular(2)),
      _gradient(
        screen,
        const <Color>[
          Color(0xFF0A2637),
          Color(0xFF1C5A72),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    );
    canvas.drawRect(
      Rect.fromLTWH(
        screen.left + screen.width * .08,
        screen.top + screen.height * .12,
        screen.width * .60,
        screen.height * .14,
      ),
      Paint()..color = const Color(0x35FFFFFF),
    );
    _tiny(
      canvas,
      active ? '24.0' : '0.0',
      Offset(screen.center.dx - screen.width * .05, screen.center.dy),
      screen.height * .48,
      color: const Color(0xFFD8FFF1),
    );
    _tiny(
      canvas,
      'V',
      Offset(screen.right - screen.width * .16, screen.center.dy),
      screen.height * .32,
      color: const Color(0xFF9BE4CC),
    );

    final double knobR = b.shortestSide * .065;
    for (final Offset c in <Offset>[
      Offset(face.left + face.width * .28, face.bottom - face.height * .22),
      Offset(face.left + face.width * .50, face.bottom - face.height * .22),
    ]) {
      canvas.drawCircle(
        c,
        knobR,
        _radial(
          Rect.fromCircle(center: c, radius: knobR),
          const <Color>[
            Color(0xFF738695),
            Color(0xFF2A3945),
          ],
        ),
      );
      canvas.drawCircle(c, knobR, _stroke(const Color(0xFF1B2730), 1));
      canvas.drawLine(
        c,
        Offset(c.dx + knobR * .10, c.dy - knobR * .65),
        _stroke(const Color(0xFFD8E2E9), 1),
      );
    }

    final Offset neg = Offset(
      face.right - face.width * .26,
      face.bottom - face.height * .22,
    );
    final Offset pos = Offset(
      face.right - face.width * .10,
      face.bottom - face.height * .22,
    );
    for (final (Offset c, Color outer, String label) in <(Offset, Color, String)>[
      (neg, const Color(0xFF1A2228), '−'),
      (pos, const Color(0xFFC43831), '+'),
    ]) {
      canvas.drawCircle(c, knobR * .86, Paint()..color = outer);
      canvas.drawCircle(c, knobR * .86, _stroke(const Color(0xFF10161A), 1));
      canvas.drawCircle(c, knobR * .38, Paint()..color = const Color(0xFFD7DEE3));
      _tiny(
        canvas,
        label,
        Offset(c.dx, c.dy + knobR * 1.65),
        b.height * .065,
        color: outer,
      );
    }

    canvas.drawCircle(
      Offset(face.left + face.width * .08, face.bottom - face.height * .08),
      b.shortestSide * .035,
      Paint()..color = fault
          ? const Color(0xFFD97706)
          : active
              ? const Color(0xFF22A35A)
              : const Color(0xFF87959E),
    );
    _tiny(
      canvas,
      'DC POWER SUPPLY',
      Offset(face.center.dx, face.bottom - face.height * .05),
      b.height * .045,
      color: const Color(0xFF667989),
    );

    for (var i = 0; i < 6; i++) {
      final double x = b.left + b.width * (.13 + i * .12);
      canvas.drawLine(
        Offset(x, b.bottom - b.height * .055),
        Offset(x + b.width * .055, b.bottom - b.height * .055),
        _stroke(const Color(0xFF697D8E), 1),
      );
    }
    final Rect leftFoot = Rect.fromLTWH(
      b.left + b.width * .10,
      b.bottom - b.height * .01,
      b.width * .16,
      b.height * .045,
    );
    final Rect rightFoot = Rect.fromLTWH(
      b.right - b.width * .26,
      b.bottom - b.height * .01,
      b.width * .16,
      b.height * .045,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(leftFoot, const Radius.circular(2)),
      Paint()..color = const Color(0xFF344550),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rightFoot, const Radius.circular(2)),
      Paint()..color = const Color(0xFF344550),
    );
  }

  static void _paintBreaker(Canvas canvas, Rect rect, Color accent, {required bool active, required bool fault}) {
    final Rect b = Rect.fromCenter(
      center: rect.center,
      width: rect.width * .82,
      height: rect.height * .96,
    );
    final RRect outer =
        RRect.fromRectAndRadius(b, Radius.circular(b.shortestSide * .075));
    _shadow(canvas, outer);
    canvas.drawRRect(
      outer,
      _gradient(
        b,
        const <Color>[
          Color(0xFFF7F8F8),
          Color(0xFFDDE5E7),
          Color(0xFFBBC7CB),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    );
    canvas.drawRRect(outer, _stroke(const Color(0xFF566B72), 1.25));

    final Rect leftRib = Rect.fromLTWH(
      b.left + b.width * .05,
      b.top + b.height * .12,
      b.width * .06,
      b.height * .72,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(leftRib, const Radius.circular(2)),
      Paint()..color = const Color(0xFFB5C1C5),
    );
    final Rect rightRib = Rect.fromLTWH(
      b.right - b.width * .11,
      b.top + b.height * .12,
      b.width * .06,
      b.height * .72,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rightRib, const Radius.circular(2)),
      Paint()..color = const Color(0xFFE9EEEE),
    );

    final Rect label = Rect.fromLTWH(
      b.left + b.width * .18,
      b.top + b.height * .08,
      b.width * .64,
      b.height * .21,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(label, const Radius.circular(3)),
      Paint()..color = const Color(0xFFFDFEFE),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(label, const Radius.circular(3)),
      _stroke(const Color(0xFFC1C9CC), .8),
    );
    _tiny(
      canvas,
      'C10',
      Offset(label.center.dx, label.top + label.height * .42),
      b.height * .075,
      color: const Color(0xFF172226),
    );
    _tiny(
      canvas,
      '6 kA',
      Offset(label.center.dx, label.bottom - label.height * .20),
      b.height * .042,
      color: const Color(0xFF6A777A),
    );

    final Rect slot = Rect.fromLTWH(
      b.left + b.width * .30,
      b.top + b.height * .32,
      b.width * .40,
      b.height * .39,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(slot, const Radius.circular(4)),
      _gradient(
        slot,
        const <Color>[
          Color(0xFF9EACB1),
          Color(0xFFCAD4D7),
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(slot, const Radius.circular(4)),
      _stroke(const Color(0xFF7A8C91), 1),
    );

    final Rect lever = Rect.fromLTWH(
      slot.left + slot.width * .18,
      active
          ? slot.top + slot.height * .08
          : slot.top + slot.height * .34,
      slot.width * .64,
      slot.height * .58,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(lever, const Radius.circular(3)),
      _gradient(
        lever,
        const <Color>[
          Color(0xFF4D5A5F),
          Color(0xFF171E21),
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(lever, const Radius.circular(3)),
      _stroke(const Color(0xFF0B1012), 1),
    );
    canvas.drawLine(
      Offset(lever.left + lever.width * .16, lever.top + lever.height * .18),
      Offset(lever.right - lever.width * .16, lever.top + lever.height * .18),
      _stroke(const Color(0x55FFFFFF), 1),
    );

    final Rect window = Rect.fromLTWH(
      b.left + b.width * .17,
      b.top + b.height * .44,
      b.width * .08,
      b.height * .11,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(window, const Radius.circular(2)),
      Paint()..color = fault
          ? const Color(0xFFF59E0B)
          : active
              ? const Color(0xFF4CB46D)
              : const Color(0xFFCF5C55),
    );

    _screw(
      canvas,
      Offset(b.center.dx, b.top + b.height * .06),
      b.shortestSide * .042,
    );
    _screw(
      canvas,
      Offset(b.center.dx, b.bottom - b.height * .06),
      b.shortestSide * .042,
    );
    _tiny(
      canvas,
      active ? 'I' : 'O',
      Offset(b.center.dx, b.top + b.height * .30),
      b.height * .062,
      color: const Color(0xFF253235),
    );

    final Rect dinFoot = Rect.fromLTWH(
      b.left + b.width * .20,
      b.bottom - b.height * .02,
      b.width * .60,
      b.height * .055,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(dinFoot, const Radius.circular(2)),
      Paint()..color = const Color(0xFF6B7D83),
    );
  }

  static void _paintSwitch(Canvas canvas, Rect rect, Color accent, {required bool active, required bool fault}) {
    final Rect b = Rect.fromCenter(
      center: rect.center,
      width: rect.width * .72,
      height: rect.height * .95,
    );
    final RRect outer =
        RRect.fromRectAndRadius(b, Radius.circular(b.shortestSide * .12));
    _shadow(canvas, outer);
    canvas.drawRRect(
      outer,
      _gradient(
        b,
        const <Color>[
          Color(0xFFF6F8F8),
          Color(0xFFD9E3E5),
          Color(0xFFA9B7BC),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    );
    canvas.drawRRect(outer, _stroke(const Color(0xFF586C72), 1.2));

    final Rect well = Rect.fromCenter(
      center: Offset(b.center.dx, b.center.dy - b.height * .04),
      width: b.width * .56,
      height: b.height * .66,
    );
    final RRect wellR =
        RRect.fromRectAndRadius(well, Radius.circular(well.shortestSide * .18));
    canvas.drawRRect(
      wellR,
      _gradient(
        well,
        const <Color>[
          Color(0xFF152126),
          Color(0xFF34464D),
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ),
    );

    final Rect rocker = Rect.fromCenter(
      center: Offset(
        well.center.dx,
        active
            ? well.center.dy + well.height * .20
            : well.center.dy - well.height * .20,
      ),
      width: well.width * .74,
      height: well.height * .36,
    );
    final RRect rockerR =
        RRect.fromRectAndRadius(rocker, Radius.circular(rocker.shortestSide * .24));
    canvas.drawRRect(
      rockerR,
      _gradient(
        rocker,
        active
            ? const <Color>[
                Color(0xFF7CDF98),
                Color(0xFF36A65F),
                Color(0xFF257A45),
              ]
            : const <Color>[
                Color(0xFFDDE4E8),
                Color(0xFF9EADB5),
                Color(0xFF697A83),
              ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ),
    );
    canvas.drawRRect(
      rockerR,
      _stroke(const Color(0xFF205C38), 1),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          rocker.left + rocker.width * .14,
          rocker.top + rocker.height * .12,
          rocker.width * .72,
          rocker.height * .16,
        ),
        const Radius.circular(2),
      ),
      Paint()..color = const Color(0x3FFFFFFF),
    );
    _tiny(
      canvas,
      active ? 'I' : 'O',
      Offset(b.center.dx, b.bottom - b.height * .07),
      b.height * .095,
      color: const Color(0xFF263237),
    );
  }

  static void _paintPushButton(Canvas canvas, Rect rect, Color accent) {
    final Rect b = Rect.fromCenter(
      center: rect.center,
      width: rect.width * .78,
      height: rect.height * .88,
    );
    final RRect outer =
        RRect.fromRectAndRadius(b, Radius.circular(b.shortestSide * .10));
    _shadow(canvas, outer);
    canvas.drawRRect(
      outer,
      _gradient(
        b,
        const <Color>[
          Color(0xFFF1F4F5),
          Color(0xFFCAD5DA),
          Color(0xFF9AABB3),
        ],
      ),
    );
    canvas.drawRRect(outer, _stroke(const Color(0xFF5D7078), 1.15));

    final Offset c = Offset(b.center.dx, b.top + b.height * .34);
    final double bezel = b.shortestSide * .25;
    canvas.drawCircle(
      c,
      bezel,
      _radial(
        Rect.fromCircle(center: c, radius: bezel),
        const <Color>[
          Color(0xFF697980),
          Color(0xFF28373D),
        ],
      ),
    );
    final double buttonR = bezel * .73;
    canvas.drawCircle(
      c,
      buttonR,
      _radial(
        Rect.fromCircle(center: c, radius: buttonR),
        const <Color>[
          Color(0xFFFF786F),
          Color(0xFFD64039),
          Color(0xFF8E201C),
        ],
        stops: const <double>[0, .55, 1],
      ),
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(c.dx - buttonR * .25, c.dy - buttonR * .28),
        width: buttonR * .50,
        height: buttonR * .24,
      ),
      Paint()..color = const Color(0x55FFFFFF),
    );

    final Rect contactBlock = Rect.fromLTWH(
      b.left + b.width * .17,
      b.top + b.height * .65,
      b.width * .66,
      b.height * .22,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(contactBlock, const Radius.circular(4)),
      _gradient(
        contactBlock,
        const <Color>[
          Color(0xFFF8F9F9),
          Color(0xFFDDE4E6),
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(contactBlock, const Radius.circular(4)),
      _stroke(const Color(0xFF89989D), .9),
    );
    _tiny(
      canvas,
      '13   14',
      contactBlock.center,
      b.height * .075,
      color: const Color(0xFF39494F),
    );
  }

  static void _paintLamp(Canvas canvas, Rect rect, Color accent, {required bool active, required bool fault}) {
    final Rect b = _inset(rect, .015);
    final Offset bulbCenter =
        Offset(b.center.dx, b.top + b.height * .36);
    final double bulbR = math.min(b.width * .35, b.height * .30);

    final Rect glowRect = Rect.fromCircle(
      center: bulbCenter,
      radius: bulbR * 1.25,
    );
    if (active && !fault) {
      canvas.drawCircle(
        bulbCenter,
        bulbR * 1.20,
        _radial(
          glowRect,
          const <Color>[
            Color(0x66FFE78A),
            Color(0x18FFE78A),
            Color(0x00FFE78A),
          ],
          stops: const <double>[0, .65, 1],
        ),
      );
    }

    final Rect glassRect = Rect.fromCircle(center: bulbCenter, radius: bulbR);
    canvas.drawCircle(
      bulbCenter,
      bulbR,
      _radial(
        glassRect,
        active && !fault
            ? const <Color>[
                Color(0xFFFFFFD0),
                Color(0xFFFFE690),
                Color(0xFFF5C84A),
              ]
            : const <Color>[
                Color(0xFFF3F5F5),
                Color(0xFFD7DFE2),
                Color(0xFFAAB8BE),
              ],
        stops: const <double>[0, .68, 1],
      ),
    );
    canvas.drawCircle(
      bulbCenter,
      bulbR,
      _stroke(const Color(0xFF30434C), 1.45),
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(
          bulbCenter.dx - bulbR * .25,
          bulbCenter.dy - bulbR * .32,
        ),
        width: bulbR * .32,
        height: bulbR * .20,
      ),
      Paint()..color = const Color(0x66FFFFFF),
    );

    final double baseTopY = b.top + b.height * .74;
    final Offset filamentNode =
        Offset(bulbCenter.dx, bulbCenter.dy + bulbR * .24);
    final Paint filament = _stroke(const Color(0xFF34434B), 1.25);
    canvas.drawLine(
      Offset(bulbCenter.dx - bulbR * .28, bulbCenter.dy + bulbR * .03),
      filamentNode,
      filament,
    );
    canvas.drawLine(
      Offset(bulbCenter.dx + bulbR * .28, bulbCenter.dy + bulbR * .03),
      filamentNode,
      filament,
    );
    canvas.drawLine(
      filamentNode,
      Offset(bulbCenter.dx, baseTopY),
      filament,
    );

    final Rect collar = Rect.fromCenter(
      center: Offset(b.center.dx, b.top + b.height * .79),
      width: bulbR * .78,
      height: b.height * .13,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(collar, const Radius.circular(2)),
      _gradient(
        collar,
        const <Color>[
          Color(0xFFB8C4CC),
          Color(0xFF596D7A),
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(collar, const Radius.circular(2)),
      _stroke(const Color(0xFF344753), 1),
    );
    for (var i = 0; i < 3; i++) {
      final double y = collar.top + collar.height * (.22 + i * .26);
      canvas.drawLine(
        Offset(collar.left + collar.width * .08, y),
        Offset(collar.right - collar.width * .08, y),
        _stroke(const Color(0xFFDDE6EC), .9),
      );
    }

    final Rect foot = Rect.fromCenter(
      center: Offset(b.center.dx, b.top + b.height * .90),
      width: collar.width * .48,
      height: b.height * .065,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(foot, Radius.circular(foot.height * .48)),
      _gradient(
        foot,
        const <Color>[
          Color(0xFF8B9BA6),
          Color(0xFF405462),
        ],
      ),
    );
  }

  static void _paintMeter(Canvas canvas, Rect rect, String t, Color accent, {required bool active}) {
    final Rect b = Rect.fromCenter(
      center: rect.center,
      width: rect.width * .84,
      height: rect.height * .98,
    );
    final RRect holster =
        RRect.fromRectAndRadius(b, Radius.circular(b.shortestSide * .13));
    _shadow(canvas, holster);
    canvas.drawRRect(
      holster,
      _gradient(
        b,
        const <Color>[
          Color(0xFF3A4651),
          Color(0xFF171F26),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    );
    canvas.drawRRect(holster, _stroke(const Color(0xFF0C1115), 1.3));

    final Rect face = Rect.fromLTWH(
      b.left + b.width * .09,
      b.top + b.height * .06,
      b.width * .82,
      b.height * .88,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(face, Radius.circular(b.shortestSide * .09)),
      Paint()..color = const Color(0xFF252E35),
    );

    final Rect screenFrame = Rect.fromLTWH(
      face.left + face.width * .12,
      face.top + face.height * .08,
      face.width * .76,
      face.height * .25,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(screenFrame, const Radius.circular(3)),
      Paint()..color = const Color(0xFF11181C),
    );
    final Rect screen = screenFrame.deflate(math.max(2, screenFrame.height * .10));
    canvas.drawRRect(
      RRect.fromRectAndRadius(screen, const Radius.circular(2)),
      _gradient(
        screen,
        const <Color>[
          Color(0xFFE1F3D0),
          Color(0xFFAFC99B),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    );
    final String reading = !active
        ? '---'
        : t.contains('amp')
            ? '1.00 A'
            : t.contains('volt')
                ? '24.0 V'
                : 'AUTO';
    _tiny(
      canvas,
      reading,
      screen.center,
      b.height * .078,
      color: const Color(0xFF183B26),
    );

    final Offset dial = Offset(b.center.dx, b.top + b.height * .61);
    final double dialR = b.shortestSide * .22;
    canvas.drawCircle(
      dial,
      dialR * 1.18,
      Paint()..color = const Color(0xFF10171C),
    );
    canvas.drawCircle(
      dial,
      dialR,
      _radial(
        Rect.fromCircle(center: dial, radius: dialR),
        const <Color>[
          Color(0xFF44525C),
          Color(0xFF151D22),
        ],
      ),
    );
    canvas.drawCircle(
      dial,
      dialR,
      _stroke(const Color(0xFF70808D), 1),
    );

    for (var i = 0; i < 9; i++) {
      final double a = -math.pi * .85 + i * (math.pi * 1.7 / 8);
      final Offset a1 = Offset(
        dial.dx + math.cos(a) * dialR * .78,
        dial.dy + math.sin(a) * dialR * .78,
      );
      final Offset a2 = Offset(
        dial.dx + math.cos(a) * dialR * .94,
        dial.dy + math.sin(a) * dialR * .94,
      );
      canvas.drawLine(a1, a2, _stroke(const Color(0xFFD1D9DE), .8));
    }

    final double needleA = -math.pi * .60;
    canvas.drawLine(
      dial,
      Offset(
        dial.dx + math.cos(needleA) * dialR * .68,
        dial.dy + math.sin(needleA) * dialR * .68,
      ),
      _stroke(const Color(0xFFE9F0F4), 1.4),
    );
    canvas.drawCircle(dial, dialR * .12, Paint()..color = const Color(0xFF0A0E11));

    final double jackR = b.shortestSide * .052;
    final Offset common = Offset(
      b.left + b.width * .36,
      b.bottom - b.height * .09,
    );
    final Offset positive = Offset(
      b.right - b.width * .25,
      b.bottom - b.height * .09,
    );
    canvas.drawCircle(common, jackR * 1.2, Paint()..color = const Color(0xFF080B0D));
    canvas.drawCircle(common, jackR * .42, Paint()..color = const Color(0xFF4A565E));
    canvas.drawCircle(positive, jackR * 1.2, Paint()..color = const Color(0xFFC12D28));
    canvas.drawCircle(positive, jackR * .42, Paint()..color = const Color(0xFFF1D7D5));
    _tiny(
      canvas,
      'COM',
      Offset(common.dx, common.dy - jackR * 1.8),
      b.height * .034,
      color: const Color(0xFFC7D0D6),
    );
    _tiny(
      canvas,
      'VΩ',
      Offset(positive.dx, positive.dy - jackR * 1.8),
      b.height * .034,
      color: const Color(0xFFE5B4B1),
    );
  }

  static void _paintResistor(Canvas canvas, Rect rect, Color accent) {
    final Rect body = Rect.fromCenter(
      center: rect.center,
      width: rect.width * .62,
      height: rect.height * .36,
    );
    final Paint lead = _stroke(const Color(0xFF697B86), 1.6);
    canvas.drawLine(
      Offset(rect.left + 2, rect.center.dy),
      Offset(body.left, rect.center.dy),
      lead,
    );
    canvas.drawLine(
      Offset(body.right, rect.center.dy),
      Offset(rect.right - 2, rect.center.dy),
      lead,
    );

    final RRect rr =
        RRect.fromRectAndRadius(body, Radius.circular(body.height * .48));
    _shadow(canvas, rr);
    canvas.drawRRect(
      rr,
      _gradient(
        body,
        const <Color>[
          Color(0xFFF4DEAF),
          Color(0xFFD4AA63),
          Color(0xFFA97939),
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ),
    );
    canvas.drawRRect(rr, _stroke(const Color(0xFF8A6231), 1));
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          body.left + body.width * .08,
          body.top + body.height * .10,
          body.width * .84,
          body.height * .20,
        ),
        Radius.circular(body.height * .10),
      ),
      Paint()..color = const Color(0x44FFFFFF),
    );

    const List<Color> bands = <Color>[
      Color(0xFF70401F),
      Color(0xFF15191C),
      Color(0xFFD83A31),
      Color(0xFFD6AA2C),
    ];
    for (var i = 0; i < bands.length; i++) {
      final double x = body.left + body.width * (.22 + i * .17);
      canvas.drawRect(
        Rect.fromLTWH(
          x,
          body.top + body.height * .05,
          math.max(2, body.width * .045),
          body.height * .90,
        ),
        Paint()..color = bands[i],
      );
    }
  }

  static void _paintFuse(Canvas canvas, Rect rect, Color accent) {
    final Rect tube = Rect.fromCenter(
      center: rect.center,
      width: rect.width * .72,
      height: rect.height * .34,
    );
    final double capW = tube.width * .15;
    final Rect glass = Rect.fromLTWH(
      tube.left + capW * .72,
      tube.top,
      tube.width - capW * 1.44,
      tube.height,
    );
    final RRect glassR =
        RRect.fromRectAndRadius(glass, Radius.circular(glass.height * .48));
    _shadow(canvas, glassR);
    canvas.drawRRect(
      glassR,
      _gradient(
        glass,
        const <Color>[
          Color(0xFFF9FFFF),
          Color(0xFFDCECEF),
          Color(0xFFAEC4CA),
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ),
    );
    canvas.drawRRect(glassR, _stroke(const Color(0xFF76909A), 1));

    for (final Rect cap in <Rect>[
      Rect.fromLTWH(tube.left, tube.top, capW, tube.height),
      Rect.fromLTWH(tube.right - capW, tube.top, capW, tube.height),
    ]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(cap, Radius.circular(cap.height * .16)),
        _gradient(
          cap,
          const <Color>[
            Color(0xFFDCE4E8),
            Color(0xFF748692),
            Color(0xFFBAC7CE),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(cap, Radius.circular(cap.height * .16)),
        _stroke(const Color(0xFF596C77), .9),
      );
    }

    final double y = tube.center.dy;
    final Path wire = Path()
      ..moveTo(glass.left + glass.width * .05, y)
      ..lineTo(glass.center.dx - glass.width * .10, y - glass.height * .10)
      ..lineTo(glass.center.dx + glass.width * .10, y + glass.height * .10)
      ..lineTo(glass.right - glass.width * .05, y);
    canvas.drawPath(wire, _stroke(const Color(0xFFC37A23), 1.25));
  }

  static void _paintBuzzer(Canvas canvas, Rect rect, Color accent) {
    final Offset c = rect.center;
    final double r = rect.shortestSide * .37;
    final Rect disk = Rect.fromCircle(center: c, radius: r);
    canvas.drawCircle(
      c,
      r,
      _radial(
        disk,
        const <Color>[
          Color(0xFF5D6C75),
          Color(0xFF27333B),
          Color(0xFF10171C),
        ],
        stops: const <double>[0, .62, 1],
      ),
    );
    canvas.drawCircle(c, r, _stroke(const Color(0xFF0B1014), 1.2));
    canvas.drawCircle(
      Offset(c.dx - r * .24, c.dy - r * .26),
      r * .16,
      Paint()..color = const Color(0x22FFFFFF),
    );
    final double holeR = r * .055;
    for (var i = 0; i < 10; i++) {
      final double a = math.pi * 2 * i / 10;
      final Offset p = Offset(
        c.dx + math.cos(a) * r * .60,
        c.dy + math.sin(a) * r * .60,
      );
      canvas.drawCircle(p, holeR, Paint()..color = const Color(0xFF0B1115));
    }
    canvas.drawCircle(c, r * .16, Paint()..color = const Color(0xFF0B1115));
    _tiny(
      canvas,
      '+',
      Offset(c.dx + r * .52, c.dy + r * .52),
      r * .28,
      color: const Color(0xFFD9E0E4),
    );
  }

  static void _paintDiode(Canvas canvas, Rect rect, Color accent) {
    final Rect body = Rect.fromCenter(
      center: rect.center,
      width: rect.width * .58,
      height: rect.height * .31,
    );
    final Paint lead = _stroke(const Color(0xFF6D7D86), 1.5);
    canvas.drawLine(
      Offset(rect.left + 2, rect.center.dy),
      Offset(body.left, rect.center.dy),
      lead,
    );
    canvas.drawLine(
      Offset(body.right, rect.center.dy),
      Offset(rect.right - 2, rect.center.dy),
      lead,
    );
    final RRect rr =
        RRect.fromRectAndRadius(body, Radius.circular(body.height * .48));
    _shadow(canvas, rr);
    canvas.drawRRect(
      rr,
      _gradient(
        body,
        const <Color>[
          Color(0xFF4A545B),
          Color(0xFF171D21),
          Color(0xFF050709),
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ),
    );
    canvas.drawRRect(rr, _stroke(const Color(0xFF050607), 1));
    canvas.drawRect(
      Rect.fromLTWH(
        body.right - body.width * .22,
        body.top,
        body.width * .075,
        body.height,
      ),
      _gradient(
        body,
        const <Color>[
          Color(0xFFF4F4F2),
          Color(0xFFB8BEC0),
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          body.left + body.width * .08,
          body.top + body.height * .10,
          body.width * .66,
          body.height * .16,
        ),
        Radius.circular(body.height * .08),
      ),
      Paint()..color = const Color(0x35FFFFFF),
    );
  }

  static void _paintMotor(Canvas canvas, Rect rect, Color accent, {required bool active}) {
    final Rect body = Rect.fromCenter(
      center: Offset(rect.center.dx - rect.width * .05, rect.center.dy),
      width: rect.width * .67,
      height: rect.height * .70,
    );
    final RRect rr =
        RRect.fromRectAndRadius(body, Radius.circular(body.height * .20));
    _shadow(canvas, rr);
    canvas.drawRRect(
      rr,
      _gradient(
        body,
        const <Color>[
          Color(0xFFC8D3DB),
          Color(0xFF8095A5),
          Color(0xFF506676),
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ),
    );
    canvas.drawRRect(rr, _stroke(const Color(0xFF415768), 1.1));

    final Rect endCap = Rect.fromLTWH(
      body.left - body.width * .04,
      body.top + body.height * .08,
      body.width * .15,
      body.height * .84,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(endCap, Radius.circular(endCap.width * .40)),
      _gradient(
        endCap,
        const <Color>[
          Color(0xFFA9B9C4),
          Color(0xFF617787),
        ],
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      ),
    );

    for (var i = 0; i < 6; i++) {
      final double x = body.left + body.width * (.17 + i * .11);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            x,
            body.top + body.height * .10,
            body.width * .035,
            body.height * .80,
          ),
          const Radius.circular(1),
        ),
        Paint()..color = const Color(0xFF5C7384),
      );
    }

    final Rect terminalBox = Rect.fromLTWH(
      body.left + body.width * .28,
      body.top - body.height * .12,
      body.width * .34,
      body.height * .20,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(terminalBox, const Radius.circular(3)),
      _gradient(
        terminalBox,
        const <Color>[
          Color(0xFFBCC9D1),
          Color(0xFF708492),
        ],
      ),
    );
    _screw(
      canvas,
      Offset(
        terminalBox.left + terminalBox.width * .28,
        terminalBox.center.dy,
      ),
      terminalBox.shortestSide * .12,
    );
    _screw(
      canvas,
      Offset(
        terminalBox.right - terminalBox.width * .28,
        terminalBox.center.dy,
      ),
      terminalBox.shortestSide * .12,
    );

    final Rect shaft = Rect.fromLTWH(
      body.right,
      body.center.dy - body.height * .065,
      math.max(4, rect.right - body.right - 3),
      body.height * .13,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(shaft, const Radius.circular(2)),
      _gradient(
        shaft,
        const <Color>[
          Color(0xFFE0E6EA),
          Color(0xFF758591),
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ),
    );

    _tiny(
      canvas,
      'M',
      body.center,
      body.height * .27,
      color: const Color(0xFFF6FAFC),
    );
    canvas.drawCircle(
      Offset(body.left + body.width * .16, body.bottom - body.height * .14),
      body.shortestSide * .035,
      Paint()..color = active
          ? const Color(0xFF4AD476)
          : const Color(0xFF71818B),
    );
  }

  static void _paintFan(Canvas canvas, Rect rect, Color accent, {required bool active}) {
    final Rect b = _inset(rect, .025);
    final Offset c = Offset(
      b.left + b.width * .43,
      b.top + b.height * .37,
    );
    final double r = math.min(b.width * .30, b.height * .30);
    final Paint cage = _stroke(const Color(0xFF263B4B), 1.2);

    canvas.drawCircle(c, r, cage);
    canvas.drawCircle(c, r * .74, cage);
    for (var i = 0; i < 8; i++) {
      final double a = math.pi * 2 * i / 8;
      canvas.drawLine(
        c,
        Offset(
          c.dx + math.cos(a) * r,
          c.dy + math.sin(a) * r,
        ),
        _stroke(const Color(0x66495F70), .8),
      );
    }

    for (var i = 0; i < 4; i++) {
      final double a = math.pi / 2 * i;
      final Path blade = Path()
        ..moveTo(c.dx + math.cos(a) * r * .13,
            c.dy + math.sin(a) * r * .13)
        ..quadraticBezierTo(
          c.dx + math.cos(a + .48) * r * .72,
          c.dy + math.sin(a + .48) * r * .72,
          c.dx + math.cos(a + .10) * r * .86,
          c.dy + math.sin(a + .10) * r * .86,
        )
        ..quadraticBezierTo(
          c.dx + math.cos(a - .48) * r * .54,
          c.dy + math.sin(a - .48) * r * .54,
          c.dx + math.cos(a) * r * .13,
          c.dy + math.sin(a) * r * .13,
        )
        ..close();
      canvas.drawPath(blade, Paint()..color = const Color(0xFF7EA4BB));
      canvas.drawPath(blade, _stroke(const Color(0xFF526F80), .8));
    }

    canvas.drawCircle(c, r * .18, Paint()..color = const Color(0xFF9CB2C0));
    canvas.drawCircle(c, r * .18, _stroke(const Color(0xFF263B4B), 1));
    canvas.drawCircle(
      c,
      r * .07,
      Paint()..color = active
          ? const Color(0xFF36A65F)
          : const Color(0xFF425967),
    );

    final Rect motor = Rect.fromCenter(
      center: Offset(c.dx + r * 1.28, c.dy),
      width: r * .54,
      height: r * .72,
    );
    final RRect motorR =
        RRect.fromRectAndRadius(motor, Radius.circular(motor.shortestSide * .24));
    canvas.drawRRect(motorR, Paint()..color = const Color(0xFF6F8999));
    canvas.drawRRect(motorR, _stroke(const Color(0xFF405A69), 1));

    final double stemTop = c.dy + r;
    final double baseY = b.bottom - b.height * .12;
    canvas.drawLine(
      Offset(c.dx, stemTop),
      Offset(c.dx, baseY - b.height * .08),
      _stroke(const Color(0xFF405A69), 1.6),
    );

    final Rect base = Rect.fromCenter(
      center: Offset(c.dx, baseY),
      width: r * 1.18,
      height: b.height * .18,
    );
    final RRect baseR =
        RRect.fromRectAndRadius(base, Radius.circular(base.height * .45));
    _shadow(canvas, baseR);
    canvas.drawRRect(baseR, Paint()..color = const Color(0xFF6F8999));
    canvas.drawRRect(baseR, _stroke(const Color(0xFF405A69), 1));
    canvas.drawLine(
      Offset(base.left + base.width * .18, base.center.dy),
      Offset(base.right - base.width * .18, base.center.dy),
      _stroke(const Color(0xFFD9E5EA), 1.2),
    );
    canvas.drawCircle(
      Offset(base.right - base.width * .14, base.center.dy),
      base.height * .12,
      Paint()..color = const Color(0xFFA8BBB9),
    );
  }

  static void _paintRelay(Canvas canvas, Rect rect, Color accent, {required bool active}) {
    final Rect b = Rect.fromCenter(
      center: rect.center,
      width: rect.width * .84,
      height: rect.height * .74,
    );
    final RRect rr =
        RRect.fromRectAndRadius(b, Radius.circular(b.shortestSide * .08));
    _shadow(canvas, rr);
    canvas.drawRRect(
      rr,
      _gradient(
        b,
        const <Color>[
          Color(0xFFF2F5F6),
          Color(0xFFCBD7DB),
          Color(0xFFA1B1B7),
        ],
      ),
    );
    canvas.drawRRect(rr, _stroke(const Color(0xFF61747B), 1.1));

    final Rect window = Rect.fromLTWH(
      b.left + b.width * .10,
      b.top + b.height * .16,
      b.width * .56,
      b.height * .66,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(window, const Radius.circular(4)),
      Paint()..color = const Color(0x553F5964),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(window, const Radius.circular(4)),
      _stroke(const Color(0xFF7A8C93), .8),
    );

    final Rect coil = Rect.fromLTWH(
      window.left + window.width * .08,
      window.top + window.height * .22,
      window.width * .48,
      window.height * .54,
    );
    for (var i = 0; i < 7; i++) {
      final double x = coil.left + coil.width * i / 6;
      canvas.drawArc(
        Rect.fromCenter(
          center: Offset(x, coil.center.dy),
          width: coil.width * .20,
          height: coil.height * .78,
        ),
        -math.pi / 2,
        math.pi,
        false,
        _stroke(
          active ? const Color(0xFFD69032) : const Color(0xFFA06B2B),
          1.1,
        ),
      );
    }

    final Paint contactPaint = _stroke(
      active ? const Color(0xFF39A861) : const Color(0xFF4B5D64),
      1.3,
    );
    final Offset pivot = Offset(
      window.left + window.width * .67,
      window.center.dy,
    );
    canvas.drawCircle(pivot, b.shortestSide * .035, Paint()..color = contactPaint.color);
    canvas.drawLine(
      pivot,
      Offset(
        window.right - window.width * .08,
        window.center.dy + (active ? 0 : -window.height * .20),
      ),
      contactPaint,
    );

    final Rect label = Rect.fromLTWH(
      b.right - b.width * .27,
      b.top + b.height * .20,
      b.width * .18,
      b.height * .50,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(label, const Radius.circular(3)),
      Paint()..color = const Color(0xFFF7F9FA),
    );
    _tiny(
      canvas,
      'K1',
      label.center,
      b.height * .10,
      color: const Color(0xFF3B4B51),
    );
    _tiny(
      canvas,
      'A1',
      Offset(b.left + b.width * .08, b.bottom - b.height * .06),
      b.height * .055,
    );
    _tiny(
      canvas,
      'A2',
      Offset(b.right - b.width * .08, b.bottom - b.height * .06),
      b.height * .055,
    );
  }

  static void _paintContactor(Canvas canvas, Rect rect, Color accent, {required bool active, required bool fault}) {
    final Rect b = Rect.fromCenter(
      center: rect.center,
      width: rect.width * .86,
      height: rect.height * .97,
    );
    final RRect outer =
        RRect.fromRectAndRadius(b, Radius.circular(b.shortestSide * .085));
    _shadow(canvas, outer);
    canvas.drawRRect(
      outer,
      _gradient(
        b,
        const <Color>[
          Color(0xFFF4F6F6),
          Color(0xFFDCE4E6),
          Color(0xFFAAB7BB),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    );
    canvas.drawRRect(outer, _stroke(const Color(0xFF52666D), 1.25));

    for (var i = 0; i < 3; i++) {
      final double x = b.left + b.width * (.23 + i * .27);
      _screw(
        canvas,
        Offset(x, b.top + b.height * .09),
        b.shortestSide * .042,
      );
      _screw(
        canvas,
        Offset(x, b.bottom - b.height * .08),
        b.shortestSide * .042,
      );
    }

    final Rect darkPanel = Rect.fromLTWH(
      b.left + b.width * .10,
      b.top + b.height * .17,
      b.width * .80,
      b.height * .43,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(darkPanel, const Radius.circular(4)),
      _gradient(
        darkPanel,
        const <Color>[
          Color(0xFF43545A),
          Color(0xFF1B292E),
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ),
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
        Paint()..color = const Color(0xFF101A1E),
      );
      final Rect indicator = Rect.fromLTWH(
        channel.left + channel.width * .26,
        channel.top + channel.height * .12,
        channel.width * .48,
        channel.height * .60,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(indicator, const Radius.circular(1.5)),
        _gradient(
          indicator,
          active
              ? const <Color>[
                  Color(0xFF71C58B),
                  Color(0xFF2F8250),
                ]
              : const <Color>[
                  Color(0xFF8B9A9D),
                  Color(0xFF5B696C),
                ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      );
    }

    final Rect label = Rect.fromLTWH(
      b.left + b.width * .20,
      b.top + b.height * .66,
      b.width * .60,
      b.height * .16,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(label, const Radius.circular(3)),
      Paint()..color = const Color(0xFFF8FAFA),
    );
    _tiny(
      canvas,
      'KM1',
      Offset(label.center.dx, label.top + label.height * .40),
      b.height * .075,
      color: const Color(0xFF263237),
    );
    _tiny(
      canvas,
      'A1        A2',
      Offset(label.center.dx, label.bottom - label.height * .22),
      b.height * .040,
      color: const Color(0xFF596B72),
    );

    canvas.drawCircle(
      Offset(b.right - b.width * .15, b.top + b.height * .72),
      b.shortestSide * .045,
      Paint()..color = fault
          ? const Color(0xFFD97706)
          : active
              ? const Color(0xFF39A861)
              : const Color(0xFF6A7B7F),
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
          _stroke(
            active ? const Color(0xFF2F8E57) : accent,
            1.2,
          ),
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
