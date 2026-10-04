import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'reference_models.dart';

enum ReferenceDevice { supply, breaker, toggle, button, lamp }

// State is supplied by the simulation. Painting never advances physics.
@immutable
final class ReferenceVisualState {
  const ReferenceVisualState({
    this.closed = false,
    this.pressed = false,
    this.tripped = false,
    this.brightness = 0,
    this.temperatureK = 293.15,
    this.voltageV = 0,
    this.currentA = 0,
    this.supplyMode = SupplyMode.off,
    this.ratedCurrentA = 1,
  });
  final bool closed, pressed, tripped;
  final double brightness, temperatureK, voltageV, currentA, ratedCurrentA;
  final SupplyMode supplyMode;
}

class ReferenceComponentView extends StatelessWidget {
  const ReferenceComponentView({
    super.key,
    required this.device,
    this.state = const ReferenceVisualState(),
    this.width = 240,
    this.height = 160,
    this.quarterTurns = 0,
    this.showTerminals = true,
  });
  final ReferenceDevice device;
  final ReferenceVisualState state;
  final double width, height;
  final int quarterTurns;
  final bool showTerminals;

  // In the unrotated component rectangle; use this same transform for wires.
  static const leftTerminal = Offset(.045, .5);
  static const rightTerminal = Offset(.955, .5);

  static Offset terminalPosition(Size size, {required bool right, int quarterTurns = 0}) {
    final scale = math.min(size.width / 240, size.height / 160);
    final local = Offset(
      (size.width - 240 * scale) / 2 + (right ? 229.2 : 10.8) * scale,
      size.height / 2,
    );
    final center = Offset(size.width / 2, size.height / 2);
    final delta = local - center;
    final angle = (quarterTurns % 4) * math.pi / 2;
    return center + Offset(
      delta.dx * math.cos(angle) - delta.dy * math.sin(angle),
      delta.dx * math.sin(angle) + delta.dy * math.cos(angle),
    );
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: switch (device) {
      ReferenceDevice.supply =>
        'Alimentation ${state.voltageV.toStringAsFixed(2)} volts, '
        '${state.currentA.toStringAsFixed(3)} ampères, ${state.supplyMode.name}',
      ReferenceDevice.breaker => state.tripped ? 'Disjoncteur déclenché' :
        state.closed ? 'Disjoncteur fermé' : 'Disjoncteur ouvert',
      ReferenceDevice.toggle => state.closed ? 'Interrupteur fermé' : 'Interrupteur ouvert',
      ReferenceDevice.button => state.pressed ? 'Bouton appuyé' : 'Bouton relâché',
      ReferenceDevice.lamp => 'Lampe, luminosité ${(state.brightness * 100).round()} pour cent',
    },
    child: SizedBox(
      width: width, height: height,
      child: Transform.rotate(
        angle: (quarterTurns % 4) * math.pi / 2,
        child: CustomPaint(
          painter: _DevicePainter(device, state, showTerminals),
        ),
      ),
    ),
  );
}

class _DevicePainter extends CustomPainter {
  _DevicePainter(this.device, this.state, this.showTerminals);
  final ReferenceDevice device;
  final ReferenceVisualState state;
  final bool showTerminals;

  void _box(Canvas canvas, Rect rect, List<Color> colors,
      {double radius = 8, bool shadow = false}) {
    final shape = RRect.fromRectAndRadius(rect, Radius.circular(radius));
    if (shadow) {
      canvas.drawShadow(Path()..addRRect(shape), const Color(0x99000000), 5, true);
    }
    canvas.drawRRect(shape, Paint()..shader = LinearGradient(
      begin: Alignment.topLeft, end: Alignment.bottomRight, colors: colors,
    ).createShader(rect));
    canvas.drawRRect(shape, Paint()
      ..color = const Color(0x66000000)
      ..style = PaintingStyle.stroke
      ..strokeWidth = .8);
  }

  void _text(Canvas canvas, String value, Offset position,
      {double size = 9, Color color = const Color(0xFF263238)}) {
    final painter = TextPainter(
      text: TextSpan(text: value, style: TextStyle(
        fontSize: size, color: color, fontWeight: FontWeight.w600,
      )),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas, position);
  }

  void _screw(Canvas canvas, Offset center, {double radius = 5}) {
    canvas.drawCircle(center, radius, Paint()..shader = const LinearGradient(
      colors: [Color(0xFFF5F7F8), Color(0xFF66757D)],
      begin: Alignment.topLeft, end: Alignment.bottomRight,
    ).createShader(Rect.fromCircle(center: center, radius: radius)));
    canvas.drawLine(center + Offset(-radius * .65, radius * .3),
      center + Offset(radius * .65, -radius * .3),
      Paint()..color = const Color(0xFF34434C)..strokeWidth = 1.5);
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    canvas.save();
    // Uniform scaling preserves proportions and terminal positions.
    final scale = math.min(size.width / 240, size.height / 160);
    canvas.translate((size.width - 240 * scale) / 2,
        (size.height - 160 * scale) / 2);
    canvas.scale(scale);
    switch (device) {
      case ReferenceDevice.supply: _supply(canvas);
      case ReferenceDevice.breaker: _breaker(canvas);
      case ReferenceDevice.toggle: _toggle(canvas);
      case ReferenceDevice.button: _button(canvas);
      case ReferenceDevice.lamp: _lamp(canvas);
    }
    if (showTerminals) {
      for (final x in [10.8, 229.2]) {
        canvas.drawLine(Offset(x, 80), Offset(x < 120 ? 43 : 197, 80),
          Paint()..color = const Color(0xFF687C86)..strokeWidth = 3);
        _screw(canvas, Offset(x, 80), radius: 7);
      }
    }
    canvas.restore();
  }

  void _supply(Canvas c) {
    _box(c, const Rect.fromLTWH(37, 22, 166, 116),
      const [Color(0xFF58636D), Color(0xFF1A232C)], shadow: true);
    _box(c, const Rect.fromLTWH(47, 32, 146, 70),
      const [Color(0xFF10191D), Color(0xFF26393D)], radius: 3);
    const green = Color(0xFFB2FFD5);
    _text(c, '${state.voltageV.toStringAsFixed(2)} V', const Offset(59, 39),
      size: 20, color: green);
    _text(c, '${state.currentA.toStringAsFixed(3)} A', const Offset(59, 68),
      size: 17, color: green);
    for (var i = 0; i < 2; i++) {
      final active = i == 0 ? state.supplyMode == SupplyMode.constantVoltage :
          state.supplyMode == SupplyMode.constantCurrent;
      c.drawCircle(Offset(156 + i * 22, 117), 3,
        Paint()..color = active ? green : const Color(0xFF46514F));
      _text(c, i == 0 ? 'CV' : 'CC', Offset(150 + i * 22, 124),
        size: 7, color: Colors.white70);
    }
    _text(c, '+', const Offset(48, 107), size: 18, color: const Color(0xFFEF6C6C));
    _text(c, '−', const Offset(74, 107), size: 18, color: Colors.white);
    _text(c, 'CC • 24 V', const Offset(96, 111), size: 8, color: Colors.white70);
  }

  void _breaker(Canvas c) {
    _box(c, const Rect.fromLTWH(76, 15, 88, 132),
      const [Color(0xFFFCFCF7), Color(0xFFBABCB6)], radius: 5, shadow: true);
    for (final y in [23.0, 127.0]) {
      _box(c, Rect.fromLTWH(96, y, 48, 13),
        const [Color(0xFF737C7C), Color(0xFF2C3538)], radius: 2);
      _screw(c, Offset(120, y + 6));
    }
    _text(c, 'CC ${state.ratedCurrentA.toStringAsFixed(2)} A', const Offset(85, 41));
    _box(c, const Rect.fromLTWH(98, 60, 45, 42),
      const [Color(0xFF353D40), Color(0xFF11191D)], radius: 3);
    final y = state.tripped ? 74.0 : state.closed ? 62.0 : 86.0;
    _box(c, Rect.fromLTWH(102, y, 37, 15),
      state.tripped ? const [Color(0xFFFFB34A), Color(0xFFA55C13)] :
        const [Color(0xFF3C4853), Color(0xFF111923)], radius: 3);
    _text(c, state.tripped ? 'DÉCLENCHÉ' : state.closed ? 'I • ON' : 'O • OFF',
      const Offset(88, 109), size: 8);
    for (var x = 84.0; x < 98; x += 4) {
      c.drawLine(Offset(x, 63), Offset(x, 99),
        Paint()..color = const Color(0xFF939B99)..strokeWidth = 1);
    }
  }

  void _toggle(Canvas c) {
    _box(c, const Rect.fromLTWH(54, 34, 132, 92),
      const [Color(0xFFE3E6E6), Color(0xFF8C979C)], shadow: true);
    _screw(c, const Offset(66, 46));
    _screw(c, const Offset(174, 114));
    _box(c, const Rect.fromLTWH(92, 48, 56, 65),
      const [Color(0xFF0D1216), Color(0xFF39444B)], radius: 5);
    final y = state.closed ? 49.0 : 59.0;
    _box(c, Rect.fromLTWH(96, y, 48, 51),
      state.closed ? const [Color(0xFF9AA5A8), Color(0xFF28323B)] :
        const [Color(0xFF34404B), Color(0xFF929EA3)], radius: 4);
    _text(c, 'I', Offset(117, y + 7), color: Colors.white);
    _text(c, 'O', Offset(115, y + 32), color: Colors.white);
  }

  void _button(Canvas c) {
    _box(c, const Rect.fromLTWH(61, 24, 118, 112),
      const [Color(0xFFD7DEE0), Color(0xFF75848B)], shadow: true);
    final center = Offset(120, state.pressed ? 85 : 78);
    c.drawCircle(const Offset(120, 80), 42, Paint()..shader =
      const LinearGradient(colors: [Color(0xFFFBFFFF), Color(0xFF657780)])
        .createShader(const Rect.fromLTWH(78, 38, 84, 84)));
    c.drawCircle(center + const Offset(0, 3), 34,
      Paint()..color = const Color(0xFF123B2A));
    c.drawCircle(center, state.pressed ? 30 : 34, Paint()..shader =
      RadialGradient(center: const Alignment(-.4, -.5),
        colors: state.pressed ? const [Color(0xFF27915D), Color(0xFF12552D)] :
          const [Color(0xFF70E4A0), Color(0xFF157A42)])
        .createShader(Rect.fromCircle(center: center, radius: 34)));
    _text(c, 'NO • APPUI', const Offset(90, 123), size: 8);
  }

  void _lamp(Canvas c) {
    final b = state.brightness.clamp(0.0, 1.0).toDouble();
    final warmth = ((state.temperatureK - 900) / 1800).clamp(0.0, 1.0).toDouble();
    final light = Color.lerp(const Color(0xFFFF5722),
        const Color(0xFFFFF4C9), warmth)!;
    if (b > .001) {
      c.drawCircle(const Offset(120, 60), 58, Paint()..shader = RadialGradient(
        colors: [light.withValues(alpha: .45 * b), light.withValues(alpha: 0)],
      ).createShader(const Rect.fromLTWH(62, 2, 116, 116)));
    }
    _box(c, const Rect.fromLTWH(81, 118, 78, 25),
      const [Color(0xFF87959B), Color(0xFF33434C)], shadow: true);
    _box(c, const Rect.fromLTWH(102, 91, 36, 30),
      const [Color(0xFFE4D6A6), Color(0xFF756845)], radius: 4);
    for (var y = 95.0; y < 118; y += 5) {
      c.drawLine(Offset(104, y), Offset(136, y - 2),
        Paint()..color = const Color(0xFF5C594A)..strokeWidth = 2);
    }
    final bulb = Path()..moveTo(107, 96)
      ..cubicTo(110, 79, 79, 72, 83, 43)
      ..cubicTo(86, 3, 154, 3, 157, 43)
      ..cubicTo(161, 72, 130, 79, 133, 96)..close();
    c.drawPath(bulb, Paint()..shader = RadialGradient(
      colors: [light.withValues(alpha: .12 + .35 * b), const Color(0x224DB1CC)],
    ).createShader(const Rect.fromLTWH(80, 12, 80, 90)));
    c.drawPath(bulb, Paint()..color = const Color(0xFFB5D6DE)
      ..style = PaintingStyle.stroke..strokeWidth = 1.5);
    c.drawLine(const Offset(111, 96), const Offset(109, 61),
      Paint()..color = const Color(0xFF83959B)..strokeWidth = 1);
    c.drawLine(const Offset(129, 96), const Offset(131, 61),
      Paint()..color = const Color(0xFF83959B)..strokeWidth = 1);
    final filament = Path()..moveTo(109, 61);
    for (var i = 1; i <= 10; i++) {
      filament.lineTo(109 + i * 2.2, i.isEven ? 61 : 57);
    }
    c.drawPath(filament, Paint()..color = Color.lerp(
      const Color(0xFF685243), light, b)!
      ..style = PaintingStyle.stroke..strokeWidth = 1.8);
    c.drawArc(const Rect.fromLTWH(89, 20, 59, 55), math.pi, .9, false,
      Paint()..color = const Color(0xAAFFFFFF)
        ..style = PaintingStyle.stroke..strokeWidth = 3);
    _text(c, '24 V • 10 W', const Offset(89, 126), size: 8, color: Colors.white);
  }

  @override
  bool shouldRepaint(covariant _DevicePainter old) =>
      old.device != device || old.state != state || old.showTerminals != showTerminals;
}
