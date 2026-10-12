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
import 'f18_frequency_3d_assets.dart';
import 'f18_phase_sequence_3d_assets.dart';
import 'f18_frequency_controls.dart';

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
    this.frequency3dIds = const <String>{},
    this.frequencyFront,
    this.phaseSequence3dIds = const <String>{},
    this.phaseSequenceFront,
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
  final Set<String> frequency3dIds;
  final ui.Image? frequencyFront;
  final Set<String> phaseSequence3dIds;
  final ui.Image? phaseSequenceFront;
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
    paintLocal(
      Rect.fromCenter(
        center: Offset.zero,
        width: screen.width,
        height: screen.height,
      ),
    );
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
    if (front != null) {
      // Draw first, independent of the reading map (OFF/ERR may be absent).
      for (final String id in voltmeter3dIds) {
        final Rect? rect = screenRect(id);
        if (rect == null || !_inView(id, rect, size)) continue;
        _paint3dRotated(canvas, id, rect, (Rect local) {
          canvas.drawImageRect(
            front,
            Rect.fromLTWH(
              0,
              0,
              front.width.toDouble(),
              front.height.toDouble(),
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
                inner,
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
              0,
              0,
              ammeter.width.toDouble(),
              ammeter.height.toDouble(),
            ),
            local,
            Paint()..filterQuality = FilterQuality.high,
          );
          final InstrumentInstance? meter = circuit?.instruments
              .where((i) => i.id.value == id)
              .firstOrNull;
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

    final ui.Image? frequency = frequencyFront;
    if (frequency != null) {
      for (final String id in frequency3dIds) {
        final Rect? rect = screenRect(id);
        if (rect == null || !_inView(id, rect, size)) continue;
        _paint3dRotated(canvas, id, rect, (Rect local) {
          canvas.drawImageRect(
            frequency,
            Rect.fromLTWH(
              0,
              0,
              frequency.width.toDouble(),
              frequency.height.toDouble(),
            ),
            local,
            Paint()..filterQuality = FilterQuality.high,
          );
          final InstrumentInstance? meter = circuit?.instruments
              .where((i) => i.id.value == id)
              .firstOrNull;
          if (meter != null) _paintFrequencyControls(canvas, local, meter);
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

    final ui.Image? phase = phaseSequenceFront;
    if (phase != null) {
      for (final id in phaseSequence3dIds) {
        final rect = screenRect(id);
        if (rect == null || !_inView(id, rect, size)) continue;
        _paint3dRotated(canvas, id, rect, (local) {
          canvas.drawImageRect(
            phase,
            Rect.fromLTWH(
              0,
              0,
              phase.width.toDouble(),
              phase.height.toDouble(),
            ),
            local,
            Paint()..filterQuality = FilterQuality.high,
          );
        });
      }
    }

    // The measurement sockets are on the FRONT: draw cords and insulated
    // plugs above the physical enclosure, independently of power wiring.
    _paintConnectedProbes(canvas);

    for (final MapEntry<String, String> item in readouts.entries) {
      final Rect? rect = screenRect(item.key);
      if (rect == null) continue;
      final bool original3d =
          (front != null && voltmeter3dIds.contains(item.key)) ||
          (ammeter != null && ammeter3dIds.contains(item.key)) ||
          (frequencyFront != null && frequency3dIds.contains(item.key)) ||
          (phase != null && phaseSequence3dIds.contains(item.key));
      if (original3d && !_inView(item.key, rect, size)) continue;
      if (!original3d && !rect.overlaps(Offset.zero & size)) continue;
      if (original3d) {
        _paint3dRotated(canvas, item.key, rect, (Rect local) {
          final InstrumentInstance? meter = circuit?.instruments
              .where((it) => it.id.value == item.key)
              .firstOrNull;
          if (phaseSequence3dIds.contains(item.key)) {
            _drawPhaseReading(
              canvas,
              F18PhaseSequence3dAssets.projectReadout(local),
              item.value,
            );
            return;
          }
          _drawReading(
            canvas,
            frequency3dIds.contains(item.key)
                ? F18Frequency3dAssets.projectReadout(local)
                : ammeter3dIds.contains(item.key)
                ? F18Ammeter3dAssets.projectReadout(local)
                : F18Voltmeter3dAssets.projectReadout(local),
            item.value,
            illuminated:
                meter != null &&
                (meter.kind == InstrumentKind.frequencyMeter
                    ? F18FrequencyControls.lit(meter)
                    : meter.kind == InstrumentKind.ammeter
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

  void _paintFrequencyControls(
    Canvas canvas,
    Rect body,
    InstrumentInstance meter,
  ) {
    canvas.save();
    canvas.translate(body.left, body.top);
    canvas.scale(body.width / 112, body.height / 152);
    for (final entry in <double, String>{
      35: 'HOLD',
      56: 'ON/OFF',
      77: 'LIGHT',
    }.entries) {
      final button = Rect.fromCenter(
        center: Offset(entry.key, 78),
        width: 13,
        height: 5.5,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(button, const Radius.circular(.6)),
        Paint()
          ..color = entry.key == 77
              ? const Color(0xFFC9A533)
              : entry.key == 56
              ? const Color(0xFF17486E)
              : const Color(0xFF515A60),
      );
      final text = TextPainter(
        text: TextSpan(
          text: entry.value,
          style: const TextStyle(
            fontFamily: 'Roboto',
            fontSize: 2.7,
            fontWeight: FontWeight.w700,
            color: Color(0xFFF1F5FA),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      text.paint(
        canvas,
        Offset(entry.key - text.width / 2, 78 - text.height / 2),
      );
      text.dispose();
    }
    if (F18FrequencyControls.held(meter) && meter.poweredOn) {
      final text = TextPainter(
        text: const TextSpan(
          text: 'HOLD',
          style: TextStyle(
            fontFamily: 'Roboto',
            fontSize: 4,
            color: Color(0xFF87C5EF),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      text.paint(canvas, const Offset(47, 90));
      text.dispose();
    }
    canvas.restore();
  }

  void _paintFrontControls(Canvas canvas, Rect body, InstrumentInstance meter) {
    final bool current = meter.kind == InstrumentKind.ammeter;
    canvas.save();
    canvas.translate(body.left, body.top);
    canvas.scale(body.width / 112, body.height / 152);
    // Draw front legends as vector text at the current viewport resolution.
    // Mask baked legends to avoid blurred text and doubled contours.
    {
      const names = <String>['HOLD', 'RANGE', 'SELECT', 'LIGHT'];
      const xs = <double>[35, 49, 63, 77];
      for (var index = 0; index < names.length; index++) {
        final String label = names[index];
        final bool selected = switch (index) {
          0 =>
            current
                ? F18AmmeterControls.held(meter)
                : F18VoltmeterControls.isHeld(meter),
          1 =>
            current
                ? F18AmmeterControls.rangeIndex(meter) != 0
                : F18VoltmeterControls.rangeIndex(meter) != 0,
          2 =>
            meter.mode == InstrumentMode.voltageAcRms ||
                meter.mode == InstrumentMode.currentAcRms,
          _ =>
            current
                ? F18AmmeterControls.lit(meter)
                : F18VoltmeterControls.isLit(meter),
        };
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset(xs[index], 56),
              width: 10,
              height: 4.1,
            ),
            const Radius.circular(0.6),
          ),
          Paint()
            ..color = index == 3
                ? const Color(0xFFC9A533)
                : const Color(0xFF515A60),
        );
        final text = TextPainter(
          text: TextSpan(
            text: label,
            style: TextStyle(
              fontFamily: 'Roboto',
              fontSize: label == 'SELECT' ? 2.5 : 2.8,
              fontWeight: FontWeight.w800,
              color: selected
                  ? const Color(0xFF102335)
                  : const Color(0xFFE5E9ED),
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        text.paint(
          canvas,
          Offset(xs[index] - text.width / 2, 56 - text.height / 2),
        );
        text.dispose();
      }
    }
    final double legendY = current ? 143 : 116;
    for (final entry in <double, String>{
      42: 'COM',
      70: current ? 'A' : 'V/Ω',
    }.entries) {
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset(entry.key, legendY),
          width: 18,
          height: 5,
        ),
        Paint()..color = const Color(0xFF292D2D),
      );
      final legend = TextPainter(
        text: TextSpan(
          text: entry.value,
          style: const TextStyle(
            fontFamily: 'Roboto',
            fontSize: 3.5,
            fontWeight: FontWeight.w600,
            color: Color(0xFFE5E9ED),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      legend.paint(
        canvas,
        Offset(entry.key - legend.width / 2, legendY - legend.height / 2),
      );
      legend.dispose();
    }
    if ((current ? (ammeterFront?.width ?? 0) : (voltmeterFront?.width ?? 0)) >=
        1000) {
      // High-definition front PNG intentionally has no selector grip.
      // Rotate a tactile vector grip above the shaft without rotating body,
      // LCD or connected measurement probes.
      final double turn = !meter.poweredOn
          ? -math.pi / 3
          : switch (meter.mode) {
              InstrumentMode.voltageDc => 0.0,
              InstrumentMode.voltageAcRms => math.pi / 3,
              InstrumentMode.currentDc => 0.0,
              InstrumentMode.currentAcRms => math.pi / 3,
              InstrumentMode.resistance => 2 * math.pi / 3,
              _ => 0.0,
            };
      canvas.save();
      canvas.translate(53, current ? 86 : 91);
      canvas.rotate(turn);
      final Rect knob = Rect.fromCenter(
        center: Offset.zero,
        width: 9,
        height: 29,
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
          Offset(-2.5, y),
          Offset(2.5, y),
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
    if (current && (ammeterFront?.width ?? 0) >= 1000) {
      // The lid is marked FUSE in the original Cycles mesh, but its ampere
      // rating is live metadata. Printing it here prevents a false fixed
      // rating when the instrument's fuseRatingA property is edited.
      final double fuse = meter.fuseRatingA;
      final String rating = fuse == fuse.truncateToDouble()
          ? '${fuse.toInt()} A'
          : '${fuse.toStringAsFixed(1)} A';
      final fuseText = TextPainter(
        text: TextSpan(
          text: rating,
          style: const TextStyle(
            fontFamily: 'Roboto',
            fontSize: 2.35,
            fontWeight: FontWeight.w700,
            color: Color(0xFFF1F4F7),
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout();
      fuseText.paint(canvas, Offset(53 - fuseText.width / 2, 115.0));
      fuseText.dispose();
    }
    final String mode = !meter.poweredOn
        ? 'OFF'
        : switch (meter.mode) {
            InstrumentMode.voltageDc => 'V⎓',
            InstrumentMode.currentDc => 'A⎓',
            InstrumentMode.currentAcRms => 'A~',
            InstrumentMode.voltageAcRms => 'V~',
            InstrumentMode.resistance => 'Ω',
            _ => 'V',
          };
    final indicator = TextPainter(
      text: TextSpan(
        text: mode,
        style: const TextStyle(
          fontFamily: 'Roboto',
          fontSize: 4.5,
          fontWeight: FontWeight.w800,
          color: Color(0xFFF4F7F9),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    indicator.paint(
      canvas,
      Offset(53 - indicator.width / 2, current ? 106 : 111),
    );
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
          current
              ? F18AmmeterControls.rangeLabel(meter)
              : F18VoltmeterControls.rangeLabel(meter),
      ].join(' ');
      final labels = TextPainter(
        text: TextSpan(
          text: flags,
          style: const TextStyle(
            fontFamily: 'Roboto',
            fontSize: 3.2,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1D4E38),
          ),
        ),
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
            (ammeterFront == null || ammeter3dIds.isEmpty) &&
            (frequencyFront == null || frequency3dIds.isEmpty) &&
            (phaseSequenceFront == null || phaseSequence3dIds.isEmpty))) {
      return;
    }
    final CircuitGeometryIndex geometry = CircuitGeometryIndex.build(
      active,
      layout,
    );
    for (final ProbeConnection probe in active.probes) {
      final String id = probe.instrumentId.value;
      final bool isVoltage =
          (voltmeterFront != null && voltmeter3dIds.contains(id)) ||
          (frequencyFront != null && frequency3dIds.contains(id));
      final bool isCurrent = ammeterFront != null && ammeter3dIds.contains(id);
      final bool isPhase =
          phaseSequenceFront != null && phaseSequence3dIds.contains(id);
      final int phaseIndex = const [
        InstrumentPort.phase1,
        InstrumentPort.phase2,
        InstrumentPort.phase3,
      ].indexOf(probe.port);
      if (!isVoltage && !isCurrent && !isPhase) continue;
      if (isPhase && phaseIndex < 0) continue;
      if (!isPhase &&
          probe.port != InstrumentPort.common &&
          probe.port !=
              (isVoltage ? InstrumentPort.voltOhm : InstrumentPort.amp)) {
        continue;
      }
      final Rect? meter = screenRect(id);
      final Offset? targetWorld = geometry.terminalPositions[probe.terminalId];
      if (meter == null || targetWorld == null) continue;
      final bool common = probe.port == InstrumentPort.common;
      final Offset local = Offset(
        meter.width *
                (isPhase
                    ? (34 + 22 * phaseIndex) / 112
                    : common
                    ? 42 / 112
                    : 70 / 112) -
            meter.width / 2,
        meter.height * (isPhase ? 1 / 152 : 128 / 152) - meter.height / 2,
      );
      final double angle = layout.quarterTurnsOf(id) * math.pi / 2;
      final Offset socket =
          meter.center +
          Offset(
            local.dx * math.cos(angle) - local.dy * math.sin(angle),
            local.dx * math.sin(angle) + local.dy * math.cos(angle),
          );
      final Offset target = viewport.worldToScreen(targetWorld);
      // Flexible silicone cords, curved and shaded, terminate in insulated
      // probes. The ordinary circuit cables stay orthogonal in SimulatorCanvas.
      final double slack = 34 * viewport.scale;
      final double direction = target.dx >= socket.dx ? 1 : -1;
      final Offset start =
          socket +
          Offset(-math.sin(angle), math.cos(angle)) *
              ((isPhase ? -3 : 3) * viewport.scale);
      final Offset probeAxis = Offset(direction * 0.8, 0.6);
      final Offset end = target - probeAxis * (72 * viewport.scale);
      // Follow the meter's local downward direction past the base before
      // turning towards the terminal, so the cable cannot cross its LCD/dial.
      final double tail = meter.height * (isPhase ? -28 : 36) / 152;
      final Offset exit =
          socket + Offset(-tail * math.sin(angle), tail * math.cos(angle));
      final Offset tangent =
          Offset(-math.sin(angle), math.cos(angle)) *
          ((isPhase ? -12 : 12) * viewport.scale);
      final Path cable = Path()
        ..moveTo(start.dx, start.dy)
        ..cubicTo(
          start.dx + tangent.dx,
          start.dy + tangent.dy,
          exit.dx - tangent.dx,
          exit.dy - tangent.dy,
          exit.dx,
          exit.dy,
        )
        ..cubicTo(
          exit.dx + direction * slack,
          exit.dy + slack,
          end.dx - direction * 32 * viewport.scale,
          end.dy + slack * 1.15,
          end.dx,
          end.dy,
        );
      final Color color = isPhase
          ? const [
              Color(0xFFA45629),
              Color(0xFF24282C),
              Color(0xFF777F87),
            ][phaseIndex]
          : common
          ? const Color(0xFF171C24)
          : const Color(0xFFCE2839);
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
      // Metal point touches the exact terminal; cable enters the rear of
      // the insulated hand grip. Dimensions are shared by both meter types.
      canvas.save();
      canvas.translate(target.dx, target.dy);
      canvas.rotate(math.atan2(probeAxis.dy, probeAxis.dx));
      canvas.scale(viewport.scale);
      final Path tip = Path()
        ..moveTo(0, 0)
        ..lineTo(-15, -1.25)
        ..lineTo(-15, 1.25)
        ..close();
      canvas.drawPath(
        tip,
        Paint()
          ..shader = const LinearGradient(
            colors: [Color(0xFF667480), Color(0xFFF4F7FA), Color(0xFF8996A0)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ).createShader(const Rect.fromLTWH(-15, -1.25, 15, 2.5)),
      );
      final Rect grip = const Rect.fromLTWH(-66, -3.8, 51, 7.6);
      canvas.drawRRect(
        RRect.fromRectAndRadius(grip, const Radius.circular(3)),
        Paint()
          ..shader = LinearGradient(
            colors: [
              common ? const Color(0xFF53606B) : const Color(0xFFF07883),
              color,
              common ? const Color(0xFF090D12) : const Color(0xFF7B1221),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ).createShader(grip),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(-21, -7, 4, 14),
          const Radius.circular(1.5),
        ),
        Paint()..color = color,
      );
      for (int rib = 0; rib < 4; rib++) {
        canvas.drawLine(
          Offset(-64 + rib * 3, -3),
          Offset(-64 + rib * 3, 3),
          Paint()
            ..color = const Color(0x55000000)
            ..strokeWidth = 1,
        );
      }
      canvas.drawLine(
        const Offset(-72, 0),
        const Offset(-66, 0),
        Paint()
          ..color = color
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round,
      );
      canvas.restore();
      canvas.drawCircle(
        socket,
        math.max(2.5, viewport.scale * 3),
        Paint()..color = color,
      );
      canvas.drawCircle(
        target,
        math.max(1.4, viewport.scale * 1.7),
        Paint()..color = const Color(0xFFC5CED7),
      );
      canvas.save();
      canvas.translate(socket.dx, socket.dy);
      canvas.rotate(angle + (isPhase ? math.pi : 0));
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            -3.5 * viewport.scale,
            -3 * viewport.scale,
            7 * viewport.scale,
            10 * viewport.scale,
          ),
          Radius.circular(2 * viewport.scale),
        ),
        Paint()..color = color,
      );
      canvas.restore();
    }
  }

  void _drawPhaseReading(Canvas canvas, Rect display, String reading) {
    final positive = reading == 'L1 → L2 → L3';
    final negative = reading == 'L1 → L3 → L2';
    if (!positive && !negative) {
      _drawReading(canvas, display, reading);
      return;
    }
    canvas.drawRect(display, Paint()..color = const Color(0xFFD5E5D6));
    _drawReading(
      canvas,
      Rect.fromLTWH(
        display.left,
        display.top,
        display.width,
        display.height * .4,
      ),
      positive ? 'L1 L2 L3' : 'L1 L3 L2',
    );
    final center = Offset(
      display.center.dx,
      display.top + display.height * .73,
    );
    final radius = math.min(display.width, display.height) * .24;
    final pen = Paint()
      ..color = const Color(0xFF142C1F)
      ..strokeWidth = math.max(1, 2.5 * viewport.scale)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final start = -math.pi * .72;
    final sweep = (positive ? 1 : -1) * math.pi * 1.65;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      start,
      sweep,
      false,
      pen,
    );
    final end = start + sweep;
    final tip = center + Offset(math.cos(end), math.sin(end)) * radius;
    final tangent = Offset(-math.sin(end), math.cos(end)) * (positive ? 1 : -1);
    final normal = Offset(-tangent.dy, tangent.dx);
    final arrow = Path()..moveTo(tip.dx, tip.dy);
    for (final point in [
      tip - tangent * radius * .5 + normal * radius * .25,
      tip - tangent * radius * .5 - normal * radius * .25,
    ]) {
      arrow.lineTo(point.dx, point.dy);
    }
    arrow.close();
    canvas.drawPath(arrow, Paint()..color = const Color(0xFF142C1F));
  }

  void _drawReading(
    Canvas canvas,
    Rect display,
    String reading, {
    bool illuminated = false,
  }) {
    if (display.width <= 0 || display.height <= 0) return;
    final double radius = (3 * viewport.scale).clamp(1.0, 6.0).toDouble();
    canvas.save();
    canvas.clipRRect(RRect.fromRectAndRadius(display, Radius.circular(radius)));
    canvas.drawRect(
      display,
      Paint()
        ..color = illuminated
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
      math.min(
        targetW / math.max(1, text.width),
        targetH / math.max(1, text.height),
      ),
    );
    canvas.translate(display.center.dx, display.center.dy);
    canvas.scale(fit);
    text.paint(canvas, Offset(-text.width / 2, -text.height / 2));
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
      !identical(frequencyFront, old.frequencyFront) ||
      !identical(phaseSequenceFront, old.phaseSequenceFront) ||
      !setEquals(frequency3dIds, old.frequency3dIds) ||
      !setEquals(phaseSequence3dIds, old.phaseSequence3dIds) ||
      !setEquals(ammeter3dIds, old.ammeter3dIds) ||
      !setEquals(voltmeter3dIds, old.voltmeter3dIds) ||
      selectedElementId != old.selectedElementId;
}
