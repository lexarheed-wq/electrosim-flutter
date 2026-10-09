import 'package:electrosim/runtime/electrosim_runtime_engine.dart';
import 'package:electrosim/runtime/electrosim_instrument_projection.dart';
import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const engine = ElectroSimRuntimeEngine();
  const projection = ElectroSimInstrumentProjection();

  test('PV battery DC voltmeter reads solved storage voltage at battery terminals', () {
    final meter = InstrumentInstance(
      id: InstrumentId('battery-volt'),
      kind: InstrumentKind.voltmeter,
      mode: InstrumentMode.voltageDc,
    );
    final circuit = _withMeter(_pvStorageCircuit(), meter, [
      ProbeConnection(id: ProbeId('pv-bat-plus'), instrumentId: meter.id,
          port: InstrumentPort.voltOhm,
          terminalId: TerminalId('storage-battery-pos')),
      ProbeConnection(id: ProbeId('pv-bat-minus'), instrumentId: meter.id,
          port: InstrumentPort.common,
          terminalId: TerminalId('storage-battery-neg')),
    ]);
    final snapshot = engine.evaluate(circuit);
    expect(snapshot.solved, isTrue);
    expect(snapshot.pv.batteryPresent, isTrue);
    final read = projection.read(snapshot: snapshot, instrument: meter);
    expect(read.status, PhysicalInstrumentStatus.valid, reason: read.message);
    expect(read.result?.reading?.value, closeTo(snapshot.pv.batteryVoltageV, 1e-5));
  });

  test('PV clamp reads battery terminal current from solved battery power', () {
    final meter = InstrumentInstance(
      id: InstrumentId('battery-clamp'),
      kind: InstrumentKind.clampAmmeter,
      mode: InstrumentMode.currentDc,
      maximumCurrentA: 100,
    );
    final circuit = _withMeter(_pvStorageCircuit(), meter, [
      ProbeConnection(id: ProbeId('pv-bat-cable'), instrumentId: meter.id,
        port: InstrumentPort.clamp,
        connectionId: ConnectionId('storage-battery-pos-wire')),
    ]);
    final snapshot = engine.evaluate(circuit);
    expect(snapshot.solved, isTrue);
    final read = projection.read(snapshot: snapshot, instrument: meter);
    expect(read.status, PhysicalInstrumentStatus.valid, reason: read.message);
    expect(read.result?.reading?.value,
        closeTo((snapshot.pv.batteryPowerW / snapshot.pv.batteryVoltageV).abs(),
            1e-5));
  });
}

CircuitState _withMeter(CircuitState base, InstrumentInstance meter,
    List<ProbeConnection> probes) => CircuitState(
  circuitId: base.circuitId,
  revision: base.revision,
  mode: base.mode,
  components: base.components,
  sources: base.sources,
  connections: base.connections,
  instruments: [meter],
  probes: probes,
  settings: base.settings,
  metadata: base.metadata,
);

Connection _wire(String id, String from, String to, PhaseTag phase) =>
    Connection(
      id: ConnectionId(id),
      fromTerminalId: TerminalId(from),
      toTerminalId: TerminalId(to),
      phase: phase,
    );

CircuitState _pvStorageCircuit({
  double irradianceWm2 = 1000.0,
  double loadPowerAt230W = 1000.0,
  double initialSoc = 0.60,
  double minSoc = 0.10,
  double maxSoc = 0.95,
  bool includeController = true,
  bool includeBattery = true,
  bool includeInverter = true,
  bool includeDcLamp = false,
  bool disconnectInverterDc = false,
  String controllerType = 'mppt',
  double controllerMaxPvInputVoltageV = 450.0,
  double controllerOutputVoltageV = 48.0,
}) {
  final double resistance = 230.0 * 230.0 / loadPowerAt230W;
  final ComponentInstance inverter = ComponentInstance(
    id: ComponentId('storage-inv'),
    modelType: 'pv_inverter',
    terminals: <Terminal>[
      Terminal(
        id: TerminalId('storage-inv-dc-pos'),
        name: 'DC+',
        role: TerminalRole.positive,
        phase: PhaseTag.dcPositive,
      ),
      Terminal(
        id: TerminalId('storage-inv-dc-neg'),
        name: 'DC-',
        role: TerminalRole.negative,
        phase: PhaseTag.dcNegative,
      ),
      Terminal(
        id: TerminalId('storage-inv-l'),
        name: 'L',
        role: TerminalRole.line,
        phase: PhaseTag.l1,
      ),
      Terminal(
        id: TerminalId('storage-inv-n'),
        name: 'N',
        role: TerminalRole.neutral,
        phase: PhaseTag.neutral,
      ),
    ],
    parameters: const <String, Object?>{
      'minDcVoltageV': 40.0,
      'maxDcVoltageV': 60.0,
      'nominalAcVoltageV': 230.0,
      'ratedAcPowerW': 3500.0,
      'efficiency': 0.95,
    },
  );
  final ComponentInstance controller = ComponentInstance(
    id: ComponentId('storage-controller'),
    modelType: 'pv_controller',
    terminals: <Terminal>[
      Terminal(
        id: TerminalId('storage-controller-pv-pos'),
        name: 'PV+',
        role: TerminalRole.positive,
        phase: PhaseTag.dcPositive,
      ),
      Terminal(
        id: TerminalId('storage-controller-pv-neg'),
        name: 'PV-',
        role: TerminalRole.negative,
        phase: PhaseTag.dcNegative,
      ),
      Terminal(
        id: TerminalId('storage-controller-bus-pos'),
        name: 'BAT+',
        role: TerminalRole.positive,
        phase: PhaseTag.dcPositive,
      ),
      Terminal(
        id: TerminalId('storage-controller-bus-neg'),
        name: 'BAT-',
        role: TerminalRole.negative,
        phase: PhaseTag.dcNegative,
      ),
    ],
    parameters: <String, Object?>{
      'outputVoltageV': controllerOutputVoltageV,
      'maxOutputCurrentA': 60.0,
      'efficiency': 0.97,
      'controllerType': controllerType,
      'maxPvInputVoltageV': controllerMaxPvInputVoltageV,
    },
  );
  final ComponentInstance battery = ComponentInstance(
    id: ComponentId('storage-battery'),
    modelType: 'pv_battery',
    terminals: <Terminal>[
      Terminal(
        id: TerminalId('storage-battery-pos'),
        name: '+',
        role: TerminalRole.positive,
        phase: PhaseTag.dcPositive,
      ),
      Terminal(
        id: TerminalId('storage-battery-neg'),
        name: '-',
        role: TerminalRole.negative,
        phase: PhaseTag.dcNegative,
      ),
    ],
    parameters: <String, Object?>{
      'nominalVoltageV': 48.0,
      'capacityAh': 100.0,
      'initialSoc': initialSoc,
      'minSoc': minSoc,
      'maxSoc': maxSoc,
      'maxChargeCurrentA': 30.0,
      'maxDischargeCurrentA': 60.0,
      'chargeEfficiency': 0.95,
      'dischargeEfficiency': 0.95,
    },
  );
  final ComponentInstance load = ComponentInstance(
    id: ComponentId('storage-load'),
    modelType: 'pv_resistive_load',
    terminals: <Terminal>[
      Terminal(
        id: TerminalId('storage-load-l'),
        name: 'L',
        role: TerminalRole.line,
        phase: PhaseTag.l1,
      ),
      Terminal(
        id: TerminalId('storage-load-n'),
        name: 'N',
        role: TerminalRole.neutral,
        phase: PhaseTag.neutral,
      ),
    ],
    parameters: <String, Object?>{'resistanceOhm': resistance},
  );

  final ComponentInstance dcLamp = ComponentInstance(
    id: ComponentId('storage-dc-lamp'),
    modelType: 'lamp',
    terminals: <Terminal>[
      Terminal(
        id: TerminalId('storage-dc-lamp-plus'),
        name: '+',
        role: TerminalRole.positive,
        phase: PhaseTag.dcPositive,
      ),
      Terminal(
        id: TerminalId('storage-dc-lamp-minus'),
        name: '-',
        role: TerminalRole.negative,
        phase: PhaseTag.dcNegative,
      ),
    ],
    parameters: const <String, Object?>{'resistanceOhm': 48.0},
  );
  final List<ComponentInstance> components = <ComponentInstance>[
    if (includeDcLamp) dcLamp,
    if (includeController) controller,
    if (includeBattery) battery,
    if (includeInverter) inverter,
    if (includeInverter) load,
  ];
  final List<Connection> connections = <Connection>[
    if (includeController) ...<Connection>[
      _wire(
        'storage-pv-pos',
        'storage-pv-source-pos',
        'storage-controller-pv-pos',
        PhaseTag.dcPositive,
      ),
      _wire(
        'storage-pv-neg',
        'storage-pv-source-neg',
        'storage-controller-pv-neg',
        PhaseTag.dcNegative,
      ),
      if (includeInverter && !disconnectInverterDc)
        _wire(
          'storage-bus-pos',
          'storage-controller-bus-pos',
          'storage-inv-dc-pos',
          PhaseTag.dcPositive,
        )
      else if (includeBattery)
        _wire(
          'storage-bus-pos-battery',
          'storage-controller-bus-pos',
          'storage-battery-pos',
          PhaseTag.dcPositive,
        ),
      if (includeInverter && !disconnectInverterDc)
        _wire(
          'storage-bus-neg',
          'storage-controller-bus-neg',
          'storage-inv-dc-neg',
          PhaseTag.dcNegative,
        )
      else if (includeBattery)
        _wire(
          'storage-bus-neg-battery',
          'storage-controller-bus-neg',
          'storage-battery-neg',
          PhaseTag.dcNegative,
        ),
    ] else ...<Connection>[
      _wire(
        'storage-direct-pos',
        'storage-pv-source-pos',
        'storage-inv-dc-pos',
        PhaseTag.dcPositive,
      ),
      _wire(
        'storage-direct-neg',
        'storage-pv-source-neg',
        'storage-inv-dc-neg',
        PhaseTag.dcNegative,
      ),
    ],
    if (includeBattery && includeInverter && !disconnectInverterDc) ...<Connection>[
      _wire(
        'storage-battery-pos-wire',
        'storage-battery-pos',
        'storage-inv-dc-pos',
        PhaseTag.dcPositive,
      ),
      _wire(
        'storage-battery-neg-wire',
        'storage-battery-neg',
        'storage-inv-dc-neg',
        PhaseTag.dcNegative,
      ),
    ],
    if (includeDcLamp) ...<Connection>[
      _wire('storage-dc-load-pos', 'storage-dc-lamp-plus',
        'storage-controller-bus-pos', PhaseTag.dcPositive),
      _wire('storage-dc-load-neg', 'storage-dc-lamp-minus',
        'storage-controller-bus-neg', PhaseTag.dcNegative),
    ],
    if (includeInverter)
      _wire('storage-ac-l', 'storage-inv-l', 'storage-load-l', PhaseTag.l1),
    if (includeInverter)
      _wire('storage-ac-n', 'storage-inv-n', 'storage-load-n', PhaseTag.neutral),
  ];

  return CircuitState(
    circuitId: CircuitId('pv-storage-test'),
    revision: 0,
    mode: ElectricalMode.pv,
    components: components,
    connections: connections,
    sources: <SourceInstance>[
      SourceInstance(
        id: SourceId('storage-pv-source'),
        modelType: 'pv_array',
        terminals: <Terminal>[
          Terminal(
            id: TerminalId('storage-pv-source-pos'),
            name: '+',
            role: TerminalRole.positive,
            phase: PhaseTag.dcPositive,
          ),
          Terminal(
            id: TerminalId('storage-pv-source-neg'),
            name: '-',
            role: TerminalRole.negative,
            phase: PhaseTag.dcNegative,
          ),
        ],
        parameters: const <String, Object?>{
          'mppVoltageV': 360.0,
          'mppCurrentA': 10.0,
          'powerTemperatureCoefficientPerC': 0.0,
          'voltageTemperatureCoefficientPerC': 0.0,
        },
      ),
    ],
    settings: <String, Object?>{
      'irradianceWm2': irradianceWm2,
      'shadingPct': 0.0,
      'cellTemperatureC': 25.0,
    },
  );
}
