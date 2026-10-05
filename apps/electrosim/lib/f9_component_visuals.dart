import 'dart:math' as math;

import 'package:electrosim_canvas/electrosim_canvas.dart';
import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:electrosim_ui_kit/electrosim_ui_kit.dart';
import 'package:flutter/material.dart';

import 'f18_component_archetypes.dart';
import 'f18_component_asset_visual.dart';
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
                  ..._buildReferenceVisuals(geometry),
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

  List<Widget> _buildReferenceVisuals(CircuitGeometryIndex geometry) {
    final List<Widget> widgets = <Widget>[];

    void addVisual({
      required String elementId,
      required String modelType,
      String? visualVariant,
      required bool enabled,
      required bool energized,
      required bool closed,
      required bool tripped,
      required bool pressed,
      required bool actuated,
      required double currentA,
      required double voltageV,
      required double ratedCurrentA,
      required double currentLimitA,
      required double resistanceOhm,
    }) {
      if (!F18ReferenceComponentVisuals.supports(modelType)) return;
      final Rect? worldRect = geometry.elementRects[elementId];
      if (worldRect == null) return;
      final Offset center = widget.viewport.worldToScreen(worldRect.center);
      final int quarterTurns = widget.layout.quarterTurnsOf(elementId);
      final Size baseWorldSize = widget.layout.sizeOf(elementId);
      final Size baseVisualSize = Size(
        baseWorldSize.width * widget.viewport.scale,
        baseWorldSize.height * widget.viewport.scale,
      );
      final Size displayVisualSize = quarterTurns.isOdd
          ? Size(baseVisualSize.height, baseVisualSize.width)
          : baseVisualSize;

      widgets.add(
        Positioned(
          left: center.dx - displayVisualSize.width / 2,
          top: center.dy - displayVisualSize.height / 2,
          width: displayVisualSize.width,
          height: displayVisualSize.height,
          child: Center(
            child: Transform.rotate(
              angle: math.pi / 2 * quarterTurns,
              child: F18ComponentAssetVisual(
              key: ValueKey<String>('board-v1-visual-$elementId'),
              modelType: modelType,
              variantKey: visualVariant,
              size: baseVisualSize,
              active: enabled,
              energized: energized,
              closed: closed,
              tripped: tripped,
              pressed: pressed,
              actuated: actuated,
              animationValue: _motion.value,
              showTerminals: true,
              currentA: currentA,
              voltageV: voltageV,
              ratedCurrentA: ratedCurrentA,
              currentLimitA: currentLimitA,
              resistanceOhm: resistanceOhm,
              ),
            ),
          ),
        ),
      );
    }

    final ElectroSimRuntimeSnapshot? runtime = widget.runtimeSnapshot;
    for (final SourceInstance source in widget.circuit.sources) {
      final double currentA =
          _sourceCurrentA(runtime, source.id, source.modelType);
      final double voltageV =
          _sourceVoltageV(runtime, source.id, source.modelType);
      addVisual(
        elementId: source.id.value,
        modelType: source.modelType,
        visualVariant: source.parameters['_visualVariant'] as String?,
        enabled: source.enabled,
        energized:
            widget.simulationRunning && (runtime?.solved ?? false) && source.enabled,
        closed: true,
        tripped: false,
        pressed: false,
        actuated: false,
        currentA: currentA,
        voltageV: voltageV,
        ratedCurrentA: 1,
        currentLimitA:
            (source.parameters['currentLimitA'] as num?)?.toDouble() ?? 2,
        resistanceOhm: 0,
      );
    }
    for (final ComponentInstance component in widget.circuit.components) {
      final double currentA = _componentSignedCurrentA(
        runtime,
        component.id,
        component.modelType,
      );
      final double voltageV = _componentVoltageV(
        runtime,
        component.id,
        component.modelType,
      );
      final bool energized = widget.simulationRunning &&
          (runtime?.solved ?? false) &&
          currentA.abs() > 1e-6;
      final String type = component.modelType.toLowerCase();
      final bool pressed = component.controlState['pressed'] == true;
      final bool closed = switch (type) {
        'push_button_no' => pressed,
        'push_button_nc' => !pressed,
        _ => (component.controlState['closed'] as bool?) ?? true,
      };
      final bool tripped = (runtime?.protectionTripped(component.id) ?? false) ||
          component.controlState['tripped'] == true;
      final bool contactorAux =
          type == 'contactor_aux_no' || type == 'contactor_aux_nc';
      final bool relayAux =
          type == 'relay_contact_no' || type == 'relay_contact_nc';
      final Object? linkedId = component.parameters[
          relayAux ? 'linkedRelayId' : 'linkedContactorId'];
      final bool actuated = (contactorAux || relayAux) && linkedId is String
          ? (runtime?.contactorActuated(ComponentId(linkedId)) ??
              (component.controlState['actuated'] == true))
          : (runtime?.contactorActuated(component.id) ??
              (component.controlState['actuated'] == true));

      addVisual(
        elementId: component.id.value,
        modelType: component.modelType,
        visualVariant: component.parameters['_visualVariant'] as String?,
        enabled: component.condition != ComponentCondition.disabled,
        energized: energized,
        closed: closed,
        tripped: tripped,
        pressed: pressed,
        actuated: actuated,
        currentA: currentA,
        voltageV: voltageV,
        ratedCurrentA:
            (component.parameters['ratedCurrentA'] as num?)?.toDouble() ?? 1,
        currentLimitA: 2,
        resistanceOhm:
            (component.parameters['resistanceOhm'] as num?)?.toDouble() ?? 0,
      );
    }
    return widgets;
  }

  static double _componentSignedCurrentA(
    ElectroSimRuntimeSnapshot? runtime,
    ComponentId id,
    String modelType,
  ) {
    if (runtime == null) return 0;
    final String prefix = 'component:${id.value}';

    final dc = runtime.dcResult;
    if (dc != null && dc.isSolved) {
      double value = 0;
      for (final branch in dc.branchResults) {
        if (branch.id != prefix && !branch.id.startsWith('$prefix:')) continue;
        final double? current = branch.currentA;
        if (current != null && current.isFinite && current.abs() > value.abs()) {
          value = current;
        }
      }
      return value;
    }

    final ac1 = runtime.ac1Result;
    if (ac1 != null && ac1.isSolved) {
      double value = 0;
      for (final branch in ac1.branchResults) {
        if (branch.id != prefix && !branch.id.startsWith('$prefix:')) continue;
        final double? current = branch.current?.magnitude;
        if (current != null && current.isFinite) value = math.max(value, current);
      }
      return value;
    }

    final ac3 = runtime.ac3Result;
    if (ac3 != null && ac3.isSolved) {
      double value = 0;
      for (final branch in ac3.branchResults) {
        if (branch.id != prefix && !branch.id.startsWith('$prefix:')) continue;
        final double? current = branch.current?.magnitude;
        if (current != null && current.isFinite) value = math.max(value, current);
      }
      return value;
    }

    final pv = runtime.pvResult;
    if (pv != null && pv.isSolved) {
      if (modelType == 'pv_inverter') {
        return pv.inverterOutputCurrentRmsA;
      }
      if (modelType == 'pv_resistive_load') {
        for (final load in pv.loadResults) {
          if (load.componentId == id) return load.currentRmsA;
        }
      }
    }
    return 0;
  }

  static double _sourceCurrentA(
    ElectroSimRuntimeSnapshot? runtime,
    SourceId id,
    String modelType,
  ) {
    if (runtime == null) return 0;
    final String target = 'source:${id.value}';
    final dc = runtime.dcResult;
    if (dc != null && dc.isSolved) {
      for (final branch in dc.branchResults) {
        if (branch.id != target) continue;
        final double? current = branch.currentA;
        if (current != null && current.isFinite) return current.abs();
      }
    }
    final ac1 = runtime.ac1Result;
    if (ac1 != null && ac1.isSolved) {
      for (final branch in ac1.branchResults) {
        if (branch.id != target) continue;
        final double? current = branch.current?.magnitude;
        if (current != null && current.isFinite) return current;
      }
    }
    final ac3 = runtime.ac3Result;
    if (ac3 != null && ac3.isSolved) {
      for (final branch in ac3.branchResults) {
        if (branch.id != target) continue;
        final double? current = branch.current?.magnitude;
        if (current != null && current.isFinite) return current;
      }
    }
    final pv = runtime.pvResult;
    if (pv != null && pv.isSolved && modelType == 'pv_array') {
      return pv.pvDrawnCurrentA;
    }
    return 0;
  }

  static double _sourceVoltageV(
    ElectroSimRuntimeSnapshot? runtime,
    SourceId id,
    String modelType,
  ) {
    if (runtime == null) return 0;
    final String target = 'source:${id.value}';
    final dc = runtime.dcResult;
    if (dc != null && dc.isSolved) {
      for (final branch in dc.branchResults) {
        if (branch.id == target && branch.voltageV.isFinite) {
          return branch.voltageV.abs();
        }
      }
    }
    final ac1 = runtime.ac1Result;
    if (ac1 != null && ac1.isSolved) {
      for (final branch in ac1.branchResults) {
        if (branch.id == target && branch.voltage.magnitude.isFinite) {
          return branch.voltage.magnitude;
        }
      }
    }
    final ac3 = runtime.ac3Result;
    if (ac3 != null && ac3.isSolved) {
      for (final branch in ac3.branchResults) {
        if (branch.id == target && branch.voltage.magnitude.isFinite) {
          return branch.voltage.magnitude;
        }
      }
    }
    final pv = runtime.pvResult;
    if (pv != null && pv.isSolved && modelType == 'pv_array') {
      return pv.pvOperatingVoltageV;
    }
    return 0;
  }

  static double _componentVoltageV(
    ElectroSimRuntimeSnapshot? runtime,
    ComponentId id,
    String modelType,
  ) {
    if (runtime == null) return 0;
    final String prefix = 'component:${id.value}';
    double value = 0;
    final dc = runtime.dcResult;
    if (dc != null && dc.isSolved) {
      for (final branch in dc.branchResults) {
        if (branch.id != prefix && !branch.id.startsWith('$prefix:')) continue;
        if (branch.voltageV.isFinite) value = math.max(value, branch.voltageV.abs());
      }
      return value;
    }
    final ac1 = runtime.ac1Result;
    if (ac1 != null && ac1.isSolved) {
      for (final branch in ac1.branchResults) {
        if (branch.id != prefix && !branch.id.startsWith('$prefix:')) continue;
        if (branch.voltage.magnitude.isFinite) value = math.max(value, branch.voltage.magnitude);
      }
      return value;
    }
    final ac3 = runtime.ac3Result;
    if (ac3 != null && ac3.isSolved) {
      for (final branch in ac3.branchResults) {
        if (branch.id != prefix && !branch.id.startsWith('$prefix:')) continue;
        if (branch.voltage.magnitude.isFinite) value = math.max(value, branch.voltage.magnitude);
      }
      return value;
    }
    final pv = runtime.pvResult;
    if (pv != null && pv.isSolved) {
      if (modelType == 'pv_inverter') {
        return pv.inverterOutputVoltageRmsV;
      }
      if (modelType == 'pv_resistive_load') {
        for (final load in pv.loadResults) {
          if (load.componentId == id) return load.voltageRmsV;
        }
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
        displayLabel: source.parameters['_displayLabel'] as String?,
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
        displayLabel: component.parameters['_displayLabel'] as String?,
      );
    }

    _paintTerminals(canvas, geometry);
    _paintWiringTargets(canvas, geometry);
  }

  void _paintLiveWires(Canvas canvas, CircuitGeometryIndex geometry) {
    final ElectroSimRuntimeSnapshot? runtime = runtimeSnapshot;
    if (!simulationRunning || runtime == null || !runtime.solved) {
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
          ..color = phase.withValues(alpha: 48 / 255)
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
    if (nodeId == null) return 0;

    double current = 0;
    final dc = runtime.dcResult;
    if (dc != null && dc.isSolved) {
      for (final branch in dc.branchResults) {
        if (branch.fromNodeId != nodeId && branch.toNodeId != nodeId) continue;
        final double? branchCurrent = branch.currentA;
        if (branchCurrent == null || !branchCurrent.isFinite) continue;
        current = math.max(current, branchCurrent.abs());
      }
      return current;
    }
    final ac1 = runtime.ac1Result;
    if (ac1 != null && ac1.isSolved) {
      for (final branch in ac1.branchResults) {
        if (branch.fromNodeId != nodeId && branch.toNodeId != nodeId) continue;
        final double? branchCurrent = branch.current?.magnitude;
        if (branchCurrent == null || !branchCurrent.isFinite) continue;
        current = math.max(current, branchCurrent);
      }
      return current;
    }
    final ac3 = runtime.ac3Result;
    if (ac3 != null && ac3.isSolved) {
      for (final branch in ac3.branchResults) {
        if (branch.fromNodeId != nodeId && branch.toNodeId != nodeId) continue;
        final double? branchCurrent = branch.current?.magnitude;
        if (branchCurrent == null || !branchCurrent.isFinite) continue;
        current = math.max(current, branchCurrent);
      }
      return current;
    }

    final pv = runtime.pvResult;
    if (pv != null && pv.isSolved) {
      return switch (connection.phase) {
        PhaseTag.dcPositive || PhaseTag.dcNegative => pv.pvDrawnCurrentA.abs(),
        PhaseTag.l1 || PhaseTag.neutral =>
          pv.inverterOutputCurrentRmsA.abs(),
        _ => math.max(
            pv.pvDrawnCurrentA.abs(),
            pv.inverterOutputCurrentRmsA.abs(),
          ),
      };
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
      final bool referenceTerminal = _isReferenceTerminal(entry.key);

      if (referenceTerminal) {
        if (pending || hovered) {
          canvas.drawCircle(
            p,
            radius + 4,
            Paint()
              ..color = ElectroSimColors.primary.withValues(alpha: 45 / 255),
          );
          canvas.drawCircle(
            p,
            radius + 1.5,
            Paint()
              ..color = ElectroSimColors.primary
              ..strokeWidth = 2
              ..style = PaintingStyle.stroke,
          );
        }
        continue;
      }

      if (pending || hovered) {
        canvas.drawCircle(
          p,
          radius + 3,
          Paint()..color = ElectroSimColors.primary.withValues(alpha: 52 / 255),
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

  bool _isReferenceTerminal(TerminalId terminalId) {
    for (final SourceInstance source in circuit.sources) {
      if (!F18ReferenceComponentVisuals.supports(source.modelType)) continue;
      if (source.terminals.any((Terminal terminal) => terminal.id == terminalId)) {
        return true;
      }
    }
    for (final ComponentInstance component in circuit.components) {
      if (!F18ReferenceComponentVisuals.supports(component.modelType)) continue;
      if (component.terminals
          .any((Terminal terminal) => terminal.id == terminalId)) {
        return true;
      }
    }
    return false;
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
    int quarterTurns, {
    String? displayLabel,
  }) {
    final Offset center = viewport.worldToScreen(worldRect.center);
    final Size visualSize = _f9VisualSize(worldRect, viewport);
    final Color color =
        active ? ElectroSimColors.primary : ElectroSimColors.textSecondary;

    if (!F18ReferenceComponentVisuals.supports(modelType)) {
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
          text: displayLabel ?? _boardLabel(modelType),
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
      'capacitor' => 'Condensateur',
      'inductor' => 'Inductance',
      'impedance' => 'Impédance',
      'contactor_aux_no' => 'Aux. NO',
      'contactor_aux_nc' => 'Aux. NC',
      'relay_contact_no' => 'Relais NO',
      'relay_contact_nc' => 'Relais NC',
      'contactor_ac1' => 'Contacteur 1φ',
      'contactor_3p' => 'Contacteur 3P',
      'breaker_3p' => 'Disjoncteur 3P',
      'thermal_overload_3p' => 'Relais thermique',
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
