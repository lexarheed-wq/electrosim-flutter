import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'design_tokens.dart';
import 'workspace_layout_controller.dart';
import 'workspace_resize_handle.dart';

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

/// Docked engineering workspace. Chrome never obscures another panel's tabs.
class ElectroSimWorkspaceShell extends StatefulWidget {
  const ElectroSimWorkspaceShell({
    super.key,
    required this.canvas,
    required this.palette,
    required this.contextPanel,
    required this.topBar,
    required this.statusBar,
    this.layoutController,
    this.interactionLocked = false,
    this.onBeforeLayoutChange,
    this.onCanvasSizeChanged,
  });
  final Widget canvas;
  final Widget palette;
  final Widget contextPanel;
  final Widget topBar;
  final Widget statusBar;
  final WorkspaceLayoutController? layoutController;
  final bool interactionLocked;
  final VoidCallback? onBeforeLayoutChange;
  final ValueChanged<Size>? onCanvasSizeChanged;
  @override
  State<ElectroSimWorkspaceShell> createState() =>
      _ElectroSimWorkspaceShellState();
}

class _ElectroSimWorkspaceShellState extends State<ElectroSimWorkspaceShell> {
  late WorkspaceLayoutController _layout;
  final _paletteFocus = FocusNode(debugLabel: 'workspace-palette-toggle');
  final _contextFocus = FocusNode(debugLabel: 'workspace-context-toggle');
  final _drawerFocus = FocusNode(debugLabel: 'workspace-drawer');
  ElectroSimWorkspacePanel? _drawerPanel;
  Size? _pendingSize;
  Size? _reportedSize;
  bool _sizeCallbackScheduled = false;

  @override
  void initState() {
    super.initState();
    _layout = widget.layoutController ?? WorkspaceLayoutController();
    _layout.addListener(_layoutChanged);
  }

  @override
  void didUpdateWidget(covariant ElectroSimWorkspaceShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.layoutController != widget.layoutController) {
      _layout.removeListener(_layoutChanged);
      if (oldWidget.layoutController == null) _layout.dispose();
      _layout = widget.layoutController ?? WorkspaceLayoutController();
      _layout.addListener(_layoutChanged);
    }
  }

  void _layoutChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _layout.removeListener(_layoutChanged);
    if (widget.layoutController == null) _layout.dispose();
    _paletteFocus.dispose();
    _contextFocus.dispose();
    _drawerFocus.dispose();
    super.dispose();
  }

  Duration get _duration => MediaQuery.disableAnimationsOf(context)
      ? Duration.zero
      : const Duration(milliseconds: 200);

  void _closeDrawer() {
    final previous = _drawerPanel;
    if (previous == null) return;
    widget.onBeforeLayoutChange?.call();
    setState(() => _drawerPanel = null);
    (previous == ElectroSimWorkspacePanel.palette
            ? _paletteFocus
            : _contextFocus)
        .requestFocus();
  }

  void _toggle(ElectroSimWorkspacePanel panel, bool docked) {
    if (widget.interactionLocked) return;
    widget.onBeforeLayoutChange?.call();
    if (docked) {
      final visible = panel == ElectroSimWorkspacePanel.palette
          ? _layout.paletteVisible
          : _layout.contextVisible;
      _layout.setPanelVisible(panel, !visible);
    } else {
      if (_drawerPanel == panel) {
        _closeDrawer();
        return;
      }
      setState(() => _drawerPanel = panel);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _drawerPanel == panel) _drawerFocus.requestFocus();
      });
    }
  }

  void _reportSize(Size size) {
    _pendingSize = size;
    if (_sizeCallbackScheduled || size == _reportedSize) return;
    _sizeCallbackScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _sizeCallbackScheduled = false;
      if (!mounted || _pendingSize == null || _pendingSize == _reportedSize) {
        return;
      }
      _reportedSize = _pendingSize;
      widget.onCanvasSizeChanged?.call(_reportedSize!);
    });
  }

  Widget _canvas({bool blocked = false}) => LayoutBuilder(
    builder: (context, constraints) {
      _reportSize(constraints.biggest);
      return SizedBox.expand(
        key: electroSimCanvasRegionKey,
        child: ExcludeFocus(
          excluding: blocked,
          child: ExcludeSemantics(
            excluding: blocked,
            child: IgnorePointer(
              ignoring: blocked,
              child: RepaintBoundary(child: widget.canvas),
            ),
          ),
        ),
      );
    },
  );

  Widget _panel(
    ElectroSimWorkspacePanel panel, {
    required VoidCallback onClose,
  }) {
    final palette = panel == ElectroSimWorkspacePanel.palette;
    return Material(
      key: palette ? electroSimPaletteRegionKey : electroSimContextRegionKey,
      color: ElectroSimColors.surface,
      child: Column(
        children: [
          Container(
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: ElectroSimColors.workspaceDivider),
              ),
            ),
            child: Row(
              children: [
                const SizedBox(width: 16),
                Icon(
                  palette ? Icons.grid_view_outlined : Icons.tune_outlined,
                  size: 18,
                  color: ElectroSimColors.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    palette ? 'Composants' : 'Inspecteur',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                IconButton(
                  key: palette
                      ? electroSimPalettePinKey
                      : electroSimContextPinKey,
                  tooltip: palette
                      ? 'Masquer les composants'
                      : 'Masquer l’inspecteur',
                  onPressed: widget.interactionLocked ? null : onClose,
                  icon: const Icon(Icons.close, size: 20),
                ),
              ],
            ),
          ),
          Expanded(child: palette ? widget.palette : widget.contextPanel),
        ],
      ),
    );
  }

  Widget _dock(ElectroSimWorkspacePanel panel, double width, bool visible) =>
      AnimatedContainer(
        duration: _duration,
        curve: Curves.easeOutCubic,
        width: visible ? width : 0,
        child: ClipRect(
          child: OverflowBox(
            alignment: Alignment.centerLeft,
            minWidth: width,
            maxWidth: width,
            child: IgnorePointer(
              ignoring: !visible,
              child: ExcludeSemantics(
                excluding: !visible,
                child: ExcludeFocus(
                  excluding: !visible,
                  child: _panel(panel, onClose: () => _toggle(panel, true)),
                ),
              ),
            ),
          ),
        ),
      );

  Widget _switcher(bool docked, bool compact) {
    Widget button(ElectroSimWorkspacePanel panel) {
      final palette = panel == ElectroSimWorkspacePanel.palette;
      final selected = docked
          ? (palette ? _layout.paletteVisible : _layout.contextVisible)
          : _drawerPanel == panel;
      return IconButton(
        key: palette ? electroSimPaletteEdgeKey : electroSimContextEdgeKey,
        focusNode: palette ? _paletteFocus : _contextFocus,
        tooltip: palette
            ? 'Afficher ou masquer les composants'
            : 'Afficher ou masquer les propriétés',
        isSelected: selected,
        onPressed: widget.interactionLocked
            ? null
            : () => _toggle(panel, docked),
        icon: Icon(palette ? Icons.grid_view_outlined : Icons.tune_outlined),
        style: IconButton.styleFrom(
          backgroundColor: selected
              ? ElectroSimColors.primary.withValues(alpha: .08)
              : null,
          foregroundColor: ElectroSimColors.primary,
        ),
      );
    }

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: ElectroSimColors.surface,
        border: Border(
          bottom: BorderSide(color: ElectroSimColors.workspaceDivider),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: [
            button(ElectroSimWorkspacePanel.palette),
            if (!compact) const Text('Bibliothèque'),
            const SizedBox(width: 8),
            button(ElectroSimWorkspacePanel.context),
            if (!compact) const Text('Propriétés et mesures'),
            const Spacer(),
            if (!compact)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'PLATINE',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: ElectroSimColors.textSecondary,
                    letterSpacing: 1,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final kind = classifyWorkspaceWidth(constraints.maxWidth);
        final compact = kind == ElectroSimWorkspaceLayoutClass.compact;
        final requested =
            (_layout.paletteVisible ? _layout.paletteWidth + 8 : 0) +
            (_layout.contextVisible ? _layout.contextWidth + 8 : 0);
        final docked =
            kind == ElectroSimWorkspaceLayoutClass.expanded &&
            constraints.maxWidth - requested >= 480;
        final open = !docked && _drawerPanel != null;
        return PopScope(
          canPop: !open,
          onPopInvokedWithResult: (didPop, result) {
            if (!didPop && mounted) _closeDrawer();
          },
          child: Material(
            color: ElectroSimColors.canvasSurface,
            child: Column(
              children: [
                KeyedSubtree(key: electroSimTopRegionKey, child: widget.topBar),
                _switcher(
                  docked,
                  compact || MediaQuery.textScalerOf(context).scale(14) > 18,
                ),
                Expanded(
                  child: docked
                      ? Stack(
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _dock(
                                  ElectroSimWorkspacePanel.palette,
                                  _layout.paletteWidth,
                                  _layout.paletteVisible,
                                ),
                                if (_layout.paletteVisible)
                                  const SizedBox(width: 8),
                                Expanded(child: _canvas()),
                                if (_layout.contextVisible)
                                  const SizedBox(width: 8),
                                _dock(
                                  ElectroSimWorkspacePanel.context,
                                  _layout.contextWidth,
                                  _layout.contextVisible,
                                ),
                              ],
                            ),
                            if (_layout.paletteVisible)
                              Positioned(
                                left: _layout.paletteWidth - 20,
                                top: 0,
                                bottom: 0,
                                width: 48,
                                child: WorkspaceResizeHandle(
                                  key: const Key('workspace-palette-resizer'),
                                  axis: Axis.horizontal,
                                  semanticLabel: 'Largeur du catalogue',
                                  enabled: !widget.interactionLocked,
                                  onDelta: (delta) {
                                    widget.onBeforeLayoutChange?.call();
                                    _layout.setPaletteWidth(
                                      _layout.paletteWidth + delta,
                                    );
                                  },
                                ),
                              ),
                            if (_layout.contextVisible)
                              Positioned(
                                right: _layout.contextWidth - 20,
                                top: 0,
                                bottom: 0,
                                width: 48,
                                child: WorkspaceResizeHandle(
                                  key: const Key('workspace-context-resizer'),
                                  axis: Axis.horizontal,
                                  semanticLabel: 'Largeur de l’inspecteur',
                                  enabled: !widget.interactionLocked,
                                  onDelta: (delta) {
                                    widget.onBeforeLayoutChange?.call();
                                    _layout.setContextWidth(
                                      _layout.contextWidth - delta,
                                    );
                                  },
                                ),
                              ),
                          ],
                        )
                      : Stack(
                          children: [
                            Positioned.fill(child: _canvas(blocked: open)),
                            if (open)
                              Positioned.fill(
                                child: ModalBarrier(
                                  color: Colors.black.withValues(alpha: .14),
                                  onDismiss: _closeDrawer,
                                  semanticsLabel: 'Fermer le panneau',
                                  barrierSemanticsDismissible: true,
                                ),
                              ),
                            Positioned.fill(
                              child: AnimatedSwitcher(
                                duration: _duration,
                                transitionBuilder: (child, animation) =>
                                    AnimatedBuilder(
                                      animation: animation,
                                      child: child,
                                      builder: (context, child) {
                                        final closing =
                                            animation.status ==
                                            AnimationStatus.reverse;
                                        return IgnorePointer(
                                          ignoring: closing,
                                          child: ExcludeSemantics(
                                            excluding: closing,
                                            child: FadeTransition(
                                              opacity: animation,
                                              child: SlideTransition(
                                                position:
                                                    Tween<Offset>(
                                                      begin: const Offset(
                                                        .06,
                                                        0,
                                                      ),
                                                      end: Offset.zero,
                                                    ).animate(
                                                      CurvedAnimation(
                                                        parent: animation,
                                                        curve:
                                                            Curves.easeOutCubic,
                                                      ),
                                                    ),
                                                child: child,
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                child: !open
                                    ? const SizedBox.shrink(
                                        key: Key('drawer-closed'),
                                      )
                                    : Align(
                                        key: ValueKey(_drawerPanel),
                                        alignment:
                                            _drawerPanel ==
                                                ElectroSimWorkspacePanel.palette
                                            ? Alignment.centerLeft
                                            : Alignment.centerRight,
                                        child: SizedBox(
                                          width: math.min(
                                            constraints.maxWidth - 32,
                                            compact ? 360 : 304,
                                          ),
                                          child: CallbackShortcuts(
                                            bindings: {
                                              const SingleActivator(
                                                LogicalKeyboardKey.escape,
                                              ): _closeDrawer,
                                            },
                                            child: Focus(
                                              autofocus: true,
                                              focusNode: _drawerFocus,
                                              child: _panel(
                                                _drawerPanel!,
                                                onClose: _closeDrawer,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                              ),
                            ),
                          ],
                        ),
                ),
                KeyedSubtree(
                  key: electroSimStatusRegionKey,
                  child: widget.statusBar,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
