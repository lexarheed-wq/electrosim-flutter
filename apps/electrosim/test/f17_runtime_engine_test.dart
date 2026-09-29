import 'package:electrosim/runtime/electrosim_runtime_engine.dart';
import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:electrosim_energy/electrosim_energy.dart';
import 'package:electrosim_measurements/electrosim_measurements.dart';
import 'package:electrosim_pv/electrosim_pv.dart';
import 'package:electrosim_solver_ac/electrosim_solver_ac.dart';
import 'package:electrosim_solver_dc/electrosim_solver_dc.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('F17 runtime evaluates a canonical healthy DC circuit end to end', () {
    final Terminal sourcePositive = Terminal(
      id: TerminalId('vp'),
      name: '+',
      role: TerminalRole.positive,
      phase: PhaseTag.dcPositive,
    );
    final Terminal sourceNegative = Terminal(
      id: TerminalId('vn'),
      name: '-',
      role: TerminalRole.negative,
      phase: PhaseTag.dcNegative,
    );
    final Terminal resistorA = Terminal(
      id: TerminalId('r1a'),
      name: 'A',
      role: TerminalRole.input,
    );
    final Terminal resistorB = Terminal(
      id: TerminalId('r1b'),
      name: 'B',
      role: TerminalRole.output,
    );

    final CircuitState circuit = CircuitState(
      circuitId: CircuitId('f17-runtime-smoke'),
      revision: 1,
      mode: ElectricalMode.dc,
      sources: <SourceInstance>[
        SourceInstance(
          id: SourceId('source-1'),
          modelType: 'dc_voltage_source',
          terminals: <Terminal>[sourcePositive, sourceNegative],
          parameters: const <String, Object?>{'voltageV': 24.0},
        ),
      ],
      components: <ComponentInstance>[
        ComponentInstance(
          id: ComponentId('r1'),
          modelType: 'resistor',
          terminals: <Terminal>[resistorA, resistorB],
          parameters: const <String, Object?>{'resistanceOhm': 24.0},
        ),
      ],
      connections: <Connection>[
        Connection(
          id: ConnectionId('w1'),
          fromTerminalId: sourcePositive.id,
          toTerminalId: resistorA.id,
        ),
        Connection(
          id: ConnectionId('w2'),
          fromTerminalId: resistorB.id,
          toTerminalId: sourceNegative.id,
        ),
      ],
    );

    final ElectroSimRuntimeSnapshot snapshot =
        const ElectroSimRuntimeEngine().evaluate(circuit);

    expect(snapshot.dc.status, DcSolveStatus.solved);
    expect(snapshot.dc.branch('component:r1').currentA, closeTo(1.0, 1e-9));
    expect(snapshot.topology.circuitRevision, 1);
    expect(snapshot.diagnostics.circuitRevision, 1);
  });

  test('F17 runtime preserves circuit identity through topology, solver and EIE', () {
    final Terminal p = Terminal(
      id: TerminalId('p'),
      name: '+',
      role: TerminalRole.positive,
      phase: PhaseTag.dcPositive,
    );
    final Terminal n = Terminal(
      id: TerminalId('n'),
      name: '-',
      role: TerminalRole.negative,
      phase: PhaseTag.dcNegative,
    );

    final CircuitState circuit = CircuitState(
      circuitId: CircuitId('f17-identity'),
      revision: 7,
      mode: ElectricalMode.dc,
      sources: <SourceInstance>[
        SourceInstance(
          id: SourceId('source'),
          modelType: 'dc_voltage_source',
          terminals: <Terminal>[p, n],
          parameters: const <String, Object?>{'voltageV': 12.0},
        ),
      ],
    );

    final ElectroSimRuntimeSnapshot snapshot =
        const ElectroSimRuntimeEngine().evaluate(circuit);

    expect(snapshot.topology.circuitId, circuit.circuitId);
    expect(snapshot.topology.circuitRevision, circuit.revision);
    expect(snapshot.dc.circuitId, circuit.circuitId);
    expect(snapshot.dc.circuitRevision, circuit.revision);
    expect(snapshot.diagnostics.circuitId, circuit.circuitId);
    expect(snapshot.diagnostics.circuitRevision, circuit.revision);
  });
  test('F17-R9 runtime routes AC1 to SolverAC1 without fabricating DC measurements', () {
    final CircuitState circuit = _ac1Circuit();
    final ElectroSimRuntimeSnapshot snapshot =
        const ElectroSimRuntimeEngine().evaluate(circuit);

    expect(snapshot.solverKind, ElectroSimRuntimeSolverKind.ac1);
    expect(snapshot.solved, isTrue);
    expect(snapshot.ac1.status, Ac1SolveStatus.solved);
    expect(
      snapshot.ac1.branch('component:load').current!.magnitude,
      closeTo(5.0, 1e-9),
    );
    expect(snapshot.dcResult, isNull);
    expect(snapshot.diagnosticsAvailable, isFalse);

    final MeasurementResult measurement = snapshot.measureVoltage(
      positiveProbe: TerminalId('ac1-load-a'),
      negativeProbe: TerminalId('ac1-load-b'),
    );
    expect(measurement.isValid, isFalse);
    expect(measurement.errorCode, MeasurementErrorCode.wrongElectricalMode);
  });

  test('F17-R9 runtime routes balanced AC3 to SolverAC3', () {
    final CircuitState circuit = _ac3Circuit();
    final ElectroSimRuntimeSnapshot snapshot =
        const ElectroSimRuntimeEngine().evaluate(circuit);

    expect(snapshot.solverKind, ElectroSimRuntimeSolverKind.ac3);
    expect(snapshot.solved, isTrue);
    expect(snapshot.ac3.status, Ac3SolveStatus.solved);
    expect(snapshot.ac3.sourceSequence, Ac3PhaseSequence.positive);
    expect(snapshot.ac3.voltageBalanced, isTrue);
    expect(snapshot.ac3.currentBalanced, isTrue);
    expect(
      snapshot.ac3.lineCurrent(PhaseTag.l1).magnitude,
      closeTo(10.0, 1e-8),
    );
    expect(snapshot.diagnosticsAvailable, isFalse);
  });

  test('F17-R10 runtime routes PV through SolverPV and exposes balanced power sample', () {
    final CircuitState circuit = _pvCircuit(loadPowerAt230W: 2000.0);
    final ElectroSimRuntimeSnapshot snapshot =
        const ElectroSimRuntimeEngine().evaluate(circuit);

    expect(snapshot.solverKind, ElectroSimRuntimeSolverKind.pv);
    expect(snapshot.solved, isTrue);
    expect(snapshot.pv.status, PvSolveStatus.solved);
    expect(snapshot.pv.inverterState, PvInverterState.running);
    expect(snapshot.pv.inverterOutputPowerW, closeTo(2000.0, 1e-7));
    expect(snapshot.energyAvailable, isTrue);
    expect(snapshot.energyPowerSample, isNotNull);
    expect(
      snapshot.energyPowerSample!.inputPowerW,
      closeTo(2000.0 / 0.95, 1e-7),
    );
    expect(snapshot.energyPowerSample!.outputPowerW, closeTo(2000.0, 1e-7));
    expect(
      snapshot.energyPowerSample!.inputPowerW,
      closeTo(
        snapshot.energyPowerSample!.outputPowerW +
            snapshot.energyPowerSample!.lossPowerW,
        1e-8,
      ),
    );
    expect(snapshot.diagnosticsAvailable, isFalse);
  });

  test('F17-R10 energy advances only for explicit elapsed simulation time', () {
    const ElectroSimRuntimeEngine runtime = ElectroSimRuntimeEngine();
    final ElectroSimRuntimeSnapshot snapshot =
        runtime.evaluate(_pvCircuit(loadPowerAt230W: 2000.0));
    final EnergySnapshot zero = runtime.zeroEnergy(snapshot);

    expect(zero.outputEnergyWh, 0.0);
    expect(zero.elapsedSeconds, 0.0);

    final EnergySnapshot afterThirtyMinutes = runtime.advanceEnergy(
      snapshot: snapshot,
      previous: zero,
      elapsed: const Duration(minutes: 30),
    );
    expect(afterThirtyMinutes.elapsedSeconds, 1800.0);
    expect(afterThirtyMinutes.outputEnergyWh, closeTo(1000.0, 1e-8));

    final EnergySnapshot afterOneHour = runtime.advanceEnergy(
      snapshot: snapshot,
      previous: afterThirtyMinutes,
      elapsed: const Duration(minutes: 30),
    );
    expect(afterOneHour.elapsedSeconds, 3600.0);
    expect(afterOneHour.outputEnergyWh, closeTo(2000.0, 1e-8));
    expect(
      afterOneHour.inputEnergyWh,
      closeTo((2000.0 / 0.95), 1e-7),
    );
  });

  test('F17-R10 unsolved PV never produces an energy sample', () {
    final ElectroSimRuntimeSnapshot snapshot =
        const ElectroSimRuntimeEngine().evaluate(
      _pvCircuit(disconnectDcPositive: true),
    );

    expect(snapshot.solverKind, ElectroSimRuntimeSolverKind.pv);
    expect(snapshot.solved, isFalse);
    expect(snapshot.pv.status, PvSolveStatus.invalid);
    expect(snapshot.energyPowerSample, isNull);
    expect(snapshot.energyAvailable, isFalse);
    expect(
      () => const ElectroSimRuntimeEngine().zeroEnergy(snapshot),
      throwsStateError,
    );
  });

}

Terminal _acTerminal(
  String id,
  String name, {
  PhaseTag phase = PhaseTag.none,
  TerminalRole role = TerminalRole.generic,
}) =>
    Terminal(id: TerminalId(id), name: name, phase: phase, role: role);

CircuitState _ac1Circuit() {
  final Terminal sourceLine = _acTerminal(
    'ac1-source-line',
    'L',
    phase: PhaseTag.l1,
    role: TerminalRole.line,
  );
  final Terminal sourceNeutral = _acTerminal(
    'ac1-source-neutral',
    'N',
    phase: PhaseTag.neutral,
    role: TerminalRole.neutral,
  );
  final Terminal loadA = _acTerminal(
    'ac1-load-a',
    'A',
    phase: PhaseTag.l1,
    role: TerminalRole.input,
  );
  final Terminal loadB = _acTerminal(
    'ac1-load-b',
    'B',
    phase: PhaseTag.neutral,
    role: TerminalRole.output,
  );
  return CircuitState(
    circuitId: CircuitId('f17-r9-ac1'),
    revision: 9,
    mode: ElectricalMode.ac1,
    sources: <SourceInstance>[
      SourceInstance(
        id: SourceId('ac1-source'),
        modelType: 'ac_voltage_source',
        terminals: <Terminal>[sourceLine, sourceNeutral],
        parameters: const <String, Object?>{
          'voltageRmsV': 230.0,
          'phaseDeg': 0.0,
        },
      ),
    ],
    components: <ComponentInstance>[
      ComponentInstance(
        id: ComponentId('load'),
        modelType: 'resistor',
        terminals: <Terminal>[loadA, loadB],
        parameters: const <String, Object?>{'resistanceOhm': 46.0},
      ),
    ],
    connections: <Connection>[
      Connection(
        id: ConnectionId('ac1-line'),
        fromTerminalId: sourceLine.id,
        toTerminalId: loadA.id,
        phase: PhaseTag.l1,
      ),
      Connection(
        id: ConnectionId('ac1-neutral'),
        fromTerminalId: loadB.id,
        toTerminalId: sourceNeutral.id,
        phase: PhaseTag.neutral,
      ),
    ],
    settings: const <String, Object?>{'frequencyHz': 50.0},
  );
}

CircuitState _ac3Circuit() {
  const List<PhaseTag> phases = <PhaseTag>[
    PhaseTag.l1,
    PhaseTag.l2,
    PhaseTag.l3,
  ];
  const List<double> phaseAngles = <double>[0.0, -120.0, 120.0];
  final List<SourceInstance> sources = <SourceInstance>[];
  final List<ComponentInstance> loads = <ComponentInstance>[];
  final List<Connection> connections = <Connection>[];

  for (var index = 0; index < phases.length; index++) {
    final int number = index + 1;
    final PhaseTag phase = phases[index];
    final TerminalRole phaseRole = switch (phase) {
      PhaseTag.l1 => TerminalRole.phaseL1,
      PhaseTag.l2 => TerminalRole.phaseL2,
      PhaseTag.l3 => TerminalRole.phaseL3,
      _ => TerminalRole.line,
    };
    final Terminal sourcePhase = _acTerminal(
      'ac3-s${number}p',
      phase.name.toUpperCase(),
      phase: phase,
      role: phaseRole,
    );
    final Terminal sourceNeutral = _acTerminal(
      'ac3-s${number}n',
      'N',
      phase: PhaseTag.neutral,
      role: TerminalRole.neutral,
    );
    final Terminal loadPhase = _acTerminal(
      'ac3-r${number}p',
      phase.name.toUpperCase(),
      phase: phase,
      role: phaseRole,
    );
    final Terminal loadNeutral = _acTerminal(
      'ac3-r${number}n',
      'N',
      phase: PhaseTag.neutral,
      role: TerminalRole.neutral,
    );
    sources.add(
      SourceInstance(
        id: SourceId('ac3-s$number'),
        modelType: 'ac_voltage_source',
        terminals: <Terminal>[sourcePhase, sourceNeutral],
        parameters: <String, Object?>{
          'voltageRmsV': 230.0,
          'phaseDeg': phaseAngles[index],
        },
      ),
    );
    loads.add(
      ComponentInstance(
        id: ComponentId('r$number'),
        modelType: 'resistor',
        terminals: <Terminal>[loadPhase, loadNeutral],
        parameters: const <String, Object?>{'resistanceOhm': 23.0},
      ),
    );
    connections.add(
      Connection(
        id: ConnectionId('ac3-phase-$number'),
        fromTerminalId: sourcePhase.id,
        toTerminalId: loadPhase.id,
        phase: phase,
      ),
    );
  }

  connections.addAll(<Connection>[
    Connection(
      id: ConnectionId('ac3-source-neutral-12'),
      fromTerminalId: TerminalId('ac3-s1n'),
      toTerminalId: TerminalId('ac3-s2n'),
      phase: PhaseTag.neutral,
    ),
    Connection(
      id: ConnectionId('ac3-source-neutral-23'),
      fromTerminalId: TerminalId('ac3-s2n'),
      toTerminalId: TerminalId('ac3-s3n'),
      phase: PhaseTag.neutral,
    ),
    Connection(
      id: ConnectionId('ac3-load-neutral-12'),
      fromTerminalId: TerminalId('ac3-r1n'),
      toTerminalId: TerminalId('ac3-r2n'),
      phase: PhaseTag.neutral,
    ),
    Connection(
      id: ConnectionId('ac3-load-neutral-23'),
      fromTerminalId: TerminalId('ac3-r2n'),
      toTerminalId: TerminalId('ac3-r3n'),
      phase: PhaseTag.neutral,
    ),
    Connection(
      id: ConnectionId('ac3-neutral-link'),
      fromTerminalId: TerminalId('ac3-s1n'),
      toTerminalId: TerminalId('ac3-r1n'),
      phase: PhaseTag.neutral,
    ),
  ]);

  return CircuitState(
    circuitId: CircuitId('f17-r9-ac3'),
    revision: 9,
    mode: ElectricalMode.ac3,
    sources: sources,
    components: loads,
    connections: connections,
    settings: const <String, Object?>{'frequencyHz': 50.0},
  );
}

CircuitState _pvCircuit({
  double loadPowerAt230W = 1000.0,
  bool disconnectDcPositive = false,
}) {
  final double resistance = 230.0 * 230.0 / loadPowerAt230W;
  final ComponentInstance inverter = ComponentInstance(
    id: ComponentId('pv-inverter'),
    modelType: 'pv_inverter',
    terminals: <Terminal>[
      _acTerminal(
        'pv-inv-dc-pos',
        'DC+',
        phase: PhaseTag.dcPositive,
        role: TerminalRole.positive,
      ),
      _acTerminal(
        'pv-inv-dc-neg',
        'DC-',
        phase: PhaseTag.dcNegative,
        role: TerminalRole.negative,
      ),
      _acTerminal(
        'pv-inv-l',
        'L',
        phase: PhaseTag.l1,
        role: TerminalRole.line,
      ),
      _acTerminal(
        'pv-inv-n',
        'N',
        phase: PhaseTag.neutral,
        role: TerminalRole.neutral,
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
    id: ComponentId('pv-load'),
    modelType: 'pv_resistive_load',
    terminals: <Terminal>[
      _acTerminal(
        'pv-load-l',
        'L',
        phase: PhaseTag.l1,
        role: TerminalRole.line,
      ),
      _acTerminal(
        'pv-load-n',
        'N',
        phase: PhaseTag.neutral,
        role: TerminalRole.neutral,
      ),
    ],
    parameters: <String, Object?>{'resistanceOhm': resistance},
  );
  return CircuitState(
    circuitId: CircuitId('f17-r10-pv'),
    revision: 10,
    mode: ElectricalMode.pv,
    sources: <SourceInstance>[
      SourceInstance(
        id: SourceId('pv-array'),
        modelType: 'pv_array',
        terminals: <Terminal>[
          _acTerminal(
            'pv-array-pos',
            '+',
            phase: PhaseTag.dcPositive,
            role: TerminalRole.positive,
          ),
          _acTerminal(
            'pv-array-neg',
            '-',
            phase: PhaseTag.dcNegative,
            role: TerminalRole.negative,
          ),
        ],
        parameters: const <String, Object?>{
          'mppVoltageV': 400.0,
          'mppCurrentA': 10.0,
          'powerTemperatureCoefficientPerC': 0.0,
          'voltageTemperatureCoefficientPerC': 0.0,
        },
      ),
    ],
    components: <ComponentInstance>[inverter, load],
    connections: <Connection>[
      if (!disconnectDcPositive)
        Connection(
          id: ConnectionId('pv-dc-pos'),
          fromTerminalId: TerminalId('pv-array-pos'),
          toTerminalId: TerminalId('pv-inv-dc-pos'),
          phase: PhaseTag.dcPositive,
        ),
      Connection(
        id: ConnectionId('pv-dc-neg'),
        fromTerminalId: TerminalId('pv-array-neg'),
        toTerminalId: TerminalId('pv-inv-dc-neg'),
        phase: PhaseTag.dcNegative,
      ),
      Connection(
        id: ConnectionId('pv-ac-line'),
        fromTerminalId: TerminalId('pv-inv-l'),
        toTerminalId: TerminalId('pv-load-l'),
        phase: PhaseTag.l1,
      ),
      Connection(
        id: ConnectionId('pv-ac-neutral'),
        fromTerminalId: TerminalId('pv-inv-n'),
        toTerminalId: TerminalId('pv-load-n'),
        phase: PhaseTag.neutral,
      ),
    ],
    settings: const <String, Object?>{
      'irradianceWm2': 1000.0,
      'cellTemperatureC': 25.0,
    },
  );
}
