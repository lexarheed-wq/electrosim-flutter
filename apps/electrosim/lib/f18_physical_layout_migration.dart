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

/// Only crusher routes are repaired; other authored routes/placements survive.
CircuitVisualLayout migrateCrusherPhysicalLayout(
  CircuitState circuit,
  CircuitVisualLayout layout, {
  required CircuitWireLayoutEngine router,
}) {
  layout = repairNativeMotorBridgeRoutes(circuit, layout);
  final ports = <TerminalId>{};
  final anchors = {...layout.terminalAnchorOffsets};
  var changed = false;
  for (final c in circuit.components) {
    if (c.parameters['_visualModelType'] != 'catalog_motor_driven_6t' ||
        c.parameters['_visualVariant'] != 'crusher') {
      continue;
    }
    ports.addAll(c.terminals.map((t) => t.id));
    final size = layout.sizeOf(c.id.value);
    for (var i = 0; i < c.terminals.length; i++) {
      final id = c.terminals[i].id.value;
      final old = anchors[id];
      final legacy = i == 6
          ? Offset(-size.width * .38, 0)
          : Offset(
              size.width * ([-.2, 0, .2][i % 3]),
              size.height * (i < 3 ? -.42 : .42),
            );
      if (old != null && (old - legacy).distance < .001) {
        anchors.remove(id);
        changed = true;
      }
    }
  }
  if (ports.isEmpty) return layout;
  CircuitVisualLayout copy(Map<String, List<Offset>> routes) =>
      CircuitVisualLayout(
        elementPositions: layout.elementPositions,
        elementSizes: layout.elementSizes,
        elementQuarterTurns: layout.elementQuarterTurns,
        defaultElementSize: layout.defaultElementSize,
        cabinetLayout: layout.cabinetLayout,
        terminalAnchorOffsets: anchors,
        wireRoutes: routes,
      );
  var current = copy(layout.wireRoutes);
  final geometry = CircuitGeometryIndex.build(circuit, current);
  for (final w in circuit.connections) {
    if (!ports.contains(w.fromTerminalId) && !ports.contains(w.toTerminalId)) {
      continue;
    }
    final start = geometry.terminalPositions[w.fromTerminalId];
    final end = geometry.terminalPositions[w.toTerminalId];
    if (start == null || end == null) continue;
    if (ports.contains(w.fromTerminalId) &&
        ports.contains(w.toTerminalId) &&
        geometry.terminalOwners[w.fromTerminalId] ==
            geometry.terminalOwners[w.toTerminalId]) {
      final local =
          (start.dx - end.dx).abs() < .001 || (start.dy - end.dy).abs() < .001
          ? <Offset>[]
          : <Offset>[Offset(end.dx, start.dy)];
      final old = current.routeFor(w.id.value);
      if (old.length != local.length ||
          List.generate(
            local.length,
            (i) => old[i] != local[i],
          ).any((x) => x)) {
        current = copy({...current.wireRoutes, w.id.value: local});
        changed = true;
      }
      continue;
    }
    final points = [start, ...current.routeFor(w.id.value), end];
    final diagonal = List.generate(
      points.length - 1,
      (i) => points[i + 1] - points[i],
    ).any((d) => d.dx.abs() > .001 && d.dy.abs() > .001);
    if (diagonal) {
      current = router.routeConnection(
        circuit: circuit,
        layout: current,
        connectionId: w.id,
      );
      changed = true;
    }
  }
  // Fan upper winding leads above the row before leaving the enclosure.
  // A straight downward stub would visually pass through the lower studs.
  for (final c in circuit.components) {
    if (c.parameters['_visualModelType'] != 'catalog_motor_driven_6t' ||
        c.parameters['_visualVariant'] != 'crusher') {
      continue;
    }
    final size = layout.sizeOf(c.id.value);
    Offset delta(double x, double y) {
      var p = Offset(x * size.width / 240, y * size.height / 220);
      for (var q = 0; q < layout.quarterTurnsOf(c.id.value); q++) {
        p = Offset(-p.dy, p.dx);
      }
      return p;
    }

    for (var i = 0; i < 3 && i < c.terminals.length; i++) {
      final id = c.terminals[i].id;
      if (anchors.containsKey(id.value)) continue;
      final p = geometry.terminalPositions[id];
      if (p == null) continue;
      final up = p + delta(0, -6 - 4.0 * i);
      final side = delta(-8 - 14.0 * i, 0);
      for (final wire in circuit.connections) {
        final from = wire.fromTerminalId == id;
        final to = wire.toTerminalId == id;
        if (!from && !to) continue;
        if (geometry.terminalOwners[wire.fromTerminalId] ==
            geometry.terminalOwners[wire.toTerminalId]) {
          continue;
        }
        final route = current.routeFor(wire.id.value);
        if (route.isEmpty) continue;
        final dock = from ? route.first : route.last;
        if ((dock - up).distance < .001) continue;
        final fan = [dock + side, up + side, up];
        final next = from
            ? [...fan.reversed, ...route.skip(1)]
            : [...route.take(route.length - 1), ...fan];
        current = copy({...current.wireRoutes, wire.id.value: next});
        changed = true;
      }
    }
  }
  return changed ? current : layout;
}

/// Repair saved star/delta links without rerouting unrelated external wires.
CircuitVisualLayout repairNativeMotorBridgeRoutes(
  CircuitState circuit,
  CircuitVisualLayout layout,
) {
  final motors = <String, Set<TerminalId>>{
    for (final c in circuit.components)
      if ((c.modelType == 'motor_3p_6t' ||
              c.modelType == 'earthed_machine_3p_7t') &&
          (c.parameters['_visualModelType'] != 'catalog_motor_driven_6t' ||
              c.parameters['_visualVariant'] == 'crusher'))
        c.id.value: c.terminals.take(6).map((t) => t.id).toSet(),
  };
  if (motors.isEmpty) return layout;
  final g = CircuitGeometryIndex.build(circuit, layout);
  final routes = {...layout.wireRoutes};
  var changed = false;
  for (final w in circuit.connections) {
    final owner = g.terminalOwners[w.fromTerminalId];
    final ports = motors[owner];
    if (ports == null ||
        owner != g.terminalOwners[w.toTerminalId] ||
        !ports.contains(w.fromTerminalId) ||
        !ports.contains(w.toTerminalId)) {
      continue;
    }
    final a = g.terminalPositions[w.fromTerminalId];
    final b = g.terminalPositions[w.toTerminalId];
    if (a == null || b == null) continue;
    final local = (a.dx - b.dx).abs() < .001 || (a.dy - b.dy).abs() < .001
        ? <Offset>[]
        : [Offset(b.dx, a.dy)];
    final old = layout.routeFor(w.id.value);
    if (old.length == local.length &&
        List.generate(
          local.length,
          (i) => local[i] == old[i],
        ).every((v) => v)) {
      continue;
    }
    routes[w.id.value] = local;
    changed = true;
  }
  return !changed
      ? layout
      : CircuitVisualLayout(
          elementPositions: layout.elementPositions,
          elementSizes: layout.elementSizes,
          wireRoutes: routes,
          elementQuarterTurns: layout.elementQuarterTurns,
          defaultElementSize: layout.defaultElementSize,
          cabinetLayout: layout.cabinetLayout,
          terminalAnchorOffsets: layout.terminalAnchorOffsets,
        );
}
