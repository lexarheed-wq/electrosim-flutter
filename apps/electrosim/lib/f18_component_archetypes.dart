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

  if (_paintSpecificElectricalModel(
    canvas,
    rect,
    type,
    stroke,
    color,
  )) {
    return;
  }

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

bool _paintSpecificElectricalModel(
  Canvas canvas,
  Rect rect,
  String type,
  Paint stroke,
  Color color,
) {
  final Offset c = rect.center;
  final double w = rect.width;
  final double h = rect.height;
  final Paint fill = Paint()
    ..color = color
    ..style = PaintingStyle.fill;

  if (type == 'dc_voltage_source' || type == 'voltage_source') {
    canvas.drawLine(
      Offset(c.dx - w * .12, rect.top + h * .06),
      Offset(c.dx - w * .12, rect.bottom - h * .06),
      stroke,
    );
    canvas.drawLine(
      Offset(c.dx + w * .10, rect.top + h * .24),
      Offset(c.dx + w * .10, rect.bottom - h * .24),
      stroke,
    );
    _paintLetter(
      canvas,
      Offset(rect.left + w * .10, rect.top + h * .08),
      '+',
      color,
      h * .24,
    );
    _paintLetter(
      canvas,
      Offset(rect.right - w * .10, rect.bottom - h * .08),
      '−',
      color,
      h * .24,
    );
    return true;
  }

  if (type == 'resistor') {
    final Path path = Path()..moveTo(rect.left + w * .02, c.dy);
    const int peaks = 6;
    for (var i = 0; i < peaks; i++) {
      final double x = rect.left + w * (.15 + i * .12);
      path.lineTo(
        x,
        c.dy + (i.isEven ? -h * .24 : h * .24),
      );
    }
    path.lineTo(rect.right - w * .02, c.dy);
    canvas.drawPath(path, stroke);
    return true;
  }

  if (type == 'lamp') {
    final double r = rect.shortestSide * .34;
    canvas.drawCircle(c, r, stroke);
    canvas.drawLine(
      Offset(c.dx - r * .68, c.dy - r * .68),
      Offset(c.dx + r * .68, c.dy + r * .68),
      stroke,
    );
    canvas.drawLine(
      Offset(c.dx + r * .68, c.dy - r * .68),
      Offset(c.dx - r * .68, c.dy + r * .68),
      stroke,
    );
    return true;
  }

  if (type == 'switch' ||
      type == 'switch_spst' ||
      type == 'push_button_no') {
    final Offset left = Offset(rect.left + w * .14, c.dy);
    final Offset right = Offset(rect.right - w * .14, c.dy);
    canvas.drawCircle(left, w * .045, fill);
    canvas.drawCircle(right, w * .045, fill);
    if (type == 'push_button_no') {
      canvas.drawLine(
        Offset(c.dx, rect.top + h * .03),
        Offset(c.dx, c.dy - h * .16),
        stroke,
      );
      canvas.drawLine(
        Offset(c.dx - w * .10, rect.top + h * .03),
        Offset(c.dx + w * .10, rect.top + h * .03),
        stroke,
      );
    }
    canvas.drawLine(
      Offset(left.dx + w * .04, left.dy),
      Offset(right.dx - w * .04, rect.top + h * .18),
      stroke,
    );
    return true;
  }

  if (type == 'breaker_dc' ||
      type == 'breaker_ac1' ||
      type == 'breaker') {
    final Rect housing = Rect.fromCenter(
      center: c,
      width: w * .58,
      height: h * .58,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(housing, Radius.circular(h * .08)),
      stroke,
    );
    canvas.drawLine(
      Offset(housing.left + w * .10, housing.bottom - h * .10),
      Offset(housing.right - w * .10, housing.top + h * .10),
      stroke,
    );
    canvas.drawCircle(
      Offset(housing.left + w * .10, housing.bottom - h * .10),
      w * .035,
      fill,
    );
    canvas.drawCircle(
      Offset(housing.right - w * .10, housing.top + h * .10),
      w * .035,
      fill,
    );
    return true;
  }

  if (type == 'fuse_dc' || type == 'fuse_ac1' || type == 'fuse') {
    final Rect fuse = Rect.fromCenter(
      center: c,
      width: w * .52,
      height: h * .28,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(fuse, Radius.circular(h * .08)),
      stroke,
    );
    canvas.drawLine(
      Offset(fuse.left + w * .06, c.dy),
      Offset(fuse.right - w * .06, c.dy),
      stroke,
    );
    return true;
  }

  if (type == 'diode') {
    final Path triangle = Path()
      ..moveTo(c.dx - w * .18, c.dy - h * .25)
      ..lineTo(c.dx - w * .18, c.dy + h * .25)
      ..lineTo(c.dx + w * .10, c.dy)
      ..close();
    canvas.drawPath(triangle, stroke);
    canvas.drawLine(
      Offset(c.dx + w * .12, c.dy - h * .25),
      Offset(c.dx + w * .12, c.dy + h * .25),
      stroke,
    );
    return true;
  }

  if (type == 'relay_coil') {
    final Rect coilRect = Rect.fromCenter(
      center: c,
      width: w * .54,
      height: h * .50,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(coilRect, Radius.circular(h * .18)),
      stroke,
    );
    _paintLetter(canvas, c, 'K', color, h * .36);
    _paintLetter(
      canvas,
      Offset(rect.left + w * .08, rect.top + h * .06),
      'A1',
      color,
      h * .16,
    );
    _paintLetter(
      canvas,
      Offset(rect.right - w * .08, rect.bottom - h * .06),
      'A2',
      color,
      h * .16,
    );
    return true;
  }

  if (type == 'motor_dc' || type == 'fan_dc') {
    final double radius = rect.shortestSide * .34;
    canvas.drawCircle(c, radius, stroke);
    if (type == 'motor_dc') {
      _paintLetter(canvas, c, 'M', color, h * .42);
    } else {
      for (var i = 0; i < 3; i++) {
        final double angle = -math.pi / 2 + i * 2 * math.pi / 3;
        final Offset tip = Offset(
          c.dx + math.cos(angle) * radius * .82,
          c.dy + math.sin(angle) * radius * .82,
        );
        canvas.drawLine(c, tip, stroke);
        canvas.drawCircle(tip, radius * .16, stroke);
      }
    }
    return true;
  }

  if (type == 'buzzer') {
    final Path body = Path()
      ..moveTo(rect.left + w * .22, c.dy - h * .16)
      ..lineTo(c.dx - w * .02, c.dy - h * .16)
      ..lineTo(c.dx + w * .12, c.dy - h * .30)
      ..lineTo(c.dx + w * .12, c.dy + h * .30)
      ..lineTo(c.dx - w * .02, c.dy + h * .16)
      ..lineTo(rect.left + w * .22, c.dy + h * .16);
    canvas.drawPath(body, stroke);
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(c.dx + w * .20, c.dy),
        width: w * .24,
        height: h * .50,
      ),
      -math.pi / 3,
      2 * math.pi / 3,
      false,
      stroke,
    );
    return true;
  }

  if (type.contains('voltmeter') || type.contains('ammeter')) {
    canvas.drawCircle(c, rect.shortestSide * .34, stroke);
    _paintLetter(
      canvas,
      c,
      type.contains('ammeter') ? 'A' : 'V',
      color,
      h * .42,
    );
    return true;
  }

  if (type.contains('pv_panel') || type == 'pv_array') {
    final Rect panel = Rect.fromCenter(
      center: c,
      width: w * .62,
      height: h * .56,
    );
    canvas.drawRect(panel, stroke);
    for (final double ratio in <double>[.33, .66]) {
      canvas.drawLine(
        Offset(panel.left + panel.width * ratio, panel.top),
        Offset(panel.left + panel.width * ratio, panel.bottom),
        stroke,
      );
    }
    canvas.drawLine(
      Offset(panel.left, panel.center.dy),
      Offset(panel.right, panel.center.dy),
      stroke,
    );
    return true;
  }

  if (type.contains('inverter')) {
    final Rect box = Rect.fromCenter(
      center: c,
      width: w * .60,
      height: h * .54,
    );
    canvas.drawRect(box, stroke);
    canvas.drawLine(
      Offset(box.center.dx, box.top),
      Offset(box.center.dx, box.bottom),
      stroke,
    );
    canvas.drawLine(
      Offset(box.left + w * .08, c.dy),
      Offset(box.center.dx - w * .06, c.dy),
      stroke,
    );
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(box.right - w * .14, c.dy),
        width: w * .22,
        height: h * .26,
      ),
      -math.pi,
      math.pi,
      false,
      stroke,
    );
    return true;
  }

  return false;
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
