import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:flutter/material.dart';

/// Interaction markers, separate from the device's physical connectors.
class F18TerminalAffordances {
  static bool visible({
    required bool hovered,
    required bool pending,
    required bool selected,
    required bool showAll,
  }) => hovered || pending || selected || showAll;

  static void paint(
    Canvas canvas,
    Offset point, {
    required bool hovered,
    required bool pending,
    required String name,
  }) {
    const color = Color(0xFF2563EB);
    final radius = hovered || pending ? 7.0 : 4.5;
    canvas.drawCircle(
      point,
      radius + 3,
      Paint()..color = color.withValues(alpha: .13),
    );
    canvas.drawCircle(
      point,
      radius,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6,
    );
    canvas.drawCircle(point, 1.3, Paint()..color = color);
    if (!hovered || name.isEmpty) return;
    final label = TextPainter(
      text: TextSpan(
        text: name,
        style: const TextStyle(
          fontSize: 12,
          color: Color(0xFF16283D),
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final box = Rect.fromLTWH(
      point.dx + 13,
      point.dy - 27,
      label.width + 12,
      label.height + 8,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(box, const Radius.circular(4)),
      Paint()..color = const Color(0xFFF1F5FA),
    );
    label.paint(canvas, box.topLeft + const Offset(6, 4));
    label.dispose();
  }

  static Map<TerminalId, ({String owner, String name})> descriptors(
    CircuitState circuit,
  ) => {
    for (final source in circuit.sources)
      for (final terminal in source.terminals)
        terminal.id: (owner: source.id.value, name: terminal.name),
    for (final component in circuit.components)
      for (final terminal in component.terminals)
        terminal.id: (owner: component.id.value, name: terminal.name),
  };
}
