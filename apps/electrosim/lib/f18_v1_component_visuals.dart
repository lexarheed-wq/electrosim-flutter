import 'dart:math' as math;

import 'package:electrosim_canvas/electrosim_canvas.dart';
import 'package:flutter/material.dart';

abstract final class F18PilotVisualMetrics {
  static const Map<String, Size> _board = <String, Size>{
    'dc_voltage_source': Size(188, 106),
    'voltage_source': Size(188, 106),
    'switch': Size(142, 84),
    'switch_spst': Size(142, 84),
    'push_button_no': Size(104, 104),
    'breaker_dc': Size(92, 158),
    'breaker_ac1': Size(92, 158),
    'breaker': Size(92, 158),
    'lamp': Size(102, 102),
  };

  static const Map<String, Size> _palette = <String, Size>{
    'dc_voltage_source': Size(104, 58),
    'voltage_source': Size(104, 58),
    'switch': Size(88, 52),
    'switch_spst': Size(88, 52),
    'push_button_no': Size(64, 64),
    'breaker_dc': Size(48, 82),
    'breaker_ac1': Size(48, 82),
    'breaker': Size(48, 82),
    'lamp': Size(64, 64),
  };

  static Size boardSizeFor(String modelType) =>
      _board[modelType.toLowerCase()] ?? const Size(104, 64);

  static Size paletteSizeFor(String modelType) =>
      _palette[modelType.toLowerCase()] ?? const Size(72, 44);

  static Size dragSizeFor(String modelType) {
    final Size size = boardSizeFor(modelType);
    return Size(size.width * .82, size.height * .82);
  }

  static Size designSizeFor(String modelType) => boardSizeFor(modelType);
}

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

  static const String renderingMode = 'per_model_front_vector';
  static const bool frontViewOnly = true;
  static const bool rasterAssetsAllowed = false;
  static const bool perspectiveAllowed = false;
  static const bool visibleBoundingBoxAllowed = false;

  static const Map<String, String> silhouetteByModel = <String, String>{
    'dc_voltage_source': 'wide_industrial_power_supply',
    'voltage_source': 'wide_industrial_power_supply',
    'switch': 'horizontal_rocker_switch',
    'switch_spst': 'horizontal_rocker_switch',
    'lamp': 'round_pilot_lamp',
    'breaker_dc': 'tall_narrow_mcb',
    'breaker_ac1': 'tall_narrow_mcb',
    'breaker': 'tall_narrow_mcb',
    'push_button_no': 'round_pushbutton',
  };

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

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final Size design = F18PilotVisualMetrics.designSizeFor(modelType);
    final double scale = math.min(
      size.width / design.width,
      size.height / design.height,
    );

    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(scale);

    switch (modelType.toLowerCase()) {
      case 'dc_voltage_source':
      case 'voltage_source':
        _paintPowerSupply(canvas, design);
      case 'switch':
      case 'switch_spst':
        _paintRockerSwitch(canvas, design);
      case 'lamp':
        _paintPilotLamp(canvas, design);
      case 'breaker_dc':
      case 'breaker_ac1':
      case 'breaker':
        _paintBreaker(canvas, design);
      case 'push_button_no':
        _paintPushButton(canvas, design);
    }

    canvas.restore();
  }

  Paint _stroke({Color color = const Color(0xFF263238), double width = 1.2}) =>
      Paint()
        ..color = color
        ..strokeWidth = width
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

  Paint _linear(Rect rect, List<Color> colors) => Paint()
    ..shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: colors,
    ).createShader(rect);

  void _text(
    Canvas canvas,
    String text,
    Offset center, {
    double size = 7,
    Color color = const Color(0xFF263238),
    FontWeight weight = FontWeight.w700,
  }) {
    final TextPainter tp = TextPainter(
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
    tp.paint(
      canvas,
      Offset(center.dx - tp.width / 2, center.dy - tp.height / 2),
    );
  }

  double _terminalHalfSpan(Size design) =>
      TerminalVisualProfile.horizontalHalfSpanForModel(
        modelType,
        size: design,
      ) ??
      design.width / 2;

  void _lead(Canvas canvas, Size design, double bodyEdge) {
    final double terminal = _terminalHalfSpan(design);
    final Paint p = Paint()
      ..color = const Color(0xFFB58D3B)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.square;
    canvas.drawLine(Offset(-terminal, 0), Offset(-bodyEdge, 0), p);
    canvas.drawLine(Offset(bodyEdge, 0), Offset(terminal, 0), p);
    if (showTerminals) {
      _terminal(canvas, Offset(-terminal, 0));
      _terminal(canvas, Offset(terminal, 0));
    }
  }

  void _terminal(Canvas canvas, Offset center) {
    final Rect r = Rect.fromCircle(center: center, radius: 4.2);
    canvas.drawCircle(
      center,
      4.2,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-.3, -.3),
          colors: <Color>[
            Color(0xFFFFE8A4),
            Color(0xFFD1A040),
            Color(0xFF76551B),
          ],
        ).createShader(r),
    );
    canvas.drawCircle(
      center,
      4.2,
      _stroke(color: const Color(0xFF5B4118), width: .9),
    );
    canvas.drawLine(
      center.translate(-1.6, 0),
      center.translate(1.6, 0),
      _stroke(color: const Color(0xFF473313), width: .8),
    );
  }

  void _screw(Canvas canvas, Offset center, {double radius = 3.2}) {
    final Rect r = Rect.fromCircle(center: center, radius: radius);
    canvas.drawCircle(
      center,
      radius,
      _linear(r, const <Color>[
        Color(0xFFF7F8F8),
        Color(0xFFBCC5C7),
        Color(0xFF6F7B7F),
      ]),
    );
    canvas.drawCircle(
      center,
      radius,
      _stroke(color: const Color(0xFF4A565A), width: .8),
    );
    canvas.drawLine(
      center.translate(-1.5, 0),
      center.translate(1.5, 0),
      _stroke(color: const Color(0xFF465257), width: .7),
    );
    canvas.drawLine(
      center.translate(0, -1.5),
      center.translate(0, 1.5),
      _stroke(color: const Color(0xFF465257), width: .7),
    );
  }

  void _paintPowerSupply(Canvas canvas, Size design) {
    final double w = design.width;
    final double h = design.height;
    final double bodyEdge = w * .405;
    _lead(canvas, design, bodyEdge);

    final Path chassis = Path()
      ..moveTo(-w * .37, -h * .40)
      ..lineTo(w * .34, -h * .40)
      ..lineTo(w * .405, -h * .30)
      ..lineTo(w * .405, h * .30)
      ..lineTo(w * .34, h * .40)
      ..lineTo(-w * .37, h * .40)
      ..lineTo(-w * .405, h * .32)
      ..lineTo(-w * .405, -h * .32)
      ..close();
    final Rect body = Rect.fromLTWH(-w * .405, -h * .40, w * .81, h * .80);
    canvas.drawPath(
      chassis,
      _linear(body, const <Color>[
        Color(0xFFF4F6F6),
        Color(0xFFDCE4E5),
        Color(0xFFB2C0C3),
      ]),
    );
    canvas.drawPath(
      chassis,
      _stroke(color: const Color(0xFF5F7278), width: 1.3),
    );

    final Rect face = Rect.fromLTWH(-w * .31, -h * .33, w * .62, h * .66);
    canvas.drawRRect(
      RRect.fromRectAndRadius(face, Radius.circular(h * .04)),
      Paint()..color = const Color(0xFF07588F),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(face, Radius.circular(h * .04)),
      _stroke(color: const Color(0xFF043D64), width: 1),
    );

    for (double x = -w * .28; x <= w * .22; x += w * .09) {
      canvas.drawLine(
        Offset(x, -h * .365),
        Offset(x + w * .045, -h * .365),
        _stroke(color: const Color(0xFF7F9095), width: 1.1),
      );
    }

    final Rect top = Rect.fromLTWH(-w * .27, -h * .27, w * .54, h * .16);
    canvas.drawRect(top, Paint()..color = const Color(0xFF37A75B));
    for (final double x in <double>[-.18, -.06, .06, .18]) {
      _screw(canvas, Offset(w * x, -h * .19), radius: h * .04);
    }

    final Rect bottom = Rect.fromLTWH(-w * .25, h * .18, w * .50, h * .12);
    canvas.drawRect(bottom, Paint()..color = const Color(0xFF319B53));
    for (final double x in <double>[-.15, 0, .15]) {
      _screw(canvas, Offset(w * x, h * .24), radius: h * .036);
    }

    _text(
      canvas,
      '24 V CC',
      Offset(-w * .05, 0),
      size: h * .12,
      color: Colors.white,
      weight: FontWeight.w800,
    );
    _text(
      canvas,
      'ALIMENTATION',
      Offset(-w * .04, h * .11),
      size: h * .055,
      color: const Color(0xFFD8ECF8),
    );

    final Color led = energized
        ? const Color(0xFF66ED7C)
        : const Color(0xFF66776F);
    if (energized) {
      canvas.drawCircle(
        Offset(w * .22, h * .04),
        h * .06,
        Paint()..color = const Color(0x4466ED7C),
      );
    }
    canvas.drawCircle(Offset(w * .22, h * .04), h * .032, Paint()..color = led);

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(-w * .445, -h * .10, w * .04, h * .20),
        Radius.circular(2),
      ),
      Paint()..color = const Color(0xFFC4CED0),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * .405, -h * .10, w * .04, h * .20),
        Radius.circular(2),
      ),
      Paint()..color = const Color(0xFFC4CED0),
    );
  }

  void _paintRockerSwitch(Canvas canvas, Size design) {
    final double w = design.width;
    final double h = design.height;
    final double bodyEdge = w * .34;
    _lead(canvas, design, bodyEdge);

    final Path shell = Path()
      ..moveTo(-w * .28, -h * .31)
      ..quadraticBezierTo(-w * .34, -h * .31, -w * .34, -h * .22)
      ..lineTo(-w * .34, h * .22)
      ..quadraticBezierTo(-w * .34, h * .31, -w * .28, h * .31)
      ..lineTo(w * .28, h * .31)
      ..quadraticBezierTo(w * .34, h * .31, w * .34, h * .22)
      ..lineTo(w * .34, -h * .22)
      ..quadraticBezierTo(w * .34, -h * .31, w * .28, -h * .31)
      ..close();
    final Rect shellRect = Rect.fromLTWH(-w * .34, -h * .31, w * .68, h * .62);
    canvas.drawPath(
      shell,
      _linear(shellRect, const <Color>[
        Color(0xFF444A4D),
        Color(0xFF202426),
        Color(0xFF0E1112),
      ]),
    );
    canvas.drawPath(shell, _stroke(color: const Color(0xFF070909), width: 1.2));

    final Rect rocker = Rect.fromLTWH(-w * .17, -h * .22, w * .34, h * .44);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rocker, Radius.circular(h * .05)),
      _linear(
        rocker,
        closed
            ? const <Color>[
                Color(0xFF555C5F),
                Color(0xFF24282A),
                Color(0xFF141719),
              ]
            : const <Color>[
                Color(0xFF34393B),
                Color(0xFF1A1E20),
                Color(0xFF0D1011),
              ],
      ),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rocker, Radius.circular(h * .05)),
      _stroke(color: const Color(0xFF080A0A), width: 1),
    );
    canvas.drawLine(
      Offset(-w * .13, 0),
      Offset(w * .13, 0),
      _stroke(color: const Color(0xFF080A0A), width: .8),
    );
    _text(canvas, 'I', Offset(0, -h * .11), size: h * .15, color: Colors.white);
    _text(canvas, 'O', Offset(0, h * .11), size: h * .15, color: Colors.white);

    canvas.drawRect(
      Rect.fromLTWH(-w * .40, -h * .06, w * .06, h * .12),
      Paint()..color = const Color(0xFFC9A34B),
    );
    canvas.drawRect(
      Rect.fromLTWH(w * .34, -h * .06, w * .06, h * .12),
      Paint()..color = const Color(0xFFC9A34B),
    );
  }

  void _paintPushButton(Canvas canvas, Size design) {
    final double w = design.width;
    final double r = math.min(design.width, design.height) * .31;
    _lead(canvas, design, r * 1.08);

    final Rect bezel = Rect.fromCircle(center: Offset.zero, radius: r);
    canvas.drawCircle(
      Offset.zero,
      r,
      _linear(bezel, const <Color>[
        Color(0xFFF5F7F7),
        Color(0xFFC9D1D3),
        Color(0xFF7D8A8E),
      ]),
    );
    canvas.drawCircle(
      Offset.zero,
      r,
      _stroke(color: const Color(0xFF58666B), width: 1.2),
    );
    canvas.drawCircle(
      Offset.zero,
      r * .84,
      Paint()..color = const Color(0xFF2E3436),
    );
    canvas.drawCircle(
      Offset.zero,
      r * .84,
      _stroke(color: const Color(0xFF161A1C), width: 1),
    );

    final double capR = pressed ? r * .62 : r * .68;
    final Rect cap = Rect.fromCircle(center: Offset.zero, radius: capR);
    canvas.drawCircle(
      Offset.zero,
      capR,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-.3, -.35),
          radius: .9,
          colors: <Color>[
            Color(0xFF8CF2A5),
            Color(0xFF2ABD5B),
            Color(0xFF087330),
          ],
        ).createShader(cap),
    );
    canvas.drawCircle(
      Offset.zero,
      capR,
      _stroke(color: const Color(0xFF075A27), width: 1.1),
    );
    canvas.drawCircle(
      Offset(-r * .20, -r * .22),
      r * .15,
      Paint()..color = const Color(0x55FFFFFF),
    );

    canvas.drawRect(
      Rect.fromLTWH(-w * .42, -4, w * .08, 8),
      Paint()..color = const Color(0xFFC9A34B),
    );
    canvas.drawRect(
      Rect.fromLTWH(w * .34, -4, w * .08, 8),
      Paint()..color = const Color(0xFFC9A34B),
    );
  }

  void _paintBreaker(Canvas canvas, Size design) {
    final double w = design.width;
    final double h = design.height;
    final double bodyEdge = w * .31;
    _lead(canvas, design, bodyEdge);

    final Path body = Path()
      ..moveTo(-w * .19, -h * .44)
      ..lineTo(w * .19, -h * .44)
      ..lineTo(w * .19, -h * .38)
      ..lineTo(w * .27, -h * .38)
      ..lineTo(w * .27, -h * .30)
      ..lineTo(w * .31, -h * .30)
      ..lineTo(w * .31, h * .30)
      ..lineTo(w * .27, h * .30)
      ..lineTo(w * .27, h * .38)
      ..lineTo(w * .19, h * .38)
      ..lineTo(w * .19, h * .44)
      ..lineTo(-w * .19, h * .44)
      ..lineTo(-w * .19, h * .38)
      ..lineTo(-w * .27, h * .38)
      ..lineTo(-w * .27, h * .30)
      ..lineTo(-w * .31, h * .30)
      ..lineTo(-w * .31, -h * .30)
      ..lineTo(-w * .27, -h * .30)
      ..lineTo(-w * .27, -h * .38)
      ..lineTo(-w * .19, -h * .38)
      ..close();
    final Rect bounds = Rect.fromLTWH(-w * .31, -h * .44, w * .62, h * .88);
    canvas.drawPath(
      body,
      _linear(bounds, const <Color>[
        Color(0xFFFAFBFB),
        Color(0xFFEEF1F1),
        Color(0xFFD2D9DA),
      ]),
    );
    canvas.drawPath(body, _stroke(color: const Color(0xFF627277), width: 1.1));

    _screw(canvas, Offset(0, -h * .34), radius: w * .055);
    _screw(canvas, Offset(0, h * .34), radius: w * .055);
    _text(
      canvas,
      'C10',
      Offset(0, -h * .18),
      size: w * .10,
      weight: FontWeight.w800,
    );
    _text(
      canvas,
      '230 V',
      Offset(0, -h * .12),
      size: w * .06,
      color: const Color(0xFF516066),
    );

    final bool isOpen = !closed && !tripped;
    final double leverY = tripped
        ? h * .12
        : isOpen
        ? h * .14
        : h * .03;
    final Rect lever = Rect.fromCenter(
      center: Offset(0, leverY),
      width: w * .27,
      height: h * .19,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(lever, Radius.circular(2)),
      _linear(
        lever,
        tripped
            ? const <Color>[Color(0xFFF0A079), Color(0xFFD25C34)]
            : const <Color>[Color(0xFF56A3F0), Color(0xFF1167BF)],
      ),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(lever, Radius.circular(2)),
      _stroke(
        color: tripped ? const Color(0xFF8A3A20) : const Color(0xFF0A4A8C),
        width: .9,
      ),
    );
    _text(
      canvas,
      tripped
          ? 'TRIP'
          : closed
          ? 'I'
          : 'O',
      Offset(0, leverY),
      size: tripped ? w * .07 : w * .10,
      color: Colors.white,
      weight: FontWeight.w800,
    );

    canvas.drawRect(
      Rect.fromLTWH(-w * .38, -5, w * .07, 10),
      Paint()..color = const Color(0xFFC9A34B),
    );
    canvas.drawRect(
      Rect.fromLTWH(w * .31, -5, w * .07, 10),
      Paint()..color = const Color(0xFFC9A34B),
    );
  }

  void _paintPilotLamp(Canvas canvas, Size design) {
    final double w = design.width;
    final double r = math.min(design.width, design.height) * .32;
    _lead(canvas, design, r * 1.08);

    final Rect bezel = Rect.fromCircle(center: Offset.zero, radius: r);
    canvas.drawCircle(
      Offset.zero,
      r,
      _linear(bezel, const <Color>[
        Color(0xFF555D60),
        Color(0xFF292F31),
        Color(0xFF101315),
      ]),
    );
    canvas.drawCircle(
      Offset.zero,
      r,
      _stroke(color: const Color(0xFF090B0C), width: 1.2),
    );

    final double phase = animationValue * math.pi * 2;
    final double pulse = .5 + .5 * math.sin(phase);
    if (energized) {
      canvas.drawCircle(
        Offset.zero,
        r * (.95 + pulse * .03),
        Paint()..color = Color.fromARGB((28 + pulse * 22).round(), 255, 45, 40),
      );
    }

    final double lensR = r * .78;
    final Rect lens = Rect.fromCircle(center: Offset.zero, radius: lensR);
    canvas.drawCircle(
      Offset.zero,
      lensR,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-.3, -.34),
          radius: .9,
          colors: energized
              ? const <Color>[
                  Color(0xFFFFA49A),
                  Color(0xFFFF2925),
                  Color(0xFF990707),
                ]
              : const <Color>[
                  Color(0xFFBF635D),
                  Color(0xFF8E2926),
                  Color(0xFF571413),
                ],
        ).createShader(lens),
    );
    canvas.drawCircle(
      Offset.zero,
      lensR,
      _stroke(color: const Color(0xFF5A0B0B), width: 1.1),
    );
    for (double rr = lensR * .35; rr <= lensR * .85; rr += lensR * .22) {
      canvas.drawCircle(
        Offset.zero,
        rr,
        _stroke(color: const Color(0x55FFD1CC), width: .55),
      );
    }
    canvas.drawCircle(
      Offset(-r * .22, -r * .23),
      r * .12,
      Paint()..color = const Color(0x44FFFFFF),
    );

    canvas.drawRect(
      Rect.fromLTWH(-w * .42, -4, w * .08, 8),
      Paint()..color = const Color(0xFFC9A34B),
    );
    canvas.drawRect(
      Rect.fromLTWH(w * .34, -4, w * .08, 8),
      Paint()..color = const Color(0xFFC9A34B),
    );
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
