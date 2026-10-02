import 'dart:math' as math;

import 'package:electrosim_ui_kit/electrosim_ui_kit.dart';
import 'package:flutter/material.dart';

enum F18ElectricalArchetype {
  source,
  protection,
  control,
  load,
  rotatingMachine,
  measurement,
  conversion,
  pvEnergy,
}

abstract final class F18ElectricalArchetypeClassifier {
  static F18ElectricalArchetype forModel(String modelType) {
    final String type = modelType.toLowerCase();

    if (_containsAny(type, <String>[
      'pv',
      'solar',
      'irradiance',
      'battery_storage',
      'regulator',
    ])) {
      return F18ElectricalArchetype.pvEnergy;
    }
    if (_containsAny(type, <String>[
      'inverter',
      'converter',
      'rectifier',
      'transformer',
      'dc_dc',
      'ac_dc',
    ])) {
      return F18ElectricalArchetype.conversion;
    }
    if (_containsAny(type, <String>[
      'meter',
      'voltmeter',
      'ammeter',
      'multimeter',
      'oscilloscope',
      'sensor',
      'probe',
    ])) {
      return F18ElectricalArchetype.measurement;
    }
    if (_containsAny(type, <String>[
      'breaker',
      'fuse',
      'rcd',
      'protection',
      'disjoncteur',
      'fusible',
    ])) {
      return F18ElectricalArchetype.protection;
    }
    if (_containsAny(type, <String>[
      'switch',
      'push_button',
      'relay',
      'contactor',
      'contacteur',
      'interrupteur',
      'bouton',
      'coil',
      'bobine',
    ])) {
      return F18ElectricalArchetype.control;
    }
    if (_containsAny(type, <String>[
      'motor',
      'fan',
      'pump',
      'moteur',
      'ventilateur',
      'pompe',
    ])) {
      return F18ElectricalArchetype.rotatingMachine;
    }
    if (_containsAny(type, <String>[
      'lamp',
      'resistor',
      'heater',
      'buzzer',
      'diode',
      'load',
      'lampe',
      'résistance',
      'resistance',
      'chauffage',
    ])) {
      return F18ElectricalArchetype.load;
    }
    return F18ElectricalArchetype.source;
  }

  static bool _containsAny(String value, List<String> needles) {
    return needles.any(value.contains);
  }
}

class F18ComponentArchetypeGlyph extends StatelessWidget {
  const F18ComponentArchetypeGlyph({
    super.key,
    required this.modelType,
    this.size = 28,
    this.active = true,
  });

  final String modelType;
  final double size;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final Color color =
        active ? ElectroSimColors.primary : ElectroSimColors.textSecondary;
    return CustomPaint(
      size: Size(size * 1.45, size),
      painter: _F18ArchetypePainter(
        modelType: modelType,
        foreground: color,
      ),
    );
  }
}

class _F18ArchetypePainter extends CustomPainter {
  const _F18ArchetypePainter({
    required this.modelType,
    required this.foreground,
  });

  final String modelType;
  final Color foreground;

  @override
  void paint(Canvas canvas, Size size) {
    paintF18ElectricalArchetype(
      canvas,
      Offset.zero & size,
      modelType,
      foreground,
    );
  }

  @override
  bool shouldRepaint(_F18ArchetypePainter oldDelegate) {
    return oldDelegate.modelType != modelType ||
        oldDelegate.foreground != foreground;
  }
}

void paintF18ElectricalArchetype(
  Canvas canvas,
  Rect rect,
  String modelType,
  Color foreground, {
  bool drawTerminals = true,
}) {
  final F18ElectricalArchetype archetype =
      F18ElectricalArchetypeClassifier.forModel(modelType);
  final double unit = rect.shortestSide;
  final double radius = math.max(4, unit * .14);
  final Rect body = rect.deflate(math.max(1.5, unit * .05));
  final Paint border = Paint()
    ..color = const Color(0xFF334155)
    ..strokeWidth = math.max(1.2, unit * .04)
    ..style = PaintingStyle.stroke
    ..strokeJoin = StrokeJoin.round;
  final Paint accent = Paint()
    ..color = foreground
    ..strokeWidth = math.max(1.4, unit * .05)
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  final Rect mark = _paintArchetypeHousing(
    canvas,
    body,
    archetype,
    modelType,
    radius,
    border,
    foreground,
  );
  _paintArchetypeMark(
    canvas,
    mark,
    modelType,
    archetype,
    accent,
    foreground,
  );

  if (!drawTerminals) {
    return;
  }
  final Paint terminalPaint = Paint()
    ..color = Colors.white
    ..style = PaintingStyle.fill;
  final Paint terminalBorder = Paint()
    ..color = const Color(0xFF0F172A)
    ..strokeWidth = math.max(1, unit * .03)
    ..style = PaintingStyle.stroke;
  final double terminalRadius = math.max(2.2, unit * .065);
  for (final Offset p in <Offset>[
    Offset(body.left, body.center.dy),
    Offset(body.right, body.center.dy),
  ]) {
    canvas.drawCircle(p, terminalRadius, terminalPaint);
    canvas.drawCircle(p, terminalRadius, terminalBorder);
  }
}

Rect _paintArchetypeHousing(
  Canvas canvas,
  Rect body,
  F18ElectricalArchetype archetype,
  String modelType,
  double radius,
  Paint border,
  Color foreground,
) {
  final String type = modelType.toLowerCase();
  switch (archetype) {
    case F18ElectricalArchetype.source:
      final RRect housing = RRect.fromRectAndRadius(
        body,
        Radius.circular(radius),
      );
      canvas.drawRRect(
        housing,
        Paint()..color = const Color(0xFFEAF2FF),
      );
      canvas.drawRRect(housing, border);
      final TextPainter polarity = TextPainter(
        text: TextSpan(
          text: '+    −',
          style: TextStyle(
            color: foreground,
            fontSize: math.max(8, body.height * .18),
            fontWeight: FontWeight.w800,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      polarity.paint(
        canvas,
        Offset(body.center.dx - polarity.width / 2, body.top + 2),
      );
      return body.deflate(body.shortestSide * .16).shift(
            Offset(0, body.height * .07),
          );
    case F18ElectricalArchetype.protection:
      final Rect module = Rect.fromCenter(
        center: body.center,
        width: body.width * .82,
        height: body.height * .96,
      );
      final RRect housing = RRect.fromRectAndRadius(
        module,
        Radius.circular(radius * .55),
      );
      canvas.drawRRect(housing, Paint()..color = const Color(0xFFF8FAFC));
      canvas.drawRRect(housing, border);
      canvas.drawRect(
        Rect.fromLTWH(
          module.left + module.width * .08,
          module.top + module.height * .08,
          module.width * .84,
          module.height * .12,
        ),
        Paint()..color = const Color(0xFFE2E8F0),
      );
      return Rect.fromCenter(
        center: Offset(module.center.dx, module.center.dy + module.height * .06),
        width: module.width * .66,
        height: module.height * .50,
      );
    case F18ElectricalArchetype.control:
      final RRect housing = RRect.fromRectAndRadius(
        body,
        Radius.circular(radius * 1.25),
      );
      canvas.drawRRect(housing, Paint()..color = const Color(0xFFFFFFFF));
      canvas.drawRRect(housing, border);
      if (type.contains('push_button') || type.contains('bouton')) {
        canvas.drawCircle(
          Offset(body.center.dx, body.top + body.height * .27),
          body.shortestSide * .13,
          Paint()..color = const Color(0xFFE2E8F0),
        );
      }
      return body.deflate(body.shortestSide * .16).shift(
            Offset(0, body.height * .08),
          );
    case F18ElectricalArchetype.load:
      if (type.contains('lamp') || type.contains('lampe')) {
        final double diameter = math.min(body.width, body.height) * .88;
        final Rect circleBounds = Rect.fromCenter(
          center: body.center,
          width: diameter,
          height: diameter,
        );
        canvas.drawCircle(
          body.center,
          diameter / 2,
          Paint()..color = const Color(0xFFFFFBEB),
        );
        canvas.drawCircle(body.center, diameter / 2, border);
        return circleBounds.deflate(diameter * .13);
      }
      final RRect housing = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: body.center,
          width: body.width * .90,
          height: body.height * .60,
        ),
        Radius.circular(radius * .55),
      );
      canvas.drawRRect(housing, Paint()..color = const Color(0xFFFFFBEB));
      canvas.drawRRect(housing, border);
      return housing.outerRect.deflate(body.shortestSide * .10);
    case F18ElectricalArchetype.rotatingMachine:
      final double diameter = math.min(body.width * .72, body.height * .92);
      final Offset center =
          Offset(body.center.dx - body.width * .05, body.center.dy);
      canvas.drawCircle(
        center,
        diameter / 2,
        Paint()..color = const Color(0xFFF1F5F9),
      );
      canvas.drawCircle(center, diameter / 2, border);
      canvas.drawLine(
        Offset(center.dx + diameter / 2, center.dy),
        Offset(body.right, center.dy),
        border,
      );
      return Rect.fromCircle(center: center, radius: diameter * .36);
    case F18ElectricalArchetype.measurement:
      final RRect housing = RRect.fromRectAndRadius(
        body,
        Radius.circular(radius),
      );
      canvas.drawRRect(housing, Paint()..color = const Color(0xFFF8FAFC));
      canvas.drawRRect(housing, border);
      final RRect display = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          body.left + body.width * .15,
          body.top + body.height * .12,
          body.width * .70,
          body.height * .30,
        ),
        Radius.circular(radius * .4),
      );
      canvas.drawRRect(display, Paint()..color = const Color(0xFFE2E8F0));
      return Rect.fromCenter(
        center: Offset(body.center.dx, body.center.dy + body.height * .10),
        width: body.width * .60,
        height: body.height * .46,
      );
    case F18ElectricalArchetype.conversion:
      final Path housing = Path()
        ..moveTo(body.left + body.width * .08, body.top)
        ..lineTo(body.right - body.width * .08, body.top)
        ..lineTo(body.right, body.center.dy)
        ..lineTo(body.right - body.width * .08, body.bottom)
        ..lineTo(body.left + body.width * .08, body.bottom)
        ..lineTo(body.left, body.center.dy)
        ..close();
      canvas.drawPath(housing, Paint()..color = const Color(0xFFF1F5F9));
      canvas.drawPath(housing, border);
      return body.deflate(body.shortestSide * .16);
    case F18ElectricalArchetype.pvEnergy:
      final RRect housing = RRect.fromRectAndRadius(
        body,
        Radius.circular(radius * .45),
      );
      canvas.drawRRect(housing, Paint()..color = const Color(0xFFEAF2FF));
      canvas.drawRRect(housing, border);
      return body.deflate(body.shortestSide * .12);
  }
}

void _paintArchetypeMark(
  Canvas canvas,
  Rect rect,
  String modelType,
  F18ElectricalArchetype archetype,
  Paint stroke,
  Color color,
) {
  final String type = modelType.toLowerCase();
  final Offset c = rect.center;
  final double w = rect.width;
  final double h = rect.height;

  if (type.contains('lamp') || type.contains('lampe')) {
    canvas.drawCircle(c, rect.shortestSide * .30, stroke);
    canvas.drawLine(
      Offset(c.dx - w * .18, c.dy - h * .18),
      Offset(c.dx + w * .18, c.dy + h * .18),
      stroke,
    );
    canvas.drawLine(
      Offset(c.dx + w * .18, c.dy - h * .18),
      Offset(c.dx - w * .18, c.dy + h * .18),
      stroke,
    );
    return;
  }

  switch (archetype) {
    case F18ElectricalArchetype.source:
      canvas.drawLine(
        Offset(c.dx - w * .12, rect.top + h * .1),
        Offset(c.dx - w * .12, rect.bottom - h * .1),
        stroke,
      );
      canvas.drawLine(
        Offset(c.dx + w * .10, rect.top + h * .24),
        Offset(c.dx + w * .10, rect.bottom - h * .24),
        stroke,
      );
      break;
    case F18ElectricalArchetype.protection:
      canvas.drawRect(
        Rect.fromCenter(center: c, width: w * .55, height: h * .42),
        stroke,
      );
      canvas.drawLine(
        Offset(c.dx - w * .18, c.dy + h * .12),
        Offset(c.dx + w * .18, c.dy - h * .12),
        stroke,
      );
      break;
    case F18ElectricalArchetype.control:
      final Paint fill = Paint()..color = color;
      canvas.drawCircle(Offset(rect.left + w * .16, c.dy), w * .055, fill);
      canvas.drawCircle(Offset(rect.right - w * .16, c.dy), w * .055, fill);
      canvas.drawLine(
        Offset(rect.left + w * .22, c.dy),
        Offset(rect.right - w * .22, rect.top + h * .18),
        stroke,
      );
      break;
    case F18ElectricalArchetype.load:
      final Path zigzag = Path()..moveTo(rect.left + w * .08, c.dy);
      for (var i = 0; i < 6; i++) {
        zigzag.lineTo(
          rect.left + w * (.20 + i * .11),
          c.dy + (i.isEven ? -h * .18 : h * .18),
        );
      }
      zigzag.lineTo(rect.right - w * .08, c.dy);
      canvas.drawPath(zigzag, stroke);
      break;
    case F18ElectricalArchetype.rotatingMachine:
      canvas.drawCircle(c, rect.shortestSide * .34, stroke);
      _paintLetter(canvas, c, type.contains('fan') ? 'F' : 'M', color, h * .46);
      break;
    case F18ElectricalArchetype.measurement:
      canvas.drawCircle(c, rect.shortestSide * .34, stroke);
      _paintLetter(
        canvas,
        c,
        type.contains('amp') ? 'A' : 'V',
        color,
        h * .42,
      );
      break;
    case F18ElectricalArchetype.conversion:
      canvas.drawRect(
        Rect.fromCenter(center: c, width: w * .58, height: h * .48),
        stroke,
      );
      canvas.drawLine(
        Offset(c.dx, rect.top + h * .10),
        Offset(c.dx, rect.bottom - h * .10),
        stroke,
      );
      canvas.drawLine(
        Offset(rect.left + w * .13, c.dy - h * .12),
        Offset(c.dx - w * .08, c.dy + h * .12),
        stroke,
      );
      canvas.drawArc(
        Rect.fromCenter(
          center: Offset(c.dx + w * .16, c.dy),
          width: w * .22,
          height: h * .28,
        ),
        -math.pi / 2,
        math.pi,
        false,
        stroke,
      );
      break;
    case F18ElectricalArchetype.pvEnergy:
      final Rect panel = Rect.fromCenter(
        center: c,
        width: w * .60,
        height: h * .50,
      );
      canvas.drawRect(panel, stroke);
      canvas.drawLine(
        Offset(panel.center.dx, panel.top),
        Offset(panel.center.dx, panel.bottom),
        stroke,
      );
      canvas.drawLine(
        Offset(panel.left, panel.center.dy),
        Offset(panel.right, panel.center.dy),
        stroke,
      );
      break;
  }
}

void _paintLetter(
  Canvas canvas,
  Offset center,
  String letter,
  Color color,
  double fontSize,
) {
  final TextPainter painter = TextPainter(
    text: TextSpan(
      text: letter,
      style: TextStyle(
        color: color,
        fontSize: fontSize,
        fontWeight: FontWeight.w700,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  painter.paint(
    canvas,
    Offset(center.dx - painter.width / 2, center.dy - painter.height / 2),
  );
}
