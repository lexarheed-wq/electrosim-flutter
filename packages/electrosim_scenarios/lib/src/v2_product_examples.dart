import 'package:electrosim_domain/electrosim_domain.dart';

import 'example_definition.dart';
import 'example_repository.dart';

ExampleRepository buildV2ProductExampleRepository() => ExampleRepository(
  examples: <ExampleDefinition>[
    _lampIndicatorSchema(),
    _dcMotorSchema(),
  ],
);

ExampleDefinition _lampIndicatorSchema() {
  const String prefix = 'v2sl1';
  return ExampleDefinition(
    id: CircuitTemplateId('V2-SCHEMA-DC-LAMP-01'),
    title: 'Voyant CC autonome',
    description:
        'Schéma sain natif V2 : source 24 V alimentant un voyant résistif.',
    circuit: CircuitState(
      circuitId: CircuitId('v2-schema-dc-lamp-01'),
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
        'libraryKind': 'healthy-schema',
        'healthy': true,
      },
    ),
    metadata: const <String, Object?>{
      'library': 'v2-product',
      'origin': 'v2-native',
      'libraryKind': 'healthy-schema',
    },
  );
}

ExampleDefinition _dcMotorSchema() {
  const String prefix = 'v2sm1';
  return ExampleDefinition(
    id: CircuitTemplateId('V2-SCHEMA-DC-MOTOR-01'),
    title: 'Moteur CC en alimentation directe',
    description:
        'Schéma sain natif V2 : moteur CC résistif alimenté sous 48 V.',
    circuit: CircuitState(
      circuitId: CircuitId('v2-schema-dc-motor-01'),
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
        Connection(
          id: ConnectionId('$prefix-return'),
          fromTerminalId: TerminalId('$prefix-motor-b'),
          toTerminalId: TerminalId('$prefix-source-minus'),
        ),
      ],
      metadata: const <String, Object?>{
        'library': 'v2-product',
        'origin': 'v2-native',
        'libraryKind': 'healthy-schema',
        'healthy': true,
      },
    ),
    metadata: const <String, Object?>{
      'library': 'v2-product',
      'origin': 'v2-native',
      'libraryKind': 'healthy-schema',
    },
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
