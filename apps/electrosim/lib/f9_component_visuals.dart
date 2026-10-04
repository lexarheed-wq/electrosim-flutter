import 'dart:math' as math;

import 'package:electrosim_canvas/electrosim_canvas.dart';
import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:electrosim_ui_kit/electrosim_ui_kit.dart';
import 'package:flutter/material.dart';

import 'f18_component_archetypes.dart';
import 'f18_component_asset_visual.dart';
import 'f18_v1_component_visuals.dart';
import 'f9_wiring_policy.dart';
import 'runtime/electrosim_runtime_engine.dart';

class F9CanvasVisualOverlay extends StatefulWidget {
  const F9CanvasVisualOverlay({
    super.key,
    required this.circuit,
    required this.layout,
    required this.viewport,
    this.pendingTerminalId,
    this.hoverTerminalId,
    this.pointerWorldPosition,
    this.wirePreviewPlanner,
    this.runtimeSnapshot,
    this.simulationRunning = false,
  });

  final CircuitState circuit;
  final CircuitVisualLayout layout;
  final ViewportController viewport;
  final TerminalId? pendingTerminalId;
  final TerminalId? hoverTerminalId;
  final Offset? pointerWorldPosition;
  final WirePreviewPlanner? wirePreviewPlanner;
  final ElectroSimRuntimeSnapshot? runtimeSnapshot;
  final bool simulationRunning;

  @override
  State<F9CanvasVisualOverlay> createState() => _F9CanvasVisualOverlayState();
}

class _F9CanvasVisualOverlayState extends State<F9CanvasVisualOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motion = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  );

  @override
  void initState() {
    super.initState();
    _syncMotion();
  }

  @override
  void didUpdateWidget(F9CanvasVisualOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncMotion();
  }

  void _syncMotion() {
    final bool shouldRun =
        widget.simulationRunning && (widget.runtimeSnapshot?.solved ?? false);
    if (shouldRun && !_motion.isAnimating) {
      _motion.repeat();
    } else if (!shouldRun && _motion.isAnimating) {
      _motion.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _motion,
        builder: (BuildContext context, Widget? child) {
          return AnimatedBuilder(
            animation: widget.viewport,
            builder: (BuildContext context, Widget? child) {
              final CircuitGeometryIndex geometry =
                  CircuitGeometryIndex.build(widget.circuit, widget.layout);
              return Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  ..._buildV1Visuals(geometry),
                  CustomPaint(
                    painter: _F9CanvasOverlayPainter(
                      circuit: widget.circuit,
                      layout: widget.layout,
                      viewport: widget.viewport,
                      pendingTerminalId: widget.pendingTerminalId,
                      hoverTerminalId: widget.hoverTerminalId,
                      pointerWorldPosition: widget.pointerWorldPosition,
                      wirePreviewPlanner: widget.wirePreviewPlanner,
                      runtimeSnapshot: widget.runtimeSnapshot,
                      simulationRunning: widget.simulationRunning,
                      animationValue: _motion.value,
                    ),
                    size: Size.infinite,
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  List<Widget> _buildV1Visuals(CircuitGeometryIndex geometry) {
    final List<Widget> widgets = <Widget>[];

    void addVisual({
      required String elementId,
      required String modelType,
      required bool enabled,
      required bool energized,
      required bool closed,
      required bool tripped,
      required bool pressed,
    }) {
      if (!F18V1PilotVisuals.supports(modelType)) return;
      final Rect? worldRect = geometry.elementRects[elementId];
      if (worldRect == null) return;
      final Offset center = widget.viewport.worldToScreen(worldRect.center);
      final Size visualSize = Size(
        worldRect.width * widget.viewport.scale,
        worldRect.height * widget.viewport.scale,
      );
      final int quarterTurns = widget.layout.quarterTurnsOf(elementId);

      widgets.add(
        Positioned(
          left: center.dx - visualSize.width / 2,
          top: center.dy - visualSize.height / 2,
          width: visualSize.width,
          height: visualSize.height,
          child: Transform.rotate(
            angle: math.pi / 2 * quarterTurns,
            child: F18ComponentAssetVisual(
              key: ValueKey<String>('board-v1-visual-$elementId'),
              modelType: modelType,
              size: visualSize,
              active: enabled,
              energized: energized,
              closed: closed,
              tripped: tripped,
              pressed: pressed,
              animationValue: _motion.value,
              showTerminals: false,
            ),
          ),
        ),
      );
    }

    final ElectroSimRuntimeSnapshot? runtime = widget.runtimeSnapshot;
    for (final SourceInstance source in widget.circuit.sources) {
      addVisual(
        elementId: source.id.value,
        modelType: source.modelType,
        enabled: source.enabled,
        energized:
            widget.simulationRunning && (runtime?.solved ?? false) && source.enabled,
        closed: true,
        tripped: false,
        pressed: false,
      );
    }
    for (final ComponentInstance component in widget.circuit.components) {
      final double currentA = _componentCurrentA(runtime, component.id);
      final double voltageV = _componentVoltageV(runtime, component.id);
      final bool energized = widget.simulationRunning &&
          (runtime?.solved ?? false) &&
          (currentA > 1e-6 || voltageV > 1);
      final bool isPush = component.modelType.toLowerCase() == 'push_button_no';
      final bool pressed = component.controlState['pressed'] == true;
      final bool closed = isPush
          ? pressed
          : (component.controlState['closed'] as bool?) ?? true;
      final bool tripped = (runtime?.protectionTripped(component.id) ?? false) ||
          component.controlState['tripped'] == true;

      addVisual(
        elementId: component.id.value,
        modelType: component.modelType,
        enabled: component.condition != ComponentCondition.disabled,
        energized: energized,
        closed: closed,
        tripped: tripped,
        pressed: pressed,
      );
    }
    return widgets;
  }

  static double _componentCurrentA(
    ElectroSimRuntimeSnapshot? runtime,
    ComponentId id,
  ) {
    final result = runtime?.dcResult;
    if (result == null || !result.isSolved) return 0;
    double value = 0;
    for (final branch in result.branchResults) {
      if (branch.id != 'component:' + id.value) continue;
      final double? current = branch.currentA;
      if (current != null && current.isFinite) {
        value = math.max(value, current.abs());
      }
    }
    return value;
  }

  static double _componentVoltageV(
    ElectroSimRuntimeSnapshot? runtime,
    ComponentId id,
  ) {
    final result = runtime?.dcResult;
    if (result == null || !result.isSolved) return 0;
    double value = 0;
    for (final branch in result.branchResults) {
      if (branch.id == 'component:' + id.value && branch.voltageV.isFinite) {
        value = math.max(value, branch.voltageV.abs());
      }
    }
    return value;
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }
}

class _F9CanvasOverlayPainter extends CustomPainter {
  const _F9CanvasOverlayPainter({
    required this.circuit,
    required this.layout,
    required this.viewport,
    required this.pendingTerminalId,
    required this.hoverTerminalId,
    required this.pointerWorldPosition,
    required this.wirePreviewPlanner,
    required this.runtimeSnapshot,
    required this.simulationRunning,
    required this.animationValue,
  });

  final CircuitState circuit;
  final CircuitVisualLayout layout;
  final ViewportController viewport;
  final TerminalId? pendingTerminalId;
  final TerminalId? hoverTerminalId;
  final Offset? pointerWorldPosition;
  final WirePreviewPlanner? wirePreviewPlanner;
  final ElectroSimRuntimeSnapshot? runtimeSnapshot;
  final bool simulationRunning;
  final double animationValue;

  @override
  void paint(Canvas canvas, Size size) {
    final CircuitGeometryIndex geometry =
        CircuitGeometryIndex.build(circuit, layout);
    _paintLiveWires(canvas, geometry);
    _paintSmartWirePreview(canvas);

    for (final SourceInstance source in circuit.sources) {
      final Rect? rect = geometry.elementRects[source.id.value];
      if (rect == null) continue;
      _paintElementGlyph(
        canvas,
        rect,
        source.modelType,
        source.enabled,
        layout.quarterTurnsOf(source.id.value),
      );
    }
    for (final ComponentInstance component in circuit.components) {
      final Rect? rect = geometry.elementRects[component.id.value];
      if (rect == null) continue;
      final Object? closed = component.controlState['closed'];
      final bool active =
          component.condition != ComponentCondition.disabled && closed != false;
      _paintElementGlyph(
        canvas,
        rect,
        component.modelType,
        active,
        layout.quarterTurnsOf(component.id.value),
      );
    }

    _paintTerminals(canvas, geometry);
    _paintWiringTargets(canvas, geometry);
  }

  void _paintLiveWires(Canvas canvas, CircuitGeometryIndex geometry) {
    final ElectroSimRuntimeSnapshot? runtime = runtimeSnapshot;
    final result = runtime?.dcResult;
    if (!simulationRunning ||
        runtime == null ||
        result == null ||
        !result.isSolved) {
      return;
    }

    for (final Connection connection in circuit.connections) {
      if (!runtime.topology.enabledConnectionIds.contains(connection.id)) {
        continue;
      }
      final double currentA = _connectionCurrentA(runtime, connection);
      if (currentA <= 1e-6) continue;

      final Offset? start =
          geometry.terminalPositions[connection.fromTerminalId];
      final Offset? end = geometry.terminalPositions[connection.toTerminalId];
      if (start == null || end == null) continue;

      final List<Offset> points = <Offset>[
        start,
        ...layout.routeFor(connection.id.value),
        end,
      ];
      if (points.length < 2) continue;

      final Path path = Path();
      final Offset first = viewport.worldToScreen(points.first);
      path.moveTo(first.dx, first.dy);
      for (final Offset worldPoint in points.skip(1)) {
        final Offset p = viewport.worldToScreen(worldPoint);
        path.lineTo(p.dx, p.dy);
      }

      final Color phase = _phaseColor(connection.phase);
      canvas.drawPath(
        path,
        Paint()
          ..color = Color.fromARGB(48, phase.red, phase.green, phase.blue)
          ..strokeWidth = 7
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );

      final double speed =
          22 + math.min(78, math.sqrt(math.max(0, currentA)) * 28);
      _paintMovingDashes(
        canvas,
        path,
        speed: speed,
        animationValue: animationValue,
      );
    }
  }

  double _connectionCurrentA(
    ElectroSimRuntimeSnapshot runtime,
    Connection connection,
  ) {
    final String? nodeId =
        runtime.topology.terminalToNode[connection.fromTerminalId];
    final result = runtime.dcResult;
    if (nodeId == null || result == null) return 0;

    double current = 0;
    for (final branch in result.branchResults) {
      if (branch.fromNodeId != nodeId && branch.toNodeId != nodeId) continue;
      final double? branchCurrent = branch.currentA;
      if (branchCurrent == null || !branchCurrent.isFinite) continue;
      current = math.max(current, branchCurrent.abs());
    }
    return current;
  }

  void _paintMovingDashes(
    Canvas canvas,
    Path path, {
    required double speed,
    required double animationValue,
  }) {
    const double dash = 2;
    const double gap = 12;
    const double cycle = dash + gap;
    final double offset = (animationValue * speed) % cycle;
    final Paint paint = Paint()
      ..color = const Color(0xEBFFFFFF)
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    for (final metric in path.computeMetrics()) {
      double cursor = -offset;
      while (cursor < metric.length) {
        final double start = math.max(0, cursor);
        final double end = math.min(metric.length, cursor + dash);
        if (end > start) {
          canvas.drawPath(metric.extractPath(start, end), paint);
        }
        cursor += cycle;
      }
    }
  }

  void _paintSmartWirePreview(Canvas canvas) {
    final TerminalId? pending = pendingTerminalId;
    final Offset? pointer = pointerWorldPosition;
    final WirePreviewPlanner? planner = wirePreviewPlanner;
    if (pending == null || pointer == null || planner == null) return;

    final WirePreviewPlan plan = planner.plan(
      circuit: circuit,
      layout: layout,
      startTerminalId: pending,
      pointerWorldPosition: pointer,
    );
    if (!plan.route.isResolved) return;

    final List<Offset> points = plan.route.path!.points;
    if (points.length < 2) return;
    final Path path = Path();
    final Offset first = viewport.worldToScreen(points.first);
    path.moveTo(first.dx, first.dy);
    for (final Offset point in points.skip(1)) {
      final Offset screen = viewport.worldToScreen(point);
      path.lineTo(screen.dx, screen.dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = ElectroSimColors.primary
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  void _paintTerminals(Canvas canvas, CircuitGeometryIndex geometry) {
    for (final MapEntry<TerminalId, Offset> entry
        in geometry.terminalPositions.entries) {
      final Offset p = viewport.worldToScreen(entry.value);
      final bool pending = entry.key == pendingTerminalId;
      final bool hovered = entry.key == hoverTerminalId;
      final double radius = pending || hovered ? 6.4 : 5.2;

      if (pending || hovered) {
        canvas.drawCircle(
          p,
          radius + 3,
          Paint()
            ..color = Color.fromARGB(
              52,
              ElectroSimColors.primary.red,
              ElectroSimColors.primary.green,
              ElectroSimColors.primary.blue,
            ),
        );
      }
      canvas.drawCircle(
        p.translate(0, 1),
        radius,
        Paint()..color = const Color(0x33000000),
      );
      final Rect metal = Rect.fromCircle(center: p, radius: radius);
      canvas.drawCircle(
        p,
        radius,
        Paint()
          ..shader = const RadialGradient(
            center: Alignment(-.35, -.35),
            colors: <Color>[
              Color(0xFFFFF2BF),
              Color(0xFFD4A44B),
              Color(0xFF7C5927),
            ],
          ).createShader(metal),
      );
      canvas.drawCircle(
        p,
        radius,
        Paint()
          ..color = pending || hovered
              ? ElectroSimColors.primary
              : const Color(0xFF49371F)
          ..strokeWidth = pending || hovered ? 2.2 : 1.4
          ..style = PaintingStyle.stroke,
      );
      canvas.drawCircle(
        p,
        math.max(1.5, radius * .30),
        Paint()..color = const Color(0xFF4D3A22),
      );
    }
  }

  void _paintWiringTargets(Canvas canvas, CircuitGeometryIndex geometry) {
    final TerminalId? pending = pendingTerminalId;
    if (pending == null) return;
    for (final MapEntry<TerminalId, Offset> entry
        in geometry.terminalPositions.entries) {
      final Offset screen = viewport.worldToScreen(entry.value);
      if (entry.key == pending) continue;
      final F9WiringDecision decision =
          F9WiringPolicy.evaluateAndBuild(circuit, pending, entry.key);
      final bool hovered = entry.key == hoverTerminalId;
      if (!decision.accepted && !hovered) continue;
      final Color color =
          decision.accepted ? ElectroSimColors.success : ElectroSimColors.danger;
      canvas.drawCircle(
        screen,
        hovered ? 12 : 9,
        Paint()
          ..color = color
          ..strokeWidth = hovered ? 3 : 2
          ..style = PaintingStyle.stroke,
      );
      if (hovered) {
        final TextPainter marker = TextPainter(
          text: TextSpan(
            text: decision.accepted ? '✓' : '×',
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        marker.paint(canvas, Offset(screen.dx + 10, screen.dy - 16));
      }
    }
  }

  void _paintElementGlyph(
    Canvas canvas,
    Rect worldRect,
    String modelType,
    bool active,
    int quarterTurns,
  ) {
    final Offset center = viewport.worldToScreen(worldRect.center);
    final Size visualSize = _f9VisualSize(worldRect, viewport);
    final Color color =
        active ? ElectroSimColors.primary : ElectroSimColors.textSecondary;

    if (!F18V1PilotVisuals.supports(modelType)) {
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(math.pi / 2 * quarterTurns);
      paintF18ComponentIdentity(
        canvas,
        Rect.fromCenter(
          center: Offset.zero,
          width: visualSize.width,
          height: visualSize.height,
        ),
        modelType,
        color,
      );
      canvas.restore();
    }

    if (viewport.scale >= 0.72) {
      final TextPainter painter = TextPainter(
        text: TextSpan(
          text: _boardLabel(modelType),
          style: TextStyle(
            color: ElectroSimColors.textPrimary,
            fontSize: (11.5 * viewport.scale).clamp(10.0, 14.0).toDouble(),
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout(maxWidth: visualSize.width + 40);
      painter.paint(
        canvas,
        Offset(
          center.dx - painter.width / 2,
          center.dy + visualSize.height / 2 + 7,
        ),
      );
    }
  }

  String _boardLabel(String modelType) {
    return switch (modelType.toLowerCase()) {
      'dc_voltage_source' || 'voltage_source' => 'Alim. 24 V',
      'push_button_no' => 'BP NO',
      'switch' || 'switch_spst' => 'Interrupteur',
      'lamp' => 'Lampe',
      'resistor' => 'Résistance',
      'breaker_dc' || 'breaker_ac1' || 'breaker' => 'Disjoncteur',
      'fuse_dc' || 'fuse_ac1' || 'fuse' => 'Fusible',
      'motor_dc' => 'Moteur CC',
      'fan_dc' => 'Ventilateur',
      'relay_coil' => 'Bobine',
      'buzzer' => 'Buzzer',
      _ => modelType.replaceAll('_', ' '),
    };
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
  bool shouldRepaint(_F9CanvasOverlayPainter oldDelegate) => true;
}

Size _f9VisualSize(
  Rect worldRect,
  ViewportController viewport,
) {
  final double scale = viewport.scale;
  return Size(
    (worldRect.width * scale * 0.96).clamp(72.0, 136.0).toDouble(),
    (worldRect.height * scale * 0.96).clamp(46.0, 92.0).toDouble(),
  );
}
