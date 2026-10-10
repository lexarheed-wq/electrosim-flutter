import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:electrosim_electropneumatic/electrosim_electropneumatic.dart';
import 'package:electrosim_multiphysics/electrosim_multiphysics.dart';
import 'package:electrosim_pneumatic_domain/electrosim_pneumatic_domain.dart';
import 'package:test/test.dart';

Terminal t(String id) => Terminal(id: TerminalId(id), name: id);

ComponentInstance contact(
  String id,
  String type,
  String a,
  String b, {
  Map<String, Object?> state = const <String, Object?>{},
}) => ComponentInstance(
  id: ComponentId(id),
  modelType: type,
  terminals: <Terminal>[t(a), t(b)],
  controlState: state,
);

ComponentInstance winding(String id, String a, String b, double resistance) =>
    ComponentInstance(
      id: ComponentId(id),
      modelType: 'resistor',
      terminals: <Terminal>[t(a), t(b)],
      parameters: <String, Object?>{'resistanceOhm': resistance},
    );

Connection wire(String id, String a, String b) => Connection(
  id: ConnectionId(id),
  fromTerminalId: TerminalId(a),
  toTerminalId: TerminalId(b),
);

CircuitState electrical({double supplyV = 24}) => CircuitState(
  circuitId: CircuitId('r3-k1-self-hold'),
  revision: 0,
  mode: ElectricalMode.dc,
  components: <ComponentInstance>[
    contact(
      's1',
      'switch',
      's1a',
      's1b',
      state: <String, Object?>{'closed': false},
    ),
    contact(
      'k1-contact',
      'relay_contact_no',
      'k1a',
      'k1b',
      state: <String, Object?>{'actuated': false},
    ),
    contact(
      'b1',
      'relay_contact_nc',
      'b1a',
      'b1b',
      state: <String, Object?>{'actuated': false},
    ),
    winding('k1-winding', 'k1c', 'k1d', 480),
    winding('y1', 'y1a', 'y1b', 240),
  ],
  connections: <Connection>[
    wire('w1', 'vp', 's1a'),
    wire('w2', 'vp', 'k1a'),
    wire('w3', 's1b', 'b1a'),
    wire('w4', 'k1b', 'b1a'),
    wire('w5', 'b1b', 'k1c'),
    wire('w6', 'b1b', 'y1a'),
    wire('w7', 'k1d', 'vn'),
    wire('w8', 'y1b', 'vn'),
  ],
  sources: <SourceInstance>[
    SourceInstance(
      id: SourceId('supply'),
      modelType: 'dc_voltage_source',
      terminals: <Terminal>[
        Terminal(
          id: TerminalId('vp'),
          name: '+',
          role: TerminalRole.positive,
          phase: PhaseTag.dcPositive,
        ),
        Terminal(
          id: TerminalId('vn'),
          name: '-',
          role: TerminalRole.negative,
          phase: PhaseTag.dcNegative,
        ),
      ],
      parameters: <String, Object?>{'voltageV': supplyV},
    ),
  ],
);

ElectropneumaticLink y1Link() => ElectropneumaticLink(
  id: 'y1-to-valve',
  electricalComponentId: 'y1',
  pneumaticDeviceId: 'valve',
  role: ElectropneumaticLinkRole.solenoidCoil,
);

MultiphysicsProject project({double supplyV = 24}) => MultiphysicsProject(
  electricalCircuit: electrical(supplyV: supplyV),
  pneumaticNetwork: PneumaticNetwork(
    devices: <PneumaticDevice>[
      PneumaticDevice(
        id: 'valve',
        kind: PneumaticDeviceKind.valve52,
        ports: <PneumaticPort>[
          PneumaticPort(
            id: PneumaticPortId('valve.P'),
            deviceId: 'valve',
            role: PneumaticPortRole.supply,
          ),
        ],
      ),
      PneumaticDevice(
        id: 'cylinder',
        kind: PneumaticDeviceKind.doubleActingCylinder,
        ports: <PneumaticPort>[
          PneumaticPort(
            id: PneumaticPortId('cylinder.A'),
            deviceId: 'cylinder',
            role: PneumaticPortRole.work,
          ),
          PneumaticPort(
            id: PneumaticPortId('cylinder.B'),
            deviceId: 'cylinder',
            role: PneumaticPortRole.work,
          ),
        ],
      ),
    ],
  ),
  devices: <PhysicalDeviceRecord>[
    PhysicalDeviceRecord(
      id: 'valve-body',
      pneumaticDeviceId: 'valve',
      electricalComponentIds: <String>['y1'],
    ),
    PhysicalDeviceRecord(
      id: 'cylinder-body',
      pneumaticDeviceId: 'cylinder',
      electricalComponentIds: <String>['b1'],
    ),
  ],
  links: <ElectropneumaticLink>[
    y1Link(),
    ElectropneumaticLink(
      id: 'b1-to-cylinder',
      electricalComponentId: 'b1',
      pneumaticDeviceId: 'cylinder',
      role: ElectropneumaticLinkRole.positionContact,
    ),
  ],
);

SelfHold24vElectricalCycle bench({double supplyV = 24}) =>
    SelfHold24vElectricalCycle(
      project: project(supplyV: supplyV),
      binding: SelfHold24vBinding(
        startComponentId: 's1',
        holdContactComponentId: 'k1-contact',
        endStopComponentId: 'b1',
        relayWindingComponentId: 'k1-winding',
        valveSolenoidLink: y1Link(),
      ),
    );

void main() {
  group('CPL-01: S1 NO parallel K1 NO, B1 NC, K1 and Y1 windings', () {
    test('brief start pulse holds K1/Y1 until physical B1 NC opens', () {
      final SelfHold24vElectricalCycle controller = bench();
      final SelfHold24vSnapshot idle = controller.settle(
        timeS: 0,
        startPressed: false,
        endStopActuated: false,
      );
      expect(idle.relay.energized, false);
      expect(idle.valveReading.voltageV, closeTo(0, 1e-9));

      final SelfHold24vSnapshot start = controller.settle(
        timeS: .1,
        startPressed: true,
        endStopActuated: false,
        previousRelay: idle.relay,
      );
      expect(start.relay.energized, true);
      expect(start.valveReading.voltageV, closeTo(24, 1e-9));
      expect(start.valveReading.currentA, closeTo(.1, 1e-9));
      expect(start.relayVoltageV, closeTo(24, 1e-9));
      expect(start.electricalIterations, greaterThanOrEqualTo(2));

      final SelfHold24vSnapshot released = controller.settle(
        timeS: .2,
        startPressed: false,
        endStopActuated: false,
        previousRelay: start.relay,
      );
      expect(released.relay.energized, true);
      expect(released.valveReading.currentA, closeTo(.1, 1e-9));

      final SelfHold24vSnapshot limit = controller.settle(
        timeS: .3,
        startPressed: false,
        endStopActuated: true,
        previousRelay: released.relay,
      );
      expect(limit.relay.energized, false);
      expect(limit.valveReading.voltageV, closeTo(0, 1e-9));
      expect(limit.valveReading.currentA, 0);
      expect(limit.electricalIterations, greaterThanOrEqualTo(2));

      final SelfHold24vSnapshot reset = controller.settle(
        timeS: .4,
        startPressed: false,
        endStopActuated: false,
        previousRelay: limit.relay,
      );
      expect(reset.relay.energized, false);
      expect(reset.valveReading.voltageV, closeTo(0, 1e-9));
      expect(reset.startPressed, false);
    });

    test('held S1 can restart after B1 NC resets (no false one-shot)', () {
      final SelfHold24vElectricalCycle controller = bench();
      final SelfHold24vSnapshot stopped = controller.settle(
        timeS: 1,
        startPressed: true,
        endStopActuated: true,
      );
      expect(stopped.relay.energized, false);
      expect(stopped.valveReading.voltageV, closeTo(0, 1e-9));

      final SelfHold24vSnapshot restarted = controller.settle(
        timeS: 1.1,
        startPressed: true,
        endStopActuated: false,
        previousRelay: stopped.relay,
      );
      expect(restarted.relay.energized, true);
      expect(restarted.valveReading.voltageV, closeTo(24, 1e-9));
    });

    test('24 V source off drops relay and both physical windings', () {
      final SelfHold24vElectricalCycle powered = bench();
      final SelfHold24vSnapshot latched = powered.settle(
        timeS: .1,
        startPressed: true,
        endStopActuated: false,
      );
      final SelfHold24vSnapshot cut = bench(supplyV: 0).settle(
        timeS: .2,
        startPressed: false,
        endStopActuated: false,
        previousRelay: latched.relay,
      );
      expect(cut.relay.energized, false);
      expect(cut.relayVoltageV, closeTo(0, 1e-9));
      expect(cut.valveReading.voltageV, closeTo(0, 1e-9));
    });

    test('DC project source and relay source circuits never mutate', () {
      final SelfHold24vElectricalCycle controller = bench();
      final String unchanged =
          controller.project.electricalCircuit.toJsonString();
      controller.settle(
        timeS: .1,
        startPressed: true,
        endStopActuated: false,
      );
      expect(
        controller.project.electricalCircuit.toJsonString(),
        unchanged,
      );
    });
  });
}
