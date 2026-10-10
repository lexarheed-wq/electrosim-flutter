import 'dart:math' as math;
import 'package:electrosim_canvas/electrosim_canvas.dart';
import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:flutter/material.dart';

import 'industrial_schematic_references.dart';

enum WorkspaceRepresentation { plate, schematic }

enum SchematicGlyph {
  source,
  lamp,
  motor,
  contact,
  protection,
  coil,
  resistor,
  capacitor,
  diode,
  terminal,
  load,
}

/// Schematic geometry is derived, never written over the authored plate.
/// Every visible port retains its original TerminalId, including coil ports.
abstract final class IndustrialSchematicProjection {
  static SchematicGlyph glyphFor(String type) {
    final t = type.toLowerCase();
    if (t.contains('source') || t.contains('battery') || t == 'pv_array') {
      return SchematicGlyph.source;
    }
    if (t.contains('lamp') || t.contains('indicator')) {
      return SchematicGlyph.lamp;
    }
    if (t.contains('motor') || t.contains('fan') || t.contains('pump')) {
      return SchematicGlyph.motor;
    }
    if (t.contains('breaker') ||
        t.contains('rcd') ||
        t.contains('fuse') ||
        t.contains('overload')) {
      return SchematicGlyph.protection;
    }
    if (t.contains('switch') ||
        t.contains('button') ||
        t.contains('contact') ||
        t.contains('isolator')) {
      return SchematicGlyph.contact;
    }
    if (t.contains('coil') || t.contains('inductor')) {
      return SchematicGlyph.coil;
    }
    if (t.contains('resistor') || t.contains('heater')) {
      return SchematicGlyph.resistor;
    }
    if (t.contains('capacitor')) return SchematicGlyph.capacitor;
    if (t.contains('diode')) return SchematicGlyph.diode;
    if (t.contains('terminal')) return SchematicGlyph.terminal;
    return SchematicGlyph.load;
  }

  static List<Offset> anchors(String type, int count) {
    if (count == 2) return const [Offset(-60, 0), Offset(60, 0)];
    if (type == 'contactor_3p' && count == 8) {
      return const [
        Offset(-36, -48),
        Offset(0, -48),
        Offset(36, -48),
        Offset(-36, 48),
        Offset(0, 48),
        Offset(36, 48),
        Offset(-75, 0),
        Offset(75, 0),
      ];
    }
    if (type == 'contactor_ac1' && count == 4) {
      return const [
        Offset(0, -48),
        Offset(0, 48),
        Offset(-75, 0),
        Offset(75, 0),
      ];
    }
    if (type.contains('source') || type == 'load_delta_3p') {
      return [
        for (var i = 0; i < count; i++) Offset((i - (count - 1) / 2) * 30, 48),
      ];
    }
    if (type == 'load_wye_3p' && count == 4) {
      return const [
        Offset(-36, -48),
        Offset(0, -48),
        Offset(36, -48),
        Offset(0, 48),
      ];
    }
    final top = (count / 2).ceil(), bottom = count - top;
    return [
      for (var i = 0; i < top; i++) Offset((i - (top - 1) / 2) * 30, -48),
      for (var i = 0; i < bottom; i++) Offset((i - (bottom - 1) / 2) * 30, 48),
    ];
  }

  static CircuitVisualLayout derive(
    CircuitState circuit,
    CircuitVisualLayout plate,
  ) {
    final positions = <String, Offset>{};
    final sizes = <String, Size>{};
    final offsets = <String, Offset>{};
    void add(String id, String type, List<Terminal> terminals) {
      final p = plate.positionOf(id);
      if (p == null) return;
      positions[id] = p;
      final ports = anchors(type, terminals.length);
      final width = terminals.length == 2
          ? 120.0
          : math.max(150.0, (terminals.length / 2).ceil() * 30.0 + 30);
      sizes[id] = Size(width, 96);
      for (var i = 0; i < terminals.length; i++) {
        offsets[terminals[i].id.value] = ports[i];
      }
    }

    for (final item in circuit.sources) {
      add(item.id.value, item.modelType, item.terminals);
    }
    for (final item in circuit.components) {
      add(item.id.value, item.modelType, item.terminals);
    }
    // Keep the spatial row order, but separate overlapping symbol envelopes.
    // Physical plate positions are never changed. This also prevents two
    // adjacent schematic ports from becoming the same hit target.
    final ordered = positions.keys.toList()
      ..sort((a, b) {
        final y = positions[a]!.dy.compareTo(positions[b]!.dy);
        if (y != 0) return y;
        final x = positions[a]!.dx.compareTo(positions[b]!.dx);
        return x == 0 ? a.compareTo(b) : x;
      });
    final occupied = <Rect>[];
    for (final id in ordered) {
      final baseSize = sizes[id]!;
      final size = plate.quarterTurnsOf(id).isOdd
          ? Size(baseSize.height, baseSize.width)
          : baseSize;
      var center = positions[id]!;
      Rect envelope() => Rect.fromCenter(
        center: center,
        width: size.width,
        height: size.height,
      ).inflate(8);
      var overlaps = occupied.where((r) => r.overlaps(envelope())).toList();
      while (overlaps.isNotEmpty) {
        center = Offset(
          overlaps.map((r) => r.right).reduce(math.max) + size.width / 2 + 16,
          center.dy,
        );
        overlaps = occupied.where((r) => r.overlaps(envelope())).toList();
      }
      positions[id] = center;
      occupied.add(envelope());
    }
    final symbols = CircuitVisualLayout(
      elementPositions: positions,
      elementSizes: sizes,
      elementQuarterTurns: plate.elementQuarterTurns,
      terminalAnchorOffsets: offsets,
    );
    // Normalize only the routing input order. The authored CircuitState and
    // its electrical topology are never rewritten by a visual projection.
    final canonicalConnections = [...circuit.connections]
      ..sort((a, b) => a.id.value.compareTo(b.id.value));
    final routingCircuit = CircuitState(
      circuitId: circuit.circuitId,
      revision: circuit.revision,
      mode: circuit.mode,
      components: circuit.components,
      sources: circuit.sources,
      connections: canonicalConnections,
      instruments: circuit.instruments,
      probes: circuit.probes,
      settings: circuit.settings,
      metadata: circuit.metadata,
    );
    return const CircuitWireLayoutEngine(
      router: OrthogonalWireRouter(
        grid: 12,
        obstacleClearance: 12,
        envelopePadding: 96,
      ),
    ).routeAll(circuit: routingCircuit, layout: symbols);
  }
}

class IndustrialSchematicOverlay extends StatelessWidget {
  const IndustrialSchematicOverlay({
    super.key,
    required this.circuit,
    required this.layout,
    required this.viewport,
    required this.selectedIds,
    required this.pointer,
    this.pendingTerminal,
    this.hoverTerminal,
  });
  final CircuitState circuit;
  final CircuitVisualLayout layout;
  final ViewportController viewport;
  final Set<String> selectedIds;
  final ValueNotifier<Offset?> pointer;
  final TerminalId? pendingTerminal, hoverTerminal;
  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: AnimatedBuilder(
      animation: Listenable.merge([viewport, pointer]),
      builder: (context, child) => CustomPaint(
        painter: IndustrialSchematicPainter(
          circuit: circuit,
          layout: layout,
          viewport: viewport,
          selectedIds: selectedIds,
          pendingTerminal: pendingTerminal,
          hoverTerminal: hoverTerminal,
          pointer: pointer.value,
        ),
        size: Size.infinite,
      ),
    ),
  );
}

/// IEC-inspired family symbols; abstract models retain an explicit model label.
/// Terminal leads only depict the device; connectivity comes from CircuitState.
class IndustrialSchematicPainter extends CustomPainter {
  IndustrialSchematicPainter({
    required this.circuit,
    required this.layout,
    required this.viewport,
    required this.selectedIds,
    this.pendingTerminal,
    this.hoverTerminal,
    this.pointer,
  });
  final CircuitState circuit;
  final CircuitVisualLayout layout;
  final ViewportController viewport;
  final Set<String> selectedIds;
  final TerminalId? pendingTerminal, hoverTerminal;
  final Offset? pointer;
  void label(
    Canvas c,
    String text,
    Offset at, {
    double size = 11,
    Color color = Colors.black,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(fontSize: size, color: color, fontFamily: 'Roboto'),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: 180);
    tp.paint(c, at - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final references = IndustrialSchematicReferences.build(circuit);
    canvas.save();
    canvas.translate(viewport.translation.dx, viewport.translation.dy);
    canvas.scale(viewport.scale);
    void element(String id, String type, List<Terminal> terminals) {
      final center = layout.positionOf(id);
      if (center == null) return;
      final glyph = IndustrialSchematicProjection.glyphFor(type);
      final anchors = IndustrialSchematicProjection.anchors(
        type,
        terminals.length,
      );
      final p = Paint()
        ..color = Colors.black
        ..strokeWidth = 1.7
        ..style = PaintingStyle.stroke;
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(layout.quarterTurnsOf(id) * math.pi / 2);
      final body = Rect.fromCenter(
        center: Offset.zero,
        width: layout.sizeOf(id).width - 40,
        height: 54,
      );
      canvas.drawRect(body.inflate(1), Paint()..color = Colors.white);
      if (selectedIds.contains(id)) {
        canvas.drawRect(
          (Offset.zero & layout.sizeOf(id))
              .shift(Offset(-layout.sizeOf(id).width / 2, -48))
              .inflate(5),
          Paint()
            ..color = Colors.blue
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.4,
        );
      }
      for (var i = 0; i < anchors.length; i++) {
        final a = anchors[i];
        final edge = a.dy == 0
            ? Offset(a.dx.sign * body.width / 2, 0)
            : Offset(a.dx, a.dy.sign * body.height / 2);
        canvas.drawLine(a, edge, p);
        canvas.drawCircle(a, 3, Paint()..color = Colors.white);
        canvas.drawCircle(a, 3, p);
        if (terminals[i].id == pendingTerminal ||
            terminals[i].id == hoverTerminal) {
          canvas.drawCircle(
            a,
            6,
            Paint()
              ..color = Colors.orange
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2,
          );
        }
        label(
          canvas,
          terminals[i].name,
          a + Offset(a.dy == 0 ? 0 : 8, a.dy == 0 ? -9 : -a.dy.sign * 9),
          size: 9,
        );
      }
      if (terminals.length == 2 &&
          [
            SchematicGlyph.lamp,
            SchematicGlyph.motor,
            SchematicGlyph.source,
          ].contains(glyph)) {
        canvas.drawLine(Offset(-body.width / 2, 0), const Offset(-22, 0), p);
        canvas.drawLine(const Offset(22, 0), Offset(body.width / 2, 0), p);
      } else if (terminals.length > 2 &&
          [
            SchematicGlyph.lamp,
            SchematicGlyph.motor,
            SchematicGlyph.source,
          ].contains(glyph)) {
        canvas.drawRect(body, p);
      }
      switch (glyph) {
        case SchematicGlyph.lamp:
          canvas.drawCircle(Offset.zero, 21, p);
          canvas.drawLine(const Offset(-15, -15), const Offset(15, 15), p);
          canvas.drawLine(const Offset(-15, 15), const Offset(15, -15), p);
        case SchematicGlyph.motor:
          canvas.drawCircle(Offset.zero, 22, p);
          label(canvas, 'M', Offset.zero, size: 23);
        case SchematicGlyph.source:
          canvas.drawCircle(Offset.zero, 22, p);
          label(
            canvas,
            type.contains('ac') ? '~' : '+  −',
            Offset.zero,
            size: 20,
          );
        case SchematicGlyph.contact:
          if (terminals.length <= 2) {
            canvas.drawLine(
              Offset(-body.width / 2, 0),
              const Offset(-16, 0),
              p,
            );
            canvas.drawCircle(const Offset(-16, 0), 2, p);
            canvas.drawCircle(const Offset(16, 0), 2, p);
            if (IndustrialSchematicReferences.normallyClosed(type)) {
              // A normally-closed contact must be shown conducting at rest;
              // dynamic opening is represented by runtime, not by this glyph.
              canvas.drawLine(const Offset(-16, 0), const Offset(16, 0), p);
            } else {
              canvas.drawLine(
                const Offset(-16, 0),
                const Offset(12, -17),
                p,
              );
            }
            canvas.drawLine(const Offset(16, 0), Offset(body.width / 2, 0), p);
          } else {
            // Power poles and an electrically separate coil for contactors.
            final coil = type.startsWith('contactor_') && !type.contains('aux');
            final power = coil ? terminals.length - 2 : terminals.length;
            final poles = power ~/ 2;
            for (var i = 0; i < poles; i++) {
              final x = anchors[i].dx;
              canvas.drawLine(Offset(x, -27), Offset(x, -10), p);
              canvas.drawCircle(Offset(x, -10), 2, p);
              canvas.drawLine(Offset(x, -10), Offset(x + 10, 9), p);
              canvas.drawCircle(Offset(x, 14), 2, p);
              canvas.drawLine(Offset(x, 14), Offset(x, 27), p);
            }
            if (coil) {
              canvas.drawRect(const Rect.fromLTWH(-17, -7, 34, 14), p);
              canvas.drawLine(
                Offset(-body.width / 2, 0),
                const Offset(-17, 0),
                p,
              );
              canvas.drawLine(
                const Offset(17, 0),
                Offset(body.width / 2, 0),
                p,
              );
            }
          }
        case SchematicGlyph.protection:
          canvas.drawRect(body, p);
          final n = terminals.length ~/ 2;
          if (terminals.length == 2) {
            canvas.drawLine(
              Offset(-body.width / 2, 0),
              Offset(body.width / 2, 0),
              p,
            );
          } else {
            for (var i = 0; i < n; i++) {
              final x = anchors[i].dx;
              canvas.drawLine(Offset(x, -27), Offset(x, 27), p);
            }
          }
          label(
            canvas,
            type.contains('fuse')
                ? 'F'
                : type.contains('overload')
                ? 'θ'
                : 'Q',
            const Offset(0, -14),
            size: 12,
          );
        case SchematicGlyph.coil:
          canvas.drawRect(const Rect.fromLTWH(-25, -18, 50, 36), p);
          canvas.drawLine(Offset(-body.width / 2, 0), const Offset(-25, 0), p);
          canvas.drawLine(const Offset(25, 0), Offset(body.width / 2, 0), p);
          label(canvas, 'A', Offset.zero, size: 16);
        case SchematicGlyph.resistor:
          canvas.drawRect(const Rect.fromLTWH(-28, -10, 56, 20), p);
          canvas.drawLine(Offset(-body.width / 2, 0), const Offset(-28, 0), p);
          canvas.drawLine(const Offset(28, 0), Offset(body.width / 2, 0), p);
        case SchematicGlyph.capacitor:
          canvas.drawLine(const Offset(-5, -19), const Offset(-5, 19), p);
          canvas.drawLine(const Offset(5, -19), const Offset(5, 19), p);
          canvas.drawLine(Offset(-body.width / 2, 0), const Offset(-5, 0), p);
          canvas.drawLine(const Offset(5, 0), Offset(body.width / 2, 0), p);
        case SchematicGlyph.diode:
          canvas.drawPath(
            Path()
              ..moveTo(-16, -16)
              ..lineTo(14, 0)
              ..lineTo(-16, 16)
              ..close(),
            p,
          );
          canvas.drawLine(const Offset(14, -18), const Offset(14, 18), p);
          canvas.drawLine(Offset(-body.width / 2, 0), const Offset(-16, 0), p);
          canvas.drawLine(const Offset(14, 0), Offset(body.width / 2, 0), p);
        case SchematicGlyph.terminal:
          canvas.drawRect(body, p);
          label(canvas, 'X', Offset.zero, size: 18);
        case SchematicGlyph.load:
          canvas.drawRect(body, p);
          label(canvas, type, Offset.zero, size: 10);
      }
      label(
        canvas,
        references.labelOf(id),
        const Offset(0, -68),
        size: 11,
        color: selectedIds.contains(id) ? Colors.blue : Colors.black,
      );
      final controlling = references.controllingLabelFor(id);
      if (controlling != null) {
        label(canvas, '↔ ' + controlling, const Offset(0, 69), size: 10);
      } else if (references.contactsFor(id).isNotEmpty) {
        final contacts = references.contactsFor(id)
            .map(references.labelOf)
            .join(', ');
        label(canvas, '↔ ' + contacts, const Offset(0, 69), size: 10);
      }
      canvas.restore();
    }

    for (final s in circuit.sources) {
      element(s.id.value, s.modelType, s.terminals);
    }
    for (final c in circuit.components) {
      element(c.id.value, c.modelType, c.terminals);
    }
    final start = pendingTerminal == null
        ? null
        : CircuitGeometryIndex.build(
            circuit,
            layout,
          ).terminalPositions[pendingTerminal];
    if (start != null && pointer != null) {
      final p = Paint()
        ..color = Colors.orange
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;
      canvas.drawPath(
        Path()
          ..moveTo(start.dx, start.dy)
          ..lineTo(pointer!.dx, start.dy)
          ..lineTo(pointer!.dx, pointer!.dy),
        p,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant IndustrialSchematicPainter oldDelegate) => true;
}
