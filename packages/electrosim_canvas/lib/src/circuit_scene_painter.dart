import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:flutter/material.dart';

import 'canvas_geometry.dart';
import 'circuit_visual_layout.dart';
import 'viewport_controller.dart';
import 'wire_preview_planner.dart';
import 'wire_semantics.dart';
import 'physical_wire_path.dart';
import 'din_rail_visual.dart';

final class CircuitScenePainter extends CustomPainter {
  CircuitScenePainter({
    required this.circuit,
    required this.layout,
    required this.viewport,
    this.selectedElementId,
    this.pendingTerminalId,
    this.pointerWorldPosition,
    this.previewPositions = const <String, Offset>{},
    this.wirePreviewPlanner,
    this.wirePreviewSession,
    this.smartWireSemantics = false,
    this.paintElementChrome = true,
  }) : viewportScaleAtBuild = viewport.scale,
       viewportTranslationAtBuild = viewport.translation,
       geometryAtBuild = CircuitGeometryIndex.build(
         circuit,
         layout,
         previewPositions: previewPositions,
       ),
       semanticsAtBuild = smartWireSemantics
           ? const WireSemanticsAnalyzer().analyze(
               circuit: circuit,
               layout: layout,
             )
           : null;

  final CircuitState circuit;
  final CircuitVisualLayout layout;
  final ViewportController viewport;
  final String? selectedElementId;
  final TerminalId? pendingTerminalId;
  final Offset? pointerWorldPosition;
  final Map<String, Offset> previewPositions;
  final WirePreviewPlanner? wirePreviewPlanner;
  final WirePreviewSession? wirePreviewSession;
  final bool smartWireSemantics;
  final double viewportScaleAtBuild;
  final Offset viewportTranslationAtBuild;
  final bool paintElementChrome;
  final CircuitGeometryIndex geometryAtBuild;
  final WireSemantics? semanticsAtBuild;
  late final List<Rect> dinSupportsAtBuild = _buildDinSupports();

  static const Color boardColor = Color(0xFFF6F8FB);
  static const Color gridColor = Color(0xFFE3E8EF);
  static const Color elementFill = Color(0xFFFFFFFF);
  static const Color elementStroke = Color(0xFF334155);
  static const Color sourceFill = Color(0xFFEFF6FF);
  static const Color terminalFill = Color(0xFFFFFFFF);
  static const Color terminalStroke = Color(0xFF0F172A);
  static const Color selectionColor = Color(0xFF2563EB);
  static const Color pendingColor = Color(0xFFF59E0B);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = boardColor);
    _paintGrid(canvas, size);

    final CircuitGeometryIndex geometry = geometryAtBuild;
    final WireSemantics? semantics = semanticsAtBuild;
    if (!paintElementChrome) {
      _paintDinSupports(canvas, geometry);
    }
    _paintWires(canvas, geometry);
    if (semantics != null) {
      _paintNonJunctionCrossingGaps(canvas, semantics);
      _paintInteriorJunctions(canvas, semantics);
    }
    if (paintElementChrome) {
      _paintSources(canvas, geometry);
      _paintComponents(canvas, geometry);
      _paintTerminals(canvas, geometry, semantics);
    }
    // Meters are physical artifacts regardless of the electrical symbol
    // overlay and are never disguised as solver receiver components.
    _paintInstruments(canvas, geometry);
    _paintWiringPreview(canvas, geometry);
  }

  void _paintGrid(Canvas canvas, Size size) {
    const double worldStep = 24;
    final double step = worldStep * viewport.scale;
    if (step < 9) {
      return;
    }
    final Paint paint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    final double xStart = viewport.translation.dx % step;
    final double yStart = viewport.translation.dy % step;
    for (double x = xStart; x <= size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = yStart; y <= size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  List<Rect> _buildDinSupports() {
    const mountedTypes = <String>{
      'breaker_dc',
      'breaker_ac1',
      'breaker',
      'breaker_3p',
      'breaker_4p',
      'contactor_ac1',
      'contactor_3p',
      'relay_coil',
      'isolator_3p',
      'isolator_4p',
      'terminal_block_5',
      'thermal_overload_3p',
    };
    final mounts = <Rect>[];
    for (final component in circuit.components) {
      final type =
          ((component.parameters['_visualModelType'] as String?) ??
                  component.modelType)
              .toLowerCase();
      if (!mountedTypes.contains(type) ||
          layout.quarterTurnsOf(component.id.value) != 0) {
        continue;
      }
      final rect = geometryAtBuild.elementRects[component.id.value];
      if (rect != null) mounts.add(rect);
    }
    // Generic front-view mounting plates for aligned panel push buttons.
    // This is decorative assembly artwork, not a mechanical compatibility
    // check. Only extend an existing DIN row; do not invent a rail elsewhere.
    final rows = mounts.map((r) => r.center.dy).toSet();
    for (final component in circuit.components) {
      final type =
          ((component.parameters['_visualModelType'] as String?) ??
                  component.modelType)
              .toLowerCase();
      if ((type != 'push_button_no' && type != 'push_button_nc') ||
          layout.quarterTurnsOf(component.id.value) != 0) {
        continue;
      }
      final rect = geometryAtBuild.elementRects[component.id.value];
      if (rect != null && rows.contains(rect.center.dy)) mounts.add(rect);
    }
    return layoutDinRails(mounts);
  }

  void _paintDinSupports(Canvas canvas, CircuitGeometryIndex geometry) {
    for (final rail in dinSupportsAtBuild) {
      final rect = Rect.fromCenter(
        center: viewport.worldToScreen(rail.center),
        width: rail.width * viewport.scale,
        height: rail.height * viewport.scale,
      );
      paintDinRail(canvas, rect, scale: viewport.scale);
    }
  }

  void _paintWires(Canvas canvas, CircuitGeometryIndex geometry) {
    for (final Connection connection in circuit.connections) {
      final Offset? start =
          geometry.terminalPositions[connection.fromTerminalId];
      final Offset? end = geometry.terminalPositions[connection.toTerminalId];
      if (start == null || end == null) {
        continue;
      }
      final List<Offset> worldPoints = <Offset>[
        start,
        ...layout.routeFor(connection.id.value),
        end,
      ];
      final Path path = buildPhysicalWirePath(
        worldPoints.map(viewport.worldToScreen).toList(),
        bendRadius: paintElementChrome ? 0 : 6 * viewport.scale,
      );
      final bool selected = selectedElementId == connection.id.value;
      final double wireWidth = paintElementChrome
          ? 3
          : (4 * viewport.scale).clamp(2.0, 7.0).toDouble();
      if (!paintElementChrome) {
        canvas.drawPath(
          path.shift(const Offset(0, 1.2)),
          Paint()
            ..color = const Color(0x35000000)
            ..strokeWidth = wireWidth + 2
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round,
        );
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = selected ? selectionColor : _phaseColor(connection.phase)
          ..strokeWidth = selected ? wireWidth + 2 : wireWidth
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
      if (!paintElementChrome && viewport.scale >= .65) {
        canvas.drawPath(
          path,
          Paint()
            ..color = const Color(0x45FFFFFF)
            ..strokeWidth = wireWidth * .25
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round,
        );
      }
    }
  }

  void _paintSources(Canvas canvas, CircuitGeometryIndex geometry) {
    for (final SourceInstance source in circuit.sources) {
      final Rect? rect = geometry.elementRects[source.id.value];
      if (rect != null) {
        _paintElement(canvas, rect, source.id.value, source.modelType, true);
      }
    }
  }

  void _paintComponents(Canvas canvas, CircuitGeometryIndex geometry) {
    for (final ComponentInstance component in circuit.components) {
      final Rect? rect = geometry.elementRects[component.id.value];
      if (rect != null) {
        _paintElement(
          canvas,
          rect,
          component.id.value,
          component.modelType,
          false,
        );
      }
    }
  }

  void _paintInstruments(Canvas canvas, CircuitGeometryIndex geometry) {
    for (final InstrumentInstance instrument in circuit.instruments) {
      final Rect? worldRect = geometry.elementRects[instrument.id.value];
      if (worldRect == null) continue;
      final Rect rect = Rect.fromCenter(
        center: viewport.worldToScreen(worldRect.center),
        width: worldRect.width * viewport.scale,
        height: worldRect.height * viewport.scale,
      );
      final bool selected = selectedElementId == instrument.id.value;
      final RRect caseShape = RRect.fromRectAndRadius(
        rect, Radius.circular(12 * viewport.scale));
      canvas.drawRRect(caseShape, Paint()..color = const Color(0xFF283748));
      canvas.drawRRect(
        caseShape,
        Paint()
          ..color = selected ? selectionColor : const Color(0xFF101E30)
          ..style = PaintingStyle.stroke
          ..strokeWidth = selected ? 3 : 1.5,
      );
      final Rect display = Rect.fromLTWH(
        rect.left + rect.width * 0.10,
        rect.top + rect.height * 0.11,
        rect.width * 0.80,
        rect.height * 0.38,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(display, Radius.circular(3 * viewport.scale)),
        Paint()..color = const Color(0xFFD5E5D6),
      );
      final bool current = instrument.kind == InstrumentKind.ammeter ||
          instrument.mode == InstrumentMode.currentDc ||
          instrument.mode == InstrumentMode.currentAcRms;
      final String title = current ? 'A' : 'V';
      // No fabricated electrical reading: dash until leads/solver are valid.
      final TextPainter label = TextPainter(
        text: TextSpan(
          text: instrument.poweredOn ? '— $title' : 'OFF',
          style: TextStyle(
            fontSize: (13 * viewport.scale).clamp(7, 23).toDouble(),
            color: const Color(0xFF142C1F),
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: display.width);
      label.paint(canvas, Offset(
        display.center.dx - label.width / 2,
        display.center.dy - label.height / 2,
      ));
      final double y = rect.bottom - rect.height * 0.20;
      final double radius = (4.5 * viewport.scale).clamp(2, 9).toDouble();
      canvas.drawCircle(
        Offset(rect.left + rect.width * 0.28, y), radius,
        Paint()..color = const Color(0xFFD12B3C));
      canvas.drawCircle(
        Offset(rect.left + rect.width * 0.72, y), radius,
        Paint()..color = const Color(0xFF15202D));
    }
  }

  void _paintElement(
    Canvas canvas,
    Rect worldRect,
    String elementId,
    String modelType,
    bool source,
  ) {
    final Rect rect = Rect.fromCenter(
      center: viewport.worldToScreen(worldRect.center),
      width: worldRect.width * viewport.scale,
      height: worldRect.height * viewport.scale,
    );
    final bool selected = selectedElementId == elementId;
    final RRect rrect = RRect.fromRectAndRadius(
      rect,
      const Radius.circular(10),
    );
    canvas.drawRRect(rrect, Paint()..color = source ? sourceFill : elementFill);
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = selected ? selectionColor : elementStroke
        ..strokeWidth = selected ? 3 : 1.5
        ..style = PaintingStyle.stroke,
    );

    // The application-level F18 overlay owns the model-specific electrical
    // symbol. The canvas base layer intentionally does not paint raw model
    // identifiers such as "motor_dc" behind that symbol.
    if (selected) {
      final double markerRadius = (3.5 * viewport.scale)
          .clamp(2.5, 5.0)
          .toDouble();
      canvas.drawCircle(
        Offset(rect.right - markerRadius * 2, rect.top + markerRadius * 2),
        markerRadius,
        Paint()..color = selectionColor,
      );
    }
  }

  void _paintNonJunctionCrossingGaps(Canvas canvas, WireSemantics semantics) {
    final double radius = (5 * viewport.scale).clamp(3, 7).toDouble();
    for (final NonJunctionWireCrossing crossing
        in semantics.nonJunctionCrossings) {
      canvas.drawCircle(
        viewport.worldToScreen(crossing.point),
        radius,
        Paint()..color = boardColor,
      );
    }
  }

  void _paintInteriorJunctions(Canvas canvas, WireSemantics semantics) {
    final double radius = (4 * viewport.scale).clamp(2.5, 6).toDouble();
    for (final Offset worldPoint in semantics.interiorJunctionPoints) {
      canvas.drawCircle(
        viewport.worldToScreen(worldPoint),
        radius,
        Paint()..color = terminalStroke,
      );
    }
  }

  void _paintTerminals(
    Canvas canvas,
    CircuitGeometryIndex geometry,
    WireSemantics? semantics,
  ) {
    for (final MapEntry<TerminalId, Offset> entry
        in geometry.terminalPositions.entries) {
      final Offset screen = viewport.worldToScreen(entry.value);
      final bool pending = entry.key == pendingTerminalId;
      final bool junction =
          semantics?.junctionTerminalIds.contains(entry.key) ?? false;
      final double radius = pending ? 7 : 5;
      canvas.drawCircle(
        screen,
        radius,
        Paint()
          ..color = pending
              ? pendingColor
              : junction
              ? terminalStroke
              : terminalFill,
      );
      canvas.drawCircle(
        screen,
        radius,
        Paint()
          ..color = pending ? pendingColor : terminalStroke
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke,
      );
    }
  }

  void _paintWiringPreview(Canvas canvas, CircuitGeometryIndex geometry) {
    if (pendingTerminalId == null || pointerWorldPosition == null) {
      return;
    }
    final Offset? start = geometry.terminalPositions[pendingTerminalId];
    if (start == null) {
      return;
    }

    final WirePreviewPlanner? planner = wirePreviewPlanner;
    if (planner != null) {
      final WirePreviewSession? session = wirePreviewSession;
      final WirePreviewPlan preview = session == null
          ? planner.plan(
              circuit: circuit,
              layout: layout,
              startTerminalId: pendingTerminalId!,
              pointerWorldPosition: pointerWorldPosition!,
            )
          : planner.planPrepared(
              session: session,
              pointerWorldPosition: pointerWorldPosition!,
            );
      if (!preview.route.isResolved) {
        return;
      }
      final List<Offset> points = preview.route.path!.points;
      final Path path = Path();
      final Offset first = viewport.worldToScreen(points.first);
      path.moveTo(first.dx, first.dy);
      for (final Offset worldPoint in points.skip(1)) {
        final Offset point = viewport.worldToScreen(worldPoint);
        path.lineTo(point.dx, point.dy);
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = pendingColor
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
      return;
    }

    canvas.drawLine(
      viewport.worldToScreen(start),
      viewport.worldToScreen(pointerWorldPosition!),
      Paint()
        ..color = pendingColor
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke,
    );
  }

  static Color _phaseColor(PhaseTag phase) => switch (phase) {
    PhaseTag.dcPositive => const Color(0xFFDC2626),
    PhaseTag.dcNegative => const Color(0xFF111827),
    PhaseTag.l1 => const Color(0xFF92400E),
    PhaseTag.l2 => const Color(0xFF111827),
    PhaseTag.l3 => const Color(0xFF6B7280),
    PhaseTag.neutral => const Color(0xFF2563EB),
    PhaseTag.protectiveEarth => const Color(0xFF15803D),
    PhaseTag.none => const Color(0xFF475569),
  };

  @override
  bool shouldRepaint(CircuitScenePainter oldDelegate) =>
      oldDelegate.circuit != circuit ||
      oldDelegate.layout != layout ||
      oldDelegate.selectedElementId != selectedElementId ||
      oldDelegate.pendingTerminalId != pendingTerminalId ||
      oldDelegate.pointerWorldPosition != pointerWorldPosition ||
      oldDelegate.previewPositions != previewPositions ||
      oldDelegate.wirePreviewPlanner != wirePreviewPlanner ||
      oldDelegate.wirePreviewSession != wirePreviewSession ||
      oldDelegate.smartWireSemantics != smartWireSemantics ||
      oldDelegate.paintElementChrome != paintElementChrome ||
      oldDelegate.viewportScaleAtBuild != viewportScaleAtBuild ||
      oldDelegate.viewportTranslationAtBuild != viewportTranslationAtBuild;
}

/// Lightweight painter used during an active wire gesture.
///
/// The dense static circuit lives behind a repaint boundary; pointer movement
/// only repaints this overlay and uses the prepared routing session.
final class CircuitWirePreviewPainter extends CustomPainter {
  CircuitWirePreviewPainter({
    required this.viewport,
    required this.planner,
    required this.session,
    required this.pointerWorldPosition,
  }) : viewportScaleAtBuild = viewport.scale,
       viewportTranslationAtBuild = viewport.translation;

  final ViewportController viewport;
  final WirePreviewPlanner planner;
  final WirePreviewSession session;
  final Offset pointerWorldPosition;
  final double viewportScaleAtBuild;
  final Offset viewportTranslationAtBuild;

  @override
  void paint(Canvas canvas, Size size) {
    final WirePreviewPlan preview = planner.planPrepared(
      session: session,
      pointerWorldPosition: pointerWorldPosition,
    );
    if (!preview.route.isResolved) return;
    final List<Offset> points = preview.route.path!.points;
    if (points.isEmpty) return;
    final Path path = Path();
    final Offset first = viewport.worldToScreen(points.first);
    path.moveTo(first.dx, first.dy);
    for (final Offset worldPoint in points.skip(1)) {
      final Offset point = viewport.worldToScreen(worldPoint);
      path.lineTo(point.dx, point.dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = CircuitScenePainter.pendingColor
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(CircuitWirePreviewPainter oldDelegate) =>
      oldDelegate.pointerWorldPosition != pointerWorldPosition ||
      oldDelegate.session != session ||
      oldDelegate.planner != planner ||
      oldDelegate.viewportScaleAtBuild != viewportScaleAtBuild ||
      oldDelegate.viewportTranslationAtBuild != viewportTranslationAtBuild;
}
