import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:electrosim_topology/electrosim_topology.dart';
import 'package:test/test.dart';

void main() {
  const TopologyEngine engine = TopologyEngine();

  group('TopologyEngine canonical compilation', () {
    test('enabled conductors merge terminals into deterministic nodes', () {
      final CircuitState circuit = _simpleDcCircuit();
      final TopologyGraph graph = engine.compile(circuit);

      expect(graph.circuitId, circuit.circuitId);
      expect(graph.circuitRevision, circuit.revision);
      expect(graph.nodes, hasLength(2));
      expect(graph.enabledConnectionIds.map((ConnectionId id) => id.value), <String>['c1', 'c2']);
      expect(graph.disabledConnectionIds, isEmpty);
      expect(
        graph.nodeForTerminal(TerminalId('src_p')).terminalIds.map((TerminalId id) => id.value),
        <String>['r_a', 'src_p'],
      );
      expect(
        graph.nodeForTerminal(TerminalId('src_n')).terminalIds.map((TerminalId id) => id.value),
        <String>['r_b', 'src_n'],
      );
      expect(graph.findings, isEmpty);
    });

    test('connection input order does not change canonical topology', () {
      final CircuitState forward = _simpleDcCircuit();
      final CircuitState reversed = CircuitState(
        circuitId: forward.circuitId,
        revision: forward.revision,
        mode: forward.mode,
        components: forward.components,
        connections: forward.connections.reversed.toList(growable: false),
        sources: forward.sources,
      );

      final TopologyGraph a = engine.compile(forward);
      final TopologyGraph b = engine.compile(reversed);

      expect(_graphSignature(a), _graphSignature(b));
    });



    test('property-style conductor chains always collapse to one node', () {
      for (var length = 2; length <= 40; length++) {
        final List<Terminal> terminals = List<Terminal>.generate(
          length,
          (int index) => Terminal(id: TerminalId('t$index'), name: 'T$index'),
          growable: false,
        );
        final CircuitState circuit = CircuitState(
          circuitId: CircuitId('chain-$length'),
          revision: 0,
          mode: ElectricalMode.dc,
          components: <ComponentInstance>[
            ComponentInstance(
              id: ComponentId('bus'),
              modelType: 'test_bus',
              terminals: terminals,
            ),
          ],
          connections: List<Connection>.generate(
            length - 1,
            (int index) => Connection(
              id: ConnectionId('c$index'),
              fromTerminalId: TerminalId('t$index'),
              toTerminalId: TerminalId('t${index + 1}'),
            ),
            growable: false,
          ),
        );

        final TopologyGraph graph = engine.compile(circuit);
        expect(graph.nodes, hasLength(1), reason: 'chain length $length');
        expect(graph.nodes.single.terminalIds, hasLength(length));
      }
    });

    test('compile never mutates CircuitState', () {
      final CircuitState circuit = _simpleDcCircuit();
      final String before = circuit.toJsonString();

      engine.compile(circuit);

      expect(circuit.toJsonString(), before);
    });
  });

  group('TopologyEngine pre-solve findings', () {
    test('disabled conductor is excluded and reported explicitly', () {
      final CircuitState base = _simpleDcCircuit();
      final CircuitState circuit = CircuitState(
        circuitId: base.circuitId,
        revision: 2,
        mode: base.mode,
        components: base.components,
        connections: <Connection>[
          base.connections.first,
          Connection(
            id: ConnectionId('c2'),
            fromTerminalId: TerminalId('src_n'),
            toTerminalId: TerminalId('r_b'),
            phase: PhaseTag.dcNegative,
            enabled: false,
          ),
        ],
        sources: base.sources,
      );

      final TopologyGraph graph = engine.compile(circuit);

      expect(graph.nodes, hasLength(3));
      expect(graph.disabledConnectionIds.map((ConnectionId id) => id.value), <String>['c2']);
      expect(
        graph.findings.where((TopologyFinding f) => f.code == TopologyFindingCode.disabledConnection),
        hasLength(1),
      );
      expect(
        graph.findings.where((TopologyFinding f) => f.code == TopologyFindingCode.floatingNode),
        hasLength(2),
      );
    });

    test('fully unwired component is isolated and its terminal nodes float', () {
      final CircuitState circuit = CircuitState(
        circuitId: CircuitId('isolated'),
        revision: 0,
        mode: ElectricalMode.dc,
        components: <ComponentInstance>[
          ComponentInstance(
            id: ComponentId('lamp'),
            modelType: 'lamp',
            terminals: <Terminal>[
              Terminal(id: TerminalId('lamp_a'), name: 'A'),
              Terminal(id: TerminalId('lamp_b'), name: 'B'),
            ],
          ),
        ],
      );

      final TopologyGraph graph = engine.compile(circuit);

      expect(graph.nodes, hasLength(2));
      expect(
        graph.findings.where((TopologyFinding f) => f.code == TopologyFindingCode.isolatedComponent),
        hasLength(1),
      );
      expect(
        graph.findings.where((TopologyFinding f) => f.code == TopologyFindingCode.floatingNode),
        hasLength(2),
      );
    });

    test('merging incompatible phase tags is a blocking topology finding', () {
      final CircuitState circuit = CircuitState(
        circuitId: CircuitId('phase-conflict'),
        revision: 0,
        mode: ElectricalMode.ac3,
        components: <ComponentInstance>[
          ComponentInstance(
            id: ComponentId('load'),
            modelType: 'load',
            terminals: <Terminal>[
              Terminal(
                id: TerminalId('load_l2'),
                name: 'L2',
                role: TerminalRole.phaseL2,
                phase: PhaseTag.l2,
              ),
            ],
          ),
        ],
        connections: <Connection>[
          Connection(
            id: ConnectionId('bad-wire'),
            fromTerminalId: TerminalId('src_l1'),
            toTerminalId: TerminalId('load_l2'),
            phase: PhaseTag.l1,
          ),
        ],
        sources: <SourceInstance>[
          SourceInstance(
            id: SourceId('grid'),
            modelType: 'ac3_source',
            terminals: <Terminal>[
              Terminal(
                id: TerminalId('src_l1'),
                name: 'L1',
                role: TerminalRole.phaseL1,
                phase: PhaseTag.l1,
              ),
            ],
          ),
        ],
      );

      final TopologyGraph graph = engine.compile(circuit);
      final TopologyFinding finding = graph.findings.singleWhere(
        (TopologyFinding f) => f.code == TopologyFindingCode.conflictingPhases,
      );

      expect(finding.severity, TopologyFindingSeverity.error);
      expect(finding.terminalIds.map((TerminalId id) => id.value), <String>['load_l2', 'src_l1']);
    });

    test('unwired source is isolated and explicit', () {
      final CircuitState circuit = CircuitState(
        circuitId: CircuitId('source-only'),
        revision: 0,
        mode: ElectricalMode.dc,
        sources: <SourceInstance>[
          SourceInstance(
            id: SourceId('battery'),
            modelType: 'dc_source',
            terminals: <Terminal>[
              Terminal(id: TerminalId('p'), name: '+', phase: PhaseTag.dcPositive),
              Terminal(id: TerminalId('n'), name: '-', phase: PhaseTag.dcNegative),
            ],
          ),
        ],
      );

      final TopologyGraph graph = engine.compile(circuit);
      expect(
        graph.findings.where((TopologyFinding f) => f.code == TopologyFindingCode.isolatedSource),
        hasLength(1),
      );
    });
  });

  group('TopologyGraph immutability', () {
    test('public collections cannot be mutated', () {
      final TopologyGraph graph = engine.compile(_simpleDcCircuit());

      expect(() => graph.nodes.add(graph.nodes.first), throwsUnsupportedError);
      expect(
        () => graph.terminalToNode[TerminalId('src_p')] = 'tampered',
        throwsUnsupportedError,
      );
      expect(
        () => graph.componentNodeIds[ComponentId('r1')]!.add('tampered'),
        throwsUnsupportedError,
      );
    });
  });
}

CircuitState _simpleDcCircuit() => CircuitState(
  circuitId: CircuitId('dc-simple'),
  revision: 1,
  mode: ElectricalMode.dc,
  components: <ComponentInstance>[
    ComponentInstance(
      id: ComponentId('r1'),
      modelType: 'resistor',
      terminals: <Terminal>[
        Terminal(id: TerminalId('r_a'), name: 'A'),
        Terminal(id: TerminalId('r_b'), name: 'B'),
      ],
      parameters: <String, Object?>{'resistanceOhm': 12.0},
    ),
  ],
  connections: <Connection>[
    Connection(
      id: ConnectionId('c1'),
      fromTerminalId: TerminalId('src_p'),
      toTerminalId: TerminalId('r_a'),
      phase: PhaseTag.dcPositive,
    ),
    Connection(
      id: ConnectionId('c2'),
      fromTerminalId: TerminalId('src_n'),
      toTerminalId: TerminalId('r_b'),
      phase: PhaseTag.dcNegative,
    ),
  ],
  sources: <SourceInstance>[
    SourceInstance(
      id: SourceId('src'),
      modelType: 'dc_voltage_source',
      terminals: <Terminal>[
        Terminal(
          id: TerminalId('src_p'),
          name: '+',
          role: TerminalRole.positive,
          phase: PhaseTag.dcPositive,
        ),
        Terminal(
          id: TerminalId('src_n'),
          name: '-',
          role: TerminalRole.negative,
          phase: PhaseTag.dcNegative,
        ),
      ],
      parameters: <String, Object?>{'voltageV': 24.0},
    ),
  ],
);

String _graphSignature(TopologyGraph graph) {
  final String nodes = graph.nodes
      .map(
        (TopologyNode node) =>
            '${node.id}=[${node.terminalIds.map((TerminalId id) => id.value).join(',')}]',
      )
      .join('|');
  final String enabled = graph.enabledConnectionIds.map((ConnectionId id) => id.value).join(',');
  final String findings = graph.findings
      .map((TopologyFinding f) => '${f.code.name}:${f.nodeId ?? ''}:${f.connectionId?.value ?? ''}')
      .join('|');
  return '$nodes#$enabled#$findings';
}
