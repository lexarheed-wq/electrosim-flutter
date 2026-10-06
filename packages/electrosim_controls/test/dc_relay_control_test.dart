import 'package:electrosim_controls/electrosim_controls.dart';
import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:electrosim_topology/electrosim_topology.dart';
import 'package:test/test.dart';

void main() {
  const TopologyEngine topologyEngine = TopologyEngine();
  const ElectromechanicalControlEngine controls =
      ElectromechanicalControlEngine();

  test('DC relay closes linked NO contact from real coil voltage', () {
    final CircuitState circuit = _relayCircuit(24.0);
    final ElectromechanicalDcOutcome outcome = controls.solveDc(
      circuit: circuit,
      topology: topologyEngine.compile(circuit),
    );

    expect(outcome.result.isSolved, isTrue);
    expect(outcome.converged, isTrue);
    expect(outcome.relays[ComponentId('k1')]?.actuated, isTrue);
    expect(
      outcome.relays[ComponentId('k1')]?.coilVoltageV,
      closeTo(24.0, 1e-9),
    );
    expect(
      outcome.result.branch('component:contact').currentA?.abs(),
      closeTo(0.24, 1e-9),
    );
    expect(
      outcome.result.branch('component:load').currentA?.abs(),
      closeTo(0.24, 1e-9),
    );
  });

  test('DC relay drops out below threshold from previously actuated state', () {
    final CircuitState circuit = _relayCircuit(5.0);
    final ElectromechanicalDcOutcome outcome = controls.solveDc(
      circuit: circuit,
      topology: topologyEngine.compile(circuit),
      previousStates: <ComponentId, bool>{ComponentId('k1'): true},
    );

    expect(outcome.result.isSolved, isTrue);
    expect(outcome.converged, isTrue);
    expect(outcome.relays[ComponentId('k1')]?.actuated, isFalse);
    expect(outcome.result.branch('component:contact').kind.name, 'openCircuit');
    expect(outcome.result.branch('component:contact').currentA, 0.0);
  });
  test('DC self-interrupting NC relay is reported as chatter', () {
    final CircuitState circuit = _selfInterruptingRelayCircuit();
    final ElectromechanicalDcOutcome outcome = controls.solveDc(
      circuit: circuit,
      topology: topologyEngine.compile(circuit),
    );

    expect(outcome.result.isSolved, isTrue);
    expect(outcome.converged, isFalse);
    expect(
      outcome.issues.any(
        (ElectromechanicalControlIssue issue) =>
            issue.code ==
            ElectromechanicalControlIssueCode.oscillatingControlState,
      ),
      isTrue,
    );
  });
}

CircuitState _relayCircuit(double voltageV) {
  return CircuitState(
    circuitId: CircuitId('dc-relay-$voltageV'),
    revision: 0,
    mode: ElectricalMode.dc,
    sources: <SourceInstance>[
      SourceInstance(
        id: SourceId('v1'),
        modelType: 'dc_voltage_source',
        terminals: <Terminal>[
          _t('vp', '+', phase: PhaseTag.dcPositive),
          _t('vn', '−', phase: PhaseTag.dcNegative),
        ],
        parameters: <String, Object?>{'voltageV': voltageV},
      ),
    ],
    components: <ComponentInstance>[
      ComponentInstance(
        id: ComponentId('k1'),
        modelType: 'relay_coil',
        terminals: <Terminal>[
          _t('a1', 'A1', role: TerminalRole.coilA1),
          _t('a2', 'A2', role: TerminalRole.coilA2),
        ],
        parameters: const <String, Object?>{
          'resistanceOhm': 120.0,
          'coilPickupVoltageV': 18.0,
          'coilDropoutVoltageV': 6.0,
        },
        controlState: const <String, Object?>{'actuated': false},
      ),
      ComponentInstance(
        id: ComponentId('contact'),
        modelType: 'relay_contact_no',
        terminals: <Terminal>[
          _t('c13', '13', role: TerminalRole.auxiliaryNormallyOpen),
          _t('c14', '14', role: TerminalRole.auxiliaryNormallyOpen),
        ],
        parameters: const <String, Object?>{'linkedRelayId': 'k1'},
        controlState: const <String, Object?>{'actuated': false},
      ),
      ComponentInstance(
        id: ComponentId('load'),
        modelType: 'resistor',
        terminals: <Terminal>[_t('r1', '1'), _t('r2', '2')],
        parameters: const <String, Object?>{'resistanceOhm': 100.0},
      ),
    ],
    connections: <Connection>[
      _w('coil-pos', 'vp', 'a1'),
      _w('coil-neg', 'a2', 'vn'),
      _w('power-pos', 'vp', 'c13'),
      _w('contact-load', 'c14', 'r1'),
      _w('load-neg', 'r2', 'vn'),
    ],
  );
}

Terminal _t(
  String id,
  String name, {
  TerminalRole role = TerminalRole.generic,
  PhaseTag phase = PhaseTag.none,
}) => Terminal(id: TerminalId(id), name: name, role: role, phase: phase);

Connection _w(String id, String from, String to) => Connection(
  id: ConnectionId(id),
  fromTerminalId: TerminalId(from),
  toTerminalId: TerminalId(to),
);

CircuitState _selfInterruptingRelayCircuit() {
  return CircuitState(
    circuitId: CircuitId('dc-relay-chatter'),
    revision: 0,
    mode: ElectricalMode.dc,
    sources: <SourceInstance>[
      SourceInstance(
        id: SourceId('v1'),
        modelType: 'dc_voltage_source',
        terminals: <Terminal>[
          _t('svp', '+', phase: PhaseTag.dcPositive),
          _t('svn', '−', phase: PhaseTag.dcNegative),
        ],
        parameters: const <String, Object?>{'voltageV': 24.0},
      ),
    ],
    components: <ComponentInstance>[
      ComponentInstance(
        id: ComponentId('sk1'),
        modelType: 'relay_coil',
        terminals: <Terminal>[
          _t('sa1', 'A1', role: TerminalRole.coilA1),
          _t('sa2', 'A2', role: TerminalRole.coilA2),
        ],
        parameters: const <String, Object?>{
          ComponentParameterKeys.resistanceOhm: 120.0,
          ComponentParameterKeys.coilPickupVoltageV: 18.0,
          ComponentParameterKeys.coilDropoutVoltageV: 6.0,
        },
        controlState: const <String, Object?>{'actuated': false},
      ),
      ComponentInstance(
        id: ComponentId('snc'),
        modelType: 'relay_contact_nc',
        terminals: <Terminal>[
          _t('s11', '11', role: TerminalRole.auxiliaryNormallyClosed),
          _t('s12', '12', role: TerminalRole.auxiliaryNormallyClosed),
        ],
        parameters: const <String, Object?>{'linkedRelayId': 'sk1'},
        controlState: const <String, Object?>{'actuated': false},
      ),
    ],
    connections: <Connection>[
      _w('supply-coil', 'svp', 'sa1'),
      _w('coil-nc', 'sa2', 's11'),
      _w('nc-return', 's12', 'svn'),
    ],
  );
}
