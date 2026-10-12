import 'dart:math' as math;
import 'package:electrosim_canvas/electrosim_canvas.dart';
import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:flutter/material.dart';

class F18AppliancePowerCords extends CustomPainter {
  F18AppliancePowerCords({
    required this.circuit,
    required this.layout,
    required this.viewport,
    required this.geometry,
  }) : super(repaint: viewport);
  final CircuitState circuit;
  final CircuitVisualLayout layout;
  final ViewportController viewport;
  final CircuitGeometryIndex geometry;
  @override
  void paint(Canvas canvas, Size size) {
    for (final c in circuit.components) {
      if (!AppliancePowerConnection.isExternal(c) ||
          AppliancePowerConnection.mode(c) == 'fixed') {
        continue;
      }
      final contacts = c.terminals
          .map((t) => geometry.terminalPositions[t.id])
          .whereType<Offset>()
          .toList();
      if (contacts.length < 2) continue;
      final originWorld = (contacts[0] + contacts[1]) / 2;
      final q = layout.elementQuarterTurns[c.id.value] ?? 0;
      final direction =
          NativeApplianceGeometry.forComponent(c)?.key == 'external-iron'
          ? -1.0
          : 1.0;
      final exit =
          Offset(-math.sin(q * math.pi / 2), math.cos(q * math.pi / 2)) *
          direction;
      final start = viewport.worldToScreen(originWorld);
      final cable = circuit.connections
          .where(
            (w) => w.metadata[AppliancePowerConnection.cableTag] == c.id.value,
          )
          .toList();
      Offset endWorld = originWorld + exit * 65;
      if (cable.length >= 2) {
        final a = geometry.terminalPositions[cable[0].fromTerminalId];
        final b = geometry.terminalPositions[cable[1].fromTerminalId];
        if (a != null && b != null) endWorld = (a + b) / 2;
      }
      final end = viewport.worldToScreen(endWorld);
      final scale = viewport.scale;
      final path = Path()
        ..moveTo(start.dx, start.dy)
        ..cubicTo(
          start.dx + exit.dx * 45 * scale,
          start.dy + exit.dy * 45 * scale,
          end.dx - 35 * scale,
          end.dy + (cable.isEmpty ? -40 : 40) * scale,
          end.dx,
          end.dy,
        );
      canvas.drawPath(
        path.shift(Offset(1, 2) * scale),
        Paint()
          ..color = Colors.black26
          ..style = PaintingStyle.stroke
          ..strokeWidth = 7 * scale
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawPath(
        path,
        Paint()
          ..color = const Color(0xFF252A2D)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5 * scale
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawPath(
        path.shift(Offset(-.7, -.7) * scale),
        Paint()
          ..color = const Color(0xFF687174)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1 * scale,
      );
      canvas.save();
      canvas.translate(end.dx, end.dy);
      canvas.scale(scale);
      final earthed = c.terminals.any(
        (t) => t.role == TerminalRole.protectiveEarth,
      );
      if (cable.isEmpty) {
        canvas.rotate(math.pi);
        for (final x in earthed ? [-10.0, 10.0] : [-5.0, 5.0]) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(x - 1.5, earthed ? -40 : -18, 3, earthed ? 14 : 10),
              const Radius.circular(1),
            ),
            Paint()..color = const Color(0xFFBFC5C4),
          );
        }
      }
      final body = RRect.fromRectAndRadius(
        earthed
            ? const Rect.fromLTWH(-23, -27, 46, 46)
            : const Rect.fromLTWH(-13, -9, 26, 25),
        const Radius.circular(6),
      );
      canvas.drawRRect(
        body,
        Paint()
          ..shader = const LinearGradient(
            colors: [Color(0xFF697175), Color(0xFF1D2225)],
          ).createShader(body.outerRect),
      );
      if (earthed && cable.isEmpty) {
        canvas.drawCircle(
          const Offset(0, -14),
          3,
          Paint()..color = const Color(0xFF151B1D),
        );
      }
      for (var i = 0; i < 3; i++) {
        canvas.drawLine(
          Offset(-8, 4.0 + i * 3),
          Offset(8, 4.0 + i * 3),
          Paint()
            ..color = const Color(0xFF7A8184)
            ..strokeWidth = .8,
        );
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(F18AppliancePowerCords old) =>
      old.circuit != circuit ||
      old.layout != layout ||
      old.geometry != geometry;
}
