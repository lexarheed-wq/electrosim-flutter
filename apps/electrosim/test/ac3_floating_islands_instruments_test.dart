import 'package:electrosim/runtime/electrosim_instrument_projection.dart';
import 'package:electrosim/runtime/electrosim_runtime_engine.dart';
import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const engine = ElectroSimRuntimeEngine();
  const projection = ElectroSimInstrumentProjection();

  test('adding a completely unconnected AC3 resistor never disables source', () {
    final circuit = _fixture(extraFloatingLoad: true);
    final baseline = engine.evaluate(circuit);
    expect(
      baseline.solved,
      isTrue,
      reason:
          '${baseline.ac3Result?.diagnostics.map((d) => d.message).join(" | ")}',
    );
    expect(
      baseline.ac3.phaseVoltage(PhaseTag.l1)?.magnitude,
      closeTo(230, 1e-6),
    );
    expect(
      baseline.ac3.phaseVoltage(PhaseTag.l2)?.magnitude,
      closeTo(230, 1e-6),
    );
  });

  test(
    'physical AC3 voltmeter reads 230 V across source with detached load',
    () {
      final meter = InstrumentInstance(
        id: InstrumentId('v'),
        kind: InstrumentKind.voltmeter,
        mode: InstrumentMode.voltageAcRms,
      );
      final circuit = _fixture(
        extraFloatingLoad: true,
        instruments: [meter],
        probes: [
          ProbeConnection(
            id: ProbeId('v-probe'),
            instrumentId: meter.id,
            port: InstrumentPort.voltOhm,
            terminalId: TerminalId('grid-l1'),
          ),
          ProbeConnection(
            id: ProbeId('com-probe'),
            instrumentId: meter.id,
            port: InstrumentPort.common,
            terminalId: TerminalId('grid-n'),
          ),
        ],
      );
      final snapshot = engine.evaluate(circuit);
      expect(snapshot.solved, isTrue);
      final measured = projection.read(snapshot: snapshot, instrument: meter);
      expect(
        measured.status,
        PhysicalInstrumentStatus.valid,
        reason: measured.message,
      );
      expect(measured.result?.reading?.value, closeTo(230.0, .01));
    },
  );

  test('AC3 clamp ammeter measures source feeder without ERR', () {
    final clamp = InstrumentInstance(
      id: InstrumentId('clamp'),
      kind: InstrumentKind.clampAmmeter,
      mode: InstrumentMode.currentAcRms,
    );
    final circuit = _fixture(
      extraFloatingLoad: true,
      instruments: [clamp],
      probes: [
        ProbeConnection(
          id: ProbeId('clamp-1'),
          instrumentId: clamp.id,
          port: InstrumentPort.clamp,
          connectionId: ConnectionId('line-1'),
        ),
      ],
    );
    final snapshot = engine.evaluate(circuit);
    expect(snapshot.solved, isTrue);
    final measured = projection.read(snapshot: snapshot, instrument: clamp);
    expect(
      measured.status,
      PhysicalInstrumentStatus.valid,
      reason: measured.message,
    );
    expect(measured.result?.reading?.value, greaterThan(0.01));
  });

  test('AC3 series ammeter inserts physical burden and reports amps', () {
    final meter = InstrumentInstance(
      id: InstrumentId('a'),
      kind: InstrumentKind.ammeter,
      mode: InstrumentMode.currentAcRms,
      burdenResistanceOhm: 0.01,
      cutConnectionId: ConnectionId('line-1'),
    );
    final circuit = _fixture(
      extraFloatingLoad: true,
      instruments: [meter],
      probes: [
        ProbeConnection(
          id: ProbeId('amp-probe'),
          instrumentId: meter.id,
          port: InstrumentPort.amp,
          terminalId: TerminalId('grid-l1'),
        ),
        ProbeConnection(
          id: ProbeId('amp-common'),
          instrumentId: meter.id,
          port: InstrumentPort.common,
          terminalId: TerminalId('load-l1'),
        ),
      ],
    );
    final snapshot = engine.evaluate(circuit);
    expect(snapshot.solved, isTrue);
    final measured = projection.read(snapshot: snapshot, instrument: meter);
    expect(
      measured.status,
      PhysicalInstrumentStatus.valid,
      reason: measured.message,
    );
    expect(measured.result?.reading?.value, closeTo(10.0, .1));
  });
}

CircuitState _fixture({
  bool extraFloatingLoad = false,
  List<InstrumentInstance> instruments = const [],
  List<ProbeConnection> probes = const [],
}) => CircuitState(
  circuitId: CircuitId('ac3-floating-instrument-regression'),
  revision: 0,
  mode: ElectricalMode.ac3,
  sources: [
    SourceInstance(
      id: SourceId('grid'),
      modelType: 'ac3_voltage_source',
      terminals: [
        _terminal('grid-l1', 'L1', PhaseTag.l1, TerminalRole.phaseL1),
        _terminal('grid-l2', 'L2', PhaseTag.l2, TerminalRole.phaseL2),
        _terminal('grid-l3', 'L3', PhaseTag.l3, TerminalRole.phaseL3),
        _terminal('grid-n', 'N', PhaseTag.neutral, TerminalRole.neutral),
      ],
      parameters: const {'phaseVoltageRmsV': 230.0},
    ),
  ],
  components: [
    ComponentInstance(
      id: ComponentId('load'),
      modelType: 'load_wye_3p',
      terminals: [
        _terminal('load-l1', 'L1', PhaseTag.l1, TerminalRole.lineL1),
        _terminal('load-l2', 'L2', PhaseTag.l2, TerminalRole.lineL2),
        _terminal('load-l3', 'L3', PhaseTag.l3, TerminalRole.lineL3),
        _terminal('load-n', 'N', PhaseTag.neutral, TerminalRole.neutral),
      ],
      parameters: const {'resistanceOhm': 23.0, 'inductanceH': 0.0},
    ),
    if (extraFloatingLoad)
      ComponentInstance(
        id: ComponentId('floating-resistor'),
        modelType: 'resistor',
        terminals: [
          _terminal('floating-p', 'A', PhaseTag.none, TerminalRole.generic),
          _terminal('floating-n', 'B', PhaseTag.none, TerminalRole.generic),
        ],
        parameters: const {'resistanceOhm': 1000.0},
      ),
  ],
  connections: [
    _wire('line-1', 'grid-l1', 'load-l1'),
    _wire('line-2', 'grid-l2', 'load-l2'),
    _wire('line-3', 'grid-l3', 'load-l3'),
    _wire('neutral', 'grid-n', 'load-n'),
  ],
  instruments: instruments,
  probes: probes,
  settings: const {'frequencyHz': 50.0},
);

Terminal _terminal(
  String id,
  String label,
  PhaseTag phase,
  TerminalRole role,
) => Terminal(id: TerminalId(id), name: label, phase: phase, role: role);
Connection _wire(String id, String from, String to) => Connection(
  id: ConnectionId(id),
  fromTerminalId: TerminalId(from),
  toTerminalId: TerminalId(to),
);
