import 'package:electrosim/industrial_marking_registry.dart';
import 'package:electrosim/runtime/electrosim_runtime_engine.dart';
import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/industrial_fixture.dart';

void main() {
  CircuitState fixture() =>
      buildIndustrialSelfHoldCircuit(startPressed: false, stopPressed: false);

  test('P4 uses Q/F/KM/KA/S/H/M/X families without changing the graph', () {
    final circuit = fixture();
    final before = circuit.toJsonString();
    final plan = IndustrialMarkingRegistry.inspect(circuit);
    expect(plan.devices['k1'], 'KM1');
    expect(plan.devices['motor'], 'M1');
    expect(plan.devices['start'], 'S1');
    expect(plan.devices['stop'], 'S2');
    expect(plan.devices['aux'], 'KM1:13-14');
    expect(plan.devices['grid'], 'G1');
    expect(plan.terminals['k1-a1'], 'KM1:A1');
    expect(plan.terminals['m-u1'], 'M1:U1');
    expect(plan.conductors.values.toSet().length, circuit.connections.length);
    expect(plan.conductors.values, contains('001'));
    expect(
      plan.colors.values,
      everyElement(IndustrialConductorColor.unspecified),
    );
    expect(plan.issues, isEmpty);
    expect(circuit.toJsonString(), before);
  });

  test(
    'P4 allocation stable across reorder, graphical moves and new insert',
    () {
      final base = fixture();
      final stamped = IndustrialMarkingRegistry.materialize(base);
      expect(stamped.revision, base.revision + 1);
      expect(
        identical(IndustrialMarkingRegistry.materialize(stamped), stamped),
        isTrue,
      );
      final previous = IndustrialMarkingRegistry.inspect(stamped);
      final extra = ComponentInstance(
        id: ComponentId('0-new'),
        modelType: 'motor_dc',
        terminals: [
          Terminal(id: TerminalId('new-a'), name: 'A'),
          Terminal(id: TerminalId('new-b'), name: 'B'),
        ],
      );
      final changed = CircuitState(
        circuitId: stamped.circuitId,
        revision: stamped.revision + 1,
        mode: stamped.mode,
        sources: stamped.sources.reversed.toList(),
        components: [extra, ...stamped.components.reversed],
        connections: stamped.connections.reversed.toList(),
        settings: stamped.settings,
        metadata: stamped.metadata,
      );
      final later = IndustrialMarkingRegistry.inspect(changed);
      for (final id in previous.devices.keys) {
        expect(later.devices[id], previous.devices[id], reason: id);
      }
      for (final id in previous.conductors.keys) {
        expect(later.conductors[id], previous.conductors[id], reason: id);
      }
      expect(later.devices['0-new'], 'M2');
    },
  );

  test(
    'P4 teacher may rename and lock without modifying electrical physics',
    () {
      final original = fixture();
      final beforeJson = original.toJsonString();
      const runtime = ElectroSimRuntimeEngine();
      final baseline = runtime.evaluate(original);
      final renamed = IndustrialMarkingRegistry.setReference(
        original,
        kind: IndustrialMarkingKind.device,
        id: 'k1',
        reference: 'KM3',
        teacherAuthorized: true,
        locked: true,
      );
      final marked = IndustrialMarkingRegistry.inspect(renamed);
      expect(marked.devices['k1'], 'KM3');
      expect(marked.devices['aux'], 'KM3:13-14');
      expect(marked.terminals['k1-a1'], 'KM3:A1');
      expect(marked.locks['device:k1'], isTrue);
      expect(
        () => IndustrialMarkingRegistry.setReference(
          renamed,
          kind: IndustrialMarkingKind.device,
          id: 'k1',
          reference: 'KM4',
          teacherAuthorized: false,
        ),
        throwsStateError,
      );
      expect(
        () => IndustrialMarkingRegistry.setLock(
          renamed,
          kind: IndustrialMarkingKind.device,
          id: 'k1',
          locked: false,
          teacherAuthorized: false,
        ),
        throwsStateError,
      );
      final output = runtime.evaluate(renamed);
      expect(output.solverKind, baseline.solverKind);
      expect(output.solved, baseline.solved);
      expect(renamed.connections, original.connections);
      expect(renamed.components, original.components);
      expect(renamed.sources, original.sources);
      expect(original.toJsonString(), beforeJson);
      expect(
        CircuitState.fromJsonString(renamed.toJsonString()).metadata,
        renamed.metadata,
      );
    },
  );

  test('P4 detects teacher-entered duplicate references', () {
    final first = IndustrialMarkingRegistry.setReference(
      fixture(),
      kind: IndustrialMarkingKind.device,
      id: 'stop',
      reference: 'S1',
      teacherAuthorized: true,
    );
    final next = IndustrialMarkingRegistry.setReference(
      first,
      kind: IndustrialMarkingKind.device,
      id: 'start',
      reference: 'S1',
      teacherAuthorized: true,
    );
    final result = IndustrialMarkingRegistry.inspect(next);
    expect(result.devices['start'], 'S1');
    expect(result.devices['stop'], 'S1');
    expect(
      result.issues.any((issue) => issue.message.contains('Duplicate')),
      isTrue,
    );
  });

  test('P4 wire colors use explicit phase only, never inferred position', () {
    final original = fixture();
    final originalWire = original.connections.first;
    final neutral = Connection(
      id: originalWire.id,
      fromTerminalId: originalWire.fromTerminalId,
      toTerminalId: originalWire.toTerminalId,
      conductorType: originalWire.conductorType,
      phase: PhaseTag.neutral,
      enabled: originalWire.enabled,
      metadata: originalWire.metadata,
    );
    final tagged = CircuitState(
      circuitId: original.circuitId,
      revision: original.revision,
      mode: original.mode,
      sources: original.sources,
      components: original.components,
      connections: [neutral, ...original.connections.skip(1)],
      settings: original.settings,
    );
    final result = IndustrialMarkingRegistry.inspect(tagged);
    expect(result.colors[neutral.id.value], IndustrialConductorColor.blue);
    expect(
      result.colors[original.connections[1].id.value],
      IndustrialConductorColor.unspecified,
    );
  });  test('P4 manually locked terminal is stable after device rename', () {
    final first = IndustrialMarkingRegistry.setReference(
      fixture(),
      kind: IndustrialMarkingKind.terminal,
      id: 'k1-a1',
      reference: 'X7:01',
      teacherAuthorized: true,
      locked: true,
    );
    final renamed = IndustrialMarkingRegistry.setReference(
      first,
      kind: IndustrialMarkingKind.device,
      id: 'k1',
      reference: 'KM7',
      teacherAuthorized: true,
    );
    final marks = IndustrialMarkingRegistry.inspect(renamed);
    expect(marks.terminals['k1-a1'], 'X7:01');
    expect(marks.locks['terminal:k1-a1'], isTrue);
    expect(marks.terminals['k1-a2'], 'KM7:A2');
    expect(marks.devices['aux'], 'KM7:13-14');
    expect(IndustrialMarkingRegistry.materialize(renamed).connections,
        renamed.connections);
  });

  test('P4 marks fresh devices and conductors without renumbering existing', () {
    final initial = IndustrialMarkingRegistry.materialize(fixture());
    final old = IndustrialMarkingRegistry.inspect(initial);
    final extra = ComponentInstance(
      id: ComponentId('aaa-motor'),
      modelType: 'motor_3p_6t',
      terminals: [
        Terminal(id: TerminalId('new-u'), name: 'U1'),
        Terminal(id: TerminalId('new-v'), name: 'V1'),
      ],
    );
    final joined = Connection(
      id: ConnectionId('000-new-wire'),
      fromTerminalId: TerminalId('grid-l1'),
      toTerminalId: TerminalId('new-u'),
      phase: PhaseTag.l1,
    );
    final amended = CircuitState(
      circuitId: initial.circuitId,
      revision: initial.revision + 1,
      mode: initial.mode,
      components: [extra, ...initial.components],
      sources: initial.sources,
      connections: [joined, ...initial.connections],
      settings: initial.settings,
      metadata: initial.metadata,
    );
    final persisted = IndustrialMarkingRegistry.materialize(amended);
    final current = IndustrialMarkingRegistry.inspect(persisted);
    expect(current.devices['aaa-motor'], 'M2');
    expect(current.conductors['000-new-wire'],
        (initial.connections.length + 1).toString().padLeft(3, '0'));
    expect(current.colors['000-new-wire'], IndustrialConductorColor.brown);
    for (final key in old.devices.keys) {
      expect(current.devices[key], old.devices[key], reason: key);
    }
    for (final key in old.conductors.keys) {
      expect(current.conductors[key], old.conductors[key], reason: key);
    }
    expect(identical(IndustrialMarkingRegistry.materialize(persisted), persisted),
        isTrue);
  });

}
