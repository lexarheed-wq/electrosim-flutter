import 'dart:convert';

import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:test/test.dart';

Terminal terminal(
  String id,
  String name, {
  TerminalRole role = TerminalRole.generic,
  PhaseTag phase = PhaseTag.none,
}) => Terminal(id: TerminalId(id), name: name, role: role, phase: phase);

CircuitState sampleCircuit() {
  final Terminal sourcePositive = terminal(
    'src-pos',
    '+',
    role: TerminalRole.positive,
    phase: PhaseTag.dcPositive,
  );
  final Terminal sourceNegative = terminal(
    'src-neg',
    '-',
    role: TerminalRole.negative,
    phase: PhaseTag.dcNegative,
  );
  final Terminal lampA = terminal('lamp-a', 'A', role: TerminalRole.input);
  final Terminal lampB = terminal('lamp-b', 'B', role: TerminalRole.output);

  return CircuitState(
    circuitId: CircuitId('circuit-001'),
    revision: 3,
    mode: ElectricalMode.dc,
    components: <ComponentInstance>[
      ComponentInstance(
        id: ComponentId('lamp-1'),
        modelType: 'lamp.dc',
        terminals: <Terminal>[lampA, lampB],
        parameters: <String, Object?>{
          'nominalVoltage': 24,
          'tags': <Object?>['load', 'lighting'],
        },
        controlState: <String, Object?>{'requestedOn': true},
      ),
    ],
    sources: <SourceInstance>[
      SourceInstance(
        id: SourceId('source-1'),
        modelType: 'voltage.dc',
        terminals: <Terminal>[sourcePositive, sourceNegative],
        parameters: <String, Object?>{'voltage': 24.0},
      ),
    ],
    connections: <Connection>[
      Connection(
        id: ConnectionId('wire-1'),
        fromTerminalId: sourcePositive.id,
        toTerminalId: lampA.id,
        phase: PhaseTag.dcPositive,
      ),
      Connection(
        id: ConnectionId('wire-2'),
        fromTerminalId: lampB.id,
        toTerminalId: sourceNegative.id,
        phase: PhaseTag.dcNegative,
      ),
    ],
    settings: <String, Object?>{'ambientCelsius': 25, 'frequencyHz': 0},
    metadata: <String, Object?>{'title': 'F1 round trip'},
  );
}

void main() {
  group('typed IDs', () {
    test('preserve value and type-sensitive equality', () {
      expect(CircuitId('abc'), equals(CircuitId('abc')));
      expect(CircuitId('abc').hashCode, equals(CircuitId('abc').hashCode));
      expect(CircuitId('abc'), isNot(equals(ComponentId('abc'))));
      expect(CircuitId('abc').toString(), 'abc');
    });

    test('reject empty, whitespace and unsupported characters', () {
      for (final String value in <String>['', ' abc', 'abc ', 'a/b', 'électro']) {
        expect(
          () => CircuitId(value),
          throwsA(isA<DomainException>().having(
            (DomainException e) => e.code,
            'code',
            DomainErrorCode.invalidId,
          )),
        );
      }
    });
  });

  group('electrical primitives', () {
    test('quantity round-trips with explicit unit', () {
      final ElectricalQuantity quantity = ElectricalQuantity(
        value: 24,
        unit: ElectricalUnit.volt,
      );
      expect(quantity.unit.symbol, 'V');
      expect(ElectricalQuantity.fromJson(quantity.toJson()), quantity);
      expect(quantity.hashCode, ElectricalQuantity(value: 24, unit: ElectricalUnit.volt).hashCode);
    });

    test('quantity rejects non-finite values', () {
      expect(
        () => ElectricalQuantity(value: double.nan, unit: ElectricalUnit.volt),
        throwsA(isA<DomainException>()),
      );
    });

    test('enum decoding rejects unknown wire value', () {
      expect(
        () => ElectricalQuantity.fromJson(<String, Object?>{
          'value': 1,
          'unit': 'banana',
        }),
        throwsA(isA<DomainException>().having(
          (DomainException e) => e.code,
          'code',
          DomainErrorCode.invalidEnumValue,
        )),
      );
    });
  });

  group('terminal/component/source/connection contracts', () {
    test('terminal round-trip preserves metadata and phase', () {
      final Terminal original = Terminal(
        id: TerminalId('t-1'),
        name: 'L1',
        role: TerminalRole.phaseL1,
        phase: PhaseTag.l1,
        metadata: <String, Object?>{'z': 1, 'a': true},
      );
      final Terminal restored = Terminal.fromJson(original.toJson());
      expect(restored, original);
      expect(restored.hashCode, original.hashCode);
      expect(restored.metadata.keys.toList(), <String>['a', 'z']);
    });

    test('component round-trip and defensive immutability', () {
      final Map<String, Object?> parameters = <String, Object?>{
        'resistanceOhm': 12,
        'nested': <String, Object?>{'b': 2, 'a': 1},
      };
      final List<Terminal> terminals = <Terminal>[terminal('r-a', 'A'), terminal('r-b', 'B')];
      final ComponentInstance component = ComponentInstance(
        id: ComponentId('r-1'),
        modelType: 'resistor',
        terminals: terminals,
        parameters: parameters,
        condition: ComponentCondition.degraded,
        controlState: <String, Object?>{'enabled': true},
      );
      parameters['resistanceOhm'] = 999;
      terminals.clear();
      expect(component.parameters['resistanceOhm'], 12);
      expect(component.terminals, hasLength(2));
      expect(ComponentInstance.fromJson(component.toJson()), component);
      expect(() => component.parameters['x'] = 1, throwsA(isA<UnsupportedError>()));
      expect(() => component.terminals.add(terminal('x', 'X')), throwsA(isA<UnsupportedError>()));
    });

    test('component rejects duplicate terminal IDs and empty model type', () {
      expect(
        () => ComponentInstance(
          id: ComponentId('c-1'),
          modelType: 'x',
          terminals: <Terminal>[terminal('same', 'A'), terminal('same', 'B')],
        ),
        throwsA(isA<DomainException>().having(
          (DomainException e) => e.code,
          'code',
          DomainErrorCode.duplicateId,
        )),
      );
      expect(
        () => ComponentInstance(
          id: ComponentId('c-1'),
          modelType: ' ',
          terminals: const <Terminal>[],
        ),
        throwsA(isA<DomainException>()),
      );
    });

    test('source round-trip, disabled state and model validation', () {
      final SourceInstance source = SourceInstance(
        id: SourceId('s-1'),
        modelType: 'voltage.dc',
        terminals: <Terminal>[terminal('s-p', '+'), terminal('s-n', '-')],
        parameters: <String, Object?>{'voltage': 12},
        enabled: false,
      );
      expect(SourceInstance.fromJson(source.toJson()), source);
      expect(source.hashCode, SourceInstance.fromJson(source.toJson()).hashCode);
      expect(
        () => SourceInstance(
          id: SourceId('s-2'),
          modelType: '',
          terminals: const <Terminal>[],
        ),
        throwsA(isA<DomainException>()),
      );
    });

    test('source rejects duplicate terminal IDs', () {
      expect(
        () => SourceInstance(
          id: SourceId('s-2'),
          modelType: 'voltage.dc',
          terminals: <Terminal>[terminal('dup', '+'), terminal('dup', '-')],
        ),
        throwsA(isA<DomainException>()),
      );
    });

    test('connection round-trip and self-link rejection', () {
      final Connection connection = Connection(
        id: ConnectionId('w-1'),
        fromTerminalId: TerminalId('a'),
        toTerminalId: TerminalId('b'),
        conductorType: ConductorType.cable,
        phase: PhaseTag.l2,
        enabled: false,
        metadata: <String, Object?>{'gaugeMm2': 2.5},
      );
      expect(Connection.fromJson(connection.toJson()), connection);
      expect(connection.hashCode, Connection.fromJson(connection.toJson()).hashCode);
      expect(
        () => Connection(
          id: ConnectionId('bad'),
          fromTerminalId: TerminalId('a'),
          toTerminalId: TerminalId('a'),
        ),
        throwsA(isA<DomainException>().having(
          (DomainException e) => e.code,
          'code',
          DomainErrorCode.invalidTerminalReference,
        )),
      );
    });
  });

  group('CircuitState', () {
    test('full JSON round-trip is exact and deterministic', () {
      final CircuitState original = sampleCircuit();
      final String encoded1 = original.toJsonString();
      final CircuitState restored = CircuitState.fromJsonString(encoded1);
      final String encoded2 = restored.toJsonString();
      expect(restored, original);
      expect(restored.hashCode, original.hashCode);
      expect(encoded2, encoded1);
      expect((jsonDecode(encoded1) as Map<String, Object?>)['schemaVersion'], 1);
    });

    test('root lists and maps are immutable snapshots', () {
      final List<ComponentInstance> components = <ComponentInstance>[];
      final Map<String, Object?> metadata = <String, Object?>{'name': 'before'};
      final CircuitState state = CircuitState(
        circuitId: CircuitId('snapshot'),
        revision: 0,
        mode: ElectricalMode.dc,
        components: components,
        metadata: metadata,
      );
      components.add(
        ComponentInstance(
          id: ComponentId('late'),
          modelType: 'lamp',
          terminals: const <Terminal>[],
        ),
      );
      metadata['name'] = 'after';
      expect(state.components, isEmpty);
      expect(state.metadata['name'], 'before');
      expect(() => state.metadata['x'] = 1, throwsA(isA<UnsupportedError>()));
      expect(() => state.connections.add(sampleCircuit().connections.first), throwsA(isA<UnsupportedError>()));
    });

    test('negative revision is rejected', () {
      expect(
        () => CircuitState(
          circuitId: CircuitId('bad-revision'),
          revision: -1,
          mode: ElectricalMode.dc,
        ),
        throwsA(isA<DomainException>().having(
          (DomainException e) => e.code,
          'code',
          DomainErrorCode.invalidValue,
        )),
      );
    });

    test('duplicate component, source, terminal and connection IDs are rejected', () {
      final ComponentInstance a = ComponentInstance(
        id: ComponentId('same-component'),
        modelType: 'lamp',
        terminals: <Terminal>[terminal('a1', 'A')],
      );
      final ComponentInstance b = ComponentInstance(
        id: ComponentId('same-component'),
        modelType: 'switch',
        terminals: <Terminal>[terminal('b1', 'B')],
      );
      expect(
        () => CircuitState(
          circuitId: CircuitId('dup-component'),
          revision: 0,
          mode: ElectricalMode.dc,
          components: <ComponentInstance>[a, b],
        ),
        throwsA(isA<DomainException>().having(
          (DomainException e) => e.code,
          'code',
          DomainErrorCode.duplicateId,
        )),
      );

      final SourceInstance s1 = SourceInstance(
        id: SourceId('same-source'),
        modelType: 'dc',
        terminals: <Terminal>[terminal('s1a', 'A')],
      );
      final SourceInstance s2 = SourceInstance(
        id: SourceId('same-source'),
        modelType: 'dc',
        terminals: <Terminal>[terminal('s2a', 'A')],
      );
      expect(
        () => CircuitState(
          circuitId: CircuitId('dup-source'),
          revision: 0,
          mode: ElectricalMode.dc,
          sources: <SourceInstance>[s1, s2],
        ),
        throwsA(isA<DomainException>()),
      );

      final ComponentInstance c1 = ComponentInstance(
        id: ComponentId('c1'),
        modelType: 'a',
        terminals: <Terminal>[terminal('global-terminal', 'A')],
      );
      final SourceInstance c2 = SourceInstance(
        id: SourceId('s3'),
        modelType: 'b',
        terminals: <Terminal>[terminal('global-terminal', 'B')],
      );
      expect(
        () => CircuitState(
          circuitId: CircuitId('dup-terminal'),
          revision: 0,
          mode: ElectricalMode.dc,
          components: <ComponentInstance>[c1],
          sources: <SourceInstance>[c2],
        ),
        throwsA(isA<DomainException>()),
      );

      final Terminal ta = terminal('ta', 'A');
      final Terminal tb = terminal('tb', 'B');
      final ComponentInstance owner = ComponentInstance(
        id: ComponentId('owner'),
        modelType: 'wireable',
        terminals: <Terminal>[ta, tb],
      );
      final Connection w1 = Connection(
        id: ConnectionId('same-wire'),
        fromTerminalId: ta.id,
        toTerminalId: tb.id,
      );
      final Connection w2 = Connection(
        id: ConnectionId('same-wire'),
        fromTerminalId: tb.id,
        toTerminalId: ta.id,
      );
      expect(
        () => CircuitState(
          circuitId: CircuitId('dup-wire'),
          revision: 0,
          mode: ElectricalMode.dc,
          components: <ComponentInstance>[owner],
          connections: <Connection>[w1, w2],
        ),
        throwsA(isA<DomainException>()),
      );
    });

    test('connection cannot reference unknown terminals', () {
      expect(
        () => CircuitState(
          circuitId: CircuitId('unknown-terminal'),
          revision: 0,
          mode: ElectricalMode.dc,
          connections: <Connection>[
            Connection(
              id: ConnectionId('w'),
              fromTerminalId: TerminalId('missing-a'),
              toTerminalId: TerminalId('missing-b'),
            ),
          ],
        ),
        throwsA(isA<DomainException>().having(
          (DomainException e) => e.code,
          'code',
          DomainErrorCode.invalidTerminalReference,
        )),
      );
    });

    test('schema mismatch and non-object root are explicit errors', () {
      final Map<String, Object?> json = sampleCircuit().toJson();
      json['schemaVersion'] = 99;
      expect(
        () => CircuitState.fromJson(json),
        throwsA(isA<DomainException>().having(
          (DomainException e) => e.code,
          'code',
          DomainErrorCode.invalidSchemaVersion,
        )),
      );
      expect(
        () => CircuitState.fromJsonString('[1,2,3]'),
        throwsA(isA<DomainException>().having(
          (DomainException e) => e.code,
          'code',
          DomainErrorCode.invalidJsonValue,
        )),
      );
    });

    test('missing field and invalid JSON value are structured failures', () {
      expect(
        () => Terminal.fromJson(<String, Object?>{}),
        throwsA(isA<DomainException>().having(
          (DomainException e) => e.code,
          'code',
          DomainErrorCode.missingField,
        )),
      );
      expect(
        () => Terminal(
          id: TerminalId('bad-json'),
          name: 'A',
          metadata: <String, Object?>{'nan': double.infinity},
        ),
        throwsA(isA<DomainException>().having(
          (DomainException e) => e.code,
          'code',
          DomainErrorCode.invalidJsonValue,
        )),
      );
    });
  });

  test('DomainException string contains stable code name', () {
    final DomainException exception = DomainException(
      code: DomainErrorCode.invalidValue,
      message: 'x',
      context: <String, Object?>{'a': 1},
    );
    expect(exception.context['a'], 1);
    expect(exception.toString(), contains('invalidValue'));
  });
}
