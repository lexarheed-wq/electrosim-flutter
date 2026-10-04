import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'reference_models.dart';

enum ReferenceDevice { supply, breaker, toggle, button, lamp }

/// Device-specific geometry shared by the drawing and connection anchors.
@immutable
final class ReferenceComponentGeometry {
  const ReferenceComponentGeometry(this.designSize, this.body, this.terminals);
  final Size designSize;
  final Rect body;
  final List<Offset> terminals;

  static ReferenceComponentGeometry forDevice(ReferenceDevice device) =>
      switch (device) {
        ReferenceDevice.supply => const ReferenceComponentGeometry(
          Size(140, 160), Rect.fromLTWH(6, 10, 128, 142),
          [Offset(42, 127), Offset(94, 127)],
        ),
        ReferenceDevice.breaker => const ReferenceComponentGeometry(
          Size(72, 160), Rect.fromLTWH(12, 8, 48, 144),
          [Offset(36, 23), Offset(36, 137)],
        ),
        ReferenceDevice.toggle => const ReferenceComponentGeometry(
          Size(90, 140), Rect.fromLTWH(10, 8, 70, 124),
          [Offset(45, 20), Offset(45, 120)],
        ),
        ReferenceDevice.button => const ReferenceComponentGeometry(
          Size(90, 140), Rect.fromLTWH(12, 8, 66, 124),
          [Offset(31, 119), Offset(59, 119)],
        ),
        ReferenceDevice.lamp => const ReferenceComponentGeometry(
          Size(130, 160), Rect.fromLTWH(26, 120, 78, 30),
          [Offset(40, 139), Offset(90, 139)],
        ),
      };
}

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
    this.width,
    this.height,
    this.quarterTurns = 0,
    this.showTerminals = true,
  });
  final ReferenceDevice device;
  final ReferenceVisualState state;
  final double? width, height;
  final int quarterTurns;
  final bool showTerminals;

  /// Returns an anchor in the actual OUTER widget rectangle, after rotation.
  /// Index 0/1 follows electrical terminal order, not left/right placement.
  static Offset terminalPosition(Size size, {
    required ReferenceDevice device,
    required int terminalIndex,
    int quarterTurns = 0,
  }) {
    if (size.isEmpty || !size.width.isFinite || !size.height.isFinite) {
      throw ArgumentError('Expected a finite, positive widget size.');
    }
    final geometry = ReferenceComponentGeometry.forDevice(device);
    if (terminalIndex < 0 || terminalIndex >= geometry.terminals.length) {
      throw RangeError.index(terminalIndex, geometry.terminals);
    }
    final turns = quarterTurns % 4;
    final base = turns.isOdd ? Size(size.height, size.width) : size;
    final scale = math.min(base.width / geometry.designSize.width,
        base.height / geometry.designSize.height);
    final anchor = geometry.terminals[terminalIndex];
    final local = Offset(
      (base.width - geometry.designSize.width * scale) / 2 + anchor.dx * scale,
      (base.height - geometry.designSize.height * scale) / 2 + anchor.dy * scale,
    );
    final center = Offset(size.width / 2, size.height / 2);
    final delta = local - Offset(base.width / 2, base.height / 2);
    final angle = turns * math.pi / 2;
    return center + Offset(
      delta.dx * math.cos(angle) - delta.dy * math.sin(angle),
      delta.dx * math.sin(angle) + delta.dy * math.cos(angle),
    );
  }

  /// Unit direction for a wire leaving the housing from this terminal.
  static Offset terminalExitDirection({
    required ReferenceDevice device,
    required int terminalIndex,
    int quarterTurns = 0,
  }) {
    if (terminalIndex < 0 || terminalIndex > 1) {
      throw RangeError.range(terminalIndex, 0, 1, 'terminalIndex');
    }
    final vertical = (device == ReferenceDevice.breaker ||
        device == ReferenceDevice.toggle) && terminalIndex == 0 ? -1.0 : 1.0;
    final angle = (quarterTurns % 4) * math.pi / 2;
    return Offset(-vertical * math.sin(angle), vertical * math.cos(angle));
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
    child: RotatedBox(
      quarterTurns: quarterTurns % 4,
      child: SizedBox(
        width: width ?? ReferenceComponentGeometry.forDevice(device).designSize.width,
        height: height ?? ReferenceComponentGeometry.forDevice(device).designSize.height,
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

  void _terminal(Canvas canvas, Offset center, {
    Color insulation = const Color(0xFF414B4F),
    double radius = 6,
  }) {
    canvas.drawCircle(center, radius + 2,
      Paint()..color = const Color(0x66000000));
    canvas.drawCircle(center, radius + 1, Paint()..color = insulation);
    _screw(canvas, center, radius: radius - 1);
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    canvas.save();
    // Uniform scaling preserves proportions and terminal positions.
    final geometry = ReferenceComponentGeometry.forDevice(device);
    final scale = math.min(size.width / geometry.designSize.width,
        size.height / geometry.designSize.height);
    canvas.translate((size.width - geometry.designSize.width * scale) / 2,
        (size.height - geometry.designSize.height * scale) / 2);
    canvas.scale(scale);
    switch (device) {
      case ReferenceDevice.supply: _supply(canvas);
      case ReferenceDevice.breaker: _breaker(canvas);
      case ReferenceDevice.toggle: _toggle(canvas);
      case ReferenceDevice.button: _button(canvas);
      case ReferenceDevice.lamp: _lamp(canvas);
    }
    if (showTerminals) {
      for (var i = 0; i < geometry.terminals.length; i++) {
        _terminal(canvas, geometry.terminals[i],
          insulation: device == ReferenceDevice.supply && i == 0
              ? const Color(0xFFC94747) : const Color(0xFF414B4F));
      }
    }
    canvas.restore();
  }

  void _supply(Canvas c) {
    _box(c, ReferenceComponentGeometry.forDevice(device).body,
      const [Color(0xFF58636D), Color(0xFF1A232C)], shadow: true);
    _box(c, const Rect.fromLTWH(16, 22, 108, 65),
      const [Color(0xFF10191D), Color(0xFF26393D)], radius: 3);
    const green = Color(0xFFB2FFD5);
    _text(c, '${state.voltageV.toStringAsFixed(2)} V', const Offset(24, 29),
      size: 18, color: green);
    _text(c, '${state.currentA.toStringAsFixed(3)} A', const Offset(24, 57),
      size: 16, color: green);
    for (var i = 0; i < 2; i++) {
      final active = i == 0 ? state.supplyMode == SupplyMode.constantVoltage :
          state.supplyMode == SupplyMode.constantCurrent;
      c.drawCircle(Offset(42 + i * 52, 99), 3,
        Paint()..color = active ? green : const Color(0xFF46514F));
      _text(c, i == 0 ? 'CV' : 'CC', Offset(48 + i * 52, 95),
        size: 7, color: Colors.white70);
    }
    _text(c, '+', const Offset(38, 107), size: 12, color: const Color(0xFFEF6C6C));
    _text(c, '−', const Offset(90, 107), size: 12, color: Colors.white);
    _text(c, 'SORTIE CC', const Offset(45, 141), size: 7, color: Colors.white70);
  }

  void _breaker(Canvas c) {
    _box(c, ReferenceComponentGeometry.forDevice(device).body,
      const [Color(0xFFFCFCF7), Color(0xFFBABCB6)], radius: 5, shadow: true);
    for (final y in [14.0, 128.0]) {
      _box(c, Rect.fromLTWH(24, y, 24, 18),
        const [Color(0xFF737C7C), Color(0xFF2C3538)], radius: 2);
    }
    _text(c, 'CC', const Offset(28, 38), size: 8);
    _text(c, '${state.ratedCurrentA.toStringAsFixed(2)} A', const Offset(20, 49), size: 8);
    _box(c, const Rect.fromLTWH(23, 66, 26, 36),
      const [Color(0xFF353D40), Color(0xFF11191D)], radius: 3);
    final y = state.tripped ? 78.0 : state.closed ? 67.0 : 88.0;
    _box(c, Rect.fromLTWH(25, y, 22, 12),
      state.tripped ? const [Color(0xFFFFB34A), Color(0xFFA55C13)] :
        const [Color(0xFF3C4853), Color(0xFF111923)], radius: 3);
    _text(c, state.tripped ? 'TRIP' : state.closed ? 'I • ON' : 'O • OFF',
      const Offset(23, 111), size: 7);
    for (var x = 15.0; x < 22; x += 3) {
      c.drawLine(Offset(x, 67), Offset(x, 99),
        Paint()..color = const Color(0xFF939B99)..strokeWidth = 1);
    }
  }

  void _toggle(Canvas c) {
    _box(c, ReferenceComponentGeometry.forDevice(device).body,
      const [Color(0xFFE3E6E6), Color(0xFF8C979C)], shadow: true);
    _box(c, const Rect.fromLTWH(32, 12, 26, 16),
      const [Color(0xFFB4A778), Color(0xFF716340)], radius: 2);
    _box(c, const Rect.fromLTWH(32, 112, 26, 16),
      const [Color(0xFFB4A778), Color(0xFF716340)], radius: 2);
    _box(c, const Rect.fromLTWH(23, 35, 44, 69),
      const [Color(0xFF0D1216), Color(0xFF39444B)], radius: 5);
    final y = state.closed ? 37.0 : 47.0;
    _box(c, Rect.fromLTWH(27, y, 36, 53),
      state.closed ? const [Color(0xFF9AA5A8), Color(0xFF28323B)] :
        const [Color(0xFF34404B), Color(0xFF929EA3)], radius: 4);
    _text(c, 'I', Offset(43, y + 7), color: Colors.white);
    _text(c, 'O', Offset(41, y + 34), color: Colors.white);
  }

  void _button(Canvas c) {
    _box(c, ReferenceComponentGeometry.forDevice(device).body,
      const [Color(0xFFD7DEE0), Color(0xFF75848B)], shadow: true);
    _box(c, const Rect.fromLTWH(20, 104, 50, 24),
      const [Color(0xFF3C4446), Color(0xFF22282B)], radius: 3);
    final center = Offset(45, state.pressed ? 61 : 56);
    c.drawCircle(const Offset(45, 58), 29, Paint()..shader =
      const LinearGradient(colors: [Color(0xFFFBFFFF), Color(0xFF657780)])
        .createShader(const Rect.fromLTWH(16, 29, 58, 58)));
    c.drawCircle(center + const Offset(0, 3), 23,
      Paint()..color = const Color(0xFF123B2A));
    c.drawCircle(center, state.pressed ? 21 : 23, Paint()..shader =
      RadialGradient(center: const Alignment(-.4, -.5),
        colors: state.pressed ? const [Color(0xFF27915D), Color(0xFF12552D)] :
          const [Color(0xFF70E4A0), Color(0xFF157A42)])
        .createShader(Rect.fromCircle(center: center, radius: 23)));
    _text(c, 'NO', const Offset(39, 91), size: 8);
    _text(c, '13', const Offset(27, 105), size: 6, color: Colors.white70);
    _text(c, '14', const Offset(55, 105), size: 6, color: Colors.white70);
  }

  void _lamp(Canvas c) {
    c.save();
    c.translate(-55, 0);
    final b = state.brightness.clamp(0.0, 1.0).toDouble();
    final warmth = ((state.temperatureK - 900) / 1800).clamp(0.0, 1.0).toDouble();
    final light = Color.lerp(const Color(0xFFFF5722),
        const Color(0xFFFFF4C9), warmth)!;
    if (b > .001) {
      c.drawCircle(const Offset(120, 60), 58, Paint()..shader = RadialGradient(
        colors: [light.withValues(alpha: .45 * b), light.withValues(alpha: 0)],
      ).createShader(const Rect.fromLTWH(62, 2, 116, 116)));
    }
    _box(c, const Rect.fromLTWH(81, 120, 78, 30),
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
    _text(c, '24 V • 10 W', const Offset(95, 123), size: 7, color: Colors.white);
    c.restore();
  }

  @override
  bool shouldRepaint(covariant _DevicePainter old) =>
      old.device != device || old.state != state || old.showTerminals != showTerminals;
}
