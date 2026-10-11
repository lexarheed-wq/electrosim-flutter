import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:electrosim/runtime/electrosim_instrument_projection.dart';
import 'package:electrosim/runtime/electrosim_runtime_engine.dart';
import 'package:flutter_test/flutter_test.dart';

CircuitState fixture({bool reversed = false, bool voltageMeter = false}) {
  Terminal t(String id) => Terminal(id: TerminalId(id), name: id);
  final m1 = InstrumentInstance(
    id: InstrumentId('A1'),
    kind: InstrumentKind.ammeter,
    mode: InstrumentMode.currentDc,
    burdenResistanceOhm: 12,
    cutConnectionId: ConnectionId('feed'),
  );
  final m2 = InstrumentInstance(
    id: InstrumentId('A2'),
    kind: InstrumentKind.ammeter,
    mode: InstrumentMode.currentDc,
    burdenResistanceOhm: 12,
    cutConnectionId: ConnectionId('return'),
  );
  final v = InstrumentInstance(
    id: InstrumentId('V'),
    kind: InstrumentKind.voltmeter,
    mode: InstrumentMode.voltageDc,
  );
  ProbeConnection p(
    String id,
    InstrumentId meter,
    InstrumentPort port,
    String target,
  ) => ProbeConnection(
    id: ProbeId(id),
    instrumentId: meter,
    port: port,
    terminalId: TerminalId(target),
  );
  return CircuitState(
    circuitId: CircuitId('shared-meter-solver'),
    revision: 0,
    mode: ElectricalMode.dc,
    sources: [
      SourceInstance(
        id: SourceId('S'),
        modelType: 'dc_voltage_source',
        terminals: [t('p'), t('n')],
        parameters: const {'voltageV': 24},
      ),
    ],
    components: [
      ComponentInstance(
        id: ComponentId('R'),
        modelType: 'resistor',
        terminals: [t('a'), t('b')],
        parameters: const {'resistanceOhm': 24},
      ),
    ],
    connections: [
      Connection(
        id: ConnectionId('feed'),
        fromTerminalId: TerminalId('p'),
        toTerminalId: TerminalId('a'),
      ),
      Connection(
        id: ConnectionId('return'),
        fromTerminalId: TerminalId('b'),
        toTerminalId: TerminalId('n'),
      ),
    ],
    instruments: [m1, m2, if (voltageMeter) v],
    probes: [
      p('a1', m1.id, InstrumentPort.amp, reversed ? 'a' : 'p'),
      p('c1', m1.id, InstrumentPort.common, reversed ? 'p' : 'a'),
      p('a2', m2.id, InstrumentPort.amp, 'b'),
      p('c2', m2.id, InstrumentPort.common, 'n'),
      if (voltageMeter) p('v', v.id, InstrumentPort.voltOhm, 'a'),
      if (voltageMeter) p('c', v.id, InstrumentPort.common, 'b'),
    ],
  );
}

void main() {
  const engine = ElectroSimRuntimeEngine();
  const projection = ElectroSimInstrumentProjection();
  test('physical power cables do not bypass connected series meters', () {
    final circuit = fixture();
    final serialized = circuit.toJsonString();
    expect(SeriesMeterWiring.openConnectionIds(circuit), {
      ConnectionId('feed'),
      ConnectionId('return'),
    });
    expect(SeriesMeterWiring.openConnectionIds(fixture(reversed: true)), {
      ConnectionId('feed'),
      ConnectionId('return'),
    });
    expect(circuit.toJsonString(), serialized);
  });
  test('both series ammeters read the same globally solved current', () {
    final circuit = fixture();
    final snapshot = engine.evaluate(circuit);
    expect(snapshot.solved, isTrue);
    final current = snapshot.dcResult!.branchResults
        .firstWhere((b) => b.id == 'source:S')
        .currentA!
        .abs();
    expect(current, closeTo(24 / (24 + 12 + 12), 1e-6));
    for (final meter in circuit.instruments) {
      final result = projection.read(snapshot: snapshot, instrument: meter);
      expect(result.status, PhysicalInstrumentStatus.valid);
      expect(result.result!.reading!.value, closeTo(current, 1e-6));
    }
    expect(circuit.toJsonString(), isNot(contains('g5-amperemeter-burden')));
  });
  test('swapping A and COM reverses the signed DC reading', () {
    final circuit = fixture(reversed: true);
    final result = projection.read(
      snapshot: engine.evaluate(circuit),
      instrument: circuit.instruments.first,
    );
    expect(result.result!.reading!.value, closeTo(-0.5, 1e-6));
  });
  test('voltmeter reads the load voltage including both ammeter burdens', () {
    final circuit = fixture(voltageMeter: true);
    final result = projection.read(
      snapshot: engine.evaluate(circuit),
      instrument: circuit.instruments.last,
    );
    expect(result.status, PhysicalInstrumentStatus.valid);
    expect(result.result!.reading!.value, closeTo(12, 1e-4));
  });
}
