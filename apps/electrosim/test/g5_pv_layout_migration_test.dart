import 'package:electrosim/f18_physical_layout_migration.dart';
import 'package:electrosim_canvas/electrosim_canvas.dart';
import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final circuit = CircuitState(
    circuitId: CircuitId('saved-pv'),
    revision: 4,
    mode: ElectricalMode.pv,
    components: [
      ComponentInstance(
        id: ComponentId('B1'),
        modelType: 'pv_battery',
        terminals: [
          Terminal(id: TerminalId('B1-p'), name: '+'),
          Terminal(id: TerminalId('B1-n'), name: '-'),
        ],
      ),
      ComponentInstance(
        id: ComponentId('R1'),
        modelType: 'resistor',
        terminals: [
          Terminal(id: TerminalId('R1-p'), name: '+'),
          Terminal(id: TerminalId('R1-n'), name: '-'),
        ],
      ),
    ],
    connections: [
      Connection(
        id: ConnectionId('W1'),
        fromTerminalId: TerminalId('B1-p'),
        toTerminalId: TerminalId('R1-p'),
      ),
    ],
  );
  final cabinet = CabinetLayout([
    CabinetFixture(
      id: 'rail',
      kind: CabinetFixtureKind.dinRail,
      bounds: const Rect.fromLTWH(20, 80, 300, 34),
    ),
  ]);
  CircuitVisualLayout layout({
    Map<String, Offset> anchors = const {},
    Map<String, List<Offset>> routes = const {},
  }) => CircuitVisualLayout(
    elementPositions: const {'B1': Offset(400, 250), 'R1': Offset(700, 400)},
    elementSizes: const {'B1': Size(210, 170), 'R1': Size(100, 80)},
    cabinetLayout: cabinet,
    terminalAnchorOffsets: anchors,
    wireRoutes: routes,
  );
  test(
    'saved battery wire with obsolete bottom route is invalidated without changing topology',
    () {
      final before = circuit.toJsonString();
      final old = layout(
        routes: const {
          'W1': [Offset(364.3, 400)],
          'unrelated': [Offset(10, 20)],
        },
      );
      final migrated = migrateIndustrialPhysicalLayout(circuit, old);
      expect(migrated.routeFor('W1'), isEmpty);
      expect(migrated.routeFor('unrelated'), old.routeFor('unrelated'));
      expect(migrated.cabinetLayout, same(cabinet));
      expect(migrated.elementPositions, old.elementPositions);
      expect(circuit.toJsonString(), before);
      expect(
        migrateIndustrialPhysicalLayout(circuit, migrated),
        same(migrated),
      );
    },
  );
  test('only recognized legacy PV overrides are removed', () {
    final old = layout(
      anchors: const {
        'B1-p': Offset(-35.7, 71.4),
        'B1-n': Offset(40, -70),
        'R1-p': Offset(-22, 5),
      },
    );
    final migrated = migrateIndustrialPhysicalLayout(circuit, old);
    expect(migrated.terminalAnchorOffsets.containsKey('B1-p'), isFalse);
    expect(migrated.terminalAnchorOffsets['B1-n'], const Offset(40, -70));
    expect(migrated.terminalAnchorOffsets['R1-p'], const Offset(-22, 5));
    expect(migrated.cabinetLayout, same(cabinet));
  });
  test('unchanged custom physical layouts remain identical', () {
    final old = layout(anchors: const {'B1-p': Offset(-74, -68)});
    expect(migrateIndustrialPhysicalLayout(circuit, old), same(old));
  });
  test('motor size migration retains rails and unrelated manual anchors', () {
    final motor = CircuitState(
      circuitId: CircuitId('motor'),
      revision: 0,
      mode: ElectricalMode.ac3,
      components: [
        ComponentInstance(
          id: ComponentId('M1'),
          modelType: 'motor_3p_6t',
          terminals: [],
        ),
      ],
    );
    final old = CircuitVisualLayout(
      elementPositions: const {'M1': Offset(400, 250)},
      elementSizes: const {'M1': Size(260, 240)},
      cabinetLayout: cabinet,
      terminalAnchorOffsets: const {'other-terminal': Offset(12, 5)},
    );
    final migrated = migrateIndustrialPhysicalLayout(motor, old);
    expect(migrated.cabinetLayout, same(cabinet));
    expect(migrated.terminalAnchorOffsets, old.terminalAnchorOffsets);
  });
}
