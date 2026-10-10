import 'package:electrosim/industrial_schematic_references.dart';
import 'package:electrosim/industrial_workspace_representation.dart';
import 'package:electrosim_canvas/electrosim_canvas.dart';
import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/industrial_fixture.dart';

void main() {
  test('P3 cross-reference links auxiliary NO to its real contactor coil', () {
    final circuit = buildIndustrialSelfHoldCircuit(
      startPressed: false,
      stopPressed: false,
    );
    final before = circuit.toJsonString();
    final references = IndustrialSchematicReferences.build(circuit);

    expect(references.controllingLabelFor('aux'), 'k1');
    expect(references.contactsFor('k1'), ['aux']);
    expect(references.labelOf('motor'), 'motor');
    expect(references.issues, isEmpty);
    expect(circuit.toJsonString(), before);
  });

  test('P3 contacts have truthful resting NO and NC representations', () {
    expect(
      IndustrialSchematicReferences.normallyClosed('push_button_nc'),
      isTrue,
    );
    expect(
      IndustrialSchematicReferences.normallyClosed('contactor_aux_nc'),
      isTrue,
    );
    expect(
      IndustrialSchematicReferences.normallyClosed('relay_contact_nc'),
      isTrue,
    );
    expect(
      IndustrialSchematicReferences.normallyClosed('contactor_aux_no'),
      isFalse,
    );
    expect(
      IndustrialSchematicReferences.normallyClosed('push_button_no'),
      isFalse,
    );
  });

  test('P3 duplicate references are reported, not silently renumbered', () {
    Terminal terminal(String id) =>
        Terminal(id: TerminalId(id), name: id, role: TerminalRole.generic);
    ComponentInstance item(String id, String reference) => ComponentInstance(
      id: ComponentId(id),
      modelType: 'resistor',
      terminals: [terminal('$id-1'), terminal('$id-2')],
      parameters: {'industrialReference': reference},
    );
    final circuit = CircuitState(
      circuitId: CircuitId('p3-duplicate'),
      revision: 0,
      mode: ElectricalMode.dc,
      components: [item('b', 'R1'), item('a', 'R1')],
    );
    final index = IndustrialSchematicReferences.build(circuit);
    expect(index.labelOf('a'), 'R1');
    expect(index.labelOf('b'), 'R1');
    expect(index.issues, hasLength(1));
    expect(
      index.issues.single.kind,
      SchematicReferenceIssueKind.duplicateReference,
    );
    expect(index.issues.single.elementId, 'b');
  });

  test('P3 orphaned auxiliary contact is not assigned an invented coil', () {
    final circuit = buildIndustrialSelfHoldCircuit(
      startPressed: false,
      stopPressed: false,
    );
    final aux = circuit.components.singleWhere((c) => c.id.value == 'aux');
    final orphan = ComponentInstance(
      id: aux.id,
      modelType: aux.modelType,
      terminals: aux.terminals,
      parameters: const {'linkedContactorId': 'unknown'},
    );
    final modified = CircuitState(
      circuitId: circuit.circuitId,
      revision: circuit.revision,
      mode: circuit.mode,
      sources: circuit.sources,
      components: [
        for (final item in circuit.components)
          if (item.id.value == 'aux') orphan else item,
      ],
      connections: circuit.connections,
      settings: circuit.settings,
      metadata: circuit.metadata,
    );
    final index = IndustrialSchematicReferences.build(modified);
    expect(index.controllingLabelFor('aux'), isNull);
    expect(
      index.issues.single.kind,
      SchematicReferenceIssueKind.unknownLinkedCoil,
    );
  });

  test('P3 projection stays identical under insertion order changes', () {
    final authored = buildIndustrialSelfHoldCircuit(
      startPressed: false,
      stopPressed: false,
    );
    final reversed = CircuitState(
      circuitId: authored.circuitId,
      revision: authored.revision,
      mode: authored.mode,
      components: authored.components.reversed.toList(),
      sources: authored.sources.reversed.toList(),
      connections: authored.connections.reversed.toList(),
      instruments: authored.instruments,
      probes: authored.probes,
      settings: authored.settings,
      metadata: authored.metadata,
    );
    final positions = <String, Offset>{};
    for (final item in authored.sources) {
      positions[item.id.value] = const Offset(120, 180);
    }
    for (final item in authored.components) {
      positions[item.id.value] = const Offset(120, 180);
    }
    final plate = CircuitVisualLayout(elementPositions: positions);
    final before = authored.toJsonString();
    final a = IndustrialSchematicProjection.derive(authored, plate);
    final b = IndustrialSchematicProjection.derive(reversed, plate);
    expect(a.elementPositions, b.elementPositions);
    expect(a.terminalAnchorOffsets, b.terminalAnchorOffsets);
    expect(a.wireRoutes.keys.toSet(), b.wireRoutes.keys.toSet());
    for (final id in a.wireRoutes.keys) {
      expect(a.wireRoutes[id], b.wireRoutes[id], reason: id);
    }
    expect(authored.toJsonString(), before);
    expect(plate.wireRoutes, isEmpty);
    expect(plate.elementPositions, positions);
  });
  test('P3 relay contacts cross-reference canonical linkedRelayId', () {
    Terminal port(String id, String name) =>
        Terminal(id: TerminalId(id), name: name);
    final circuit = CircuitState(
      circuitId: CircuitId('relay-cross-reference'),
      revision: 0,
      mode: ElectricalMode.dc,
      components: [
        ComponentInstance(
          id: ComponentId('k1'),
          modelType: 'relay_coil',
          terminals: [port('coil-A1', 'A1'), port('coil-A2', 'A2')],
          parameters: const {'industrialReference': 'KA1'},
        ),
        ComponentInstance(
          id: ComponentId('aux'),
          modelType: 'relay_contact_nc',
          terminals: [port('aux-21', '21'), port('aux-22', '22')],
          parameters: const {
            'linkedRelayId': 'k1',
            'industrialReference': 'KA1:21-22',
          },
        ),
      ],
    );
    final original = circuit.toJsonString();
    final refs = IndustrialSchematicReferences.build(circuit);
    expect(refs.controllingLabelFor('aux'), 'KA1');
    expect(refs.contactsFor('k1'), ['aux']);
    expect(
      IndustrialSchematicReferences.normallyClosed('relay_contact_nc'),
      isTrue,
    );
    expect(refs.issues, isEmpty);
    expect(circuit.toJsonString(), original);
  });
}
