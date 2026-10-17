import 'package:electrosim_canvas/electrosim_canvas.dart';
import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:electrosim_multiphysics/electrosim_multiphysics.dart';
import 'package:electrosim_storage/electrosim_storage.dart';
import 'package:electrosim/mixed_board_projection.dart';
import 'package:electrosim/runtime/electrosim_layout_persistence.dart';
import 'package:flutter_test/flutter_test.dart';

CircuitState _circuit(ElectricalMode mode) => CircuitState(
  circuitId: CircuitId('same-circuit'), revision: 0, mode: mode,
  components: <ComponentInstance>[ComponentInstance(
    id: ComponentId('same-component'), modelType: 'resistor',
    terminals: <Terminal>[
      Terminal(id: TerminalId('terminal-a'), name: 'A'),
      Terminal(id: TerminalId('terminal-b'), name: 'B'),
    ], parameters: const <String, Object?>{'resistanceOhm': 100},
  )],
);

ElectricalProject _project() => ElectricalProject(networks: <ElectricalNetwork>[
  ElectricalNetwork(id: 'dc', circuit: _circuit(ElectricalMode.dc)),
  ElectricalNetwork(id: 'ac', circuit: _circuit(ElectricalMode.ac1)),
]);

void main() {
  test('empty mixed board has all four solver domains with safe defaults', () {
    final project = ElectricalProject.emptyMixedBoard();
    expect(project.networks.map((network) => network.circuit.mode), containsAll(<ElectricalMode>[
      ElectricalMode.dc, ElectricalMode.ac1, ElectricalMode.ac3, ElectricalMode.pv,
    ]));
    expect(project.networks.firstWhere((network) => network.circuit.mode == ElectricalMode.ac1)
        .circuit.settings['frequencyHz'], 50.0);
    expect(project.networks.firstWhere((network) => network.circuit.mode == ElectricalMode.pv)
        .circuit.settings['irradianceWm2'], 1000.0);
  });

  test('mixed project serialization preserves domains and shared board layout', () {
    final project = _project();
    final layout = MixedBoardProjection.combineLayouts(project, <String, CircuitVisualLayout>{
      'dc': CircuitVisualLayout(elementPositions: <String, Offset>{'same-component': const Offset(20, 30)}),
      'ac': CircuitVisualLayout(elementPositions: <String, Offset>{'same-component': const Offset(40, 50)}),
    });
    final now = DateTime.utc(2026, 10, 17);
    final document = SavedElectricalProjectDocument(
      saveId: 'mixed-roundtrip', title: 'Mixed roundtrip',
      createdAtUtc: now, updatedAtUtc: now,
      engineVersion: 'test', project: project,
      appState: <String, Object?>{'layouts': <String, Object?>{
        '__mixed_board__': ElectroSimLayoutPersistence.encode(layout),
      }},
    );
    final restored = SavedElectricalProjectDocument.fromJsonString(document.toJsonString());
    expect(restored.project.toJson(), project.toJson());
    expect(restored.appState['layouts'], isNotEmpty);
  });
  test('namespaces colliding local identities and maps them to their networks', () {
    final projection = MixedBoardProjection.fromProject(_project());
    expect(projection.circuit.components, hasLength(2));
    expect(projection.circuit.components.map((c) => c.id.value).toSet(), hasLength(2));
    for (final component in projection.circuit.components) {
      expect(projection.componentOrigins[component.id.value]?.networkId, isNotNull);
    }
    expect(projection.circuit.mode, isNot(ElectricalMode.mixed));
  });

  test('board edits route back to the selected homogeneous network', () {
    final project = _project();
    final projection = MixedBoardProjection.fromProject(project);
    final edited = CircuitState(
      circuitId: projection.circuit.circuitId,
      revision: 1,
      mode: projection.circuit.mode,
      components: <ComponentInstance>[
        ...projection.circuit.components,
        ComponentInstance(
          id: ComponentId('new-ac-device'), modelType: 'resistor',
          terminals: <Terminal>[
            Terminal(id: TerminalId('new-ac-a'), name: 'A'),
            Terminal(id: TerminalId('new-ac-b'), name: 'B'),
          ], parameters: const <String, Object?>{'resistanceOhm': 200},
        ),
      ],
    );

    final next = MixedBoardProjection.applyBoardEdit(project, edited, 'ac');
    expect(next.networks.first.circuit.mode, ElectricalMode.dc);
    expect(next.networks.first.circuit.components, hasLength(1));
    expect(next.networks.last.circuit.mode, ElectricalMode.ac1);
    expect(next.networks.last.circuit.components, hasLength(2));
    expect(next.networks.last.circuit.components.last.id.value, 'new-ac-device');
    expect(next.networks.last.circuit.components.first.id.value, 'same-component');
  });

  test('rejects a conductive wire between domains', () {
    final project = _project();
    final board = MixedBoardProjection.fromProject(project).circuit;
    final edited = CircuitState(
      circuitId: board.circuitId, revision: 1, mode: board.mode,
      components: board.components,
      connections: <Connection>[Connection(
        id: ConnectionId('cross-domain-wire'),
        fromTerminalId: TerminalId('n0--terminal-a'),
        toTerminalId: TerminalId('n1--terminal-a'),
      )],
      sources: board.sources,
    );
    expect(
      () => MixedBoardProjection.applyBoardEdit(project, edited, 'dc'),
      throwsA(isA<StateError>()),
    );
  });

  test('combines legacy layouts into namespaced, non-overlapping slots', () {
    final project = _project();
    final layout = MixedBoardProjection.combineLayouts(project, <String, CircuitVisualLayout>{
      'dc': CircuitVisualLayout(elementPositions: <String, Offset>{'same-component': Offset.zero}),
      'ac': CircuitVisualLayout(elementPositions: <String, Offset>{'same-component': Offset.zero}),
    });
    expect(layout.elementPositions['n0--same-component'], const Offset(96, 96));
    expect(layout.elementPositions['n1--same-component'], const Offset(1496, 96));
  });
}
