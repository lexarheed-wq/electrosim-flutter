import 'package:electrosim/runtime/electrosim_runtime_engine.dart';
import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:electrosim_solver_ac/electrosim_solver_ac.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lib/f9_component_palette.dart';

void main() {
  test('timer, PLC and existing locking contacts are available in AC3', () {
    final ComponentModelContract timer = CoreComponentModelContracts.registry
        .resolve('timer_star_delta')!;
    final ComponentModelContract plc = CoreComponentModelContracts.registry
        .resolve('plc_ac3')!;
    expect(timer.supportsMode(ElectricalMode.ac3), isTrue);
    expect(timer.terminalCount, 5);
    expect(plc.supportsMode(ElectricalMode.ac3), isTrue);
    expect(plc.terminalCount, 10);
    expect(plc.branches, isEmpty);
    expect(
      f9PaletteCatalog.singleWhere((item) => item.modelType == 'timer_star_delta')
          .supportsMode(ElectricalMode.ac3),
      isTrue,
    );
    expect(
      f9PaletteCatalog.singleWhere((item) => item.modelType == 'plc_ac3')
          .supportsMode(ElectricalMode.ac3),
      isTrue,
    );
    expect(
      f9PaletteCatalog.any((item) => item.modelType == 'contactor_aux_no'),
      isTrue,
    );
    expect(
      f9PaletteCatalog.any((item) => item.modelType == 'contactor_aux_nc'),
      isTrue,
    );
    expect(
      f9PaletteCatalog.singleWhere((item) => item.modelType == 'plc_ac3')
          .terminalLabels.take(2).toList(),
      <String>['L+ 24 V', 'M 0 V'],
    );
  });

  test('24 V command supply and field sensors are available in their modes', () {
    expect(
      f9PaletteCatalog.singleWhere((item) => item.keyName == 'source-control-24v')
          .supportsMode(ElectricalMode.dc),
      isTrue,
    );
    for (final String model in <String>[
      'proximity_sensor_24v',
      'limit_switch_no',
      'limit_switch_nc',
    ]) {
      expect(
        CoreComponentModelContracts.registry.resolve(model)?.supportsMode(
              ElectricalMode.dc,
            ),
        isTrue,
        reason: '$model should have a DC electrical contract',
      );
      expect(
        f9PaletteCatalog.any((item) => item.modelType == model),
        isTrue,
      );
    }
  });

  test('star-delta timer opens NC then closes NO after the dead time', () {
    final CircuitState circuit = _timerCircuit();
    const ElectroSimRuntimeEngine engine = ElectroSimRuntimeEngine();
    final ElectroSimRuntimeSnapshot initial = engine.evaluate(circuit);
    expect(initial.solved, isTrue, reason: _diagnostics(initial));
    final ComponentInstance initialTimer = initial.effectiveCircuit.components
        .singleWhere((ComponentInstance component) => component.id.value == 'timer');
    expect(initialTimer.controlState['timerActuated'], isTrue);

    final ElectroSimRuntimeSnapshot switched = engine.advance(
      circuit,
      elapsed: const Duration(milliseconds: 150),
      previousContactorStates: <ComponentId, bool>{
        ComponentId('timer'): true,
      },
      previousControlStates: <ComponentId, Map<String, Object?>>{
        ComponentId('timer'): <String, Object?>{'elapsedSeconds': 0.0},
      },
    );
    expect(switched.solved, isTrue, reason: _diagnostics(switched));
    final ComponentInstance timer = switched.effectiveCircuit.components.singleWhere(
      (ComponentInstance component) => component.id.value == 'timer',
    );
    expect(timer.controlState['timerNcClosed'], isFalse);
    expect(timer.controlState['timerNoClosed'], isTrue);
  });

  test('PLC Ladder Q0 drives the explicitly linked contactor', () {
    final CircuitState circuit = _plcCircuit();
    final ElectroSimRuntimeSnapshot snapshot = const ElectroSimRuntimeEngine()
        .evaluate(circuit);
    expect(snapshot.solved, isTrue, reason: _diagnostics(snapshot));
    expect(snapshot.contactorActuated(ComponentId('k1')), isTrue);
    expect(snapshot.contactorActuated(ComponentId('k2')), isFalse);
    expect(
      circuit.components.singleWhere((ComponentInstance c) => c.id.value == 'k1')
          .controlState['plcCommand'],
      isNull,
      reason: 'runtime projection must leave the authored contactor unchanged',
    );
    final CircuitState stopped = CircuitState(
      circuitId: circuit.circuitId,
      revision: circuit.revision + 1,
      mode: circuit.mode,
      sources: circuit.sources,
      components: circuit.components.map((ComponentInstance c) =>
          c.id.value == 'button'
              ? ComponentInstance(
                  id: c.id,
                  modelType: c.modelType,
                  terminals: c.terminals,
                  parameters: c.parameters,
                  controlState: const <String, Object?>{'pressed': false},
                )
              : c).toList(),
      connections: circuit.connections,
      settings: circuit.settings,
    );
    final ElectroSimRuntimeSnapshot stoppedSnapshot = const ElectroSimRuntimeEngine()
        .evaluate(stopped);
    expect(stoppedSnapshot.contactorActuated(ComponentId('k1')), isFalse);
  });

  test('PLC TON retains elapsed time across runtime scans', () {
    final CircuitState baseCircuit = _timerCircuit();
    final ComponentInstance basePlc = ComponentInstance(
      id: ComponentId('plc-ton'),
      modelType: 'plc_ac3',
      terminals: <Terminal>[
        for (int index = 0; index < 10; index++)
          _terminal('plc-ton-$index', 'PLC-$index', PhaseTag.none, TerminalRole.generic),
      ],
      parameters: const <String, Object?>{
        'ladderProgram': <Object?>[
          <String, Object?>{
            'steps': <Object?>[
              <String, Object?>{'type': 'contact_no', 'address': 'I0'},
              <String, Object?>{'type': 'TON', 'address': 'T0', 'presetSeconds': 0.2},
            ],
          },
          <String, Object?>{
            'steps': <Object?>[
              <String, Object?>{'type': 'timer_done', 'address': 'T0'},
              <String, Object?>{'type': 'coil', 'address': 'Q0'},
            ],
          },
        ],
      },
      controlState: const <String, Object?>{'I0': true},
    );
    final List<Terminal> plcTerminals = <Terminal>[
      for (int index = 0; index < 10; index++)
        _terminal('plc-ton-$index', 'PLC-$index', PhaseTag.none, TerminalRole.generic),
    ];
    final List<Connection> plcWires = <Connection>[
      ...baseCircuit.connections,
      _wire('plc-ton-i0-a', 'plc-ton-2', 'button-a'),
      _wire('plc-ton-i0-b', 'plc-ton-3', 'button-b'),
    ];
    final ComponentInstance activePlc = ComponentInstance(
      id: basePlc.id,
      modelType: basePlc.modelType,
      terminals: plcTerminals,
      parameters: basePlc.parameters,
      controlState: basePlc.controlState,
    );
    final CircuitState withPlc = CircuitState(
      circuitId: baseCircuit.circuitId,
      revision: baseCircuit.revision,
      mode: baseCircuit.mode,
      sources: baseCircuit.sources,
      components: <ComponentInstance>[
        ...baseCircuit.components,
        activePlc,
        ComponentInstance(
          id: ComponentId('button'),
          modelType: 'push_button_no',
          terminals: <Terminal>[
            _terminal('button-a', '13', PhaseTag.none, TerminalRole.generic),
            _terminal('button-b', '14', PhaseTag.none, TerminalRole.generic),
          ],
          controlState: const <String, Object?>{'pressed': true},
        ),
      ],
      connections: plcWires,
      settings: baseCircuit.settings,
    );
    final ElectroSimRuntimeEngine engine = const ElectroSimRuntimeEngine();
    final ElectroSimRuntimeSnapshot first = engine.advance(
      withPlc,
      elapsed: const Duration(milliseconds: 100),
    );
    final ElectroSimRuntimeSnapshot second = engine.advance(
      withPlc,
      elapsed: const Duration(milliseconds: 100),
      previousControlStates: first.controlRuntimeStates,
    );
    final ComponentInstance plc = second.effectiveCircuit.components.singleWhere(
      (ComponentInstance component) => component.id.value == 'plc-ton',
    );
    expect(plc.controlState['ton:T0'], 0.2);
    expect(plc.controlState['T0.DN'], isTrue);
    expect(plc.controlState['Q0'], isTrue);
  });

  test('PLC reset coil only resets memory when its rung is energized', () {
    final CircuitState circuit = _plcCircuitWithProgram(<Object?>[
      <String, Object?>{
        'steps': <Object?>[
          <String, Object?>{'type': 'contact_no', 'address': 'I0'},
          <String, Object?>{'type': 'coil_set', 'address': 'M0'},
        ],
      },
      <String, Object?>{
        'steps': <Object?>[
          <String, Object?>{'type': 'contact_no', 'address': 'I1'},
          <String, Object?>{'type': 'coil_reset', 'address': 'M0'},
        ],
      },
      <String, Object?>{
        'steps': <Object?>[
          <String, Object?>{'type': 'contact_no', 'address': 'M0'},
          <String, Object?>{'type': 'coil', 'address': 'Q0'},
        ],
      },
    ]);
    final ElectroSimRuntimeSnapshot snapshot = const ElectroSimRuntimeEngine()
        .evaluate(circuit);
    final ComponentInstance plc = snapshot.effectiveCircuit.components
        .singleWhere((ComponentInstance component) => component.id.value == 'plc');
    expect(plc.controlState['M0'], isTrue);
    expect(plc.controlState['Q0'], isTrue);
  });

  test('malformed Ladder fails safe and reports an error', () {
    final CircuitState circuit = _plcCircuitWithProgram(<Object?>[
      <String, Object?>{
        'steps': <Object?>[
          <String, Object?>{'type': 'contact_no', 'address': 'I99'},
          <String, Object?>{'type': 'coil', 'address': 'Q0'},
        ],
      },
    ]);
    final ElectroSimRuntimeSnapshot snapshot = const ElectroSimRuntimeEngine()
        .evaluate(circuit);
    final ComponentInstance plc = snapshot.effectiveCircuit.components
        .singleWhere((ComponentInstance component) => component.id.value == 'plc');
    expect(plc.controlState['programError'], isTrue);
    expect(plc.controlState['Q0'], isFalse);
    expect(snapshot.contactorActuated(ComponentId('k1')), isFalse);
  });

  test('PLC invalid 24 V control supply disables all outputs', () {
    final CircuitState circuit = _plcCircuitWithParameters(
      <String, Object?>{
        'controlVoltageV': 12.0,
        'outputLinks': <String, Object?>{'Q0': 'k1'},
        'ladderProgram': <Object?>[
          <String, Object?>{
            'steps': <Object?>[
              <String, Object?>{'type': 'coil', 'address': 'Q0'},
            ],
          },
        ],
      },
    );
    final ElectroSimRuntimeSnapshot snapshot = const ElectroSimRuntimeEngine()
        .evaluate(circuit);
    final ComponentInstance plc = snapshot.effectiveCircuit.components
        .singleWhere((ComponentInstance component) => component.id.value == 'plc');
    expect(plc.controlState['supplyValid'], isFalse);
    expect(plc.controlState['programError'], isTrue);
    expect(snapshot.contactorActuated(ComponentId('k1')), isFalse);
  });
}

String _diagnostics(ElectroSimRuntimeSnapshot snapshot) => snapshot.ac3Result
    ?.diagnostics
    .map((Ac3SolverDiagnostic issue) => issue.message)
    .join(' | ') ?? 'AC3 result missing';

CircuitState _timerCircuit() => CircuitState(
  circuitId: CircuitId('star-delta-timer'),
  revision: 0,
  mode: ElectricalMode.ac3,
  sources: <SourceInstance>[
    SourceInstance(
      id: SourceId('grid'),
      modelType: 'ac3_voltage_source',
      terminals: <Terminal>[
        _terminal('l1', 'L1', PhaseTag.l1, TerminalRole.phaseL1),
        _terminal('l2', 'L2', PhaseTag.l2, TerminalRole.phaseL2),
        _terminal('l3', 'L3', PhaseTag.l3, TerminalRole.phaseL3),
        _terminal('n', 'N', PhaseTag.neutral, TerminalRole.neutral),
      ],
      parameters: const <String, Object?>{'phaseVoltageRmsV': 230.0},
    ),
  ],
  components: <ComponentInstance>[
    ComponentInstance(
      id: ComponentId('timer'),
      modelType: 'timer_star_delta',
      terminals: <Terminal>[
        _terminal('timer-a1', 'A1', PhaseTag.l1, TerminalRole.coilA1),
        _terminal('timer-a2', 'A2', PhaseTag.neutral, TerminalRole.coilA2),
        _terminal('timer-15', '15', PhaseTag.none, TerminalRole.generic),
        _terminal('timer-16', '16', PhaseTag.none, TerminalRole.generic),
        _terminal('timer-18', '18', PhaseTag.none, TerminalRole.generic),
      ],
      parameters: const <String, Object?>{
        'delaySeconds': 0.1,
        'deadTimeSeconds': 0.05,
        'coilResistanceOhm': 1000.0,
        'coilInductanceH': 0.0,
        'coilPickupVoltageV': 180.0,
        'coilDropoutVoltageV': 100.0,
      },
    ),
  ],
  connections: <Connection>[
    _wire('phase', 'l1', 'timer-a1'),
    _wire('neutral', 'n', 'timer-a2'),
  ],
  settings: const <String, Object?>{'frequencyHz': 50.0},
);

Terminal _terminal(String id, String name, PhaseTag phase, TerminalRole role) =>
    Terminal(id: TerminalId(id), name: name, phase: phase, role: role);

Connection _wire(String id, String first, String second) => Connection(
  id: ConnectionId(id),
  fromTerminalId: TerminalId(first),
  toTerminalId: TerminalId(second),
);

CircuitState _plcCircuit() => _plcCircuitWithProgram(<Object?>[
  <String, Object?>{
    'steps': <Object?>[
      <String, Object?>{'type': 'contact_no', 'address': 'I0'},
      <String, Object?>{'type': 'coil', 'address': 'Q0'},
    ],
  },
]);

CircuitState _plcCircuitWithProgram(List<Object?> ladderProgram) {
  final CircuitState base = _plcCircuitWithParameters(<String, Object?>{
    'controlVoltageV': 24.0,
    'outputLinks': <String, Object?>{'Q0': 'k1'},
    'ladderProgram': ladderProgram,
  });
  return base;
}

CircuitState _plcCircuitWithParameters(Map<String, Object?> plcParameters) {
  final CircuitState base = _timerCircuit();
  final ComponentInstance timer = base.components.single;
  final List<Terminal> k1Terminals = <Terminal>[
    _terminal('k1-l1', '1L1', PhaseTag.l1, TerminalRole.lineL1),
    _terminal('k1-l2', '3L2', PhaseTag.l2, TerminalRole.lineL2),
    _terminal('k1-l3', '5L3', PhaseTag.l3, TerminalRole.lineL3),
    _terminal('k1-t1', '2T1', PhaseTag.l1, TerminalRole.loadT1),
    _terminal('k1-t2', '4T2', PhaseTag.l2, TerminalRole.loadT2),
    _terminal('k1-t3', '6T3', PhaseTag.l3, TerminalRole.loadT3),
    _terminal('k1-a1', 'A1', PhaseTag.l1, TerminalRole.coilA1),
    _terminal('k1-a2', 'A2', PhaseTag.neutral, TerminalRole.coilA2),
  ];
  final List<Terminal> k2Terminals = <Terminal>[
    _terminal('k2-l1', '1L1', PhaseTag.l1, TerminalRole.lineL1),
    _terminal('k2-l2', '3L2', PhaseTag.l2, TerminalRole.lineL2),
    _terminal('k2-l3', '5L3', PhaseTag.l3, TerminalRole.lineL3),
    _terminal('k2-t1', '2T1', PhaseTag.l1, TerminalRole.loadT1),
    _terminal('k2-t2', '4T2', PhaseTag.l2, TerminalRole.loadT2),
    _terminal('k2-t3', '6T3', PhaseTag.l3, TerminalRole.loadT3),
    _terminal('k2-a1', 'A1', PhaseTag.l1, TerminalRole.coilA1),
    _terminal('k2-a2', 'A2', PhaseTag.neutral, TerminalRole.coilA2),
  ];
  final List<Terminal> plcTerminals = <Terminal>[
    for (int i = 0; i < 10; i++)
      _terminal('plc-$i', 'PLC-$i', PhaseTag.none, i == 8 ? TerminalRole.output : i >= 2 && i <= 5 ? TerminalRole.input : TerminalRole.generic),
  ];
  return CircuitState(
    circuitId: CircuitId('plc-coil-control'),
    revision: 0,
    mode: ElectricalMode.ac3,
    sources: base.sources,
    components: <ComponentInstance>[
      ComponentInstance(
        id: ComponentId('plc'),
        modelType: 'plc_ac3',
        terminals: plcTerminals,
        parameters: plcParameters,
        controlState: const <String, Object?>{},
      ),
      for (final String id in <String>['k1', 'k2'])
        ComponentInstance(
          id: ComponentId(id),
          modelType: 'contactor_3p',
          terminals: id == 'k1' ? k1Terminals : k2Terminals,
          parameters: const <String, Object?>{
            'coilResistanceOhm': 1000.0,
            'coilInductanceH': 0.0,
            'coilPickupVoltageV': 180.0,
            'coilDropoutVoltageV': 100.0,
          },
        ),
      timer,
      ComponentInstance(
        id: ComponentId('button'),
        modelType: 'push_button_no',
        terminals: <Terminal>[
          _terminal('button-a', '13', PhaseTag.none, TerminalRole.generic),
          _terminal('button-b', '14', PhaseTag.none, TerminalRole.generic),
        ],
        controlState: const <String, Object?>{'pressed': true},
      ),
    ],
    connections: <Connection>[
      for (final String id in <String>['k1', 'k2']) ...<Connection>[
        _wire('$id-l1', 'l1', '$id-l1'),
        _wire('$id-l2', 'l2', '$id-l2'),
        _wire('$id-l3', 'l3', '$id-l3'),
      ],
      _wire('plc-in-a', 'plc-2', 'button-a'),
      _wire('plc-in-b', 'plc-3', 'button-b'),
      _wire('k1-coil-phase', 'l1', 'k1-a1'),
      _wire('k1-n', 'k1-a2', 'n'),
    ],
    settings: const <String, Object?>{'frequencyHz': 50.0},
  );
}
