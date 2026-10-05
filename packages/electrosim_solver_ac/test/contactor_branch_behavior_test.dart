import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:electrosim_solver_ac/electrosim_solver_ac.dart';
import 'package:electrosim_topology/electrosim_topology.dart';
import 'package:test/test.dart';

void main() {
  const TopologyEngine topologyEngine = TopologyEngine();

  group('Contactor AC1 branch behavior', () {
    test('coil remains electrical while power pole follows actuated state', () {
      final CircuitState released = _ac1ContactorCircuit(actuated: false);
      final Ac1SolveResult releasedResult = const SolverAC1().solve(
        released,
        topologyEngine.compile(released),
      );
      expect(releasedResult.isSolved, isTrue);
      expect(
        releasedResult.branch('component:k1:control:coil').current!.magnitude,
        closeTo(0.23, 1e-9),
      );
      expect(
        releasedResult.branch('component:k1:power:1').kind,
        Ac1BranchKind.contactorContact,
      );
      expect(
        releasedResult.branch('component:k1:power:1').current!.magnitude,
        closeTo(0.0, 1e-12),
      );
      expect(
        releasedResult.branch('component:r1').current!.magnitude,
        closeTo(0.0, 1e-12),
      );

      final CircuitState actuated = _ac1ContactorCircuit(actuated: true);
      final Ac1SolveResult actuatedResult = const SolverAC1().solve(
        actuated,
        topologyEngine.compile(actuated),
      );
      expect(actuatedResult.isSolved, isTrue);
      expect(
        actuatedResult.branch('component:r1').current!.magnitude,
        closeTo(5.0, 1e-9),
      );
    });

    test('auxiliary NO and NC contacts follow actuated state', () {
      final CircuitState noReleased = _ac1AuxCircuit(
        modelType: 'contactor_aux_no',
        actuated: false,
      );
      final Ac1SolveResult noReleasedResult = const SolverAC1().solve(
        noReleased,
        topologyEngine.compile(noReleased),
      );
      expect(
        noReleasedResult.branch('component:aux1').current!.magnitude,
        closeTo(0.0, 1e-12),
      );

      final CircuitState noActuated = _ac1AuxCircuit(
        modelType: 'contactor_aux_no',
        actuated: true,
      );
      final Ac1SolveResult noActuatedResult = const SolverAC1().solve(
        noActuated,
        topologyEngine.compile(noActuated),
      );
      expect(
        noActuatedResult.branch('component:r1').current!.magnitude,
        closeTo(5.0, 1e-9),
      );

      final CircuitState ncReleased = _ac1AuxCircuit(
        modelType: 'contactor_aux_nc',
        actuated: false,
      );
      final Ac1SolveResult ncReleasedResult = const SolverAC1().solve(
        ncReleased,
        topologyEngine.compile(ncReleased),
      );
      expect(
        ncReleasedResult.branch('component:r1').current!.magnitude,
        closeTo(5.0, 1e-9),
      );

      final CircuitState ncActuated = _ac1AuxCircuit(
        modelType: 'contactor_aux_nc',
        actuated: true,
      );
      final Ac1SolveResult ncActuatedResult = const SolverAC1().solve(
        ncActuated,
        topologyEngine.compile(ncActuated),
      );
      expect(
        ncActuatedResult.branch('component:r1').current!.magnitude,
        closeTo(0.0, 1e-12),
      );
    });
  });

  group('Contactor AC3 validation branches', () {
    test('invalid actuated state is rejected explicitly', () {
      final CircuitState base = _ac3ContactorCircuit(actuated: false);
      final ComponentInstance original = base.components.first;
      final ComponentInstance malformed = ComponentInstance(
        id: original.id,
        modelType: original.modelType,
        terminals: original.terminals,
        parameters: original.parameters,
        controlState: const <String, Object?>{'actuated': 'yes'},
        condition: original.condition,
      );
      final Ac3SolveResult result = const SolverAC3().solve(
        _replaceFirstComponent(base, malformed),
        topologyEngine.compile(_replaceFirstComponent(base, malformed)),
      );
      expect(result.status, Ac3SolveStatus.invalid);
      expect(
        result.diagnostics.map((Ac3SolverDiagnostic item) => item.code),
        contains(Ac3DiagnosticCode.invalidParameter),
      );
    });

    test('degraded contactor condition is rejected explicitly', () {
      final CircuitState base = _ac3ContactorCircuit(actuated: false);
      final ComponentInstance original = base.components.first;
      final ComponentInstance degraded = ComponentInstance(
        id: original.id,
        modelType: original.modelType,
        terminals: original.terminals,
        parameters: original.parameters,
        controlState: original.controlState,
        condition: ComponentCondition.degraded,
      );
      final CircuitState circuit = _replaceFirstComponent(base, degraded);
      final Ac3SolveResult result = const SolverAC3().solve(
        circuit,
        topologyEngine.compile(circuit),
      );
      expect(result.status, Ac3SolveStatus.invalid);
      expect(
        result.diagnostics.map((Ac3SolverDiagnostic item) => item.code),
        contains(Ac3DiagnosticCode.unsupportedComponentCondition),
      );
    });

    test('invalid coil parameters are rejected and open condition remains explicit', () {
      final CircuitState base = _ac3ContactorCircuit(actuated: true);
      final ComponentInstance original = base.components.first;
      final ComponentInstance invalidCoil = ComponentInstance(
        id: original.id,
        modelType: original.modelType,
        terminals: original.terminals,
        parameters: const <String, Object?>{
          'coilResistanceOhm': 0.0,
          'coilInductanceH': -0.1,
        },
        controlState: original.controlState,
        condition: original.condition,
      );
      final CircuitState invalidCircuit = _replaceFirstComponent(
        base,
        invalidCoil,
      );
      final Ac3SolveResult invalid = const SolverAC3().solve(
        invalidCircuit,
        topologyEngine.compile(invalidCircuit),
      );
      expect(invalid.status, Ac3SolveStatus.invalid);
      expect(
        invalid.diagnostics.map((Ac3SolverDiagnostic item) => item.code),
        contains(Ac3DiagnosticCode.invalidParameter),
      );

      final ComponentInstance openContactor = ComponentInstance(
        id: original.id,
        modelType: original.modelType,
        terminals: original.terminals,
        parameters: original.parameters,
        controlState: original.controlState,
        condition: ComponentCondition.openCircuit,
      );
      final CircuitState openCircuit = _replaceFirstComponent(
        base,
        openContactor,
      );
      final Ac3SolveResult open = const SolverAC3().solve(
        openCircuit,
        topologyEngine.compile(openCircuit),
      );
      expect(open.isSolved, isTrue);
      expect(
        open.branch('component:k1:control:coil').kind,
        Ac3BranchKind.controlCoil,
      );
      expect(
        open.branch('component:k1:control:coil').current!.magnitude,
        closeTo(0.0, 1e-12),
      );
    });
  });

  group('Contactor AC3 branch behavior', () {
    test(
      'three power poles follow actuated state while coil remains modeled',
      () {
        final CircuitState released = _ac3ContactorCircuit(actuated: false);
        final Ac3SolveResult releasedResult = const SolverAC3().solve(
          released,
          topologyEngine.compile(released),
        );
        expect(releasedResult.isSolved, isTrue);
        expect(
          releasedResult.branch('component:k1:control:coil').current!.magnitude,
          closeTo(0.23, 1e-8),
        );
        for (final String branchId in <String>[
          'component:k1:power:L1',
          'component:k1:power:L2',
          'component:k1:power:L3',
        ]) {
          expect(
            releasedResult.branch(branchId).kind,
            Ac3BranchKind.contactorContact,
          );
          expect(
            releasedResult.branch(branchId).current!.magnitude,
            closeTo(0.0, 1e-10),
          );
        }

        final CircuitState actuated = _ac3ContactorCircuit(actuated: true);
        final Ac3SolveResult actuatedResult = const SolverAC3().solve(
          actuated,
          topologyEngine.compile(actuated),
        );
        expect(actuatedResult.isSolved, isTrue);
        for (final String load in <String>['r1', 'r2', 'r3']) {
          expect(
            actuatedResult.branch('component:$load').current!.magnitude,
            closeTo(5.0, 1e-8),
          );
        }
      },
    );
  });
}

CircuitState _replaceFirstComponent(
  CircuitState base,
  ComponentInstance replacement,
) => CircuitState(
  circuitId: base.circuitId,
  revision: base.revision,
  mode: base.mode,
  components: <ComponentInstance>[
    replacement,
    ...base.components.skip(1),
  ],
  connections: base.connections,
  sources: base.sources,
  settings: base.settings,
);

CircuitState _ac1ContactorCircuit({required bool actuated}) => CircuitState(
  circuitId: CircuitId('contact-ac1-$actuated'),
  revision: 0,
  mode: ElectricalMode.ac1,
  components: <ComponentInstance>[
    ComponentInstance(
      id: ComponentId('k1'),
      modelType: 'contactor_ac1',
      terminals: <Terminal>[
        _t('k1-in', '1', phase: PhaseTag.l1),
        _t('k1-out', '2', phase: PhaseTag.l1),
        _t('k1-a1', 'A1', role: TerminalRole.coilA1, phase: PhaseTag.l1),
        _t('k1-a2', 'A2', role: TerminalRole.coilA2, phase: PhaseTag.neutral),
      ],
      parameters: const <String, Object?>{'coilResistanceOhm': 1000.0},
      controlState: <String, Object?>{'actuated': actuated},
    ),
    _resistor('r1', PhaseTag.l1),
  ],
  connections: <Connection>[
    _wire('w1', 'v-l', 'k1-in'),
    _wire('w2', 'k1-out', 'r1-p'),
    _wire('w3', 'r1-n', 'v-n'),
    _wire('w4', 'v-l', 'k1-a1'),
    _wire('w5', 'k1-a2', 'v-n'),
  ],
  sources: <SourceInstance>[_singlePhaseSource('v')],
  settings: const <String, Object?>{'frequencyHz': 50.0},
);

CircuitState _ac1AuxCircuit({
  required String modelType,
  required bool actuated,
}) => CircuitState(
  circuitId: CircuitId('$modelType-$actuated'),
  revision: 0,
  mode: ElectricalMode.ac1,
  components: <ComponentInstance>[
    ComponentInstance(
      id: ComponentId('aux1'),
      modelType: modelType,
      terminals: <Terminal>[
        _t('aux-in', '13', phase: PhaseTag.l1),
        _t('aux-out', '14', phase: PhaseTag.l1),
      ],
      controlState: <String, Object?>{'actuated': actuated},
    ),
    _resistor('r1', PhaseTag.l1),
  ],
  connections: <Connection>[
    _wire('w1', 'v-l', 'aux-in'),
    _wire('w2', 'aux-out', 'r1-p'),
    _wire('w3', 'r1-n', 'v-n'),
  ],
  sources: <SourceInstance>[_singlePhaseSource('v')],
  settings: const <String, Object?>{'frequencyHz': 50.0},
);

CircuitState _ac3ContactorCircuit({required bool actuated}) => CircuitState(
  circuitId: CircuitId('contact-ac3-$actuated'),
  revision: 0,
  mode: ElectricalMode.ac3,
  components: <ComponentInstance>[
    ComponentInstance(
      id: ComponentId('k1'),
      modelType: 'contactor_3p',
      terminals: <Terminal>[
        _t('k1-l1-in', '1L1', phase: PhaseTag.l1),
        _t('k1-l2-in', '3L2', phase: PhaseTag.l2),
        _t('k1-l3-in', '5L3', phase: PhaseTag.l3),
        _t('k1-l1-out', '2T1', phase: PhaseTag.l1),
        _t('k1-l2-out', '4T2', phase: PhaseTag.l2),
        _t('k1-l3-out', '6T3', phase: PhaseTag.l3),
        _t('k1-a1', 'A1', role: TerminalRole.coilA1, phase: PhaseTag.l1),
        _t('k1-a2', 'A2', role: TerminalRole.coilA2, phase: PhaseTag.neutral),
      ],
      parameters: const <String, Object?>{'coilResistanceOhm': 1000.0},
      controlState: <String, Object?>{'actuated': actuated},
    ),
    _resistor('r1', PhaseTag.l1),
    _resistor('r2', PhaseTag.l2),
    _resistor('r3', PhaseTag.l3),
  ],
  connections: <Connection>[
    _wire('p1', 'v1-p', 'k1-l1-in'),
    _wire('p2', 'v2-p', 'k1-l2-in'),
    _wire('p3', 'v3-p', 'k1-l3-in'),
    _wire('o1', 'k1-l1-out', 'r1-p'),
    _wire('o2', 'k1-l2-out', 'r2-p'),
    _wire('o3', 'k1-l3-out', 'r3-p'),
    _wire('n1', 'r1-n', 'v1-n'),
    _wire('n2', 'r2-n', 'v1-n'),
    _wire('n3', 'r3-n', 'v1-n'),
    _wire('ns2', 'v2-n', 'v1-n'),
    _wire('ns3', 'v3-n', 'v1-n'),
    _wire('c1', 'v1-p', 'k1-a1'),
    _wire('c2', 'k1-a2', 'v1-n'),
  ],
  sources: <SourceInstance>[
    _phaseSource('v1', PhaseTag.l1),
    _phaseSource('v2', PhaseTag.l2),
    _phaseSource('v3', PhaseTag.l3),
  ],
  settings: const <String, Object?>{'frequencyHz': 50.0},
);

ComponentInstance _resistor(String id, PhaseTag phase) => ComponentInstance(
  id: ComponentId(id),
  modelType: 'resistor',
  terminals: <Terminal>[
    _t('$id-p', 'L', phase: phase),
    _t('$id-n', 'N', phase: PhaseTag.neutral),
  ],
  parameters: const <String, Object?>{'resistanceOhm': 46.0},
);

SourceInstance _singlePhaseSource(String id) => SourceInstance(
  id: SourceId(id),
  modelType: 'ac_voltage_source',
  terminals: <Terminal>[
    _t('$id-l', 'L', phase: PhaseTag.l1),
    _t('$id-n', 'N', phase: PhaseTag.neutral),
  ],
  parameters: const <String, Object?>{'voltageRmsV': 230.0},
);

SourceInstance _phaseSource(String id, PhaseTag phase) => SourceInstance(
  id: SourceId(id),
  modelType: 'ac_voltage_source',
  terminals: <Terminal>[
    _t('$id-p', phase.name, phase: phase),
    _t('$id-n', 'N', phase: PhaseTag.neutral),
  ],
  parameters: const <String, Object?>{'voltageRmsV': 230.0},
);

Connection _wire(String id, String from, String to) => Connection(
  id: ConnectionId(id),
  fromTerminalId: TerminalId(from),
  toTerminalId: TerminalId(to),
);

Terminal _t(
  String id,
  String name, {
  TerminalRole role = TerminalRole.generic,
  PhaseTag phase = PhaseTag.none,
}) => Terminal(id: TerminalId(id), name: name, role: role, phase: phase);
