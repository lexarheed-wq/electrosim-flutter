// BOOTSTRAP_FIXTURE_ONLY: V2 technical contract fixture; not the target product library.
import 'package:electrosim_domain/electrosim_domain.dart';

import 'example_definition.dart';
import 'example_repository.dart';

ExampleRepository buildF10ExampleRepository() => ExampleRepository(
  examples: <ExampleDefinition>[
    _singleResistorExample(),
    _seriesResistorsExample(),
    _switchLoadExample(),
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

ExampleDefinition _singleResistorExample() {
  const String p = 'ex01';
  return ExampleDefinition(
    id: CircuitTemplateId('EX-DC-001'),
    title: 'Circuit résistif CC simple',
    description: 'Source 24 V alimentant une résistance de 12 ohms.',
    circuit: CircuitState(
      circuitId: CircuitId('example-dc-001'),
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
        Connection(id: ConnectionId('$p-w2'), fromTerminalId: TerminalId('$p-r1b'), toTerminalId: TerminalId('$p-vn')),
      ],
      sources: <SourceInstance>[_voltageSource(p, 24.0)],
      metadata: const <String, Object?>{'category': 'dc-basics', 'healthy': true},
    ),
  );
}

ExampleDefinition _seriesResistorsExample() {
  const String p = 'ex02';
  return ExampleDefinition(
    id: CircuitTemplateId('EX-DC-002'),
    title: 'Résistances en série',
    description: 'Deux résistances de 10 et 20 ohms alimentées sous 30 V.',
    circuit: CircuitState(
      circuitId: CircuitId('example-dc-002'),
      revision: 0,
      mode: ElectricalMode.dc,
      components: <ComponentInstance>[
        ComponentInstance(
          id: ComponentId('$p-r1'),
          modelType: 'resistor',
          terminals: <Terminal>[_terminal('$p-r1a', 'A'), _terminal('$p-r1b', 'B')],
          parameters: const <String, Object?>{'resistanceOhm': 10.0},
        ),
        ComponentInstance(
          id: ComponentId('$p-r2'),
          modelType: 'resistor',
          terminals: <Terminal>[_terminal('$p-r2a', 'A'), _terminal('$p-r2b', 'B')],
          parameters: const <String, Object?>{'resistanceOhm': 20.0},
        ),
      ],
      connections: <Connection>[
        Connection(id: ConnectionId('$p-w1'), fromTerminalId: TerminalId('$p-vp'), toTerminalId: TerminalId('$p-r1a')),
        Connection(id: ConnectionId('$p-w2'), fromTerminalId: TerminalId('$p-r1b'), toTerminalId: TerminalId('$p-r2a')),
        Connection(id: ConnectionId('$p-w3'), fromTerminalId: TerminalId('$p-r2b'), toTerminalId: TerminalId('$p-vn')),
      ],
      sources: <SourceInstance>[_voltageSource(p, 30.0)],
      metadata: const <String, Object?>{'category': 'dc-basics', 'healthy': true},
    ),
  );
}

ExampleDefinition _switchLoadExample() {
  const String p = 'ex03';
  return ExampleDefinition(
    id: CircuitTemplateId('EX-DC-003'),
    title: 'Commande simple par interrupteur',
    description: 'Interrupteur fermé commandant une charge résistive saine sous 24 V.',
    circuit: CircuitState(
      circuitId: CircuitId('example-dc-003'),
      revision: 0,
      mode: ElectricalMode.dc,
      components: <ComponentInstance>[
        ComponentInstance(
          id: ComponentId('$p-s1'),
          modelType: 'switch',
          terminals: <Terminal>[_terminal('$p-s1a', 'A'), _terminal('$p-s1b', 'B')],
          controlState: const <String, Object?>{'closed': true},
        ),
        ComponentInstance(
          id: ComponentId('$p-r1'),
          modelType: 'resistor',
          terminals: <Terminal>[_terminal('$p-r1a', 'A'), _terminal('$p-r1b', 'B')],
          parameters: const <String, Object?>{'resistanceOhm': 24.0},
        ),
      ],
      connections: <Connection>[
        Connection(id: ConnectionId('$p-w1'), fromTerminalId: TerminalId('$p-vp'), toTerminalId: TerminalId('$p-s1a')),
        Connection(id: ConnectionId('$p-w2'), fromTerminalId: TerminalId('$p-s1b'), toTerminalId: TerminalId('$p-r1a')),
        Connection(id: ConnectionId('$p-w3'), fromTerminalId: TerminalId('$p-r1b'), toTerminalId: TerminalId('$p-vn')),
      ],
      sources: <SourceInstance>[_voltageSource(p, 24.0)],
      metadata: const <String, Object?>{'category': 'dc-control', 'healthy': true},
    ),
  );
}
