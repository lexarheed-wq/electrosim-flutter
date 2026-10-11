import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:electrosim/runtime/electrosim_instrument_projection.dart';
import 'package:electrosim/runtime/electrosim_runtime_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final srcP = Terminal(id: TerminalId('plus'), name: '+',
      phase: PhaseTag.dcPositive);
  final srcN = Terminal(id: TerminalId('minus'), name: '-',
      phase: PhaseTag.dcNegative);
  final loadA = Terminal(id: TerminalId('load-a'), name: 'A');
  final loadB = Terminal(id: TerminalId('load-b'), name: 'B');

  CircuitState build({double resistanceOhm = 24.0,
      bool wrongProbe = false, bool blownFuse = false}) {
    final source = SourceInstance(
      id: SourceId('src24'), modelType: 'dc_voltage_source',
      terminals: [srcP, srcN],
      parameters: const {'voltageV': 24.0},
    );
    final load = ComponentInstance(
      id: ComponentId('load24'), modelType: 'resistor',
      terminals: [loadA, loadB],
      parameters: {'resistanceOhm': resistanceOhm},
    );
    final meter = InstrumentInstance(
      id: InstrumentId('fused-a'), kind: InstrumentKind.ammeter,
      mode: InstrumentMode.currentDc,
      burdenResistanceOhm: 0.01, fuseRatingA: 10.0,
      maximumCurrentA: 10.0, fuseBlown: blownFuse,
      cutConnectionId: ConnectionId('cut-measured-wire'),
    );
    return CircuitState(
      circuitId: CircuitId('fused-ammeter-g5-02'),
      revision: 1, mode: ElectricalMode.dc,
      sources: [source], components: [load],
      connections: [
        Connection(
          id: ConnectionId('cut-measured-wire'),
          fromTerminalId: srcP.id, toTerminalId: loadA.id,
        ),
        Connection(
          id: ConnectionId('return-wire'),
          fromTerminalId: loadB.id, toTerminalId: srcN.id,
        ),
      ],
      instruments: [meter],
      probes: [
        ProbeConnection(
          id: ProbeId('probe-current'),
          instrumentId: meter.id,
          port: InstrumentPort.amp,
          terminalId: wrongProbe ? loadB.id : srcP.id,
        ),
        ProbeConnection(
          id: ProbeId('probe-common'),
          instrumentId: meter.id,
          port: InstrumentPort.common,
          terminalId: loadA.id,
        ),
      ],
    );
  }

  PhysicalInstrumentReading read(CircuitState c) =>
      const ElectroSimInstrumentProjection().read(
        snapshot: const ElectroSimRuntimeEngine().evaluate(c),
        instrument: c.instruments.single,
      );

  test('A/COM insertion in series includes real burden resistance', () {
    final circuit = build();
    final result = read(circuit);
    expect(result.status, PhysicalInstrumentStatus.valid,
        reason: result.message);
    expect(result.result!.reading!.unit, ElectricalUnit.ampere);
    expect(result.result!.reading!.value,
        closeTo(24 / (24 + 0.01), 0.005));
    expect(circuit.connections, hasLength(2),
        reason: 'No synthetic power wire may be stored');
    expect(circuit.probes, hasLength(2),
        reason: 'Both measurement leads remain probes');
    expect(circuit.components, hasLength(1),
        reason: 'The temporary burden is not saved');
  });

  test('misplaced probe is not allowed to report current', () {
    final measured = read(build(wrongProbe: true));
    expect(measured.status, PhysicalInstrumentStatus.invalidWiring);
    expect(measured.result, isNull);
  });

  test('fuse rating exceeded reports FUSE, not a plausible reading', () {
    final measured = read(build(resistanceOhm: 1));
    expect(measured.status, PhysicalInstrumentStatus.blownFuse);
    expect(measured.result, isNull);
  });

  test('existing blown fuse is never bypassed by the series projection', () {
    final measured = read(build(blownFuse: true));
    expect(measured.status, PhysicalInstrumentStatus.blownFuse);
    expect(measured.result, isNull);
  });
}
