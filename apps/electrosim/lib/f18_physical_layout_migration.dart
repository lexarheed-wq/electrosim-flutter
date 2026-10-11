import 'package:electrosim_canvas/electrosim_canvas.dart';
import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:flutter/material.dart';
import 'f18_component_asset_visual.dart';

/// Restore physical presentation only. Keep electrical IDs, user placements,
/// cabinet fixtures and custom anchors; discard routes incompatible with ports.
CircuitVisualLayout migrateIndustrialPhysicalLayout(
  CircuitState circuit,
  CircuitVisualLayout layout,
) {
  final sizes = <String, Size>{...layout.elementSizes};
  final anchors = <String, Offset>{...layout.terminalAnchorOffsets};
  final pvTerminals = <TerminalId>{};
  bool resized = false, changed = false;
  for (final component in circuit.components) {
    final type =
        (component.parameters['_visualModelType'] as String?) ??
        component.modelType;
    if (type == 'motor_3p_6t' || type == 'lamp') {
      final size = F18ReferenceComponentMetrics.boardSizeFor(type);
      if (layout.sizeOf(component.id.value) != size) {
        sizes[component.id.value] = size;
        resized = changed = true;
      }
    }
    if (type != 'pv_controller' && type != 'pv_battery') continue;
    final size = layout.sizeOf(component.id.value);
    final count = type == 'pv_controller' ? 4 : 2;
    if (component.terminals.length != count) continue;
    for (var i = 0; i < count; i++) {
      final terminal = component.terminals[i].id;
      pvTerminals.add(terminal);
      final saved = anchors[terminal.value];
      if (saved == null) continue;
      final legacy = type == 'pv_battery'
          ? Offset(size.width * (i == 0 ? -.17 : .17), size.height * .42)
          : Offset(
              size.width * (i.isEven ? -.19 : .19),
              size.height * (i < 2 ? -.42 : .42),
            );
      if ((saved - legacy).distance < .001) {
        anchors.remove(terminal.value);
        changed = true;
      }
    }
  }
  CircuitVisualLayout copy(Map<String, List<Offset>> routes) =>
      CircuitVisualLayout(
        elementPositions: layout.elementPositions,
        elementSizes: sizes,
        elementQuarterTurns: layout.elementQuarterTurns,
        defaultElementSize: layout.defaultElementSize,
        cabinetLayout: layout.cabinetLayout,
        terminalAnchorOffsets: anchors,
        wireRoutes: routes,
      );
  final routes = resized
      ? <String, List<Offset>>{}
      : <String, List<Offset>>{...layout.wireRoutes};
  if (!resized && pvTerminals.isNotEmpty && routes.isNotEmpty) {
    final geometry = CircuitGeometryIndex.build(circuit, copy(routes));
    for (final connection in circuit.connections) {
      if (!pvTerminals.contains(connection.fromTerminalId) &&
          !pvTerminals.contains(connection.toTerminalId)) {
        continue;
      }
      final route = routes[connection.id.value];
      final start = geometry.terminalPositions[connection.fromTerminalId];
      final end = geometry.terminalPositions[connection.toTerminalId];
      if (route == null || route.isEmpty || start == null || end == null) {
        continue;
      }
      final points = [start, ...route, end];
      // Saved waypoints omit physical endpoints. An obsolete lower battery
      // connection would create a diagonal from its new upper lid terminal.
      final invalid = List.generate(
        points.length - 1,
        (i) => points[i + 1] - points[i],
      ).any((delta) => delta.dx.abs() > .001 && delta.dy.abs() > .001);
      if (invalid) {
        routes.remove(connection.id.value);
        changed = true;
      }
    }
  }
  return changed ? copy(routes) : layout;
}
