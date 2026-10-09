import 'package:electrosim/f18_physical_layout_migration.dart';
import 'package:electrosim/f18_component_asset_visual.dart';
import 'package:electrosim_canvas/electrosim_canvas.dart';
import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final circuit = CircuitState(
    circuitId: CircuitId('legacy'),
    revision: 3,
    mode: ElectricalMode.ac3,
    components: [
      ComponentInstance(
        id: ComponentId('M1'),
        modelType: 'motor_3p_6t',
        terminals: [],
      ),
      ComponentInstance(
        id: ComponentId('H1'),
        modelType: 'lamp',
        terminals: [],
      ),
    ],
  );
  test(
    'legacy motor/lamp layouts retain placement but invalidate old wire routes',
    () {
      final old = CircuitVisualLayout(
        elementPositions: const {
          'M1': Offset(300, 200),
          'H1': Offset(750, 300),
        },
        elementSizes: const {'M1': Size(260, 240), 'H1': Size(130, 160)},
        elementQuarterTurns: const {'M1': 1},
        wireRoutes: const {
          'wire-1': [Offset(220, 120), Offset(600, 120)],
        },
      );
      final migrated = migrateIndustrialPhysicalLayout(circuit, old);
      expect(
        migrated.sizeOf('M1'),
        F18ReferenceComponentMetrics.boardSizeFor('motor_3p_6t'),
      );
      expect(
        migrated.sizeOf('H1'),
        F18ReferenceComponentMetrics.boardSizeFor('lamp'),
      );
      expect(migrated.elementPositions, old.elementPositions);
      expect(migrated.elementQuarterTurns, old.elementQuarterTurns);
      expect(migrated.wireRoutes, isEmpty);
      expect(circuit.revision, 3);
      expect(
        migrateIndustrialPhysicalLayout(circuit, migrated),
        same(migrated),
      );
    },
  );
}
