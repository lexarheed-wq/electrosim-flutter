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
  Color foreground,
) {
  final F18ElectricalArchetype archetype =
      F18ElectricalArchetypeClassifier.forModel(modelType);
  final double radius = math.max(4, rect.shortestSide * .16);
  final Rect body = rect.deflate(rect.shortestSide * .06);
  final Paint housing = Paint()
    ..color = archetype == F18ElectricalArchetype.source
        ? const Color(0xFFEAF2FF)
        : const Color(0xFFF8FAFC)
    ..style = PaintingStyle.fill;
  final Paint border = Paint()
    ..color = const Color(0xFF334155)
    ..strokeWidth = math.max(1.2, rect.shortestSide * .045)
    ..style = PaintingStyle.stroke;
  final Paint accent = Paint()
    ..color = foreground
    ..strokeWidth = math.max(1.4, rect.shortestSide * .055)
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  canvas.drawRRect(
    RRect.fromRectAndRadius(body, Radius.circular(radius)),
    housing,
  );
  canvas.drawRRect(
    RRect.fromRectAndRadius(body, Radius.circular(radius)),
    border,
  );

  final Rect mark = Rect.fromCenter(
    center: body.center,
    width: body.width * .62,
    height: body.height * .58,
  );
  _paintArchetypeMark(
    canvas,
    mark,
    modelType,
    archetype,
    accent,
    foreground,
  );

  final Paint terminalPaint = Paint()
    ..color = Colors.white
    ..style = PaintingStyle.fill;
  final Paint terminalBorder = Paint()
    ..color = const Color(0xFF0F172A)
    ..strokeWidth = math.max(1, rect.shortestSide * .035)
    ..style = PaintingStyle.stroke;
  final double terminalRadius = math.max(2.2, rect.shortestSide * .07);
  for (final Offset p in <Offset>[
    Offset(body.left, body.center.dy),
    Offset(body.right, body.center.dy),
  ]) {
    canvas.drawCircle(p, terminalRadius, terminalPaint);
    canvas.drawCircle(p, terminalRadius, terminalBorder);
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
          Offset(
            rect.left + w * (.20 + i * .11),
            c.dy + (i.isEven ? -h * .18 : h * .18),
          ),
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
