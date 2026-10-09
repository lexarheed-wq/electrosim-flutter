import 'package:electrosim_canvas/electrosim_canvas.dart';
import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:flutter/material.dart';
import 'f18_component_asset_visual.dart';

/// Restore the shared physical gabarits without altering saved electrical IDs,
/// positions or rotations. Old paths must be rerouted around the new envelopes.
CircuitVisualLayout migrateIndustrialPhysicalLayout(
  CircuitState circuit,
  CircuitVisualLayout layout,
) {
  final sizes = <String, Size>{...layout.elementSizes};
  bool changed = false;
  for (final component in circuit.components) {
    final type =
        (component.parameters['_visualModelType'] as String?) ??
        component.modelType;
    if (type != 'motor_3p_6t' && type != 'lamp') continue;
    final size = F18ReferenceComponentMetrics.boardSizeFor(type);
    if (layout.sizeOf(component.id.value) == size) continue;
    sizes[component.id.value] = size;
    changed = true;
  }
  if (!changed) return layout;
  return CircuitVisualLayout(
    elementPositions: layout.elementPositions,
    elementSizes: sizes,
    elementQuarterTurns: layout.elementQuarterTurns,
    defaultElementSize: layout.defaultElementSize,
    cabinetLayout: layout.cabinetLayout,
  );
}
