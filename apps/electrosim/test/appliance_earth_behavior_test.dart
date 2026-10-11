import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:electrosim/runtime/electrosim_runtime_engine.dart';
import 'package:flutter_test/flutter_test.dart';

CircuitState earthCircuit({bool earthConnected = true, bool fault = false}) {
  Terminal t(String id) => Terminal(id: TerminalId(id), name: id);
  Connection w(String id, String a, String b) => Connection(
    id: ConnectionId(id),
    fromTerminalId: TerminalId(a),
    toTerminalId: TerminalId(b),
  );
  var c = CircuitState(
    circuitId: CircuitId('earth-demo'),
    revision: 0,
    mode: ElectricalMode.ac1,
    sources: [
      SourceInstance(
        id: SourceId('s'),
        modelType: 'ac_voltage_source',
        terminals: [t('sl'), t('sn')],
        parameters: {'voltageRmsV': 230.0},
      ),
    ],
    components: [
      ComponentInstance(
        id: ComponentId('rcd'),
        modelType: 'rcd_2p_ac1',
        terminals: [t('nin'), t('lin'), t('nout'), t('lout')],
        parameters: {
          ProtectionRating.ratedCurrentKey: 16.0,
          'residualTripCurrentA': .03,
        },
        controlState: {'closed': true},
      ),
      ComponentInstance(
        id: ComponentId('socket'),
        modelType: 'power_socket_ac',
        terminals: [t('li'), t('ni'), t('pei'), t('lo'), t('no'), t('peo')],
      ),
      ComponentInstance(
        id: ComponentId('load'),
        modelType: 'impedance',
        terminals: [t('load-l'), t('load-n')],
        parameters: {
          '_visualModelType': 'catalog_appliance_2t',
          '_visualVariant': 'refrigerator',
          'resistanceOhm': 100.0,
          'reactanceOhm': 0.0,
        },
      ),
    ],
    connections: [
      w('feed-l', 'sl', 'lin'),
      w('feed-n', 'sn', 'nin'),
      w('socket-l', 'lout', 'li'),
      w('socket-n', 'nout', 'ni'),
      if (earthConnected) w('tn-bond', 'sn', 'pei'),
    ],
    settings: {'frequencyHz': 50.0},
  );
  c = AppliancePowerConnection.addProtectiveEarth(c);
  c = AppliancePowerConnection.configure(c, 'load', 'plug', socketId: 'socket');
  return AppliancePowerConnection.setInsulationFault(c, 'load', fault);
}

void main() {
  const engine = ElectroSimRuntimeEngine();
  test(
    'class I adds isolated chassis contact without changing existing L/N IDs',
    () {
      final c = earthCircuit();
      final load = c.components.last;
      expect(load.terminals.map((t) => t.id.value), [
        'load-l',
        'load-n',
        'load:chassis-pe',
      ]);
      expect(load.terminals.last.role, TerminalRole.protectiveEarth);
      expect(
        c.connections
            .where(
              (w) => w.metadata[AppliancePowerConnection.cableTag] == 'load',
            )
            .length,
        3,
      );
      expect(AppliancePowerConnection.addProtectiveEarth(c), same(c));
      final normal = engine.advance(c, elapsed: const Duration(seconds: 1));
      expect(normal.protectionTripped(ComponentId('rcd')), isFalse);
      expect(
        normal.ac1Result!.branchResults
            .firstWhere((b) => b.id == 'component:load')
            .current!
            .magnitude,
        closeTo(2.3, 1e-8),
      );
    },
  );
  test('230 V / 1 kΩ earth fault produces 230 mA then trips 30 mA RCD', () {
    final c = earthCircuit(fault: true);
    final initial = engine.evaluate(c);
    final branch = initial.ac1Result!.branchResults.firstWhere(
      (b) => b.id == 'component:earth-fault:load',
    );
    expect(branch.current!.magnitude, closeTo(.23, 1e-8));
    final tripped = engine.advance(
      c,
      elapsed: const Duration(milliseconds: 50),
    );
    expect(tripped.protectionTripped(ComponentId('rcd')), isTrue);
    expect(c.components.last.controlState['insulationFault'], isTrue);
    expect(c.components.length, 3); // synthetic leakage stays runtime-only
  });
  test(
    'broken PE does not invent earth return current or a protective trip',
    () {
      final c = earthCircuit(earthConnected: false, fault: true);
      final result = engine.advance(c, elapsed: const Duration(seconds: 1));
      expect(result.protectionTripped(ComponentId('rcd')), isFalse);
      final fault = result.ac1Result!.branchResults.firstWhere(
        (b) => b.id == 'component:earth-fault:load',
      );
      expect(fault.current!.magnitude, closeTo(0, 1e-8));
      final peNode =
          result.topology.terminalToNode[TerminalId('load:chassis-pe')];
      final neutralNode = result.topology.terminalToNode[TerminalId('sn')];
      expect(
        (result.ac1Result!.nodeVoltages[peNode]! -
                result.ac1Result!.nodeVoltages[neutralNode]!)
            .magnitude,
        closeTo(230, 1e-8),
      );
    },
  );
  test(
    'unplug disconnects L, N and PE together without removing supply wiring',
    () {
      final c = earthCircuit(fault: true);
      final unplugged = AppliancePowerConnection.configure(c, 'load', 'plug');
      expect(unplugged.connections.length, c.connections.length - 3);
      final result = engine.advance(
        unplugged,
        elapsed: const Duration(seconds: 1),
      );
      expect(result.protectionTripped(ComponentId('rcd')), isFalse);
    },
  );
}
