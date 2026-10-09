import 'package:electrosim/runtime/electrosim_runtime_engine.dart';
import 'package:electrosim/runtime/electrosim_instrument_projection.dart';
import 'package:electrosim/f9_source_voltage_readout.dart';
import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const engine = ElectroSimRuntimeEngine();
  const projection = ElectroSimInstrumentProjection();

  test('AC1 source stays 230 V with an unattached receiving component', () {
    final circuit = _ac1(connectedLoad: false);
    final snapshot = engine.evaluate(circuit);
    expect(snapshot.solved, isTrue,
        reason: '${snapshot.ac1Result?.diagnostics.map((d) => d.message).join(" | ")}');
    final readout = F9SourceVoltageReadout.voltageV(
      snapshot, circuit.sources.single, simulationRunning: true,
    );
    expect(readout, closeTo(230, 1e-6));
    final measured = snapshot.measureAcVoltage(
      positiveProbe: TerminalId('l'), negativeProbe: TerminalId('n'));
    expect(measured.isValid, isTrue, reason: measured.message);
    expect(measured.reading?.value, closeTo(230, 1e-5));
  });

  test('AC1 connected receiver and extra floating part preserve volt and amps', () {
    final circuit = _ac1(connectedLoad: true);
    final snapshot = engine.evaluate(circuit);
    expect(snapshot.solved, isTrue,
        reason: '${snapshot.ac1Result?.diagnostics.map((d) => d.message).join(" | ")}');
    expect(snapshot.ac1.branch('component:load').current!.magnitude,
      closeTo(5.0, 1e-6));
    final volt = InstrumentInstance(
      id: InstrumentId('v'), kind: InstrumentKind.voltmeter,
      mode: InstrumentMode.voltageAcRms,
    );
    final instrumented = _ac1(connectedLoad: true,
        instruments: [volt],
        probes: [
          ProbeConnection(id: ProbeId('v-l'), instrumentId: volt.id,
            port: InstrumentPort.voltOhm, terminalId: TerminalId('l')),
          ProbeConnection(id: ProbeId('v-n'), instrumentId: volt.id,
            port: InstrumentPort.common, terminalId: TerminalId('n')),
        ]);
    final measurement = projection.read(
      snapshot: engine.evaluate(instrumented), instrument: volt);
    expect(measurement.status, PhysicalInstrumentStatus.valid,
        reason: measurement.message);
    expect(measurement.result?.reading?.value, closeTo(230, .05));
  });

  test('PV disconnected voltmeter/ammeter show wiring required, not N/A', () {
    final v = InstrumentInstance(id: InstrumentId('v'),
      kind: InstrumentKind.voltmeter, mode: InstrumentMode.voltageDc);
    final a = InstrumentInstance(id: InstrumentId('a'),
      kind: InstrumentKind.ammeter, mode: InstrumentMode.currentDc);
    final circuit = _pvWithMeters([v, a], []);
    final snapshot = engine.evaluate(circuit);
    expect(snapshot.solved, isTrue);
    expect(projection.read(snapshot: snapshot, instrument: v).status,
        PhysicalInstrumentStatus.invalidWiring);
    expect(projection.read(snapshot: snapshot, instrument: a).status,
        PhysicalInstrumentStatus.invalidWiring);
  });

  test('PV source probe reads real solved 400 V, no invented value', () {
    final v = InstrumentInstance(id: InstrumentId('v'),
      kind: InstrumentKind.voltmeter, mode: InstrumentMode.voltageDc);
    final circuit = _pvWithMeters([v], [
      ProbeConnection(id: ProbeId('v-pos'), instrumentId: v.id,
        port: InstrumentPort.voltOhm, terminalId: TerminalId('pv-pos')),
      ProbeConnection(id: ProbeId('v-neg'), instrumentId: v.id,
        port: InstrumentPort.common, terminalId: TerminalId('pv-neg')),
    ]);
    final snapshot = engine.evaluate(circuit);
    expect(snapshot.solved, isTrue);
    final read = projection.read(snapshot: snapshot, instrument: v);
    expect(read.status, PhysicalInstrumentStatus.valid, reason: read.message);
    expect(read.result?.reading?.value, closeTo(400, 1e-6));
  });

  test('PV clamp reads solved source line current, not arbitrary cable', () {
    final meter = InstrumentInstance(id: InstrumentId('clamp'),
        kind: InstrumentKind.clampAmmeter, mode: InstrumentMode.currentDc);
    final circuit = _pvWithMeters([meter], [
      ProbeConnection(id: ProbeId('clamp-1'), instrumentId: meter.id,
        port: InstrumentPort.clamp, connectionId: ConnectionId('dc-pos')),
    ]);
    final snapshot = engine.evaluate(circuit);
    expect(snapshot.solved, isTrue);
    final reading = projection.read(snapshot: snapshot, instrument: meter);
    expect(reading.status, PhysicalInstrumentStatus.valid,
        reason: reading.message);
    expect(reading.result?.reading?.value,
        closeTo(snapshot.pv.pvDrawnCurrentA, 1e-5));
  });
}

CircuitState _ac1({required bool connectedLoad,
  List<InstrumentInstance> instruments = const [],
  List<ProbeConnection> probes = const [],
}) => CircuitState(
  circuitId: CircuitId('multi-mode-ac1'),
  revision: 3,
  mode: ElectricalMode.ac1,
  sources: [
    SourceInstance(id: SourceId('s'), modelType: 'ac_voltage_source',
      terminals: [
        Terminal(id: TerminalId('l'), name: 'L', phase: PhaseTag.l1,
          role: TerminalRole.line),
        Terminal(id: TerminalId('n'), name: 'N', phase: PhaseTag.neutral,
          role: TerminalRole.neutral),
      ],
      parameters: const {'voltageRmsV': 230.0}),
  ],
  components: [
    ComponentInstance(id: ComponentId('load'), modelType: 'resistor',
      terminals: [
        Terminal(id: TerminalId('load-a'), name: 'A'),
        Terminal(id: TerminalId('load-b'), name: 'B'),
      ],
      parameters: const {'resistanceOhm': 46.0}),
    ComponentInstance(id: ComponentId('floating'), modelType: 'resistor',
      terminals: [
        Terminal(id: TerminalId('floating-a'), name: 'A'),
        Terminal(id: TerminalId('floating-b'), name: 'B'),
      ],
      parameters: const {'resistanceOhm': 30.0}),
  ],
  connections: [
    if (connectedLoad) ...[
      Connection(id: ConnectionId('line'), fromTerminalId: TerminalId('l'),
        toTerminalId: TerminalId('load-a')),
      Connection(id: ConnectionId('neutral'),
        fromTerminalId: TerminalId('load-b'),
        toTerminalId: TerminalId('n')),
    ],
  ],
  instruments: instruments,
  probes: probes,
  settings: const {'frequencyHz': 50.0},
);

CircuitState _pvWithMeters(List<InstrumentInstance> instruments,
    List<ProbeConnection> probes) {
  final base = _pvCircuit(loadPowerAt230W: 2000);
  return CircuitState(
    circuitId: base.circuitId,
    revision: base.revision,
    mode: base.mode,
    sources: base.sources,
    components: base.components,
    connections: base.connections,
    settings: base.settings,
    instruments: instruments,
    probes: probes,
  );
}

CircuitState _pvCircuit({
  double loadPowerAt230W = 1000.0,
  bool disconnectDcPositive = false,
}) {
  final double resistance = 230.0 * 230.0 / loadPowerAt230W;

  final SourceInstance array = SourceInstance(
    id: SourceId('pv'),
    modelType: 'pv_array',
    terminals: <Terminal>[
      Terminal(
        id: TerminalId('pv-pos'),
        name: '+',
        role: TerminalRole.positive,
        phase: PhaseTag.dcPositive,
      ),
      Terminal(
        id: TerminalId('pv-neg'),
        name: '-',
        role: TerminalRole.negative,
        phase: PhaseTag.dcNegative,
      ),
    ],
    parameters: const <String, Object?>{
      'mppVoltageV': 400.0,
      'mppCurrentA': 10.0,
      'powerTemperatureCoefficientPerC': 0.0,
      'voltageTemperatureCoefficientPerC': 0.0,
    },
  );

  final ComponentInstance inverter = ComponentInstance(
    id: ComponentId('inv'),
    modelType: 'pv_inverter',
    terminals: <Terminal>[
      Terminal(
        id: TerminalId('inv-dc-pos'),
        name: 'DC+',
        role: TerminalRole.positive,
        phase: PhaseTag.dcPositive,
      ),
      Terminal(
        id: TerminalId('inv-dc-neg'),
        name: 'DC-',
        role: TerminalRole.negative,
        phase: PhaseTag.dcNegative,
      ),
      Terminal(
        id: TerminalId('inv-l'),
        name: 'L',
        role: TerminalRole.line,
        phase: PhaseTag.l1,
      ),
      Terminal(
        id: TerminalId('inv-n'),
        name: 'N',
        role: TerminalRole.neutral,
        phase: PhaseTag.neutral,
      ),
    ],
    parameters: const <String, Object?>{
      'minDcVoltageV': 300.0,
      'maxDcVoltageV': 500.0,
      'nominalAcVoltageV': 230.0,
      'ratedAcPowerW': 3500.0,
      'efficiency': 0.95,
    },
  );

  final ComponentInstance load = ComponentInstance(
    id: ComponentId('load'),
    modelType: 'pv_resistive_load',
    terminals: <Terminal>[
      Terminal(
        id: TerminalId('load-l'),
        name: 'L',
        role: TerminalRole.line,
        phase: PhaseTag.l1,
      ),
      Terminal(
        id: TerminalId('load-n'),
        name: 'N',
        role: TerminalRole.neutral,
        phase: PhaseTag.neutral,
      ),
    ],
    parameters: <String, Object?>{'resistanceOhm': resistance},
  );

  return CircuitState(
    circuitId: CircuitId('f17-r10-pv'),
    revision: 10,
    mode: ElectricalMode.pv,
    sources: <SourceInstance>[array],
    components: <ComponentInstance>[inverter, load],
    connections: <Connection>[
      if (!disconnectDcPositive)
        Connection(
          id: ConnectionId('dc-pos'),
          fromTerminalId: TerminalId('pv-pos'),
          toTerminalId: TerminalId('inv-dc-pos'),
          phase: PhaseTag.dcPositive,
        ),
      Connection(
        id: ConnectionId('dc-neg'),
        fromTerminalId: TerminalId('pv-neg'),
        toTerminalId: TerminalId('inv-dc-neg'),
        phase: PhaseTag.dcNegative,
      ),
      Connection(
        id: ConnectionId('ac-l'),
        fromTerminalId: TerminalId('inv-l'),
        toTerminalId: TerminalId('load-l'),
        phase: PhaseTag.l1,
      ),
      Connection(
        id: ConnectionId('ac-n'),
        fromTerminalId: TerminalId('inv-n'),
        toTerminalId: TerminalId('load-n'),
        phase: PhaseTag.neutral,
      ),
    ],
    settings: const <String, Object?>{
      'irradianceWm2': 1000.0,
      'cellTemperatureC': 25.0,
    },
  );
}
