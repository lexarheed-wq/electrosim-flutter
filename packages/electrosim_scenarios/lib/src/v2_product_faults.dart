import 'package:electrosim_domain/electrosim_domain.dart';

import 'fault_scenario_definition.dart';
import 'fault_scenario_repository.dart';

FaultScenarioRepository buildV2ProductFaultRepository() =>
    FaultScenarioRepository(
      scenarios: <FaultScenarioDefinition>[
        _openLampScenario(),
        _missingMotorReturnScenario(),
      ],
    );

FaultScenarioDefinition _openLampScenario() {
  const String prefix = 'v2fl1';
  return FaultScenarioDefinition(
    id: FaultScenarioId('V2-FAULT-DC-LAMP-OPEN-01'),
    title: 'Voyant ouvert intérieurement',
    studentBrief:
        'Le voyant reste éteint alors que le câblage est complet. Effectuer les mesures utiles, identifier la défaillance puis remettre le circuit en service.',
    faultyCircuit: CircuitState(
      circuitId: CircuitId('v2-fault-dc-lamp-open-01'),
      revision: 0,
      mode: ElectricalMode.dc,
      sources: <SourceInstance>[
        _source(prefix: prefix, voltageV: 24),
      ],
      components: <ComponentInstance>[
        ComponentInstance(
          id: ComponentId('$prefix-lamp'),
          modelType: 'lamp',
          terminals: <Terminal>[
            _terminal('$prefix-lamp-a', 'A'),
            _terminal('$prefix-lamp-b', 'B'),
          ],
          parameters: const <String, Object?>{'resistanceOhm': 24.0},
          condition: ComponentCondition.openCircuit,
        ),
      ],
      connections: <Connection>[
        Connection(
          id: ConnectionId('$prefix-feed'),
          fromTerminalId: TerminalId('$prefix-source-plus'),
          toTerminalId: TerminalId('$prefix-lamp-a'),
        ),
        Connection(
          id: ConnectionId('$prefix-return'),
          fromTerminalId: TerminalId('$prefix-lamp-b'),
          toTerminalId: TerminalId('$prefix-source-minus'),
        ),
      ],
      metadata: const <String, Object?>{
        'library': 'v2-product',
        'origin': 'v2-native',
        'libraryKind': 'fault-scenario',
        'autonomousFaultScenario': true,
      },
    ),
    teacherTruth: TeacherTruth(
      rootCauses: const <RootCause>[
        RootCause(
          kind: RootCauseKind.componentOpen,
          targetId: '$prefix-lamp',
          description: 'Le voyant présente une coupure interne.',
        ),
      ],
      expectedSymptoms: const <String>[
        'Le courant du voyant est nul malgré la présence de la source.',
      ],
      expectedMeasurements: const <ExpectedBranchMeasurement>[
        ExpectedBranchMeasurement(
          branchId: 'component:$prefix-lamp',
          currentA: 0,
        ),
      ],
      acceptableRepairs: <RepairAction>[
        RepairAction.normalizeComponent(
          id: 'v2-repair-replace-lamp',
          componentId: ComponentId('$prefix-lamp'),
        ),
      ],
    ),
    difficulty: FaultDifficulty.basic,
    estimatedDurationMinutes: 20,
    version: '2.0.0',
  );
}

FaultScenarioDefinition _missingMotorReturnScenario() {
  const String prefix = 'v2fm1';
  final Connection returnConductor = Connection(
    id: ConnectionId('$prefix-return'),
    fromTerminalId: TerminalId('$prefix-motor-b'),
    toTerminalId: TerminalId('$prefix-source-minus'),
  );

  return FaultScenarioDefinition(
    id: FaultScenarioId('V2-FAULT-DC-MOTOR-RETURN-01'),
    title: 'Retour moteur CC interrompu',
    studentBrief:
        'Le moteur ne démarre pas. Localiser la rupture du circuit par des mesures électriques puis rétablir le fonctionnement.',
    faultyCircuit: CircuitState(
      circuitId: CircuitId('v2-fault-dc-motor-return-01'),
      revision: 0,
      mode: ElectricalMode.dc,
      sources: <SourceInstance>[
        _source(prefix: prefix, voltageV: 48),
      ],
      components: <ComponentInstance>[
        ComponentInstance(
          id: ComponentId('$prefix-motor'),
          modelType: 'motor_dc',
          terminals: <Terminal>[
            _terminal('$prefix-motor-a', 'A'),
            _terminal('$prefix-motor-b', 'B'),
          ],
          parameters: const <String, Object?>{'resistanceOhm': 16.0},
        ),
      ],
      connections: <Connection>[
        Connection(
          id: ConnectionId('$prefix-feed'),
          fromTerminalId: TerminalId('$prefix-source-plus'),
          toTerminalId: TerminalId('$prefix-motor-a'),
        ),
      ],
      metadata: const <String, Object?>{
        'library': 'v2-product',
        'origin': 'v2-native',
        'libraryKind': 'fault-scenario',
        'autonomousFaultScenario': true,
      },
    ),
    teacherTruth: TeacherTruth(
      rootCauses: const <RootCause>[
        RootCause(
          kind: RootCauseKind.missingConnection,
          targetId: '$prefix-return',
          description: 'Le conducteur de retour du moteur est absent.',
        ),
      ],
      expectedSymptoms: const <String>[
        'Le moteur ne consomme aucun courant avec la source disponible.',
      ],
      expectedMeasurements: const <ExpectedBranchMeasurement>[
        ExpectedBranchMeasurement(
          branchId: 'component:$prefix-motor',
          currentA: 0,
        ),
      ],
      acceptableRepairs: <RepairAction>[
        RepairAction.addConnection(
          id: 'v2-repair-restore-motor-return',
          connection: returnConductor,
        ),
      ],
    ),
    difficulty: FaultDifficulty.basic,
    estimatedDurationMinutes: 25,
    version: '2.0.0',
  );
}

Terminal _terminal(String id, String name) =>
    Terminal(id: TerminalId(id), name: name);

SourceInstance _source({
  required String prefix,
  required double voltageV,
}) => SourceInstance(
  id: SourceId('$prefix-source'),
  modelType: 'dc_voltage_source',
  terminals: <Terminal>[
    Terminal(
      id: TerminalId('$prefix-source-plus'),
      name: '+',
      role: TerminalRole.positive,
      phase: PhaseTag.dcPositive,
    ),
    Terminal(
      id: TerminalId('$prefix-source-minus'),
      name: '-',
      role: TerminalRole.negative,
      phase: PhaseTag.dcNegative,
    ),
  ],
  parameters: <String, Object?>{'voltageV': voltageV},
);
