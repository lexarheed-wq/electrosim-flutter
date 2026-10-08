import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Genuine replacement artwork for the eight original educational devices.
/// Does not introduce electrical ports or change their world coordinates.
enum IndustrialDevice {
  supply,
  breaker,
  toggle,
  button,
  lamp,
  fan,
  motor,
  coil,
}

abstract final class IndustrialDeviceContract {
  static IndustrialDevice? resolve(String type) => switch (type.toLowerCase()) {
    'dc_voltage_source' || 'voltage_source' => IndustrialDevice.supply,
    'breaker_dc' || 'breaker_ac1' || 'breaker' => IndustrialDevice.breaker,
    'switch' || 'switch_spst' => IndustrialDevice.toggle,
    'push_button_no' => IndustrialDevice.button,
    'lamp' => IndustrialDevice.lamp,
    'fan_dc' => IndustrialDevice.fan,
    'motor_dc' => IndustrialDevice.motor,
    'relay_coil' => IndustrialDevice.coil,
    _ => null,
  };

  static Size designSize(IndustrialDevice device) => switch (device) {
    IndustrialDevice.supply => const Size(140, 160),
    IndustrialDevice.breaker => const Size(72, 160),
    IndustrialDevice.toggle => const Size(90, 140),
    IndustrialDevice.button => const Size(90, 140),
    IndustrialDevice.lamp => const Size(130, 160),
    IndustrialDevice.fan => const Size(210, 210),
    IndustrialDevice.motor => const Size(230, 190),
    IndustrialDevice.coil => const Size(190, 230),
  };

  /// Matches ReferenceComponentGeometry/ExtendedReferenceGeometry exactly.
  static List<Offset> anchors(IndustrialDevice device) => switch (device) {
    IndustrialDevice.supply => const [Offset(42, 127), Offset(94, 127)],
    IndustrialDevice.breaker => const [Offset(36, 23), Offset(36, 137)],
    IndustrialDevice.toggle => const [Offset(45, 20), Offset(45, 120)],
    IndustrialDevice.button => const [Offset(31, 119), Offset(59, 119)],
    IndustrialDevice.lamp => const [Offset(40, 139), Offset(90, 139)],
    IndustrialDevice.fan => const [Offset(82, 187), Offset(128, 187)],
    IndustrialDevice.motor => const [Offset(90, 161), Offset(140, 161)],
    IndustrialDevice.coil => const [Offset(65, 202), Offset(125, 202)],
  };
}

/// Pure visual projection of CORE-UNIFY state; never computes protection.
/// Breakers are one-pole as in the existing 2-terminal canonical model.
/// A 1P+N differential requires a distinct real four-terminal model.
class IndustrialPhysicalView extends StatelessWidget {
  const IndustrialPhysicalView({
    super.key,
    required this.device,
    required this.size,
    this.showTerminals = true,
    this.closed = true,
    this.tripped = false,
    this.pressed = false,
    this.energized = false,
    this.animationValue = 0,
    this.currentA = 0,
    this.voltageV = 0,
    this.ratedCurrentA = 0,
    this.domain = 'CC',
  });

  final IndustrialDevice device;
  final Size size;
  final bool showTerminals, closed, tripped, pressed, energized;
  final double animationValue, currentA, voltageV, ratedCurrentA;
  final String domain;

  /// Rotational phase is strictly display-only; polarity is supplied by the
  /// solver. A reversed motor rotates in the opposite direction.
  static double signedMotorPhaseAngle(
    double animationValue,
    double signedCurrentA, {
    required bool energized,
  }) => energized && signedCurrentA.isFinite
      ? animationValue * 2 * math.pi * (signedCurrentA < 0 ? -1 : 1)
      : 0;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size.width,
    height: size.height,
    child: RepaintBoundary(
      child: CustomPaint(
        key: Key('new-industrial-${device.name}'),
        painter: _IndustrialPainter(this),
      ),
    ),
  );
}

final class _IndustrialPainter extends CustomPainter {
  const _IndustrialPainter(this.v);
  final IndustrialPhysicalView v;
  static const dark = Color(0xFF26383E);
  static const emerald = Color(0xFF148148);

  void box(Canvas c, Rect r, Color light, Color shade, {double radius = 4}) {
    final rr = RRect.fromRectAndRadius(r, Radius.circular(radius));
    c.drawShadow(Path()..addRRect(rr), const Color(0x44000000), 2, false);
    c.drawRRect(
      rr,
      Paint()
        ..shader = LinearGradient(
          colors: [light, shade],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(r),
    );
    c.drawRRect(
      rr,
      Paint()
        ..color = const Color(0xFF76878C)
        ..strokeWidth = .8
        ..style = PaintingStyle.stroke,
    );
  }

  void label(
    Canvas c,
    String s,
    double x,
    double y, {
    double font = 8,
    Color color = dark,
    bool center = false,
  }) {
    final t = TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(
          fontSize: font,
          color: color,
          fontWeight: FontWeight.w600,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    t.paint(c, Offset(center ? x - t.width / 2 : x, y));
  }

  void screw(Canvas c, Offset p, {double r = 5}) {
    c.drawCircle(p, r + 2, Paint()..color = const Color(0xFF415159));
    c.drawCircle(
      p,
      r,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFFE8EFEB), Color(0xFF87959A), Color(0xFFDCE4DE)],
        ).createShader(Rect.fromCircle(center: p, radius: r)),
    );
    c.drawLine(
      p + Offset(-r * .55, 0),
      p + Offset(r * .55, 0),
      Paint()
        ..color = dark
        ..strokeWidth = 1.2,
    );
    c.drawLine(
      p + Offset(0, -r * .55),
      p + Offset(0, r * .55),
      Paint()
        ..color = dark
        ..strokeWidth = 1.2,
    );
  }

  void terminals(Canvas c) {
    if (!v.showTerminals) return;
    for (final p in IndustrialDeviceContract.anchors(v.device)) {
      screw(c, p, r: v.device == IndustrialDevice.breaker ? 5 : 4.5);
    }
  }

  void breaker(Canvas c) {
    box(
      c,
      const Rect.fromLTWH(10, 8, 52, 144),
      const Color(0xFFFFFFFF),
      const Color(0xFFC3CBC4),
    );
    for (final y in [13.0, 127.0]) {
      box(
        c,
        Rect.fromLTWH(22, y, 28, 20),
        const Color(0xFFACB6B2),
        const Color(0xFF536267),
      );
    }
    box(
      c,
      const Rect.fromLTWH(14, 37, 44, 34),
      Colors.white,
      const Color(0xFFE1E6DE),
      radius: 2,
    );
    c.drawRect(const Rect.fromLTWH(16, 38, 40, 2), Paint()..color = emerald);
    label(c, 'PROTECTION', 16, 43, font: 6.5);
    label(c, v.domain, 16, 53, font: 8);
    if (v.ratedCurrentA > 0 && v.ratedCurrentA.isFinite) {
      label(c, '${v.ratedCurrentA.toStringAsFixed(1)} A', 16, 62, font: 7.2);
    }
    box(
      c,
      const Rect.fromLTWH(20, 75, 32, 42),
      const Color(0xFF849095),
      const Color(0xFF333F44),
      radius: 5,
    );
    final pos = v.tripped
        ? 90.0
        : v.closed
        ? 78.0
        : 100.0;
    box(
      c,
      Rect.fromLTWH(24, pos, 24, 13),
      const Color(0xFF596469),
      const Color(0xFF111C22),
    );
    label(
      c,
      v.tripped
          ? 'TRIP'
          : v.closed
          ? 'I'
          : 'O',
      36,
      120,
      center: true,
      font: 8,
    );
    terminals(c);
  }

  void supply(Canvas c) {
    box(
      c,
      const Rect.fromLTWH(7, 8, 126, 144),
      const Color(0xFF65787F),
      const Color(0xFF25353E),
      radius: 6,
    );
    box(
      c,
      const Rect.fromLTWH(16, 24, 108, 73),
      const Color(0xFF1F3438),
      const Color(0xFF091A20),
    );
    label(c, 'ALIMENTATION CC', 17, 13, font: 7, color: Colors.white);
    label(
      c,
      '${v.voltageV.abs().toStringAsFixed(2)} V',
      22,
      35,
      font: 18,
      color: const Color(0xFF99F6D6),
    );
    label(
      c,
      '${v.currentA.abs().toStringAsFixed(3)} A',
      22,
      65,
      font: 14,
      color: const Color(0xFF99F6D6),
    );
    c.drawCircle(
      const Offset(39, 107),
      4,
      Paint()..color = v.energized ? emerald : Colors.white24,
    );
    label(c, 'CV', 48, 102, color: Colors.white, font: 7);
    label(c, 'CC', 91, 102, color: Colors.white, font: 7);
    label(c, '+', 40, 138, color: Colors.white, font: 10);
    label(c, '−', 93, 138, color: Colors.white, font: 10);
    terminals(c);
  }

  void toggle(Canvas c) {
    box(
      c,
      const Rect.fromLTWH(10, 8, 70, 124),
      const Color(0xFFE9EEEA),
      const Color(0xFF91A4A7),
    );
    box(
      c,
      const Rect.fromLTWH(20, 36, 50, 69),
      const Color(0xFFAEBAB8),
      const Color(0xFF485C64),
      radius: 8,
    );
    box(
      c,
      const Rect.fromLTWH(32, 42, 26, 56),
      const Color(0xFF273A40),
      const Color(0xFF102127),
      radius: 8,
    );
    box(
      c,
      Rect.fromLTWH(34, v.closed ? 44 : 68, 22, 25),
      const Color(0xFFE9F0E9),
      const Color(0xFF95A6AB),
    );
    label(c, 'I', 45, 30, center: true, font: 9);
    label(c, 'O', 45, 106, center: true, font: 9);
    terminals(c);
  }

  void button(Canvas c) {
    box(
      c,
      const Rect.fromLTWH(16, 75, 58, 55),
      const Color(0xFFE7ECEA),
      const Color(0xFF95A8A4),
      radius: 8,
    );
    c.drawCircle(
      const Offset(45, 55),
      35,
      Paint()..color = const Color(0xFF6A777C),
    );
    c.drawCircle(
      const Offset(45, 55),
      30,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0xFFFFFFFF), Color(0xFFA5BAB5), Color(0xFFE1E8E2)],
        ).createShader(Rect.fromCircle(center: Offset(45, 55), radius: 30)),
    );
    final rad = v.pressed ? 21.0 : 25.0;
    c.drawCircle(
      const Offset(45, 55),
      rad,
      Paint()
        ..shader =
            const RadialGradient(
              colors: [Color(0xFF64FA92), Color(0xFF18864D), Color(0xFF07482C)],
            ).createShader(
              Rect.fromCircle(center: const Offset(45, 55), radius: rad),
            ),
    );
    label(c, 'NO', 45, 101, center: true);
    terminals(c);
  }

  void lamp(Canvas c) {
    box(
      c,
      const Rect.fromLTWH(30, 119, 70, 32),
      const Color(0xFFAABABE),
      const Color(0xFF53656D),
    );
    c.drawCircle(
      const Offset(65, 74),
      43,
      Paint()
        ..shader = RadialGradient(
          colors: v.energized
              ? const [Color(0xFFFFFFF1), Color(0xFFFFEDAB), Color(0xFFD9B16A)]
              : const [Color(0xFFFFFFFF), Color(0xFFDDE8E7), Color(0xFF9BACAF)],
        ).createShader(Rect.fromCircle(center: Offset(65, 74), radius: 43)),
    );
    final p = Paint()
      ..color = const Color(0xFF896E5B)
      ..strokeWidth = 2;
    c.drawLine(const Offset(52, 60), const Offset(52, 87), p);
    c.drawLine(const Offset(78, 60), const Offset(78, 87), p);
    final filament = Path()
      ..moveTo(52, 60)
      ..quadraticBezierTo(59, 82, 65, 60)
      ..quadraticBezierTo(71, 82, 78, 60);
    c.drawPath(filament, p);
    terminals(c);
  }

  void fan(Canvas c) {
    box(
      c,
      const Rect.fromLTWH(12, 10, 186, 188),
      const Color(0xFF9BACB0),
      const Color(0xFF4A5E65),
      radius: 9,
    );
    c.drawCircle(
      const Offset(105, 99),
      82,
      Paint()..color = const Color(0xFF1C3038),
    );
    c.save();
    c.translate(105, 99);
    if (v.energized) c.rotate(v.animationValue * math.pi * 2);
    for (var n = 0; n < 6; n++) {
      c.rotate(math.pi / 3);
      final blade = Path()
        ..moveTo(-5, -9)
        ..quadraticBezierTo(-12, -67, 28, -72)
        ..quadraticBezierTo(52, -35, 10, 0)
        ..close();
      c.drawPath(blade, Paint()..color = const Color(0xFF728991));
    }
    c.drawCircle(Offset.zero, 15, Paint()..color = const Color(0xFFC6D3D1));
    c.restore();
    for (final p in [
      const Offset(23, 23),
      const Offset(185, 23),
      const Offset(23, 182),
      const Offset(185, 182),
    ]) {
      screw(c, p, r: 4);
    }
    terminals(c);
  }

  void motor(Canvas c) {
    box(
      c,
      const Rect.fromLTWH(21, 32, 188, 124),
      const Color(0xFFA9BABD),
      const Color(0xFF61757B),
      radius: 29,
    );
    for (double x = 44; x <= 187; x += 13) {
      c.drawLine(
        Offset(x, 38),
        Offset(x, 150),
        Paint()
          ..color = const Color(0xFF455B61)
          ..strokeWidth = 3,
      );
      c.drawLine(
        Offset(x + 2, 38),
        Offset(x + 2, 150),
        Paint()
          ..color = const Color(0xFFC1CDCC)
          ..strokeWidth = 1,
      );
    }
    c.drawCircle(
      const Offset(115, 93),
      48,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0xFFCAD7D6), Color(0xFF789097), Color(0xFF2F4951)],
        ).createShader(Rect.fromCircle(center: Offset(115, 93), radius: 48)),
    );
    c.drawCircle(
      const Offset(115, 93),
      22,
      Paint()..color = const Color(0xFF526C72),
    );
    c.drawCircle(
      const Offset(115, 93),
      10,
      Paint()..color = const Color(0xFFDAE3DE),
    );
    // Visible shaft rotation. Do not rotate the housing or terminal box.
    c.save();
    c.translate(115, 93);
    c.rotate(IndustrialPhysicalView.signedMotorPhaseAngle(
      v.animationValue, v.currentA, energized: v.energized,
    ));
    for (var n = 0; n < 3; n++) {
      c.rotate(math.pi * 2 / 3);
      c.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(-2, -17, 4, 8),
          const Radius.circular(1),
        ),
        Paint()..color = const Color(0xFF223F47),
      );
    }
    c.restore();
    box(
      c,
      const Rect.fromLTWH(66, 146, 98, 34),
      const Color(0xFFD8E2DD),
      const Color(0xFF839B9F),
      radius: 7,
    );
    label(c, 'MOTEUR CC', 115, 12, font: 9, center: true);
    terminals(c);
  }

  void coil(Canvas c) {
    box(
      c,
      const Rect.fromLTWH(27, 16, 136, 195),
      const Color(0xFFAFBEC2),
      const Color(0xFF667F84),
      radius: 7,
    );
    box(
      c,
      const Rect.fromLTWH(42, 36, 106, 134),
      const Color(0xFF1B343A),
      const Color(0xFF344F55),
    );
    for (double x = 51; x < 143; x += 7) {
      c.drawLine(
        Offset(x, 48),
        Offset(x, 156),
        Paint()
          ..color = const Color(0xFFB8763A)
          ..strokeWidth = 3.2,
      );
      c.drawLine(
        Offset(x + 2, 48),
        Offset(x + 2, 156),
        Paint()
          ..color = const Color(0xFFF7BA76)
          ..strokeWidth = 1,
      );
    }
    box(
      c,
      const Rect.fromLTWH(84, 35, 22, 136),
      const Color(0xFFE5ECE8),
      const Color(0xFF91A6A8),
    );
    box(
      c,
      const Rect.fromLTWH(39, 178, 112, 33),
      const Color(0xFFD5E0DD),
      const Color(0xFF71898F),
    );
    label(c, 'A1', 65, 219, center: true);
    label(c, 'A2', 125, 219, center: true);
    terminals(c);
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final base = IndustrialDeviceContract.designSize(v.device);
    final k = math.min(size.width / base.width, size.height / base.height);
    canvas.save();
    canvas.translate(
      (size.width - base.width * k) / 2,
      (size.height - base.height * k) / 2,
    );
    canvas.scale(k);
    switch (v.device) {
      case IndustrialDevice.supply:
        supply(canvas);
      case IndustrialDevice.breaker:
        breaker(canvas);
      case IndustrialDevice.toggle:
        toggle(canvas);
      case IndustrialDevice.button:
        button(canvas);
      case IndustrialDevice.lamp:
        lamp(canvas);
      case IndustrialDevice.fan:
        fan(canvas);
      case IndustrialDevice.motor:
        motor(canvas);
      case IndustrialDevice.coil:
        coil(canvas);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _IndustrialPainter previous) {
    final old = previous.v;
    return old.device != v.device ||
        old.showTerminals != v.showTerminals ||
        old.closed != v.closed ||
        old.pressed != v.pressed ||
        old.tripped != v.tripped ||
        old.energized != v.energized ||
        old.animationValue != v.animationValue ||
        old.currentA != v.currentA ||
        old.voltageV != v.voltageV ||
        old.ratedCurrentA != v.ratedCurrentA ||
        old.domain != v.domain;
  }
}
