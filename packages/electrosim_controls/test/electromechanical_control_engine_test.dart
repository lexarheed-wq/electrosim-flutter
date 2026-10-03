
import 'package:electrosim_controls/electrosim_controls.dart';
import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:electrosim_topology/electrosim_topology.dart';
import 'package:test/test.dart';

void main() {
  const TopologyEngine topologyEngine = TopologyEngine();
  const ElectromechanicalControlEngine controls =
      ElectromechanicalControlEngine();

  test('AC1 energized coil automatically closes the contactor power pole', () {
    final CircuitState circuit = _ac1Circuit(
      sourceVoltageV: 230.0,
      initiallyActuated: false,
    );
    final outcome = controls.solveAc1(
      circuit: circuit,
      topology: topologyEngine.compile(circuit),
    );

    expect(outcome.converged, isTrue);
    expect(outcome.iterations, 2);
    expect(outcome.contactors[ComponentId('k1')]!.actuated, isTrue);
    expect(
      outcome.result.branch('component:r1').current!.magnitude,
      closeTo(5.0, 1e-8),
    );
  });

  test('AC1 released coil automatically opens a previously actuated contactor',
      () {
    final CircuitState circuit = _ac1Circuit(
      sourceVoltageV: 0.0,
      initiallyActuated: true,
    );
    final outcome = controls.solveAc1(
      circuit: circuit,
      topology: topologyEngine.compile(circuit),
    );

    expect(outcome.converged, isTrue);
    expect(outcome.contactors[ComponentId('k1')]!.actuated, isFalse);
    expect(
      outcome.result.branch('component:r1').current!.magnitude,
      closeTo(0.0, 1e-12),
    );
  });

  test('pickup/dropout hysteresis prevents chatter in the intermediate band',
      () {
    final CircuitState released = _ac1Circuit(
      sourceVoltageV: 120.0,
      initiallyActuated: false,
    );
    final releasedOutcome = controls.solveAc1(
      circuit: released,
      topology: topologyEngine.compile(released),
    );
    expect(releasedOutcome.contactors[ComponentId('k1')]!.actuated, isFalse);

    final CircuitState held = _ac1Circuit(
      sourceVoltageV: 120.0,
      initiallyActuated: true,
    );
    final heldOutcome = controls.solveAc1(
      circuit: held,
      topology: topologyEngine.compile(held),
    );
    expect(heldOutcome.contactors[ComponentId('k1')]!.actuated, isTrue);
  });

  test('linked auxiliary NO follows the derived contactor state', () {
    final CircuitState circuit = _ac1Circuit(
      sourceVoltageV: 230.0,
      initiallyActuated: false,
      includeAuxiliaryLoad: true,
    );
    final outcome = controls.solveAc1(
      circuit: circuit,
      topology: topologyEngine.compile(circuit),
    );

    expect(outcome.converged, isTrue);
    expect(outcome.contactors[ComponentId('k1')]!.actuated, isTrue);
    expect(
      outcome.result.branch('component:raux').current!.magnitude,
      closeTo(5.0, 1e-8),
    );

    final ComponentInstance aux = outcome.effectiveCircuit.components
        .firstWhere((ComponentInstance item) => item.id == ComponentId('aux1'));
    expect(aux.controlState['actuated'], isTrue);
  });

  test('AC3 coil closes all three power poles after bounded coordination', () {
    final CircuitState circuit = _ac3Circuit();
    final outcome = controls.solveAc3(
      circuit: circuit,
      topology: topologyEngine.compile(circuit),
    );

    expect(outcome.converged, isTrue);
    expect(outcome.iterations, 2);
    expect(outcome.contactors[ComponentId('k1')]!.actuated, isTrue);
    for (final String id in <String>['r1', 'r2', 'r3']) {
      expect(
        outcome.result.branch('component:$id').current!.magnitude,
        closeTo(5.0, 1e-8),
      );
    }
  });

  test('invalid thresholds never invent a contactor state', () {
    final CircuitState circuit = _ac1Circuit(
      sourceVoltageV: 230.0,
      initiallyActuated: false,
      invalidThresholds: true,
    );
    final outcome = controls.solveAc1(
      circuit: circuit,
      topology: topologyEngine.compile(circuit),
    );

    expect(outcome.contactors, isEmpty);
    expect(
      outcome.issues.map((ElectromechanicalControlIssue issue) => issue.code),
      contains(ElectromechanicalControlIssueCode.invalidCoilThreshold),
    );
  });
}

CircuitState _ac1Circuit({
  required double sourceVoltageV,
  required bool initiallyActuated,
  bool includeAuxiliaryLoad = false,
  bool invalidThresholds = false,
}) {
  final List<ComponentInstance> components = <ComponentInstance>[
    ComponentInstance(
      id: ComponentId('k1'),
      modelType: 'contactor_ac1',
      terminals: <Terminal>[
        _t('k1-in', '1', phase: PhaseTag.l1),
        _t('k1-out', '2', phase: PhaseTag.l1),
        _t('k1-a1', 'A1', role: TerminalRole.coilA1, phase: PhaseTag.l1),
        _t(
          'k1-a2',
          'A2',
          role: TerminalRole.coilA2,
          phase: PhaseTag.neutral,
        ),
      ],
      parameters: <String, Object?>{
        'coilResistanceOhm': 1000.0,
        'coilPickupVoltageV': invalidThresholds ? 80.0 : 180.0,
        'coilDropoutVoltageV': invalidThresholds ? 100.0 : 100.0,
      },
      controlState: <String, Object?>{'actuated': initiallyActuated},
    ),
    _resistor('r1', PhaseTag.l1),
  ];

  final List<Connection> connections = <Connection>[
    _wire('w1', 'v-l', 'k1-in'),
    _wire('w2', 'k1-out', 'r1-p'),
    _wire('w3', 'r1-n', 'v-n'),
    _wire('w4', 'v-l', 'k1-a1'),
    _wire('w5', 'k1-a2', 'v-n'),
  ];

  if (includeAuxiliaryLoad) {
    components.add(
      ComponentInstance(
        id: ComponentId('aux1'),
        modelType: 'contactor_aux_no',
        terminals: <Terminal>[
          _t('aux-in', '13', phase: PhaseTag.l1),
          _t('aux-out', '14', phase: PhaseTag.l1),
        ],
        parameters: const <String, Object?>{'linkedContactorId': 'k1'},
      ),
    );
    components.add(_resistor('raux', PhaseTag.l1));
    connections.addAll(<Connection>[
      _wire('wa1', 'v-l', 'aux-in'),
      _wire('wa2', 'aux-out', 'raux-p'),
      _wire('wa3', 'raux-n', 'v-n'),
    ]);
  }

  return CircuitState(
    circuitId: CircuitId('controls-ac1-$sourceVoltageV-$initiallyActuated'),
    revision: 0,
    mode: ElectricalMode.ac1,
    components: components,
    connections: connections,
    sources: <SourceInstance>[
      SourceInstance(
        id: SourceId('v'),
        modelType: 'ac_voltage_source',
        terminals: <Terminal>[
          _t('v-l', 'L', phase: PhaseTag.l1),
          _t('v-n', 'N', phase: PhaseTag.neutral),
        ],
        parameters: <String, Object?>{'voltageRmsV': sourceVoltageV},
      ),
    ],
    settings: const <String, Object?>{'frequencyHz': 50.0},
  );
}

CircuitState _ac3Circuit() => CircuitState(
      circuitId: CircuitId('controls-ac3'),
      revision: 0,
      mode: ElectricalMode.ac3,
      components: <ComponentInstance>[
        ComponentInstance(
          id: ComponentId('k1'),
          modelType: 'contactor_3p',
          terminals: <Terminal>[
            _t('k1-l1-in', '1L1', phase: PhaseTag.l1),
            _t('k1-l2-in', '3L2', phase: PhaseTag.l2),
            _t('k1-l3-in', '5L3', phase: PhaseTag.l3),
            _t('k1-l1-out', '2T1', phase: PhaseTag.l1),
            _t('k1-l2-out', '4T2', phase: PhaseTag.l2),
            _t('k1-l3-out', '6T3', phase: PhaseTag.l3),
            _t('k1-a1', 'A1', role: TerminalRole.coilA1, phase: PhaseTag.l1),
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
        ),
        _resistor('r1', PhaseTag.l1),
        _resistor('r2', PhaseTag.l2),
        _resistor('r3', PhaseTag.l3),
      ],
      connections: <Connection>[
        _wire('p1', 'v1-p', 'k1-l1-in'),
        _wire('p2', 'v2-p', 'k1-l2-in'),
        _wire('p3', 'v3-p', 'k1-l3-in'),
        _wire('o1', 'k1-l1-out', 'r1-p'),
        _wire('o2', 'k1-l2-out', 'r2-p'),
        _wire('o3', 'k1-l3-out', 'r3-p'),
        _wire('n1', 'r1-n', 'v1-n'),
        _wire('n2', 'r2-n', 'v1-n'),
        _wire('n3', 'r3-n', 'v1-n'),
        _wire('ns2', 'v2-n', 'v1-n'),
        _wire('ns3', 'v3-n', 'v1-n'),
        _wire('c1', 'v1-p', 'k1-a1'),
        _wire('c2', 'k1-a2', 'v1-n'),
      ],
      sources: <SourceInstance>[
        _phaseSource('v1', PhaseTag.l1),
        _phaseSource('v2', PhaseTag.l2),
        _phaseSource('v3', PhaseTag.l3),
      ],
      settings: const <String, Object?>{'frequencyHz': 50.0},
    );

ComponentInstance _resistor(String id, PhaseTag phase) => ComponentInstance(
      id: ComponentId(id),
      modelType: 'resistor',
      terminals: <Terminal>[
        _t('$id-p', 'L', phase: phase),
        _t('$id-n', 'N', phase: PhaseTag.neutral),
      ],
      parameters: const <String, Object?>{'resistanceOhm': 46.0},
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
    Terminal(
      id: TerminalId(id),
      name: name,
      role: role,
      phase: phase,
    );
