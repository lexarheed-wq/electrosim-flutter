
import 'package:electrosim/runtime/electrosim_runtime_engine.dart';
import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:test/test.dart';

void main() {
  test('runtime AC1 derives contactor actuation from real coil voltage', () {
    final CircuitState circuit = CircuitState(
      circuitId: CircuitId('runtime-contactor-ac1'),
      revision: 0,
      mode: ElectricalMode.ac1,
      components: <ComponentInstance>[
        ComponentInstance(
          id: ComponentId('k1'),
          modelType: 'contactor_ac1',
          terminals: <Terminal>[
            _t('k1-in', '1', phase: PhaseTag.l1),
            _t('k1-out', '2', phase: PhaseTag.l1),
            _t(
              'k1-a1',
              'A1',
              role: TerminalRole.coilA1,
              phase: PhaseTag.l1,
            ),
            _t(
              'k1-a2',
              'A2',
              role: TerminalRole.coilA2,
              phase: PhaseTag.neutral,
            ),
          ],
          parameters: const <String, Object?>{
            'coilResistanceOhm': 1000.0,
            'coilPickupVoltageV': 180.0,
            'coilDropoutVoltageV': 100.0,
          },
          controlState: const <String, Object?>{'actuated': false},
        ),
        ComponentInstance(
          id: ComponentId('r1'),
          modelType: 'resistor',
          terminals: <Terminal>[
            _t('r1-p', 'L', phase: PhaseTag.l1),
            _t('r1-n', 'N', phase: PhaseTag.neutral),
          ],
          parameters: const <String, Object?>{'resistanceOhm': 46.0},
        ),
      ],
      connections: <Connection>[
        _wire('w1', 'v-l', 'k1-in'),
        _wire('w2', 'k1-out', 'r1-p'),
        _wire('w3', 'r1-n', 'v-n'),
        _wire('w4', 'v-l', 'k1-a1'),
        _wire('w5', 'k1-a2', 'v-n'),
      ],
      sources: <SourceInstance>[
        SourceInstance(
          id: SourceId('v'),
          modelType: 'ac_voltage_source',
          terminals: <Terminal>[
            _t('v-l', 'L', phase: PhaseTag.l1),
            _t('v-n', 'N', phase: PhaseTag.neutral),
          ],
          parameters: const <String, Object?>{'voltageRmsV': 230.0},
        ),
      ],
      settings: const <String, Object?>{'frequencyHz': 50.0},
    );

    final ElectroSimRuntimeSnapshot snapshot =
        const ElectroSimRuntimeEngine().evaluate(circuit);

    expect(snapshot.solved, isTrue);
    expect(snapshot.contactorActuated(ComponentId('k1')), isTrue);
    expect(snapshot.controlIssues, isEmpty);
    expect(
      snapshot.ac1.branch('component:r1').current!.magnitude,
      closeTo(5.0, 1e-8),
    );
    expect(
      snapshot.ac1.branch('component:k1:control:coil').current!.magnitude,
      closeTo(0.23, 1e-8),
    );
  });
}

Connection _wire(String id, String from, String to) => Connection(
      id: ConnectionId(id),
      fromTerminalId: TerminalId(from),
      toTerminalId: TerminalId(to),
    );

Terminal _t(
  String id,
  String name, {
  TerminalRole role = TerminalRole.generic,
  PhaseTag phase = PhaseTag.none,
}) =>
    Terminal(id: TerminalId(id), name: name, role: role, phase: phase);
