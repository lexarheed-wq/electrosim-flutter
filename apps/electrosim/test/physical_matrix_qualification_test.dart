import 'dart:convert';
import 'dart:math' as math;

import 'package:electrosim/f9_component_palette.dart';
import 'package:electrosim/runtime/electrosim_runtime_engine.dart';
import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:electrosim_scenarios/electrosim_scenarios.dart';
import 'package:electrosim_solver_dc/electrosim_solver_dc.dart';
import 'package:flutter_test/flutter_test.dart';

const ElectroSimRuntimeEngine _runtime = ElectroSimRuntimeEngine();

void _result(String family, String id, String verdict, Map<String, Object?> data) {
  print('PHYSICS_AUDIT_JSON:${jsonEncode(<String, Object?>{
    'family': family,
    'case': id,
    'verdict': verdict,
    ...data,
  })}');
}

Terminal _pin(String id, {String? name, PhaseTag phase = PhaseTag.none}) =>
    Terminal(id: TerminalId(id), name: name ?? id, phase: phase);

Connection _wire(String id, String from, String to) => Connection(
  id: ConnectionId(id),
  fromTerminalId: TerminalId(from),
  toTerminalId: TerminalId(to),
);

SourceInstance _dcSource(double volts) => SourceInstance(
  id: SourceId('supply'),
  modelType: 'dc_voltage_source',
  terminals: <Terminal>[
    _pin('s-plus', name: '+', phase: PhaseTag.dcPositive),
    _pin('s-minus', name: '-', phase: PhaseTag.dcNegative),
  ],
  parameters: <String, Object?>{'voltageV': volts},
);

ComponentInstance _resistor(String id, double ohms, {String model = 'resistor'}) =>
    ComponentInstance(
      id: ComponentId(id),
      modelType: model,
      terminals: <Terminal>[_pin('$id-a'), _pin('$id-b')],
      parameters: <String, Object?>{'resistanceOhm': ohms},
    );

CircuitState _resistiveDc(
  String id, double volts, List<double> resistors, {
  bool parallel = false,
  bool withSwitch = false,
  bool closed = true,
}) {
  final parts = <ComponentInstance>[
    for (var index = 0; index < resistors.length; index++)
      _resistor('r$index', resistors[index]),
    if (withSwitch)
      ComponentInstance(
        id: ComponentId('sw'),
        modelType: 'switch',
        terminals: <Terminal>[_pin('sw-a'), _pin('sw-b')],
        controlState: <String, Object?>{'closed': closed},
      ),
  ];
  final wires = <Connection>[];
  final String positive = withSwitch ? 'sw-b' : 's-plus';
  if (withSwitch) wires.add(_wire('switch-feed', 's-plus', 'sw-a'));
  if (parallel) {
    for (var i = 0; i < resistors.length; i++) {
      wires.add(_wire('p$i', positive, 'r$i-a'));
      wires.add(_wire('n$i', 'r$i-b', 's-minus'));
    }
  } else {
    wires.add(_wire('head', positive, 'r0-a'));
    for (var i = 1; i < resistors.length; i++) {
      wires.add(_wire('link$i', 'r${i-1}-b', 'r$i-a'));
    }
    wires.add(_wire('tail', 'r${resistors.length-1}-b', 's-minus'));
  }
  return CircuitState(
    circuitId: CircuitId(id),
    revision: 1,
    mode: ElectricalMode.dc,
    sources: <SourceInstance>[_dcSource(volts)],
    components: parts,
    connections: wires,
  );
}

CircuitState _ac1Resistive() => CircuitState(
  circuitId: CircuitId('audit-ac1-resistor'),
  revision: 1,
  mode: ElectricalMode.ac1,
  settings: const <String, Object?>{'frequencyHz': 50.0},
  sources: <SourceInstance>[
    SourceInstance(
      id: SourceId('grid'),
      modelType: 'ac_voltage_source',
      terminals: <Terminal>[
        _pin('ac-l', name: 'L', phase: PhaseTag.l1),
        _pin('ac-n', name: 'N', phase: PhaseTag.neutral),
      ],
      parameters: const <String, Object?>{
        'voltageRmsV': 230.0,
        'phaseDegrees': 0.0,
      },
    ),
  ],
  components: <ComponentInstance>[_resistor('load', 529)],
  connections: <Connection>[
    _wire('ac-phase', 'ac-l', 'load-a'),
    _wire('ac-return', 'load-b', 'ac-n'),
  ],
);

CircuitState _ac3BalancedStar() => CircuitState(
  circuitId: CircuitId('audit-ac3-star'),
  revision: 1,
  mode: ElectricalMode.ac3,
  settings: const <String, Object?>{'frequencyHz': 50.0},
  sources: <SourceInstance>[
    SourceInstance(
      id: SourceId('grid'),
      modelType: 'ac3_voltage_source',
      terminals: <Terminal>[
        _pin('grid-l1', name: 'L1', phase: PhaseTag.l1),
        _pin('grid-l2', name: 'L2', phase: PhaseTag.l2),
        _pin('grid-l3', name: 'L3', phase: PhaseTag.l3),
        _pin('grid-n', name: 'N', phase: PhaseTag.neutral),
      ],
      parameters: const <String, Object?>{
        'phaseVoltageRmsV': 230.0,
        'frequencyHz': 50.0,
      },
    ),
  ],
  components: <ComponentInstance>[
    _resistor('a', 529),
    _resistor('b', 529),
    _resistor('c', 529),
  ],
  connections: <Connection>[
    _wire('l1', 'grid-l1', 'a-a'),
    _wire('l2', 'grid-l2', 'b-a'),
    _wire('l3', 'grid-l3', 'c-a'),
    _wire('return-a', 'a-b', 'grid-n'),
    _wire('return-b', 'b-b', 'grid-n'),
    _wire('return-c', 'c-b', 'grid-n'),
  ],
);

double _maxResidual(Iterable<double> values) =>
    values.fold<double>(0, (a, b) => math.max(a, b.abs()));

void main() {
  test('PHYS-INV: sweep every palette entry and declared mode without exceptions', () {
    final violations = <String>[];
    final modes = ElectricalMode.values;
    final unique = <String>{};
    var total = 0;
    for (final item in f9PaletteCatalog) {
      for (final mode in modes.where(item.supportsMode)) {
        total++;
        unique.add(item.modelType);
        try {
          if (item.kind == F9PaletteElementKind.instrument) {
            _result('inventory', item.keyName, 'OVERLAY', {
              'model': item.modelType,
              'mode': mode.name,
              'kind': 'physical-instrument',
              'note': 'Measurement overlay: validated separately, not a solver branch.',
            });
            continue;
          }
          final terminals = <Terminal>[
            for (var k = 0; k < item.terminalCount; k++)
              Terminal(
                id: TerminalId('pin-$k'),
                name: item.terminals.isNotEmpty
                    ? item.terminals[k].label
                    : item.terminalLabels[k],
                role: item.terminals.isNotEmpty
                    ? item.terminals[k].role
                    : TerminalRole.generic,
                phase: item.terminals.isNotEmpty
                    ? item.terminals[k].phase
                    : PhaseTag.none,
              ),
          ];
          final source = item.kind == F9PaletteElementKind.source;
          final circuit = CircuitState(
            circuitId: CircuitId('sweep-${item.keyName}-${mode.name}'),
            revision: 1,
            mode: mode,
            settings: const <String, Object?>{'frequencyHz': 50.0},
            sources: source
                ? <SourceInstance>[
                    SourceInstance(
                      id: SourceId('source'),
                      modelType: item.modelType,
                      terminals: terminals,
                      parameters: item.defaultParameters,
                    ),
                  ]
                : const <SourceInstance>[],
            components: source
                ? const <ComponentInstance>[]
                : <ComponentInstance>[
                    ComponentInstance(
                      id: ComponentId('device'),
                      modelType: item.modelType,
                      terminals: terminals,
                      parameters: item.defaultParameters,
                      controlState: item.defaultControlState,
                    ),
                  ],
          );
          final snapshot = _runtime.evaluate(circuit);
          final residuals = <double>[
            ...?snapshot.dcResult?.nodeVoltages.values,
            ...?snapshot.dcResult?.kclResiduals.values,
            ...?snapshot.ac1Result?.kclResiduals.values,
            ...?snapshot.ac3Result?.kclResiduals.values,
          ];
          if (residuals.any((n) => !n.isFinite)) {
            violations.add('${item.keyName}/${mode.name}: nonfinite');
          }
          _result('inventory', item.keyName, 'OBSERVED', {
            'model': item.modelType,
            'kind': item.kind.name,
            'mode': mode.name,
            'solved': snapshot.solved,
            'diagnostics': snapshot.diagnostics.advice.length,
            'maxResidual': _maxResidual(residuals),
            'note': 'Isolated/open-circuit probe; unsolved is not by itself a defect.',
          });
        } on Object catch (error) {
          violations.add('${item.keyName}/${mode.name}: $error');
          _result('inventory', item.keyName, 'EXCEPTION', {
            'mode': mode.name,
            'model': item.modelType,
            'error': '$error',
          });
        }
      }
    }
    _result('inventory-summary', 'palette-sweep', 'MEASURED', {
      'entries': f9PaletteCatalog.length,
      'distinctModels': unique.length,
      'modelModeAttempts': total,
      'exceptionsAndNonfinite': violations.length,
    });
    expect(violations, isEmpty, reason: violations.join('\n'));
  });

  for (final volts in <double>[12, 24, 48]) {
    for (final ohms in <double>[12, 24, 48, 120]) {
      test('PHYS-DC: Ohm, Kirchhoff and power U=$volts R=$ohms', () {
        final snap = _runtime.evaluate(
          _resistiveDc('ohm-$volts-$ohms', volts, <double>[ohms]),
        );
        expect(snap.solved, isTrue);
        final r = snap.dc.branch('component:r0');
        final expectedI = volts / ohms;
        final expectedP = volts * volts / ohms;
        final observations = <String, double>{
          'voltage': r.voltageV.abs(),
          'current': (r.currentA ?? double.nan).abs(),
          'power': r.powerW ?? double.nan,
          'sourceVoltage': snap.dc.branchResults
              .firstWhere((b) => b.kind == DcBranchKind.voltageSource)
              .voltageV
              .abs(),
        };
        final tol = 0.0001;
        final passed = (observations['voltage']! - volts).abs() < tol &&
            (observations['current']! - expectedI).abs() < tol &&
            (observations['power']! - expectedP).abs() < tol &&
            (observations['sourceVoltage']! - volts).abs() < tol;
        _result('dc-ohm', 'U=$volts,R=$ohms', passed ? 'PASS' : 'FAIL', {
          'expectedCurrentA': expectedI,
          'expectedPowerW': expectedP,
          ...observations,
          'maxKclResidual': _maxResidual(snap.dc.kclResiduals.values),
        });
        expect(passed, isTrue);
        expect(_maxResidual(snap.dc.kclResiduals.values), lessThan(0.0001));
      });
    }
  }

  for (final parallel in <bool>[false, true]) {
    test('PHYS-DC: ${parallel ? 'parallel KCL' : 'series KVL'} resistors', () {
      final snap = _runtime.evaluate(
        _resistiveDc('network-$parallel', 24, <double>[24, 48],
            parallel: parallel),
      );
      expect(snap.solved, isTrue);
      final a = snap.dc.branch('component:r0');
      final b = snap.dc.branch('component:r1');
      final expectedA = parallel ? 1.0 : 24 / 72;
      final expectedB = parallel ? 0.5 : 24 / 72;
      final okay = (a.currentA!.abs() - expectedA).abs() < 1e-4 &&
          (b.currentA!.abs() - expectedB).abs() < 1e-4 &&
          (parallel
              ? (a.voltageV.abs() - 24).abs() < 1e-4 &&
                  (b.voltageV.abs() - 24).abs() < 1e-4
              : (a.voltageV.abs() + b.voltageV.abs() - 24).abs() < 1e-4);
      _result('dc-network', parallel ? 'parallel' : 'series',
          okay ? 'PASS' : 'FAIL', {
        'i1A': a.currentA!.abs(),
        'i2A': b.currentA!.abs(),
        'v1V': a.voltageV.abs(),
        'v2V': b.voltageV.abs(),
        'sourceV': 24,
      });
      expect(okay, isTrue);
    });
  }

  for (final closed in <bool>[false, true]) {
    test('PHYS-DC: switching correctly isolates/energizes a load ($closed)', () {
      final snap = _runtime.evaluate(
        _resistiveDc('switch-$closed', 24, <double>[24],
            withSwitch: true, closed: closed),
      );
      final i = snap.dc.branch('component:r0').currentA?.abs() ?? double.nan;
      final okay = snap.solved && (i - (closed ? 1.0 : 0.0)).abs() < 1e-4;
      _result('dc-switch', '$closed', okay ? 'PASS' : 'FAIL', {
        'solved': snap.solved,
        'currentA': i,
        'expectedA': closed ? 1.0 : 0.0,
      });
      expect(okay, isTrue);
    });
  }

  test('PHYS-AC1: resistive 230 V RMS / 529 ohm / 50 Hz', () {
    final snap = _runtime.evaluate(_ac1Resistive());
    final b = snap.ac1Result?.branch('component:load');
    final v = b?.voltage.magnitude ?? double.nan;
    final i = b?.current?.magnitude ?? double.nan;
    final p = b?.activePowerW ?? double.nan;
    final okay = snap.solved && (v - 230).abs() < 0.001 &&
        (i - 230 / 529).abs() < 0.001 &&
        (p - 100).abs() < 0.01;
    _result('ac1-rms', 'R=529;U=230;f=50', okay ? 'PASS' : 'FAIL', {
      'solved': snap.solved,
      'voltageRmsV': v,
      'currentRmsA': i,
      'activePowerW': p,
      'expectedPowerW': 100,
      'powerFactor': b?.powerFactor,
      'diagnostics': snap.ac1Result?.diagnostics.map((d) => d.message).toList(),
    });
    expect(okay, isTrue);
  });

  test('PHYS-AC3: symmetrical star L1/L2/L3/N and neutral current', () {
    final snap = _runtime.evaluate(_ac3BalancedStar());
    final result = snap.ac3Result;
    final branches = <String>['a', 'b', 'c']
        .map((id) => result?.branch('component:$id')).toList();
    final currents = branches
        .map((b) => b?.current?.magnitude ?? double.nan).toList();
    final okay = snap.solved &&
        currents.every((i) => (i - (230 / 529)).abs() < 0.001) &&
        (result!.neutralCurrent.magnitude < 0.001);
    _result('ac3-star', 'balanced-230V-50Hz', okay ? 'PASS' : 'FAIL', {
      'solved': snap.solved,
      'phaseCurrentsA': currents,
      'neutralCurrentA': result?.neutralCurrent.magnitude,
      'phaseSequence': result?.sourceSequence.name,
      'voltageBalanced': result?.voltageBalanced,
      'currentBalanced': result?.currentBalanced,
      'diagnostics': result?.diagnostics.map((d) => d.message).toList(),
    });
    expect(okay, isTrue);
  });

  test('PHYS-V2: execute all native healthy examples and faulty circuits', () {
    final lib = buildV2ProductLibrary();
    expect(lib.allValidated, isTrue);
    expect(lib.allNativeV2, isTrue);
    final exceptions = <String>[];
    for (final example in lib.schemas) {
      try {
        final snap = _runtime.evaluate(example.circuit);
        _result('v2-healthy', example.id.value,
            snap.solved ? 'PASS' : 'UNRESOLVED', {
          'mode': example.circuit.mode.name,
          'solved': snap.solved,
          'diagnosticCount': snap.diagnostics.advice.length,
        });
        if (!snap.solved) exceptions.add(example.id.value);
      } catch (error) {
        exceptions.add(example.id.value);
        _result('v2-healthy', example.id.value, 'EXCEPTION', {'error': '$error'});
      }
    }
    for (final example in lib.faultScenarios) {
      try {
        final snap = _runtime.evaluate(example.faultyCircuit);
        _result('v2-fault', example.id.value, 'OBSERVED', {
          'mode': example.faultyCircuit.mode.name,
          'solved': snap.solved,
          'diagnosticCount': snap.diagnostics.advice.length,
        });
      } catch (error) {
        exceptions.add(example.id.value);
        _result('v2-fault', example.id.value, 'EXCEPTION', {'error': '$error'});
      }
    }
    expect(exceptions, isEmpty, reason: exceptions.join(', '));
  });
}
