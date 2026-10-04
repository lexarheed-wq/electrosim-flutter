import 'dart:async';

import 'package:flutter/material.dart';

import 'design_tokens.dart';
import 'responsive.dart';

const Key electroSimCanvasRegionKey = Key('electrosim-canvas-region');
const Key electroSimPaletteRegionKey = Key('electrosim-palette-region');
const Key electroSimContextRegionKey = Key('electrosim-context-region');
const Key electroSimTopRegionKey = Key('electrosim-top-region');
const Key electroSimStatusRegionKey = Key('electrosim-status-region');

const Key electroSimPaletteEdgeKey = Key('electrosim-palette-edge');
const Key electroSimContextEdgeKey = Key('electrosim-context-edge');
const Key electroSimTopEdgeKey = Key('electrosim-top-edge');
const Key electroSimStatusEdgeKey = Key('electrosim-status-edge');

const Key electroSimPalettePinKey = Key('electrosim-palette-pin');
const Key electroSimContextPinKey = Key('electrosim-context-pin');
const Key electroSimTopPinKey = Key('electrosim-top-pin');
const Key electroSimStatusPinKey = Key('electrosim-status-pin');

// Kept for API compatibility with earlier tests/importers. The permanent
// switcher rows were removed when the workspace moved to auto-hide overlays.
const Key electroSimCompactActionsKey = Key('electrosim-compact-actions');
const Key electroSimMediumActionsKey = Key('electrosim-medium-actions');

enum ElectroSimWorkspacePanel { palette, context, top, status }

/// Workspace shell whose canvas always owns the full available surface.
///
/// Every auxiliary surface is an overlay:
/// - mouse/trackpad: entering an edge opens it; leaving schedules auto-close;
/// - touch: tapping the edge toggles it; tapping the canvas closes unpinned
///   panels;
/// - pin: keeps a panel open until explicitly unpinned.
///
/// Opening a panel never resizes the canvas, so component positions remain
/// stable and large visual components do not lose placement area.
class ElectroSimWorkspaceShell extends StatefulWidget {
  const ElectroSimWorkspaceShell({
    super.key,
    required this.canvas,
    required this.palette,
    required this.contextPanel,
    required this.topBar,
    required this.statusBar,
  });

  final Widget canvas;
  final Widget palette;
  final Widget contextPanel;
  final Widget topBar;
  final Widget statusBar;

  @override
  State<ElectroSimWorkspaceShell> createState() =>
      _ElectroSimWorkspaceShellState();
}

class _ElectroSimWorkspaceShellState extends State<ElectroSimWorkspaceShell> {
  static const Duration _motionDuration = Duration(milliseconds: 180);
  static const Duration _closeDelay = Duration(milliseconds: 420);

  final Set<ElectroSimWorkspacePanel> _open = <ElectroSimWorkspacePanel>{};
  final Set<ElectroSimWorkspacePanel> _pinned = <ElectroSimWorkspacePanel>{};
  final Map<ElectroSimWorkspacePanel, Timer> _closeTimers =
      <ElectroSimWorkspacePanel, Timer>{};

  bool _isOpen(ElectroSimWorkspacePanel panel) =>
      _open.contains(panel) || _pinned.contains(panel);

  void _cancelClose(ElectroSimWorkspacePanel panel) {
    _closeTimers.remove(panel)?.cancel();
  }

  void _openPanel(ElectroSimWorkspacePanel panel) {
    _cancelClose(panel);
    if (_open.contains(panel)) return;
    setState(() => _open.add(panel));
  }

  void _scheduleClose(ElectroSimWorkspacePanel panel) {
    _cancelClose(panel);
    if (_pinned.contains(panel)) return;
    _closeTimers[panel] = Timer(_closeDelay, () {
      if (!mounted || _pinned.contains(panel)) return;
      setState(() => _open.remove(panel));
    });
  }

  void _togglePanel(ElectroSimWorkspacePanel panel) {
    _cancelClose(panel);
    setState(() {
      if (_isOpen(panel)) {
        if (!_pinned.contains(panel)) {
          _open.remove(panel);
        }
      } else {
        _open.add(panel);
      }
    });
  }

  void _togglePin(ElectroSimWorkspacePanel panel) {
    _cancelClose(panel);
    setState(() {
      if (_pinned.remove(panel)) {
        _open.add(panel);
      } else {
        _pinned.add(panel);
        _open.add(panel);
      }
    });
  }

  void _closeUnpinned() {
    for (final Timer timer in _closeTimers.values) {
      timer.cancel();
    }
    _closeTimers.clear();
    final Set<ElectroSimWorkspacePanel> keep = <ElectroSimWorkspacePanel>{
      ..._pinned,
    };
    if (_open.length == keep.length && _open.containsAll(keep)) return;
    setState(() {
      _open
        ..clear()
        ..addAll(keep);
    });
  }

  @override
  void dispose() {
    for (final Timer timer in _closeTimers.values) {
      timer.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final ElectroSimWindowClass windowClass =
            ElectroSimBreakpoints.classify(constraints.maxWidth);
        final bool compact = windowClass == ElectroSimWindowClass.compact;
        final bool medium = windowClass == ElectroSimWindowClass.medium;

        final double paletteWidth = compact
            ? constraints.maxWidth * .88
            : medium
                ? ElectroSimGeometry.mediumPanelWidth
                : ElectroSimGeometry.expandedPaletteWidth;
        final double contextWidth = compact
            ? constraints.maxWidth * .88
            : medium
                ? ElectroSimGeometry.mediumPanelWidth
                : ElectroSimGeometry.expandedContextWidth;

        return Material(
          color: ElectroSimColors.surface,
          child: Stack(
            clipBehavior: Clip.hardEdge,
            children: <Widget>[
              Positioned.fill(
                key: electroSimCanvasRegionKey,
                child: Listener(
                  behavior: HitTestBehavior.translucent,
                  onPointerDown: (_) => _closeUnpinned(),
                  child: widget.canvas,
                ),
              ),

              _edgeActivator(
                key: electroSimPaletteEdgeKey,
                panel: ElectroSimWorkspacePanel.palette,
                alignment: Alignment.centerLeft,
                tooltip: 'Afficher la palette',
                icon: Icons.grid_view_outlined,
              ),
              _edgeActivator(
                key: electroSimContextEdgeKey,
                panel: ElectroSimWorkspacePanel.context,
                alignment: Alignment.centerRight,
                tooltip: 'Afficher les propriétés',
                icon: Icons.tune,
              ),
              _edgeActivator(
                key: electroSimTopEdgeKey,
                panel: ElectroSimWorkspacePanel.top,
                alignment: Alignment.topCenter,
                tooltip: 'Afficher les commandes',
                icon: Icons.keyboard_arrow_down,
              ),
              _edgeActivator(
                key: electroSimStatusEdgeKey,
                panel: ElectroSimWorkspacePanel.status,
                alignment: Alignment.bottomCenter,
                tooltip: 'Afficher l’état',
                icon: Icons.keyboard_arrow_up,
              ),

              _sideOverlay(
                panel: ElectroSimWorkspacePanel.palette,
                alignment: Alignment.centerLeft,
                width: paletteWidth,
                regionKey: electroSimPaletteRegionKey,
                pinKey: electroSimPalettePinKey,
                child: widget.palette,
              ),
              _sideOverlay(
                panel: ElectroSimWorkspacePanel.context,
                alignment: Alignment.centerRight,
                width: contextWidth,
                regionKey: electroSimContextRegionKey,
                pinKey: electroSimContextPinKey,
                child: widget.contextPanel,
              ),
              _horizontalOverlay(
                panel: ElectroSimWorkspacePanel.top,
                alignment: Alignment.topCenter,
                regionKey: electroSimTopRegionKey,
                pinKey: electroSimTopPinKey,
                child: widget.topBar,
              ),
              _horizontalOverlay(
                panel: ElectroSimWorkspacePanel.status,
                alignment: Alignment.bottomCenter,
                regionKey: electroSimStatusRegionKey,
                pinKey: electroSimStatusPinKey,
                child: widget.statusBar,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _edgeActivator({
    required Key key,
    required ElectroSimWorkspacePanel panel,
    required Alignment alignment,
    required String tooltip,
    required IconData icon,
  }) {
    final bool horizontal =
        panel == ElectroSimWorkspacePanel.top ||
        panel == ElectroSimWorkspacePanel.status;
    final bool open = _isOpen(panel);

    final Widget visibleHandle = Container(
      width: horizontal ? 58 : 7,
      height: horizontal ? 7 : 58,
      decoration: BoxDecoration(
        color: open
            ? ElectroSimColors.primary.withValues(alpha: .38)
            : ElectroSimColors.surfaceElevated.withValues(alpha: .92),
        borderRadius: BorderRadius.circular(8),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            blurRadius: 4,
            color: Color(0x22000000),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: open
          ? Icon(
              icon,
              size: 8,
              color: ElectroSimColors.textSecondary,
            )
          : null,
    );

    final Widget activationZone = MouseRegion(
      onEnter: (_) => _openPanel(panel),
      onExit: (_) => _scheduleClose(panel),
      child: Semantics(
        button: true,
        label: tooltip,
        child: Tooltip(
          message: tooltip,
          child: GestureDetector(
            key: key,
            behavior: HitTestBehavior.opaque,
            onTap: () => _togglePanel(panel),
            child: Center(child: visibleHandle),
          ),
        ),
      ),
    );

    const double activationExtent = 18;
    if (alignment == Alignment.centerLeft) {
      return Positioned(
        left: 0,
        top: 0,
        bottom: 0,
        width: activationExtent,
        child: activationZone,
      );
    }
    if (alignment == Alignment.centerRight) {
      return Positioned(
        right: 0,
        top: 0,
        bottom: 0,
        width: activationExtent,
        child: activationZone,
      );
    }
    if (alignment == Alignment.topCenter) {
      return Positioned(
        left: 0,
        right: 0,
        top: 0,
        height: activationExtent,
        child: activationZone,
      );
    }
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      height: activationExtent,
      child: activationZone,
    );
  }

  Widget _sideOverlay({
    required ElectroSimWorkspacePanel panel,
    required Alignment alignment,
    required double width,
    required Key regionKey,
    required Key pinKey,
    required Widget child,
  }) {
    final bool open = _isOpen(panel);
    final bool left = alignment == Alignment.centerLeft;
    final Offset hiddenOffset = Offset(left ? -1.04 : 1.04, 0);

    return Positioned(
      top: 0,
      bottom: 0,
      left: left ? 0 : null,
      right: left ? null : 0,
      width: width,
      child: IgnorePointer(
        ignoring: !open,
        child: AnimatedSlide(
          duration: _motionDuration,
          curve: Curves.easeOutCubic,
          offset: open ? Offset.zero : hiddenOffset,
          child: MouseRegion(
            onEnter: (_) => _openPanel(panel),
            onExit: (_) => _scheduleClose(panel),
            child: Material(
              key: regionKey,
              elevation: 14,
              color: ElectroSimColors.surfaceElevated,
              child: Stack(
                children: <Widget>[
                  Positioned.fill(child: child),
                  Positioned(
                    top: 4,
                    right: left ? 4 : null,
                    left: left ? null : 4,
                    child: _pinButton(
                      panel: panel,
                      key: pinKey,
                      compact: true,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _horizontalOverlay({
    required ElectroSimWorkspacePanel panel,
    required Alignment alignment,
    required Key regionKey,
    required Key pinKey,
    required Widget child,
  }) {
    final bool open = _isOpen(panel);
    final bool top = alignment == Alignment.topCenter;
    final Offset hiddenOffset = Offset(0, top ? -1.08 : 1.08);

    return Align(
      alignment: alignment,
      child: IgnorePointer(
        ignoring: !open,
        child: AnimatedSlide(
          duration: _motionDuration,
          curve: Curves.easeOutCubic,
          offset: open ? Offset.zero : hiddenOffset,
          child: MouseRegion(
            onEnter: (_) => _openPanel(panel),
            onExit: (_) => _scheduleClose(panel),
            child: Material(
              key: regionKey,
              elevation: 14,
              color: ElectroSimColors.surfaceElevated,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (!top)
                    _horizontalPinRail(
                      panel: panel,
                      pinKey: pinKey,
                    ),
                  child,
                  if (top)
                    _horizontalPinRail(
                      panel: panel,
                      pinKey: pinKey,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _horizontalPinRail({
    required ElectroSimWorkspacePanel panel,
    required Key pinKey,
  }) {
    return SizedBox(
      height: 24,
      child: Align(
        alignment: Alignment.centerRight,
        child: Padding(
          padding: const EdgeInsets.only(right: 4),
          child: _pinButton(
            panel: panel,
            key: pinKey,
            compact: true,
          ),
        ),
      ),
    );
  }

  Widget _pinButton({
    required ElectroSimWorkspacePanel panel,
    required Key key,
    bool compact = false,
  }) {
    final bool pinned = _pinned.contains(panel);
    return IconButton(
      key: key,
      tooltip: pinned ? 'Désépingler' : 'Épingler',
      visualDensity: compact ? VisualDensity.compact : null,
      padding: compact ? const EdgeInsets.all(3) : null,
      constraints: compact
          ? const BoxConstraints.tightFor(width: 30, height: 30)
          : null,
      onPressed: () => _togglePin(panel),
      icon: Icon(
        pinned ? Icons.push_pin : Icons.push_pin_outlined,
        size: compact ? 17 : 19,
      ),
    );
  }
}
