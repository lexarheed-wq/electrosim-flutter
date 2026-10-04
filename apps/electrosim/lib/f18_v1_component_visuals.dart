import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Five-component pilot ported from the V1 C31 visual language.
///
/// Presentation only: electrical state remains owned by the Flutter/Dart
/// runtime and is passed in as explicit visual state.
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

  static const Size _designSize = Size(104, 64);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(size.width / _designSize.width, size.height / _designSize.height);
    if (!enabled) {
      canvas.saveLayer(
        Offset.zero & _designSize,
        Paint()..color = const Color.fromARGB(112, 255, 255, 255),
      );
    }

    switch (modelType.toLowerCase()) {
      case 'dc_voltage_source':
      case 'voltage_source':
        _paintSource(canvas);
      case 'switch':
      case 'switch_spst':
        _paintSwitch(canvas, push: false);
      case 'lamp':
        _paintLamp(canvas);
      case 'breaker_dc':
      case 'breaker_ac1':
      case 'breaker':
        _paintBreaker(canvas);
      case 'push_button_no':
        _paintSwitch(canvas, push: true);
    }

    if (!enabled) canvas.restore();
    canvas.restore();
  }

  Paint _stroke({
    Color color = const Color(0xFF445B63),
    double width = 1.8,
  }) =>
      Paint()
        ..color = color
        ..strokeWidth = width
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

  Paint _metal(Rect rect) => Paint()
    ..shader = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: <Color>[
        Color(0xFFF0F4F4),
        Color(0xFFCCD6D8),
        Color(0xFF8CA0A7),
      ],
      stops: <double>[0, .55, 1],
    ).createShader(rect);

  Paint _dark(Rect rect) => Paint()
    ..shader = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: <Color>[Color(0xFF43545B), Color(0xFF172429)],
    ).createShader(rect);

  void _round(
    Canvas canvas,
    Rect rect,
    double radius,
    Paint fill, {
    Color border = const Color(0xFF445B63),
    double borderWidth = 1.8,
  }) {
    final RRect rr = RRect.fromRectAndRadius(rect, Radius.circular(radius));
    canvas.drawRRect(
      rr.shift(const Offset(0, 1.6)),
      Paint()..color = const Color(0x33000000),
    );
    canvas.drawRRect(rr, fill);
    canvas.drawRRect(rr, _stroke(color: border, width: borderWidth));
  }

  void _lead(Canvas canvas, double bodyLeft, double bodyRight) {
    final Paint base = _stroke(color: const Color(0xFF556970), width: 2.2);
    canvas.drawLine(Offset(-52, 0), Offset(bodyLeft, 0), base);
    canvas.drawLine(Offset(bodyRight, 0), const Offset(52, 0), base);
    final Paint highlight = _stroke(color: const Color(0xFFBAC8CC), width: .7);
    canvas.drawLine(Offset(-48, -0.8), Offset(bodyLeft, -0.8), highlight);
    canvas.drawLine(Offset(bodyRight, -0.8), const Offset(48, -0.8), highlight);
    if (showTerminals) {
      _terminal(canvas, const Offset(-52, 0));
      _terminal(canvas, const Offset(52, 0));
    }
  }

  void _terminal(Canvas canvas, Offset center) {
    canvas.drawCircle(
      center.translate(0, 1),
      4.5,
      Paint()..color = const Color(0x33000000),
    );
    final Rect r = Rect.fromCircle(center: center, radius: 4.2);
    canvas.drawCircle(
      center,
      4.2,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-.35, -.35),
          colors: <Color>[
            Color(0xFFFFF2BF),
            Color(0xFFD4A44B),
            Color(0xFF7C5927),
          ],
        ).createShader(r),
    );
    canvas.drawCircle(
      center,
      4.2,
      _stroke(color: const Color(0xFF49371F), width: 1.15),
    );
    canvas.drawCircle(center, 1.45, Paint()..color = const Color(0xFF4D3A22));
  }

  void _text(
    Canvas canvas,
    String text,
    Offset center, {
    double size = 8,
    Color color = const Color(0xFF273237),
    FontWeight weight = FontWeight.w800,
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

  void _statusLed(Canvas canvas, Offset center, bool on, {bool fault = false}) {
    final Color color = fault
        ? const Color(0xFFE56A4A)
        : on
            ? const Color(0xFF72D99A)
            : const Color(0xFF74858A);
    if (on || fault) {
      canvas.drawCircle(
        center,
        5.3,
        Paint()..color = color.withValues(alpha: 55 / 255),
      );
    }
    canvas.drawCircle(center, 3.2, Paint()..color = color);
    canvas.drawCircle(
      center,
      3.2,
      _stroke(color: const Color(0xFF33474D), width: .9),
    );
  }

  void _paintSource(Canvas canvas) {
    const Rect body = Rect.fromLTWH(-41, -29, 82, 58);
    _lead(canvas, body.left, body.right);
    _round(canvas, body, 8, _metal(body));

    const Rect display = Rect.fromLTWH(-29, -21, 58, 22);
    _round(
      canvas,
      display,
      4,
      Paint()..color = const Color(0xFF17272D),
      border: const Color(0xFF0A1418),
      borderWidth: 1.4,
    );
    _text(
      canvas,
      '24.0 V',
      const Offset(0, -10),
      size: 9.5,
      color: energized ? const Color(0xFF79DCA0) : const Color(0xFF668078),
    );

    for (final (Offset, Color) item in <(Offset, Color)>[
      (const Offset(-20, 16), const Color(0xFFD8524B)),
      (const Offset(20, 16), const Color(0xFF171C1E)),
    ]) {
      final Offset p = item.$1;
      canvas.drawCircle(p, 8, Paint()..color = const Color(0xFF293A40));
      canvas.drawCircle(p, 4, Paint()..color = item.$2);
      canvas.drawCircle(
        p,
        8,
        _stroke(color: const Color(0xFF18272C), width: 1),
      );
    }
    _text(canvas, '+', const Offset(-20, 16), size: 5.8, color: Colors.white);
    _text(canvas, '−', const Offset(20, 16), size: 5.8, color: Colors.white);
    _statusLed(canvas, const Offset(33, -22), energized);
  }

  void _paintSwitch(Canvas canvas, {required bool push}) {
    const Rect body = Rect.fromLTWH(-26, -26, 52, 52);
    _lead(canvas, body.left, body.right);
    _round(
      canvas,
      body,
      9,
      _metal(body),
      border: const Color(0xFF667B81),
      borderWidth: 1.8,
    );

    const Rect well = Rect.fromLTWH(-15, -20, 30, 38);
    canvas.drawRRect(
      RRect.fromRectAndRadius(well, const Radius.circular(9)),
      _dark(well),
    );

    final bool stateClosed = push ? pressed : closed;
    final double knobY = stateClosed ? 4 : -12;
    final Rect knob = Rect.fromCenter(
      center: Offset(0, knobY),
      width: 22,
      height: 16,
    );
    final RRect knobR =
        RRect.fromRectAndRadius(knob, const Radius.circular(5));
    canvas.drawRRect(
      knobR,
      Paint()
        ..color = stateClosed
            ? const Color(0xFF5CBD79)
            : const Color(0xFF76868A),
    );
    canvas.drawRRect(
      knobR,
      _stroke(color: const Color(0xFF18262A), width: 1.4),
    );
    canvas.drawCircle(
      Offset(0, knobY - 2),
      4,
      Paint()..color = const Color(0xB8DFE9E6),
    );

    if (push) {
      final double depression = pressed ? 2.5 : 0;
      final Rect cap = Rect.fromCenter(
        center: Offset(0, -24 + depression),
        width: 26,
        height: 7,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(cap, const Radius.circular(3.5)),
        Paint()
          ..color = pressed
              ? const Color(0xFF42B769)
              : const Color(0xFF55D67A),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(cap, const Radius.circular(3.5)),
        _stroke(color: const Color(0xFF17663A), width: 1.2),
      );
      canvas.drawLine(
        Offset(0, cap.bottom),
        Offset(0, -20 + depression),
        _stroke(color: const Color(0xFF42575E), width: 2),
      );
    }

    _text(
      canvas,
      push ? 'NO' : (closed ? 'I' : 'O'),
      const Offset(0, 22),
      size: 7.2,
      color: stateClosed
          ? const Color(0xFF21613B)
          : const Color(0xFF273237),
    );
  }

  void _paintLamp(Canvas canvas) {
    const double bulbR = 22;
    const Offset bulb = Offset(0, -7);
    _lead(canvas, -bulbR, bulbR);

    final double phase = animationValue * math.pi * 2;
    final double pulse = .5 + .5 * math.sin(phase);
    if (energized) {
      canvas.drawCircle(
        bulb,
        29 + pulse * 3.5,
        Paint()
          ..color = Color.fromARGB(
            (28 + pulse * 24).round(),
            255,
            216,
            107,
          ),
      );
      canvas.drawCircle(
        bulb,
        25.5,
        Paint()..color = const Color(0x55FFD86B),
      );
    }
    canvas.drawCircle(
      bulb,
      bulbR,
      Paint()
        ..color = energized
            ? const Color(0xFFFFE49A)
            : const Color(0xFFDBE1DF),
    );
    canvas.drawCircle(
      bulb,
      bulbR,
      _stroke(color: const Color(0xFF67777B), width: 2),
    );
    final Path filament = Path()
      ..moveTo(-10, -10)
      ..quadraticBezierTo(0, 3, 10, -10);
    canvas.drawPath(
      filament,
      _stroke(
        color: energized
            ? const Color(0xFFF0A84B)
            : const Color(0xFF7A8586),
        width: 2,
      ),
    );

    const Rect base = Rect.fromLTWH(-12, 16, 24, 17);
    _round(
      canvas,
      base,
      3,
      Paint()..color = const Color(0xFF687E84),
      border: const Color(0xFF35494F),
      borderWidth: 1.5,
    );
  }

  void _paintBreaker(Canvas canvas) {
    const Rect body = Rect.fromLTWH(-32, -28, 64, 56);
    _lead(canvas, body.left, body.right);
    _round(
      canvas,
      body,
      6,
      _metal(body),
      border: const Color(0xFF65777C),
      borderWidth: 1.8,
    );

    const Rect top = Rect.fromLTWH(-19, -23, 38, 10);
    canvas.drawRRect(
      RRect.fromRectAndRadius(top, const Radius.circular(2)),
      Paint()..color = const Color(0xFFEEF2F1),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(top, const Radius.circular(2)),
      _stroke(color: const Color(0xFFA7B2B4), width: .8),
    );

    final bool open = !closed && !tripped;
    final double leverY = tripped ? 2 : open ? 9 : -7;
    final Rect lever = Rect.fromCenter(
      center: Offset(0, leverY),
      width: 12,
      height: 20,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(lever, const Radius.circular(3)),
      Paint()
        ..color = tripped
            ? const Color(0xFFDB7047)
            : open
                ? const Color(0xFF38474B)
                : const Color(0xFF232D31),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(lever, const Radius.circular(3)),
      _stroke(color: const Color(0xFF0D1517), width: 1.2),
    );

    final String stateText = tripped ? 'TRIP' : open ? 'O' : 'I';
    _text(
      canvas,
      'Q · $stateText',
      const Offset(0, -18),
      size: 6.5,
    );
    _statusLed(
      canvas,
      const Offset(0, 21),
      closed && !tripped,
      fault: tripped,
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
