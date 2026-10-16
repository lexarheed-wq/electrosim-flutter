import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:electrosim_multiphysics/electrosim_multiphysics.dart';
import 'package:electrosim/runtime/electrical_project_runtime_engine.dart';
import 'package:electrosim/runtime/electrosim_runtime_engine.dart';
import 'package:test/test.dart';

CircuitState _empty(String id, ElectricalMode mode) => CircuitState(
  circuitId: CircuitId(id), revision: 0, mode: mode,
);

CircuitState _controlCircuit({required bool sourceEnabled}) {
  final plc = ComponentInstance(
    id: ComponentId('plc'), modelType: 'plc_dc',
    terminals: <Terminal>[
      for (int i = 0; i < 10; i++) Terminal(id: TerminalId('plc-$i'), name: switch (i) {
        0 => 'L+', 1 => 'M', >= 2 && <= 5 => 'I${i - 2}', _ => 'Q${i - 6}',
      }),
    ],
    parameters: const <String, Object?>{'ladderProgram': <Object?>[
      <String, Object?>{'steps': <Object?>[
        <String, Object?>{'type': 'contact_no', 'address': 'I0'},
        <String, Object?>{'type': 'coil', 'address': 'Q0'},
      ]},
    ]},
  );
  return CircuitState(
    circuitId: CircuitId('control'), revision: sourceEnabled ? 0 : 1, mode: ElectricalMode.dc,
    components: <ComponentInstance>[
      plc,
      ComponentInstance(id: ComponentId('relay'), modelType: 'relay_coil',
        terminals: <Terminal>[
          Terminal(id: TerminalId('relay-a'), name: 'A1'),
          Terminal(id: TerminalId('relay-b'), name: 'A2'),
        ],
        parameters: const <String, Object?>{
          'resistanceOhm': 960.0,
          'coilPickupVoltageV': 18.0,
          'coilDropoutVoltageV': 5.0,
        }),
    ],
    sources: <SourceInstance>[
      SourceInstance(id: SourceId('s24'), modelType: 'dc_voltage_source', enabled: sourceEnabled,
        terminals: <Terminal>[
          Terminal(id: TerminalId('s24+'), name: '+', phase: PhaseTag.dcPositive),
          Terminal(id: TerminalId('s24-'), name: '-', phase: PhaseTag.dcNegative),
        ], parameters: const <String, Object?>{'voltageV': 24.0}),
    ],
    connections: <Connection>[
      Connection(id: ConnectionId('l+'), fromTerminalId: TerminalId('s24+'), toTerminalId: TerminalId('plc-0')),
      Connection(id: ConnectionId('m'), fromTerminalId: TerminalId('s24-'), toTerminalId: TerminalId('plc-1')),
      Connection(id: ConnectionId('input'), fromTerminalId: TerminalId('s24+'), toTerminalId: TerminalId('plc-2')),
      Connection(id: ConnectionId('q0-relay'), fromTerminalId: TerminalId('plc-6'), toTerminalId: TerminalId('relay-a')),
      Connection(id: ConnectionId('relay-m'), fromTerminalId: TerminalId('relay-b'), toTerminalId: TerminalId('s24-')),
    ],
  );
}

CircuitState _powerCircuit() => CircuitState(
  circuitId: CircuitId('power'), revision: 0, mode: ElectricalMode.ac3,
  components: <ComponentInstance>[
    ComponentInstance(id: ComponentId('interface-contact'), modelType: 'contactor_aux_no',
      terminals: <Terminal>[
        Terminal(id: TerminalId('interface-1'), name: '13'),
        Terminal(id: TerminalId('interface-2'), name: '14'),
      ]),
  ],
);

ElectricalProject _relayProject({required bool sourceEnabled}) => ElectricalProject(
  networks: <ElectricalNetwork>[
    ElectricalNetwork(id: 'control', circuit: _controlCircuit(sourceEnabled: sourceEnabled)),
    ElectricalNetwork(id: 'power', circuit: _powerCircuit()),
  ],
  relayLinks: <CrossNetworkRelayLink>[
    CrossNetworkRelayLink(id: 'k1-bridge', plcNetworkId: 'control', plcComponentId: 'plc', outputAddress: 'Q0',
      dcNetworkId: 'control', relayCoilId: 'relay', ac3NetworkId: 'power', ac3ContactId: 'interface-contact'),
  ],
);

void main() {
  test('runtime preserves two solver domains and advances the project clock once', () {
    final ElectricalProject project = ElectricalProject(networks: <ElectricalNetwork>[
      ElectricalNetwork(id: 'control', circuit: _empty('dc', ElectricalMode.dc)),
      ElectricalNetwork(id: 'power', circuit: _empty('ac3', ElectricalMode.ac3)),
    ]);
    const ElectricalProjectRuntimeEngine engine = ElectricalProjectRuntimeEngine();
    final first = engine.advance(project, elapsed: const Duration(milliseconds: 100));
    expect(first.elapsed, const Duration(milliseconds: 100));
    expect(first.networks.keys, containsAll(<String>['control', 'power']));
    expect(first.networks['control']!.solverKind, ElectroSimRuntimeSolverKind.dc);
    expect(first.networks['power']!.solverKind, ElectroSimRuntimeSolverKind.ac3);
    final correction = engine.advance(project, elapsed: Duration.zero, previous: first);
    expect(correction.elapsed, first.elapsed);
  });

  test('single homogeneous network can still be evaluated independently', () {
    final ElectricalProject project = ElectricalProject(networks: <ElectricalNetwork>[
      ElectricalNetwork(id: 'dc', circuit: _empty('dc-only', ElectricalMode.dc)),
    ]);
    final result = const ElectricalProjectRuntimeEngine().advance(
      project, elapsed: Duration.zero,
    );
    expect(result.networks.keys, contains('dc'));
    expect(result.elapsed, Duration.zero);
  });

  test('solved DC relay transfers through the isolated bridge and drops after 24 V loss', () {
    const ElectricalProjectRuntimeEngine engine = ElectricalProjectRuntimeEngine();
    final first = engine.advance(_relayProject(sourceEnabled: true), elapsed: const Duration(milliseconds: 20));
    expect(first.relayBridgeStates['k1-bridge'], isTrue);
    final linkedContact = first.networks['power']!.effectiveCircuit.components.single;
    expect(linkedContact.controlState['externalLinkResolved'], isTrue);
    expect(linkedContact.controlState['actuated'], isTrue);

    final failed = engine.advance(_relayProject(sourceEnabled: false), elapsed: const Duration(milliseconds: 20), previous: first);
    expect(failed.relayBridgeStates['k1-bridge'], isFalse);
    expect(failed.networks['power']!.effectiveCircuit.components.single.controlState['actuated'], isFalse);
  });
}
