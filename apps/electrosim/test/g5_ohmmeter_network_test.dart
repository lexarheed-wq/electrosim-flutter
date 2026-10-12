import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:electrosim/runtime/electrosim_instrument_projection.dart';
import 'package:electrosim/runtime/electrosim_runtime_engine.dart';

void main() {
  final meter = InstrumentInstance(
    id: InstrumentId('meter-ohm'),
    kind: InstrumentKind.voltmeter,
    mode: InstrumentMode.resistance,
  );
  Terminal terminal(String id) => Terminal(id: TerminalId(id), name: id);
  ComponentInstance resistor(String id, double value) => ComponentInstance(
    id: ComponentId(id), modelType: 'resistor',
    terminals: [terminal('$id-a'), terminal('$id-b')],
    parameters: {'resistanceOhm': value},
  );
  CircuitState circuit(List<ComponentInstance> components, {
    List<Connection> wires = const [],
    String a = 'r1-a',
    String b = 'r1-b',
    List<SourceInstance> sources = const [],
  }) => CircuitState(
    circuitId: CircuitId('ohm-g5-test'),
    revision: 1, mode: ElectricalMode.dc,
    components: components, sources: sources, connections: wires,
    instruments: [meter],
    probes: [
      ProbeConnection(
        id: ProbeId('ohm-v'), instrumentId: meter.id,
        port: InstrumentPort.voltOhm, terminalId: TerminalId(a),
      ),
      ProbeConnection(
        id: ProbeId('ohm-com'), instrumentId: meter.id,
        port: InstrumentPort.common, terminalId: TerminalId(b),
      ),
    ],
  );
  PhysicalInstrumentReading read(CircuitState c) =>
    const ElectroSimInstrumentProjection().read(
      snapshot: const ElectroSimRuntimeEngine().evaluate(c),
      instrument: meter,
    );

  test('a disconnected 120 ohm resistor reads a real solver-backed Ω', () {
    final c = circuit([resistor('r1', 120)]);
    final result = read(c);
    expect(result.status, PhysicalInstrumentStatus.valid,
        reason: result.message);
    expect(result.result!.reading!.unit, ElectricalUnit.ohm);
    expect(result.result!.reading!.value, closeTo(120, 0.5));
    expect(c.sources, isEmpty);
    expect(c.connections, isEmpty);
    expect(c.probes, hasLength(2));
  });

  test('series 120+80 returns equivalent 200 ohms', () {
    final c = circuit(
      [resistor('r1', 120), resistor('r2', 80)],
      a: 'r1-a', b: 'r2-b',
      wires: [
        Connection(id: ConnectionId('series-1'),
          fromTerminalId: TerminalId('r1-b'),
          toTerminalId: TerminalId('r2-a')),
      ],
    );
    final result = read(c);
    expect(result.status, PhysicalInstrumentStatus.valid,
        reason: result.message);
    expect(result.result!.reading!.value, closeTo(200, 0.6));
    expect(c.connections, hasLength(1));
  });

  test('parallel 100||200 reads 66.67 ohms', () {
    final c = circuit(
      [resistor('r1', 100), resistor('r2', 200)],
      wires: [
        Connection(id: ConnectionId('parallel-a'),
          fromTerminalId: TerminalId('r1-a'),
          toTerminalId: TerminalId('r2-a')),
        Connection(id: ConnectionId('parallel-b'),
          fromTerminalId: TerminalId('r1-b'),
          toTerminalId: TerminalId('r2-b')),
      ],
    );
    final result = read(c);
    expect(result.status, PhysicalInstrumentStatus.valid,
        reason: result.message);
    expect(result.result!.reading!.value, closeTo(66.6667, 0.5));
    expect(c.connections, hasLength(2));
  });
}
