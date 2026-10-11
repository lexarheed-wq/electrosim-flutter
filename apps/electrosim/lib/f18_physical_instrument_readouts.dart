import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:electrosim_canvas/electrosim_canvas.dart';
import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'f18_voltmeter_3d_assets.dart';
import 'f18_voltmeter_controls.dart';
import 'f18_ammeter_controls.dart';
import 'f18_ammeter_3d_assets.dart';

/// LCD readouts are projected from the electrical runtime: invalid/disconnected
/// devices never manufacture a zero. The optional Cycles body is painted by
/// this same top overlay to keep the LCD and its texture in ONE transform.
final class F18PhysicalInstrumentReadouts extends CustomPainter {
  const F18PhysicalInstrumentReadouts({
    required this.layout,
    required this.viewport,
    required this.readouts,
    this.circuit,
    this.voltmeter3dIds = const <String>{},
    this.voltmeterFront,
    this.ammeter3dIds = const <String>{},
    this.ammeterFront,
    this.selectedElementId,
  });

  final CircuitVisualLayout layout;
  final ViewportController viewport;
  final Map<String, String> readouts;
  final CircuitState? circuit;
  final Set<String> voltmeter3dIds;
  final ui.Image? voltmeterFront;
  final Set<String> ammeter3dIds;
  final ui.Image? ammeterFront;
  final String? selectedElementId;

  Rect? screenRect(String id) {
    final Offset? center = layout.positionOf(id);
    if (center == null) return null;
    final Size base = layout.sizeOf(id);
    final Offset screen = viewport.worldToScreen(center);
    return Rect.fromCenter(
      center: screen,
      width: base.width * viewport.scale,
      height: base.height * viewport.scale,
    );
  }

  /// The board footprint rotates with layout.quarterTurnsOf; transform both
  /// the image and its live LCD together, never the probe connections.
  void _paint3dRotated(
    Canvas canvas,
    String id,
    Rect screen,
    void Function(Rect localBody) paintLocal,
  ) {
    canvas.save();
    canvas.translate(screen.center.dx, screen.center.dy);
    canvas.rotate(layout.quarterTurnsOf(id) * math.pi / 2);
    paintLocal(Rect.fromCenter(
      center: Offset.zero,
      width: screen.width,
      height: screen.height,
    ));
    canvas.restore();
  }

  bool _inView(String id, Rect screen, Size viewportSize) {
    final Rect visualBounds = layout.quarterTurnsOf(id).isOdd
        ? Rect.fromCenter(
            center: screen.center,
            width: screen.height,
            height: screen.width,
          )
        : screen;
    return visualBounds.overlaps(Offset.zero & viewportSize);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final ui.Image? front = voltmeterFront;
    // Silicone probe leads stay BEHIND the meter body, never replacing power
    // wiring in the circuit painter.
    _paintConnectedProbes(canvas);
    if (front != null) {
      // Draw first, independent of the reading map (OFF/ERR may be absent).
      for (final String id in voltmeter3dIds) {
        final Rect? rect = screenRect(id);
        if (rect == null || !_inView(id, rect, size)) continue;
        _paint3dRotated(canvas, id, rect, (Rect local) {
          canvas.drawImageRect(
            front,
            Rect.fromLTWH(
              0, 0, front.width.toDouble(), front.height.toDouble(),
            ),
            local,
            Paint()..filterQuality = FilterQuality.high,
          );
          final InstrumentInstance? meter = circuit?.instruments
              .where((item) => item.id.value == id)
              .firstOrNull;
          if (meter != null) {
            _paintFrontControls(canvas, local, meter);
          }
          if (id == selectedElementId) {
            final Rect inner = local.deflate(2 * viewport.scale);
            canvas.drawRRect(
              RRect.fromRectAndRadius(
                inner, Radius.circular(8 * viewport.scale),
              ),
              Paint()
                ..color = const Color(0xFF2563EB)
                ..strokeWidth =
                    (2 * viewport.scale).clamp(1.5, 5.0).toDouble()
                ..style = PaintingStyle.stroke,
            );
          }
        });
      }
    }

    // Component 02: independent original current-meter body; the same
    // runtime layer continues to paint the actual meter current reading.
    final ui.Image? ammeter = ammeterFront;
    if (ammeter != null) {
      for (final String id in ammeter3dIds) {
        final Rect? rect = screenRect(id);
        if (rect == null || !_inView(id, rect, size)) continue;
        _paint3dRotated(canvas, id, rect, (Rect local) {
          canvas.drawImageRect(
            ammeter,
            Rect.fromLTWH(
              0, 0, ammeter.width.toDouble(), ammeter.height.toDouble(),
            ),
            local,
            Paint()..filterQuality = FilterQuality.high,
          );
          final InstrumentInstance? meter = circuit?.instruments
              .where((i) => i.id.value == id).firstOrNull;
          if (meter != null) _paintFrontControls(canvas, local, meter);
          if (id == selectedElementId) {
            canvas.drawRRect(
              RRect.fromRectAndRadius(
                local.deflate(2 * viewport.scale),
                Radius.circular(8 * viewport.scale),
              ),
              Paint()
                ..color = const Color(0xFF2563EB)
                ..strokeWidth = (2 * viewport.scale).clamp(1.5, 5.0).toDouble()
                ..style = PaintingStyle.stroke,
            );
          }
        });
      }
    }

    for (final MapEntry<String, String> item in readouts.entries) {
      final Rect? rect = screenRect(item.key);
      if (rect == null) continue;
      final bool original3d =
          (front != null && voltmeter3dIds.contains(item.key)) ||
          (ammeter != null && ammeter3dIds.contains(item.key));
      if (original3d && !_inView(item.key, rect, size)) continue;
      if (!original3d && !rect.overlaps(Offset.zero & size)) continue;
      if (original3d) {
        _paint3dRotated(canvas, item.key, rect, (Rect local) {
          final InstrumentInstance? meter = circuit?.instruments
              .where((it) => it.id.value == item.key)
              .firstOrNull;
          _drawReading(
            canvas,
            ammeter3dIds.contains(item.key)
                ? F18Ammeter3dAssets.projectReadout(local)
                : F18Voltmeter3dAssets.projectReadout(local),
            item.value,
            illuminated: meter != null && (
              meter.kind == InstrumentKind.ammeter
                  ? F18AmmeterControls.lit(meter)
                  : F18VoltmeterControls.isLit(meter)),
          );
        });
      } else {
        _drawReading(
          canvas,
          Rect.fromLTWH(
            rect.left + rect.width * 0.10,
            rect.top + rect.height * 0.11,
            rect.width * 0.80,
            rect.height * 0.38,
          ),
          item.value,
        );
      }
    }
  }

  void _paintFrontControls(Canvas canvas, Rect body, InstrumentInstance meter) {
    final bool current = meter.kind == InstrumentKind.ammeter;
    canvas.save();
    canvas.translate(body.left, body.top);
    canvas.scale(body.width / 112, body.height / 152);
    // Legacy low-resolution PNGs lack physically embossed text. 4x Cycles
    // textures already contain HOLD/RANGE/SELECT/LIGHT and COM/V-ohm labels.
    if ((current ? (ammeterFront?.width ?? 0) : (voltmeterFront?.width ?? 0)) < 1000) {
    const names = <String>['HOLD', 'RANGE', 'SELECT', 'LIGHT'];
    const xs = <double>[35, 49, 63, 77];
    for (var index = 0; index < names.length; index++) {
      final String label = names[index];
      final bool selected = switch (index) {
        0 => current
            ? F18AmmeterControls.held(meter)
            : F18VoltmeterControls.isHeld(meter),
        1 => current
            ? F18AmmeterControls.rangeIndex(meter) != 0
            : F18VoltmeterControls.rangeIndex(meter) != 0,
        2 => meter.mode == InstrumentMode.voltageAcRms ||
            meter.mode == InstrumentMode.currentAcRms,
        _ => current
            ? F18AmmeterControls.lit(meter)
            : F18VoltmeterControls.isLit(meter),
      };
      final text = TextPainter(
        text: TextSpan(text: label, style: TextStyle(
          fontFamily: 'Roboto',
          fontSize: label == 'SELECT' ? 2.35 : 2.7,
          fontWeight: FontWeight.w800,
          color: selected ? const Color(0xFF102335) : const Color(0xFFE5E9ED),
        )),
        textDirection: TextDirection.ltr,
      )..layout();
      text.paint(canvas, Offset(xs[index] - text.width / 2, 54.3));
      text.dispose();
    }
    }
    if ((current ? (ammeterFront?.width ?? 0) : (voltmeterFront?.width ?? 0)) >= 1000) {
      // High-definition front PNG intentionally has no selector grip.
      // Rotate a tactile vector grip above the shaft without rotating body,
      // LCD or connected measurement probes.
      final double turn = !meter.poweredOn ? -math.pi / 3 : switch (meter.mode) {
        InstrumentMode.voltageDc => 0.0,
        InstrumentMode.voltageAcRms => math.pi / 3,
        InstrumentMode.currentDc => 0.0,
        InstrumentMode.currentAcRms => math.pi / 3,
        InstrumentMode.resistance => 2 * math.pi / 3,
        _ => 0.0,
      };
      canvas.save();
      canvas.translate(53, 91);
      canvas.rotate(turn);
      final Rect knob = Rect.fromCenter(
        center: Offset.zero, width: 9, height: 29,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(knob, const Radius.circular(2)),
        Paint()..color = const Color(0xFF7A8288),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(knob.deflate(.85), const Radius.circular(1.4)),
        Paint()..color = const Color(0xFF353E49),
      );
      for (var rib = 0; rib < 5; rib++) {
        final double y = -9 + rib * 4.3;
        canvas.drawLine(
          Offset(-2.5, y), Offset(2.5, y),
          Paint()
            ..color = const Color(0xFFAFB8C0)
            ..strokeWidth = .8
            ..strokeCap = StrokeCap.round,
        );
      }
      final Path marker = Path()
        ..moveTo(0, -17.0)
        ..lineTo(-3, -12.5)
        ..lineTo(3, -12.5)
        ..close();
      canvas.drawPath(marker, Paint()..color = const Color(0xFFF2F6F9));
      canvas.restore();
    }
    final String mode = !meter.poweredOn ? 'OFF' : switch (meter.mode) {
      InstrumentMode.voltageDc => 'V⎓',
      InstrumentMode.currentDc => 'A⎓',
      InstrumentMode.currentAcRms => 'A~',
      InstrumentMode.voltageAcRms => 'V~',
      InstrumentMode.resistance => 'Ω',
      _ => 'V',
    };
    final indicator = TextPainter(
      text: TextSpan(text: mode, style: const TextStyle(
        fontFamily: 'Roboto', fontSize: 4.5, fontWeight: FontWeight.w800,
        color: Color(0xFFF4F7F9),
      )),
      textDirection: TextDirection.ltr,
    )..layout();
    indicator.paint(canvas, Offset(53 - indicator.width / 2, 111));
    indicator.dispose();
    final bool isHeld = current
        ? F18AmmeterControls.held(meter)
        : F18VoltmeterControls.isHeld(meter);
    final int rangeIndex = current
        ? F18AmmeterControls.rangeIndex(meter)
        : F18VoltmeterControls.rangeIndex(meter);
    if (isHeld || rangeIndex != 0) {
      final flags = <String>[
        if (isHeld) 'H',
        if (rangeIndex != 0)
          current ? F18AmmeterControls.rangeLabel(meter) : F18VoltmeterControls.rangeLabel(meter),
      ].join(' ');
      final labels = TextPainter(
        text: TextSpan(text: flags, style: const TextStyle(
          fontFamily: 'Roboto', fontSize: 3.2, fontWeight: FontWeight.w700,
          color: Color(0xFF1D4E38),
        )),
        textDirection: TextDirection.ltr,
      )..layout();
      labels.paint(canvas, Offset(37, 27));
      labels.dispose();
    }
    canvas.restore();
  }

  void _paintConnectedProbes(Canvas canvas) {
    final CircuitState? active = circuit;
    if (active == null ||
        ((voltmeterFront == null || voltmeter3dIds.isEmpty) &&
         (ammeterFront == null || ammeter3dIds.isEmpty))) return;
    final CircuitGeometryIndex geometry =
        CircuitGeometryIndex.build(active, layout);
    for (final ProbeConnection probe in active.probes) {
      final String id = probe.instrumentId.value;
      final bool isVoltage = voltmeterFront != null &&
          voltmeter3dIds.contains(id);
      final bool isCurrent = ammeterFront != null &&
          ammeter3dIds.contains(id);
      if (!isVoltage && !isCurrent) continue;
      if (probe.port != InstrumentPort.common &&
          probe.port != (isVoltage ? InstrumentPort.voltOhm : InstrumentPort.amp)) {
        continue;
      }
      final Rect? meter = screenRect(id);
      final Offset? targetWorld = geometry.terminalPositions[probe.terminalId];
      if (meter == null || targetWorld == null) continue;
      final bool common = probe.port == InstrumentPort.common;
      final Offset local = Offset(
        meter.width * (common ? 42 / 112 : 70 / 112) - meter.width / 2,
        meter.height * (128 / 152) - meter.height / 2,
      );
      final double angle = layout.quarterTurnsOf(id) * math.pi / 2;
      final Offset socket = meter.center + Offset(
        local.dx * math.cos(angle) - local.dy * math.sin(angle),
        local.dx * math.sin(angle) + local.dy * math.cos(angle),
      );
      final Offset target = viewport.worldToScreen(targetWorld);
      // Flexible silicone cords, curved and shaded, terminate in insulated
      // probes. The ordinary circuit cables stay orthogonal in SimulatorCanvas.
      final double slack = 34 * viewport.scale;
      final double direction = target.dx >= socket.dx ? 1 : -1;
      final Offset start = socket + Offset(0, 3 * viewport.scale);
      final Offset end = target + Offset(-direction * 12 * viewport.scale, -8 * viewport.scale);
      final Path cable = Path()
        ..moveTo(start.dx, start.dy)
        ..cubicTo(
          start.dx + direction * 11 * viewport.scale,
          start.dy + slack,
          end.dx - direction * 32 * viewport.scale,
          end.dy + slack * 1.15,
          end.dx,
          end.dy,
        );
      final Color color =
          common ? const Color(0xFF171C24) : const Color(0xFFCE2839);
      final Paint insulation = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(3.2, viewport.scale * 3.9)
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      canvas.drawPath(cable, insulation);
      canvas.drawPath(
        cable,
        Paint()
          ..color = common ? const Color(0xFF515D65) : const Color(0xFFEE7780)
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(0.7, viewport.scale * 0.95)
          ..strokeCap = StrokeCap.round,
      );
      final double shaftW = math.max(4, viewport.scale * 5.0);
      canvas.drawLine(
        end, target,
        Paint()
          ..color = const Color(0xFFD4DAE0)
          ..strokeWidth = math.max(1.4, viewport.scale * 1.7)
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawCircle(
        end, shaftW,
        Paint()..color = color,
      );
      canvas.drawCircle(
        socket, math.max(2.5, viewport.scale * 3),
        Paint()..color = color,
      );
      canvas.drawCircle(
        target, math.max(1.4, viewport.scale * 1.7),
        Paint()..color = const Color(0xFFC5CED7),
      );
    }
  }

  void _drawReading(Canvas canvas, Rect display, String reading, {
    bool illuminated = false,
  }) {
    if (display.width <= 0 || display.height <= 0) return;
      final double radius = (3 * viewport.scale).clamp(1.0, 6.0).toDouble();
      canvas.save();
      canvas.clipRRect(
        RRect.fromRectAndRadius(display, Radius.circular(radius)),
      );
      canvas.drawRect(
        display,
        Paint()..color = illuminated
            ? const Color(0xFFA5ECF5)
            : const Color(0xFFD5E5D6),
      );
      final TextPainter text = TextPainter(
        text: TextSpan(
          text: reading,
          style: TextStyle(
            fontFamily: 'Roboto',
            fontSize: (13 * viewport.scale).clamp(7, 22).toDouble(),
            fontWeight: FontWeight.w700,
            color: const Color(0xFF142C1F),
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout();
      // Shrink, don't clip, values such as 230.00 V / FUSE at low zoom.
      final double targetW = math.max(1, display.width - 4 * viewport.scale);
      final double targetH = math.max(1, display.height - 2 * viewport.scale);
      final double fit = math.min(
        1,
        math.min(targetW / math.max(1, text.width),
                 targetH / math.max(1, text.height)),
      );
      canvas.translate(display.center.dx, display.center.dy);
      canvas.scale(fit);
      text.paint(
        canvas,
        Offset(-text.width / 2, -text.height / 2),
      );
      canvas.restore();
      text.dispose();
  }

  @override
  bool shouldRepaint(covariant F18PhysicalInstrumentReadouts old) =>
      !identical(layout, old.layout) ||
      !identical(viewport, old.viewport) ||
      !identical(readouts, old.readouts) ||
      !identical(circuit, old.circuit) ||
      !identical(voltmeterFront, old.voltmeterFront) ||
      !identical(ammeterFront, old.ammeterFront) ||
      !setEquals(ammeter3dIds, old.ammeter3dIds) ||
      !setEquals(voltmeter3dIds, old.voltmeter3dIds) ||
      selectedElementId != old.selectedElementId;
}
