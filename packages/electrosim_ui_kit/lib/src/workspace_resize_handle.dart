import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A thin divider with a generous pointer surface and keyboard alternatives.
class WorkspaceResizeHandle extends StatelessWidget {
  const WorkspaceResizeHandle({
    super.key,
    required this.axis,
    required this.onDelta,
    required this.semanticLabel,
    required this.enabled,
  });
  final Axis axis;
  final ValueChanged<double> onDelta;
  final String semanticLabel;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final horizontal = axis == Axis.horizontal;
    void delta(double value) {
      if (enabled) onDelta(value);
    }

    return Semantics(
      label: semanticLabel,
      enabled: enabled,
      onIncrease: enabled ? () => delta(8) : null,
      onDecrease: enabled ? () => delta(-8) : null,
      child: FocusableActionDetector(
        enabled: enabled,
        mouseCursor: enabled
            ? (horizontal
                  ? SystemMouseCursors.resizeLeftRight
                  : SystemMouseCursors.resizeUpDown)
            : SystemMouseCursors.basic,
        shortcuts: {
          SingleActivator(
            horizontal
                ? LogicalKeyboardKey.arrowRight
                : LogicalKeyboardKey.arrowDown,
          ): const _ResizeIntent(
            8,
          ),
          SingleActivator(
            horizontal
                ? LogicalKeyboardKey.arrowLeft
                : LogicalKeyboardKey.arrowUp,
          ): const _ResizeIntent(
            -8,
          ),
        },
        actions: {
          _ResizeIntent: CallbackAction<_ResizeIntent>(
            onInvoke: (intent) {
              delta(intent.delta);
              return null;
            },
          ),
        },
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onHorizontalDragUpdate: enabled && horizontal
              ? (details) => delta(details.delta.dx)
              : null,
          onVerticalDragUpdate: enabled && !horizontal
              ? (details) => delta(details.delta.dy)
              : null,
          child: Center(
            child: Container(
              width: horizontal ? 2 : 28,
              height: horizontal ? 28 : 2,
              decoration: BoxDecoration(
                color: const Color(0xFFB8C6D7),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ResizeIntent extends Intent {
  const _ResizeIntent(this.delta);
  final double delta;
}
