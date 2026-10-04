import 'dart:math' as math;

import 'package:electrosim_canvas/electrosim_canvas.dart';
import 'package:flutter/material.dart';

/// Point 5 pilot visual contract.
///
/// The 104x64 canvas is a hidden interaction/routing envelope only. It is not
/// part of the visible component. Every pilot owns its real front silhouette.
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

  static const String renderingMode = 'free_silhouette_front_vector';
  static const bool frontViewOnly = true;
  static const bool rasterAssetsAllowed = false;
  static const bool perspectiveAllowed = false;
  static const bool visibleBoundingBoxAllowed = false;

  static const Map<String, String> silhouetteByModel = <String, String>{
    'dc_voltage_source': 'industrial_power_supply_front',
    'voltage_source': 'industrial_power_supply_front',
    'switch': 'rocker_switch_front',
    'switch_spst': 'rocker_switch_front',
    'lamp': 'round_pilot_lamp_front',
    'breaker_dc': 'stepped_mcb_front',
    'breaker_ac1': 'stepped_mcb_front',
    'breaker': 'stepped_mcb_front',
    'push_button_no': 'round_pushbutton_front',
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

/// Free-silhouette orthographic front renderer.
///
/// There is deliberately no shared visible "component box". The canonical
/// canvas exists only to position the drawing and its terminals.
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
      canvas.saveLayer(
        const Rect.fromLTWH(-52, -32, 104, 64),
        Paint()..color = const Color(0x88FFFFFF),
      );
      canvas.restore();
    }
    canvas.restore();
  }

  Paint _stroke({
    Color color = const Color(0xFF263238),
    double width = 1.1,
  }) =>
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
    double size = 5.4,
    Color color = const Color(0xFF263238),
    FontWeight weight = FontWeight.w700,
  }) {
    final TextPainter tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: size,
          color: color,
          fontWeight: weight,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    tp.paint(canvas, Offset(center.dx - tp.width / 2, center.dy - tp.height / 2));
  }

  double _terminalHalfSpan() =>
      TerminalVisualProfile.horizontalHalfSpanForModel(
        modelType,
        size: _designSize,
      ) ??
      _designSize.width / 2;

  void _lead(
    Canvas canvas, {
    required bool left,
    required double bodyEdge,
    double y = 0,
  }) {
    final double terminalX = left ? -_terminalHalfSpan() : _terminalHalfSpan();
    final double edgeX = left ? -bodyEdge : bodyEdge;
    canvas.drawLine(
      Offset(edgeX, y),
      Offset(terminalX, y),
      Paint()
        ..color = const Color(0xFFB68E3E)
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.square,
    );
    if (showTerminals) {
      _terminal(canvas, Offset(terminalX, y));
    }
  }

  void _terminal(Canvas canvas, Offset center) {
    final Rect r = Rect.fromCircle(center: center, radius: 3.5);
    canvas.drawCircle(
      center,
      3.5,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-.3, -.3),
          colors: <Color>[
            Color(0xFFFFE7A1),
            Color(0xFFD1A040),
            Color(0xFF806020),
          ],
        ).createShader(r),
    );
    canvas.drawCircle(
      center,
      3.5,
      _stroke(color: const Color(0xFF5C4218), width: .8),
    );
    canvas.drawLine(
      center.translate(-1.4, 0),
      center.translate(1.4, 0),
      _stroke(color: const Color(0xFF493514), width: .7),
    );
  }

  void _screw(Canvas canvas, Offset center, {double radius = 2.8}) {
    final Rect r = Rect.fromCircle(center: center, radius: radius);
    canvas.drawCircle(
      center,
      radius,
      _linear(
        r,
        const <Color>[
          Color(0xFFF7F8F8),
          Color(0xFFB8C0C2),
          Color(0xFF707D81),
        ],
      ),
    );
    canvas.drawCircle(center, radius, _stroke(color: const Color(0xFF465257), width: .75));
    canvas.drawLine(
      center.translate(-1.4, 0),
      center.translate(1.4, 0),
      _stroke(color: const Color(0xFF465257), width: .65),
    );
    canvas.drawLine(
      center.translate(0, -1.4),
      center.translate(0, 1.4),
      _stroke(color: const Color(0xFF465257), width: .65),
    );
  }

  void _paintPowerSupply(Canvas canvas) {
    _lead(canvas, left: true, bodyEdge: 39);
    _lead(canvas, left: false, bodyEdge: 39);

    final Path chassis = Path()
      ..moveTo(-36, -29)
      ..lineTo(34, -29)
      ..lineTo(39, -24)
      ..lineTo(39, 24)
      ..lineTo(34, 29)
      ..lineTo(-36, 29)
      ..lineTo(-39, 25)
      ..lineTo(-39, -25)
      ..close();
    final Rect bounds = const Rect.fromLTWH(-39, -29, 78, 58);
    canvas.drawPath(
      chassis,
      _linear(
        bounds,
        const <Color>[
          Color(0xFFF4F6F6),
          Color(0xFFDDE4E5),
          Color(0xFFB7C4C7),
        ],
      ),
    );
    canvas.drawPath(chassis, _stroke(color: const Color(0xFF64777D), width: 1));

    final Path face = Path()
      ..moveTo(-30, -24)
      ..lineTo(28, -24)
      ..lineTo(33, -19)
      ..lineTo(33, 21)
      ..lineTo(29, 25)
      ..lineTo(-30, 25)
      ..close();
    canvas.drawPath(face, Paint()..color = const Color(0xFF07578F));
    canvas.drawPath(face, _stroke(color: const Color(0xFF043B62), width: .85));

    // Ventilation slots form the characteristic industrial PSU silhouette.
    for (final double x in <double>[-27, -19, -11, -3, 5, 13, 21]) {
      canvas.drawLine(
        Offset(x, -26.5),
        Offset(x + 4, -26.5),
        _stroke(color: const Color(0xFF839397), width: 1),
      );
    }

    final Path topBlock = Path()
      ..moveTo(-27, -21)
      ..lineTo(27, -21)
      ..lineTo(27, -10)
      ..lineTo(-27, -10)
      ..close();
    canvas.drawPath(topBlock, Paint()..color = const Color(0xFF37A75B));
    canvas.drawPath(topBlock, _stroke(color: const Color(0xFF1B6536), width: .7));
    for (final double x in <double>[-18, -6, 6, 18]) {
      _screw(canvas, Offset(x, -15.5), radius: 2.35);
    }

    final Path bottomBlock = Path()
      ..moveTo(-25, 15)
      ..lineTo(25, 15)
      ..lineTo(25, 23)
      ..lineTo(-25, 23)
      ..close();
    canvas.drawPath(bottomBlock, Paint()..color = const Color(0xFF339D55));
    canvas.drawPath(bottomBlock, _stroke(color: const Color(0xFF1B6536), width: .7));
    for (final double x in <double>[-16, 0, 16]) {
      _screw(canvas, Offset(x, 19), radius: 2.1);
    }

    _text(canvas, '24 V', const Offset(-8, 0), size: 7.4, color: Colors.white, weight: FontWeight.w800);
    _text(canvas, 'CC', const Offset(-8, 8), size: 4.9, color: const Color(0xFFD8ECF8));

    final Color ledColor =
        energized ? const Color(0xFF62EF7D) : const Color(0xFF65756E);
    if (energized) {
      canvas.drawCircle(
        const Offset(23, 3),
        4.4,
        Paint()..color = const Color(0x4462EF7D),
      );
    }
    canvas.drawCircle(const Offset(23, 3), 2.3, Paint()..color = ledColor);
    canvas.drawCircle(
      const Offset(23, 3),
      2.3,
      _stroke(color: const Color(0xFF143A24), width: .65),
    );

    // DIN/mounting ears break the generic rectangular silhouette.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-43, -8, 5, 16),
        const Radius.circular(1.5),
      ),
      Paint()..color = const Color(0xFFC8D1D3),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(38, -8, 5, 16),
        const Radius.circular(1.5),
      ),
      Paint()..color = const Color(0xFFC8D1D3),
    );
  }

  void _paintRockerSwitch(Canvas canvas) {
    _lead(canvas, left: true, bodyEdge: 27);
    _lead(canvas, left: false, bodyEdge: 27);

    final Path bezel = Path()
      ..moveTo(-21, -25)
      ..quadraticBezierTo(-26, -25, -27, -20)
      ..lineTo(-27, 20)
      ..quadraticBezierTo(-26, 25, -21, 25)
      ..lineTo(21, 25)
      ..quadraticBezierTo(26, 25, 27, 20)
      ..lineTo(27, -20)
      ..quadraticBezierTo(26, -25, 21, -25)
      ..close();
    final Rect bezelBounds = const Rect.fromLTWH(-27, -25, 54, 50);
    canvas.drawPath(
      bezel,
      _linear(
        bezelBounds,
        const <Color>[
          Color(0xFF454B4E),
          Color(0xFF202527),
          Color(0xFF101315),
        ],
      ),
    );
    canvas.drawPath(bezel, _stroke(color: const Color(0xFF070909), width: 1.1));

    // Snap-in clips are part of the real front outline.
    canvas.drawRect(const Rect.fromLTWH(-31, -7, 4, 14), Paint()..color = const Color(0xFF141719));
    canvas.drawRect(const Rect.fromLTWH(27, -7, 4, 14), Paint()..color = const Color(0xFF141719));

    final Rect rocker = const Rect.fromLTWH(-14.5, -19, 29, 38);
    final RRect rr = RRect.fromRectAndRadius(rocker, const Radius.circular(2.8));
    canvas.drawRRect(
      rr,
      _linear(
        rocker,
        closed
            ? const <Color>[Color(0xFF535A5D), Color(0xFF222729), Color(0xFF141719)]
            : const <Color>[Color(0xFF33383A), Color(0xFF1A1E20), Color(0xFF0E1112)],
      ),
    );
    canvas.drawRRect(rr, _stroke(color: const Color(0xFF080A0A), width: .9));
    canvas.drawLine(const Offset(-11, 0), const Offset(11, 0), _stroke(color: const Color(0xFF080A0A), width: .7));
    _text(canvas, 'I', const Offset(0, -9), size: 8, color: Colors.white);
    _text(canvas, 'O', const Offset(0, 9), size: 8, color: Colors.white);

    canvas.drawRect(const Rect.fromLTWH(-33, -4.5, 6, 9), Paint()..color = const Color(0xFFC9A34B));
    canvas.drawRect(const Rect.fromLTWH(27, -4.5, 6, 9), Paint()..color = const Color(0xFFC9A34B));
  }

  void _paintPushButton(Canvas canvas) {
    _lead(canvas, left: true, bodyEdge: 19);
    _lead(canvas, left: false, bodyEdge: 19);

    // Only the real circular bezel is visible; no square contact-block card.
    final Rect bezelRect = Rect.fromCircle(center: Offset.zero, radius: 18.8);
    canvas.drawCircle(
      Offset.zero,
      18.8,
      _linear(
        bezelRect,
        const <Color>[
          Color(0xFFF5F7F7),
          Color(0xFFCBD2D4),
          Color(0xFF879397),
        ],
      ),
    );
    canvas.drawCircle(Offset.zero, 18.8, _stroke(color: const Color(0xFF59666B), width: 1.05));

    // Front locking nut.
    canvas.drawCircle(Offset.zero, 16.1, Paint()..color = const Color(0xFF303638));
    canvas.drawCircle(Offset.zero, 16.1, _stroke(color: const Color(0xFF171B1D), width: .85));

    final double capR = pressed ? 12.3 : 13.2;
    final Rect capRect = Rect.fromCircle(center: Offset.zero, radius: capR);
    canvas.drawCircle(
      Offset.zero,
      capR,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-.3, -.35),
          radius: .9,
          colors: <Color>[
            Color(0xFF8AF0A3),
            Color(0xFF2ABD5B),
            Color(0xFF087330),
          ],
        ).createShader(capRect),
    );
    canvas.drawCircle(Offset.zero, capR, _stroke(color: const Color(0xFF075A27), width: 1));
    canvas.drawCircle(const Offset(-3.8, -4.2), 3, Paint()..color = const Color(0x55FFFFFF));

    // Two exposed contact tabs, seen from the front.
    canvas.drawRect(const Rect.fromLTWH(-24, -3.5, 5, 7), Paint()..color = const Color(0xFFC9A34B));
    canvas.drawRect(const Rect.fromLTWH(19, -3.5, 5, 7), Paint()..color = const Color(0xFFC9A34B));
  }

  void _paintBreaker(Canvas canvas) {
    _lead(canvas, left: true, bodyEdge: 32);
    _lead(canvas, left: false, bodyEdge: 32);

    // A stepped MCB outline replaces the former generic rectangle.
    final Path body = Path()
      ..moveTo(-17, -30)
      ..lineTo(17, -30)
      ..lineTo(17, -25)
      ..lineTo(23, -25)
      ..lineTo(23, -18)
      ..lineTo(29, -18)
      ..lineTo(29, 18)
      ..lineTo(23, 18)
      ..lineTo(23, 25)
      ..lineTo(17, 25)
      ..lineTo(17, 30)
      ..lineTo(-17, 30)
      ..lineTo(-17, 25)
      ..lineTo(-23, 25)
      ..lineTo(-23, 18)
      ..lineTo(-29, 18)
      ..lineTo(-29, -18)
      ..lineTo(-23, -18)
      ..lineTo(-23, -25)
      ..lineTo(-17, -25)
      ..close();
    final Rect bodyBounds = const Rect.fromLTWH(-29, -30, 58, 60);
    canvas.drawPath(
      body,
      _linear(
        bodyBounds,
        const <Color>[
          Color(0xFFFAFBFB),
          Color(0xFFEEF1F1),
          Color(0xFFD6DCDD),
        ],
      ),
    );
    canvas.drawPath(body, _stroke(color: const Color(0xFF66757A), width: 1));

    _screw(canvas, const Offset(0, -24), radius: 3.1);
    _screw(canvas, const Offset(0, 24), radius: 3.1);

    _text(canvas, 'C10', const Offset(0, -13), size: 5.2, weight: FontWeight.w800);
    _text(canvas, '230 V', const Offset(0, -7.5), size: 3.8, color: const Color(0xFF4C5B60));

    final bool isOpen = !closed && !tripped;
    final double leverY = tripped ? 8 : isOpen ? 9 : 2;
    final Rect lever = Rect.fromCenter(center: Offset(0, leverY), width: 16, height: 14);
    final RRect leverR = RRect.fromRectAndRadius(lever, const Radius.circular(1.8));
    canvas.drawRRect(
      leverR,
      _linear(
        lever,
        tripped
            ? const <Color>[Color(0xFFF0A079), Color(0xFFD25C34)]
            : const <Color>[Color(0xFF54A1EE), Color(0xFF1166BF)],
      ),
    );
    canvas.drawRRect(
      leverR,
      _stroke(
        color: tripped ? const Color(0xFF8A3A20) : const Color(0xFF0A4A8C),
        width: .85,
      ),
    );
    _text(
      canvas,
      tripped ? 'TRIP' : closed ? 'I' : 'O',
      Offset(0, leverY),
      size: tripped ? 4 : 6,
      color: Colors.white,
      weight: FontWeight.w800,
    );

    // Real projecting side connection ears.
    canvas.drawRect(const Rect.fromLTWH(-35, -4, 6, 8), Paint()..color = const Color(0xFFC9A34B));
    canvas.drawRect(const Rect.fromLTWH(29, -4, 6, 8), Paint()..color = const Color(0xFFC9A34B));
  }

  void _paintPilotLamp(Canvas canvas) {
    _lead(canvas, left: true, bodyEdge: 19.5);
    _lead(canvas, left: false, bodyEdge: 19.5);

    // Circular front only: bezel + lens, no square mounting plate.
    final Rect bezelRect = Rect.fromCircle(center: Offset.zero, radius: 19.5);
    canvas.drawCircle(
      Offset.zero,
      19.5,
      _linear(
        bezelRect,
        const <Color>[
          Color(0xFF545C5F),
          Color(0xFF292E30),
          Color(0xFF111416),
        ],
      ),
    );
    canvas.drawCircle(Offset.zero, 19.5, _stroke(color: const Color(0xFF090B0C), width: 1));

    final double phase = animationValue * math.pi * 2;
    final double pulse = .5 + .5 * math.sin(phase);
    if (energized) {
      canvas.drawCircle(
        Offset.zero,
        18 + pulse * 1.3,
        Paint()..color = Color.fromARGB((28 + pulse * 22).round(), 255, 46, 40),
      );
    }

    const double lensR = 15.5;
    final Rect lensRect = Rect.fromCircle(center: Offset.zero, radius: lensR);
    canvas.drawCircle(
      Offset.zero,
      lensR,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-.3, -.34),
          radius: .9,
          colors: energized
              ? const <Color>[Color(0xFFFFA39A), Color(0xFFFF2925), Color(0xFF9A0707)]
              : const <Color>[Color(0xFFBF635D), Color(0xFF8E2926), Color(0xFF571413)],
        ).createShader(lensRect),
    );
    canvas.drawCircle(Offset.zero, lensR, _stroke(color: const Color(0xFF5A0B0B), width: 1));

    for (double r = 6; r <= 13; r += 3.5) {
      canvas.drawCircle(Offset.zero, r, _stroke(color: const Color(0x55FFD1CC), width: .5));
    }
    canvas.drawCircle(const Offset(-4.3, -4.5), 3.1, Paint()..color = const Color(0x44FFFFFF));

    canvas.drawRect(const Rect.fromLTWH(-25, -3.5, 5.5, 7), Paint()..color = const Color(0xFFC9A34B));
    canvas.drawRect(const Rect.fromLTWH(19.5, -3.5, 5.5, 7), Paint()..color = const Color(0xFFC9A34B));
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
