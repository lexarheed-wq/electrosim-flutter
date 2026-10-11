import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:flutter_test/flutter_test.dart';

CircuitState fixture({bool dc = false, bool directlyWired = false}) {
  List<Terminal> terminals(String id, List<String> names) =>
      names.map((n) => Terminal(id: TerminalId('$id:$n'), name: n)).toList();
  return CircuitState(
    circuitId: CircuitId('plug-test'),
    revision: 0,
    mode: dc ? ElectricalMode.dc : ElectricalMode.ac1,
    components: [
      ComponentInstance(
        id: ComponentId('load'),
        modelType: dc ? 'resistor' : 'impedance',
        terminals: terminals('load', ['L', 'N']),
        parameters: {
          '_visualModelType': 'catalog_appliance_2t',
          '_visualVariant': dc ? 'refrigerator-dc' : 'television',
          'resistanceOhm': 100.0,
        },
      ),
      ComponentInstance(
        id: ComponentId('socket'),
        modelType: dc ? 'power_socket_dc' : 'power_socket_ac',
        terminals: terminals(
          'socket',
          dc
              ? ['positive-in', 'negative-in', 'positive-out', 'negative-out']
              : ['Lin', 'Nin', 'PEin', 'Lout', 'Nout', 'PEout'],
        ),
      ),
    ],
    connections: directlyWired
        ? [
            Connection(
              id: ConnectionId('legacy'),
              fromTerminalId: TerminalId('socket:Lin'),
              toTerminalId: TerminalId('load:L'),
            ),
          ]
        : [],
  );
}

void main() {
  test('earth migration preserves colliding legacy terminal IDs', () {
    final base = fixture();
    final data = base.toJson();
    final load = base.components.first.toJson();
    load['parameters'] = {
      ...base.components.first.parameters,
      '_visualVariant': 'refrigerator',
    };
    final other = ComponentInstance(
      id: ComponentId('aux'),
      modelType: 'resistor',
      terminals: [
        Terminal(id: TerminalId('load:chassis-pe'), name: 'legacy'),
        Terminal(id: TerminalId('aux-return'), name: 'return'),
      ],
      parameters: {'resistanceOhm': 100.0},
    );
    data['components'] = [load, base.components.last.toJson(), other.toJson()];
    final upgraded = AppliancePowerConnection.addProtectiveEarth(
      CircuitState.fromJson(data),
    );
    expect(
      upgraded.components.first.terminals.last.id,
      TerminalId('load:chassis-pe:2'),
    );
    expect(
      upgraded.components.last.terminals.first.id,
      TerminalId('load:chassis-pe'),
    );
  });
  test(
    'declared class II appliance never acquires a fictitious earth terminal',
    () {
      final base = fixture();
      final data = base.toJson();
      final load = base.components.first.toJson();
      load['parameters'] = {
        ...base.components.first.parameters,
        '_visualVariant': 'refrigerator',
        'protectionClass': 'II',
      };
      data['components'] = [load, base.components.last.toJson()];
      final c = CircuitState.fromJson(data);
      expect(AppliancePowerConnection.addProtectiveEarth(c), same(c));
    },
  );

  test(
    'plug connects independent conductors, unplug removes only its cable and persists',
    () {
      final base = fixture();
      final plugged = AppliancePowerConnection.configure(
        base,
        'load',
        'plug',
        socketId: 'socket',
      );
      expect(plugged.connections.length, 2);
      expect(plugged.connections[0].fromTerminalId, TerminalId('socket:Lout'));
      expect(plugged.connections[1].fromTerminalId, TerminalId('socket:Nout'));
      expect(
        plugged.components.first.terminals,
        base.components.first.terminals,
      );
      final restored = CircuitState.fromJsonString(plugged.toJsonString());
      expect(restored.connections, plugged.connections);
      final unplugged = AppliancePowerConnection.configure(
        restored,
        'load',
        'plug',
      );
      expect(unplugged.connections, isEmpty);
      expect(base.connections, isEmpty);
    },
  );
  test(
    'legacy wiring is preserved and conversion refuses a parallel bypass',
    () {
      final base = fixture(directlyWired: true);
      expect(
        () => AppliancePowerConnection.configure(
          base,
          'load',
          'plug',
          socketId: 'socket',
        ),
        throwsArgumentError,
      );
      expect(base.connections.single.id, ConnectionId('legacy'));
    },
  );
  test(
    'DC connector cannot be replaced with AC and motors retain winding terminals',
    () {
      final base = fixture(dc: true);
      expect(
        () => AppliancePowerConnection.configure(
          base,
          'load',
          'plug',
          socketId: 'socket',
        ),
        throwsArgumentError,
      );
      expect(
        AppliancePowerConnection.configure(
          base,
          'load',
          'dc',
          socketId: 'socket',
        ).connections.length,
        2,
      );
      final motor = ComponentInstance(
        id: ComponentId('motor'),
        modelType: 'motor_3p_6t',
        terminals: [],
      );
      expect(AppliancePowerConnection.isExternal(motor), isFalse);
    },
  );
  test('socket poles are feed-throughs and never connect L to N or PE', () {
    final c = CoreComponentModelContracts.registry.resolve('power_socket_ac')!;
    expect(c.terminalCount, 6);
    expect(
      c.branches.map((b) => '${b.fromTerminalIndex}:${b.toTerminalIndex}'),
      ['0:3', '1:4', '2:5'],
    );
    expect(CoreComponentPhysicsContracts.resolve('power_socket_ac'), isNotNull);
  });
}
