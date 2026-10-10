import 'package:electrosim/f9_component_palette.dart';
import 'package:electrosim/runtime/electrosim_instrument_projection.dart';
import 'package:electrosim/runtime/electrosim_runtime_engine.dart';
import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:flutter_test/flutter_test.dart';

const ElectroSimRuntimeEngine engine = ElectroSimRuntimeEngine();
const ElectroSimInstrumentProjection meters = ElectroSimInstrumentProjection();

Terminal terminal(String id, {PhaseTag phase = PhaseTag.none}) =>
    Terminal(id: TerminalId(id), name: id, phase: phase);

Connection wire(String id, String a, String b) => Connection(
  id: ConnectionId(id),
  fromTerminalId: TerminalId(a),
  toTerminalId: TerminalId(b),
);

const batteryParams = <String, Object?>{
  'nominalVoltageV': 48.0,
  'internalResistanceOhm': 0.08,
  'capacityAh': 100.0,
  'initialSoc': 0.60,
  'minSoc': 0.10,
  'maxSoc': 0.95,
  'maxChargeCurrentA': 30.0,
  'maxDischargeCurrentA': 60.0,
  'chargeEfficiency': 0.95,
  'dischargeEfficiency': 0.95,
};

CircuitState batteryLoad({
  required ElectricalMode mode,
  required InstrumentInstance meter,
  required List<ProbeConnection> probes,
}) => CircuitState(
  circuitId: CircuitId('battery-meter-${mode.name}'),
  revision: 1,
  mode: mode,
  components: <ComponentInstance>[
    ComponentInstance(
      id: ComponentId('battery'),
      modelType: 'pv_battery',
      terminals: <Terminal>[
        terminal('battery-plus', phase: PhaseTag.dcPositive),
        terminal('battery-minus', phase: PhaseTag.dcNegative),
      ],
      parameters: batteryParams,
    ),
    ComponentInstance(
      id: ComponentId('resistor'),
      modelType: 'resistor',
      terminals: <Terminal>[terminal('resistor-a'), terminal('resistor-b')],
      parameters: const <String, Object?>{'resistanceOhm': 48.0},
    ),
  ],
  connections: <Connection>[
    wire('feed', 'battery-plus', 'resistor-a'),
    wire('return', 'resistor-b', 'battery-minus'),
  ],
  instruments: <InstrumentInstance>[meter],
  probes: probes,
);

InstrumentInstance voltmeter() => InstrumentInstance(
  id: InstrumentId('v1'),
  kind: InstrumentKind.voltmeter,
  mode: InstrumentMode.voltageDc,
);

InstrumentInstance ammeter() => InstrumentInstance(
  id: InstrumentId('a1'),
  kind: InstrumentKind.ammeter,
  mode: InstrumentMode.currentDc,
  cutConnectionId: ConnectionId('feed'),
);

ProbeConnection lead(
  String id,
  InstrumentInstance meter,
  InstrumentPort port,
  String target,
) => ProbeConnection(
  id: ProbeId(id),
  instrumentId: meter.id,
  port: port,
  terminalId: TerminalId(target),
);

F9PaletteDefinition palette(String key) =>
    f9PaletteCatalog.singleWhere((entry) => entry.keyName == key);

List<Terminal> paletteTerminals(F9PaletteDefinition entry, String prefix) => [
  for (var i = 0; i < entry.terminals.length; i++)
    terminal(
      '$prefix-${entry.terminals[i].idSuffix}',
      phase: entry.terminals[i].phase,
    ),
];

CircuitState pvCircuit(F9PaletteDefinition panel) {
  final inverter = palette('pv-inverter');
  final load = palette('pv-resistive-load');
  return CircuitState(
    circuitId: CircuitId('pv-default-${panel.keyName}'),
    revision: 1,
    mode: ElectricalMode.pv,
    sources: <SourceInstance>[
      SourceInstance(
        id: SourceId('panel'),
        modelType: panel.modelType,
        terminals: paletteTerminals(panel, 'p'),
        parameters: panel.defaultParameters,
      ),
    ],
    components: <ComponentInstance>[
      ComponentInstance(
        id: ComponentId('inverter'),
        modelType: inverter.modelType,
        terminals: paletteTerminals(inverter, 'i'),
        parameters: inverter.defaultParameters,
      ),
      ComponentInstance(
        id: ComponentId('load'),
        modelType: load.modelType,
        terminals: paletteTerminals(load, 'l'),
        parameters: load.defaultParameters,
      ),
    ],
    connections: <Connection>[
      wire('pv+', 'p-pos', 'i-dc-pos'),
      wire('pv-', 'p-neg', 'i-dc-neg'),
      wire('ac-l', 'i-l', 'l-l'),
      wire('ac-n', 'i-n', 'l-n'),
    ],
  );
}

void main() {
  test('PV-DEFAULT: primary panel is compatible with PWM and 48V inverter', () {
    final panel = palette('pv-array');
    final pwm = palette('pv-controller-pwm');
    final inverter = palette('pv-inverter');
    final volts = (panel.defaultParameters['mppVoltageV'] as num).toDouble();
    final amps = (panel.defaultParameters['mppCurrentA'] as num).toDouble();
    expect(volts, greaterThan(48.0));
    expect(
      volts,
      lessThanOrEqualTo(
        (pwm.defaultParameters['maxPvInputVoltageV'] as num).toDouble(),
      ),
    );
    expect(
      volts,
      inInclusiveRange(
        (inverter.defaultParameters['minDcVoltageV'] as num).toDouble(),
        (inverter.defaultParameters['maxDcVoltageV'] as num).toDouble(),
      ),
    );
    expect(volts * amps, greaterThan(1000 / 0.96));
    final snapshot = engine.evaluate(pvCircuit(panel));
    expect(snapshot.solved, isTrue);
    expect(snapshot.pvResult!.inverterState.name, 'running');
    expect(snapshot.pvResult!.inverterOutputVoltageRmsV, closeTo(230.0, 0.001));
    expect(snapshot.pvResult!.inverterOutputPowerW, closeTo(1000.0, 0.01));
  });

  test(
    'PV-DEFAULT: high-voltage MPPT panel remains a separate explicit preset',
    () {
      final highVoltage = palette('pv-array-high-voltage');
      final inverter = palette('pv-inverter');
      expect(highVoltage.searchOnlyModes, contains(ElectricalMode.pv));
      expect(highVoltage.defaultParameters['mppVoltageV'], 360.0);
      expect(
        (highVoltage.defaultParameters['mppVoltageV'] as num).toDouble(),
        greaterThan(
          (inverter.defaultParameters['maxDcVoltageV'] as num).toDouble(),
        ),
      );
      final result = engine.evaluate(pvCircuit(highVoltage));
      expect(result.pvResult?.inverterState.name, isNot('running'));
    },
  );

  for (final mode in <ElectricalMode>[ElectricalMode.dc, ElectricalMode.pv]) {
    test(
      'METER: physical voltmeter reads an autonomous 48V battery in ${mode.name}',
      () {
        final meter = voltmeter();
        final circuit = batteryLoad(
          mode: mode,
          meter: meter,
          probes: [
            lead('v', meter, InstrumentPort.voltOhm, 'battery-plus'),
            lead('com', meter, InstrumentPort.common, 'battery-minus'),
          ],
        );
        final snapshot = engine.evaluate(circuit);
        expect(snapshot.solved, isTrue);
        if (mode == ElectricalMode.pv) {
          expect(snapshot.pvResult, isNull);
          expect(snapshot.dcResult, isNotNull);
          expect(snapshot.effectiveCircuit.mode, ElectricalMode.dc);
        }
        final reading = meters.read(snapshot: snapshot, instrument: meter);
        expect(
          reading.status,
          PhysicalInstrumentStatus.valid,
          reason: reading.message,
        );
        expect(reading.result!.reading!.value, closeTo(47.92013, 0.005));
      },
    );

    test(
      'METER: real series burden reads 48V battery current in ${mode.name}',
      () {
        final meter = ammeter();
        final circuit = batteryLoad(
          mode: mode,
          meter: meter,
          probes: [
            lead('a', meter, InstrumentPort.amp, 'battery-plus'),
            lead('com', meter, InstrumentPort.common, 'resistor-a'),
          ],
        );
        final snapshot = engine.evaluate(circuit);
        final reading = meters.read(snapshot: snapshot, instrument: meter);
        expect(
          reading.status,
          PhysicalInstrumentStatus.valid,
          reason: reading.message,
        );
        expect(reading.result!.reading!.value.abs(), closeTo(0.998, 0.005));
      },
    );
  }

  test(
    'METER: incorrect ammeter series leads cannot produce a valid reading',
    () {
      final meter = ammeter();
      final circuit = batteryLoad(
        mode: ElectricalMode.dc,
        meter: meter,
        probes: [
          lead('a', meter, InstrumentPort.amp, 'battery-plus'),
          lead('com', meter, InstrumentPort.common, 'battery-minus'),
        ],
      );
      final snapshot = engine.evaluate(circuit);
      final reading = meters.read(snapshot: snapshot, instrument: meter);
      expect(reading.status, PhysicalInstrumentStatus.invalidWiring);
      expect(reading.isValid, isFalse);
    },
  );
}
