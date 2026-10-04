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

abstract final class F18ComponentIdentityMetrics {
  static const double aspectRatio = 104 / 64;
  static const Size paletteSize = Size(72, 44);
  static const Size dragSize = Size(104, 64);

  static Rect fit(Rect bounds) {
    if (bounds.isEmpty) return bounds;
    double width = bounds.width;
    double height = width / aspectRatio;
    if (height > bounds.height) {
      height = bounds.height;
      width = height * aspectRatio;
    }
    return Rect.fromCenter(
      center: bounds.center,
      width: width,
      height: height,
    );
  }
}

class F18ComponentIdentityVisual extends StatelessWidget {
  const F18ComponentIdentityVisual({
    super.key,
    required this.modelType,
    this.size = F18ComponentIdentityMetrics.paletteSize,
    this.active = true,
  });

  final String modelType;
  final Size size;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final Color color =
        active ? ElectroSimColors.primary : ElectroSimColors.textSecondary;
    return SizedBox(
      width: size.width,
      height: size.height,
      child: CustomPaint(
        painter: _F18IdentityPainter(
          modelType: modelType,
          foreground: color,
        ),
      ),
    );
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
    return F18ComponentIdentityVisual(
      modelType: modelType,
      size: Size(size * 1.45, size),
      active: active,
    );
  }
}

class _F18IdentityPainter extends CustomPainter {
  const _F18IdentityPainter({
    required this.modelType,
    required this.foreground,
  });

  final String modelType;
  final Color foreground;

  @override
  void paint(Canvas canvas, Size size) {
    paintF18ComponentIdentity(
      canvas,
      Offset.zero & size,
      modelType,
      foreground,
    );
  }

  @override
  bool shouldRepaint(_F18IdentityPainter oldDelegate) {
    return oldDelegate.modelType != modelType ||
        oldDelegate.foreground != foreground;
  }
}

void paintF18ComponentIdentity(
  Canvas canvas,
  Rect bounds,
  String modelType,
  Color foreground,
) {
  paintF18ElectricalArchetype(
    canvas,
    F18ComponentIdentityMetrics.fit(bounds),
    modelType,
    foreground,
  );
}

void paintF18ElectricalArchetype(
  Canvas canvas,
  Rect rect,
  String modelType,
  Color foreground,
) {
  final String normalizedType = modelType.toLowerCase();
  if (_paintIndustrialModel(
    canvas,
    rect,
    normalizedType,
    foreground,
  )) {
    return;
  }

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


bool _paintIndustrialModel(
  Canvas canvas,
  Rect rect,
  String type,
  Color foreground,
) {
  final Offset c = rect.center;
  final double w = rect.width;
  final double h = rect.height;
  final double lineWidth = math.max(1.5, rect.shortestSide * .035);
  final Paint outline = Paint()
    ..color = const Color(0xFF243447)
    ..strokeWidth = lineWidth
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;
  final Paint dark = Paint()
    ..color = const Color(0xFF263746)
    ..style = PaintingStyle.fill;
  final Paint metal = Paint()
    ..color = const Color(0xFFDCE3E8)
    ..style = PaintingStyle.fill;
  final Paint lightMetal = Paint()
    ..color = const Color(0xFFF3F6F8)
    ..style = PaintingStyle.fill;
  final Paint indicator = Paint()
    ..color = const Color(0xFF5FD79A)
    ..style = PaintingStyle.fill;
  final Paint amber = Paint()
    ..color = const Color(0xFFE7B25F)
    ..style = PaintingStyle.fill;

  void terminals({double radius = 5}) {
    final double r = math.max(3.0, radius * rect.shortestSide / 64);
    for (final Offset p in <Offset>[
      Offset(rect.left + r, c.dy),
      Offset(rect.right - r, c.dy),
    ]) {
      canvas.drawCircle(p, r, amber);
      canvas.drawCircle(p, r, outline);
    }
  }

  void leadToBody(Rect body) {
    canvas.drawLine(
      Offset(rect.left + 4, c.dy),
      Offset(body.left, c.dy),
      outline,
    );
    canvas.drawLine(
      Offset(body.right, c.dy),
      Offset(rect.right - 4, c.dy),
      outline,
    );
  }

  if (type == 'dc_voltage_source' || type == 'voltage_source') {
    final Rect body = Rect.fromCenter(
      center: c,
      width: w * .72,
      height: h * .72,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(body, Radius.circular(h * .10)),
      metal,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(body, Radius.circular(h * .10)),
      outline,
    );
    leadToBody(body);

    final Rect display = Rect.fromLTWH(
      body.left + body.width * .16,
      body.top + body.height * .16,
      body.width * .68,
      body.height * .30,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(display, Radius.circular(h * .05)),
      dark,
    );
    _paintLetter(
      canvas,
      display.center,
      '24 V',
      const Color(0xFF9BE1D1),
      math.max(8, h * .16),
    );
    canvas.drawCircle(
      Offset(body.left + body.width * .30, body.bottom - h * .13),
      h * .055,
      Paint()..color = const Color(0xFFD74E4E),
    );
    canvas.drawCircle(
      Offset(body.right - body.width * .30, body.bottom - h * .13),
      h * .055,
      Paint()..color = const Color(0xFF27313B),
    );
    terminals(radius: 4.7);
    return true;
  }

  if (type == 'switch' ||
      type == 'switch_spst' ||
      type == 'push_button_no') {
    final Rect body = Rect.fromCenter(
      center: c,
      width: w * .54,
      height: h * .72,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(body, Radius.circular(h * .11)),
      lightMetal,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(body, Radius.circular(h * .11)),
      outline,
    );
    leadToBody(body);

    if (type == 'push_button_no') {
      final double outerR = h * .22;
      canvas.drawCircle(c, outerR, dark);
      canvas.drawCircle(
        c.translate(0, -h * .025),
        outerR * .58,
        Paint()..color = const Color(0xFFEEF2F5),
      );
      canvas.drawCircle(c, outerR, outline);
      canvas.drawLine(
        Offset(c.dx - outerR * .85, body.bottom - h * .09),
        Offset(c.dx + outerR * .85, body.bottom - h * .09),
        outline,
      );
    } else {
      final Rect well = Rect.fromCenter(
        center: c,
        width: body.width * .42,
        height: body.height * .62,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(well, Radius.circular(h * .13)),
        dark,
      );
      final Rect rocker = Rect.fromCenter(
        center: Offset(c.dx, c.dy - h * .06),
        width: well.width * .72,
        height: well.height * .48,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rocker, Radius.circular(h * .08)),
        Paint()..color = const Color(0xFF71808D),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rocker, Radius.circular(h * .08)),
        outline,
      );
    }
    terminals(radius: 4.7);
    return true;
  }

  if (type == 'lamp') {
    final double bulbR = h * .29;
    final Offset bulb = Offset(c.dx, c.dy - h * .06);
    canvas.drawCircle(
      bulb,
      bulbR,
      Paint()..color = const Color(0xFFFFF2A8),
    );
    canvas.drawCircle(bulb, bulbR, outline);
    canvas.drawLine(
      bulb + Offset(-bulbR * .55, -bulbR * .55),
      bulb + Offset(bulbR * .55, bulbR * .55),
      outline,
    );
    canvas.drawLine(
      bulb + Offset(bulbR * .55, -bulbR * .55),
      bulb + Offset(-bulbR * .55, bulbR * .55),
      outline,
    );
    final Rect base = Rect.fromCenter(
      center: Offset(c.dx, rect.bottom - h * .15),
      width: w * .28,
      height: h * .17,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(base, Radius.circular(h * .04)),
      metal,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(base, Radius.circular(h * .04)),
      outline,
    );
    canvas.drawLine(
      Offset(rect.left + 4, c.dy),
      Offset(bulb.dx - bulbR, c.dy),
      outline,
    );
    canvas.drawLine(
      Offset(bulb.dx + bulbR, c.dy),
      Offset(rect.right - 4, c.dy),
      outline,
    );
    terminals(radius: 4.7);
    return true;
  }

  if (type == 'breaker_dc' ||
      type == 'breaker_ac1' ||
      type == 'breaker') {
    final Rect body = Rect.fromCenter(
      center: c,
      width: w * .56,
      height: h * .78,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(body, Radius.circular(h * .07)),
      metal,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(body, Radius.circular(h * .07)),
      outline,
    );
    final Rect toggle = Rect.fromCenter(
      center: Offset(c.dx, c.dy - h * .03),
      width: body.width * .18,
      height: body.height * .46,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(toggle, Radius.circular(h * .035)),
      dark,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(toggle, Radius.circular(h * .035)),
      outline,
    );
    canvas.drawCircle(
      Offset(c.dx, body.bottom - h * .10),
      h * .042,
      indicator,
    );
    _paintLetter(
      canvas,
      Offset(c.dx, body.top + h * .10),
      'Q',
      const Color(0xFF243447),
      math.max(8, h * .13),
    );
    leadToBody(body);
    terminals(radius: 4.7);
    return true;
  }

  if (type == 'fuse_dc' || type == 'fuse_ac1' || type == 'fuse') {
    final Rect tube = Rect.fromCenter(
      center: c,
      width: w * .55,
      height: h * .22,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(tube, Radius.circular(h * .08)),
      Paint()..color = const Color(0xFFD9F2F6),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(tube, Radius.circular(h * .08)),
      outline,
    );
    final double capW = w * .08;
    canvas.drawRect(
      Rect.fromLTWH(tube.left, tube.top, capW, tube.height),
      dark,
    );
    canvas.drawRect(
      Rect.fromLTWH(tube.right - capW, tube.top, capW, tube.height),
      dark,
    );
    canvas.drawLine(
      Offset(tube.left + capW, c.dy),
      Offset(tube.right - capW, c.dy),
      outline,
    );
    leadToBody(tube);
    terminals(radius: 4.7);
    return true;
  }

  if (type == 'resistor') {
    final Rect body = Rect.fromCenter(
      center: c,
      width: w * .50,
      height: h * .30,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(body, Radius.circular(h * .10)),
      Paint()..color = const Color(0xFFEAD7B2),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(body, Radius.circular(h * .10)),
      outline,
    );
    for (final double ratio in <double>[.28, .44, .60, .76]) {
      final double x = body.left + body.width * ratio;
      canvas.drawLine(
        Offset(x, body.top + 2),
        Offset(x, body.bottom - 2),
        Paint()
          ..color = const Color(0xFF8B5E3C)
          ..strokeWidth = math.max(2, w * .018),
      );
    }
    leadToBody(body);
    terminals(radius: 4.7);
    return true;
  }

  if (type == 'motor_dc' || type == 'fan_dc') {
    final Rect body = Rect.fromCenter(
      center: c,
      width: w * .55,
      height: h * .58,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(body, Radius.circular(h * .12)),
      Paint()..color = const Color(0xFFCBD6DD),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(body, Radius.circular(h * .12)),
      outline,
    );
    for (final double ratio in <double>[.22, .36, .50, .64, .78]) {
      final double x = body.left + body.width * ratio;
      canvas.drawLine(
        Offset(x, body.top + h * .06),
        Offset(x, body.bottom - h * .06),
        Paint()
          ..color = const Color(0xFF93A2AD)
          ..strokeWidth = 1.2,
      );
    }
    if (type == 'motor_dc') {
      _paintLetter(
        canvas,
        c,
        'M',
        const Color(0xFF243447),
        math.max(12, h * .28),
      );
    } else {
      final double r = h * .18;
      for (var i = 0; i < 3; i++) {
        final double angle = -math.pi / 2 + i * 2 * math.pi / 3;
        final Offset tip = Offset(
          c.dx + math.cos(angle) * r,
          c.dy + math.sin(angle) * r,
        );
        canvas.drawLine(c, tip, outline);
      }
    }
    leadToBody(body);
    terminals(radius: 4.7);
    return true;
  }

  if (type == 'relay_coil') {
    final Rect body = Rect.fromCenter(
      center: c,
      width: w * .52,
      height: h * .52,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(body, Radius.circular(h * .08)),
      Paint()..color = const Color(0xFFE8EEF2),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(body, Radius.circular(h * .08)),
      outline,
    );
    _paintLetter(
      canvas,
      c,
      'K',
      const Color(0xFF243447),
      math.max(12, h * .26),
    );
    _paintLetter(
      canvas,
      Offset(body.left + h * .09, body.top + h * .07),
      'A1',
      const Color(0xFF526575),
      math.max(6, h * .10),
    );
    _paintLetter(
      canvas,
      Offset(body.right - h * .09, body.bottom - h * .07),
      'A2',
      const Color(0xFF526575),
      math.max(6, h * .10),
    );
    leadToBody(body);
    terminals(radius: 4.7);
    return true;
  }

  return false;
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
