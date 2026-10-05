import 'package:electrosim/runtime/electrosim_simulation_controller.dart';
import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'simulation controller advances thermal protection by explicit time',
    () {
      final CircuitState circuit = _ac3ThermalCircuit();
      final ElectroSimSimulationController controller =
          ElectroSimSimulationController(circuit: circuit);

      controller.advance(const Duration(seconds: 60));
      expect(
        controller
            .snapshot
            .protectionState![ComponentId('rt1')]!
            .exposure
            .exposure,
        closeTo(0.5, 1e-7),
      );
      expect(
        controller.snapshot.protectionTripped(ComponentId('rt1')),
        isFalse,
      );

      controller.advance(const Duration(seconds: 60));
      expect(controller.snapshot.protectionTripped(ComponentId('rt1')), isTrue);
      expect(controller.simulatedTime, const Duration(seconds: 120));

      controller.dispose();
    },
  );

  test(
    'simulation controller preserves contactor hold across circuit updates',
    () {
      final ElectroSimSimulationController controller =
          ElectroSimSimulationController(
            circuit: _selfHoldCircuit(startPressed: true),
          );

      expect(controller.snapshot.contactorActuated(ComponentId('k1')), isTrue);

      controller.updateCircuit(_selfHoldCircuit(startPressed: false));

      expect(controller.snapshot.contactorActuated(ComponentId('k1')), isTrue);
      expect(
        controller.snapshot.ac1.branch('component:load').current!.magnitude,
        closeTo(5.0, 1e-8),
      );

      controller.dispose();
    },
  );

  test('reset clears dynamic time and protection state', () {
    final ElectroSimSimulationController controller =
        ElectroSimSimulationController(circuit: _ac3ThermalCircuit());

    controller.advance(const Duration(seconds: 60));
    expect(controller.simulatedTime, const Duration(seconds: 60));

    controller.resetDynamics();

    expect(controller.simulatedTime, Duration.zero);
    expect(controller.snapshot.protectionTripped(ComponentId('rt1')), isFalse);

    controller.dispose();
  });
}

CircuitState _selfHoldCircuit({required bool startPressed}) => CircuitState(
  circuitId: CircuitId('clock-self-hold'),
  revision: startPressed ? 1 : 2,
  mode: ElectricalMode.ac1,
  components: <ComponentInstance>[
    ComponentInstance(
      id: ComponentId('stop'),
      modelType: 'push_button_nc',
      terminals: <Terminal>[
        _t('stop-in', '21', phase: PhaseTag.l1),
        _t('stop-out', '22', phase: PhaseTag.l1),
      ],
      controlState: const <String, Object?>{'pressed': false},
    ),
    ComponentInstance(
      id: ComponentId('start'),
      modelType: 'push_button_no',
      terminals: <Terminal>[
        _t('start-in', '13', phase: PhaseTag.l1),
        _t('start-out', '14', phase: PhaseTag.l1),
      ],
      controlState: <String, Object?>{'pressed': startPressed},
    ),
    ComponentInstance(
      id: ComponentId('hold'),
      modelType: 'contactor_aux_no',
      terminals: <Terminal>[
        _t('hold-in', '13', phase: PhaseTag.l1),
        _t('hold-out', '14', phase: PhaseTag.l1),
      ],
      parameters: const <String, Object?>{'linkedContactorId': 'k1'},
    ),
    ComponentInstance(
      id: ComponentId('k1'),
      modelType: 'contactor_ac1',
      terminals: <Terminal>[
        _t('k1-in', '1', phase: PhaseTag.l1),
        _t('k1-out', '2', phase: PhaseTag.l1),
        _t('k1-a1', 'A1', role: TerminalRole.coilA1, phase: PhaseTag.l1),
        _t('k1-a2', 'A2', role: TerminalRole.coilA2, phase: PhaseTag.neutral),
      ],
      parameters: const <String, Object?>{
        'coilResistanceOhm': 1000.0,
        'coilPickupVoltageV': 180.0,
        'coilDropoutVoltageV': 100.0,
      },
      controlState: const <String, Object?>{'actuated': false},
    ),
    _resistor('load', PhaseTag.l1, 46.0),
  ],
  connections: <Connection>[
    _w('c1', 'v-l', 'stop-in'),
    _w('c2', 'stop-out', 'start-in'),
    _w('c3', 'stop-out', 'hold-in'),
    _w('c4', 'start-out', 'k1-a1'),
    _w('c5', 'hold-out', 'k1-a1'),
    _w('c6', 'k1-a2', 'v-n'),
    _w('p1', 'v-l', 'k1-in'),
    _w('p2', 'k1-out', 'load-p'),
    _w('p3', 'load-n', 'v-n'),
  ],
  sources: <SourceInstance>[_ac1Source()],
  settings: const <String, Object?>{'frequencyHz': 50.0},
);

CircuitState _ac3ThermalCircuit() => CircuitState(
  circuitId: CircuitId('clock-thermal'),
  revision: 1,
  mode: ElectricalMode.ac3,
  components: <ComponentInstance>[
    ComponentInstance(
      id: ComponentId('rt1'),
      modelType: 'thermal_overload_3p',
      terminals: <Terminal>[
        _t('rt-l1-in', '1L1', phase: PhaseTag.l1),
        _t('rt-l2-in', '3L2', phase: PhaseTag.l2),
        _t('rt-l3-in', '5L3', phase: PhaseTag.l3),
        _t('rt-l1-out', '2T1', phase: PhaseTag.l1),
        _t('rt-l2-out', '4T2', phase: PhaseTag.l2),
        _t('rt-l3-out', '6T3', phase: PhaseTag.l3),
      ],
      parameters: <String, Object?>{ProtectionRating.ratedCurrentKey: 5.0},
      controlState: const <String, Object?>{'closed': true, 'tripped': false},
    ),
    _resistor('r1', PhaseTag.l1, 23.0),
    _resistor('r2', PhaseTag.l2, 23.0),
    _resistor('r3', PhaseTag.l3, 23.0),
  ],
  connections: <Connection>[
    _w('p1', 'v1-p', 'rt-l1-in'),
    _w('p2', 'v2-p', 'rt-l2-in'),
    _w('p3', 'v3-p', 'rt-l3-in'),
    _w('o1', 'rt-l1-out', 'r1-p'),
    _w('o2', 'rt-l2-out', 'r2-p'),
    _w('o3', 'rt-l3-out', 'r3-p'),
    _w('n1', 'r1-n', 'v1-n'),
    _w('n2', 'r2-n', 'v1-n'),
    _w('n3', 'r3-n', 'v1-n'),
    _w('ns2', 'v2-n', 'v1-n'),
    _w('ns3', 'v3-n', 'v1-n'),
  ],
  sources: <SourceInstance>[
    _phaseSource('v1', PhaseTag.l1),
    _phaseSource('v2', PhaseTag.l2),
    _phaseSource('v3', PhaseTag.l3),
  ],
  settings: const <String, Object?>{'frequencyHz': 50.0},
);

ComponentInstance _resistor(String id, PhaseTag phase, double resistance) =>
    ComponentInstance(
      id: ComponentId(id),
      modelType: 'resistor',
      terminals: <Terminal>[
        _t('$id-p', 'L', phase: phase),
        _t('$id-n', 'N', phase: PhaseTag.neutral),
      ],
      parameters: <String, Object?>{'resistanceOhm': resistance},
    );

SourceInstance _ac1Source() => SourceInstance(
  id: SourceId('v'),
  modelType: 'ac_voltage_source',
  terminals: <Terminal>[
    _t('v-l', 'L', phase: PhaseTag.l1),
    _t('v-n', 'N', phase: PhaseTag.neutral),
  ],
  parameters: const <String, Object?>{'voltageRmsV': 230.0},
);

SourceInstance _phaseSource(String id, PhaseTag phase) => SourceInstance(
  id: SourceId(id),
  modelType: 'ac_voltage_source',
  terminals: <Terminal>[
    _t('$id-p', phase.name, phase: phase),
    _t('$id-n', 'N', phase: PhaseTag.neutral),
  ],
  parameters: const <String, Object?>{'voltageRmsV': 230.0},
);

Connection _w(String id, String from, String to) => Connection(
  id: ConnectionId(id),
  fromTerminalId: TerminalId(from),
  toTerminalId: TerminalId(to),
);

Terminal _t(
  String id,
  String name, {
  TerminalRole role = TerminalRole.generic,
  PhaseTag phase = PhaseTag.none,
}) => Terminal(id: TerminalId(id), name: name, role: role, phase: phase);
