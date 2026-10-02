import 'dart:math' as math;

import 'package:electrosim_ui_kit/electrosim_ui_kit.dart';
import 'package:flutter/material.dart';

import 'f18_component_visual_registry.dart';

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
    this.fault = false,
  });

  final String modelType;
  final double size;
  final bool active;
  final bool fault;

  @override
  Widget build(BuildContext context) {
    final Color color =
        active ? ElectroSimColors.primary : ElectroSimColors.textSecondary;
    return CustomPaint(
      size: Size(size * 1.45, size),
      painter: _F18ArchetypePainter(
        modelType: modelType,
        foreground: color,
        active: active,
        fault: fault,
      ),
    );
  }
}

class _F18ArchetypePainter extends CustomPainter {
  const _F18ArchetypePainter({
    required this.modelType,
    required this.foreground,
    required this.active,
    required this.fault,
  });

  final String modelType;
  final Color foreground;
  final bool active;
  final bool fault;

  @override
  void paint(Canvas canvas, Size size) {
    paintF18ElectricalArchetype(
      canvas,
      Offset.zero & size,
      modelType,
      foreground,
      drawTerminals: false,
      active: active,
      fault: fault,
    );
  }

  @override
  bool shouldRepaint(_F18ArchetypePainter oldDelegate) {
    return oldDelegate.modelType != modelType ||
        oldDelegate.foreground != foreground ||
        oldDelegate.active != active ||
        oldDelegate.fault != fault;
  }
}

void paintF18ElectricalArchetype(
  Canvas canvas,
  Rect rect,
  String modelType,
  Color foreground, {
  bool drawTerminals = true,
  bool active = true,
  bool fault = false,
}) {
  final F18ElectricalArchetype archetype =
      F18ElectricalArchetypeClassifier.forModel(modelType);
  final double unit = rect.shortestSide;
  final double radius = math.max(4, unit * .14);
  final Rect body = rect.deflate(math.max(1.5, unit * .05));
  if (F18ComponentVisualRegistry.paint(
    canvas,
    body,
    modelType,
    foreground,
    active: active,
    fault: fault,
  )) {
    return;
  }
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
      final Rect sourceBody = Rect.fromCenter(
        center: Offset(body.center.dx, body.center.dy + body.height * .04),
        width: body.width * .84,
        height: body.height * .78,
      );
      final RRect housing = RRect.fromRectAndRadius(
        sourceBody,
        Radius.circular(radius * .75),
      );
      canvas.drawRRect(housing, Paint()..color = const Color(0xFFC7D2DE));
      canvas.drawRRect(housing, border);
      final double tabW = sourceBody.width * .18;
      final double tabH = math.max(3, sourceBody.height * .12);
      for (final double dx in <double>[.30, .70]) {
        final RRect tab = RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(
              sourceBody.left + sourceBody.width * dx,
              sourceBody.top - tabH * .18,
            ),
            width: tabW,
            height: tabH,
          ),
          Radius.circular(radius * .25),
        );
        canvas.drawRRect(tab, Paint()..color = const Color(0xFF8293A6));
      }
      final RRect front = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          sourceBody.left + sourceBody.width * .15,
          sourceBody.top + sourceBody.height * .22,
          sourceBody.width * .70,
          sourceBody.height * .54,
        ),
        Radius.circular(radius * .35),
      );
      canvas.drawRRect(front, Paint()..color = const Color(0xFFE8EEF4));
      canvas.drawRRect(
        front,
        Paint()
          ..color = const Color(0xFFAAB8C6)
          ..strokeWidth = math.max(1, body.shortestSide * .018)
          ..style = PaintingStyle.stroke,
      );
      return front.outerRect.deflate(sourceBody.shortestSide * .08);
    case F18ElectricalArchetype.protection:
      final Rect module = Rect.fromCenter(
        center: body.center,
        width: body.width * .68,
        height: body.height * .94,
      );
      final RRect housing = RRect.fromRectAndRadius(
        module,
        Radius.circular(radius * .48),
      );
      canvas.drawRRect(housing, Paint()..color = const Color(0xFFF1F4F7));
      canvas.drawRRect(
        housing,
        Paint()
          ..color = const Color(0xFF8FA0B3)
          ..strokeWidth = math.max(1, body.shortestSide * .02)
          ..style = PaintingStyle.stroke,
      );
      _paintScrew(
        canvas,
        Offset(module.left + module.width * .15, module.top + module.height * .12),
        module.shortestSide * .055,
      );
      _paintScrew(
        canvas,
        Offset(module.right - module.width * .15, module.top + module.height * .12),
        module.shortestSide * .055,
      );
      _paintTinyText(
        canvas,
        'MCB',
        Offset(module.center.dx, module.top + module.height * .25),
        const Color(0xFF52657A),
        module.height * .075,
      );
      return Rect.fromCenter(
        center: Offset(module.center.dx, module.center.dy + module.height * .08),
        width: module.width * .56,
        height: module.height * .44,
      );
    case F18ElectricalArchetype.control:
      if (type.contains('switch') || type.contains('interrupteur')) {
        final Rect switchBody = Rect.fromCenter(
          center: body.center,
          width: body.width * .90,
          height: body.height * .64,
        );
        final RRect housing = RRect.fromRectAndRadius(
          switchBody,
          Radius.circular(radius * .75),
        );
        canvas.drawRRect(housing, Paint()..color = const Color(0xFFF8FAFC));
        canvas.drawRRect(housing, border);
        return switchBody.deflate(body.shortestSide * .13);
      }
      final Rect contactor = Rect.fromCenter(
        center: body.center,
        width: body.width * .82,
        height: body.height * .92,
      );
      final RRect housing = RRect.fromRectAndRadius(
        contactor,
        Radius.circular(radius * .55),
      );
      canvas.drawRRect(housing, Paint()..color = const Color(0xFFE9EEF3));
      canvas.drawRRect(
        housing,
        Paint()
          ..color = const Color(0xFF93A4B5)
          ..strokeWidth = math.max(1, body.shortestSide * .02)
          ..style = PaintingStyle.stroke,
      );
      _paintScrew(
        canvas,
        Offset(contactor.left + contactor.width * .13, contactor.top + contactor.height * .10),
        contactor.shortestSide * .045,
      );
      _paintScrew(
        canvas,
        Offset(contactor.right - contactor.width * .13, contactor.top + contactor.height * .10),
        contactor.shortestSide * .045,
      );
      for (var i = 0; i < 3; i++) {
        final Rect cell = Rect.fromLTWH(
          contactor.left + contactor.width * (.16 + i * .23),
          contactor.top + contactor.height * .24,
          contactor.width * .17,
          contactor.height * .13,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(cell, Radius.circular(radius * .15)),
          Paint()..color = const Color(0xFFF8FAFC),
        );
      }
      return Rect.fromCenter(
        center: Offset(contactor.center.dx, contactor.center.dy + contactor.height * .14),
        width: contactor.width * .58,
        height: contactor.height * .38,
      );
    case F18ElectricalArchetype.load:
      if (type.contains('lamp') || type.contains('lampe')) {
        final Rect lampBody = Rect.fromCenter(
          center: body.center,
          width: body.width * .78,
          height: body.height * .86,
        );
        final RRect housing = RRect.fromRectAndRadius(
          lampBody,
          Radius.circular(radius * .60),
        );
        canvas.drawRRect(housing, Paint()..color = const Color(0xFFE9EEF3));
        canvas.drawRRect(
          housing,
          Paint()
            ..color = const Color(0xFF96A6B6)
            ..strokeWidth = math.max(1, body.shortestSide * .02)
            ..style = PaintingStyle.stroke,
        );
        final double diameter = lampBody.shortestSide * .58;
        final Rect circleBounds = Rect.fromCenter(
          center: lampBody.center,
          width: diameter,
          height: diameter,
        );
        canvas.drawCircle(
          lampBody.center,
          diameter / 2,
          Paint()..color = const Color(0xFFFFE28A),
        );
        canvas.drawCircle(
          lampBody.center,
          diameter / 2,
          Paint()
            ..color = const Color(0xFFC49A22)
            ..strokeWidth = math.max(1.2, body.shortestSide * .025)
            ..style = PaintingStyle.stroke,
        );
        return circleBounds.deflate(diameter * .12);
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
      final double diameter = math.min(body.width * .70, body.height * .86);
      final Offset center =
          Offset(body.center.dx - body.width * .07, body.center.dy);
      final Rect motorRect = Rect.fromCircle(center: center, radius: diameter / 2);
      canvas.drawOval(motorRect, Paint()..color = const Color(0xFFB9C6D2));
      for (var i = -2; i <= 2; i++) {
        final double x = center.dx + i * diameter * .11;
        canvas.drawLine(
          Offset(x, motorRect.top + diameter * .08),
          Offset(x, motorRect.bottom - diameter * .08),
          Paint()
            ..color = const Color(0xFF8395A8)
            ..strokeWidth = math.max(1, body.shortestSide * .018),
        );
      }
      canvas.drawOval(motorRect, border);
      final Rect shaft = Rect.fromLTWH(
        motorRect.right - 1,
        center.dy - diameter * .08,
        body.right - motorRect.right,
        diameter * .16,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(shaft, Radius.circular(radius * .18)),
        Paint()..color = const Color(0xFF7D8EA0),
      );
      return Rect.fromCircle(center: center, radius: diameter * .34);
    case F18ElectricalArchetype.measurement:
      final Rect meter = Rect.fromCenter(
        center: body.center,
        width: body.width * .76,
        height: body.height * .94,
      );
      final RRect housing = RRect.fromRectAndRadius(
        meter,
        Radius.circular(radius * .80),
      );
      canvas.drawRRect(housing, Paint()..color = const Color(0xFF27323D));
      canvas.drawRRect(
        housing,
        Paint()
          ..color = const Color(0xFF17212B)
          ..strokeWidth = math.max(1, body.shortestSide * .02)
          ..style = PaintingStyle.stroke,
      );
      final RRect display = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          meter.left + meter.width * .14,
          meter.top + meter.height * .12,
          meter.width * .72,
          meter.height * .28,
        ),
        Radius.circular(radius * .30),
      );
      canvas.drawRRect(display, Paint()..color = const Color(0xFFD8F0C9));
      _paintTinyText(
        canvas,
        type.contains('amp') ? '1.00 A' : '230.0 V',
        display.outerRect.center,
        const Color(0xFF17412B),
        meter.height * .12,
      );
      return Rect.fromCenter(
        center: Offset(meter.center.dx, meter.center.dy + meter.height * .18),
        width: meter.width * .52,
        height: meter.height * .34,
      );
    case F18ElectricalArchetype.conversion:
      final Rect inverter = Rect.fromCenter(
        center: body.center,
        width: body.width * .78,
        height: body.height * .86,
      );
      final RRect housing = RRect.fromRectAndRadius(
        inverter,
        Radius.circular(radius * .55),
      );
      canvas.drawRRect(housing, Paint()..color = const Color(0xFFD7E0E8));
      canvas.drawRRect(housing, border);
      for (final double x in <double>[inverter.left, inverter.right]) {
        for (var i = 0; i < 5; i++) {
          final double y = inverter.top + inverter.height * (.18 + i * .14);
          canvas.drawLine(
            Offset(x, y),
            Offset(x + (x == inverter.left ? -body.width * .06 : body.width * .06), y),
            Paint()
              ..color = const Color(0xFF72869A)
              ..strokeWidth = math.max(1, body.shortestSide * .018),
          );
        }
      }
      final RRect screen = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          inverter.left + inverter.width * .18,
          inverter.top + inverter.height * .18,
          inverter.width * .64,
          inverter.height * .26,
        ),
        Radius.circular(radius * .25),
      );
      canvas.drawRRect(screen, Paint()..color = const Color(0xFF16395B));
      _paintTinyText(
        canvas,
        'INV',
        screen.outerRect.center,
        Colors.white,
        inverter.height * .10,
      );
      return Rect.fromCenter(
        center: Offset(inverter.center.dx, inverter.center.dy + inverter.height * .16),
        width: inverter.width * .55,
        height: inverter.height * .30,
      );
    case F18ElectricalArchetype.pvEnergy:
      final Rect panel = Rect.fromCenter(
        center: body.center,
        width: body.width * .84,
        height: body.height * .74,
      );
      final RRect housing = RRect.fromRectAndRadius(
        panel,
        Radius.circular(radius * .35),
      );
      canvas.drawRRect(housing, Paint()..color = const Color(0xFF2C5F8E));
      canvas.drawRRect(
        housing,
        Paint()
          ..color = const Color(0xFF9FB0C0)
          ..strokeWidth = math.max(1, body.shortestSide * .025)
          ..style = PaintingStyle.stroke,
      );
      final Paint grid = Paint()
        ..color = const Color(0xFF75A0C6)
        ..strokeWidth = math.max(.8, body.shortestSide * .012);
      for (var i = 1; i < 4; i++) {
        final double x = panel.left + panel.width * i / 4;
        canvas.drawLine(Offset(x, panel.top), Offset(x, panel.bottom), grid);
      }
      for (var i = 1; i < 2; i++) {
        final double y = panel.top + panel.height * i / 2;
        canvas.drawLine(Offset(panel.left, y), Offset(panel.right, y), grid);
      }
      return panel.deflate(body.shortestSide * .08);
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


void _paintScrew(
  Canvas canvas,
  Offset center,
  double radius,
) {
  final Paint fill = Paint()
    ..color = const Color(0xFFD7E0EA)
    ..style = PaintingStyle.fill;
  final Paint stroke = Paint()
    ..color = const Color(0xFF6B7E91)
    ..strokeWidth = math.max(1, radius * .35)
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;
  canvas.drawCircle(center, radius, fill);
  canvas.drawCircle(center, radius, stroke);
  canvas.drawLine(
    Offset(center.dx - radius * .55, center.dy),
    Offset(center.dx + radius * .55, center.dy),
    stroke,
  );
}

void _paintTinyText(
  Canvas canvas,
  String text,
  Offset center,
  Color color,
  double fontSize,
) {
  final TextPainter painter = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        color: color,
        fontSize: math.max(6, fontSize),
        fontWeight: FontWeight.w800,
        height: 1,
      ),
    ),
    textDirection: TextDirection.ltr,
    maxLines: 1,
  )..layout();
  painter.paint(
    canvas,
    Offset(
      center.dx - painter.width / 2,
      center.dy - painter.height / 2,
    ),
  );
}
