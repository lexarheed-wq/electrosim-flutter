import 'dart:math' as math;

import 'package:electrosim_canvas/electrosim_canvas.dart';
import 'package:flutter/material.dart';

/// Visual contract for the five Point 5 pilot components.
///
/// The public API is intentionally kept stable while the former simplified
/// painter has been replaced by a front-view vector renderer. Electrical state
/// remains owned by the Flutter/Dart runtime and is only consumed here.
abstract final class F18V1PilotVisuals {
  static const Set<String> coveredModelTypes = <String>{
    'dc_voltage_source',
    'voltage_source',
    'switch',
    'switch_spst',
    'lamp',
    'breaker_dc',
    'breaker_ac1',
    'breaker',
    'push_button_no',
  };

  static const String renderingMode = 'orthographic_front_vector';
  static const bool frontViewOnly = true;
  static const bool rasterAssetsAllowed = false;
  static const bool perspectiveAllowed = false;

  static bool supports(String modelType) =>
      coveredModelTypes.contains(modelType.toLowerCase());
}

class F18V1ComponentVisual extends StatelessWidget {
  const F18V1ComponentVisual({
    super.key,
    required this.modelType,
    required this.size,
    this.enabled = true,
    this.energized = false,
    this.closed = false,
    this.tripped = false,
    this.pressed = false,
    this.animationValue = 0,
    this.showTerminals = true,
  });

  final String modelType;
  final Size size;
  final bool enabled;
  final bool energized;
  final bool closed;
  final bool tripped;
  final bool pressed;
  final double animationValue;
  final bool showTerminals;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size.width,
      height: size.height,
      child: CustomPaint(
        painter: F18V1ComponentPainter(
          modelType: modelType,
          enabled: enabled,
          energized: energized,
          closed: closed,
          tripped: tripped,
          pressed: pressed,
          animationValue: animationValue,
          showTerminals: showTerminals,
        ),
      ),
    );
  }
}

/// Orthographic front-view vector renderer.
///
/// No perspective transforms, side faces, raster textures or photographic
/// assets are used. Material realism comes from symmetric front-face shading,
/// mechanical proportions, screws, bezels, lenses and connection hardware.
class F18V1ComponentPainter extends CustomPainter {
  const F18V1ComponentPainter({
    required this.modelType,
    required this.enabled,
    required this.energized,
    required this.closed,
    required this.tripped,
    required this.pressed,
    required this.animationValue,
    required this.showTerminals,
  });

  final String modelType;
  final bool enabled;
  final bool energized;
  final bool closed;
  final bool tripped;
  final bool pressed;
  final double animationValue;
  final bool showTerminals;

  static const Size _designSize = Size(104, 64);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(
      size.width / _designSize.width,
      size.height / _designSize.height,
    );

    switch (modelType.toLowerCase()) {
      case 'dc_voltage_source':
      case 'voltage_source':
        _paintPowerSupply(canvas);
      case 'switch':
      case 'switch_spst':
        _paintRockerSwitch(canvas);
      case 'lamp':
        _paintPilotLamp(canvas);
      case 'breaker_dc':
      case 'breaker_ac1':
      case 'breaker':
        _paintBreaker(canvas);
      case 'push_button_no':
        _paintPushButton(canvas);
    }

    if (!enabled) {
      canvas.drawRect(
        Rect.fromCenter(center: Offset.zero, width: 104, height: 64),
        Paint()..color = const Color(0x66FFFFFF),
      );
    }
    canvas.restore();
  }

  Paint _stroke({
    Color color = const Color(0xFF29363B),
    double width = 1.2,
  }) =>
      Paint()
        ..color = color
        ..strokeWidth = width
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

  Paint _frontGradient(Rect rect, List<Color> colors) => Paint()
    ..shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: colors,
    ).createShader(rect);

  void _roundedPanel(
    Canvas canvas,
    Rect rect, {
    required double radius,
    required Paint fill,
    Color border = const Color(0xFF34464C),
    double borderWidth = 1.1,
  }) {
    final RRect shape =
        RRect.fromRectAndRadius(rect, Radius.circular(radius));
    canvas.drawRRect(shape, fill);
    canvas.drawRRect(
      shape,
      _stroke(color: border, width: borderWidth),
    );
  }

  void _label(
    Canvas canvas,
    String text,
    Offset center, {
    double size = 6,
    Color color = const Color(0xFF263338),
    FontWeight weight = FontWeight.w700,
  }) {
    final TextPainter painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: size,
          fontWeight: weight,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    painter.paint(
      canvas,
      Offset(center.dx - painter.width / 2, center.dy - painter.height / 2),
    );
  }

  double _terminalHalfSpan() =>
      TerminalVisualProfile.horizontalHalfSpanForModel(
        modelType,
        size: _designSize,
      ) ??
      _designSize.width / 2;

  void _drawLeadAndTerminal(
    Canvas canvas, {
    required bool left,
    required double bodyEdge,
    required Color conductorColor,
  }) {
    final double terminalX = left ? -_terminalHalfSpan() : _terminalHalfSpan();
    final double bodyX = left ? -bodyEdge : bodyEdge;
    canvas.drawLine(
      Offset(bodyX, 0),
      Offset(terminalX, 0),
      Paint()
        ..color = conductorColor
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.square,
    );
    if (showTerminals) {
      _terminal(canvas, Offset(terminalX, 0));
    }
  }

  void _terminal(Canvas canvas, Offset center) {
    final Rect brassRect = Rect.fromCircle(center: center, radius: 3.8);
    canvas.drawCircle(
      center,
      3.8,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.25, -0.25),
          radius: .9,
          colors: <Color>[
            Color(0xFFFFE9A2),
            Color(0xFFD7A843),
            Color(0xFF8D6425),
          ],
        ).createShader(brassRect),
    );
    canvas.drawCircle(
      center,
      3.8,
      _stroke(color: const Color(0xFF5F451D), width: .9),
    );
    canvas.drawLine(
      center.translate(-1.5, 0),
      center.translate(1.5, 0),
      _stroke(color: const Color(0xFF59411D), width: .8),
    );
  }

  void _screw(Canvas canvas, Offset center, {double radius = 3.1}) {
    final Rect r = Rect.fromCircle(center: center, radius: radius);
    canvas.drawCircle(
      center,
      radius,
      _frontGradient(
        r,
        const <Color>[
          Color(0xFFF3F5F5),
          Color(0xFFB7C1C4),
          Color(0xFF7D8B8F),
        ],
      ),
    );
    canvas.drawCircle(
      center,
      radius,
      _stroke(color: const Color(0xFF4A585D), width: .8),
    );
    canvas.drawLine(
      center.translate(-1.6, 0),
      center.translate(1.6, 0),
      _stroke(color: const Color(0xFF475358), width: .7),
    );
    canvas.drawLine(
      center.translate(0, -1.6),
      center.translate(0, 1.6),
      _stroke(color: const Color(0xFF475358), width: .7),
    );
  }

  void _paintPowerSupply(Canvas canvas) {
    const Rect body = Rect.fromLTWH(-39, -29, 78, 58);
    _drawLeadAndTerminal(
      canvas,
      left: true,
      bodyEdge: 39,
      conductorColor: const Color(0xFFB59B5F),
    );
    _drawLeadAndTerminal(
      canvas,
      left: false,
      bodyEdge: 39,
      conductorColor: const Color(0xFFB59B5F),
    );

    _roundedPanel(
      canvas,
      body,
      radius: 3.2,
      fill: _frontGradient(
        body,
        const <Color>[
          Color(0xFFF5F7F7),
          Color(0xFFE6ECEC),
          Color(0xFFD2DCDD),
        ],
      ),
      border: const Color(0xFF65767B),
    );

    const Rect face = Rect.fromLTWH(-32, -24, 64, 48);
    _roundedPanel(
      canvas,
      face,
      radius: 2.4,
      fill: Paint()..color = const Color(0xFF07558C),
      border: const Color(0xFF043A61),
    );

    for (double x = -28; x <= 28; x += 7) {
      canvas.drawLine(
        Offset(x, -20.5),
        Offset(x + 3, -20.5),
        _stroke(color: const Color(0xFFA9B7BA), width: 1),
      );
    }

    const Rect topTerminals = Rect.fromLTWH(-27, -17, 54, 11);
    _roundedPanel(
      canvas,
      topTerminals,
      radius: 1.5,
      fill: Paint()..color = const Color(0xFF38A65C),
      border: const Color(0xFF1B6336),
      borderWidth: .8,
    );
    for (final double x in <double>[-18, -6, 6, 18]) {
      _screw(canvas, Offset(x, -11.5), radius: 2.5);
    }

    _label(
      canvas,
      '24 V CC',
      const Offset(0, 1),
      size: 7.4,
      color: Colors.white,
      weight: FontWeight.w800,
    );
    _label(
      canvas,
      'ALIM',
      const Offset(0, 9),
      size: 5.2,
      color: const Color(0xFFDCECF6),
    );

    const Rect lower = Rect.fromLTWH(-27, 13, 54, 8);
    _roundedPanel(
      canvas,
      lower,
      radius: 1.4,
      fill: Paint()..color = const Color(0xFF2E9C55),
      border: const Color(0xFF1D6438),
      borderWidth: .7,
    );
    _screw(canvas, const Offset(-17, 17), radius: 2.2);
    _screw(canvas, const Offset(0, 17), radius: 2.2);
    _screw(canvas, const Offset(17, 17), radius: 2.2);

    final Color led = energized
        ? const Color(0xFF65E87C)
        : const Color(0xFF6C7E78);
    if (energized) {
      canvas.drawCircle(
        const Offset(25, 5),
        4.5,
        Paint()..color = const Color(0x4465E87C),
      );
    }
    canvas.drawCircle(const Offset(25, 5), 2.4, Paint()..color = led);
    canvas.drawCircle(
      const Offset(25, 5),
      2.4,
      _stroke(color: const Color(0xFF163C26), width: .7),
    );
  }

  void _paintRockerSwitch(Canvas canvas) {
    const Rect shell = Rect.fromLTWH(-25, -27, 50, 54);
    _drawLeadAndTerminal(
      canvas,
      left: true,
      bodyEdge: 25,
      conductorColor: const Color(0xFFB79C5B),
    );
    _drawLeadAndTerminal(
      canvas,
      left: false,
      bodyEdge: 25,
      conductorColor: const Color(0xFFB79C5B),
    );

    _roundedPanel(
      canvas,
      shell,
      radius: 4.2,
      fill: _frontGradient(
        shell,
        const <Color>[
          Color(0xFF343A3D),
          Color(0xFF181D20),
          Color(0xFF0F1315),
        ],
      ),
      border: const Color(0xFF070A0B),
      borderWidth: 1.2,
    );

    const Rect rocker = Rect.fromLTWH(-15, -20, 30, 40);
    _roundedPanel(
      canvas,
      rocker,
      radius: 3.6,
      fill: _frontGradient(
        rocker,
        closed
            ? const <Color>[
                Color(0xFF4A5053),
                Color(0xFF252A2C),
                Color(0xFF171A1C),
              ]
            : const <Color>[
                Color(0xFF2C3133),
                Color(0xFF171B1D),
                Color(0xFF0F1213),
              ],
      ),
      border: const Color(0xFF080A0B),
      borderWidth: 1,
    );

    canvas.drawLine(
      const Offset(-11, 0),
      const Offset(11, 0),
      _stroke(color: const Color(0xFF090C0D), width: .8),
    );
    _label(
      canvas,
      'I',
      const Offset(0, -10),
      size: 8,
      color: closed ? Colors.white : const Color(0xFFB9BFC1),
    );
    _label(
      canvas,
      'O',
      const Offset(0, 10),
      size: 8,
      color: !closed ? Colors.white : const Color(0xFFB9BFC1),
    );

    const Rect leftLug = Rect.fromLTWH(-31, -5, 6, 10);
    const Rect rightLug = Rect.fromLTWH(25, -5, 6, 10);
    canvas.drawRect(leftLug, Paint()..color = const Color(0xFFC8A44F));
    canvas.drawRect(rightLug, Paint()..color = const Color(0xFFC8A44F));
    canvas.drawRect(leftLug, _stroke(color: const Color(0xFF70531E), width: .7));
    canvas.drawRect(rightLug, _stroke(color: const Color(0xFF70531E), width: .7));
  }

  void _paintPushButton(Canvas canvas) {
    const Rect block = Rect.fromLTWH(-22, -22, 44, 44);
    _drawLeadAndTerminal(
      canvas,
      left: true,
      bodyEdge: 22,
      conductorColor: const Color(0xFFB79C5B),
    );
    _drawLeadAndTerminal(
      canvas,
      left: false,
      bodyEdge: 22,
      conductorColor: const Color(0xFFB79C5B),
    );

    _roundedPanel(
      canvas,
      block,
      radius: 3.2,
      fill: _frontGradient(
        block,
        const <Color>[
          Color(0xFF3D4346),
          Color(0xFF23282A),
          Color(0xFF171A1C),
        ],
      ),
      border: const Color(0xFF0D1011),
    );

    for (final Offset screw in const <Offset>[
      Offset(-16, -16),
      Offset(16, -16),
      Offset(-16, 16),
      Offset(16, 16),
    ]) {
      _screw(canvas, screw, radius: 2.1);
    }

    final Rect bezelRect = Rect.fromCircle(center: Offset.zero, radius: 16.5);
    canvas.drawCircle(
      Offset.zero,
      16.5,
      _frontGradient(
        bezelRect,
        const <Color>[
          Color(0xFFF5F7F7),
          Color(0xFFC9D0D2),
          Color(0xFF879397),
        ],
      ),
    );
    canvas.drawCircle(
      Offset.zero,
      16.5,
      _stroke(color: const Color(0xFF59676C), width: 1.1),
    );

    final double capRadius = pressed ? 12.2 : 13.2;
    final Rect capRect = Rect.fromCircle(center: Offset.zero, radius: capRadius);
    canvas.drawCircle(
      Offset.zero,
      capRadius,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-.3, -.35),
          radius: .85,
          colors: <Color>[
            Color(0xFF7EF19B),
            Color(0xFF26B85A),
            Color(0xFF0A7634),
          ],
        ).createShader(capRect),
    );
    canvas.drawCircle(
      Offset.zero,
      capRadius,
      _stroke(color: const Color(0xFF075D2A), width: 1.1),
    );
    canvas.drawCircle(
      const Offset(-3.5, -4),
      3.4,
      Paint()..color = const Color(0x55FFFFFF),
    );
    _label(
      canvas,
      'NO',
      const Offset(0, 25.5),
      size: 5,
      color: const Color(0xFF324148),
    );
  }

  void _paintBreaker(Canvas canvas) {
    const Rect body = Rect.fromLTWH(-29, -30, 58, 60);
    _drawLeadAndTerminal(
      canvas,
      left: true,
      bodyEdge: 29,
      conductorColor: const Color(0xFFB79C5B),
    );
    _drawLeadAndTerminal(
      canvas,
      left: false,
      bodyEdge: 29,
      conductorColor: const Color(0xFFB79C5B),
    );

    _roundedPanel(
      canvas,
      body,
      radius: 2.5,
      fill: _frontGradient(
        body,
        const <Color>[
          Color(0xFFF9FAFA),
          Color(0xFFF0F2F2),
          Color(0xFFD9DEDF),
        ],
      ),
      border: const Color(0xFF69777B),
    );

    const Rect terminalTop = Rect.fromLTWH(-18, -28, 36, 9);
    const Rect terminalBottom = Rect.fromLTWH(-18, 19, 36, 9);
    canvas.drawRect(terminalTop, Paint()..color = const Color(0xFFE4E8E8));
    canvas.drawRect(terminalBottom, Paint()..color = const Color(0xFFE4E8E8));
    _screw(canvas, const Offset(0, -23.5), radius: 3);
    _screw(canvas, const Offset(0, 23.5), radius: 3);

    _label(
      canvas,
      'Q1',
      const Offset(0, -14.5),
      size: 5.6,
      color: const Color(0xFF263238),
      weight: FontWeight.w800,
    );
    _label(
      canvas,
      'C10',
      const Offset(0, -8.5),
      size: 5.2,
      color: const Color(0xFF263238),
    );

    const Rect leverWell = Rect.fromLTWH(-10, -2, 20, 20);
    _roundedPanel(
      canvas,
      leverWell,
      radius: 2,
      fill: Paint()..color = const Color(0xFFCAD0D1),
      border: const Color(0xFF939C9F),
      borderWidth: .7,
    );

    final bool isOpen = !closed && !tripped;
    final double leverY = tripped ? 9 : isOpen ? 10 : 2;
    final Rect lever = Rect.fromCenter(
      center: Offset(0, leverY),
      width: 16,
      height: 14,
    );
    _roundedPanel(
      canvas,
      lever,
      radius: 1.8,
      fill: _frontGradient(
        lever,
        tripped
            ? const <Color>[
                Color(0xFFF2A073),
                Color(0xFFD35D35),
              ]
            : const <Color>[
                Color(0xFF4E9EF0),
                Color(0xFF1368C5),
              ],
      ),
      border: tripped
          ? const Color(0xFF8F3D23)
          : const Color(0xFF0A4B92),
      borderWidth: .9,
    );

    _label(
      canvas,
      tripped ? 'TRIP' : closed ? 'I' : 'O',
      Offset(0, leverY),
      size: tripped ? 4.2 : 6,
      color: Colors.white,
      weight: FontWeight.w800,
    );

    const Rect leftLug = Rect.fromLTWH(-35, -4, 6, 8);
    const Rect rightLug = Rect.fromLTWH(29, -4, 6, 8);
    canvas.drawRect(leftLug, Paint()..color = const Color(0xFFC9A451));
    canvas.drawRect(rightLug, Paint()..color = const Color(0xFFC9A451));
    canvas.drawRect(leftLug, _stroke(color: const Color(0xFF6F531D), width: .7));
    canvas.drawRect(rightLug, _stroke(color: const Color(0xFF6F531D), width: .7));
  }

  void _paintPilotLamp(Canvas canvas) {
    const double bodyRadius = 22;
    _drawLeadAndTerminal(
      canvas,
      left: true,
      bodyEdge: bodyRadius,
      conductorColor: const Color(0xFFB79C5B),
    );
    _drawLeadAndTerminal(
      canvas,
      left: false,
      bodyEdge: bodyRadius,
      conductorColor: const Color(0xFFB79C5B),
    );

    const Rect mount = Rect.fromLTWH(-22, -22, 44, 44);
    _roundedPanel(
      canvas,
      mount,
      radius: 3,
      fill: _frontGradient(
        mount,
        const <Color>[
          Color(0xFF343A3D),
          Color(0xFF202527),
          Color(0xFF141719),
        ],
      ),
      border: const Color(0xFF0A0D0E),
    );

    final Rect bezel = Rect.fromCircle(center: Offset.zero, radius: 18.2);
    canvas.drawCircle(
      Offset.zero,
      18.2,
      _frontGradient(
        bezel,
        const <Color>[
          Color(0xFF707A7D),
          Color(0xFF2B3133),
          Color(0xFF15191A),
        ],
      ),
    );
    canvas.drawCircle(
      Offset.zero,
      18.2,
      _stroke(color: const Color(0xFF0A0D0E), width: 1),
    );

    final double phase = animationValue * math.pi * 2;
    final double pulse = .5 + .5 * math.sin(phase);
    if (energized) {
      canvas.drawCircle(
        Offset.zero,
        17.5 + pulse,
        Paint()..color = Color.fromARGB((30 + pulse * 22).round(), 255, 40, 35),
      );
    }

    const double lensRadius = 14.7;
    final Rect lens = Rect.fromCircle(center: Offset.zero, radius: lensRadius);
    canvas.drawCircle(
      Offset.zero,
      lensRadius,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-.28, -.32),
          radius: .9,
          colors: energized
              ? const <Color>[
                  Color(0xFFFF9185),
                  Color(0xFFFF2825),
                  Color(0xFF9A0808),
                ]
              : const <Color>[
                  Color(0xFFB85A55),
                  Color(0xFF8D2623),
                  Color(0xFF561413),
                ],
        ).createShader(lens),
    );
    canvas.drawCircle(
      Offset.zero,
      lensRadius,
      _stroke(color: const Color(0xFF5C0B0B), width: 1.1),
    );

    for (double r = 5; r <= 12; r += 3.5) {
      canvas.drawCircle(
        Offset.zero,
        r,
        _stroke(
          color: const Color(0x55FFD0CB),
          width: .55,
        ),
      );
    }
    canvas.drawCircle(
      const Offset(-4.2, -4.5),
      3,
      Paint()..color = const Color(0x44FFFFFF),
    );

    const Rect leftLug = Rect.fromLTWH(-28, -4, 6, 8);
    const Rect rightLug = Rect.fromLTWH(22, -4, 6, 8);
    canvas.drawRect(leftLug, Paint()..color = const Color(0xFFC9A451));
    canvas.drawRect(rightLug, Paint()..color = const Color(0xFFC9A451));
    canvas.drawRect(leftLug, _stroke(color: const Color(0xFF6F531D), width: .7));
    canvas.drawRect(rightLug, _stroke(color: const Color(0xFF6F531D), width: .7));
  }

  @override
  bool shouldRepaint(F18V1ComponentPainter oldDelegate) =>
      oldDelegate.modelType != modelType ||
      oldDelegate.enabled != enabled ||
      oldDelegate.energized != energized ||
      oldDelegate.closed != closed ||
      oldDelegate.tripped != tripped ||
      oldDelegate.pressed != pressed ||
      oldDelegate.animationValue != animationValue ||
      oldDelegate.showTerminals != showTerminals;
}
