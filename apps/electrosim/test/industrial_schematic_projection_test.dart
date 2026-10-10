import 'package:electrosim/industrial_workspace_representation.dart';
import 'package:electrosim/f9_component_palette.dart';
import 'package:electrosim_canvas/electrosim_canvas.dart';
import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('adjacent devices never share schematic hit targets', () {
    List<Terminal> terminals(String id) => [
      Terminal(id: TerminalId('$id-a'), name: '1', role: TerminalRole.input),
      Terminal(id: TerminalId('$id-b'), name: '2', role: TerminalRole.output),
    ];
    final circuit = CircuitState(
      circuitId: CircuitId('dense-symbols'),
      revision: 1,
      mode: ElectricalMode.dc,
      components: [
        ComponentInstance(
          id: ComponentId('a'),
          modelType: 'switch',
          terminals: terminals('a'),
        ),
        ComponentInstance(
          id: ComponentId('b'),
          modelType: 'breaker_dc',
          terminals: terminals('b'),
        ),
      ],
      sources: const [],
      connections: const [],
    );
    final author = CircuitVisualLayout(
      elementPositions: const {'a': Offset.zero, 'b': Offset(120, 0)},
      elementSizes: const {'a': Size(90, 140), 'b': Size(72, 160)},
    );
    final projected = IndustrialSchematicProjection.derive(circuit, author);
    final ports = CircuitGeometryIndex.build(
      circuit,
      projected,
    ).terminalPositions;
    expect(ports.values.toSet().length, 4);
    expect(author.positionOf('b'), const Offset(120, 0));
  });
  test(
    'every catalogue model keeps all terminal IDs across four rotations',
    () {
      for (final definition in f9PaletteCatalog.where(
        (d) => d.kind != F9PaletteElementKind.instrument,
      )) {
        final terminals = [
          for (var i = 0; i < definition.terminalCount; i++)
            Terminal(
              id: TerminalId('p-$i'),
              name: definition.terminals.isEmpty
                  ? definition.terminalLabels[i]
                  : definition.terminals[i].label,
              role: TerminalRole.generic,
              phase: PhaseTag.none,
            ),
        ];
        final circuit = CircuitState(
          circuitId: CircuitId('symbol-test'),
          revision: 1,
          mode: ElectricalMode.dc,
          components: [
            ComponentInstance(
              id: ComponentId('device'),
              modelType: definition.modelType,
              terminals: terminals,
            ),
          ],
          sources: const [],
          connections: const [],
        );
        for (var turn = 0; turn < 4; turn++) {
          final author = CircuitVisualLayout(
            elementPositions: const {'device': Offset(400, 400)},
            elementSizes: const {'device': Size(230, 170)},
            elementQuarterTurns: {'device': turn},
          );
          final projected = IndustrialSchematicProjection.derive(
            circuit,
            author,
          );
          final geometry = CircuitGeometryIndex.build(circuit, projected);
          expect(
            geometry.terminalPositions.keys.toSet(),
            terminals.map((t) => t.id).toSet(),
            reason: definition.keyName,
          );
          expect(
            geometry.terminalPositions.values.toSet().length,
            terminals.length,
            reason: definition.keyName,
          );
          final session = const HitTestEngine().prepare(
            circuit: circuit,
            layout: projected,
          );
          for (final port in geometry.terminalPositions.entries) {
            expect(
              const HitTestEngine()
                  .hitTestPrepared(worldPoint: port.value, session: session)
                  .terminalId,
              port.key,
              reason: '${definition.keyName} rotation$turn',
            );
          }
          expect(author.terminalAnchorOffsets, isEmpty);
          expect(projected.cabinetLayout.fixtures, isEmpty);
        }
      }
    },
  );
  test(
    'schematic painter explicitly uses white without cabinet/instrument layers',
    () {
      final circuit = CircuitState(
        circuitId: CircuitId('white'),
        revision: 1,
        mode: ElectricalMode.dc,
        components: const [],
        sources: const [],
        connections: const [],
      );
      final viewport = ViewportController();
      addTearDown(viewport.dispose);
      final painter = CircuitScenePainter(
        circuit: circuit,
        layout: CircuitVisualLayout(elementPositions: const {}),
        viewport: viewport,
        paintElementChrome: false,
        schematicPresentation: true,
      );
      expect(painter.backgroundColor, Colors.white);
      expect(
        IndustrialSchematicProjection.glyphFor('load_wye_3p'),
        SchematicGlyph.load,
      );
      expect(
        IndustrialSchematicProjection.glyphFor('motor_3p_6t'),
        SchematicGlyph.motor,
      );
      expect(
        IndustrialSchematicProjection.glyphFor('contactor_3p'),
        SchematicGlyph.contact,
      );
    },
  );
}
