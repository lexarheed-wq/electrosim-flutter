import 'dart:convert';
import 'dart:io';

import 'package:electrosim/f9_component_palette.dart';
import 'package:electrosim/runtime/electrosim_runtime_engine.dart';
import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:electrosim_measurements/electrosim_measurements.dart';
import 'package:flutter_test/flutter_test.dart';

const engine = ElectroSimRuntimeEngine();
const dynamics = ProtectionDynamicsEngine();

void record(
  String family,
  String caseName,
  bool pass,
  Map<String, Object?> data,
) {
  stdout.writeln(
    'PHYSICS_AUDIT_JSON:' +
        jsonEncode(<String, Object?>{
          'family': family,
          'case': caseName,
          'verdict': pass ? 'PASS' : 'FAIL',
          ...data,
        }),
  );
}

Terminal terminal(String id, PhaseTag phase) =>
    Terminal(id: TerminalId(id), name: id, phase: phase);
Connection join(String id, String a, String b) => Connection(
  id: ConnectionId(id),
  fromTerminalId: TerminalId(a),
  toTerminalId: TerminalId(b),
);

F9PaletteDefinition preset(String key) =>
    f9PaletteCatalog.singleWhere((entry) => entry.keyName == key);

ComponentInstance instance(
  F9PaletteDefinition definition, {
  Map<String, Object?> extra = const <String, Object?>{},
}) => ComponentInstance(
  id: ComponentId('device'),
  modelType: definition.modelType,
  terminals: <Terminal>[
    for (var i = 0; i < definition.terminalCount; i++)
      terminal(
        'dev-' + i.toString(),
        definition.terminals.isEmpty
            ? PhaseTag.none
            : definition.terminals[i].phase,
      ),
  ],
  parameters: <String, Object?>{...definition.defaultParameters, ...extra},
  controlState: definition.defaultControlState,
);

SourceInstance supply() => SourceInstance(
  id: SourceId('source'),
  modelType: 'ac3_voltage_source',
  terminals: <Terminal>[
    terminal('s1', PhaseTag.l1),
    terminal('s2', PhaseTag.l2),
    terminal('s3', PhaseTag.l3),
    terminal('sn', PhaseTag.neutral),
  ],
  parameters: const <String, Object?>{'phaseVoltageRmsV': 230.0},
);

CircuitState poles(
  String key,
  double resistance, {
  bool coil = true,
  Map<String, Object?> parameters = const <String, Object?>{},
}) {
  final spec = preset(key);
  final three = spec.terminalCount == 6 || spec.modelType == 'contactor_3p';
  final offset = three ? 3 : 4;
  final parts = <ComponentInstance>[instance(spec, extra: parameters)];
  final wires = <Connection>[];
  for (var i = 0; i < 3; i++) {
    final k = i.toString();
    final phase = <PhaseTag>[PhaseTag.l1, PhaseTag.l2, PhaseTag.l3][i];
    parts.add(
      ComponentInstance(
        id: ComponentId('r' + k),
        modelType: 'resistor',
        terminals: <Terminal>[
          terminal('r' + k + 'a', phase),
          terminal('r' + k + 'b', PhaseTag.neutral),
        ],
        parameters: <String, Object?>{'resistanceOhm': resistance},
      ),
    );
    wires.add(join('in' + k, 's' + (i + 1).toString(), 'dev-' + k));
    wires.add(join('out' + k, 'dev-' + (offset + i).toString(), 'r' + k + 'a'));
    wires.add(join('return' + k, 'r' + k + 'b', three ? 'sn' : 'dev-7'));
  }
  if (!three) wires.add(join('neutral', 'sn', 'dev-3'));
  if (spec.modelType == 'contactor_3p' && coil) {
    wires.add(join('coilL', 's1', 'dev-6'));
    wires.add(join('coilN', 'sn', 'dev-7'));
  }
  return CircuitState(
    circuitId: CircuitId(
      'qualified-' + key + '-' + resistance.toString() + '-' + coil.toString(),
    ),
    revision: 1,
    mode: ElectricalMode.ac3,
    sources: <SourceInstance>[supply()],
    components: parts,
    connections: wires,
    settings: const <String, Object?>{'frequencyHz': 50.0},
  );
}

CircuitState motor(String key, bool delta) {
  final part = instance(preset(key));
  return CircuitState(
    circuitId: CircuitId('motor-' + key + '-' + delta.toString()),
    revision: 1,
    mode: ElectricalMode.ac3,
    sources: <SourceInstance>[supply()],
    components: <ComponentInstance>[part],
    connections: <Connection>[
      join('l1', 's1', 'dev-0'),
      join('l2', 's2', 'dev-1'),
      join('l3', 's3', 'dev-2'),
      if (delta) ...<Connection>[
        join('d1', 'dev-3', 'dev-1'),
        join('d2', 'dev-4', 'dev-2'),
        join('d3', 'dev-5', 'dev-0'),
      ] else ...<Connection>[
        join('y1', 'dev-3', 'dev-4'),
        join('y2', 'dev-4', 'dev-5'),
      ],
    ],
    settings: const <String, Object?>{'frequencyHz': 50.0},
  );
}

double rms(ElectroSimRuntimeSnapshot result, String id) =>
    result.ac3.branch(id).current?.magnitude ?? double.nan;

void main() {
  test('MULTIPOLE catalogue contractual enumeration', () {
    var count = 0;
    final missing = <String>[];
    for (final entry in f9PaletteCatalog) {
      if (entry.kind != F9PaletteElementKind.component ||
          entry.terminalCount <= 2)
        continue;
      count++;
      final contract = CoreComponentModelContracts.registry.resolve(
        entry.modelType,
      );
      final ok =
          contract != null && contract.terminalCount == entry.terminalCount;
      if (!ok) missing.add(entry.keyName);
      record('multipole-inventory', entry.keyName, ok, {
        'terminals': entry.terminalCount,
        'model': entry.modelType,
        'family': contract?.family.name,
        'manufacturerRatedOverloadData': false,
      });
    }
    record('multipole-summary', 'all-catalogue', missing.isEmpty, {
      'multiPoleEntries': count,
      'missingContracts': missing,
    });
    expect(count, greaterThanOrEqualTo(8));
    expect(missing, isEmpty);
  });

  for (final key in <String>[
    'breaker-3p',
    'breaker-4p',
    'isolator-3p',
    'isolator-4p',
    'thermal-overload-3p',
    'contactor-3p',
  ]) {
    for (final resistance in <double>[46.0, 23.0, 11.5]) {
      test('MULTIPOLE wired ' + key + ' R=' + resistance.toString(), () {
        final result = engine.evaluate(poles(key, resistance));
        final currents = <double>[
          for (var i = 0; i < 3; i++) rms(result, 'component:r' + i.toString()),
        ];
        final expected = 230.0 / resistance;
        final residual = result.solved
            ? result.ac3.kclResiduals.values.fold<double>(
                0.0,
                (max, v) => v.abs() > max ? v.abs() : max,
              )
            : double.nan;
        final pass =
            result.solved &&
            residual < 1e-4 &&
            currents.every((i) => i.isFinite && (i - expected).abs() < 0.05);
        record('multipole-loaded', key + '/' + resistance.toString(), pass, {
          'measuredRmsA': currents,
          'expectedRmsA': expected,
          'expectedTotalActiveW': 3 * 230 * expected,
          'kclResidualA': residual,
          'solved': result.solved,
          'diagnostics': result.ac3Result?.diagnostics
              .map((d) => d.message)
              .toList(),
        });
        expect(pass, isTrue);
      });
    }
  }

  test('CONTACTOR: all 3 poles release when coil is disconnected', () {
    final on = engine.evaluate(poles('contactor-3p', 46));
    final off = engine.evaluate(poles('contactor-3p', 46, coil: false));
    final a = <double>[
      for (var i = 0; i < 3; i++) rms(on, 'component:r' + i.toString()),
    ];
    final b = <double>[
      for (var i = 0; i < 3; i++) rms(off, 'component:r' + i.toString()),
    ];
    final pass =
        on.solved &&
        off.solved &&
        a.every((x) => x > 4.95) &&
        b.every((x) => x < 1e-5) &&
        on.contactorActuated(ComponentId('device')) &&
        !off.contactorActuated(ComponentId('device'));
    record('contactor-3p-control', 'coil-disconnect', pass, {
      'energizedA': a,
      'disconnectedA': b,
    });
    expect(pass, isTrue);
  });

  for (final key in <String>[
    'motor-3p-6t',
    'external-pump-3p',
    'external-fan-3p',
  ]) {
    test('MOTOR 6 terminals star/delta ' + key, () {
      final y = engine.evaluate(motor(key, false));
      final d = engine.evaluate(motor(key, true));
      final ia = <double>[
        for (final p in <String>['U', 'V', 'W'])
          rms(y, 'component:device:winding:' + p),
      ];
      final ib = <double>[
        for (final p in <String>['U', 'V', 'W'])
          rms(d, 'component:device:winding:' + p),
      ];
      final ratio = ib.first / ia.first;
      final pass =
          y.solved &&
          d.solved &&
          ia.every((x) => x > 0 && x.isFinite) &&
          ib.every((x) => x > 0 && x.isFinite) &&
          ratio > 2.9 &&
          ratio < 3.1;
      record('motor6-windings', key, pass, {
        'starWindingA': ia,
        'deltaWindingA': ib,
        'windingRatioDeltaToStar': ratio,
        'modelLimit':
            'Phasor R-L only; torque-speed and locked rotor not qualified.',
      });
      expect(pass, isTrue);
    });
  }

  for (final key in <String>[
    'breaker-3p',
    'breaker-4p',
    'thermal-overload-3p',
  ]) {
    test('OVERLOAD 3P/4P at 1x and 2x rated ' + key, () {
      final rated = key == 'thermal-overload-3p'
          ? 5.0
          : key == 'breaker-4p'
          ? 16.0
          : 10.0;
      final regular = engine.advance(
        poles(
          key,
          230 / rated,
          parameters: <String, Object?>{'ratedCurrentA': rated},
        ),
        elapsed: const Duration(hours: 1),
      );
      final heavy = engine.advance(
        poles(
          key,
          230 / (2 * rated),
          parameters: <String, Object?>{'ratedCurrentA': rated},
        ),
        elapsed: const Duration(hours: 2),
      );
      final hold = !regular.protectionTripped(ComponentId('device'));
      final trip = heavy.protectionTripped(ComponentId('device'));
      final pass = regular.solved && heavy.solved && hold && trip;
      record('multipole-overload', key, pass, {
        'ratedA': rated,
        'holdOneHourAtRated': hold,
        'tripTwoHoursAt2x': trip,
        'normalSolved': regular.solved,
        'overloadSolved': heavy.solved,
      });
      expect(pass, isTrue);
    });
  }

  for (final curve in <String>['B', 'C', 'D']) {
    test('IEC 60898 breaker reference limits ' + curve, () {
      final breaker = ComponentInstance(
        id: ComponentId('curve'),
        modelType: 'breaker_3p',
        terminals: <Terminal>[
          for (var i = 0; i < 6; i++)
            terminal('c' + i.toString(), PhaseTag.none),
        ],
        parameters: <String, Object?>{
          'ratedCurrentA': 10.0,
          'tripCurve': curve,
        },
      );
      final hold = dynamics.tripTimeSeconds(breaker, 11.3);
      final trip = dynamics.tripTimeSeconds(breaker, 14.5);
      final profile = dynamics.profile(breaker);
      final fast = dynamics.tripTimeSeconds(
        breaker,
        10 * profile.magneticHighMultiple,
      );
      final pass = !hold.isFinite && trip > 0 && trip <= 3600 && fast <= 0.1;
      record('iec60898', '10A-curve-' + curve, pass, {
        '1_13InHoldSeconds': hold.isFinite ? hold : null,
        '1_45InTripSeconds': trip,
        'magneticBand': <double>[
          profile.magneticLowMultiple,
          profile.magneticHighMultiple,
        ],
        'highMagneticTripSeconds': fast,
      });
      expect(pass, isTrue);
    });
  }

  test('IEC 60947-4-1 thermal relay 7.2 Ir trip classes 10/20/30', () {
    ComponentInstance relay(String tripClass) => ComponentInstance(
      id: ComponentId('ol'),
      modelType: 'thermal_overload_3p',
      terminals: <Terminal>[
        for (var i = 0; i < 6; i++)
          terminal('ol' + i.toString(), PhaseTag.none),
      ],
      parameters: <String, Object?>{
        'ratedCurrentA': 5.0,
        'tripClass': tripClass,
      },
    );
    final result = <String, double>{
      for (final cls in <String>['10', '20', '30'])
        cls: dynamics.tripTimeSeconds(relay(cls), 36.0),
    };
    final pass =
        result['10']! >= 4 &&
        result['10']! <= 10 &&
        result['20']! >= 6 &&
        result['20']! <= 20 &&
        result['30']! >= 9 &&
        result['30']! <= 30 &&
        result['10']! < result['20']! &&
        result['20']! < result['30']!;
    record('iec60947-4-1', 'trip-classes', pass, {
      '7_2IrTripSeconds': result,
      'reference': 'Schneider trip class envelopes',
      'caveat': 'Generic educational approximation, not a manufacturer test.',
    });
    expect(pass, isTrue);
  });
}
