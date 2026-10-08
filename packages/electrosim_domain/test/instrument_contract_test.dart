import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:test/test.dart';

CircuitState _circuit({
  List<InstrumentInstance> instruments = const <InstrumentInstance>[],
  List<ProbeConnection> probes = const <ProbeConnection>[],
}) => CircuitState(
  circuitId: CircuitId('sim-r1-probes'),
  revision: 0,
  mode: ElectricalMode.dc,
  components: <ComponentInstance>[
    ComponentInstance(
      id: ComponentId('lamp'),
      modelType: 'lamp',
      terminals: <Terminal>[
        Terminal(id: TerminalId('lamp-a'), name: 'A'),
        Terminal(id: TerminalId('lamp-b'), name: 'B'),
      ],
      parameters: const <String, Object?>{'resistanceOhm': 48.0},
    ),
  ],
  connections: <Connection>[
    Connection(
      id: ConnectionId('wire'),
      fromTerminalId: TerminalId('lamp-a'),
      toTerminalId: TerminalId('lamp-b'),
    ),
  ],
  instruments: instruments,
  probes: probes,
);

InstrumentInstance _meter() => InstrumentInstance(
  id: InstrumentId('vm'),
  kind: InstrumentKind.voltmeter,
  mode: InstrumentMode.voltageDc,
);

void main() {
  test('SIM-R1: instrument and detachable leads survive JSON round trip', () {
    final CircuitState circuit = _circuit(
      instruments: <InstrumentInstance>[_meter()],
      probes: <ProbeConnection>[
        ProbeConnection(
          id: ProbeId('probe-v'),
          instrumentId: InstrumentId('vm'),
          port: InstrumentPort.voltOhm,
          terminalId: TerminalId('lamp-a'),
        ),
        ProbeConnection(
          id: ProbeId('probe-common'),
          instrumentId: InstrumentId('vm'),
          port: InstrumentPort.common,
          terminalId: TerminalId('lamp-b'),
        ),
      ],
    );
    final CircuitState read = CircuitState.fromJsonString(circuit.toJsonString());
    expect(read, circuit);
    expect(read.instruments.single.inputImpedanceOhm, 10000000);
    expect(read.probes, hasLength(2));
    expect(read.connections, hasLength(1));
    expect(read.connections.single.id.value, 'wire');
  });

  test('SIM-R1 legacy circuits have no instruments and unchanged JSON', () {
    final CircuitState old = _circuit();
    expect(old.toJson().containsKey('instruments'), isFalse);
    expect(old.toJson().containsKey('probes'), isFalse);
    expect(CircuitState.fromJson(old.toJson()), old);
  });

  test('SIM-R1 refuses orphan probes and double-port occupancy', () {
    expect(
      () => _circuit(probes: <ProbeConnection>[
        ProbeConnection(
          id: ProbeId('orphan'),
          instrumentId: InstrumentId('not-created'),
          port: InstrumentPort.common,
          terminalId: TerminalId('lamp-a'),
        ),
      ]),
      throwsA(isA<DomainException>()),
    );
    expect(
      () => _circuit(instruments: <InstrumentInstance>[_meter()], probes: <ProbeConnection>[
        ProbeConnection(id: ProbeId('a'), instrumentId: InstrumentId('vm'),
          port: InstrumentPort.common, terminalId: TerminalId('lamp-a')),
        ProbeConnection(id: ProbeId('b'), instrumentId: InstrumentId('vm'),
          port: InstrumentPort.common, terminalId: TerminalId('lamp-b')),
      ]),
      throwsA(isA<DomainException>()),
    );
  });

  test('SIM-R1 validates physical limits and single probe target', () {
    expect(
      () => InstrumentInstance(
        id: InstrumentId('broken'), kind: InstrumentKind.ammeter,
        mode: InstrumentMode.currentDc, burdenResistanceOhm: double.nan),
      throwsA(isA<DomainException>()),
    );
    expect(
      () => ProbeConnection(id: ProbeId('bad'), instrumentId: InstrumentId('vm'),
        port: InstrumentPort.common,
        terminalId: TerminalId('lamp-a'),
        connectionId: ConnectionId('wire')),
      throwsA(isA<DomainException>()),
    );
  });
}
