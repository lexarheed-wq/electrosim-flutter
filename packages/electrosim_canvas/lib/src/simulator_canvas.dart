import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'circuit_scene_painter.dart';
import 'circuit_visual_layout.dart';
import 'circuit_wire_layout_engine.dart';
import 'hit_test_engine.dart';
import 'viewport_controller.dart';
import 'wire_preview_planner.dart';

typedef ElementMovedCallback = void Function(String elementId, Offset worldPosition);
typedef ConnectionRequestedCallback = void Function(TerminalId from, TerminalId to);

final class SimulatorCanvas extends StatefulWidget {
  const SimulatorCanvas({
    super.key,
    required this.circuit,
    required this.layout,
    this.viewportController,
    this.selectedElementId,
    this.onSelectionChanged,
    this.onElementMoved,
    this.onConnectionRequested,
    this.onContextAction,
    this.hitTestEngine = const HitTestEngine(),
    this.enableInteraction = true,
    this.wireLayoutEngine,
    this.wirePreviewPlanner,
    this.elementVisualPainter,
    this.showElementLabels = true,
    this.preserveCommittedWireRoutes = false,
  });

  final CircuitState circuit;
  final CircuitVisualLayout layout;
  final ViewportController? viewportController;
  final String? selectedElementId;
  final ValueChanged<String?>? onSelectionChanged;
  final ElementMovedCallback? onElementMoved;
  final ConnectionRequestedCallback? onConnectionRequested;
  final ValueChanged<CanvasHitResult>? onContextAction;
  final HitTestEngine hitTestEngine;
  final bool enableInteraction;
  final CircuitWireLayoutEngine? wireLayoutEngine;
  final WirePreviewPlanner? wirePreviewPlanner;
  final CircuitElementVisualPainter? elementVisualPainter;
  final bool showElementLabels;
  final bool preserveCommittedWireRoutes;

  @override
  State<SimulatorCanvas> createState() => _SimulatorCanvasState();
}

final class _SimulatorCanvasState extends State<SimulatorCanvas> {
  late ViewportController _viewport;
  late bool _ownsViewport;
  late CircuitVisualLayout _effectiveLayout;
  String? _localSelectedElementId;
  TerminalId? _pendingTerminalId;
  String? _draggingElementId;
  Offset? _dragGrabDelta;
  Offset? _dragPreviewPosition;
  Offset? _pointerWorldPosition;
  Offset? _lastScaleFocal;
  double _scaleStartValue = 1;
  bool _scaleStartedOnBackground = false;
  DateTime? _lastContextTapTime;
  Offset? _lastContextTapPosition;
  CanvasHitResult? _lastContextTapHit;

  static const Duration _contextDoubleTapWindow = Duration(milliseconds: 400);
  static const double _contextDoubleTapDistance = 24;

  String? get _selectedElementId => widget.selectedElementId ?? _localSelectedElementId;

  Map<String, Offset> get _previewPositions => _draggingElementId != null && _dragPreviewPosition != null
      ? <String, Offset>{_draggingElementId!: _dragPreviewPosition!}
      : const <String, Offset>{};

  @override
  void initState() {
    super.initState();
    _refreshEffectiveLayout();
    _attachViewport(widget.viewportController);
  }

  @override
  void didUpdateWidget(SimulatorCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.circuit != widget.circuit ||
        !identical(oldWidget.layout, widget.layout) ||
        oldWidget.wireLayoutEngine != widget.wireLayoutEngine ||
        oldWidget.preserveCommittedWireRoutes !=
            widget.preserveCommittedWireRoutes) {
      _refreshEffectiveLayout();
    }
    if (oldWidget.viewportController != widget.viewportController) {
      _detachViewport();
      _attachViewport(widget.viewportController);
    }
    if (_pendingTerminalId != null && !_terminalExists(_pendingTerminalId!)) {
      _pendingTerminalId = null;
    }
  }

  void _refreshEffectiveLayout() {
    final CircuitWireLayoutEngine? engine = widget.wireLayoutEngine;
    _effectiveLayout = engine == null || widget.preserveCommittedWireRoutes
        ? widget.layout
        : engine.routeAll(circuit: widget.circuit, layout: widget.layout);
  }

  void _attachViewport(ViewportController? controller) {
    _ownsViewport = controller == null;
    _viewport = controller ?? ViewportController();
    _viewport.addListener(_onViewportChanged);
  }

  void _detachViewport() {
    _viewport.removeListener(_onViewportChanged);
    if (_ownsViewport) {
      _viewport.dispose();
    }
  }

  void _onViewportChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  bool _terminalExists(TerminalId id) {
    for (final ComponentInstance component in widget.circuit.components) {
      if (component.terminals.any((Terminal terminal) => terminal.id == id)) {
        return true;
      }
    }
    for (final SourceInstance source in widget.circuit.sources) {
      if (source.terminals.any((Terminal terminal) => terminal.id == id)) {
        return true;
      }
    }
    return false;
  }

  CanvasHitResult _hitAt(Offset screenPosition) => widget.hitTestEngine.hitTest(
    worldPoint: _viewport.screenToWorld(screenPosition),
    circuit: widget.circuit,
    layout: _effectiveLayout,
    previewPositions: _previewPositions,
    viewportScale: _viewport.scale,
  );

  void _select(String? elementId) {
    setState(() {
      _localSelectedElementId = elementId;
    });
    widget.onSelectionChanged?.call(elementId);
  }

  void _onTapUp(TapUpDetails details) {
    if (!widget.enableInteraction) {
      return;
    }
    final CanvasHitResult hit = _hitAt(details.localPosition);
    switch (hit.kind) {
      case CanvasHitKind.terminal:
        _resetContextTapTracking();
        final TerminalId terminalId = hit.terminalId!;
        final TerminalId? pending = _pendingTerminalId;
        if (pending == null) {
          setState(() {
            _pendingTerminalId = terminalId;
            _pointerWorldPosition = hit.worldPosition;
          });
        } else if (pending == terminalId) {
          setState(() {
            _pendingTerminalId = null;
            _pointerWorldPosition = null;
          });
        } else {
          widget.onConnectionRequested?.call(pending, terminalId);
          setState(() {
            _pendingTerminalId = null;
            _pointerWorldPosition = null;
          });
        }
        return;
      case CanvasHitKind.component:
      case CanvasHitKind.source:
        _select(hit.elementId);
        _maybeEmitContextDoubleTap(hit, details.localPosition);
        return;
      case CanvasHitKind.wire:
        _select(hit.connectionId?.value);
        _maybeEmitContextDoubleTap(hit, details.localPosition);
        return;
      case CanvasHitKind.background:
        _resetContextTapTracking();
        if (_pendingTerminalId != null || _pointerWorldPosition != null) {
          setState(() {
            _pendingTerminalId = null;
            _pointerWorldPosition = null;
          });
        }
        _select(null);
        return;
    }
  }

  void _maybeEmitContextDoubleTap(CanvasHitResult hit, Offset localPosition) {
    final DateTime now = DateTime.now();
    final CanvasHitResult? previousHit = _lastContextTapHit;
    final DateTime? previousTime = _lastContextTapTime;
    final Offset? previousPosition = _lastContextTapPosition;
    final bool sameTarget = previousHit != null &&
        previousHit.kind == hit.kind &&
        previousHit.elementId == hit.elementId &&
        previousHit.connectionId == hit.connectionId;
    final bool withinTime = previousTime != null &&
        now.difference(previousTime) <= _contextDoubleTapWindow;
    final bool withinDistance = previousPosition != null &&
        (localPosition - previousPosition).distance <= _contextDoubleTapDistance;

    if (sameTarget && withinTime && withinDistance) {
      widget.onContextAction?.call(hit);
      _resetContextTapTracking();
      return;
    }

    _lastContextTapTime = now;
    _lastContextTapPosition = localPosition;
    _lastContextTapHit = hit;
  }

  void _resetContextTapTracking() {
    _lastContextTapTime = null;
    _lastContextTapPosition = null;
    _lastContextTapHit = null;
  }

  void _onLongPressStart(LongPressStartDetails details) {
    if (!widget.enableInteraction) {
      return;
    }
    final CanvasHitResult hit = _hitAt(details.localPosition);
    if (hit.kind != CanvasHitKind.component && hit.kind != CanvasHitKind.source) {
      return;
    }
    final String id = hit.elementId!;
    final Offset? current = _effectiveLayout.positionOf(id);
    if (current == null) {
      return;
    }
    final Offset pointerWorld = _viewport.screenToWorld(details.localPosition);
    setState(() {
      _draggingElementId = id;
      _dragGrabDelta = current - pointerWorld;
      _dragPreviewPosition = current;
      _localSelectedElementId = id;
    });
    widget.onSelectionChanged?.call(id);
  }

  void _onLongPressMoveUpdate(LongPressMoveUpdateDetails details) {
    if (_draggingElementId == null || _dragGrabDelta == null) {
      return;
    }
    final Offset pointerWorld = _viewport.screenToWorld(details.localPosition);
    setState(() {
      _dragPreviewPosition = pointerWorld + _dragGrabDelta!;
      _pointerWorldPosition = pointerWorld;
    });
  }

  void _onLongPressEnd(LongPressEndDetails _) {
    final String? id = _draggingElementId;
    final Offset? position = _dragPreviewPosition;
    if (id != null && position != null) {
      widget.onElementMoved?.call(id, position);
    }
    setState(() {
      _draggingElementId = null;
      _dragGrabDelta = null;
      _dragPreviewPosition = null;
    });
  }

  void _onScaleStart(ScaleStartDetails details) {
    if (!widget.enableInteraction) {
      return;
    }
    _lastScaleFocal = details.localFocalPoint;
    _scaleStartValue = _viewport.scale;
    _scaleStartedOnBackground = _hitAt(details.localFocalPoint).kind == CanvasHitKind.background;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    if (!widget.enableInteraction || _draggingElementId != null) {
      return;
    }
    final Offset focal = details.localFocalPoint;
    if (details.pointerCount >= 2 || (details.scale - 1).abs() > 0.001) {
      final double targetScale = (_scaleStartValue * details.scale)
          .clamp(_viewport.minScale, _viewport.maxScale)
          .toDouble();
      final double factor = targetScale / _viewport.scale;
      _viewport.zoomAt(focal, factor);
      final Offset? previous = _lastScaleFocal;
      if (previous != null) {
        _viewport.panBy(focal - previous);
      }
    } else if (_scaleStartedOnBackground) {
      final Offset? previous = _lastScaleFocal;
      if (previous != null) {
        _viewport.panBy(focal - previous);
      }
    }
    _lastScaleFocal = focal;
  }

  void _onPointerSignal(PointerSignalEvent event) {
    if (!widget.enableInteraction || event is! PointerScrollEvent) {
      return;
    }
    final double factor = event.scrollDelta.dy > 0 ? 0.9 : 1.1;
    _viewport.zoomAt(event.localPosition, factor);
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (_pendingTerminalId == null && _draggingElementId == null) {
      return;
    }
    setState(() {
      _pointerWorldPosition = _viewport.screenToWorld(event.localPosition);
    });
  }


  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'ElectroSim simulator canvas',
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerSignal: _onPointerSignal,
        onPointerMove: _onPointerMove,
        child: MouseRegion(
          cursor: _draggingElementId == null ? SystemMouseCursors.basic : SystemMouseCursors.grabbing,
          onHover: (PointerHoverEvent event) {
            if (_pendingTerminalId != null) {
              setState(() {
                _pointerWorldPosition = _viewport.screenToWorld(event.localPosition);
              });
            }
          },
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: _onTapUp,
            onLongPressStart: _onLongPressStart,
            onLongPressMoveUpdate: _onLongPressMoveUpdate,
            onLongPressEnd: _onLongPressEnd,
            onScaleStart: _onScaleStart,
            onScaleUpdate: _onScaleUpdate,
            child: CustomPaint(
              painter: CircuitScenePainter(
                circuit: widget.circuit,
                layout: _effectiveLayout,
                viewport: _viewport,
                selectedElementId: _selectedElementId,
                pendingTerminalId: _pendingTerminalId,
                pointerWorldPosition: _pointerWorldPosition,
                previewPositions: _previewPositions,
                wirePreviewPlanner: widget.wirePreviewPlanner,
                smartWireSemantics: widget.wireLayoutEngine != null,
                elementVisualPainter: widget.elementVisualPainter,
                showElementLabels: widget.showElementLabels,
              ),
              size: Size.infinite,
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _detachViewport();
    super.dispose();
  }
}
