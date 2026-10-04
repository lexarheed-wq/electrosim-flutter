import 'dart:math' as math;

import 'package:flutter/material.dart';

enum ExtendedReferenceDevice {
  resistor,
  pushButtonNc,
  buzzer,
  fuse,
  diode,
  fan,
  motor,
  relayCoil,
}

@immutable
final class ExtendedReferenceVisualState {
  const ExtendedReferenceVisualState({
    this.pressed = false,
    this.active = false,
    this.blown = false,
    this.forwardBiased = false,
    this.speedFraction = 0,
    this.speedRpm = 0,
    this.energized = false,
    this.currentA = 0,
    this.voltageV = 0,
    this.resistanceOhm = 0,
  });

  final bool pressed;
  final bool active;
  final bool blown;
  final bool forwardBiased;
  final double speedFraction;
  final double speedRpm;
  final bool energized;
  final double currentA;
  final double voltageV;
  final double resistanceOhm;
}

abstract final class ExtendedReferenceGeometry {
  static Size designSizeFor(ExtendedReferenceDevice device) => switch (device) {
        ExtendedReferenceDevice.resistor => const Size(280, 110),
        ExtendedReferenceDevice.pushButtonNc => const Size(180, 180),
        ExtendedReferenceDevice.buzzer => const Size(190, 190),
        ExtendedReferenceDevice.fuse => const Size(300, 110),
        ExtendedReferenceDevice.diode => const Size(270, 105),
        ExtendedReferenceDevice.fan => const Size(210, 210),
        ExtendedReferenceDevice.motor => const Size(230, 190),
        ExtendedReferenceDevice.relayCoil => const Size(190, 230),
      };

  static Size displaySizeFor(ExtendedReferenceDevice device) =>
      designSizeFor(device);

  static Offset terminalOffset(
    ExtendedReferenceDevice device, {
    required bool right,
  }) {
    final Size s = designSizeFor(device);
    final double inset = switch (device) {
      ExtendedReferenceDevice.resistor => 8,
      ExtendedReferenceDevice.pushButtonNc => 10,
      ExtendedReferenceDevice.buzzer => 10,
      ExtendedReferenceDevice.fuse => 8,
      ExtendedReferenceDevice.diode => 8,
      ExtendedReferenceDevice.fan => 10,
      ExtendedReferenceDevice.motor => 10,
      ExtendedReferenceDevice.relayCoil => 10,
    };
    return Offset(right ? s.width - inset : inset, s.height / 2);
  }
}

class ExtendedReferenceComponentView extends StatelessWidget {
  const ExtendedReferenceComponentView({
    super.key,
    required this.device,
    this.state = const ExtendedReferenceVisualState(),
    this.showTerminals = true,
    this.quarterTurns = 0,
    this.width,
    this.height,
  });

  final ExtendedReferenceDevice device;
  final ExtendedReferenceVisualState state;
  final bool showTerminals;
  final int quarterTurns;
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final Size design = ExtendedReferenceGeometry.displaySizeFor(device);
    return Semantics(
      label: switch (device) {
        ExtendedReferenceDevice.resistor =>
          'Résistance ${state.resistanceOhm.toStringAsFixed(0)} ohms',
        ExtendedReferenceDevice.pushButtonNc =>
          state.pressed ? 'Bouton normalement fermé appuyé, contact ouvert' : 'Bouton normalement fermé relâché, contact fermé',
        ExtendedReferenceDevice.buzzer =>
          state.active ? 'Buzzer actif' : 'Buzzer inactif',
        ExtendedReferenceDevice.fuse =>
          state.blown ? 'Fusible fondu' : 'Fusible intact',
        ExtendedReferenceDevice.diode =>
          state.forwardBiased ? 'Diode polarisée en direct' : 'Diode bloquée',
        ExtendedReferenceDevice.fan =>
          'Ventilateur ${(state.speedFraction * 100).round()} pour cent',
        ExtendedReferenceDevice.motor =>
          'Moteur ${state.speedRpm.round()} tours par minute',
        ExtendedReferenceDevice.relayCoil =>
          state.energized ? 'Bobine de relais alimentée' : 'Bobine de relais au repos',
      },
      child: SizedBox(
        width: width ?? design.width,
        height: height ?? design.height,
        child: Transform.rotate(
          angle: (quarterTurns % 4) * math.pi / 2,
          child: CustomPaint(
            painter: _ExtendedReferencePainter(
              device,
              state,
              showTerminals,
            ),
          ),
        ),
      ),
    );
  }
}

class _ExtendedReferencePainter extends CustomPainter {
  const _ExtendedReferencePainter(
    this.device,
    this.state,
    this.showTerminals,
  );

  final ExtendedReferenceDevice device;
  final ExtendedReferenceVisualState state;
  final bool showTerminals;

  Paint _stroke({
    Color color = const Color(0xFF33434C),
    double width = 1.4,
  }) =>
      Paint()
        ..color = color
        ..strokeWidth = width
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

  Paint _linear(Rect rect, List<Color> colors,
      {Alignment begin = Alignment.topLeft,
      Alignment end = Alignment.bottomRight}) {
    return Paint()
      ..shader = LinearGradient(
        begin: begin,
        end: end,
        colors: colors,
      ).createShader(rect);
  }

  void _box(
    Canvas canvas,
    Rect rect,
    List<Color> colors, {
    double radius = 8,
    bool shadow = false,
  }) {
    final RRect rr = RRect.fromRectAndRadius(rect, Radius.circular(radius));
    if (shadow) {
      canvas.drawShadow(
        Path()..addRRect(rr),
        const Color(0x88000000),
        5,
        true,
      );
    }
    canvas.drawRRect(rr, _linear(rect, colors));
    canvas.drawRRect(
      rr,
      _stroke(color: const Color(0x66000000), width: .9),
    );
  }

  void _text(
    Canvas canvas,
    String value,
    Offset position, {
    double size = 10,
    Color color = const Color(0xFF263238),
    FontWeight weight = FontWeight.w600,
  }) {
    final TextPainter tp = TextPainter(
      text: TextSpan(
        text: value,
        style: TextStyle(
          fontSize: size,
          color: color,
          fontWeight: weight,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, position);
  }

  void _screw(Canvas canvas, Offset center, {double radius = 6}) {
    final Rect r = Rect.fromCircle(center: center, radius: radius);
    canvas.drawCircle(
      center,
      radius,
      _linear(
        r,
        const <Color>[
          Color(0xFFF7F8F8),
          Color(0xFFB7C2C6),
          Color(0xFF63747B),
        ],
      ),
    );
    canvas.drawCircle(
      center,
      radius,
      _stroke(color: const Color(0xFF46555C), width: .9),
    );
    canvas.drawLine(
      center + Offset(-radius * .62, radius * .28),
      center + Offset(radius * .62, -radius * .28),
      _stroke(color: const Color(0xFF46555C), width: 1.4),
    );
  }

  void _terminal(Canvas canvas, Offset center, Offset bodyEdge) {
    canvas.drawLine(
      center,
      bodyEdge,
      Paint()
        ..color = const Color(0xFF6C7E86)
        ..strokeWidth = 3.2
        ..strokeCap = StrokeCap.square,
    );
    _screw(canvas, center, radius: 7);
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final Size design = ExtendedReferenceGeometry.designSizeFor(device);
    final double scale =
        math.min(size.width / design.width, size.height / design.height);

    canvas.save();
    canvas.translate(
      (size.width - design.width * scale) / 2,
      (size.height - design.height * scale) / 2,
    );
    canvas.scale(scale);

    switch (device) {
      case ExtendedReferenceDevice.resistor:
        _paintResistor(canvas, design);
      case ExtendedReferenceDevice.pushButtonNc:
        _paintPushButtonNc(canvas, design);
      case ExtendedReferenceDevice.buzzer:
        _paintBuzzer(canvas, design);
      case ExtendedReferenceDevice.fuse:
        _paintFuse(canvas, design);
      case ExtendedReferenceDevice.diode:
        _paintDiode(canvas, design);
      case ExtendedReferenceDevice.fan:
        _paintFan(canvas, design);
      case ExtendedReferenceDevice.motor:
        _paintMotor(canvas, design);
      case ExtendedReferenceDevice.relayCoil:
        _paintRelayCoil(canvas, design);
    }

    canvas.restore();
  }

  void _paintResistor(Canvas c, Size s) {
    final Offset left =
        ExtendedReferenceGeometry.terminalOffset(device, right: false);
    final Offset right =
        ExtendedReferenceGeometry.terminalOffset(device, right: true);
    const Rect body = Rect.fromLTWH(69, 28, 142, 54);

    if (showTerminals) {
      _terminal(c, left, Offset(body.left, s.height / 2));
      _terminal(c, right, Offset(body.right, s.height / 2));
    }

    _box(
      c,
      body,
      const <Color>[
        Color(0xFFE5D2A1),
        Color(0xFFC6A86C),
        Color(0xFF9C7E48),
      ],
      radius: 25,
      shadow: true,
    );

    final List<Color> bands = <Color>[
      const Color(0xFF6D3B18),
      const Color(0xFF111111),
      const Color(0xFFD33A31),
      const Color(0xFFD6A832),
    ];
    final List<double> xs = <double>[94, 118, 142, 177];
    for (var i = 0; i < xs.length; i++) {
      c.drawRect(
        Rect.fromLTWH(xs[i], 31, 9, 48),
        Paint()..color = bands[i],
      );
    }
    c.drawOval(
      const Rect.fromLTWH(76, 35, 25, 12),
      Paint()..color = const Color(0x44FFFFFF),
    );
    _text(
      c,
      state.resistanceOhm > 0
          ? '${state.resistanceOhm.toStringAsFixed(0)} Ω'
          : 'R',
      const Offset(112, 86),
      size: 9,
      color: const Color(0xFF59492E),
    );
  }

  void _paintPushButtonNc(Canvas c, Size s) {
    final Offset left =
        ExtendedReferenceGeometry.terminalOffset(device, right: false);
    final Offset right =
        ExtendedReferenceGeometry.terminalOffset(device, right: true);
    const Offset center = Offset(90, 88);
    const double bezelR = 55;

    if (showTerminals) {
      _terminal(c, left, const Offset(35, 90));
      _terminal(c, right, const Offset(145, 90));
    }

    final Rect bezel = Rect.fromCircle(center: center, radius: bezelR);
    c.drawCircle(
      center,
      bezelR,
      _linear(
        bezel,
        const <Color>[
          Color(0xFFF7F9F9),
          Color(0xFFC4CDD0),
          Color(0xFF68787F),
        ],
      ),
    );
    c.drawCircle(
      center,
      bezelR,
      _stroke(color: const Color(0xFF53636A), width: 1.3),
    );
    c.drawCircle(
      center,
      46,
      Paint()..color = const Color(0xFF343B3F),
    );

    final Offset capCenter =
        Offset(center.dx, center.dy + (state.pressed ? 6 : 0));
    final double capR = state.pressed ? 34 : 39;
    final Rect cap = Rect.fromCircle(center: capCenter, radius: capR);
    c.drawCircle(
      capCenter,
      capR,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-.35, -.4),
          colors: <Color>[
            Color(0xFFFF7C70),
            Color(0xFFD93A32),
            Color(0xFF7B1614),
          ],
        ).createShader(cap),
    );
    c.drawCircle(
      capCenter,
      capR,
      _stroke(color: const Color(0xFF6D1513), width: 1.3),
    );
    c.drawCircle(
      capCenter + const Offset(-12, -14),
      7,
      Paint()..color = const Color(0x44FFFFFF),
    );
    _text(c, 'NC', const Offset(80, 151), size: 11);
  }

  void _paintBuzzer(Canvas c, Size s) {
    final Offset left =
        ExtendedReferenceGeometry.terminalOffset(device, right: false);
    final Offset right =
        ExtendedReferenceGeometry.terminalOffset(device, right: true);
    const Offset center = Offset(95, 94);
    const double r = 63;

    if (showTerminals) {
      _terminal(c, left, const Offset(31, 95));
      _terminal(c, right, const Offset(159, 95));
    }

    final Rect face = Rect.fromCircle(center: center, radius: r);
    c.drawCircle(
      center,
      r,
      _linear(
        face,
        const <Color>[
          Color(0xFF4D555A),
          Color(0xFF20272B),
          Color(0xFF0C1012),
        ],
      ),
    );
    c.drawCircle(center, r, _stroke(color: const Color(0xFF090C0E), width: 1.4));

    c.drawCircle(
      center,
      42,
      Paint()..color = const Color(0xFF11171A),
    );
    for (var angle = 0.0; angle < math.pi * 2; angle += math.pi / 5) {
      final Offset p = center + Offset(math.cos(angle), math.sin(angle)) * 22;
      c.drawCircle(
        p,
        4.2,
        Paint()..color = const Color(0xFF5B666B),
      );
    }
    c.drawCircle(center, 6, Paint()..color = const Color(0xFF69777C));

    if (state.active) {
      for (final double radius in <double>[73, 82]) {
        c.drawArc(
          Rect.fromCircle(center: center, radius: radius),
          -.65,
          1.3,
          false,
          _stroke(color: const Color(0xAA23A6D5), width: 2),
        );
      }
    }
    _text(c, '24 V', const Offset(79, 160), size: 10, color: const Color(0xFF424E54));
  }

  void _paintFuse(Canvas c, Size s) {
    final Offset left =
        ExtendedReferenceGeometry.terminalOffset(device, right: false);
    final Offset right =
        ExtendedReferenceGeometry.terminalOffset(device, right: true);

    const Rect glass = Rect.fromLTWH(77, 31, 146, 48);
    const Rect leftCap = Rect.fromLTWH(54, 27, 28, 56);
    const Rect rightCap = Rect.fromLTWH(218, 27, 28, 56);

    if (showTerminals) {
      _terminal(c, left, const Offset(54, 55));
      _terminal(c, right, const Offset(246, 55));
    }

    _box(
      c,
      leftCap,
      const <Color>[
        Color(0xFFF1F4F5),
        Color(0xFFADB8BC),
        Color(0xFF65747A),
      ],
      radius: 4,
      shadow: true,
    );
    _box(
      c,
      rightCap,
      const <Color>[
        Color(0xFFF1F4F5),
        Color(0xFFADB8BC),
        Color(0xFF65747A),
      ],
      radius: 4,
      shadow: true,
    );

    c.drawRRect(
      RRect.fromRectAndRadius(glass, const Radius.circular(19)),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            Color(0x99E8FAFF),
            Color(0x44B9DCE4),
            Color(0x88FFFFFF),
          ],
        ).createShader(glass),
    );
    c.drawRRect(
      RRect.fromRectAndRadius(glass, const Radius.circular(19)),
      _stroke(color: const Color(0xFF8DA9B0), width: 1.2),
    );

    if (state.blown) {
      c.drawLine(
        const Offset(90, 55),
        const Offset(139, 50),
        _stroke(color: const Color(0xFF756050), width: 2),
      );
      c.drawLine(
        const Offset(161, 60),
        const Offset(211, 55),
        _stroke(color: const Color(0xFF756050), width: 2),
      );
      c.drawCircle(
        const Offset(150, 55),
        8,
        Paint()..color = const Color(0x337B2B1F),
      );
    } else {
      c.drawLine(
        const Offset(82, 55),
        const Offset(218, 55),
        _stroke(color: const Color(0xFF7A5943), width: 2.2),
      );
    }
    _text(c, state.blown ? 'FONDU' : '1 A', const Offset(133, 88), size: 9);
  }

  void _paintDiode(Canvas c, Size s) {
    final Offset left =
        ExtendedReferenceGeometry.terminalOffset(device, right: false);
    final Offset right =
        ExtendedReferenceGeometry.terminalOffset(device, right: true);

    const Rect body = Rect.fromLTWH(80, 27, 110, 51);
    if (showTerminals) {
      _terminal(c, left, const Offset(80, 52.5));
      _terminal(c, right, const Offset(190, 52.5));
    }

    _box(
      c,
      body,
      state.forwardBiased
          ? const <Color>[
              Color(0xFF444B50),
              Color(0xFF121719),
              Color(0xFF263238),
            ]
          : const <Color>[
              Color(0xFF30363A),
              Color(0xFF0C1012),
              Color(0xFF1A2023),
            ],
      radius: 24,
      shadow: true,
    );
    c.drawRect(
      const Rect.fromLTWH(162, 29, 10, 47),
      Paint()..color = const Color(0xFFD8DEE0),
    );
    c.drawOval(
      const Rect.fromLTWH(91, 34, 36, 11),
      Paint()..color = const Color(0x33FFFFFF),
    );
    _text(c, 'K', const Offset(164, 82), size: 9);
    _text(c, 'A', const Offset(92, 82), size: 9);
  }

  void _paintFan(Canvas c, Size s) {
    final Offset left =
        ExtendedReferenceGeometry.terminalOffset(device, right: false);
    final Offset right =
        ExtendedReferenceGeometry.terminalOffset(device, right: true);

    const Rect frame = Rect.fromLTWH(29, 29, 152, 152);
    if (showTerminals) {
      _terminal(c, left, const Offset(29, 105));
      _terminal(c, right, const Offset(181, 105));
    }

    _box(
      c,
      frame,
      const <Color>[
        Color(0xFF3A4247),
        Color(0xFF161D21),
        Color(0xFF080B0D),
      ],
      radius: 12,
      shadow: true,
    );

    for (final Offset p in const <Offset>[
      Offset(43, 43),
      Offset(167, 43),
      Offset(43, 167),
      Offset(167, 167),
    ]) {
      _screw(c, p, radius: 5);
    }

    const Offset center = Offset(105, 105);
    c.drawCircle(
      center,
      62,
      Paint()..color = const Color(0xFF0E1417),
    );
    c.drawCircle(
      center,
      18,
      Paint()..color = const Color(0xFF4E5C62),
    );

    final double phase = state.speedFraction * math.pi / 7;
    c.save();
    c.translate(center.dx, center.dy);
    c.rotate(phase);
    for (var i = 0; i < 7; i++) {
      c.save();
      c.rotate(i * math.pi * 2 / 7);
      final Path blade = Path()
        ..moveTo(7, -7)
        ..cubicTo(35, -21, 60, -8, 61, 4)
        ..cubicTo(40, 9, 24, 11, 8, 8)
        ..close();
      c.drawPath(
        blade,
        _linear(
          const Rect.fromLTWH(0, -25, 65, 45),
          const <Color>[
            Color(0xFF66757B),
            Color(0xFF263238),
            Color(0xFF11171A),
          ],
        ),
      );
      c.restore();
    }
    c.restore();

    c.drawCircle(center, 12, Paint()..color = const Color(0xFF78868C));
    _text(
      c,
      '${(state.speedFraction * 100).clamp(0, 100).round()} %',
      const Offset(92, 187),
      size: 9,
    );
  }

  void _paintMotor(Canvas c, Size s) {
    final Offset left =
        ExtendedReferenceGeometry.terminalOffset(device, right: false);
    final Offset right =
        ExtendedReferenceGeometry.terminalOffset(device, right: true);
    const Offset center = Offset(116, 91);

    if (showTerminals) {
      _terminal(c, left, const Offset(43, 95));
      _terminal(c, right, const Offset(189, 95));
    }

    final Rect shell = Rect.fromCircle(center: center, radius: 68);
    c.drawCircle(
      center,
      68,
      _linear(
        shell,
        const <Color>[
          Color(0xFFE8ECEE),
          Color(0xFF9AA8AD),
          Color(0xFF53636A),
        ],
      ),
    );
    c.drawCircle(center, 68, _stroke(color: const Color(0xFF53636A), width: 1.4));

    c.drawCircle(
      center,
      49,
      Paint()..color = const Color(0xFF303A3F),
    );

    for (var i = 0; i < 10; i++) {
      final double a = i * math.pi * 2 / 10;
      final Offset p = center + Offset(math.cos(a), math.sin(a)) * 38;
      c.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: p, width: 7, height: 19),
          const Radius.circular(3),
        ),
        Paint()..color = const Color(0xFF6E7D82),
      );
    }

    final double phase =
        (state.speedRpm.abs() / 3000).clamp(0.0, 1.0) * math.pi / 2;
    c.save();
    c.translate(center.dx, center.dy);
    c.rotate(phase);
    c.drawRect(
      const Rect.fromLTWH(-5, -47, 10, 94),
      Paint()..color = const Color(0xFFC4CDD0),
    );
    c.restore();

    c.drawCircle(
      center,
      17,
      _linear(
        Rect.fromCircle(center: center, radius: 17),
        const <Color>[
          Color(0xFFF7F8F8),
          Color(0xFFB5C0C4),
          Color(0xFF687980),
        ],
      ),
    );
    c.drawCircle(center, 6, Paint()..color = const Color(0xFF424E54));

    _text(c, 'M', const Offset(109, 84), size: 12, color: Colors.white);
    _text(c, '24 V CC', const Offset(88, 163), size: 9);
  }

  void _paintRelayCoil(Canvas c, Size s) {
    final Offset left =
        ExtendedReferenceGeometry.terminalOffset(device, right: false);
    final Offset right =
        ExtendedReferenceGeometry.terminalOffset(device, right: true);

    const Rect body = Rect.fromLTWH(35, 24, 120, 182);
    if (showTerminals) {
      _terminal(c, left, const Offset(35, 115));
      _terminal(c, right, const Offset(155, 115));
    }

    _box(
      c,
      body,
      const <Color>[
        Color(0xFFDDE9ED),
        Color(0xFF9CB8C2),
        Color(0xFF5E7780),
      ],
      radius: 7,
      shadow: true,
    );

    final Rect window = const Rect.fromLTWH(52, 50, 86, 91);
    _box(
      c,
      window,
      const <Color>[
        Color(0xFF263238),
        Color(0xFF11191D),
      ],
      radius: 5,
    );

    for (var x = 60.0; x <= 130; x += 7) {
      c.drawLine(
        Offset(x, 59),
        Offset(x, 131),
        _stroke(
          color: state.energized
              ? const Color(0xFFF09A4A)
              : const Color(0xFFB46A32),
          width: 3,
        ),
      );
    }

    final Rect core = const Rect.fromLTWH(87, 55, 16, 80);
    c.drawRect(
      core,
      _linear(
        core,
        const <Color>[
          Color(0xFFE2E7E8),
          Color(0xFF788A91),
        ],
      ),
    );

    if (state.energized) {
      c.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(47, 45, 96, 101),
          const Radius.circular(8),
        ),
        _stroke(color: const Color(0xAA43C777), width: 3),
      );
    }

    _screw(c, const Offset(57, 176), radius: 6);
    _screw(c, const Offset(133, 176), radius: 6);
    _text(c, 'A1', const Offset(47, 190), size: 8);
    _text(c, 'A2', const Offset(126, 190), size: 8);
    _text(c, '24 V CC', const Offset(72, 31), size: 9);
  }

  @override
  bool shouldRepaint(covariant _ExtendedReferencePainter oldDelegate) =>
      oldDelegate.device != device ||
      oldDelegate.state != state ||
      oldDelegate.showTerminals != showTerminals;
}
