import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:electrosim_multiphysics/electrosim_multiphysics.dart';
import 'package:test/test.dart';

CircuitState _circuit(String id, ElectricalMode mode, List<String> models) =>
    CircuitState(
      circuitId: CircuitId(id),
      revision: 0,
      mode: mode,
      components: <ComponentInstance>[
        for (final String model in models)
          ComponentInstance(
            id: ComponentId(model),
            modelType: model,
            terminals: <Terminal>[
              Terminal(id: TerminalId('$model-a'), name: 'A'),
              Terminal(id: TerminalId('$model-b'), name: 'B'),
            ],
          ),
      ],
    );

ElectricalProject _project({
  List<CrossNetworkRelayLink> relays = const <CrossNetworkRelayLink>[],
  List<CrossNetworkSignalLink> signals = const <CrossNetworkSignalLink>[],
}) => ElectricalProject(
  networks: <ElectricalNetwork>[
    ElectricalNetwork(
      id: 'control',
      circuit: _circuit('dc', ElectricalMode.dc, <String>['plc_dc', 'relay_coil']),
    ),
    ElectricalNetwork(
      id: 'power',
      circuit: _circuit('ac3', ElectricalMode.ac3, <String>['contactor_aux_no', 'contactor_aux_nc']),
    ),
  ],
  relayLinks: relays,
  signalLinks: signals,
);

CrossNetworkRelayLink _relay({String q = 'Q0', String coil = 'relay_coil', String contact = 'contactor_aux_no'}) =>
    CrossNetworkRelayLink(
      id: 'bridge',
      plcNetworkId: 'control',
      plcComponentId: 'plc_dc',
      outputAddress: q,
      dcNetworkId: 'control',
      relayCoilId: coil,
      ac3NetworkId: 'power',
      ac3ContactId: contact,
    );

CrossNetworkSignalLink _signal({String address = 'I0'}) =>
    CrossNetworkSignalLink(
      id: 'feedback',
      ac3NetworkId: 'power',
      auxiliaryContactId: 'contactor_aux_nc',
      dcNetworkId: 'control',
      plcComponentId: 'plc_dc',
      inputAddress: address,
    );

void main() {
  test('roundTripsTwoHomogeneousNetworksAndCrossLinks', () {
    final ElectricalProject original = _project(
      relays: <CrossNetworkRelayLink>[_relay()],
      signals: <CrossNetworkSignalLink>[_signal()],
    );
    final ElectricalProject restored =
        ElectricalProject.fromJsonString(original.toJsonString());
    expect(restored.toJson(), equals(original.toJson()));
    expect(restored.networks.map((ElectricalNetwork n) => n.circuit.mode),
        <ElectricalMode>[ElectricalMode.dc, ElectricalMode.ac3]);
  });

  test('rejectsWrongModeOrDanglingRelayLinks', () {
    expect(
      () => ElectricalProject(networks: <ElectricalNetwork>[
        ElectricalNetwork(id: 'control', circuit: _circuit('dc', ElectricalMode.ac3, <String>['plc_dc', 'relay_coil'])),
        ElectricalNetwork(id: 'power', circuit: _circuit('ac3', ElectricalMode.ac3, <String>['contactor_aux_no'])),
      ]),
      throwsA(isA<ElectricalProjectException>()),
    );
    expect(
      () => _project(relays: <CrossNetworkRelayLink>[_relay(coil: 'missing')]),
      throwsA(isA<ElectricalProjectException>()),
    );
  });

  test('rejectsDuplicateBridgeEndpoints', () {
    expect(
      () => _project(relays: <CrossNetworkRelayLink>[
        _relay(),
        CrossNetworkRelayLink(
          id: 'bridge2', plcNetworkId: 'control', plcComponentId: 'plc_dc',
          outputAddress: 'Q1', dcNetworkId: 'control', relayCoilId: 'relay_coil',
          ac3NetworkId: 'power', ac3ContactId: 'contactor_aux_no',
        ),
      ]),
      throwsA(isA<ElectricalProjectException>()),
    );
  });

  test('rejectsInvalidPlcAddressesAndFeedback', () {
    expect(() => _project(relays: <CrossNetworkRelayLink>[_relay(q: 'Q9')]),
        throwsA(isA<ElectricalProjectException>()));
    expect(() => _project(signals: <CrossNetworkSignalLink>[_signal(address: 'I9')]),
        throwsA(isA<ElectricalProjectException>()));
  });

  test('allowsSingleNetworkLegacyEnvelope', () {
    final CircuitState circuit = _circuit('legacy', ElectricalMode.dc, <String>['relay_coil']);
    final ElectricalProject project = ElectricalProject.fromLegacyCircuit(circuit);
    expect(project.networks, hasLength(1));
    expect(project.networks.single.circuit.toJson(), equals(circuit.toJson()));
  });

  test('rejects more than one DC PLC in a mixed project', () {
    final CircuitState base = _circuit('dc', ElectricalMode.dc, <String>['plc_dc', 'relay_coil']);
    final CircuitState withSecondPlc = CircuitState(
      circuitId: base.circuitId,
      revision: base.revision,
      mode: base.mode,
      components: <ComponentInstance>[
        ...base.components,
        ComponentInstance(
          id: ComponentId('plc-2'),
          modelType: 'plc_dc',
          terminals: <Terminal>[
            for (int i = 0; i < 10; i++)
              Terminal(id: TerminalId('plc-2-$i'), name: 'T$i'),
          ],
        ),
      ],
    );
    expect(
      () => ElectricalProject(networks: <ElectricalNetwork>[
        ElectricalNetwork(id: 'control', circuit: withSecondPlc),
        ElectricalNetwork(id: 'power', circuit: _circuit('ac3', ElectricalMode.ac3, <String>['contactor_aux_no'])),
      ]),
      throwsA(isA<ElectricalProjectException>().having(
        (ElectricalProjectException error) => error.code,
        'code',
        'unsupported_plc_count',
      )),
    );
  });

  test('supports mixed board with all homogeneous domains and partial combinations', () {
    final ElectricalProject board = ElectricalProject.emptyMixedBoard();
    expect(board.networks.map((ElectricalNetwork n) => n.circuit.mode),
      containsAll(<ElectricalMode>[ElectricalMode.dc, ElectricalMode.ac1, ElectricalMode.ac3, ElectricalMode.pv]));
    expect(() => ElectricalProject(networks: <ElectricalNetwork>[
      for (final ElectricalMode mode in <ElectricalMode>[ElectricalMode.dc, ElectricalMode.ac3])
        ElectricalNetwork(id: mode.name, circuit: _circuit(mode.name, mode, const <String>[])),
    ]), returnsNormally);
    expect(() => ElectricalProject(networks: <ElectricalNetwork>[
      ElectricalNetwork(id: 'a', circuit: _circuit('a', ElectricalMode.ac1, const <String>[])),
      ElectricalNetwork(id: 'b', circuit: _circuit('b', ElectricalMode.ac1, const <String>[])),
    ]), throwsA(isA<ElectricalProjectException>()));
    expect(() => ElectricalProject(networks: <ElectricalNetwork>[
      ElectricalNetwork(id: 'm', circuit: _circuit('m', ElectricalMode.mixed, const <String>[])),
    ]), throwsA(isA<ElectricalProjectException>()));
  });

  test('round trips typed links and reads schema one without new link fields', () {
    final ElectricalProject project = ElectricalProject(networks: <ElectricalNetwork>[
      ElectricalNetwork(id: 'control', circuit: _circuit('dc', ElectricalMode.dc, <String>['plc_dc'])),
      ElectricalNetwork(id: 'power', circuit: _circuit('ac3', ElectricalMode.ac3, <String>['contactor_3p'])),
      ElectricalNetwork(id: 'solar', circuit: _circuit('pv', ElectricalMode.pv, <String>['pv_inverter'])),
      ElectricalNetwork(id: 'load', circuit: CircuitState(circuitId: CircuitId('ac1'), revision: 0,
        mode: ElectricalMode.ac1, components: <ComponentInstance>[ComponentInstance(
          id: ComponentId('resistor'), modelType: 'resistor', terminals: <Terminal>[
            Terminal(id: TerminalId('resistor-a'), name: 'L', role: TerminalRole.line),
            Terminal(id: TerminalId('resistor-b'), name: 'N', role: TerminalRole.neutral),
          ])])),
    ], actuatorLinks: <CrossNetworkActuatorLink>[
      CrossNetworkActuatorLink(id: 'command', plcNetworkId: 'control', plcComponentId: 'plc_dc',
        outputAddress: 'Q0', targetNetworkId: 'power', contactorId: 'contactor_3p'),
    ], converterLinks: <CrossNetworkConverterLink>[
      CrossNetworkConverterLink(id: 'inverter', inputNetworkId: 'solar', converterComponentId: 'pv_inverter', outputNetworkId: 'load', outputLineTerminalId: 'resistor-a', outputNeutralTerminalId: 'resistor-b'),
    ]);
    expect(ElectricalProject.fromJsonString(project.toJsonString()).toJson(), equals(project.toJson()));
    final Map<String, Object?> v1 = project.toJson()..['schemaVersion'] = 1
      ..remove('actuatorLinks')..remove('converterLinks');
    expect(ElectricalProject.fromJson(v1).actuatorLinks, isEmpty);
    expect(ElectricalProject.fromJson(v1).converterLinks, isEmpty);
  });

  test('rejects invalid cross-domain actuator and converter contracts', () {
    final List<ElectricalNetwork> networks = <ElectricalNetwork>[
      ElectricalNetwork(id: 'control', circuit: _circuit('dc', ElectricalMode.dc, <String>['plc_dc'])),
      ElectricalNetwork(id: 'power', circuit: _circuit('ac3', ElectricalMode.ac3, <String>['contactor_3p'])),
      ElectricalNetwork(id: 'solar', circuit: _circuit('pv', ElectricalMode.pv, <String>['pv_inverter'])),
    ];
    expect(() => ElectricalProject(networks: networks, actuatorLinks: <CrossNetworkActuatorLink>[
      CrossNetworkActuatorLink(id: 'bad', plcNetworkId: 'control', plcComponentId: 'plc_dc', outputAddress: 'Q9', targetNetworkId: 'power', contactorId: 'contactor_3p'),
    ]), throwsA(isA<ElectricalProjectException>()));
    expect(() => ElectricalProject(networks: networks, converterLinks: <CrossNetworkConverterLink>[
      CrossNetworkConverterLink(id: 'bad', inputNetworkId: 'solar', converterComponentId: 'pv_inverter', outputNetworkId: 'control', outputLineTerminalId: 'plc_dc-a', outputNeutralTerminalId: 'plc_dc-b'),
    ]), throwsA(isA<ElectricalProjectException>()));
  });
}
