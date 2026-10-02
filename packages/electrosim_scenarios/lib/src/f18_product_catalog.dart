import 'package:electrosim_domain/electrosim_domain.dart';

import 'f16_catalog.dart';
import 'fault_scenario_definition.dart';
import 'fault_scenario_repository.dart';

/// First F18 product-native troubleshooting catalog.
///
/// This catalog intentionally starts from zero instead of inheriting the
/// historical F11/F16 fault library. Historical catalogs remain available for
/// regression coverage only.
QualifiedCatalog buildF18ProductCatalog() {
  final FaultScenarioRepository faults = FaultScenarioRepository(
    scenarios: <FaultScenarioDefinition>[
      _lightingSwitchOpenScenario(),
    ],
  );
  return QualifiedCatalog(
    catalogVersion: '18.0.0',
    examples: const <dynamic>[],
    faultScenarios: faults.all,
  );
}

Terminal _terminal(
  String id,
  String name, {
  TerminalRole role = TerminalRole.generic,
  PhaseTag phase = PhaseTag.none,
}) =>
    Terminal(
      id: TerminalId(id),
      name: name,
      role: role,
      phase: phase,
    );

FaultScenarioDefinition _lightingSwitchOpenScenario() {
  final Terminal sourcePositive = _terminal(
    'f18-g1-pos',
    '+',
    role: TerminalRole.positive,
    phase: PhaseTag.dcPositive,
  );
  final Terminal sourceNegative = _terminal(
    'f18-g1-neg',
    '−',
    role: TerminalRole.negative,
    phase: PhaseTag.dcNegative,
  );
  final Terminal breakerIn = _terminal(
    'f18-qf1-in',
    '1',
    role: TerminalRole.input,
    phase: PhaseTag.dcPositive,
  );
  final Terminal breakerOut = _terminal(
    'f18-qf1-out',
    '2',
    role: TerminalRole.output,
    phase: PhaseTag.dcPositive,
  );
  final Terminal switchIn = _terminal(
    'f18-s1-in',
    '1',
    role: TerminalRole.input,
    phase: PhaseTag.dcPositive,
  );
  final Terminal switchOut = _terminal(
    'f18-s1-out',
    '2',
    role: TerminalRole.output,
    phase: PhaseTag.dcPositive,
  );
  final Terminal lampIn = _terminal(
    'f18-h1-in',
    'L',
    role: TerminalRole.input,
    phase: PhaseTag.dcPositive,
  );
  final Terminal lampOut = _terminal(
    'f18-h1-out',
    'N',
    role: TerminalRole.output,
    phase: PhaseTag.dcNegative,
  );

  return FaultScenarioDefinition(
    id: FaultScenarioId('FAULT-F18-004'),
    title: 'TP 04 · Circuit d’éclairage 24 V',
    studentBrief:
        'La lampe reste éteinte. Localiser la panne, justifier le diagnostic par des mesures puis proposer la réparation.',
    faultyCircuit: CircuitState(
      circuitId: CircuitId('fault-f18-lighting-004'),
      revision: 0,
      mode: ElectricalMode.dc,
      sources: <SourceInstance>[
        SourceInstance(
          id: SourceId('g1'),
          modelType: 'dc_voltage_source',
          terminals: <Terminal>[sourcePositive, sourceNegative],
          parameters: const <String, Object?>{'voltageV': 24.0},
        ),
      ],
      components: <ComponentInstance>[
        ComponentInstance(
          id: ComponentId('qf1'),
          modelType: 'breaker',
          terminals: <Terminal>[breakerIn, breakerOut],
          controlState: const <String, Object?>{
            'closed': true,
            'tripped': false,
          },
        ),
        ComponentInstance(
          id: ComponentId('s1'),
          modelType: 'switch',
          terminals: <Terminal>[switchIn, switchOut],
          condition: ComponentCondition.openCircuit,
          controlState: const <String, Object?>{'closed': true},
        ),
        ComponentInstance(
          id: ComponentId('h1'),
          modelType: 'lamp',
          terminals: <Terminal>[lampIn, lampOut],
          parameters: const <String, Object?>{'resistanceOhm': 24.0},
        ),
      ],
      connections: <Connection>[
        Connection(
          id: ConnectionId('f18-w1'),
          fromTerminalId: sourcePositive.id,
          toTerminalId: breakerIn.id,
          phase: PhaseTag.dcPositive,
        ),
        Connection(
          id: ConnectionId('f18-w2'),
          fromTerminalId: breakerOut.id,
          toTerminalId: switchIn.id,
          phase: PhaseTag.dcPositive,
        ),
        Connection(
          id: ConnectionId('f18-w3'),
          fromTerminalId: switchOut.id,
          toTerminalId: lampIn.id,
          phase: PhaseTag.dcPositive,
        ),
        Connection(
          id: ConnectionId('f18-w4'),
          fromTerminalId: lampOut.id,
          toTerminalId: sourceNegative.id,
          phase: PhaseTag.dcNegative,
        ),
      ],
      metadata: const <String, Object?>{
        'category': 'troubleshooting',
        'autonomousFaultScenario': true,
        'catalogBatch': 'F18-MAGICPATH',
      },
    ),
    teacherTruth: TeacherTruth(
      rootCauses: const <RootCause>[
        RootCause(
          kind: RootCauseKind.componentOpen,
          targetId: 's1',
          description:
              'L’interrupteur S1 présente une coupure interne malgré une commande mécaniquement fermée.',
        ),
      ],
      expectedSymptoms: const <String>[
        'La lampe H1 reste éteinte malgré une alimentation G1 active et un disjoncteur QF1 fermé.',
      ],
      expectedMeasurements: const <ExpectedBranchMeasurement>[
        ExpectedBranchMeasurement(
          branchId: 'component:h1',
          currentA: 0.0,
        ),
      ],
      acceptableRepairs: <RepairAction>[
        RepairAction.normalizeComponent(
          id: 'repair-replace-s1',
          componentId: ComponentId('s1'),
        ),
      ],
    ),
    difficulty: FaultDifficulty.basic,
    estimatedDurationMinutes: 20,
    version: '18.0.0',
  );
}
