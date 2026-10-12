import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:electrosim/runtime/electrosim_instrument_projection.dart';
import 'package:electrosim/runtime/electrosim_runtime_engine.dart';

void main() {
  final a = Terminal(id: TerminalId('a'), name: 'A');
  final b = Terminal(id: TerminalId('b'), name: 'B');
  final c = Terminal(id: TerminalId('c'), name: 'C');
  final d = Terminal(id: TerminalId('d'), name: 'D');
  final meter = InstrumentInstance(
    id: InstrumentId('meter'),
    kind: InstrumentKind.voltmeter,
    mode: InstrumentMode.resistance,
  );
  ComponentInstance resistor(String id, Terminal one, Terminal two) =>
      ComponentInstance(
        id: ComponentId(id),
        modelType: 'resistor',
        terminals: [one, two],
        parameters: const {'resistanceOhm': 100.0},
      );
  CircuitState state({
    List<SourceInstance> sources = const [],
    List<Connection> wires = const [],
    bool second = false,
    bool active = false,
  }) => CircuitState(
    circuitId: CircuitId('ohm-safety'),
    revision: 0,
    mode: ElectricalMode.dc,
    sources: sources,
    components: [
      resistor('r1', a, b),
      if (second) resistor('r2', c, d),
      if (active)
        ComponentInstance(
          id: ComponentId('active'),
          modelType: 'pv_battery',
          terminals: [
            Terminal(id: TerminalId('battery-plus'), name: '+'),
            Terminal(id: TerminalId('battery-minus'), name: '-'),
          ],
        ),
    ],
    connections: wires,
    instruments: [meter],
    probes: [
      ProbeConnection(
        id: ProbeId('v'),
        instrumentId: meter.id,
        port: InstrumentPort.voltOhm,
        terminalId: a.id,
      ),
      ProbeConnection(
        id: ProbeId('com'),
        instrumentId: meter.id,
        port: InstrumentPort.common,
        terminalId: second ? d.id : b.id,
      ),
    ],
  );
  PhysicalInstrumentReading read(CircuitState circuit) =>
      const ElectroSimInstrumentProjection().read(
        snapshot: const ElectroSimRuntimeEngine().evaluate(circuit),
        instrument: meter,
      );

  test('power source present blocks ohmmeter even at 0 V', () {
    final source = SourceInstance(
      id: SourceId('battery'),
      modelType: 'dc_voltage_source',
      terminals: [
        Terminal(id: TerminalId('src-p'), name: '+'),
        Terminal(id: TerminalId('src-n'), name: '-'),
      ],
      parameters: const {'voltageV': 0.0},
    );
    final circuit = state(sources: [source]);
    final reading = read(circuit);
    expect(reading.status, PhysicalInstrumentStatus.unsupportedMode);
    expect(reading.result, isNull);
    expect(circuit.sources, hasLength(1));
  });

  test('disconnected resistance never reports a plausible number', () {
    final reading = read(state(second: true));
    expect(reading.status, isNot(PhysicalInstrumentStatus.valid));
    expect(reading.result, isNull);
  });

  test('probes across same ideal conductor read zero-ohm continuity', () {
    final circuit = state(
      wires: [
        Connection(
          id: ConnectionId('short'),
          fromTerminalId: a.id,
          toTerminalId: b.id,
        ),
      ],
    );
    final reading = read(circuit);
    expect(
      reading.status,
      PhysicalInstrumentStatus.valid,
      reason: reading.message,
    );
    expect(reading.result!.reading!.value, closeTo(0, 0.02));
    expect(circuit.connections, hasLength(1));
  });

  test('active component blocks ohmmeter even without SourceInstance', () {
    final result = read(state(active: true));
    expect(result.status, PhysicalInstrumentStatus.unsupportedMode);
  });
}
