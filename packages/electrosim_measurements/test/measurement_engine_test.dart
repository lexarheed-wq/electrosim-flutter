import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:electrosim_measurements/electrosim_measurements.dart';
import 'package:electrosim_solver_dc/electrosim_solver_dc.dart';
import 'package:electrosim_topology/electrosim_topology.dart';
import 'package:test/test.dart';

void main() {
  const TopologyEngine topologyEngine = TopologyEngine();
  const SolverDC solver = SolverDC();
  const MeasurementEngine measurementEngine = MeasurementEngine();
  const DeviceStateEngine deviceStateEngine = DeviceStateEngine();

  DcSolveResult solve(CircuitState circuit) =>
      solver.solve(circuit, topologyEngine.compile(circuit));

  group('MeasurementEngine', () {
    test('DC voltage is read from solved node potentials', () {
      final CircuitState circuit = _singleResistor();
      final TopologyGraph topology = topologyEngine.compile(circuit);
      final DcSolveResult simulation = solver.solve(circuit, topology);
      final MeasurementResult result = measurementEngine.measure(
        request: MeasurementRequest.voltage(
          positiveProbe: TerminalId('r1a'),
          negativeProbe: TerminalId('r1b'),
        ),
        circuit: circuit,
        topology: topology,
        simulation: simulation,
      );
      expect(result.isValid, isTrue);
      expect(result.reading!.unit, ElectricalUnit.volt);
      expect(result.reading!.value, closeTo(24.0, 1e-9));
      expect(result.evidenceIds, hasLength(2));
    });

    test('DC current is read from the solved branch result', () {
      final CircuitState circuit = _singleResistor();
      final TopologyGraph topology = topologyEngine.compile(circuit);
      final MeasurementResult result = measurementEngine.measure(
        request: MeasurementRequest.current(branchId: 'component:r1'),
        circuit: circuit,
        topology: topology,
        simulation: solver.solve(circuit, topology),
      );
      expect(result.reading!.unit, ElectricalUnit.ampere);
      expect(result.reading!.value, closeTo(2.0, 1e-9));
    });

    test('resistance is permitted for a de-energized normal resistor', () {
      final CircuitState circuit = _isolatedResistor();
      final TopologyGraph topology = topologyEngine.compile(circuit);
      final MeasurementResult result = measurementEngine.measure(
        request: MeasurementRequest.resistance(componentId: ComponentId('r1')),
        circuit: circuit,
        topology: topology,
        simulation: solver.solve(circuit, topology),
      );
      expect(result.isValid, isTrue);
      expect(result.reading!.unit, ElectricalUnit.ohm);
      expect(result.reading!.value, 12.0);
    });

    test('resistance with an enabled source is explicitly rejected', () {
      final CircuitState circuit = _singleResistor();
      final TopologyGraph topology = topologyEngine.compile(circuit);
      final MeasurementResult result = measurementEngine.measure(
        request: MeasurementRequest.resistance(componentId: ComponentId('r1')),
        circuit: circuit,
        topology: topology,
        simulation: solver.solve(circuit, topology),
      );
      expect(result.status, MeasurementStatus.invalid);
      expect(
        result.errorCode,
        MeasurementErrorCode.energizedResistanceMeasurement,
      );
    });

    test('unknown voltage probe and current branch are explicit failures', () {
      final CircuitState circuit = _singleResistor();
      final TopologyGraph topology = topologyEngine.compile(circuit);
      final DcSolveResult simulation = solver.solve(circuit, topology);
      final MeasurementResult badVoltage = measurementEngine.measure(
        request: MeasurementRequest.voltage(
          positiveProbe: TerminalId('missing'),
          negativeProbe: TerminalId('r1b'),
        ),
        circuit: circuit,
        topology: topology,
        simulation: simulation,
      );
      final MeasurementResult badCurrent = measurementEngine.measure(
        request: MeasurementRequest.current(branchId: 'component:missing'),
        circuit: circuit,
        topology: topology,
        simulation: simulation,
      );
      expect(badVoltage.errorCode, MeasurementErrorCode.unknownTerminal);
      expect(badCurrent.errorCode, MeasurementErrorCode.unknownBranch);
    });

    test(
      'missing solved node voltage is an explicit invalid voltage measurement',
      () {
        final CircuitState circuit = _singleResistor();
        final TopologyGraph topology = topologyEngine.compile(circuit);
        final DcSolveResult fakeSolved = DcSolveResult(
          circuitId: circuit.circuitId,
          circuitRevision: circuit.revision,
          engineVersion: SolverDC.engineVersion,
          status: DcSolveStatus.solved,
          referenceNodeId: null,
          nodeVoltages: const <String, double>{},
          branchResults: const <DcBranchResult>[],
          diagnostics: const <DcSolverDiagnostic>[],
          maxMatrixResidual: 0.0,
          kclResiduals: const <String, double>{},
          kvlResiduals: const <String, double>{},
        );
        final MeasurementResult result = measurementEngine.measure(
          request: MeasurementRequest.voltage(
            positiveProbe: TerminalId('r1a'),
            negativeProbe: TerminalId('r1b'),
          ),
          circuit: circuit,
          topology: topology,
          simulation: fakeSolved,
        );
        expect(result.errorCode, MeasurementErrorCode.unknownTerminal);
      },
    );

    test('indeterminate ideal-source branch current is not fabricated', () {
      final CircuitState circuit = _redundantZeroVoltSource();
      final TopologyGraph topology = topologyEngine.compile(circuit);
      final DcSolveResult simulation = solver.solve(circuit, topology);
      expect(simulation.isSolved, isTrue);
      final MeasurementResult result = measurementEngine.measure(
        request: MeasurementRequest.current(branchId: 'source:z'),
        circuit: circuit,
        topology: topology,
        simulation: simulation,
      );
      expect(result.status, MeasurementStatus.invalid);
      expect(result.errorCode, MeasurementErrorCode.branchCurrentUnavailable);
    });

    test('unsolved result, wrong mode and revision mismatch are rejected', () {
      final CircuitState invalidCircuit = _shortedSource();
      final TopologyGraph invalidTopology = topologyEngine.compile(
        invalidCircuit,
      );
      final DcSolveResult invalidSimulation = solver.solve(
        invalidCircuit,
        invalidTopology,
      );
      final MeasurementResult unsolved = measurementEngine.measure(
        request: MeasurementRequest.current(branchId: 'source:v1'),
        circuit: invalidCircuit,
        topology: invalidTopology,
        simulation: invalidSimulation,
      );
      expect(unsolved.errorCode, MeasurementErrorCode.simulationNotSolved);

      final CircuitState dc = _singleResistor();
      final TopologyGraph topology = topologyEngine.compile(dc);
      final DcSolveResult simulation = solver.solve(dc, topology);
      final CircuitState ac = CircuitState(
        circuitId: dc.circuitId,
        revision: dc.revision,
        mode: ElectricalMode.ac1,
      );
      final MeasurementResult wrongMode = measurementEngine.measure(
        request: MeasurementRequest.current(branchId: 'component:r1'),
        circuit: ac,
        topology: topology,
        simulation: simulation,
      );
      expect(wrongMode.errorCode, MeasurementErrorCode.wrongElectricalMode);

      final CircuitState revised = CircuitState(
        circuitId: dc.circuitId,
        revision: 1,
        mode: ElectricalMode.dc,
      );
      final MeasurementResult mismatch = measurementEngine.measure(
        request: MeasurementRequest.current(branchId: 'component:r1'),
        circuit: revised,
        topology: topology,
        simulation: simulation,
      );
      expect(mismatch.errorCode, MeasurementErrorCode.identityMismatch);
    });

    test('unsupported and malformed resistance targets fail explicitly', () {
      final CircuitState switchCircuit = _isolatedSwitch(closed: false);
      final TopologyGraph switchTopology = topologyEngine.compile(
        switchCircuit,
      );
      final MeasurementResult unsupported = measurementEngine.measure(
        request: MeasurementRequest.resistance(componentId: ComponentId('s1')),
        circuit: switchCircuit,
        topology: switchTopology,
        simulation: solver.solve(switchCircuit, switchTopology),
      );
      expect(
        unsupported.errorCode,
        MeasurementErrorCode.unsupportedResistanceTarget,
      );

      final CircuitState resistor = _isolatedResistor(resistance: -1.0);
      final TopologyGraph resistorTopology = topologyEngine.compile(resistor);
      final DcSolveResult fakeSolved = DcSolveResult(
        circuitId: resistor.circuitId,
        circuitRevision: resistor.revision,
        engineVersion: SolverDC.engineVersion,
        status: DcSolveStatus.solved,
        referenceNodeId: null,
        nodeVoltages: const <String, double>{},
        branchResults: const <DcBranchResult>[],
        diagnostics: const <DcSolverDiagnostic>[],
        maxMatrixResidual: 0.0,
        kclResiduals: const <String, double>{},
        kvlResiduals: const <String, double>{},
      );
      final MeasurementResult malformed = measurementEngine.measure(
        request: MeasurementRequest.resistance(componentId: ComponentId('r1')),
        circuit: resistor,
        topology: resistorTopology,
        simulation: fakeSolved,
      );
      expect(
        malformed.errorCode,
        MeasurementErrorCode.invalidResistanceParameter,
      );

      final MeasurementResult missing = measurementEngine.measure(
        request: MeasurementRequest.resistance(
          componentId: ComponentId('missing'),
        ),
        circuit: _isolatedResistor(),
        topology: topologyEngine.compile(_isolatedResistor()),
        simulation: solve(_isolatedResistor()),
      );
      expect(missing.errorCode, MeasurementErrorCode.unknownComponent);
    });
  });

  group('DeviceStateEngine', () {
    test('normal solved resistor state is energized from solver evidence', () {
      final CircuitState circuit = _singleResistor();
      final ComponentOperatingState state = deviceStateEngine.evaluate(
        component: circuit.components.single,
        circuit: circuit,
        simulation: solve(circuit),
      );
      expect(state.code, ComponentOperatingCode.energized);
      expect(state.voltageV!.abs(), closeTo(24.0, 1e-9));
      expect(state.currentA!.abs(), closeTo(2.0, 1e-9));
      expect(state.evidenceIds, contains('branch:component:r1'));
    });

    test('max voltage/current/power limits produce overload warnings', () {
      final CircuitState circuit = _singleResistor(
        parameters: const <String, Object?>{
          'resistanceOhm': 12.0,
          'maxVoltageV': 10.0,
          'maxCurrentA': 1.0,
          'maxPowerW': 20.0,
        },
      );
      final ComponentOperatingState state = deviceStateEngine.evaluate(
        component: circuit.components.single,
        circuit: circuit,
        simulation: solve(circuit),
      );
      expect(state.code, ComponentOperatingCode.overloaded);
      final Set<OperatingWarningCode> codes = state.warnings
          .map<OperatingWarningCode>((OperatingWarning warning) => warning.code)
          .toSet();
      expect(
        codes,
        containsAll(<OperatingWarningCode>[
          OperatingWarningCode.overVoltage,
          OperatingWarningCode.overCurrent,
          OperatingWarningCode.overPower,
        ]),
      );
    });

    test('invalid nominal limit is a warning, not fabricated overload', () {
      final CircuitState circuit = _singleResistor(
        parameters: const <String, Object?>{
          'resistanceOhm': 12.0,
          'maxVoltageV': -1.0,
        },
      );
      final ComponentOperatingState state = deviceStateEngine.evaluate(
        component: circuit.components.single,
        circuit: circuit,
        simulation: solve(circuit),
      );
      expect(state.code, ComponentOperatingCode.energized);
      expect(
        state.warnings.map((OperatingWarning warning) => warning.code),
        contains(OperatingWarningCode.invalidNominalLimit),
      );
    });

    test(
      'switch state comes from controlState plus solved branch evidence',
      () {
        for (final bool closed in <bool>[false, true]) {
          final CircuitState circuit = _isolatedSwitch(closed: closed);
          final ComponentInstance switchComponent = circuit.components
              .firstWhere(
                (ComponentInstance component) =>
                    component.id == ComponentId('s1'),
              );
          final ComponentOperatingState state = deviceStateEngine.evaluate(
            component: switchComponent,
            circuit: circuit,
            simulation: solve(circuit),
          );
          expect(
            state.code,
            closed
                ? ComponentOperatingCode.closed
                : ComponentOperatingCode.open,
          );
        }
      },
    );

    test('disabled/faulted conditions and unsolved results stay explicit', () {
      final CircuitState disabled = _isolatedResistor(
        condition: ComponentCondition.disabled,
      );
      final CircuitState open = _isolatedResistor(
        condition: ComponentCondition.openCircuit,
      );
      expect(
        deviceStateEngine
            .evaluate(
              component: disabled.components.single,
              circuit: disabled,
              simulation: solve(disabled),
            )
            .code,
        ComponentOperatingCode.disabled,
      );
      expect(
        deviceStateEngine
            .evaluate(
              component: open.components.single,
              circuit: open,
              simulation: solve(open),
            )
            .code,
        ComponentOperatingCode.faulted,
      );

      final CircuitState invalid = _shortedSource();
      final ComponentInstance component = _singleResistor().components.single;
      final ComponentOperatingState unknown = deviceStateEngine.evaluate(
        component: component,
        circuit: _singleResistor(),
        simulation: solve(invalid),
      );
      expect(unknown.code, ComponentOperatingCode.undetermined);
      expect(
        unknown.warnings.single.code,
        OperatingWarningCode.simulationNotSolved,
      );
    });

    test(
      'de-energized, missing-branch and indeterminate-current states remain explicit',
      () {
        final CircuitState circuit = _isolatedResistor();
        final DcSolveResult solved = solve(circuit);
        final ComponentOperatingState deenergized = deviceStateEngine.evaluate(
          component: circuit.components.single,
          circuit: circuit,
          simulation: solved,
        );
        expect(deenergized.code, ComponentOperatingCode.deenergized);

        final DcSolveResult missingBranch = DcSolveResult(
          circuitId: circuit.circuitId,
          circuitRevision: circuit.revision,
          engineVersion: SolverDC.engineVersion,
          status: DcSolveStatus.solved,
          referenceNodeId: solved.referenceNodeId,
          nodeVoltages: solved.nodeVoltages,
          branchResults: const <DcBranchResult>[],
          diagnostics: const <DcSolverDiagnostic>[],
          maxMatrixResidual: 0.0,
          kclResiduals: const <String, double>{},
          kvlResiduals: const <String, double>{},
        );
        final ComponentOperatingState missing = deviceStateEngine.evaluate(
          component: circuit.components.single,
          circuit: circuit,
          simulation: missingBranch,
        );
        expect(missing.code, ComponentOperatingCode.undetermined);
        expect(
          missing.warnings.single.code,
          OperatingWarningCode.missingBranchResult,
        );

        final DcSolveResult indeterminate = DcSolveResult(
          circuitId: circuit.circuitId,
          circuitRevision: circuit.revision,
          engineVersion: SolverDC.engineVersion,
          status: DcSolveStatus.solved,
          referenceNodeId: solved.referenceNodeId,
          nodeVoltages: solved.nodeVoltages,
          branchResults: <DcBranchResult>[
            DcBranchResult(
              id: 'component:r1',
              modelType: 'resistor',
              kind: DcBranchKind.resistor,
              fromNodeId: 'n0',
              toNodeId: 'n1',
              voltageV: 0.0,
              currentA: null,
              powerW: null,
            ),
          ],
          diagnostics: const <DcSolverDiagnostic>[],
          maxMatrixResidual: 0.0,
          kclResiduals: const <String, double>{},
          kvlResiduals: const <String, double>{},
        );
        final ComponentOperatingState unknownCurrent = deviceStateEngine
            .evaluate(
              component: circuit.components.single,
              circuit: circuit,
              simulation: indeterminate,
            );
        expect(unknownCurrent.code, ComponentOperatingCode.deenergized);
        expect(
          unknownCurrent.warnings.map(
            (OperatingWarning warning) => warning.code,
          ),
          contains(OperatingWarningCode.currentIndeterminate),
        );
      },
    );

    test('evaluateAll and public collections are immutable', () {
      final CircuitState circuit = _singleResistor();
      final List<ComponentOperatingState> states = deviceStateEngine
          .evaluateAll(circuit: circuit, simulation: solve(circuit));
      expect(states, hasLength(1));
      expect(() => states.add(states.single), throwsUnsupportedError);
      expect(() => states.single.evidenceIds.add('x'), throwsUnsupportedError);
    });
  });
}

Terminal _terminal(
  String id,
  String name, {
  TerminalRole role = TerminalRole.generic,
  PhaseTag phase = PhaseTag.none,
}) => Terminal(id: TerminalId(id), name: name, role: role, phase: phase);

SourceInstance _voltageSource(double voltage) => SourceInstance(
  id: SourceId('v1'),
  modelType: 'dc_voltage_source',
  terminals: <Terminal>[
    _terminal(
      'vp',
      '+',
      role: TerminalRole.positive,
      phase: PhaseTag.dcPositive,
    ),
    _terminal(
      'vn',
      '-',
      role: TerminalRole.negative,
      phase: PhaseTag.dcNegative,
    ),
  ],
  parameters: <String, Object?>{'voltageV': voltage},
);

CircuitState _singleResistor({Map<String, Object?>? parameters}) =>
    CircuitState(
      circuitId: CircuitId('dc-f4'),
      revision: 0,
      mode: ElectricalMode.dc,
      components: <ComponentInstance>[
        ComponentInstance(
          id: ComponentId('r1'),
          modelType: 'resistor',
          terminals: <Terminal>[_terminal('r1a', 'A'), _terminal('r1b', 'B')],
          parameters:
              parameters ?? const <String, Object?>{'resistanceOhm': 12.0},
        ),
      ],
      connections: <Connection>[
        Connection(
          id: ConnectionId('w1'),
          fromTerminalId: TerminalId('vp'),
          toTerminalId: TerminalId('r1a'),
        ),
        Connection(
          id: ConnectionId('w2'),
          fromTerminalId: TerminalId('r1b'),
          toTerminalId: TerminalId('vn'),
        ),
      ],
      sources: <SourceInstance>[_voltageSource(24.0)],
    );

CircuitState _isolatedResistor({
  double resistance = 12.0,
  ComponentCondition condition = ComponentCondition.normal,
}) => CircuitState(
  circuitId: CircuitId('resistance-f4'),
  revision: 0,
  mode: ElectricalMode.dc,
  components: <ComponentInstance>[
    ComponentInstance(
      id: ComponentId('r1'),
      modelType: 'resistor',
      terminals: <Terminal>[_terminal('r1a', 'A'), _terminal('r1b', 'B')],
      parameters: <String, Object?>{'resistanceOhm': resistance},
      condition: condition,
    ),
  ],
);

CircuitState _isolatedSwitch({required bool closed}) => CircuitState(
  circuitId: CircuitId('switch-$closed'),
  revision: 0,
  mode: ElectricalMode.dc,
  components: <ComponentInstance>[
    ComponentInstance(
      id: ComponentId('s1'),
      modelType: 'switch',
      terminals: <Terminal>[_terminal('s1a', 'A'), _terminal('s1b', 'B')],
      controlState: <String, Object?>{'closed': closed},
    ),
    ComponentInstance(
      id: ComponentId('rload'),
      modelType: 'resistor',
      terminals: <Terminal>[_terminal('rla', 'A'), _terminal('rlb', 'B')],
      parameters: const <String, Object?>{'resistanceOhm': 100.0},
    ),
  ],
  connections: <Connection>[
    Connection(
      id: ConnectionId('sw-a'),
      fromTerminalId: TerminalId('s1a'),
      toTerminalId: TerminalId('rla'),
    ),
    Connection(
      id: ConnectionId('sw-b'),
      fromTerminalId: TerminalId('s1b'),
      toTerminalId: TerminalId('rlb'),
    ),
  ],
);

CircuitState _redundantZeroVoltSource() => CircuitState(
  circuitId: CircuitId('redundant-zero-f4'),
  revision: 0,
  mode: ElectricalMode.dc,
  connections: <Connection>[
    Connection(
      id: ConnectionId('short'),
      fromTerminalId: TerminalId('z1'),
      toTerminalId: TerminalId('z2'),
    ),
  ],
  sources: <SourceInstance>[
    SourceInstance(
      id: SourceId('z'),
      modelType: 'dc_voltage_source',
      terminals: <Terminal>[_terminal('z1', 'A'), _terminal('z2', 'B')],
      parameters: const <String, Object?>{'voltageV': 0.0},
    ),
  ],
);

CircuitState _shortedSource() => CircuitState(
  circuitId: CircuitId('shorted-source-f4'),
  revision: 0,
  mode: ElectricalMode.dc,
  connections: <Connection>[
    Connection(
      id: ConnectionId('short'),
      fromTerminalId: TerminalId('vp'),
      toTerminalId: TerminalId('vn'),
    ),
  ],
  sources: <SourceInstance>[_voltageSource(24.0)],
);
