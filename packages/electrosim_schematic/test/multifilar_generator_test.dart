import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:electrosim_schematic/electrosim_schematic.dart';
import 'package:test/test.dart';

final MultifilarGenerator generator = MultifilarGenerator();

Terminal _terminal(String id, String name, {TerminalRole role = TerminalRole.generic}) =>
    Terminal(id: TerminalId(id), name: name, role: role);

CircuitState _circuit({bool secondWireEnabled = true, bool reverse = false}) {
  final source = SourceInstance(
    id: SourceId('S1'),
    modelType: 'dc_voltage_source',
    terminals: [
      _terminal('s_p', '+', role: TerminalRole.positive),
      _terminal('s_n', '-', role: TerminalRole.negative),
    ],
    parameters: const {'voltageV': 12.0, 'reference': 'G1'},
  );
  final resistor = ComponentInstance(
    id: ComponentId('R1'),
    modelType: 'resistor',
    terminals: [
      _terminal('r_a', 'A'),
      _terminal('r_b', 'B'),
    ],
    parameters: const {'resistanceOhm': 12.0},
  );
  final wires = [
    Connection(
      id: ConnectionId('W1'),
      fromTerminalId: TerminalId('s_p'),
      toTerminalId: TerminalId('r_a'),
    ),
    Connection(
      id: ConnectionId('W2'),
      fromTerminalId: TerminalId('s_n'),
      toTerminalId: TerminalId('r_b'),
      enabled: secondWireEnabled,
    ),
  ];
  return CircuitState(
    circuitId: CircuitId('simple-dc'),
    revision: 9,
    mode: ElectricalMode.dc,
    sources: [source],
    components: [resistor],
    connections: reverse
        ? [wires.last, wires.first]
        : wires,
  );
}

void main() {
  test('P3 produces deterministic read-only projection irrespective of wire order', () {
    final first = _circuit();
    final before = first.toJsonString();
    final a = generator.generate(first);
    final b = generator.generate(_circuit(reverse: true));

    expect(a.canonicalJson(), b.canonicalJson());
    expect(first.toJsonString(), before, reason: 'Generator must be read-only');
    expect(a.circuitId, 'simple-dc');
    expect(a.revision, 9);
    expect(a.electricalMode, 'dc');
    expect(a.devices.map((d) => d.key).toList(), [
      'component:R1',
      'source:S1',
    ]);
    expect(a.nets, hasLength(2));
    expect(a.conductors, hasLength(2));
  });

  test('P3 assigns physical terminals to canonical conductor nets, not graphics', () {
    final doc = generator.generate(_circuit());
    final src = doc.devices.singleWhere((d) => d.key == 'source:S1');
    final load = doc.devices.singleWhere((d) => d.key == 'component:R1');
    String net(MultifilarDevice d, String terminal) =>
        d.terminals.singleWhere((t) => t.id == terminal).netId;

    expect(net(src, 's_p'), net(load, 'r_a'));
    expect(net(src, 's_n'), net(load, 'r_b'));
    expect(net(src, 's_p'), isNot(net(src, 's_n')));
    expect(src.reference, 'G1');
    expect(src.referenceProvisional, isFalse);
    expect(load.reference, 'R1');
    expect(load.referenceProvisional, isTrue);
  });

  test('P3 disabled wire is drawn as disabled and does not connect terminals', () {
    final doc = generator.generate(_circuit(secondWireEnabled: false));
    final disabled = doc.conductors.singleWhere((c) => c.id == 'W2');
    expect(disabled.enabled, isFalse);
    expect(doc.nets, hasLength(3));
    final s = doc.devices.singleWhere((d) => d.key == 'source:S1');
    final r = doc.devices.singleWhere((d) => d.key == 'component:R1');
    expect(
      s.terminals.singleWhere((t) => t.id == 's_n').netId,
      isNot(r.terminals.singleWhere((t) => t.id == 'r_b').netId),
    );
    expect(doc.findings.any((f) => f.code == 'disabledConnection'), isTrue);
  });

  test('P3 contactor coil and three main poles are distinct structural branches', () {
    final contactor = ComponentInstance(
      id: ComponentId('KM1'),
      modelType: 'contactor_3p',
      terminals: [
        _terminal('km_l1', 'L1', role: TerminalRole.lineL1),
        _terminal('km_l2', 'L2', role: TerminalRole.lineL2),
        _terminal('km_l3', 'L3', role: TerminalRole.lineL3),
        _terminal('km_t1', 'T1', role: TerminalRole.loadT1),
        _terminal('km_t2', 'T2', role: TerminalRole.loadT2),
        _terminal('km_t3', 'T3', role: TerminalRole.loadT3),
        _terminal('km_a1', 'A1', role: TerminalRole.coilA1),
        _terminal('km_a2', 'A2', role: TerminalRole.coilA2),
      ],
    );
    final circuit = CircuitState(
      circuitId: CircuitId('km-circuit'),
      revision: 0,
      mode: ElectricalMode.ac3,
      components: [contactor],
    );
    final doc = generator.generate(circuit);
    expect(doc.devices, hasLength(1));
    expect(doc.branches, hasLength(4));
    expect(doc.branches.where((b) => b.role == 'powerPole'), hasLength(3));
    expect(doc.branches.where((b) => b.role == 'controlCoil'), hasLength(1));
    final coil = doc.branches.singleWhere((b) => b.role == 'controlCoil');
    expect(coil.fromTerminalId, 'km_a1');
    expect(coil.toTerminalId, 'km_a2');
    expect(coil.fromNetId, isNot(coil.toNetId));
    expect(doc.branches.every((b) => b.deviceKey == 'component:KM1'), isTrue);
  });

  test('P3 reports physical instruments not yet projected rather than inventing wiring', () {
    final base = _circuit();
    final circuit = CircuitState(
      circuitId: base.circuitId,
      revision: base.revision,
      mode: base.mode,
      sources: base.sources,
      components: base.components,
      connections: base.connections,
      instruments: [
        InstrumentInstance(
          id: InstrumentId('V1'),
          kind: InstrumentKind.voltmeter,
          mode: InstrumentMode.voltageDc,
        ),
      ],
    );
    final doc = generator.generate(circuit);
    expect(doc.unprojectedInstrumentIds, ['V1']);
    expect(doc.conductors, hasLength(2));
  });

  test('P3 will not invent a canonical component symbol when contract is unknown', () {
    final circuit = CircuitState(
      circuitId: CircuitId('unknown'),
      revision: 0,
      mode: ElectricalMode.pv,
      components: [
        ComponentInstance(
          id: ComponentId('U1'),
          modelType: 'unregistered_future_device',
          terminals: [
            _terminal('u_a', 'A'),
            _terminal('u_b', 'B'),
          ],
        ),
      ],
    );
    final doc = generator.generate(circuit);
    expect(doc.devices.single.modelType, 'unregistered_future_device');
    expect(doc.branches, isEmpty);
    expect(doc.nets, hasLength(2));
  });
}
