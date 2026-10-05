import 'dart:math' as math;

import 'package:flutter/material.dart';

enum F15SourcePvDevice {
  dcCurrentSource,
  acVoltageSource,
  acCurrentSource,
  pvArray,
  pvInverter,
  pvLoad,
}

@immutable
final class F15SourcePvState {
  const F15SourcePvState({
    this.active = true,
    this.energized = false,
    this.currentA = 0,
    this.voltageV = 0,
    this.animationValue = 0,
    this.variantKey,
  });

  final bool active;
  final bool energized;
  final double currentA;
  final double voltageV;
  final double animationValue;
  final String? variantKey;
}

abstract final class F15SourcePvGeometry {
  static Size boardSizeFor(F15SourcePvDevice device) => switch (device) {
        F15SourcePvDevice.dcCurrentSource => const Size(140, 160),
        F15SourcePvDevice.acVoltageSource => const Size(140, 160),
        F15SourcePvDevice.acCurrentSource => const Size(140, 160),
        F15SourcePvDevice.pvArray => const Size(220, 170),
        F15SourcePvDevice.pvInverter => const Size(190, 230),
        F15SourcePvDevice.pvLoad => const Size(170, 160),
      };
}

class F15SourcePvComponentView extends StatelessWidget {
  const F15SourcePvComponentView({
    super.key,
    required this.device,
    required this.size,
    this.state = const F15SourcePvState(),
  });

  final F15SourcePvDevice device;
  final Size size;
  final F15SourcePvState state;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size.width,
        height: size.height,
        child: CustomPaint(
          painter: _F15SourcePvPainter(device: device, state: state),
        ),
      );
}

final class _F15SourcePvPainter extends CustomPainter {
  const _F15SourcePvPainter({required this.device, required this.state});

  final F15SourcePvDevice device;
  final F15SourcePvState state;

  @override
  void paint(Canvas canvas, Size size) {
    final _P p = _P(canvas, Offset.zero & size, state);
    switch (device) {
      case F15SourcePvDevice.dcCurrentSource:
        p.source(ac: false, currentSource: true);
      case F15SourcePvDevice.acVoltageSource:
        p.source(ac: true, currentSource: false);
      case F15SourcePvDevice.acCurrentSource:
        p.source(ac: true, currentSource: true);
      case F15SourcePvDevice.pvArray:
        p.pvArray();
      case F15SourcePvDevice.pvInverter:
        p.pvInverter();
      case F15SourcePvDevice.pvLoad:
        p.pvLoad();
    }
  }

  @override
  bool shouldRepaint(_F15SourcePvPainter oldDelegate) =>
      oldDelegate.device != device ||
      oldDelegate.state.active != state.active ||
      oldDelegate.state.energized != state.energized ||
      oldDelegate.state.currentA != state.currentA ||
      oldDelegate.state.voltageV != state.voltageV ||
      oldDelegate.state.animationValue != state.animationValue ||
      oldDelegate.state.variantKey != state.variantKey;
}

final class _P {
  _P(this.canvas, this.rect, this.state);

  final Canvas canvas;
  final Rect rect;
  final F15SourcePvState state;

  Offset get c => rect.center;
  double get w => rect.width;
  double get h => rect.height;
  double get s => rect.shortestSide;

  Paint get outline => Paint()
    ..color = const Color(0xFF263746)
    ..strokeWidth = math.max(1.1, s * .018)
    ..style = PaintingStyle.stroke
    ..strokeJoin = StrokeJoin.round
    ..strokeCap = StrokeCap.round;

  Paint grad(Rect target, List<Color> colors) => Paint()
    ..shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: colors,
    ).createShader(target);

  void housing(Rect body, {List<Color>? colors, double radius = 8}) {
    final RRect rr = RRect.fromRectAndRadius(body, Radius.circular(radius));
    canvas.drawRRect(
      rr.shift(Offset(0, math.max(1.5, h * .018))),
      Paint()..color = const Color(0x26000000),
    );
    canvas.drawRRect(
      rr,
      grad(
        body,
        colors ??
            const <Color>[Color(0xFFF8FAFB), Color(0xFFD3DDE3)],
      ),
    );
    canvas.drawRRect(rr, outline);
  }

  void terminal(Offset p, Color color, String label) {
    final double r = math.max(3.3, s * .035);
    canvas.drawCircle(p, r * 1.25, Paint()..color = const Color(0xFF202A31));
    canvas.drawCircle(p, r, Paint()..color = color);
    canvas.drawCircle(p, r, outline);
    text(
      label,
      p.translate(0, -r - 8),
      size: math.max(6, s * .047),
      color: const Color(0xFF34454F),
    );
  }

  void text(
    String value,
    Offset center, {
    double? size,
    Color color = const Color(0xFF22313D),
    FontWeight weight = FontWeight.w700,
  }) {
    final TextPainter tp = TextPainter(
      text: TextSpan(
        text: value,
        style: TextStyle(
          color: color,
          fontSize: size ?? math.max(7, h * .065),
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

  void source({required bool ac, required bool currentSource}) {
    final Rect body = Rect.fromCenter(
      center: Offset(c.dx, c.dy - h * .03),
      width: w * .76,
      height: h * .76,
    );
    housing(
      body,
      colors: const <Color>[Color(0xFFEDF2F5), Color(0xFFB9C7D0)],
      radius: h * .055,
    );
    final Rect screen = Rect.fromLTWH(
      body.left + body.width * .10,
      body.top + body.height * .10,
      body.width * .80,
      body.height * .34,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(screen, Radius.circular(h * .028)),
      Paint()..color = const Color(0xFF09242B),
    );
    final String phase = switch (state.variantKey) {
      'ac-l1' => 'L1',
      'ac-l2' => 'L2',
      'ac-l3' => 'L3',
      _ => ac ? '1φ' : 'CC',
    };
    final String value = currentSource
        ? '${state.currentA.abs().toStringAsFixed(2)} A'
        : '${state.voltageV.abs().toStringAsFixed(0)} V';
    text(
      value,
      screen.center.translate(0, -screen.height * .09),
      size: h * .11,
      color: const Color(0xFF8FF7D4),
    );
    text(
      phase,
      screen.center.translate(0, screen.height * .25),
      size: h * .07,
      color: const Color(0xFF8CCFE3),
    );

    final Offset a = Offset(c.dx - w * .18, rect.bottom - h * .10);
    final Offset b = Offset(c.dx + w * .18, rect.bottom - h * .10);
    if (ac) {
      terminal(a, const Color(0xFF8B5A2B), phase == '1φ' ? 'L' : phase);
      terminal(b, const Color(0xFF2563EB), 'N');
    } else {
      terminal(a, const Color(0xFFE65353), '+');
      terminal(b, const Color(0xFF111827), '−');
    }

    final double symbolR = h * .085;
    final Offset symbol = Offset(c.dx, body.bottom - h * .15);
    canvas.drawCircle(symbol, symbolR, Paint()..color = const Color(0xFFF7FAFB));
    canvas.drawCircle(symbol, symbolR, outline);
    if (currentSource) {
      canvas.drawLine(
        symbol.translate(0, symbolR * .52),
        symbol.translate(0, -symbolR * .52),
        Paint()
          ..color = const Color(0xFF354650)
          ..strokeWidth = math.max(1.3, s * .015)
          ..strokeCap = StrokeCap.round,
      );
      final Path arrow = Path()
        ..moveTo(symbol.dx, symbol.dy - symbolR * .62)
        ..lineTo(symbol.dx - symbolR * .22, symbol.dy - symbolR * .28)
        ..lineTo(symbol.dx + symbolR * .22, symbol.dy - symbolR * .28)
        ..close();
      canvas.drawPath(arrow, Paint()..color = const Color(0xFF354650));
    } else if (ac) {
      final Path wave = Path();
      for (var i = 0; i <= 24; i++) {
        final double t = i / 24;
        final Offset p = Offset(
          symbol.dx - symbolR * .58 + t * symbolR * 1.16,
          symbol.dy + math.sin(t * math.pi * 2) * symbolR * .28,
        );
        if (i == 0) {
          wave.moveTo(p.dx, p.dy);
        } else {
          wave.lineTo(p.dx, p.dy);
        }
      }
      canvas.drawPath(
        wave,
        Paint()
          ..color = const Color(0xFF354650)
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1.2, s * .014),
      );
    }
  }

  void pvArray() {
    final Rect frame = Rect.fromCenter(
      center: Offset(c.dx, c.dy - h * .05),
      width: w * .78,
      height: h * .66,
    );
    final RRect rr = RRect.fromRectAndRadius(frame, Radius.circular(h * .025));
    canvas.drawRRect(
      rr,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Color(0xFF215B80),
            Color(0xFF0D3553),
            Color(0xFF081F34),
          ],
        ).createShader(frame),
    );
    canvas.drawRRect(
      rr,
      Paint()
        ..color = const Color(0xFFAFC0CB)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(2, s * .022),
    );

    const int cols = 6;
    const int rows = 4;
    for (var i = 1; i < cols; i++) {
      final double x = frame.left + frame.width * i / cols;
      canvas.drawLine(
        Offset(x, frame.top),
        Offset(x, frame.bottom),
        Paint()
          ..color = const Color(0x886CA4C5)
          ..strokeWidth = math.max(.7, s * .006),
      );
    }
    for (var i = 1; i < rows; i++) {
      final double y = frame.top + frame.height * i / rows;
      canvas.drawLine(
        Offset(frame.left, y),
        Offset(frame.right, y),
        Paint()
          ..color = const Color(0x886CA4C5)
          ..strokeWidth = math.max(.7, s * .006),
      );
    }

    final Offset pos = Offset(c.dx - w * .14, rect.bottom - h * .08);
    final Offset neg = Offset(c.dx + w * .14, rect.bottom - h * .08);
    terminal(pos, const Color(0xFFE65353), '+');
    terminal(neg, const Color(0xFF111827), '−');
    text(
      state.energized
          ? '${state.voltageV.toStringAsFixed(0)} V · ${state.currentA.toStringAsFixed(1)} A'
          : 'PV',
      Offset(c.dx, frame.bottom + h * .08),
      size: h * .065,
    );
  }

  void pvInverter() {
    final Rect body = Rect.fromCenter(
      center: c,
      width: w * .68,
      height: h * .74,
    );
    housing(
      body,
      colors: const <Color>[Color(0xFFF7FAF8), Color(0xFFD4DED8)],
      radius: h * .05,
    );
    final Rect display = Rect.fromLTWH(
      body.left + body.width * .16,
      body.top + body.height * .12,
      body.width * .68,
      body.height * .17,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(display, Radius.circular(h * .02)),
      Paint()..color = const Color(0xFF15362F),
    );
    text(
      state.energized ? '${state.voltageV.toStringAsFixed(0)} V AC' : 'STANDBY',
      display.center,
      size: h * .055,
      color: const Color(0xFF91F0C7),
    );
    final Offset centerSymbol = Offset(c.dx, c.dy - h * .02);
    final double r = h * .10;
    canvas.drawCircle(centerSymbol, r, Paint()..color = const Color(0xFFE5ECE8));
    canvas.drawCircle(centerSymbol, r, outline);
    text('DC', centerSymbol.translate(-r * .75, 0), size: h * .045);
    text('AC', centerSymbol.translate(r * .75, 0), size: h * .045);
    canvas.drawLine(
      centerSymbol.translate(-r * .34, 0),
      centerSymbol.translate(r * .34, 0),
      Paint()
        ..color = const Color(0xFF2C6B59)
        ..strokeWidth = math.max(2, s * .018),
    );
    final Offset dcP = Offset(c.dx - w * .19, rect.top + h * .08);
    final Offset dcN = Offset(c.dx + w * .19, rect.top + h * .08);
    final Offset line = Offset(c.dx - w * .19, rect.bottom - h * .08);
    final Offset neutral = Offset(c.dx + w * .19, rect.bottom - h * .08);
    terminal(dcP, const Color(0xFFE65353), 'DC+');
    terminal(dcN, const Color(0xFF111827), 'DC−');
    terminal(line, const Color(0xFF8B5A2B), 'L');
    terminal(neutral, const Color(0xFF2563EB), 'N');
  }

  void pvLoad() {
    final Rect body = Rect.fromCenter(
      center: c,
      width: w * .62,
      height: h * .58,
    );
    housing(
      body,
      colors: const <Color>[Color(0xFFE9ECEF), Color(0xFF929EA6)],
      radius: h * .05,
    );
    final Offset line = Offset(c.dx - w * .16, rect.bottom - h * .09);
    final Offset neutral = Offset(c.dx + w * .16, rect.bottom - h * .09);
    terminal(line, const Color(0xFF8B5A2B), 'L');
    terminal(neutral, const Color(0xFF2563EB), 'N');
    final Path zig = Path()
      ..moveTo(body.left + body.width * .18, c.dy)
      ..lineTo(body.left + body.width * .30, c.dy - h * .08)
      ..lineTo(body.left + body.width * .42, c.dy + h * .08)
      ..lineTo(body.left + body.width * .54, c.dy - h * .08)
      ..lineTo(body.left + body.width * .66, c.dy + h * .08)
      ..lineTo(body.right - body.width * .18, c.dy);
    canvas.drawPath(
      zig,
      Paint()
        ..color = state.energized
            ? const Color(0xFFD86926)
            : const Color(0xFF43525B)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(2, s * .022)
        ..strokeJoin = StrokeJoin.round,
    );
    text(
      'CHARGE',
      Offset(c.dx, body.top + h * .08),
      size: h * .06,
    );
  }
}
