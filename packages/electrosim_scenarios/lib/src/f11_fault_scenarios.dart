import 'package:electrosim_domain/electrosim_domain.dart';

import 'fault_scenario_definition.dart';
import 'fault_scenario_repository.dart';

FaultScenarioRepository buildF11FaultScenarioRepository() => FaultScenarioRepository(
      scenarios: <FaultScenarioDefinition>[
        _missingReturnConductorScenario(),
        _openComponentScenario(),
      ],
    );

Terminal _terminal(String id, String name, {TerminalRole role = TerminalRole.generic, PhaseTag phase = PhaseTag.none}) =>
    Terminal(id: TerminalId(id), name: name, role: role, phase: phase);

SourceInstance _voltageSource(String prefix, double voltageV) => SourceInstance(
      id: SourceId('$prefix-source'),
      modelType: 'dc_voltage_source',
      terminals: <Terminal>[
        _terminal('$prefix-vp', '+', role: TerminalRole.positive, phase: PhaseTag.dcPositive),
        _terminal('$prefix-vn', '-', role: TerminalRole.negative, phase: PhaseTag.dcNegative),
      ],
      parameters: <String, Object?>{'voltageV': voltageV},
    );

FaultScenarioDefinition _missingReturnConductorScenario() {
  const String p = 'f11c1';
  final Connection missingReturn = Connection(
    id: ConnectionId('$p-w2'),
    fromTerminalId: TerminalId('$p-r1b'),
    toTerminalId: TerminalId('$p-vn'),
  );
  return FaultScenarioDefinition(
    id: FaultScenarioId('FAULT-DC-001'),
    title: 'Conducteur retour absent',
    studentBrief: 'Le récepteur ne fonctionne pas. Identifier la cause par mesures puis remettre le circuit en service.',
    faultyCircuit: CircuitState(
      circuitId: CircuitId('fault-dc-001'),
      revision: 0,
      mode: ElectricalMode.dc,
      components: <ComponentInstance>[
        ComponentInstance(
          id: ComponentId('$p-r1'),
          modelType: 'resistor',
          terminals: <Terminal>[_terminal('$p-r1a', 'A'), _terminal('$p-r1b', 'B')],
          parameters: const <String, Object?>{'resistanceOhm': 12.0},
        ),
      ],
      connections: <Connection>[
        Connection(id: ConnectionId('$p-w1'), fromTerminalId: TerminalId('$p-vp'), toTerminalId: TerminalId('$p-r1a')),
      ],
      sources: <SourceInstance>[_voltageSource(p, 24.0)],
      metadata: const <String, Object?>{'category': 'troubleshooting', 'autonomousFaultScenario': true},
    ),
    teacherTruth: TeacherTruth(
      rootCauses: const <RootCause>[
        RootCause(kind: RootCauseKind.missingConnection, targetId: '$p-w2', description: 'Le conducteur retour entre le récepteur et le pôle négatif est absent.'),
      ],
      expectedSymptoms: const <String>['Courant nul dans le récepteur malgré une source active.'],
      expectedMeasurements: const <ExpectedBranchMeasurement>[
        ExpectedBranchMeasurement(branchId: 'component:$p-r1', currentA: 0.0),
      ],
      acceptableRepairs: <RepairAction>[
        RepairAction.addConnection(id: 'repair-add-return', connection: missingReturn),
      ],
    ),
    difficulty: FaultDifficulty.basic,
    estimatedDurationMinutes: 15,
    version: '1.0.0',
  );
}

FaultScenarioDefinition _openComponentScenario() {
  const String p = 'f11c2';
  return FaultScenarioDefinition(
    id: FaultScenarioId('FAULT-DC-002'),
    title: 'Récepteur électriquement ouvert',
    studentBrief: 'Le circuit est correctement câblé mais le récepteur ne consomme aucun courant. Diagnostiquer puis réparer.',
    faultyCircuit: CircuitState(
      circuitId: CircuitId('fault-dc-002'),
      revision: 0,
      mode: ElectricalMode.dc,
      components: <ComponentInstance>[
        ComponentInstance(
          id: ComponentId('$p-r1'),
          modelType: 'resistor',
          terminals: <Terminal>[_terminal('$p-r1a', 'A'), _terminal('$p-r1b', 'B')],
          parameters: const <String, Object?>{'resistanceOhm': 6.0},
          condition: ComponentCondition.openCircuit,
        ),
      ],
      connections: <Connection>[
        Connection(id: ConnectionId('$p-w1'), fromTerminalId: TerminalId('$p-vp'), toTerminalId: TerminalId('$p-r1a')),
        Connection(id: ConnectionId('$p-w2'), fromTerminalId: TerminalId('$p-r1b'), toTerminalId: TerminalId('$p-vn')),
      ],
      sources: <SourceInstance>[_voltageSource(p, 12.0)],
      metadata: const <String, Object?>{'category': 'troubleshooting', 'autonomousFaultScenario': true},
    ),
    teacherTruth: TeacherTruth(
      rootCauses: const <RootCause>[
        RootCause(kind: RootCauseKind.componentOpen, targetId: '$p-r1', description: 'Le récepteur est en circuit ouvert interne.'),
      ],
      expectedSymptoms: const <String>['Courant nul avec tension présente aux bornes du composant ouvert.'],
      expectedMeasurements: const <ExpectedBranchMeasurement>[
        ExpectedBranchMeasurement(branchId: 'component:$p-r1', currentA: 0.0),
      ],
      acceptableRepairs: <RepairAction>[
        RepairAction.normalizeComponent(id: 'repair-replace-open-load', componentId: ComponentId('$p-r1')),
      ],
    ),
    difficulty: FaultDifficulty.basic,
    estimatedDurationMinutes: 15,
    version: '1.0.0',
  );
}
