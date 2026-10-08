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

enum ExtendedDiodeVisualPackage { rectifier, schottky, led, zenerGlass, tvs }

abstract final class ExtendedReferenceVisualIdentity {
  static ExtendedDiodeVisualPackage diodePackage(String? variantKey) =>
      switch (variantKey) {
        'schottky' => ExtendedDiodeVisualPackage.schottky,
        'led-red' || 'led-green' => ExtendedDiodeVisualPackage.led,
        'zener' => ExtendedDiodeVisualPackage.zenerGlass,
        'tvs' => ExtendedDiodeVisualPackage.tvs,
        _ => ExtendedDiodeVisualPackage.rectifier,
      };
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
    this.animationValue = 0,
    this.variantKey,
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
  final double animationValue;
  final String? variantKey;
}

abstract final class ExtendedReferenceGeometry {
  static Size designSizeFor(ExtendedReferenceDevice device) => switch (device) {
    ExtendedReferenceDevice.resistor => const Size(280, 110),
    ExtendedReferenceDevice.pushButtonNc => const Size(90, 140),
    ExtendedReferenceDevice.buzzer => const Size(190, 190),
    ExtendedReferenceDevice.fuse => const Size(300, 110),
    ExtendedReferenceDevice.diode => const Size(270, 105),
    ExtendedReferenceDevice.fan => const Size(210, 210),
    ExtendedReferenceDevice.motor => const Size(230, 190),
    ExtendedReferenceDevice.relayCoil => const Size(190, 230),
  };

  static Size displaySizeFor(ExtendedReferenceDevice device) =>
      designSizeFor(device);

  /// Physical terminal coordinates for the eight additional V2 front views.
  /// The lugs stay close to the actual housing; routing ports remain separate.
  static List<Offset> terminalOffsetsFor(ExtendedReferenceDevice device) =>
      switch (device) {
        ExtendedReferenceDevice.resistor => const <Offset>[
          Offset(62, 55),
          Offset(218, 55),
        ],
        ExtendedReferenceDevice.pushButtonNc => const <Offset>[
          Offset(31, 119),
          Offset(59, 119),
        ],
        ExtendedReferenceDevice.buzzer => const <Offset>[
          Offset(70, 160),
          Offset(120, 160),
        ],
        ExtendedReferenceDevice.fuse => const <Offset>[
          Offset(48, 55),
          Offset(252, 55),
        ],
        ExtendedReferenceDevice.diode => const <Offset>[
          Offset(60, 52.5),
          Offset(210, 52.5),
        ],
        ExtendedReferenceDevice.fan => const <Offset>[
          Offset(82, 187),
          Offset(128, 187),
        ],
        ExtendedReferenceDevice.motor => const <Offset>[
          Offset(90, 161),
          Offset(140, 161),
        ],
        ExtendedReferenceDevice.relayCoil => const <Offset>[
          Offset(65, 202),
          Offset(125, 202),
        ],
      };

  static Offset terminalOffset(
    ExtendedReferenceDevice device, {
    required bool right,
  }) => terminalOffsetsFor(device)[right ? 1 : 0];
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
          state.pressed
              ? 'Bouton normalement fermé appuyé, contact ouvert'
              : 'Bouton normalement fermé relâché, contact fermé',
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
          state.energized
              ? 'Bobine de relais alimentée'
              : 'Bobine de relais au repos',
      },
      child: SizedBox(
        width: width ?? design.width,
        height: height ?? design.height,
        child: Transform.rotate(
          angle: (quarterTurns % 4) * math.pi / 2,
          child: CustomPaint(
            painter: _ExtendedReferencePainter(device, state, showTerminals),
          ),
        ),
      ),
    );
  }
}

class _ExtendedReferencePainter extends CustomPainter {
  const _ExtendedReferencePainter(this.device, this.state, this.showTerminals);

  final ExtendedReferenceDevice device;
  final ExtendedReferenceVisualState state;
  final bool showTerminals;

  Paint _stroke({Color color = const Color(0xFF33434C), double width = 1.4}) =>
      Paint()
        ..color = color
        ..strokeWidth = width
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

  Paint _linear(
    Rect rect,
    List<Color> colors, {
    Alignment begin = Alignment.topLeft,
    Alignment end = Alignment.bottomRight,
  }) {
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
      canvas.drawShadow(Path()..addRRect(rr), const Color(0x88000000), 5, true);
    }
    canvas.drawRRect(rr, _linear(rect, colors));
    canvas.drawRRect(rr, _stroke(color: const Color(0x66000000), width: .9));
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
          fontFamily: 'Roboto',
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
      _linear(r, const <Color>[
        Color(0xFFF7F8F8),
        Color(0xFFB7C2C6),
        Color(0xFF63747B),
      ]),
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
    final double scale = math.min(
      size.width / design.width,
      size.height / design.height,
    );

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
    final Offset left = ExtendedReferenceGeometry.terminalOffset(
      device,
      right: false,
    );
    final Offset right = ExtendedReferenceGeometry.terminalOffset(
      device,
      right: true,
    );
    const Rect body = Rect.fromLTWH(69, 28, 142, 54);

    if (showTerminals) {
      _terminal(c, left, Offset(body.left, s.height / 2));
      _terminal(c, right, Offset(body.right, s.height / 2));
    }

    _box(
      c,
      body,
      const <Color>[Color(0xFFE5D2A1), Color(0xFFC6A86C), Color(0xFF9C7E48)],
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
      c.drawRect(Rect.fromLTWH(xs[i], 31, 9, 48), Paint()..color = bands[i]);
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
    _box(c, const Rect.fromLTWH(12, 8, 66, 124), const [
      Color(0xFFD8DFE0),
      Color(0xFF76858C),
    ], shadow: true);
    _box(c, const Rect.fromLTWH(20, 104, 50, 24), const [
      Color(0xFF424B4C),
      Color(0xFF222B30),
    ], radius: 3);
    const bezelCentre = Offset(45, 58);
    final capCentre = Offset(45, state.pressed ? 61 : 56);
    final bezel = Rect.fromCircle(center: bezelCentre, radius: 29);
    c.drawCircle(
      bezelCentre,
      29,
      _linear(bezel, const [
        Color(0xFFFCFFFF),
        Color(0xFFBEC9CD),
        Color(0xFF5D717B),
      ]),
    );
    c.drawCircle(
      capCentre + const Offset(0, 3),
      23,
      Paint()..color = const Color(0xFF521F1E),
    );
    c.drawCircle(
      capCentre,
      state.pressed ? 21 : 23,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-.4, -.5),
          colors: [Color(0xFFFF8A7B), Color(0xFFD44338), Color(0xFF861A19)],
        ).createShader(Rect.fromCircle(center: capCentre, radius: 23)),
    );
    c.drawArc(
      Rect.fromCircle(center: capCentre, radius: 19),
      math.pi * 1.1,
      math.pi * .55,
      false,
      _stroke(color: const Color(0x90FFD7CF), width: 1),
    );
    _text(c, 'NC', const Offset(39, 91), size: 8);
    _text(c, '21', const Offset(27, 105), size: 6, color: Colors.white70);
    _text(c, '22', const Offset(55, 105), size: 6, color: Colors.white70);
    for (final terminal in ExtendedReferenceGeometry.terminalOffsetsFor(
      device,
    )) {
      _screw(c, terminal, radius: 4);
    }
  }

  void _paintBuzzer(Canvas c, Size s) {
    final Offset left = ExtendedReferenceGeometry.terminalOffset(
      device,
      right: false,
    );
    final Offset right = ExtendedReferenceGeometry.terminalOffset(
      device,
      right: true,
    );
    const Offset center = Offset(95, 94);
    const double r = 63;

    if (showTerminals) {
      _terminal(c, left, const Offset(70, 145));
      _terminal(c, right, const Offset(120, 145));
    }

    final Rect face = Rect.fromCircle(center: center, radius: r);
    c.drawCircle(
      center,
      r,
      _linear(face, const <Color>[
        Color(0xFF4D555A),
        Color(0xFF20272B),
        Color(0xFF0C1012),
      ]),
    );
    c.drawCircle(
      center,
      r,
      _stroke(color: const Color(0xFF090C0E), width: 1.4),
    );

    c.drawCircle(center, 42, Paint()..color = const Color(0xFF11171A));
    for (var angle = 0.0; angle < math.pi * 2; angle += math.pi / 5) {
      final Offset p = center + Offset(math.cos(angle), math.sin(angle)) * 22;
      c.drawCircle(p, 4.2, Paint()..color = const Color(0xFF5B666B));
    }
    c.drawCircle(center, 6, Paint()..color = const Color(0xFF69777C));

    if (state.active) {
      final double pulse =
          .65 + .35 * math.sin(state.animationValue * math.pi * 2);
      for (final double radius in <double>[73, 82]) {
        c.drawArc(
          Rect.fromCircle(center: center, radius: radius),
          -.65,
          1.3,
          false,
          _stroke(
            color: const Color(0xFF23A6D5).withValues(alpha: pulse),
            width: 2,
          ),
        );
      }
    }
    _text(
      c,
      '24 V',
      const Offset(79, 160),
      size: 10,
      color: const Color(0xFF424E54),
    );
  }

  void _paintFuse(Canvas c, Size s) {
    final Offset left = ExtendedReferenceGeometry.terminalOffset(
      device,
      right: false,
    );
    final Offset right = ExtendedReferenceGeometry.terminalOffset(
      device,
      right: true,
    );

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
      const <Color>[Color(0xFFF1F4F5), Color(0xFFADB8BC), Color(0xFF65747A)],
      radius: 4,
      shadow: true,
    );
    _box(
      c,
      rightCap,
      const <Color>[Color(0xFFF1F4F5), Color(0xFFADB8BC), Color(0xFF65747A)],
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
    final Offset left = ExtendedReferenceGeometry.terminalOffset(
      device,
      right: false,
    );
    final Offset right = ExtendedReferenceGeometry.terminalOffset(
      device,
      right: true,
    );
    final String variant = state.variantKey ?? 'rectifier';

    switch (ExtendedReferenceVisualIdentity.diodePackage(variant)) {
      case ExtendedDiodeVisualPackage.rectifier:
        _paintAxialDiode(c, left, right, schottky: false);
        break;
      case ExtendedDiodeVisualPackage.schottky:
        _paintAxialDiode(c, left, right, schottky: true);
        break;
      case ExtendedDiodeVisualPackage.led:
        _paintLed(c, left, right, green: variant == 'led-green');
        break;
      case ExtendedDiodeVisualPackage.zenerGlass:
        _paintZenerGlass(c, left, right);
        break;
      case ExtendedDiodeVisualPackage.tvs:
        _paintTvs(c, left, right);
        break;
    }

    _text(c, 'A', const Offset(92, 82), size: 9);
    _text(c, 'K', const Offset(164, 82), size: 9);
  }

  void _paintAxialDiode(
    Canvas c,
    Offset left,
    Offset right, {
    required bool schottky,
  }) {
    final Rect body = schottky
        ? const Rect.fromLTWH(88, 31, 94, 43)
        : const Rect.fromLTWH(80, 27, 110, 51);
    if (showTerminals) {
      _terminal(c, left, Offset(body.left, 52.5));
      _terminal(c, right, Offset(body.right, 52.5));
    }

    final Color bodyTop = schottky
        ? const Color(0xFF385B68)
        : const Color(0xFF42494D);
    final Color bodyBottom = schottky
        ? const Color(0xFF162B33)
        : const Color(0xFF171B1E);
    _box(
      c,
      body,
      <Color>[
        state.forwardBiased ? Color.lerp(bodyTop, Colors.white, .18)! : bodyTop,
        bodyBottom,
      ],
      radius: body.height * .46,
      shadow: true,
    );
    c.drawRect(
      Rect.fromLTWH(
        body.right - body.width * .23,
        body.top + 2,
        body.width * .10,
        body.height - 4,
      ),
      Paint()..color = const Color(0xFFDDE2E4),
    );
    c.drawOval(
      Rect.fromLTWH(
        body.left + body.width * .10,
        body.top + body.height * .13,
        body.width * .30,
        body.height * .20,
      ),
      Paint()..color = const Color(0x33FFFFFF),
    );
    if (schottky) {
      _text(
        c,
        'S',
        Offset(body.center.dx - 6, body.center.dy - 8),
        size: 15,
        color: const Color(0xFFE9F2F4),
      );
    }
  }

  void _paintLed(Canvas c, Offset left, Offset right, {required bool green}) {
    const Offset center = Offset(135, 49);
    final Color color = green
        ? const Color(0xFF2DAA60)
        : const Color(0xFFD94444);
    final Color litColor = green
        ? const Color(0xFF65F095)
        : const Color(0xFFFF7070);

    if (showTerminals) {
      _terminal(c, left, const Offset(112, 58));
      _terminal(c, right, const Offset(158, 58));
    }
    c.drawLine(
      const Offset(112, 58),
      const Offset(122, 58),
      _stroke(color: const Color(0xFF8C979C), width: 3),
    );
    c.drawLine(
      const Offset(148, 58),
      const Offset(158, 58),
      _stroke(color: const Color(0xFF8C979C), width: 3),
    );

    if (state.forwardBiased) {
      c.drawCircle(
        center,
        31,
        Paint()
          ..color = litColor.withValues(alpha: .25)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 13),
      );
    }

    final Path dome = Path()
      ..moveTo(118, 58)
      ..lineTo(118, 47)
      ..quadraticBezierTo(118, 25, 135, 22)
      ..quadraticBezierTo(152, 25, 152, 47)
      ..lineTo(152, 58)
      ..close();
    c.drawPath(
      dome,
      _linear(dome.getBounds(), <Color>[
        Color.lerp(color, Colors.white, .48)!,
        state.forwardBiased ? litColor : color,
        Color.lerp(color, Colors.black, .28)!,
      ]),
    );
    c.drawPath(dome, _stroke(color: const Color(0xFF6A757A), width: 1.2));
    c.drawRect(
      const Rect.fromLTWH(115, 56, 40, 7),
      Paint()..color = const Color(0xFF7B878C),
    );
    c.drawLine(
      const Offset(126, 44),
      const Offset(126, 57),
      _stroke(color: const Color(0xFFB7C0C4), width: 1.5),
    );
    c.drawLine(
      const Offset(143, 38),
      const Offset(143, 57),
      _stroke(color: const Color(0xFFB7C0C4), width: 1.5),
    );
  }

  void _paintZenerGlass(Canvas c, Offset left, Offset right) {
    const Rect glass = Rect.fromLTWH(88, 33, 94, 39);
    if (showTerminals) {
      _terminal(c, left, const Offset(88, 52.5));
      _terminal(c, right, const Offset(182, 52.5));
    }
    c.drawRRect(
      RRect.fromRectAndRadius(glass, const Radius.circular(17)),
      _linear(glass, const <Color>[
        Color(0x99F8D6A2),
        Color(0x66CE8B45),
        Color(0x99F4E3C5),
      ]),
    );
    c.drawRRect(
      RRect.fromRectAndRadius(glass, const Radius.circular(17)),
      _stroke(color: const Color(0xFF8C6E55), width: 1.1),
    );
    c.drawRect(
      const Rect.fromLTWH(157, 35, 7, 35),
      Paint()..color = const Color(0xFF6C4B88),
    );
    c.drawRect(
      const Rect.fromLTWH(124, 44, 21, 17),
      Paint()..color = const Color(0x885A3A28),
    );
    _text(
      c,
      '5V1',
      const Offset(120, 82),
      size: 8,
      color: const Color(0xFF60472F),
    );
  }

  void _paintTvs(Canvas c, Offset left, Offset right) {
    const Rect body = Rect.fromLTWH(91, 29, 88, 47);
    if (showTerminals) {
      _terminal(c, left, const Offset(91, 52.5));
      _terminal(c, right, const Offset(179, 52.5));
    }
    _box(
      c,
      body,
      const <Color>[Color(0xFF5A6267), Color(0xFF20272B), Color(0xFF101518)],
      radius: 6,
      shadow: true,
    );
    c.drawRect(
      const Rect.fromLTWH(152, 31, 9, 43),
      Paint()..color = const Color(0xFFB74E58),
    );
    _text(
      c,
      'TVS',
      const Offset(112, 45),
      size: 11,
      color: const Color(0xFFF1F3F4),
    );
    _text(
      c,
      '12 V',
      const Offset(111, 82),
      size: 8,
      color: const Color(0xFF545F64),
    );
  }

  void _paintFan(Canvas c, Size s) {
    final Offset left = ExtendedReferenceGeometry.terminalOffset(
      device,
      right: false,
    );
    final Offset right = ExtendedReferenceGeometry.terminalOffset(
      device,
      right: true,
    );

    const Rect frame = Rect.fromLTWH(29, 29, 152, 152);
    if (showTerminals) {
      _terminal(c, left, const Offset(82, 176));
      _terminal(c, right, const Offset(128, 176));
    }

    _box(
      c,
      frame,
      const <Color>[Color(0xFF3A4247), Color(0xFF161D21), Color(0xFF080B0D)],
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
    c.drawCircle(center, 62, Paint()..color = const Color(0xFF0E1417));
    c.drawCircle(center, 18, Paint()..color = const Color(0xFF4E5C62));

    final double phase = state.speedFraction <= 1e-6
        ? 0
        : state.animationValue *
              math.pi *
              2 *
              (0.25 + state.speedFraction * 2.75);
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
        _linear(const Rect.fromLTWH(0, -25, 65, 45), const <Color>[
          Color(0xFF66757B),
          Color(0xFF263238),
          Color(0xFF11171A),
        ]),
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
    final Offset left = ExtendedReferenceGeometry.terminalOffset(
      device,
      right: false,
    );
    final Offset right = ExtendedReferenceGeometry.terminalOffset(
      device,
      right: true,
    );
    const Offset center = Offset(116, 91);

    if (showTerminals) {
      _terminal(c, left, const Offset(90, 146));
      _terminal(c, right, const Offset(140, 146));
    }

    final Rect shell = Rect.fromCircle(center: center, radius: 68);
    c.drawCircle(
      center,
      68,
      _linear(shell, const <Color>[
        Color(0xFFE8ECEE),
        Color(0xFF9AA8AD),
        Color(0xFF53636A),
      ]),
    );
    c.drawCircle(
      center,
      68,
      _stroke(color: const Color(0xFF53636A), width: 1.4),
    );

    c.drawCircle(center, 49, Paint()..color = const Color(0xFF303A3F));

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

    final double speedFraction = (state.speedRpm.abs() / 3000)
        .clamp(0.0, 1.0)
        .toDouble();
    final double direction = state.speedRpm < 0 ? -1 : 1;
    final double phase = speedFraction <= 1e-6
        ? 0
        : state.animationValue *
              math.pi *
              2 *
              (0.2 + speedFraction * 3.8) *
              direction;
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
      _linear(Rect.fromCircle(center: center, radius: 17), const <Color>[
        Color(0xFFF7F8F8),
        Color(0xFFB5C0C4),
        Color(0xFF687980),
      ]),
    );
    c.drawCircle(center, 6, Paint()..color = const Color(0xFF424E54));

    _text(c, 'M', const Offset(109, 84), size: 12, color: Colors.white);
    _text(c, '24 V CC', const Offset(88, 163), size: 9);
  }

  void _paintRelayCoil(Canvas c, Size s) {
    final Offset left = ExtendedReferenceGeometry.terminalOffset(
      device,
      right: false,
    );
    final Offset right = ExtendedReferenceGeometry.terminalOffset(
      device,
      right: true,
    );

    const Rect body = Rect.fromLTWH(35, 24, 120, 182);
    if (showTerminals) {
      _terminal(c, left, const Offset(65, 188));
      _terminal(c, right, const Offset(125, 188));
    }

    _box(
      c,
      body,
      const <Color>[Color(0xFFDDE9ED), Color(0xFF9CB8C2), Color(0xFF5E7780)],
      radius: 7,
      shadow: true,
    );

    final Rect window = const Rect.fromLTWH(52, 50, 86, 91);
    _box(c, window, const <Color>[
      Color(0xFF263238),
      Color(0xFF11191D),
    ], radius: 5);

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
      _linear(core, const <Color>[Color(0xFFE2E7E8), Color(0xFF788A91)]),
    );

    if (state.energized) {
      c.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(47, 45, 96, 101),
          const Radius.circular(8),
        ),
        _stroke(
          color: const Color(0xFF43C777).withValues(
            alpha:
                .55 + .35 * math.sin(state.animationValue * math.pi * 2).abs(),
          ),
          width: 3,
        ),
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
