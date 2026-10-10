import 'dart:math' as math;

import 'package:electrosim_canvas/electrosim_canvas.dart';
import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:flutter/material.dart';

import 'industrial_schematic_references.dart';
import 'industrial_workspace_representation.dart';

/// A vector *multifilar* view derived from the real electrical netlist.
/// The family symbols are not claimed to be fully IEC certified.
abstract final class IndustrialSchematicSvgExport {
  static String render(CircuitState circuit, CircuitVisualLayout plate) {
    final layout = IndustrialSchematicProjection.derive(circuit, plate);
    final geometry = CircuitGeometryIndex.build(circuit, layout);
    final refs = IndustrialSchematicReferences.build(circuit);
    final ids = <String>[
      ...circuit.sources.map((e) => e.id.value),
      ...circuit.components.map((e) => e.id.value),
    ]..sort();
    if (ids.any((id) => layout.positionOf(id) == null)) {
      throw StateError('Missing schematic location: cannot export an incomplete page.');
    }

    final points = <Offset>[];
    for (final id in ids) {
      final center = layout.positionOf(id)!;
      final size = layout.displaySizeOf(id);
      points.add(center + Offset(-size.width / 2 - 105, -size.height / 2 - 105));
      points.add(center + Offset(size.width / 2 + 105, size.height / 2 + 105));
    }
    final wires = [...circuit.connections]
      ..sort((a, b) => a.id.value.compareTo(b.id.value));
    final paths = <String, List<Offset>>{};
    for (final wire in wires) {
      final first = geometry.terminalPositions[wire.fromTerminalId];
      final last = geometry.terminalPositions[wire.toTerminalId];
      if (first == null || last == null) {
        throw StateError('Unresolved electrical terminal on wire ${wire.id.value}.');
      }
      final route = <Offset>[first, ...layout.routeFor(wire.id.value), last];
      for (var i = 1; i < route.length; i++) {
        final a = route[i - 1], b = route[i];
        if ((a.dx - b.dx).abs() > 0.001 && (a.dy - b.dy).abs() > 0.001) {
          throw StateError('Wire not orthogonal: ${wire.id.value}.');
        }
      }
      paths[wire.id.value] = route;
      points.addAll(route);
    }
    final minX = points.isEmpty ? 0.0 : points.map((p) => p.dx).reduce(math.min) - 20;
    final minY = points.isEmpty ? 0.0 : points.map((p) => p.dy).reduce(math.min) - 20;
    final maxX = points.isEmpty ? 800.0 : points.map((p) => p.dx).reduce(math.max) + 20;
    final maxY = points.isEmpty ? 600.0 : points.map((p) => p.dy).reduce(math.max) + 20;

    final svg = StringBuffer()
      ..writeln('<?xml version="1.0" encoding="UTF-8"?>')
      ..writeln('<svg xmlns="http://www.w3.org/2000/svg" '
          'viewBox="${_n(minX)} ${_n(minY)} ${_n(maxX - minX)} ${_n(maxY - minY)}" '
          'data-circuit-id="${_xml(circuit.circuitId.value)}" data-mode="${circuit.mode.name}">')
      ..writeln('<title>ElectroSim - Schéma multifilaire</title>')
      ..writeln('<desc>Symboles de familles indicatifs, non certifiés IEC. '
          'Topologie issue de CircuitState.</desc>')
      ..writeln('<rect x="${_n(minX)}" y="${_n(minY)}" '
          'width="${_n(maxX - minX)}" height="${_n(maxY - minY)}" fill="white"/>')
      ..writeln('<g stroke="black" stroke-width="2" fill="none">');
    for (final wire in wires) {
      final route = paths[wire.id.value]!;
      svg.writeln('<polyline id="wire-${_xml(wire.id.value)}" '
          'data-from="${_xml(wire.fromTerminalId.value)}" '
          'data-to="${_xml(wire.toTerminalId.value)}" '
          'points="${route.map((p) => '${_n(p.dx)},${_n(p.dy)}').join(' ')}"/>');
    }
    svg.writeln('</g>');

    final models = <String, String>{
      for (final source in circuit.sources) source.id.value: source.modelType,
      for (final item in circuit.components) item.id.value: item.modelType,
    };
    final terminals = <String, List<Terminal>>{
      for (final source in circuit.sources) source.id.value: source.terminals,
      for (final item in circuit.components) item.id.value: item.terminals,
    };
    for (final id in ids) {
      final center = layout.positionOf(id)!;
      final type = models[id]!;
      final ports = terminals[id]!;
      final anchors = IndustrialSchematicProjection.anchors(type, ports.length);
      final glyph = IndustrialSchematicProjection.glyphFor(type);
      final halfWidth = layout.sizeOf(id).width / 2 - 20;
      svg.writeln('<g id="device-${_xml(id)}" data-model="${_xml(type)}" '
          'data-reference="${_xml(refs.labelOf(id))}" '
          'transform="translate(${_n(center.dx)},${_n(center.dy)}) '
          'rotate(${layout.quarterTurnsOf(id) * 90})" '
          'stroke="black" stroke-width="1.6" fill="none">');

      if (glyph == SchematicGlyph.motor ||
          glyph == SchematicGlyph.lamp ||
          glyph == SchematicGlyph.source) {
        svg.writeln('<circle r="22" cx="0" cy="0"/>');
        final mark = glyph == SchematicGlyph.motor ? 'M'
            : glyph == SchematicGlyph.lamp ? 'X'
            : type.contains('ac') ? '~' : '+';
        svg.writeln('<text x="0" y="6" text-anchor="middle" stroke="none" '
            'fill="black" font-size="20">${_xml(mark)}</text>');
      } else if (glyph == SchematicGlyph.contact && ports.length == 2) {
        svg.writeln('<path d="M ${_n(-halfWidth)} 0 H -16 M 16 0 H ${_n(halfWidth)}"/>');
        svg.writeln('<circle cx="-16" cy="0" r="2"/><circle cx="16" cy="0" r="2"/>');
        svg.writeln(IndustrialSchematicReferences.normallyClosed(type)
            ? '<path d="M -16 0 H 16"/>'
            : '<path d="M -16 0 L 12 -17"/>');
      } else {
        svg.writeln('<rect x="${_n(-halfWidth)}" y="-27" '
            'width="${_n(halfWidth * 2)}" height="54" fill="white"/>');
        svg.writeln('<text x="0" y="5" text-anchor="middle" '
            'stroke="none" fill="black" font-size="10">${_xml(type)}</text>');
      }
      for (var i = 0; i < ports.length; i++) {
        final anchor = anchors[i];
        final edgeX = anchor.dy == 0 ? anchor.dx.sign * halfWidth : anchor.dx;
        final edgeY = anchor.dy == 0 ? 0.0 : anchor.dy.sign * 27.0;
        svg.writeln('<line x1="${_n(anchor.dx)}" y1="${_n(anchor.dy)}" '
            'x2="${_n(edgeX)}" y2="${_n(edgeY)}"/>');
        svg.writeln('<circle data-terminal-id="${_xml(ports[i].id.value)}" '
            'cx="${_n(anchor.dx)}" cy="${_n(anchor.dy)}" r="3" fill="white"/>');
        svg.writeln('<text x="${_n(anchor.dx + 7)}" y="${_n(anchor.dy - 9)}" '
            'stroke="none" fill="black" font-size="9">${_xml(ports[i].name)}</text>');
      }
      svg.writeln('<text x="0" y="-67" text-anchor="middle" stroke="none" '
          'fill="black" font-size="12">${_xml(refs.labelOf(id))}</text>');
      final link = refs.controllingLabelFor(id);
      if (link != null) {
        svg.writeln('<text x="0" y="73" text-anchor="middle" '
            'stroke="none" fill="black" font-size="10">↔ ${_xml(link)}</text>');
      }
      svg.writeln('</g>');
    }
    svg.writeln('</svg>');
    return svg.toString();
  }

  static String _n(num value) => value.toStringAsFixed(2);
  static String _xml(String input) => input
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&apos;');
}
