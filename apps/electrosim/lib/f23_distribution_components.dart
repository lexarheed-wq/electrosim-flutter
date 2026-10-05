import 'dart:math' as math;

import 'package:flutter/material.dart';

enum F23DistributionDevice { isolator3p, isolator4p, breaker4p, terminalBlock5 }

@immutable
final class F23DistributionState {
  const F23DistributionState({
    this.closed = true,
    this.tripped = false,
    this.energized = false,
    this.currentA = 0,
  });
  final bool closed;
  final bool tripped;
  final bool energized;
  final double currentA;
}

abstract final class F23DistributionGeometry {
  static Size boardSizeFor(F23DistributionDevice device) => switch (device) {
    F23DistributionDevice.isolator3p => const Size(200, 230),
    F23DistributionDevice.isolator4p => const Size(240, 230),
    F23DistributionDevice.breaker4p => const Size(240, 230),
    F23DistributionDevice.terminalBlock5 => const Size(280, 210),
  };
}

class F23DistributionComponentView extends StatelessWidget {
  const F23DistributionComponentView({
    super.key,
    required this.device,
    required this.size,
    this.state = const F23DistributionState(),
  });
  final F23DistributionDevice device;
  final Size size;
  final F23DistributionState state;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size.width,
    height: size.height,
    child: CustomPaint(
      painter: _F23DistributionPainter(device: device, state: state),
    ),
  );
}

final class _F23DistributionPainter extends CustomPainter {
  const _F23DistributionPainter({required this.device, required this.state});
  final F23DistributionDevice device;
  final F23DistributionState state;

  @override
  void paint(Canvas canvas, Size size) {
    final _P p = _P(canvas, Offset.zero & size, state);
    switch (device) {
      case F23DistributionDevice.isolator3p:
        p.multipoleSwitch(poles: 3, breaker: false);
        return;
      case F23DistributionDevice.isolator4p:
        p.multipoleSwitch(poles: 4, breaker: false);
        return;
      case F23DistributionDevice.breaker4p:
        p.multipoleSwitch(poles: 4, breaker: true);
        return;
      case F23DistributionDevice.terminalBlock5:
        p.terminalBlock5();
        return;
    }
  }

  @override
  bool shouldRepaint(_F23DistributionPainter oldDelegate) =>
      oldDelegate.device != device ||
      oldDelegate.state.closed != state.closed ||
      oldDelegate.state.tripped != state.tripped ||
      oldDelegate.state.energized != state.energized ||
      oldDelegate.state.currentA != state.currentA;
}

final class _P {
  _P(this.canvas, this.rect, this.state);
  final Canvas canvas;
  final Rect rect;
  final F23DistributionState state;

  Offset get c => rect.center;
  double get w => rect.width;
  double get h => rect.height;
  double get s => rect.shortestSide;

  Paint get outline => Paint()
    ..color = const Color(0xFF2C3942)
    ..strokeWidth = math.max(1.2, s * .015)
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  Paint gradient(Rect target, List<Color> colors) => Paint()
    ..shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: colors,
    ).createShader(target);

  void text(
    String value,
    Offset center, {
    double? size,
    Color color = const Color(0xFF26363E),
  }) {
    final TextPainter tp = TextPainter(
      text: TextSpan(
        text: value,
        style: TextStyle(
          fontSize: size ?? math.max(7, h * .05),
          fontWeight: FontWeight.w700,
          color: color,
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

  Color phaseColor(int pole) => switch (pole) {
    0 => const Color(0xFF8B5A2B),
    1 => const Color(0xFF242A30),
    2 => const Color(0xFF777F86),
    _ => const Color(0xFF2563EB),
  };

  String topLabel(int pole, int poles) => switch (pole) {
    0 => '1L1',
    1 => '3L2',
    2 => '5L3',
    _ => poles == 4 ? 'N' : '',
  };

  String bottomLabel(int pole, int poles) => switch (pole) {
    0 => '2T1',
    1 => '4T2',
    2 => '6T3',
    _ => poles == 4 ? 'N' : '',
  };

  void terminal(
    Offset p,
    String label,
    Color color, {
    bool labelAbove = false,
  }) {
    final double r = math.max(3.8, s * .027);
    canvas.drawCircle(
      p,
      r,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-.35, -.35),
          colors: <Color>[
            Color.lerp(color, Colors.white, .40)!,
            color,
            Color.lerp(color, Colors.black, .33)!,
          ],
        ).createShader(Rect.fromCircle(center: p, radius: r)),
    );
    canvas.drawCircle(p, r, outline);
    canvas.drawLine(
      Offset(p.dx - r * .45, p.dy),
      Offset(p.dx + r * .45, p.dy),
      Paint()
        ..color = const Color(0xFF3D454A)
        ..strokeWidth = math.max(.8, r * .18),
    );
    text(
      label,
      p.translate(0, labelAbove ? -(r + 8) : r + 8),
      size: math.max(6, s * .039),
    );
  }

  void multipoleSwitch({required int poles, required bool breaker}) {
    final Rect body = Rect.fromCenter(
      center: c,
      width: w * .74,
      height: h * .72,
    );
    final RRect rr = RRect.fromRectAndRadius(body, Radius.circular(h * .035));
    canvas.drawRRect(
      rr.shift(Offset(0, h * .014)),
      Paint()..color = const Color(0x26000000),
    );
    canvas.drawRRect(
      rr,
      gradient(
        body,
        breaker
            ? const <Color>[Color(0xFFF7F8F6), Color(0xFFC9D0D2)]
            : const <Color>[Color(0xFFF4F5F2), Color(0xFFCDD2CF)],
      ),
    );
    canvas.drawRRect(rr, outline);

    final double step = body.width / poles;
    for (var pole = 0; pole < poles; pole++) {
      final double x = body.left + step * (pole + .5);
      final Offset top = Offset(x, rect.top + h * .075);
      final Offset bottom = Offset(x, rect.bottom - h * .075);
      terminal(top, topLabel(pole, poles), phaseColor(pole));
      terminal(
        bottom,
        bottomLabel(pole, poles),
        phaseColor(pole),
        labelAbove: true,
      );

      final Rect channel = Rect.fromCenter(
        center: Offset(x, c.dy + h * .005),
        width: step * .56,
        height: body.height * .46,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(channel, Radius.circular(h * .018)),
        Paint()..color = const Color(0xFFB6BEC2),
      );

      final bool effectiveClosed = state.closed && !state.tripped;
      final double leverY = state.tripped
          ? channel.center.dy
          : effectiveClosed
          ? channel.top + channel.height * .30
          : channel.bottom - channel.height * .30;
      final Rect lever = Rect.fromCenter(
        center: Offset(x, leverY),
        width: channel.width * .72,
        height: channel.height * .24,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(lever, Radius.circular(h * .012)),
        gradient(
          lever,
          breaker
              ? const <Color>[Color(0xFF515C63), Color(0xFF1E272C)]
              : const <Color>[Color(0xFF6B7478), Color(0xFF2F393D)],
        ),
      );
    }

    text(
      breaker ? 'DISJ. 4P' : 'SECTIONNEUR ${poles}P',
      Offset(c.dx, body.top + h * .055),
      size: h * .052,
    );
    final Color indicator = state.tripped
        ? const Color(0xFFD64A42)
        : state.closed
        ? const Color(0xFF3B9B5E)
        : const Color(0xFF9AA4A9);
    canvas.drawCircle(
      Offset(c.dx, body.bottom - h * .055),
      h * .018,
      Paint()..color = indicator,
    );
  }

  void terminalBlock5() {
    final Rect rail = Rect.fromCenter(
      center: c,
      width: w * .82,
      height: h * .56,
    );
    final RRect rr = RRect.fromRectAndRadius(rail, Radius.circular(h * .028));
    canvas.drawRRect(
      rr,
      gradient(rail, const <Color>[Color(0xFFF4F5F1), Color(0xFFD3D5CE)]),
    );
    canvas.drawRRect(rr, outline);

    const List<String> labels = <String>['L1', 'L2', 'L3', 'N', 'PE'];
    const List<Color> colors = <Color>[
      Color(0xFF8B5A2B),
      Color(0xFF242A30),
      Color(0xFF777F86),
      Color(0xFF2563EB),
      Color(0xFF2F8B57),
    ];
    final double step = rail.width / 5;
    for (var pole = 0; pole < 5; pole++) {
      final double x = rail.left + step * (pole + .5);
      final Rect block = Rect.fromCenter(
        center: Offset(x, c.dy),
        width: step * .82,
        height: rail.height * .82,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(block, Radius.circular(h * .018)),
        Paint()..color = const Color(0xFFE9ECE7),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(block, Radius.circular(h * .018)),
        Paint()
          ..color = colors[pole].withValues(alpha: .42)
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1.2, s * .012),
      );
      final Offset top = Offset(x, rect.top + h * .075);
      final Offset bottom = Offset(x, rect.bottom - h * .075);
      terminal(top, '${labels[pole]} IN', colors[pole]);
      terminal(bottom, '${labels[pole]} OUT', colors[pole], labelAbove: true);
      canvas.drawLine(
        top.translate(0, h * .035),
        bottom.translate(0, -h * .035),
        Paint()
          ..color = colors[pole]
          ..strokeWidth = math.max(2.2, s * .018),
      );
    }
  }
}
