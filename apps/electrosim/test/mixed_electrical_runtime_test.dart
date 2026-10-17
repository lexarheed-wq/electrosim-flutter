import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:electrosim_controls/electrosim_controls.dart';
import 'package:electrosim_multiphysics/electrosim_multiphysics.dart';
import 'package:electrosim_solver_ac/electrosim_solver_ac.dart';
import 'package:electrosim/f9_source_voltage_readout.dart';
import 'package:electrosim/runtime/electrical_project_runtime_engine.dart';
import 'package:electrosim/runtime/electrosim_runtime_engine.dart';
import 'package:flutter_test/flutter_test.dart';

CircuitState _empty(String id, ElectricalMode mode) => CircuitState(
  circuitId: CircuitId(id), revision: 0, mode: mode,
);

CircuitState _plcCircuit({bool supply = true, bool validProgram = true, bool startCommand = true}) {
  final ComponentInstance plc = ComponentInstance(
    id: ComponentId('plc'), modelType: 'plc_dc',
    terminals: <Terminal>[
      for (int i = 0; i < 10; i++) Terminal(id: TerminalId('plc-$i'), name: 'T$i'),
    ],
    parameters: <String, Object?>{'ladderProgram': <Object?>[
      for (final String output in <String>['Q0', 'Q1'])
        <String, Object?>{'steps': <Object?>[
          <String, Object?>{'type': validProgram ? 'contact_no' : 'unsupported', 'address': 'I0'},
          <String, Object?>{'type': 'coil', 'address': output},
        ]},
    ]},
  );
  final SourceInstance source = SourceInstance(
    id: SourceId('s24'), modelType: 'dc_voltage_source', enabled: supply,
    terminals: <Terminal>[
      Terminal(id: TerminalId('s24-pos'), name: '+', phase: PhaseTag.dcPositive),
      Terminal(id: TerminalId('s24-neg'), name: '-', phase: PhaseTag.dcNegative),
    ], parameters: const <String, Object?>{'voltageV': 24.0},
  );
  return CircuitState(
    circuitId: CircuitId('dc'), revision: 0, mode: ElectricalMode.dc,
    components: <ComponentInstance>[plc], sources: <SourceInstance>[source],
    connections: <Connection>[
      Connection(id: ConnectionId('supply-positive'), fromTerminalId: TerminalId('s24-pos'), toTerminalId: TerminalId('plc-0')),
      Connection(id: ConnectionId('supply-negative'), fromTerminalId: TerminalId('s24-neg'), toTerminalId: TerminalId('plc-1')),
      if (startCommand)
        Connection(id: ConnectionId('input'), fromTerminalId: TerminalId('s24-pos'), toTerminalId: TerminalId('plc-2')),
    ],
  );
}

CircuitState _targetCircuit(ElectricalMode targetMode) => CircuitState(
  circuitId: CircuitId('target'), revision: 0, mode: targetMode,
  components: <ComponentInstance>[
      ComponentInstance(id: ComponentId('k1'), modelType: targetMode == ElectricalMode.ac1 ? 'contactor_ac1' : 'contactor_3p',
        terminals: <Terminal>[for (int i = 0; i < (targetMode == ElectricalMode.ac1 ? 4 : 8); i++) Terminal(id: TerminalId('k1-$i'), name: 'T$i')],
        parameters: const <String, Object?>{'coilResistanceOhm': 1000.0, 'coilPickupVoltageV': 20.0, 'coilDropoutVoltageV': 5.0}),
  ],
);

ElectricalProject _actuatorProject(ElectricalMode targetMode, {bool supply = true, bool validProgram = true, bool startCommand = true}) => ElectricalProject(
  networks: <ElectricalNetwork>[
    ElectricalNetwork(id: 'control', circuit: _plcCircuit(supply: supply, validProgram: validProgram, startCommand: startCommand)),
    ElectricalNetwork(id: 'target', circuit: _targetCircuit(targetMode)),
  ],
  actuatorLinks: <CrossNetworkActuatorLink>[
    CrossNetworkActuatorLink(id: 'cmd', plcNetworkId: 'control', plcComponentId: 'plc',
      outputAddress: 'Q0', targetNetworkId: 'target', contactorId: 'k1'),
  ],
);

CircuitState _pvInverterCircuit() => CircuitState(
  circuitId: CircuitId('solar'), revision: 0, mode: ElectricalMode.pv,
  components: <ComponentInstance>[
    ComponentInstance(id: ComponentId('inv'), modelType: 'pv_inverter', terminals: <Terminal>[
      Terminal(id: TerminalId('inv-dc-pos'), name: 'DC+', role: TerminalRole.positive, phase: PhaseTag.dcPositive),
      Terminal(id: TerminalId('inv-dc-neg'), name: 'DC-', role: TerminalRole.negative, phase: PhaseTag.dcNegative),
      Terminal(id: TerminalId('inv-line'), name: 'L', role: TerminalRole.line, phase: PhaseTag.l1),
      Terminal(id: TerminalId('inv-neutral'), name: 'N', role: TerminalRole.neutral, phase: PhaseTag.neutral),
    ], parameters: const <String, Object?>{
      'minDcVoltageV': 300.0, 'maxDcVoltageV': 500.0, 'nominalAcVoltageV': 230.0,
      'ratedAcPowerW': 3500.0, 'efficiency': 0.95,
    }),
  ],
  sources: <SourceInstance>[
    SourceInstance(id: SourceId('array'), modelType: 'pv_array', terminals: <Terminal>[
      Terminal(id: TerminalId('array-pos'), name: '+', phase: PhaseTag.dcPositive),
      Terminal(id: TerminalId('array-neg'), name: '-', phase: PhaseTag.dcNegative),
    ], parameters: const <String, Object?>{
      'mppVoltageV': 400.0, 'mppCurrentA': 10.0,
      'powerTemperatureCoefficientPerC': 0.0, 'voltageTemperatureCoefficientPerC': 0.0,
    }),
  ],
  connections: <Connection>[
    Connection(id: ConnectionId('pv-positive'), fromTerminalId: TerminalId('array-pos'), toTerminalId: TerminalId('inv-dc-pos'), phase: PhaseTag.dcPositive),
    Connection(id: ConnectionId('pv-negative'), fromTerminalId: TerminalId('array-neg'), toTerminalId: TerminalId('inv-dc-neg'), phase: PhaseTag.dcNegative),
  ],
  settings: const <String, Object?>{'irradianceWm2': 1000.0, 'cellTemperatureC': 25.0, 'shadingPct': 0.0},
);

CircuitState _acLoadCircuit() => CircuitState(
  circuitId: CircuitId('load'), revision: 0, mode: ElectricalMode.ac1,
  components: <ComponentInstance>[
    ComponentInstance(id: ComponentId('load'), modelType: 'resistor', terminals: <Terminal>[
      Terminal(id: TerminalId('load-line'), name: 'L', role: TerminalRole.line, phase: PhaseTag.l1),
      Terminal(id: TerminalId('load-neutral'), name: 'N', role: TerminalRole.neutral, phase: PhaseTag.neutral),
    ], parameters: const <String, Object?>{'resistanceOhm': 100.0}),
  ],
  settings: const <String, Object?>{'frequencyHz': 50.0},
);

CircuitState _ac3MotorCircuit() {
  Terminal terminal(String id, String name, PhaseTag phase, TerminalRole role) =>
      Terminal(id: TerminalId(id), name: name, phase: phase, role: role);
  Connection wire(String id, String from, String to) => Connection(
    id: ConnectionId(id), fromTerminalId: TerminalId(from), toTerminalId: TerminalId(to),
  );
  return CircuitState(
    circuitId: CircuitId('mixed-power-motor'), revision: 0, mode: ElectricalMode.ac3,
    sources: <SourceInstance>[SourceInstance(
      id: SourceId('grid'), modelType: 'ac3_voltage_source',
      terminals: <Terminal>[
        terminal('grid-l1', 'L1', PhaseTag.l1, TerminalRole.phaseL1),
        terminal('grid-l2', 'L2', PhaseTag.l2, TerminalRole.phaseL2),
        terminal('grid-l3', 'L3', PhaseTag.l3, TerminalRole.phaseL3),
        terminal('grid-n', 'N', PhaseTag.neutral, TerminalRole.neutral),
      ], parameters: const <String, Object?>{'phaseVoltageRmsV': 230.0},
    )],
    components: <ComponentInstance>[
      ComponentInstance(id: ComponentId('k1'), modelType: 'contactor_3p',
        terminals: <Terminal>[
          terminal('k1-1', '1L1', PhaseTag.l1, TerminalRole.lineL1),
          terminal('k1-3', '3L2', PhaseTag.l2, TerminalRole.lineL2),
          terminal('k1-5', '5L3', PhaseTag.l3, TerminalRole.lineL3),
          terminal('k1-2', '2T1', PhaseTag.l1, TerminalRole.loadT1),
          terminal('k1-4', '4T2', PhaseTag.l2, TerminalRole.loadT2),
          terminal('k1-6', '6T3', PhaseTag.l3, TerminalRole.loadT3),
          terminal('k1-a1', 'A1', PhaseTag.l1, TerminalRole.coilA1),
          terminal('k1-a2', 'A2', PhaseTag.neutral, TerminalRole.coilA2),
        ], parameters: const <String, Object?>{
          'coilResistanceOhm': 1000.0, 'coilInductanceH': 0.0,
          'coilPickupVoltageV': 180.0, 'coilDropoutVoltageV': 100.0,
        }),
      ComponentInstance(id: ComponentId('motor'), modelType: 'motor_3p_6t',
        terminals: <Terminal>[
          terminal('m-u1', 'U1', PhaseTag.l1, TerminalRole.lineL1),
          terminal('m-v1', 'V1', PhaseTag.l2, TerminalRole.lineL2),
          terminal('m-w1', 'W1', PhaseTag.l3, TerminalRole.lineL3),
          terminal('m-u2', 'U2', PhaseTag.none, TerminalRole.loadT1),
          terminal('m-v2', 'V2', PhaseTag.none, TerminalRole.loadT2),
          terminal('m-w2', 'W2', PhaseTag.none, TerminalRole.loadT3),
        ], parameters: const <String, Object?>{'resistanceOhm': 18.0, 'inductanceH': 0.035}),
    ],
    connections: <Connection>[
      wire('in-1', 'grid-l1', 'k1-1'), wire('in-2', 'grid-l2', 'k1-3'),
      wire('in-3', 'grid-l3', 'k1-5'), wire('out-1', 'k1-2', 'm-u1'),
      wire('out-2', 'k1-4', 'm-v1'), wire('out-3', 'k1-6', 'm-w1'),
      wire('star-1', 'm-u2', 'm-v2'), wire('star-2', 'm-v2', 'm-w2'),
    ], settings: const <String, Object?>{'frequencyHz': 50.0},
  );
}

void main() {
  test('mixedRuntimeSolvesEveryPresentDomainWithItsOwnSolver', () {
    final ElectricalProject project = ElectricalProject(networks: <ElectricalNetwork>[
      for (final ElectricalMode mode in <ElectricalMode>[
        ElectricalMode.dc, ElectricalMode.ac1, ElectricalMode.ac3, ElectricalMode.pv,
      ])
        ElectricalNetwork(id: mode.name, circuit: _empty(mode.name, mode)),
    ]);

    final ElectricalProjectRuntimeSnapshot result = const ElectricalProjectRuntimeEngine()
        .advance(project, elapsed: const Duration(milliseconds: 50));

    expect(result.networks.keys, containsAll(<String>['dc', 'ac1', 'ac3', 'pv']));
    expect(result.networks['dc']!.solverKind, ElectroSimRuntimeSolverKind.dc);
    expect(result.networks['ac1']!.solverKind, ElectroSimRuntimeSolverKind.ac1);
    expect(result.networks['ac3']!.solverKind, ElectroSimRuntimeSolverKind.ac3);
    expect(result.networks['pv']!.solverKind, ElectroSimRuntimeSolverKind.pv);
    expect(result.elapsed, const Duration(milliseconds: 50));
  });

  test('mixedRuntimeAllowsAnySubsetOfDomains', () {
    for (final List<ElectricalMode> modes in <List<ElectricalMode>>[
      <ElectricalMode>[ElectricalMode.dc, ElectricalMode.ac3],
      <ElectricalMode>[ElectricalMode.pv, ElectricalMode.ac1],
    ]) {
      final ElectricalProject project = ElectricalProject(networks: <ElectricalNetwork>[
        for (final ElectricalMode mode in modes)
          ElectricalNetwork(id: mode.name, circuit: _empty(mode.name, mode)),
      ]);
      final ElectricalProjectRuntimeSnapshot result = const ElectricalProjectRuntimeEngine()
          .advance(project, elapsed: Duration.zero);
      expect(result.networks.keys, containsAll(modes.map((ElectricalMode m) => m.name)));
      expect(result.diagnostics, isEmpty);
    }
  });

  test('CC source and PLC remain powered while the AC3 network is simulated', () {
    final ElectricalProject project = ElectricalProject(networks: <ElectricalNetwork>[
      ElectricalNetwork(id: 'control', circuit: _plcCircuit()),
      ElectricalNetwork(id: 'power', circuit: _ac3MotorCircuit()),
    ]);
    final ElectricalProjectRuntimeEngine engine = const ElectricalProjectRuntimeEngine();

    // The mixed workspace's AC3 chip only changes the selected view. Both
    // homogeneous networks must continue advancing on every shared clock tick.
    ElectricalProjectRuntimeSnapshot runtime = engine.advance(
      project, elapsed: const Duration(milliseconds: 250),
    );
    runtime = engine.advance(
      project,
      elapsed: const Duration(milliseconds: 250),
      previous: runtime,
    );

    final ElectroSimRuntimeSnapshot control = runtime.networks['control']!;
    final ElectroSimRuntimeSnapshot power = runtime.networks['power']!;
    expect(control.solverKind, ElectroSimRuntimeSolverKind.dc);
    expect(control.dcResult?.isSolved, isTrue);
    expect(power.solverKind, ElectroSimRuntimeSolverKind.ac3);
    expect(power.ac3Result?.isSolved, isTrue);
    expect(
      F9SourceVoltageReadout.voltageV(
        control,
        control.circuit.sources.single,
        simulationRunning: true,
      ),
      closeTo(24.0, 1e-6),
    );
    final ComponentInstance plc = control.effectiveCircuit.components.single;
    expect(plc.controlState['plcSupplyValid'], isTrue);
    expect(plc.controlState['supplyVoltageV'], closeTo(24.0, 1e-6));
  });

  test('mixedRuntimeAdvancesElapsedOnceAndRejectsMixedSolverInput', () {
    final ElectricalProject project = ElectricalProject(networks: <ElectricalNetwork>[
      ElectricalNetwork(id: 'dc', circuit: _empty('dc', ElectricalMode.dc)),
      ElectricalNetwork(id: 'pv', circuit: _empty('pv', ElectricalMode.pv)),
    ]);
    final ElectricalProjectRuntimeSnapshot result = const ElectricalProjectRuntimeEngine()
        .advance(project, elapsed: const Duration(seconds: 2));
    expect(result.elapsed, const Duration(seconds: 2));
    expect(
      () => const ElectroSimRuntimeEngine().advance(
        _empty('board', ElectricalMode.mixed), elapsed: Duration.zero,
      ),
      throwsArgumentError,
    );
  });

  test('PLC Q output directly commands AC1 and AC3 contactors', () {
    for (final ElectricalMode mode in <ElectricalMode>[ElectricalMode.ac1, ElectricalMode.ac3]) {
      final ElectricalProjectRuntimeSnapshot result = const ElectricalProjectRuntimeEngine()
          .advance(_actuatorProject(mode), elapsed: const Duration(milliseconds: 20));
      expect(result.networks['target']!.contactorActuated(ComponentId('k1')), isTrue,
          reason: 'PLC Q0 should actuate the linked ${mode.name} contactor without a relay coil');
    }
  });

  test('mixed PLC command starts and stops a wired AC3 motor through contactor poles', () {
    ElectricalProject motorProject({required bool startCommand}) => ElectricalProject(
      networks: <ElectricalNetwork>[
        ElectricalNetwork(id: 'control', circuit: _plcCircuit(startCommand: startCommand)),
        ElectricalNetwork(id: 'power', circuit: _ac3MotorCircuit()),
      ],
      actuatorLinks: <CrossNetworkActuatorLink>[
        CrossNetworkActuatorLink(
          id: 'motor-start', plcNetworkId: 'control', plcComponentId: 'plc',
          outputAddress: 'Q0', targetNetworkId: 'power', contactorId: 'k1',
        ),
      ],
    );

    final engine = const ElectricalProjectRuntimeEngine();
    final started = engine.advance(
      motorProject(startCommand: true), elapsed: const Duration(milliseconds: 20),
    );
    final motorBranches = started.networks['power']!.ac3Result!.branchResults
        .where((branch) => branch.id.startsWith('component:motor:'))
        .toList();
    expect(started.networks['power']!.ac3Result!.isSolved, isTrue);
    expect(started.networks['power']!.contactorActuated(ComponentId('k1')), isTrue);
    expect(motorBranches, hasLength(3));
    expect(motorBranches.every((branch) => (branch.current?.magnitude ?? 0) > 0.01), isTrue);

    final stopped = engine.advance(
      motorProject(startCommand: false), elapsed: const Duration(milliseconds: 20),
    );
    expect(stopped.networks['power']!.contactorActuated(ComponentId('k1')), isFalse);
    expect(stopped.networks['power']!.ac3Result!.branchResults
        .where((branch) => branch.id.startsWith('component:motor:'))
        .every((branch) => (branch.current?.magnitude ?? 0) < 1e-7), isTrue);
  });

  test('PLC supply loss safely releases a directly linked contactor', () {
    final ElectricalProjectRuntimeSnapshot result = const ElectricalProjectRuntimeEngine()
        .advance(_actuatorProject(ElectricalMode.ac3, supply: false), elapsed: const Duration(milliseconds: 20));
    expect(result.networks['target']!.contactorActuated(ComponentId('k1')), isFalse);
    expect(result.diagnostics, isNotEmpty);
  });

  test('Invalid PLC Ladder logic safely releases its linked contactor', () {
    final ElectricalProjectRuntimeSnapshot result = const ElectricalProjectRuntimeEngine()
        .advance(_actuatorProject(ElectricalMode.ac3, validProgram: false), elapsed: const Duration(milliseconds: 20));
    expect(result.networks['target']!.contactorActuated(ComponentId('k1')), isFalse);
    expect(result.diagnostics.any((String diagnostic) => diagnostic.contains('programme Ladder invalide')), isTrue);
  });

  test('PLC demands cannot bypass an AC3 mechanical interlock', () {
    final CircuitState power = CircuitState(
      circuitId: CircuitId('interlocked'), revision: 0, mode: ElectricalMode.ac3,
      components: <ComponentInstance>[
        for (final String id in <String>['k1', 'k2']) ComponentInstance(
          id: ComponentId(id), modelType: 'contactor_3p',
          terminals: <Terminal>[for (int i = 0; i < 8; i++) Terminal(id: TerminalId('$id-$i'), name: 'T$i')],
          parameters: const <String, Object?>{'coilResistanceOhm': 1000.0, 'coilPickupVoltageV': 180.0, 'coilDropoutVoltageV': 100.0}),
        ComponentInstance(id: ComponentId('lock'), modelType: 'mechanical_interlock_ac3', terminals: const <Terminal>[],
          parameters: const <String, Object?>{'contactorAId': 'k1', 'contactorBId': 'k2'}),
      ],
    );
    final ElectricalProject project = ElectricalProject(
      networks: <ElectricalNetwork>[
        ElectricalNetwork(id: 'control', circuit: _plcCircuit()),
        ElectricalNetwork(id: 'power', circuit: power),
      ],
      actuatorLinks: <CrossNetworkActuatorLink>[
        for (final String id in <String>['k1', 'k2']) CrossNetworkActuatorLink(
          id: 'cmd-$id', plcNetworkId: 'control', plcComponentId: 'plc',
          outputAddress: id == 'k1' ? 'Q0' : 'Q1', targetNetworkId: 'power', contactorId: id),
      ],
    );
    final ElectricalProjectRuntimeSnapshot result = const ElectricalProjectRuntimeEngine()
        .advance(project, elapsed: const Duration(milliseconds: 20));
    expect(result.networks['power']!.contactorActuated(ComponentId('k1')), isFalse);
    expect(result.networks['power']!.contactorActuated(ComponentId('k2')), isFalse);
    expect(result.networks['power']!.controlIssues.any((issue) => issue.code == ElectromechanicalControlIssueCode.mechanicalInterlockConflict), isTrue);
  });

  test('PV inverter boundary supplies a separately solved AC1 load', () {
    final ElectricalProject project = ElectricalProject(
      networks: <ElectricalNetwork>[
        ElectricalNetwork(id: 'solar', circuit: _pvInverterCircuit()),
        ElectricalNetwork(id: 'ac', circuit: _acLoadCircuit()),
      ],
      converterLinks: <CrossNetworkConverterLink>[
        CrossNetworkConverterLink(id: 'solar-ac', inputNetworkId: 'solar', converterComponentId: 'inv',
          outputNetworkId: 'ac', outputLineTerminalId: 'load-line', outputNeutralTerminalId: 'load-neutral'),
      ],
    );
    final ElectricalProjectRuntimeSnapshot result = const ElectricalProjectRuntimeEngine()
        .advance(project, elapsed: const Duration(milliseconds: 20));
    expect(result.networks['solar']!.pvResult?.isSolved, isTrue);
    expect(result.networks['ac']!.ac1Result?.isSolved, isTrue);
    expect(result.networks['solar']!.pvResult!.inverterOutputPowerW, greaterThan(0));
    final double loadPower = result.networks['ac']!.ac1Result!.branchResults
        .where((Ac1BranchResult branch) => branch.modelType == 'resistor')
        .fold<double>(0.0, (double sum, Ac1BranchResult branch) => sum + (branch.activePowerW ?? 0.0));
    expect(loadPower, greaterThan(0));
    expect(result.networks['solar']!.pvResult!.inverterOutputPowerW, closeTo(loadPower, 1.0),
        reason: 'The equivalent load from the AC network is reflected into the PV inverter solve.');
    expect(result.diagnostics.where((String d) => d.contains('non convergé')), isEmpty);
  });
}
