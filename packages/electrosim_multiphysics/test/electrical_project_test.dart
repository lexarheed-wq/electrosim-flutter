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
}
