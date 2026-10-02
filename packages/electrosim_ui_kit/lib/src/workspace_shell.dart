import 'package:flutter/material.dart';

import 'design_tokens.dart';
import 'responsive.dart';

const Key electroSimCanvasRegionKey = Key('electrosim-canvas-region');
const Key electroSimPaletteRegionKey = Key('electrosim-palette-region');
const Key electroSimContextRegionKey = Key('electrosim-context-region');
const Key electroSimCompactActionsKey = Key('electrosim-compact-actions');
const Key electroSimMediumActionsKey = Key('electrosim-medium-actions');

enum ElectroSimWorkspacePanel { palette, context }

class ElectroSimWorkspaceShell extends StatefulWidget {
  const ElectroSimWorkspaceShell({
    super.key,
    required this.canvas,
    required this.palette,
    required this.contextPanel,
    required this.topBar,
    required this.statusBar,
    this.showStatusBar = true,
    this.showCompactPanelSwitcher = true,
    this.mediumPanelInitiallyVisible = false,
    this.expandedPaletteWidth = ElectroSimGeometry.expandedPaletteWidth,
    this.expandedContextWidth = ElectroSimGeometry.expandedContextWidth,
    this.mediumPanelWidth = ElectroSimGeometry.mediumPanelWidth,
  });

  final Widget canvas;
  final Widget palette;
  final Widget contextPanel;
  final Widget topBar;
  final Widget statusBar;
  final bool showStatusBar;
  final bool showCompactPanelSwitcher;
  final bool mediumPanelInitiallyVisible;
  final double expandedPaletteWidth;
  final double expandedContextWidth;
  final double mediumPanelWidth;

  @override
  State<ElectroSimWorkspaceShell> createState() => _ElectroSimWorkspaceShellState();
}

class _ElectroSimWorkspaceShellState extends State<ElectroSimWorkspaceShell> {
  ElectroSimWorkspacePanel? _activePanel;

  @override
  void initState() {
    super.initState();
    if (widget.mediumPanelInitiallyVisible) {
      _activePanel = ElectroSimWorkspacePanel.context;
    }
  }

  void _toggle(ElectroSimWorkspacePanel panel) {
    setState(() {
      _activePanel = _activePanel == panel ? null : panel;
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final ElectroSimWindowClass windowClass = ElectroSimBreakpoints.classify(constraints.maxWidth);
        return switch (windowClass) {
          ElectroSimWindowClass.compact => _buildCompact(),
          ElectroSimWindowClass.medium => _buildMedium(),
          ElectroSimWindowClass.expanded => _buildExpanded(),
        };
      },
    );
  }

  Widget _buildExpanded() {
    return Column(
      children: <Widget>[
        widget.topBar,
        const Divider(height: 1),
        Expanded(
          child: Row(
            children: <Widget>[
              SizedBox(
                key: electroSimPaletteRegionKey,
                width: widget.expandedPaletteWidth,
                child: widget.palette,
              ),
              const VerticalDivider(width: 1),
              Expanded(key: electroSimCanvasRegionKey, child: widget.canvas),
              const VerticalDivider(width: 1),
              SizedBox(
                key: electroSimContextRegionKey,
                width: widget.expandedContextWidth,
                child: widget.contextPanel,
              ),
            ],
          ),
        ),
        if (widget.showStatusBar) ...<Widget>[
          const Divider(height: 1),
          SizedBox(
            height: ElectroSimGeometry.statusBarHeight,
            child: widget.statusBar,
          ),
        ],
      ],
    );
  }

  Widget _buildMedium() {
    final Widget? panel = _activePanel == null
        ? null
        : _activePanel == ElectroSimWorkspacePanel.palette
        ? widget.palette
        : widget.contextPanel;
    return Column(
      children: <Widget>[
        widget.topBar,
        _PanelSwitcher(
          key: electroSimMediumActionsKey,
          activePanel: _activePanel,
          onPalette: () => _toggle(ElectroSimWorkspacePanel.palette),
          onContext: () => _toggle(ElectroSimWorkspacePanel.context),
        ),
        const Divider(height: 1),
        Expanded(
          child: Row(
            children: <Widget>[
              Expanded(key: electroSimCanvasRegionKey, child: widget.canvas),
              if (panel != null) ...<Widget>[
                const VerticalDivider(width: 1),
                SizedBox(
                  key: _activePanel == ElectroSimWorkspacePanel.palette
                      ? electroSimPaletteRegionKey
                      : electroSimContextRegionKey,
                  width: widget.mediumPanelWidth,
                  child: panel,
                ),
              ],
            ],
          ),
        ),
        if (widget.showStatusBar) ...<Widget>[
          const Divider(height: 1),
          SizedBox(
            height: ElectroSimGeometry.statusBarHeight,
            child: widget.statusBar,
          ),
        ],
      ],
    );
  }

  Widget _buildCompact() {
    final Widget? overlay = _activePanel == null
        ? null
        : _activePanel == ElectroSimWorkspacePanel.palette
        ? widget.palette
        : widget.contextPanel;
    return Column(
      children: <Widget>[
        widget.topBar,
        const Divider(height: 1),
        Expanded(
          child: Stack(
            children: <Widget>[
              Positioned.fill(key: electroSimCanvasRegionKey, child: widget.canvas),
              if (overlay != null)
                Positioned.fill(
                  child: ColoredBox(
                    color: Colors.black26,
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 420),
                        child: Material(
                          key: _activePanel == ElectroSimWorkspacePanel.palette
                              ? electroSimPaletteRegionKey
                              : electroSimContextRegionKey,
                          color: ElectroSimColors.surfaceElevated,
                          elevation: 8,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(ElectroSimRadii.panel),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: overlay,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (widget.showStatusBar) ...<Widget>[
          const Divider(height: 1),
          SizedBox(
            height: ElectroSimGeometry.statusBarHeight,
            child: widget.statusBar,
          ),
        ],
        if (widget.showCompactPanelSwitcher)
          _PanelSwitcher(
            key: electroSimCompactActionsKey,
            activePanel: _activePanel,
            onPalette: () => _toggle(ElectroSimWorkspacePanel.palette),
            onContext: () => _toggle(ElectroSimWorkspacePanel.context),
          ),
      ],
    );
  }
}

class _PanelSwitcher extends StatelessWidget {
  const _PanelSwitcher({
    super.key,
    required this.activePanel,
    required this.onPalette,
    required this.onContext,
  });

  final ElectroSimWorkspacePanel? activePanel;
  final VoidCallback onPalette;
  final VoidCallback onContext;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: ElectroSimColors.surfaceElevated,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: ElectroSimSpacing.xs, vertical: ElectroSimSpacing.xxs),
          child: Row(
            children: <Widget>[
              Expanded(
                child: TextButton.icon(
                  onPressed: onPalette,
                  icon: const Icon(Icons.grid_view_outlined),
                  label: const Text('Palette'),
                  style: TextButton.styleFrom(
                    minimumSize: const Size(0, ElectroSimGeometry.minimumTouchTarget),
                    backgroundColor: activePanel == ElectroSimWorkspacePanel.palette
                        ? const Color(0xFFEFF4FF)
                        : null,
                  ),
                ),
              ),
              const SizedBox(width: ElectroSimSpacing.xs),
              Expanded(
                child: TextButton.icon(
                  onPressed: onContext,
                  icon: const Icon(Icons.tune),
                  label: const Text('Propriétés'),
                  style: TextButton.styleFrom(
                    minimumSize: const Size(0, ElectroSimGeometry.minimumTouchTarget),
                    backgroundColor: activePanel == ElectroSimWorkspacePanel.context
                        ? const Color(0xFFEFF4FF)
                        : null,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
