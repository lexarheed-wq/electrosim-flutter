import 'dart:math' as math;

import 'package:electrosim_canvas/electrosim_canvas.dart';
import 'package:flutter/material.dart';

import 'f18_industrial_physical_plate.dart';

abstract final class F18ControlModuleVisuals {
  static bool supports(String modelType) => const {
    'timer_star_delta',
    'plc_ac3',
    'plc_dc',
  }.contains(modelType.toLowerCase());
}

/// Dedicated industrial renderings for the two AC3 control modules.
///
/// Palette art receives a shallow three-quarter extrusion; board art remains
/// frontal so its ports continue to line up with the canvas hit targets.
final class F18ControlModuleVisual extends StatelessWidget {
  const F18ControlModuleVisual({
    super.key,
    required this.modelType,
    required this.size,
    this.controlState = const <String, Object?>{},
    this.parameters = const <String, Object?>{},
    this.active = true,
    this.showTerminals = true,
  });

  final String modelType;
  final Size size;
  final Map<String, Object?> controlState;
  final Map<String, Object?> parameters;
  final bool active;
  final bool showTerminals;

  @override
  Widget build(BuildContext context) {
    final bool timer = modelType.toLowerCase() == 'timer_star_delta';
    final bool powered =
        active && controlState[timer ? 'timerActuated' : 'supplyValid'] == true;
    final String state = timer
        ? !powered
              ? 'hors tension'
              : controlState['timerNoClosed'] == true
              ? 'triangle actif'
              : controlState['timerNcClosed'] == true
              ? 'étoile active'
              : 'temporisation en cours'
        : controlState['programError'] == true
        ? 'défaut programme'
        : powered
        ? 'automate alimenté'
        : 'arrêté';
    return Semantics(
      label:
          '${timer ? 'Temporisateur étoile-triangle' : 'Automate programmable'}, $state',
      image: true,
      child: SizedBox(
        width: size.width,
        height: size.height,
        child: RepaintBoundary(
          child: CustomPaint(
            key: Key('control-module-${modelType.toLowerCase()}'),
            painter: _F18ControlModulePainter(
              modelType: modelType.toLowerCase(),
              controlState: controlState,
              parameters: parameters,
              active: active,
              showTerminals: showTerminals,
              perspective: F18PhysicalPresentationScope.perspectiveOf(context),
            ),
          ),
        ),
      ),
    );
  }
}

final class _F18ControlModulePainter extends CustomPainter {
  const _F18ControlModulePainter({
    required this.modelType,
    required this.controlState,
    required this.parameters,
    required this.active,
    required this.showTerminals,
    required this.perspective,
  });

  final String modelType;
  final Map<String, Object?> controlState;
  final Map<String, Object?> parameters;
  final bool active;
  final bool showTerminals;
  final bool perspective;

  static const _ink = Color(0xFF16232A);
  static const _caseLight = Color(0xFFF4F5F2);
  static const _caseMid = Color(0xFFD4D9D6);
  static const _green = Color(0xFF24C877);
  static const _amber = Color(0xFFFFB12C);
  static const _red = Color(0xFFFF493F);

  bool get isTimer => modelType == 'timer_star_delta';
  double get w => isTimer ? 180 : 300;
  double get h => isTimer ? 260 : 220;

  double _value(String key, double fallback) {
    final Object? raw = parameters[key];
    return raw is num && raw.toDouble().isFinite ? raw.toDouble() : fallback;
  }

  void _text(
    Canvas canvas,
    String value,
    Offset center,
    double fontSize, {
    Color color = _ink,
    FontWeight weight = FontWeight.w600,
    double maxWidth = double.infinity,
  }) {
    final TextPainter painter = TextPainter(
      text: TextSpan(
        text: value,
        style: TextStyle(
          color: color,
          fontFamily: 'Roboto',
          fontSize: fontSize,
          fontWeight: weight,
          height: 1,
          letterSpacing: .12,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: maxWidth);
    painter.paint(
      canvas,
      center - Offset(painter.width / 2, painter.height / 2),
    );
  }

  void _body(Canvas canvas) {
    final Rect front = Rect.fromLTWH(w * .055, h * .055, w * .89, h * .89);
    final RRect body = RRect.fromRectAndRadius(
      front,
      Radius.circular(w * .035),
    );
    canvas.drawShadow(Path()..addRRect(body), const Color(0x880A1116), 7, true);
    if (perspective) {
      final Offset depth = Offset(w * .045, -h * .018);
      final Path rightSide = Path()
        ..moveTo(front.right, front.top)
        ..lineTo(front.right + depth.dx, front.top + depth.dy)
        ..lineTo(front.right + depth.dx, front.bottom + depth.dy)
        ..lineTo(front.right, front.bottom)
        ..close();
      canvas.drawPath(
        rightSide,
        Paint()
          ..shader = const LinearGradient(
            colors: [Color(0xFF747D80), Color(0xFF343F44)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ).createShader(rightSide.getBounds()),
      );
      final Path topFace = Path()
        ..moveTo(front.topLeft.dx, front.top)
        ..lineTo(front.topLeft.dx + depth.dx, front.top + depth.dy)
        ..lineTo(front.right + depth.dx, front.top + depth.dy)
        ..lineTo(front.right, front.top)
        ..close();
      canvas.drawPath(
        topFace,
        Paint()
          ..shader = const LinearGradient(
            colors: [Color(0xFFE8EBE8), Color(0xFF9DA6A5)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ).createShader(topFace.getBounds()),
      );
    }
    canvas.drawRRect(
      body,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_caseLight, _caseMid, Color(0xFFB7BFBE)],
          stops: [0, .47, 1],
        ).createShader(front),
    );
    canvas.drawRRect(
      body,
      Paint()
        ..color = const Color(0xFF838D8E)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.15,
    );
    // A formed lower DIN-rail catch and shallow side ribs make the case read
    // as an installable industrial module at palette size.
    final Rect catchRect = Rect.fromLTWH(w * .26, h * .91, w * .48, h * .045);
    canvas.drawRRect(
      RRect.fromRectAndRadius(catchRect, Radius.circular(h * .012)),
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFF596468), Color(0xFF202A2F)],
        ).createShader(catchRect),
    );
    for (final double x in [w * .075, w * .925]) {
      for (final double y in [h * .29, h * .70]) {
        canvas.drawLine(
          Offset(x, y),
          Offset(x, y + h * .075),
          Paint()
            ..color = const Color(0x66828B8D)
            ..strokeWidth = w * .012,
        );
      }
    }
  }

  void _screw(Canvas canvas, Offset center, double radius) {
    canvas.drawCircle(
      center,
      radius * 1.25,
      Paint()..color = const Color(0xFF3A464A),
    );
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-.35, -.45),
          colors: [Color(0xFFF9FAF7), Color(0xFFB8C0BE), Color(0xFF667176)],
          stops: [0, .55, 1],
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
    );
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = const Color(0xFF526065)
        ..style = PaintingStyle.stroke
        ..strokeWidth = .65,
    );
    canvas.drawLine(
      center + Offset(-radius * .55, 0),
      center + Offset(radius * .55, 0),
      Paint()
        ..color = const Color(0xFF455055)
        ..strokeWidth = radius * .16,
    );
    canvas.drawLine(
      center + Offset(0, -radius * .55),
      center + Offset(0, radius * .55),
      Paint()
        ..color = const Color(0xFF455055)
        ..strokeWidth = radius * .16,
    );
  }

  void _terminal(Canvas canvas, int index, String label) {
    final Size size = Size(w, h);
    final Offset port =
        size.center(Offset.zero) +
        TerminalVisualProfile.terminalOffset(
          modelType: modelType,
          size: size,
          index: index,
          count: isTimer ? 5 : 10,
        );
    final double radius = isTimer ? 6.7 : 7.2;
    canvas.drawCircle(
      port,
      radius * 1.52,
      Paint()..color = const Color(0xFF5A6365),
    );
    canvas.drawCircle(
      port,
      radius * 1.19,
      Paint()..color = const Color(0xFF1E292E),
    );
    _screw(canvas, port, radius * .76);
    if (!showTerminals) return;
    final double labelY = port.dy < h / 2
        ? port.dy + radius * 2.1
        : port.dy - radius * 2.1;
    _text(
      canvas,
      label,
      Offset(port.dx, labelY),
      isTimer ? 6.0 : 7.1,
      color: _ink,
    );
  }

  void _led(
    Canvas canvas,
    Offset center, {
    required bool on,
    required Color color,
    double radius = 4,
  }) {
    canvas.drawCircle(
      center,
      radius * 1.65,
      Paint()..color = const Color(0xFF26343A),
    );
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = RadialGradient(
          colors: on
              ? [Colors.white, color, Color.lerp(color, _ink, .38)!]
              : [const Color(0xFF728080), const Color(0xFF384649)],
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
    );
    if (on) {
      canvas.drawCircle(
        center,
        radius * 2.7,
        Paint()
          ..shader = RadialGradient(
            colors: [color.withValues(alpha: .42), color.withValues(alpha: 0)],
          ).createShader(Rect.fromCircle(center: center, radius: radius * 2.7)),
      );
    }
  }

  void _dial(
    Canvas canvas,
    Offset center,
    double radius,
    String caption,
    String reading, {
    double angle = -.55,
  }) {
    canvas.drawCircle(
      center,
      radius * 1.18,
      Paint()..color = const Color(0xFF687477),
    );
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-.35, -.45),
          colors: [Color(0xFF59666A), Color(0xFF182329), Color(0xFF10191E)],
          stops: [0, .62, 1],
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
    );
    canvas.drawCircle(
      center,
      radius * .82,
      Paint()
        ..color = const Color(0xFF9AA4A2)
        ..style = PaintingStyle.stroke
        ..strokeWidth = .8,
    );
    for (int i = 0; i < 9; i++) {
      final double theta = math.pi * (1.12 + i * .095);
      final double inner = radius * .88;
      final double outer = radius * (i % 2 == 0 ? 1.08 : 1.0);
      canvas.drawLine(
        center + Offset(math.cos(theta) * inner, math.sin(theta) * inner),
        center + Offset(math.cos(theta) * outer, math.sin(theta) * outer),
        Paint()
          ..color = const Color(0xFFE0E4DF)
          ..strokeWidth = .75,
      );
    }
    final Offset tip =
        center +
        Offset(math.cos(angle) * radius * .6, math.sin(angle) * radius * .6);
    canvas.drawLine(
      center,
      tip,
      Paint()
        ..color = const Color(0xFFE9EBE6)
        ..strokeWidth = radius * .09,
    );
    canvas.drawCircle(
      center,
      radius * .12,
      Paint()..color = const Color(0xFFD9DEDA),
    );
    _text(
      canvas,
      caption,
      center + Offset(0, radius * 1.3),
      radius * .42,
      color: _ink,
      maxWidth: radius * 3.4,
    );
    _text(
      canvas,
      reading,
      center + Offset(0, radius * 1.73),
      radius * .36,
      color: const Color(0xFF37454A),
      maxWidth: radius * 3.8,
    );
  }

  void _timer(Canvas canvas) {
    final Rect face = Rect.fromLTWH(w * .14, h * .20, w * .72, h * .60);
    canvas.drawRRect(
      RRect.fromRectAndRadius(face, const Radius.circular(5)),
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFF324147), Color(0xFF172329), Color(0xFF3B494D)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(face),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(face.deflate(1.2), const Radius.circular(4)),
      Paint()
        ..color = const Color(0xFF829091)
        ..style = PaintingStyle.stroke
        ..strokeWidth = .65,
    );
    _text(
      canvas,
      'TEMPORISATEUR',
      Offset(w * .50, h * .245),
      8.2,
      color: Colors.white,
      weight: FontWeight.w700,
    );
    _text(
      canvas,
      'ETOILE  →  TRIANGLE',
      Offset(w * .50, h * .285),
      5.7,
      color: const Color(0xFFBEC8C6),
    );
    final double delay = _value('delaySeconds', 5.0);
    final double deadTime = _value('deadTimeSeconds', .05);
    final Offset first = Offset(w * .37, h * .49);
    final Offset second = Offset(w * .63, h * .49);
    _dial(
      canvas,
      first,
      w * .095,
      'DELAI',
      '${delay.toStringAsFixed(1)} s',
      angle: -math.pi * .26,
    );
    _dial(
      canvas,
      second,
      w * .095,
      'PAUSE',
      '${(deadTime * 1000).round()} ms',
      angle: -math.pi * .58,
    );
    final bool powered = active && controlState['timerActuated'] == true;
    final bool star = powered && controlState['timerNcClosed'] == true;
    final bool delta = powered && controlState['timerNoClosed'] == true;
    _led(
      canvas,
      Offset(w * .29, h * .69),
      on: powered,
      color: _green,
      radius: 3.4,
    );
    _text(canvas, 'U', Offset(w * .29, h * .735), 5.4, color: Colors.white);
    _led(
      canvas,
      Offset(w * .50, h * .69),
      on: star,
      color: _amber,
      radius: 3.4,
    );
    _text(canvas, 'Y', Offset(w * .50, h * .735), 5.4, color: Colors.white);
    _led(
      canvas,
      Offset(w * .71, h * .69),
      on: delta,
      color: _green,
      radius: 3.4,
    );
    _text(canvas, 'Δ', Offset(w * .71, h * .735), 5.4, color: Colors.white);
    if (showTerminals) {
      for (int i = 0; i < 5; i++) {
        _terminal(canvas, i, const ['A1', 'A2', '15', '16', '18'][i]);
      }
    }
  }

  void _plc(Canvas canvas) {
    final Rect fascia = Rect.fromLTWH(w * .07, h * .22, w * .86, h * .55);
    canvas.drawRRect(
      RRect.fromRectAndRadius(fascia, const Radius.circular(5)),
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFFE9ECE8), Color(0xFFB6BFBD), Color(0xFFD7DCDA)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(fascia),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(fascia, const Radius.circular(5)),
      Paint()
        ..color = const Color(0xFF798487)
        ..style = PaintingStyle.stroke
        ..strokeWidth = .9,
    );
    // Left communication bay: screened Ethernet jack and serial service port.
    final Rect comm = Rect.fromLTWH(w * .095, h * .285, w * .205, h * .415);
    canvas.drawRRect(
      RRect.fromRectAndRadius(comm, const Radius.circular(3)),
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFF414D51), Color(0xFF202B30)],
        ).createShader(comm),
    );
    final Rect jack = Rect.fromLTWH(w * .135, h * .42, w * .125, h * .12);
    canvas.drawRRect(
      RRect.fromRectAndRadius(jack, const Radius.circular(2)),
      Paint()..color = const Color(0xFF11191D),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(jack.deflate(w * .012), const Radius.circular(1)),
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFF77928B), Color(0xFF263735)],
        ).createShader(jack),
    );
    for (int i = 0; i < 8; i++) {
      canvas.drawLine(
        Offset(jack.left + w * (.025 + i * .011), jack.top + h * .018),
        Offset(jack.left + w * (.025 + i * .011), jack.top + h * .045),
        Paint()
          ..color = const Color(0xFFC7B985)
          ..strokeWidth = 1.1,
      );
    }
    _text(
      canvas,
      'ETHERNET',
      Offset(w * .197, h * .57),
      5.6,
      color: Colors.white,
    );
    final Rect usb = Rect.fromLTWH(w * .15, h * .615, w * .095, h * .035);
    canvas.drawRRect(
      RRect.fromRectAndRadius(usb, const Radius.circular(2)),
      Paint()..color = const Color(0xFF313B3F),
    );
    _text(
      canvas,
      'SERVICE',
      Offset(w * .197, h * .68),
      5.0,
      color: Colors.white,
    );

    final Rect central = Rect.fromLTWH(w * .33, h * .285, w * .33, h * .415);
    canvas.drawRRect(
      RRect.fromRectAndRadius(central, const Radius.circular(3)),
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFF536267), Color(0xFF29363B)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(central),
    );
    _text(
      canvas,
      'AUTOMATE',
      Offset(w * .495, h * .37),
      9,
      color: Colors.white,
      weight: FontWeight.w700,
    );
    _text(
      canvas,
      'LOGIQUE 24 V CC',
      Offset(w * .495, h * .425),
      6.5,
      color: const Color(0xFFD6DCD8),
    );
    _text(
      canvas,
      'LADDER  ·  4 E / 4 S',
      Offset(w * .495, h * .68),
      6.0,
      color: const Color(0xFFB9C3C0),
    );

    final bool powered = active && controlState['supplyValid'] == true;
    final bool run = powered && active && controlState['programError'] != true;
    final Rect status = Rect.fromLTWH(w * .69, h * .285, w * .215, h * .415);
    canvas.drawRRect(
      RRect.fromRectAndRadius(status, const Radius.circular(3)),
      Paint()..color = const Color(0xFF26343A),
    );
    final List<(String, bool, Color)> statusLeds = [
      ('PWR', powered, _green),
      ('RUN', run, _green),
      ('ERR', controlState['programError'] == true, _red),
    ];
    for (int i = 0; i < statusLeds.length; i++) {
      final double y = h * (.36 + i * .075);
      _led(
        canvas,
        Offset(w * .725, y),
        on: statusLeds[i].$2,
        color: statusLeds[i].$3,
        radius: 3.2,
      );
      _text(
        canvas,
        statusLeds[i].$1,
        Offset(w * .77, y),
        5.2,
        color: Colors.white,
        maxWidth: w * .08,
      );
    }
    _text(
      canvas,
      'INPUTS',
      Offset(w * .825, h * .61),
      5.0,
      color: const Color(0xFFCCD4D0),
    );
    _text(
      canvas,
      'OUTPUTS',
      Offset(w * .825, h * .665),
      5.0,
      color: const Color(0xFFCCD4D0),
    );
    for (int i = 0; i < 4; i++) {
      final double x = w * (.79 + i * .028);
      _led(
        canvas,
        Offset(x, h * .635),
        on: controlState['I$i'] == true,
        color: const Color(0xFF57C97E),
        radius: 2.1,
      );
      _led(
        canvas,
        Offset(x, h * .69),
        on: controlState['Q$i'] == true,
        color: const Color(0xFFFFB950),
        radius: 2.1,
      );
    }
    if (showTerminals) {
      for (int i = 0; i < 6; i++) {
        _terminal(canvas, i, const ['L+', 'M', 'I0', 'I1', 'I2', 'I3'][i]);
      }
      for (int i = 0; i < 4; i++) {
        _terminal(canvas, i + 6, 'Q$i');
      }
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    canvas.save();
    canvas.scale(size.width / w, size.height / h);
    _body(canvas);
    if (isTimer) {
      _timer(canvas);
    } else {
      _plc(canvas);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_F18ControlModulePainter old) =>
      old.modelType != modelType ||
      old.perspective != perspective ||
      old.active != active ||
      old.showTerminals != showTerminals ||
      old.controlState != controlState ||
      old.parameters != parameters;
}
