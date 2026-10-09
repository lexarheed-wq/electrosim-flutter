import 'dart:math' as math;

import 'package:electrosim_canvas/electrosim_canvas.dart';
import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:electrosim_measurements/electrosim_measurements.dart';
import 'package:electrosim_ui_kit/electrosim_ui_kit.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'f18_component_archetypes.dart';
import 'f18_component_asset_visual.dart';
import 'f18_industrial_dual_view.dart';
import 'f9_wiring_policy.dart';
import 'f9_source_voltage_readout.dart';
import 'runtime/electrosim_runtime_engine.dart';

class F9CanvasVisualOverlay extends StatefulWidget {
  const F9CanvasVisualOverlay({
    super.key,
    required this.circuit,
    required this.layout,
    required this.viewport,
    this.selectedElementIds = const <String>{},
    this.pendingTerminalId,
    this.hoverTerminalId,
    this.pointerWorldPosition,
    this.pointerWorldPositionListenable,
    this.wirePreviewPlanner,
    this.runtimeSnapshot,
    this.simulationRunning = false,
  });

  final CircuitState circuit;
  final CircuitVisualLayout layout;
  final ViewportController viewport;
  final Set<String> selectedElementIds;
  final TerminalId? pendingTerminalId;
  final TerminalId? hoverTerminalId;
  final Offset? pointerWorldPosition;
  final ValueListenable<Offset?>? pointerWorldPositionListenable;
  final WirePreviewPlanner? wirePreviewPlanner;
  final ElectroSimRuntimeSnapshot? runtimeSnapshot;
  final bool simulationRunning;

  @override
  State<F9CanvasVisualOverlay> createState() => _F9CanvasVisualOverlayState();
}

class _F9CanvasVisualOverlayState extends State<F9CanvasVisualOverlay>
    with SingleTickerProviderStateMixin {
  final ValueNotifier<double> _motionSeconds = ValueNotifier<double>(0);
  final ValueNotifier<Offset?> _fallbackPointerWorld = ValueNotifier<Offset?>(
    null,
  );
  late final Ticker _ticker;
  double _motionBaseSeconds = 0;

  CircuitState? _cachedCircuit;
  CircuitVisualLayout? _cachedLayout;
  CircuitGeometryIndex? _cachedGeometry;
  WireSemantics? _cachedSemantics;
  TerminalId? _cachedPendingTerminalId;
  WirePreviewPlanner? _cachedWirePreviewPlanner;
  WirePreviewSession? _cachedWirePreviewSession;
  Map<TerminalId, F9WiringDecision> _cachedWiringDecisions =
      const <TerminalId, F9WiringDecision>{};

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((Duration elapsed) {
      _motionSeconds.value =
          _motionBaseSeconds +
          elapsed.inMicroseconds / Duration.microsecondsPerSecond;
    });
    _fallbackPointerWorld.value = widget.pointerWorldPosition;
    _syncMotion();
  }

  @override
  void didUpdateWidget(F9CanvasVisualOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.circuit != widget.circuit ||
        !identical(oldWidget.layout, widget.layout)) {
      _cachedCircuit = null;
      _cachedLayout = null;
      _cachedGeometry = null;
      _cachedSemantics = null;
      _cachedPendingTerminalId = null;
      _cachedWirePreviewPlanner = null;
      _cachedWirePreviewSession = null;
      _cachedWiringDecisions = const <TerminalId, F9WiringDecision>{};
    } else if (oldWidget.pendingTerminalId != widget.pendingTerminalId ||
        oldWidget.wirePreviewPlanner != widget.wirePreviewPlanner) {
      _cachedPendingTerminalId = null;
      _cachedWirePreviewPlanner = null;
      _cachedWirePreviewSession = null;
      _cachedWiringDecisions = const <TerminalId, F9WiringDecision>{};
    }
    if (widget.pointerWorldPositionListenable == null &&
        oldWidget.pointerWorldPosition != widget.pointerWorldPosition) {
      _fallbackPointerWorld.value = widget.pointerWorldPosition;
    }
    _syncMotion();
  }

  void _ensureOverlayCaches() {
    final bool staticCacheInvalid =
        _cachedGeometry == null ||
        _cachedSemantics == null ||
        _cachedCircuit != widget.circuit ||
        !identical(_cachedLayout, widget.layout);

    if (staticCacheInvalid) {
      _cachedCircuit = widget.circuit;
      _cachedLayout = widget.layout;
      _cachedGeometry = CircuitGeometryIndex.build(
        widget.circuit,
        widget.layout,
      );
      _cachedSemantics = const WireSemanticsAnalyzer().analyze(
        circuit: widget.circuit,
        layout: widget.layout,
      );
      _cachedPendingTerminalId = null;
      _cachedWirePreviewPlanner = null;
      _cachedWirePreviewSession = null;
      _cachedWiringDecisions = const <TerminalId, F9WiringDecision>{};
    }

    final TerminalId? pending = widget.pendingTerminalId;
    final WirePreviewPlanner? planner = widget.wirePreviewPlanner;
    final bool interactionCacheInvalid =
        _cachedPendingTerminalId != pending ||
        _cachedWirePreviewPlanner != planner;

    if (!interactionCacheInvalid) return;

    _cachedPendingTerminalId = pending;
    _cachedWirePreviewPlanner = planner;
    _cachedWirePreviewSession = pending == null || planner == null
        ? null
        : planner.prepare(
            circuit: widget.circuit,
            layout: widget.layout,
            startTerminalId: pending,
          );

    if (pending == null) {
      _cachedWiringDecisions = const <TerminalId, F9WiringDecision>{};
      return;
    }

    final Map<TerminalId, F9WiringDecision> decisions =
        <TerminalId, F9WiringDecision>{};
    for (final TerminalId terminalId
        in _cachedGeometry!.terminalPositions.keys) {
      if (terminalId == pending) continue;
      decisions[terminalId] = F9WiringPolicy.evaluateAndBuild(
        widget.circuit,
        pending,
        terminalId,
      );
    }
    _cachedWiringDecisions = Map<TerminalId, F9WiringDecision>.unmodifiable(
      decisions,
    );
  }

  void _syncMotion() {
    final bool shouldRun =
        widget.simulationRunning &&
        (widget.runtimeSnapshot?.solved ?? false) &&
        widget.pendingTerminalId == null;
    if (shouldRun && !_ticker.isActive) {
      _motionBaseSeconds = _motionSeconds.value;
      _ticker.start();
    } else if (!shouldRun && _ticker.isActive) {
      _motionBaseSeconds = _motionSeconds.value;
      _ticker.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    _ensureOverlayCaches();
    final CircuitGeometryIndex geometry = _cachedGeometry!;
    final WireSemantics semantics = _cachedSemantics!;
    final WirePreviewSession? wirePreviewSession = _cachedWirePreviewSession;
    final Map<TerminalId, F9WiringDecision> wiringDecisions =
        _cachedWiringDecisions;

    return IgnorePointer(
      child: AnimatedBuilder(
        animation: widget.viewport,
        builder: (BuildContext context, Widget? child) {
          return Stack(
            fit: StackFit.expand,
            children: <Widget>[
              RepaintBoundary(
                child: CustomPaint(
                  painter: _F9CurrentFlowPainter(
                    circuit: widget.circuit,
                    layout: widget.layout,
                    viewport: widget.viewport,
                    geometry: geometry,
                    semantics: semantics,
                    runtimeSnapshot: widget.runtimeSnapshot,
                    simulationRunning: widget.simulationRunning,
                    motionSeconds: _motionSeconds,
                  ),
                  size: Size.infinite,
                ),
              ),
              ..._buildReferenceVisuals(geometry),
              RepaintBoundary(
                child: CustomPaint(
                  painter: _F9StaticOverlayPainter(
                    circuit: widget.circuit,
                    layout: widget.layout,
                    viewport: widget.viewport,
                    geometry: geometry,
                    selectedElementIds: widget.selectedElementIds,
                    pendingTerminalId: widget.pendingTerminalId,
                    hoverTerminalId: widget.hoverTerminalId,
                    pointerWorldPosition: null,
                    wirePreviewPlanner: widget.wirePreviewPlanner,
                    wirePreviewSession: wirePreviewSession,
                    wiringDecisions: wiringDecisions,
                    paintStaticChrome: true,
                    paintInteraction: false,
                  ),
                  size: Size.infinite,
                ),
              ),
              ValueListenableBuilder<Offset?>(
                valueListenable:
                    widget.pointerWorldPositionListenable ??
                    _fallbackPointerWorld,
                builder:
                    (BuildContext context, Offset? pointer, Widget? child) =>
                        RepaintBoundary(
                          child: CustomPaint(
                            painter: _F9StaticOverlayPainter(
                              circuit: widget.circuit,
                              layout: widget.layout,
                              viewport: widget.viewport,
                              geometry: geometry,
                              selectedElementIds: widget.selectedElementIds,
                              pendingTerminalId: widget.pendingTerminalId,
                              hoverTerminalId: widget.hoverTerminalId,
                              pointerWorldPosition: pointer,
                              wirePreviewPlanner: widget.wirePreviewPlanner,
                              wirePreviewSession: wirePreviewSession,
                              wiringDecisions: wiringDecisions,
                              paintStaticChrome: false,
                              paintInteraction: true,
                            ),
                            size: Size.infinite,
                          ),
                        ),
              ),
            ],
          );
        },
      ),
    );
  }

  @visibleForTesting
  static bool requiresContinuousAnimation(String modelType) =>
      switch (modelType.toLowerCase()) {
        'fan_dc' ||
        'motor_dc' ||
        'pv_array' ||
        'pv_controller' ||
        'pv_battery' ||
        'pv_inverter' ||
        'motor_3p_6t' ||
        'catalog_motor_driven_2t' ||
        'catalog_motor_driven_6t' => true,
        _ => false,
      };

  List<Widget> _buildReferenceVisuals(CircuitGeometryIndex geometry) {
    final List<Widget> widgets = <Widget>[];

    void addVisual({
      required String elementId,
      required String modelType,
      String? visualModelType,
      String? visualVariant,
      required bool enabled,
      required bool energized,
      required bool closed,
      required bool tripped,
      required bool pressed,
      required bool actuated,
      required double currentA,
      required double voltageV,
      required double batterySoc,
      required double ratedCurrentA,
      required double ratedVoltageV,
      required double ratedPowerW,
      required double currentLimitA,
      required double resistanceOhm,
      double residualTripCurrentA = 0,
      ComponentHealthState healthState = const ComponentHealthState.normal(),
    }) {
      final String renderedModelType = visualModelType ?? modelType;
      if (!F18ReferenceComponentVisuals.supports(renderedModelType)) return;
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
              child: _F9HealthVisual(
                healthState: healthState,
                motionSeconds: _motionSeconds,
                child: _F9ReferenceAsset(
                  key: ValueKey<String>('board-v1-visual-$elementId'),
                  modelType: renderedModelType,
                  variantKey: visualVariant,
                  size: baseVisualSize,
                  active: enabled,
                  energized: energized,
                  closed: closed,
                  tripped: tripped,
                  pressed: pressed,
                  actuated: actuated,
                  motionSeconds: _motionSeconds,
                  animate:
                      energized &&
                      requiresContinuousAnimation(renderedModelType),
                  showTerminals: true,
                  currentA: currentA,
                  voltageV: voltageV,
                  batterySoc: batterySoc,
                  ratedCurrentA: ratedCurrentA,
                  ratedVoltageV: ratedVoltageV,
                  ratedPowerW: ratedPowerW,
                  currentLimitA: currentLimitA,
                  resistanceOhm: resistanceOhm,
                  residualTripCurrentA: residualTripCurrentA,
                ),
              ),
            ),
          ),
        ),
      );
    }

    final ElectroSimRuntimeSnapshot? runtime = widget.runtimeSnapshot;
    for (final SourceInstance source in widget.circuit.sources) {
      final double currentA = _sourceCurrentA(
        runtime,
        source.id,
        source.modelType,
      );
      final double voltageV = F9SourceVoltageReadout.voltageV(
        runtime,
        source,
        simulationRunning: widget.simulationRunning,
      );
      addVisual(
        elementId: source.id.value,
        modelType: source.modelType,
        visualModelType: source.parameters['_visualModelType'] as String?,
        visualVariant: source.parameters['_visualVariant'] as String?,
        enabled: source.enabled,
        energized:
            widget.simulationRunning &&
            (runtime?.solved ?? false) &&
            source.enabled,
        closed: true,
        tripped: false,
        pressed: false,
        actuated: false,
        currentA: currentA,
        voltageV: voltageV,
        batterySoc: 0,
        ratedCurrentA: 1,
        ratedVoltageV: 0,
        ratedPowerW: 0,
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
      final double batterySoc = component.modelType != 'pv_battery'
          ? 0.0
          : (runtime?.pvResult?.isSolved ?? false)
          ? runtime!.pvResult!.batterySoc
          : runtime?.dcBatterySocs[component.id] ??
                (component.parameters['initialSoc'] as num?)?.toDouble() ??
                0.0;
      final componentState = runtime?.componentOperatingState(component.id);
      final bool stateAllowsEnergy =
          componentState?.code == ComponentOperatingCode.energized ||
          componentState?.code == ComponentOperatingCode.overloaded;
      final bool energized =
          widget.simulationRunning &&
          (runtime?.solved ?? false) &&
          stateAllowsEnergy &&
          currentA.abs() > 1e-6;
      final String type = component.modelType.toLowerCase();
      final bool pressed = component.controlState['pressed'] == true;
      final bool closed = switch (type) {
        'push_button_no' => pressed,
        'push_button_nc' => !pressed,
        _ => (component.controlState['closed'] as bool?) ?? true,
      };
      final bool tripped =
          (runtime?.protectionTripped(component.id) ?? false) ||
          component.controlState['tripped'] == true;
      final bool contactorAux =
          type == 'contactor_aux_no' || type == 'contactor_aux_nc';
      final bool relayAux =
          type == 'relay_contact_no' || type == 'relay_contact_nc';
      final Object? linkedId = component
          .parameters[relayAux ? 'linkedRelayId' : 'linkedContactorId'];
      final bool actuated = (contactorAux || relayAux) && linkedId is String
          ? (runtime?.contactorActuated(ComponentId(linkedId)) ??
                (component.controlState['actuated'] == true))
          : (runtime?.contactorActuated(component.id) ??
                (component.controlState['actuated'] == true));

      addVisual(
        elementId: component.id.value,
        modelType: component.modelType,
        visualModelType: component.parameters['_visualModelType'] as String?,
        visualVariant: component.parameters['_visualVariant'] as String?,
        enabled: component.condition != ComponentCondition.disabled,
        energized: energized,
        closed: closed,
        tripped: tripped,
        pressed: pressed,
        actuated: actuated,
        currentA: currentA,
        voltageV: voltageV,
        batterySoc: batterySoc,
        ratedCurrentA:
            (component.parameters[ProtectionRating.ratedCurrentKey] as num?)
                ?.toDouble() ??
            0,
        ratedVoltageV:
            (component.parameters[ReceiverNominalRating.voltageKey] as num?)
                ?.toDouble() ??
            0,
        ratedPowerW:
            (component.parameters[ReceiverNominalRating.powerKey] as num?)
                ?.toDouble() ??
            0,
        currentLimitA: 2,
        resistanceOhm:
            (component.parameters['resistanceOhm'] as num?)?.toDouble() ?? 0,
        residualTripCurrentA:
            (component.parameters[ComponentParameterKeys.residualTripCurrentA]
                    as num?)
                ?.toDouble() ??
            0,
        healthState:
            runtime?.componentHealthState(component.id) ??
            const ComponentHealthState.normal(),
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
        if (current != null &&
            current.isFinite &&
            current.abs() > value.abs()) {
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
        if (current != null && current.isFinite) {
          value = math.max(value, current);
        }
      }
      return value;
    }

    final ac3 = runtime.ac3Result;
    if (ac3 != null && ac3.isSolved) {
      double value = 0;
      for (final branch in ac3.branchResults) {
        if (branch.id != prefix && !branch.id.startsWith('$prefix:')) continue;
        final double? current = branch.current?.magnitude;
        if (current != null && current.isFinite) {
          value = math.max(value, current);
        }
      }
      return value;
    }

    final pv = runtime.pvResult;
    if (pv != null && pv.isSolved) {
      if (modelType == 'pv_controller') {
        return pv.pvDrawnCurrentA;
      }
      if (modelType == 'pv_battery') {
        final double voltage = pv.batteryVoltageV.abs();
        return voltage > 1e-9 ? pv.batteryPowerW / voltage : 0;
      }
      if (modelType == 'pv_inverter') {
        return pv.inverterOutputCurrentRmsA;
      }
      for (final load in pv.loadResults) {
        if (load.componentId == id) return load.currentRmsA;
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
      double value = 0;
      for (final branch in ac1.branchResults) {
        if (branch.id != target && !branch.id.startsWith('$target:')) continue;
        final double? current = branch.current?.magnitude;
        if (current != null && current.isFinite) {
          value = math.max(value, current);
        }
      }
      if (value > 0) return value;
    }
    final ac3 = runtime.ac3Result;
    if (ac3 != null && ac3.isSolved) {
      double value = 0;
      for (final branch in ac3.branchResults) {
        if (branch.id != target && !branch.id.startsWith('$target:')) continue;
        final double? current = branch.current?.magnitude;
        if (current != null && current.isFinite) {
          value = math.max(value, current);
        }
      }
      if (value > 0) return value;
    }
    final pv = runtime.pvResult;
    if (pv != null && pv.isSolved && modelType == 'pv_array') {
      return pv.pvDrawnCurrentA;
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
        if (branch.voltageV.isFinite) {
          value = math.max(value, branch.voltageV.abs());
        }
      }
      return value;
    }
    final ac1 = runtime.ac1Result;
    if (ac1 != null && ac1.isSolved) {
      for (final branch in ac1.branchResults) {
        if (branch.id != prefix && !branch.id.startsWith('$prefix:')) continue;
        if (branch.voltage.magnitude.isFinite) {
          value = math.max(value, branch.voltage.magnitude);
        }
      }
      return value;
    }
    final ac3 = runtime.ac3Result;
    if (ac3 != null && ac3.isSolved) {
      for (final branch in ac3.branchResults) {
        if (branch.id != prefix && !branch.id.startsWith('$prefix:')) continue;
        if (branch.voltage.magnitude.isFinite) {
          value = math.max(value, branch.voltage.magnitude);
        }
      }
      return value;
    }
    final pv = runtime.pvResult;
    if (pv != null && pv.isSolved) {
      if (modelType == 'pv_controller' || modelType == 'pv_battery') {
        return pv.batteryVoltageV;
      }
      if (modelType == 'pv_inverter') {
        return pv.inverterOutputVoltageRmsV;
      }
      for (final load in pv.loadResults) {
        if (load.componentId == id) return load.voltageRmsV;
      }
    }
    return value;
  }

  @override
  void dispose() {
    _ticker.dispose();
    _motionSeconds.dispose();
    _fallbackPointerWorld.dispose();
    super.dispose();
  }
}

class _F9ReferenceAsset extends StatelessWidget {
  const _F9ReferenceAsset({
    super.key,
    required this.modelType,
    required this.size,
    required this.motionSeconds,
    required this.animate,
    this.variantKey,
    this.active = true,
    this.energized = false,
    this.closed,
    this.tripped = false,
    this.pressed = false,
    this.actuated = false,
    this.batterySoc = 0,
    this.showTerminals = true,
    this.currentA = 0,
    this.voltageV = 0,
    this.ratedCurrentA = 1,
    this.ratedVoltageV = 24,
    this.ratedPowerW = 10,
    this.currentLimitA = 2,
    this.resistanceOhm = 0,
    this.residualTripCurrentA = 0,
  });

  final String modelType;
  final Size size;
  final ValueListenable<double> motionSeconds;
  final bool animate;
  final String? variantKey;
  final bool active;
  final bool energized;
  final bool? closed;
  final bool tripped;
  final bool pressed;
  final bool actuated;
  final double batterySoc;
  final bool showTerminals;
  final double currentA;
  final double voltageV;
  final double ratedCurrentA;
  final double ratedVoltageV;
  final double ratedPowerW;
  final double currentLimitA;
  final double resistanceOhm;
  final double residualTripCurrentA;

  // Board camera is locked to zero yaw/pitch. The same canonical device
  // painter continues to own all terminal and state geometry.
  Widget _visual(double phase) => F18IndustrialDualView(
    modelType: modelType,
    size: size,
    presentation: F18IndustrialPresentation.boardFront,
    child: F18ComponentAssetVisual(
      modelType: modelType,
      variantKey: variantKey,
      size: size,
      active: active,
      energized: energized,
      closed: closed,
      tripped: tripped,
      pressed: pressed,
      actuated: actuated,
      animationValue: phase,
      batterySoc: batterySoc,
      showTerminals: showTerminals,
      currentA: currentA,
      voltageV: voltageV,
      ratedCurrentA: ratedCurrentA,
      ratedVoltageV: ratedVoltageV,
      ratedPowerW: ratedPowerW,
      currentLimitA: currentLimitA,
      resistanceOhm: resistanceOhm,
      residualTripCurrentA: residualTripCurrentA,
    ),
  );

  @override
  Widget build(BuildContext context) {
    if (!animate) return _visual(0);
    return AnimatedBuilder(
      animation: motionSeconds,
      builder: (BuildContext context, Widget? child) =>
          _visual(motionSeconds.value % 1.0),
    );
  }
}

class _F9HealthVisual extends StatelessWidget {
  const _F9HealthVisual({
    required this.healthState,
    required this.motionSeconds,
    required this.child,
  });

  final ComponentHealthState healthState;
  final ValueListenable<double> motionSeconds;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (healthState.code == ComponentHealthCode.normal) return child;
    return AnimatedBuilder(
      animation: motionSeconds,
      child: child,
      builder: (BuildContext context, Widget? stableChild) {
        final double phase = motionSeconds.value * math.pi * 2;
        final double pulse = (math.sin(phase) + 1) / 2;
        final double opacity = switch (healthState.code) {
          ComponentHealthCode.normal => 1.0,
          ComponentHealthCode.stressed => 0.94 + pulse * 0.06,
          ComponentHealthCode.degraded => 0.72 + pulse * 0.16,
          ComponentHealthCode.failedOpen => 0.42,
        };
        return Stack(
          fit: StackFit.expand,
          children: <Widget>[
            Opacity(opacity: opacity, child: stableChild),
            IgnorePointer(
              child: CustomPaint(
                painter: _F9HealthOverlayPainter(
                  state: healthState.code,
                  pulse: pulse,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _F9HealthOverlayPainter extends CustomPainter {
  const _F9HealthOverlayPainter({required this.state, required this.pulse});

  final ComponentHealthCode state;
  final double pulse;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect bounds = Offset.zero & size;
    final Color warning = switch (state) {
      ComponentHealthCode.normal => Colors.transparent,
      ComponentHealthCode.stressed => const Color(0xFFFFA000),
      ComponentHealthCode.degraded => const Color(0xFFEF6C00),
      ComponentHealthCode.failedOpen => const Color(0xFF5D4037),
    };
    if (warning == Colors.transparent) return;

    canvas.drawRRect(
      RRect.fromRectAndRadius(bounds.deflate(1.5), const Radius.circular(8)),
      Paint()
        ..color = warning.withValues(
          alpha: state == ComponentHealthCode.failedOpen
              ? 0.55
              : 0.22 + pulse * 0.18,
        )
        ..style = PaintingStyle.stroke
        ..strokeWidth = state == ComponentHealthCode.failedOpen ? 2.4 : 1.8,
    );

    if (state == ComponentHealthCode.degraded ||
        state == ComponentHealthCode.failedOpen) {
      final Offset center = Offset(size.width * 0.70, size.height * 0.34);
      final double radius = math.min(size.width, size.height) * 0.075;
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = const Color(0xFF3E2723).withValues(
            alpha: state == ComponentHealthCode.failedOpen ? 0.62 : 0.28,
          ),
      );
      final Paint crack = Paint()
        ..color = const Color(0xFF3E2723).withValues(
          alpha: state == ComponentHealthCode.failedOpen ? 0.85 : 0.50,
        )
        ..strokeWidth = 1.2
        ..style = PaintingStyle.stroke;
      final Path path = Path()
        ..moveTo(center.dx - radius * 0.7, center.dy - radius * 0.8)
        ..lineTo(center.dx - radius * 0.1, center.dy - radius * 0.1)
        ..lineTo(center.dx - radius * 0.45, center.dy + radius * 0.45)
        ..moveTo(center.dx - radius * 0.1, center.dy - radius * 0.1)
        ..lineTo(center.dx + radius * 0.65, center.dy + radius * 0.55);
      canvas.drawPath(path, crack);
    }
  }

  @override
  bool shouldRepaint(_F9HealthOverlayPainter oldDelegate) =>
      oldDelegate.state != state || oldDelegate.pulse != pulse;
}

@visibleForTesting
bool f9ShouldPaintCurrentFlow(
  ConnectionCurrentEvidence flow, {
  double minimumCurrentA = 1e-6,
}) => flow.magnitudeA > minimumCurrentA;

@visibleForTesting
double f9CurrentFlowDashPhase({
  required double elapsedSeconds,
  required double speed,
  double cycle = 14,
}) {
  assert(cycle > 0);
  return (elapsedSeconds * speed) % cycle;
}

class _F9CurrentFlowPainter extends CustomPainter {
  _F9CurrentFlowPainter({
    required this.circuit,
    required this.layout,
    required this.viewport,
    required this.geometry,
    required this.semantics,
    required this.runtimeSnapshot,
    required this.simulationRunning,
    required this.motionSeconds,
  }) : super(repaint: motionSeconds);

  final CircuitState circuit;
  final CircuitVisualLayout layout;
  final ViewportController viewport;
  final CircuitGeometryIndex geometry;
  final WireSemantics semantics;
  final ElectroSimRuntimeSnapshot? runtimeSnapshot;
  final bool simulationRunning;
  final ValueListenable<double> motionSeconds;

  @override
  void paint(Canvas canvas, Size size) {
    final ElectroSimRuntimeSnapshot? runtime = runtimeSnapshot;
    if (!simulationRunning || runtime == null || !runtime.solved) return;

    for (final Connection connection in circuit.connections) {
      if (!runtime.topology.enabledConnectionIds.contains(connection.id)) {
        continue;
      }
      final ConnectionCurrentEvidence flow = runtime.connectionCurrentEvidence(
        connection,
      );
      final double currentA = flow.magnitudeA;
      if (!f9ShouldPaintCurrentFlow(flow)) continue;

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

      final Path path = buildPhysicalWirePath(
        points.map(viewport.worldToScreen).toList(),
        bendRadius: 6 * viewport.scale,
      );

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

      final double baseSpeed =
          22 + math.min(78, math.sqrt(math.max(0, currentA)) * 28);
      final double direction = flow.directionKnown && !flow.alternating
          ? (flow.signedCurrentA >= 0 ? 1.0 : -1.0)
          : 0.0;
      _paintMovingDashes(
        canvas,
        path,
        speed: baseSpeed * direction,
        elapsedSeconds: motionSeconds.value,
      );
    }

    final double gapRadius = (5 * viewport.scale).clamp(3, 7).toDouble();
    for (final NonJunctionWireCrossing crossing
        in semantics.nonJunctionCrossings) {
      canvas.drawCircle(
        viewport.worldToScreen(crossing.point),
        gapRadius,
        Paint()..color = CircuitScenePainter.boardColor,
      );
    }
  }

  void _paintMovingDashes(
    Canvas canvas,
    Path path, {
    required double speed,
    required double elapsedSeconds,
  }) {
    const double dash = 2;
    const double gap = 12;
    const double cycle = dash + gap;
    final double offset = f9CurrentFlowDashPhase(
      elapsedSeconds: elapsedSeconds,
      speed: speed,
      cycle: cycle,
    );
    final Paint paint = Paint()
      ..color = const Color(0xEBFFFFFF)
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    for (final metric in path.computeMetrics()) {
      double cursor = offset;
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
  bool shouldRepaint(_F9CurrentFlowPainter oldDelegate) => true;
}

class _F9StaticOverlayPainter extends CustomPainter {
  const _F9StaticOverlayPainter({
    required this.circuit,
    required this.layout,
    required this.viewport,
    required this.geometry,
    required this.selectedElementIds,
    required this.pendingTerminalId,
    required this.hoverTerminalId,
    required this.pointerWorldPosition,
    required this.wirePreviewPlanner,
    required this.wirePreviewSession,
    required this.wiringDecisions,
    this.paintStaticChrome = true,
    this.paintInteraction = true,
  });

  final CircuitState circuit;
  final CircuitVisualLayout layout;
  final ViewportController viewport;
  final CircuitGeometryIndex geometry;
  final Set<String> selectedElementIds;
  final TerminalId? pendingTerminalId;
  final TerminalId? hoverTerminalId;
  final Offset? pointerWorldPosition;
  final WirePreviewPlanner? wirePreviewPlanner;
  final WirePreviewSession? wirePreviewSession;
  final Map<TerminalId, F9WiringDecision> wiringDecisions;
  final bool paintStaticChrome;
  final bool paintInteraction;

  @override
  void paint(Canvas canvas, Size size) {
    if (paintInteraction) {
      _paintSmartWirePreview(canvas);
      _paintTerminals(canvas, geometry);
      _paintWiringTargets(canvas, geometry);
    }
    if (!paintStaticChrome) return;

    for (final SourceInstance source in circuit.sources) {
      final Rect? rect = geometry.elementRects[source.id.value];
      if (rect == null) continue;
      _paintElementGlyph(
        canvas,
        rect,
        (source.parameters['_visualModelType'] as String?) ?? source.modelType,
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
        (component.parameters['_visualModelType'] as String?) ??
            component.modelType,
        active,
        layout.quarterTurnsOf(component.id.value),
        displayLabel: component.parameters['_displayLabel'] as String?,
      );
    }

    _paintSelection(canvas, geometry);
  }

  void _paintSelection(Canvas canvas, CircuitGeometryIndex geometry) {
    if (selectedElementIds.isEmpty) return;

    final Paint outline = Paint()
      ..color = ElectroSimColors.primary
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    for (final String id in selectedElementIds) {
      final Rect? worldRect = geometry.elementRects[id];
      if (worldRect != null) {
        final Offset center = viewport.worldToScreen(worldRect.center);
        final Rect screenRect = Rect.fromCenter(
          center: center,
          width: worldRect.width * viewport.scale + 12,
          height: worldRect.height * viewport.scale + 12,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(screenRect, const Radius.circular(12)),
          outline,
        );
        continue;
      }

      Connection? selectedConnection;
      for (final Connection connection in circuit.connections) {
        if (connection.id.value == id) {
          selectedConnection = connection;
          break;
        }
      }
      if (selectedConnection == null) continue;
      final Offset? start =
          geometry.terminalPositions[selectedConnection.fromTerminalId];
      final Offset? end =
          geometry.terminalPositions[selectedConnection.toTerminalId];
      if (start == null || end == null) continue;
      final List<Offset> points = <Offset>[
        start,
        ...layout.routeFor(selectedConnection.id.value),
        end,
      ];
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
          ..strokeWidth = 6
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }
  }

  void _paintSmartWirePreview(Canvas canvas) {
    final TerminalId? pending = pendingTerminalId;
    final Offset? pointer = pointerWorldPosition;
    final WirePreviewPlanner? planner = wirePreviewPlanner;
    if (pending == null || pointer == null || planner == null) return;

    final WirePreviewSession? session = wirePreviewSession;
    final WirePreviewPlan plan = session == null
        ? planner.plan(
            circuit: circuit,
            layout: layout,
            startTerminalId: pending,
            pointerWorldPosition: pointer,
          )
        : planner.planPrepared(session: session, pointerWorldPosition: pointer);
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
      final String rendered =
          (source.parameters['_visualModelType'] as String?) ??
          source.modelType;
      if (!F18ReferenceComponentVisuals.supports(rendered)) continue;
      if (source.terminals.any(
        (Terminal terminal) => terminal.id == terminalId,
      )) {
        return true;
      }
    }
    for (final ComponentInstance component in circuit.components) {
      final String rendered =
          (component.parameters['_visualModelType'] as String?) ??
          component.modelType;
      if (!F18ReferenceComponentVisuals.supports(rendered)) continue;
      if (component.terminals.any(
        (Terminal terminal) => terminal.id == terminalId,
      )) {
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
          wiringDecisions[entry.key] ??
          F9WiringPolicy.evaluateAndBuild(circuit, pending, entry.key);
      final bool hovered = entry.key == hoverTerminalId;
      if (!decision.accepted && !hovered) continue;
      final Color color = decision.accepted
          ? ElectroSimColors.success
          : ElectroSimColors.danger;
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
              fontFamily: 'Roboto',
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
    final Size visualSize = F18ReferenceComponentVisuals.supports(modelType)
        ? Size(
            worldRect.width * viewport.scale,
            worldRect.height * viewport.scale,
          )
        : _f9VisualSize(worldRect, viewport);
    final Color color = active
        ? ElectroSimColors.primary
        : ElectroSimColors.textSecondary;

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
            fontFamily: 'Roboto',
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

  @override
  bool shouldRepaint(_F9StaticOverlayPainter oldDelegate) => true;
}

Size _f9VisualSize(Rect worldRect, ViewportController viewport) {
  final double scale = viewport.scale;
  return Size(
    (worldRect.width * scale * 0.96).clamp(72.0, 136.0).toDouble(),
    (worldRect.height * scale * 0.96).clamp(46.0, 92.0).toDouble(),
  );
}
