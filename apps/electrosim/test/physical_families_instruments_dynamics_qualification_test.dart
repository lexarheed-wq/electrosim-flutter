import 'dart:convert';
import 'dart:io';

import 'package:electrosim/f9_component_palette.dart';
import 'package:electrosim/runtime/electrosim_instrument_projection.dart';
import 'package:electrosim/runtime/electrosim_runtime_engine.dart';
import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:flutter_test/flutter_test.dart';

const ElectroSimRuntimeEngine engine = ElectroSimRuntimeEngine();
const ElectroSimInstrumentProjection projector =
    ElectroSimInstrumentProjection();

Terminal pin(String id, [PhaseTag phase = PhaseTag.none]) =>
    Terminal(id: TerminalId(id), name: id, phase: phase);

Connection wire(String id, String a, String b) => Connection(
  id: ConnectionId(id),
  fromTerminalId: TerminalId(a),
  toTerminalId: TerminalId(b),
);

ProbeConnection probe(
  String id,
  InstrumentInstance instrument,
  InstrumentPort port,
  String terminal,
) => ProbeConnection(
  id: ProbeId(id),
  instrumentId: instrument.id,
  port: port,
  terminalId: TerminalId(terminal),
);

void audit(
  String family,
  String id,
  String verdict,
  Map<String, Object?> data,
) {
  stdout.writeln(
    'PHYSICS_AUDIT_JSON:${jsonEncode(<String, Object?>{'family': family, 'case': id, 'verdict': verdict, ...data})}',
  );
}

CircuitState acCircuit({
  required ElectricalMode mode,
  List<InstrumentInstance> instruments = const [],
  List<ProbeConnection> probes = const [],
}) {
  final bool three = mode == ElectricalMode.ac3;
  return CircuitState(
    circuitId: CircuitId('meter-${mode.name}'),
    revision: 1,
    mode: mode,
    settings: const <String, Object?>{'frequencyHz': 50.0},
    sources: <SourceInstance>[
      SourceInstance(
        id: SourceId('grid'),
        modelType: three ? 'ac3_voltage_source' : 'ac_voltage_source',
        terminals: three
            ? <Terminal>[
                pin('l1', PhaseTag.l1),
                pin('l2', PhaseTag.l2),
                pin('l3', PhaseTag.l3),
                pin('n', PhaseTag.neutral),
              ]
            : <Terminal>[pin('l1', PhaseTag.l1), pin('n', PhaseTag.neutral)],
        parameters: three
            ? const <String, Object?>{
                'phaseVoltageRmsV': 230.0,
                'frequencyHz': 50.0,
              }
            : const <String, Object?>{
                'voltageRmsV': 230.0,
                'phaseDegrees': 0.0,
              },
      ),
    ],
    components: <ComponentInstance>[
      for (final String name
          in (three ? <String>['r1', 'r2', 'r3'] : <String>['r1']))
        ComponentInstance(
          id: ComponentId(name),
          modelType: 'resistor',
          terminals: <Terminal>[pin('$name-a'), pin('$name-b')],
          parameters: const <String, Object?>{'resistanceOhm': 529.0},
        ),
    ],
    connections: <Connection>[
      wire('s1', 'l1', 'r1-a'),
      wire('n1', 'r1-b', 'n'),
      if (three) ...<Connection>[
        wire('s2', 'l2', 'r2-a'),
        wire('n2', 'r2-b', 'n'),
        wire('s3', 'l3', 'r3-a'),
        wire('n3', 'r3-b', 'n'),
      ],
    ],
    instruments: instruments,
    probes: probes,
  );
}

CircuitState withInstrument(
  CircuitState circuit,
  InstrumentInstance instrument,
  List<ProbeConnection> leads,
) => CircuitState(
  circuitId: circuit.circuitId,
  revision: circuit.revision,
  mode: circuit.mode,
  sources: circuit.sources,
  components: circuit.components,
  connections: circuit.connections,
  settings: circuit.settings,
  instruments: <InstrumentInstance>[instrument],
  probes: leads,
);

CircuitState dcLoaded(
  String model,
  Map<String, Object?> parameters, {
  String id = 'load',
  double voltage = 24.0,
  Map<String, Object?> controlState = const <String, Object?>{},
  Duration? elapsed,
}) => CircuitState(
  circuitId: CircuitId('loaded-$id'),
  revision: 1,
  mode: ElectricalMode.dc,
  sources: <SourceInstance>[
    SourceInstance(
      id: SourceId('supply'),
      modelType: 'dc_voltage_source',
      terminals: <Terminal>[
        pin('plus', PhaseTag.dcPositive),
        pin('minus', PhaseTag.dcNegative),
      ],
      parameters: <String, Object?>{'voltageV': voltage},
    ),
  ],
  components: <ComponentInstance>[
    ComponentInstance(
      id: ComponentId(id),
      modelType: model,
      terminals: <Terminal>[pin('$id-a'), pin('$id-b')],
      parameters: parameters,
      controlState: controlState,
    ),
  ],
  connections: <Connection>[
    wire('head', 'plus', '$id-a'),
    wire('return', '$id-b', 'minus'),
  ],
);

CircuitState loadedPalette(F9PaletteDefinition entry, ElectricalMode mode) {
  final bool ac = mode == ElectricalMode.ac1;
  final terminals = <Terminal>[
    for (var i = 0; i < entry.terminalCount; i++)
      pin(
        'load-t$i',
        entry.terminals.isNotEmpty ? entry.terminals[i].phase : PhaseTag.none,
      ),
  ];
  return CircuitState(
    circuitId: CircuitId('scan-${entry.keyName}-${mode.name}'),
    revision: 1,
    mode: mode,
    settings: const <String, Object?>{'frequencyHz': 50.0},
    sources: <SourceInstance>[
      SourceInstance(
        id: SourceId('supply'),
        modelType: ac ? 'ac_voltage_source' : 'dc_voltage_source',
        terminals: <Terminal>[
          pin('plus', ac ? PhaseTag.l1 : PhaseTag.dcPositive),
          pin('minus', ac ? PhaseTag.neutral : PhaseTag.dcNegative),
        ],
        parameters: ac
            ? const <String, Object?>{'voltageRmsV': 230.0}
            : const <String, Object?>{'voltageV': 24.0},
      ),
    ],
    components: <ComponentInstance>[
      ComponentInstance(
        id: ComponentId('load'),
        modelType: entry.modelType,
        terminals: terminals,
        parameters: entry.defaultParameters,
        controlState: entry.defaultControlState,
      ),
      // Never attach an ideal closed switch or protective contact straight
      // across an ideal source: put a real receiver in series.
      ComponentInstance(
        id: ComponentId('ballast'),
        modelType: 'resistor',
        terminals: <Terminal>[pin('ballast-a'), pin('ballast-b')],
        parameters: const <String, Object?>{'resistanceOhm': 48.0},
      ),
    ],
    connections: <Connection>[
      wire('head', 'plus', 'load-t0'),
      wire('ballast-feed', 'load-t1', 'ballast-a'),
      wire('return', 'ballast-b', 'minus'),
    ],
  );
}

void main() {
  for (final mode in <ElectricalMode>[ElectricalMode.ac1, ElectricalMode.ac3]) {
    test('PHYS-METER: AC frequency needs live probes ($mode)', () {
      final meter = InstrumentInstance(
        id: InstrumentId('frequency-meter'),
        kind: InstrumentKind.frequencyMeter,
        mode: InstrumentMode.frequency,
      );
      final base = acCircuit(mode: mode);
      final connected = withInstrument(base, meter, <ProbeConnection>[
        probe('freq-v', meter, InstrumentPort.voltOhm, 'l1'),
        probe('freq-common', meter, InstrumentPort.common, 'n'),
      ]);
      final snapshot = engine.evaluate(connected);
      expect(snapshot.solved, isTrue);
      final reading = projector.read(snapshot: snapshot, instrument: meter);
      expect(
        reading.status,
        PhysicalInstrumentStatus.valid,
        reason: reading.message,
      );
      expect(reading.result?.reading?.value, closeTo(50.0, 0.000001));
      audit('meter-frequency', mode.name, 'PASS', {
        'hz': reading.result?.reading?.value,
      });
      final disconnected = withInstrument(base, meter, <ProbeConnection>[]);
      expect(
        projector
            .read(snapshot: engine.evaluate(disconnected), instrument: meter)
            .status,
        PhysicalInstrumentStatus.invalidWiring,
      );
      final zeroVoltage = withInstrument(base, meter, <ProbeConnection>[
        probe('same-node-v', meter, InstrumentPort.voltOhm, 'l1'),
        probe('same-node-com', meter, InstrumentPort.common, 'r1-a'),
      ]);
      expect(
        projector
            .read(snapshot: engine.evaluate(zeroVoltage), instrument: meter)
            .isValid,
        isFalse,
        reason: 'Equal-potential probes must not show a fictitious frequency.',
      );
    });
  }

  test('PHYS-METER: three-phase phase order reverses when two probes swap', () {
    final meter = InstrumentInstance(
      id: InstrumentId('sequence-meter'),
      kind: InstrumentKind.phaseSequenceTester,
      mode: InstrumentMode.phaseSequence,
    );
    final base = acCircuit(mode: ElectricalMode.ac3);
    CircuitState connected(List<String> terminals) =>
        withInstrument(base, meter, <ProbeConnection>[
          probe('phase-one', meter, InstrumentPort.phase1, terminals[0]),
          probe('phase-two', meter, InstrumentPort.phase2, terminals[1]),
          probe('phase-three', meter, InstrumentPort.phase3, terminals[2]),
        ]);
    final normal = projector.read(
      snapshot: engine.evaluate(connected(<String>['l1', 'l2', 'l3'])),
      instrument: meter,
    );
    final inverted = projector.read(
      snapshot: engine.evaluate(connected(<String>['l1', 'l3', 'l2'])),
      instrument: meter,
    );
    expect(
      normal.status,
      PhysicalInstrumentStatus.valid,
      reason: normal.message,
    );
    expect(
      inverted.status,
      PhysicalInstrumentStatus.valid,
      reason: inverted.message,
    );
    expect(normal.result?.displayText, 'L1 → L2 → L3');
    expect(inverted.result?.displayText, 'L1 → L3 → L2');
    final invalid = projector.read(
      snapshot: engine.evaluate(connected(<String>['l1', 'l1', 'l2'])),
      instrument: meter,
    );
    expect(invalid.status, PhysicalInstrumentStatus.invalidWiring);
    audit('meter-phase-sequence', 'three-phase-swap', 'PASS', {
      'forward': normal.result?.displayText,
      'reversed': inverted.result?.displayText,
    });
  });

  test('PHYS-PRESET: a newly dropped 100Ω resistor conducts 0.24A at 24V', () {
    final definition = f9PaletteCatalog.singleWhere(
      (item) => item.keyName == 'resistor',
    );
    expect(definition.defaultParameters['resistanceOhm'], 100.0);
    final snapshot = engine.evaluate(
      loadedPalette(definition, ElectricalMode.dc),
    );
    expect(snapshot.solved, isTrue);
    // The family fixture includes an independent 48Ω safety load in series.
    final current = snapshot.dc.branch('component:load').currentA!.abs();
    expect(current, closeTo(24.0 / 148.0, 0.000001));
    audit('default-resistor', '100ohm-plus-48ohm', 'PASS', {
      'currentA': current,
      'expectedCurrentA': 24.0 / 148.0,
    });
  });

  test(
    'PHYS-FAMILY: load each two-terminal passive/receiver/switching model',
    () {
      final failures = <String>[];
      final families = <String, int>{};
      final statuses = <String, int>{};
      var attempts = 0;
      for (final entry in f9PaletteCatalog) {
        if (entry.kind != F9PaletteElementKind.component ||
            entry.terminalCount != 2 ||
            entry.modelType == 'pv_battery') {
          continue;
        }
        for (final mode in <ElectricalMode>[
          ElectricalMode.dc,
          ElectricalMode.ac1,
        ]) {
          if (!entry.supportsMode(mode)) continue;
          attempts++;
          final contract = CoreComponentModelContracts.registry.resolve(
            entry.modelType,
          );
          final family = contract?.family.name ?? 'unregistered';
          families[family] = (families[family] ?? 0) + 1;
          try {
            final result = engine.evaluate(loadedPalette(entry, mode));
            final verdict = result.solved ? 'SOLVED' : 'UNRESOLVED';
            statuses[verdict] = (statuses[verdict] ?? 0) + 1;
            final List<double> residuals = <double>[
              ...?result.dcResult?.kclResiduals.values,
              ...?result.ac1Result?.kclResiduals.values,
            ];
            final finite = residuals.every((x) => x.isFinite);
            if (!finite)
              failures.add('${entry.keyName}/${mode.name}: nonfinite');
            audit(
              'loaded-family',
              '${entry.keyName}/${mode.name}',
              finite ? verdict : 'NONFINITE',
              {
                'familyName': family,
                'model': entry.modelType,
                'mode': mode.name,
                'solved': result.solved,
                'maxKclResidual': residuals.fold<double>(
                  0.0,
                  (max, x) => x.abs() > max ? x.abs() : max,
                ),
                'diagnostics': result.diagnostics.advice.length,
              },
            );
          } on Object catch (error) {
            failures.add('${entry.keyName}/${mode.name}: $error');
            audit(
              'loaded-family',
              '${entry.keyName}/${mode.name}',
              'EXCEPTION',
              {'error': '$error'},
            );
          }
        }
      }
      audit('loaded-family-summary', '2-terminal-loaded-modes', 'MEASURED', {
        'attempts': attempts,
        'families': families,
        'statuses': statuses,
        'exceptionsAndNonfinite': failures.length,
        'ballastOhm': 48.0,
        'unresolvedCannotBeClaimedAsQualified': true,
        'otherTopologiesNotCovered':
            'Three-phase, multipole, sensors, inverter and battery',
      });
      expect(attempts, greaterThanOrEqualTo(10));
      expect(failures, isEmpty, reason: failures.join('; '));
    },
  );

  test(
    'PHYS-THERMAL: overloaded lamp accumulates I²t-like damage, opens permanently',
    () {
      final circuit = dcLoaded('lamp', <String, Object?>{
        ComponentParameterKeys.resistanceOhm: 24.0,
        ReceiverNominalRating.voltageKey: 24.0,
        ReceiverNominalRating.currentKey: 1.0,
        ReceiverNominalRating.powerKey: 24.0,
        ComponentParameterKeys.thermalWithstandSeconds: 1.0,
      }, voltage: 30.0);
      final id = ComponentId('load');
      final first = engine.advance(
        circuit,
        elapsed: const Duration(milliseconds: 100),
      );
      final initial = first.componentHealthState(id);
      expect(initial.failedOpen, isFalse);
      expect(initial.thermalExposure, greaterThan(0));
      final second = engine.advance(
        circuit,
        elapsed: const Duration(seconds: 2),
        previousComponentHealthStates: first.componentHealthStates,
      );
      final failed = second.componentHealthState(id);
      expect(failed.failedOpen, isTrue);
      final third = engine.advance(
        circuit,
        elapsed: const Duration(seconds: 5),
        previousComponentHealthStates: second.componentHealthStates,
      );
      expect(third.componentHealthState(id).failedOpen, isTrue);
      audit('thermal-damage', 'overrated-lamp', 'PASS', {
        'firstExposure': initial.thermalExposure,
        'failedExposure': failed.thermalExposure,
        'latchedFailure': third.componentHealthState(id).failedOpen,
        'note':
            'Simplified thermal exposure; no ambient temperature or calendar aging.',
      });
    },
  );

  test('PHYS-MOTOR: 24 V DC armature accelerates over runtime steps', () {
    final circuit = dcLoaded('motor_dc', <String, Object?>{
      ComponentParameterKeys.resistanceOhm: 8.0,
      ComponentParameterKeys.motorBackEmfVPerRadS: 0.1,
      ComponentParameterKeys.motorTorqueNmPerA: 0.1,
      ComponentParameterKeys.motorInertiaKgM2: 0.01,
      ComponentParameterKeys.motorFrictionNmPerRadS: 0.002,
      ComponentParameterKeys.motorLoadTorqueNm: 0.0,
      ReceiverNominalRating.voltageKey: 24.0,
      ReceiverNominalRating.currentKey: 3.0,
      ReceiverNominalRating.powerKey: 72.0,
    });
    final first = engine.advance(
      circuit,
      elapsed: const Duration(milliseconds: 100),
    );
    expect(first.solved, isTrue);
    final firstSpeed = first.motorAngularSpeedsRadS[ComponentId('load')] ?? 0;
    expect(firstSpeed, greaterThan(0));
    final next = engine.advance(
      circuit,
      elapsed: const Duration(milliseconds: 100),
      previousMotorAngularSpeedsRadS: first.motorAngularSpeedsRadS,
    );
    final secondSpeed = next.motorAngularSpeedsRadS[ComponentId('load')] ?? 0;
    expect(next.solved, isTrue);
    expect(secondSpeed, greaterThan(firstSpeed));
    audit('motor-dynamics', 'dc-armature-start', 'PASS', {
      'firstSpeedRadS': firstSpeed,
      'secondSpeedRadS': secondSpeed,
      'note': 'Simplified DC rotor model; not an induction motor.',
    });
  });

  test(
    'PHYS-AGING: at nominal voltage a healthy receiver does not age by itself',
    () {
      final circuit = dcLoaded('lamp', <String, Object?>{
        ComponentParameterKeys.resistanceOhm: 24.0,
        ReceiverNominalRating.voltageKey: 24.0,
        ReceiverNominalRating.currentKey: 1.0,
        ReceiverNominalRating.powerKey: 24.0,
        ComponentParameterKeys.thermalWithstandSeconds: 1.0,
      });
      final first = engine.advance(circuit, elapsed: const Duration(hours: 2));
      final health = first.componentHealthState(ComponentId('load'));
      expect(first.solved, isTrue);
      expect(health.failedOpen, isFalse);
      expect(health.thermalExposure, closeTo(0, 1e-10));
      audit('aging-limit', 'nominal-2h', 'NO_CALENDAR_AGING', {
        'exposure': health.thermalExposure,
        'note':
            'Calendar aging and insulation drift are not modeled by this thermal engine.',
      });
    },
  );
}
