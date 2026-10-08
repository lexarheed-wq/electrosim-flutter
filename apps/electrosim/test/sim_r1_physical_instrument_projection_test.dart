import 'package:electrosim/runtime/electrosim_instrument_projection.dart';
import 'package:electrosim/runtime/electrosim_runtime_engine.dart';
import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/regression_fixture.dart';

CircuitState withMeter({
  required InstrumentInstance instrument,
  required List<ProbeConnection> probes,
}) {
  final CircuitState base = buildRegressionFixtureCircuit();
  return CircuitState(
    circuitId: base.circuitId,
    revision: base.revision,
    mode: base.mode,
    components: base.components,
    sources: base.sources,
    connections: base.connections,
    settings: base.settings,
    metadata: base.metadata,
    instruments: <InstrumentInstance>[instrument],
    probes: probes,
  );
}

void main() {
  const ElectroSimRuntimeEngine engine = ElectroSimRuntimeEngine();
  const ElectroSimInstrumentProjection projection =
      ElectroSimInstrumentProjection();

  test('SIM-R1 loaded voltmeter measures DC without changing authored wires', () {
    final InstrumentInstance voltmeter = InstrumentInstance(
      id: InstrumentId('meter-v'),
      kind: InstrumentKind.voltmeter,
      mode: InstrumentMode.voltageDc,
      inputImpedanceOhm: 10000000,
    );
    final CircuitState circuit = withMeter(
      instrument: voltmeter,
      probes: <ProbeConnection>[
        ProbeConnection(
          id: ProbeId('probe-positive'),
          instrumentId: voltmeter.id,
          port: InstrumentPort.voltOhm,
          terminalId: TerminalId('lamp-in'),
        ),
        ProbeConnection(
          id: ProbeId('probe-common'),
          instrumentId: voltmeter.id,
          port: InstrumentPort.common,
          terminalId: TerminalId('lamp-out'),
        ),
      ],
    );
    final String original = circuit.toJsonString();
    final ElectroSimRuntimeSnapshot baseline = engine.evaluate(circuit);
    final PhysicalInstrumentReading result = projection.read(
      snapshot: baseline, instrument: voltmeter);
    expect(baseline.solved, isTrue);
    expect(result.status, PhysicalInstrumentStatus.valid);
    expect(result.result?.reading?.value, closeTo(24.0, 0.03));
    expect(circuit.toJsonString(), original);
    expect(circuit.connections, hasLength(3));
  });

  test('SIM-R1 inline ammeter inserts burden, not a fake parallel short', () {
    final InstrumentInstance meter = InstrumentInstance(
      id: InstrumentId('meter-a'),
      kind: InstrumentKind.ammeter,
      mode: InstrumentMode.currentDc,
      burdenResistanceOhm: 0.01,
      cutConnectionId: ConnectionId('wire-2'),
    );
    final CircuitState circuit = withMeter(
      instrument: meter,
      probes: <ProbeConnection>[
        ProbeConnection(
          id: ProbeId('probe-a'),
          instrumentId: meter.id,
          port: InstrumentPort.amp,
          terminalId: TerminalId('switch-out'),
        ),
        ProbeConnection(
          id: ProbeId('probe-common'),
          instrumentId: meter.id,
          port: InstrumentPort.common,
          terminalId: TerminalId('lamp-in'),
        ),
      ],
    );
    final PhysicalInstrumentReading result = projection.read(
      snapshot: engine.evaluate(circuit), instrument: meter);
    expect(result.status, PhysicalInstrumentStatus.valid);
    expect(result.result?.reading?.value, closeTo(1.0, 0.005));
    expect(circuit.connections, hasLength(3));
  });

  test('SIM-R1 wrong V/COM ports do not invent a measurement', () {
    final InstrumentInstance meter = InstrumentInstance(
      id: InstrumentId('meter-v'),
      kind: InstrumentKind.voltmeter,
      mode: InstrumentMode.voltageDc,
    );
    final CircuitState circuit = withMeter(
      instrument: meter,
      probes: <ProbeConnection>[
        ProbeConnection(
          id: ProbeId('probe-a'),
          instrumentId: meter.id,
          port: InstrumentPort.amp,
          terminalId: TerminalId('lamp-in'),
        ),
      ],
    );
    final PhysicalInstrumentReading result = projection.read(
      snapshot: engine.evaluate(circuit), instrument: meter);
    expect(result.status, PhysicalInstrumentStatus.invalidWiring);
    expect(result.result, isNull);
  });

  test('SIM-R1 exhausted ammeter fuse blocks current measurement', () {
    final InstrumentInstance meter = InstrumentInstance(
      id: InstrumentId('meter-a'),
      kind: InstrumentKind.ammeter,
      mode: InstrumentMode.currentDc,
      fuseBlown: true,
    );
    final CircuitState circuit = withMeter(instrument: meter, probes: []);
    final PhysicalInstrumentReading result = projection.read(
      snapshot: engine.evaluate(circuit), instrument: meter);
    expect(result.status, PhysicalInstrumentStatus.blownFuse);
    expect(result.result, isNull);
  });
}
