import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:test/test.dart';

ComponentInstance appliance({
  String id = 'load',
  String model = 'resistor',
  String visual = 'catalog_appliance_2t',
  String variant = 'iron',
  String? protection,
  int poles = 2,
  Map<String, Object?> extra = const {},
  Map<String, Object?> controls = const {},
}) => ComponentInstance(
  id: ComponentId(id),
  modelType: model,
  terminals: List.generate(
    poles,
    (i) => Terminal(id: TerminalId('$id:$i'), name: '$i'),
  ),
  parameters: {
    '_visualModelType': visual,
    '_visualVariant': variant,
    if (protection != null) 'protectionClass': protection,
    ...extra,
  },
  controlState: controls,
);
ComponentInstance socket(String id, {bool dc = false}) => ComponentInstance(
  id: ComponentId(id),
  modelType: dc ? 'power_socket_dc' : 'power_socket_ac',
  terminals: List.generate(
    dc ? 4 : 6,
    (i) => Terminal(
      id: TerminalId('$id:$i'),
      name: '$i',
      role: !dc && i % 3 == 2
          ? TerminalRole.protectiveEarth
          : TerminalRole.generic,
    ),
  ),
);
CircuitState circuit(
  List<ComponentInstance> components, [
  List<Connection> wires = const [],
]) => CircuitState(
  circuitId: CircuitId('physical'),
  revision: 4,
  mode: ElectricalMode.ac1,
  components: components,
  connections: wires,
  metadata: const {'author': 'unchanged'},
);
Connection wire(
  String id,
  String a,
  String b, {
  Map<String, Object?> metadata = const {},
}) => Connection(
  id: ConnectionId(id),
  fromTerminalId: TerminalId(a),
  toTerminalId: TerminalId(b),
  metadata: metadata,
);

void main() {
  for (final model in ['resistor', 'impedance', 'motor_3p_6t']) {
    test(
      'PE migration preserves authored graph for $model and is idempotent',
      () {
        final load = appliance(
          model: model,
          poles: model == 'motor_3p_6t' ? 6 : 2,
        );
        final original = circuit(
          [load, socket('s')],
          [wire('fixed', 'load:0', 's:0')],
        );
        final migrated = AppliancePowerConnection.addProtectiveEarth(original);
        final changed = migrated.components.first;
        expect(changed.terminals.take(load.terminals.length), load.terminals);
        expect(changed.terminals.last.role, TerminalRole.protectiveEarth);
        expect(changed.parameters['originalElectricalModelType'], model);
        expect(
          changed.modelType,
          model == 'motor_3p_6t' ? 'earthed_machine_3p_7t' : 'earthed_$model',
        );
        expect(migrated.connections, original.connections);
        expect(migrated.revision, 5);
        expect(
          identical(
            AppliancePowerConnection.addProtectiveEarth(migrated),
            migrated,
          ),
          isTrue,
        );
        expect(original.components.first, load);
      },
    );
  }
  for (final variant in [
    'iron',
    'television',
    'refrigerator-dc',
    'solar-pump',
  ]) {
    for (final protection in [null, 'I', 'II', 'III']) {
      test('PE eligibility $variant class $protection', () {
        final input = circuit([
          appliance(variant: variant, protection: protection),
        ]);
        final eligible =
            !['refrigerator-dc', 'solar-pump'].contains(variant) &&
            protection != 'II' &&
            protection != 'III' &&
            (variant != 'television' || protection == 'I');
        final output = AppliancePowerConnection.addProtectiveEarth(input);
        expect(output.components.first.terminals.length, eligible ? 3 : 2);
        if (!eligible) expect(identical(input, output), isTrue);
      });
    }
  }
  test('PE terminal allocation avoids existing IDs without changing them', () {
    final other = ComponentInstance(
      id: ComponentId('other'),
      modelType: 'resistor',
      terminals: [
        Terminal(id: TerminalId('load:chassis-pe'), name: 'A'),
        Terminal(id: TerminalId('load:chassis-pe:2'), name: 'B'),
      ],
    );
    final result = AppliancePowerConnection.addProtectiveEarth(
      circuit([appliance(), other]),
    );
    expect(
      result.components.first.terminals.last.id.value,
      'load:chassis-pe:3',
    );
    expect(result.components.last, other);
  });
  test('unplugged / A / B / unplugged / fixed preserves unrelated graph', () {
    final original = AppliancePowerConnection.addProtectiveEarth(
      circuit(
        [appliance(), socket('a'), socket('b')],
        [for (var i = 0; i < 3; i++) wire('third:$i', 'a:$i', 'b:$i')],
      ),
    );
    var state = AppliancePowerConnection.configure(original, 'load', 'plug');
    expect(state.connections, original.connections);
    for (final target in ['a', 'b']) {
      state = AppliancePowerConnection.configure(
        state,
        'load',
        'plug',
        socketId: target,
      );
      expect(state.connections.take(3), original.connections);
      final cable = state.connections.skip(3).toList();
      expect(cable, hasLength(3));
      for (var i = 0; i < 3; i++) {
        expect(cable[i].id.value, 'power-cable:load:$i');
        expect(cable[i].fromTerminalId.value, '$target:${i + 3}');
        expect(
          cable[i].toTerminalId,
          original.components.first.terminals[i].id,
        );
      }
    }
    state = AppliancePowerConnection.configure(state, 'load', 'plug');
    expect(state.connections, original.connections);
    state = AppliancePowerConnection.configure(state, 'load', 'fixed');
    expect(state.connections, original.connections);
    expect(
      state.components.map((c) => c.id),
      original.components.map((c) => c.id),
    );
    expect(state.metadata, original.metadata);
    expect(original.connections, hasLength(3));
  });
  test(
    'fixed wires, occupied sockets and cable ID collisions refuse mutation',
    () {
      for (final obstruction in [
        wire('fixed', 'load:0', 'a:0'),
        wire('occupied', 'a:0', 'a:3', metadata: {'powerSocketId': 'a'}),
        wire('power-cable:load:0', 'a:0', 'a:3'),
      ]) {
        final original = circuit([appliance(), socket('a')], [obstruction]);
        expect(
          () => AppliancePowerConnection.configure(
            original,
            'load',
            'plug',
            socketId: 'a',
          ),
          throwsArgumentError,
        );
        expect(original.connections.single, obstruction);
      }
    },
  );
  test('connector type and terminal-only motors refuse incompatible modes', () {
    final ac = circuit([appliance(), socket('dc', dc: true)]);
    expect(
      () => AppliancePowerConnection.configure(ac, 'load', 'dc'),
      throwsArgumentError,
    );
    expect(
      () => AppliancePowerConnection.configure(
        ac,
        'load',
        'plug',
        socketId: 'dc',
      ),
      throwsArgumentError,
    );
    expect(
      () => AppliancePowerConnection.configure(
        ac,
        'load',
        'fixed',
        socketId: 'dc',
      ),
      throwsArgumentError,
    );
    expect(
      () => AppliancePowerConnection.configure(ac, 'load', 'unknown'),
      throwsArgumentError,
    );
    final motor = circuit([appliance(model: 'motor_3p_6t', poles: 6)]);
    expect(
      () => AppliancePowerConnection.configure(motor, 'load', 'plug'),
      throwsArgumentError,
    );
    final bare = circuit([appliance(model: 'motor_dc', visual: 'motor_dc')]);
    expect(
      () => AppliancePowerConnection.configure(bare, 'load', 'fixed'),
      throwsArgumentError,
    );
    final dc = CircuitState(
      circuitId: CircuitId('dc-physical'),
      revision: 4,
      mode: ElectricalMode.dc,
      components: [
        appliance(variant: 'solar-pump'),
        socket('dc', dc: true),
      ],
    );
    expect(
      AppliancePowerConnection.configure(
        dc,
        'load',
        'dc',
        socketId: 'dc',
      ).connections,
      hasLength(2),
    );
    expect(
      () => AppliancePowerConnection.configure(dc, 'load', 'plug'),
      throwsArgumentError,
    );
  });
  test(
    'runtime insulation fault is a single line-to-chassis resistor, author intact',
    () {
      final original = AppliancePowerConnection.addProtectiveEarth(
        circuit([
          appliance(extra: {'insulationFaultResistanceOhm': 2200}),
        ]),
      );
      final enabled = AppliancePowerConnection.setInsulationFault(
        original,
        'load',
        true,
      );
      final projected = AppliancePowerConnection.projectInsulationFaults(
        enabled,
      );
      expect(projected.components, hasLength(2));
      expect(projected.components.first, enabled.components.first);
      expect(projected.components.last.parameters['resistanceOhm'], 2200.0);
      expect(projected.connections.map((w) => w.fromTerminalId), [
        enabled.components.first.terminals.first.id,
        enabled.components.first.terminals.last.id,
      ]);
      expect(
        projected.connections.map((w) => w.toTerminalId),
        projected.components.last.terminals.map((t) => t.id),
      );
      expect(enabled.connections, isEmpty);
      expect(projected.revision, enabled.revision);
      expect(
        () => AppliancePowerConnection.projectInsulationFaults(projected),
        throwsArgumentError,
      );
      final disabled = AppliancePowerConnection.setInsulationFault(
        enabled,
        'load',
        false,
      );
      expect(
        identical(
          AppliancePowerConnection.projectInsulationFaults(disabled),
          disabled,
        ),
        isTrue,
      );
      expect(
        () => AppliancePowerConnection.setInsulationFault(
          circuit([appliance()]),
          'load',
          true,
        ),
        throwsArgumentError,
      );
    },
  );
  for (final value in [null, 0, -1, double.infinity, double.nan, 'invalid']) {
    test('insulation resistance contract for $value', () {
      if (value is num && !value.isFinite) {
        expect(
          () => appliance(extra: {'insulationFaultResistanceOhm': value}),
          throwsA(isA<DomainException>()),
        );
        return;
      }
      final input = AppliancePowerConnection.addProtectiveEarth(
        circuit([
          appliance(
            extra: {'insulationFaultResistanceOhm': value},
            controls: {'insulationFault': true},
          ),
        ]),
      );
      if (value == null) {
        expect(
          AppliancePowerConnection.projectInsulationFaults(
            input,
          ).components.last.parameters['resistanceOhm'],
          1000.0,
        );
      } else {
        expect(
          () => AppliancePowerConnection.projectInsulationFaults(input),
          throwsArgumentError,
        );
      }
      expect(input.connections, isEmpty);
    });
  }
}
