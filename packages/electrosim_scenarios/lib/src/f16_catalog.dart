import 'package:electrosim_domain/electrosim_domain.dart';

import 'example_definition.dart';
import 'example_repository.dart';
import 'f10_examples.dart';
import 'f11_fault_scenarios.dart';
import 'fault_scenario_definition.dart';
import 'fault_scenario_repository.dart';

final class QualifiedCatalog {
  QualifiedCatalog({
    required this.catalogVersion,
    required List<ExampleDefinition> examples,
    required List<FaultScenarioDefinition> faultScenarios,
  })  : examples = List<ExampleDefinition>.unmodifiable(examples),
        faultScenarios = List<FaultScenarioDefinition>.unmodifiable(faultScenarios);

  final String catalogVersion;
  final List<ExampleDefinition> examples;
  final List<FaultScenarioDefinition> faultScenarios;

  bool get allItemsSigned =>
      examples.every((ExampleDefinition item) => item.validationStamp != null) &&
      faultScenarios.every((FaultScenarioDefinition item) => item.validationStamp != null);
}

QualifiedCatalog buildF16QualifiedCatalog() {
  final List<ExampleDefinition> baselineExamples =
      buildF10ExampleRepository().all;
  final List<FaultScenarioDefinition> baselineFaults =
      buildF11FaultScenarioRepository().all;

  final List<ExampleDefinition> batchExamples = ExampleRepository(
    examples: <ExampleDefinition>[
      _parallelResistorsExample(),
      _voltageDividerExample(),
    ],
  ).all;

  final List<FaultScenarioDefinition> batchFaults = FaultScenarioRepository(
    scenarios: <FaultScenarioDefinition>[
      _missingSeriesLinkScenario(),
    ],
  ).all;

  return QualifiedCatalog(
    catalogVersion: '16.1.0',
    examples: <ExampleDefinition>[...baselineExamples, ...batchExamples],
    faultScenarios: <FaultScenarioDefinition>[...baselineFaults, ...batchFaults],
  );
}

Terminal _terminal(
  String id,
  String name, {
  TerminalRole role = TerminalRole.generic,
  PhaseTag phase = PhaseTag.none,
}) =>
    Terminal(id: TerminalId(id), name: name, role: role, phase: phase);

SourceInstance _voltageSource(String prefix, double voltageV) => SourceInstance(
      id: SourceId('$prefix-source'),
      modelType: 'dc_voltage_source',
      terminals: <Terminal>[
        _terminal(
          '$prefix-vp',
          '+',
          role: TerminalRole.positive,
          phase: PhaseTag.dcPositive,
        ),
        _terminal(
          '$prefix-vn',
          '-',
          role: TerminalRole.negative,
          phase: PhaseTag.dcNegative,
        ),
      ],
      parameters: <String, Object?>{'voltageV': voltageV},
    );

ComponentInstance _resistor(
  String prefix,
  String name,
  double resistanceOhm,
) =>
    ComponentInstance(
      id: ComponentId('$prefix-' + name),
      modelType: 'resistor',
      terminals: <Terminal>[
        _terminal('$prefix-' + name + 'a', 'A'),
        _terminal('$prefix-' + name + 'b', 'B'),
      ],
      parameters: <String, Object?>{'resistanceOhm': resistanceOhm},
    );

ExampleDefinition _parallelResistorsExample() {
  const String p = 'f16ex04';
  return ExampleDefinition(
    id: ExampleId('EX-DC-004'),
    title: 'Résistances identiques en parallèle',
    description:
        'Deux résistances de 10 ohms en parallèle sous 10 V, circuit sain.',
    circuit: CircuitState(
      circuitId: CircuitId('example-dc-004'),
      revision: 0,
      mode: ElectricalMode.dc,
      components: <ComponentInstance>[
        _resistor(p, 'r1', 10.0),
        _resistor(p, 'r2', 10.0),
      ],
      connections: <Connection>[
        Connection(
          id: ConnectionId('$p-w1'),
          fromTerminalId: TerminalId('$p-vp'),
          toTerminalId: TerminalId('$p-r1a'),
        ),
        Connection(
          id: ConnectionId('$p-w2'),
          fromTerminalId: TerminalId('$p-vp'),
          toTerminalId: TerminalId('$p-r2a'),
        ),
        Connection(
          id: ConnectionId('$p-w3'),
          fromTerminalId: TerminalId('$p-r1b'),
          toTerminalId: TerminalId('$p-vn'),
        ),
        Connection(
          id: ConnectionId('$p-w4'),
          fromTerminalId: TerminalId('$p-r2b'),
          toTerminalId: TerminalId('$p-vn'),
        ),
      ],
      sources: <SourceInstance>[_voltageSource(p, 10.0)],
      metadata: const <String, Object?>{
        'category': 'dc-basics',
        'healthy': true,
        'catalogBatch': 'F16-B01',
      },
    ),
  );
}

ExampleDefinition _voltageDividerExample() {
  const String p = 'f16ex05';
  return ExampleDefinition(
    id: ExampleId('EX-DC-005'),
    title: 'Diviseur résistif CC',
    description:
        'Résistances de 5 et 15 ohms en série sous 20 V, circuit sain.',
    circuit: CircuitState(
      circuitId: CircuitId('example-dc-005'),
      revision: 0,
      mode: ElectricalMode.dc,
      components: <ComponentInstance>[
        _resistor(p, 'r1', 5.0),
        _resistor(p, 'r2', 15.0),
      ],
      connections: <Connection>[
        Connection(
          id: ConnectionId('$p-w1'),
          fromTerminalId: TerminalId('$p-vp'),
          toTerminalId: TerminalId('$p-r1a'),
        ),
        Connection(
          id: ConnectionId('$p-w2'),
          fromTerminalId: TerminalId('$p-r1b'),
          toTerminalId: TerminalId('$p-r2a'),
        ),
        Connection(
          id: ConnectionId('$p-w3'),
          fromTerminalId: TerminalId('$p-r2b'),
          toTerminalId: TerminalId('$p-vn'),
        ),
      ],
      sources: <SourceInstance>[_voltageSource(p, 20.0)],
      metadata: const <String, Object?>{
        'category': 'dc-basics',
        'healthy': true,
        'catalogBatch': 'F16-B01',
      },
    ),
  );
}

FaultScenarioDefinition _missingSeriesLinkScenario() {
  const String p = 'f16f03';
  final Connection missingLink = Connection(
    id: ConnectionId('$p-w2'),
    fromTerminalId: TerminalId('$p-r1b'),
    toTerminalId: TerminalId('$p-r2a'),
  );

  return FaultScenarioDefinition(
    id: FaultScenarioId('FAULT-DC-003'),
    title: 'Liaison intermédiaire absente',
    studentBrief:
        'Deux récepteurs sont câblés en série mais le circuit ne consomme aucun courant. Identifier puis réparer la liaison défaillante.',
    faultyCircuit: CircuitState(
      circuitId: CircuitId('fault-dc-003'),
      revision: 0,
      mode: ElectricalMode.dc,
      components: <ComponentInstance>[
        _resistor(p, 'r1', 10.0),
        _resistor(p, 'r2', 10.0),
      ],
      connections: <Connection>[
        Connection(
          id: ConnectionId('$p-w1'),
          fromTerminalId: TerminalId('$p-vp'),
          toTerminalId: TerminalId('$p-r1a'),
        ),
        Connection(
          id: ConnectionId('$p-w3'),
          fromTerminalId: TerminalId('$p-r2b'),
          toTerminalId: TerminalId('$p-vn'),
        ),
      ],
      sources: <SourceInstance>[_voltageSource(p, 20.0)],
      metadata: const <String, Object?>{
        'category': 'troubleshooting',
        'autonomousFaultScenario': true,
        'catalogBatch': 'F16-B01',
      },
    ),
    teacherTruth: TeacherTruth(
      rootCauses: const <RootCause>[
        RootCause(
          kind: RootCauseKind.missingConnection,
          targetId: '$p-w2',
          description:
              'La liaison entre les deux résistances en série est absente.',
        ),
      ],
      expectedSymptoms: const <String>[
        'Courant nul dans les deux récepteurs malgré une source active.',
      ],
      expectedMeasurements: const <ExpectedBranchMeasurement>[
        ExpectedBranchMeasurement(branchId: 'component:$p-r1', currentA: 0.0),
        ExpectedBranchMeasurement(branchId: 'component:$p-r2', currentA: 0.0),
      ],
      acceptableRepairs: <RepairAction>[
        RepairAction.addConnection(
          id: 'repair-add-series-link',
          connection: missingLink,
        ),
      ],
    ),
    difficulty: FaultDifficulty.basic,
    estimatedDurationMinutes: 20,
    version: '1.0.0',
  );
}
