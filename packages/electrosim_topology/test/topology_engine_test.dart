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
      expect(
        graph.enabledConnectionIds.map((ConnectionId id) => id.value),
        <String>['c1', 'c2'],
      );
      expect(graph.disabledConnectionIds, isEmpty);
      expect(
        graph
            .nodeForTerminal(TerminalId('src_p'))
            .terminalIds
            .map((TerminalId id) => id.value),
        <String>['r_a', 'src_p'],
      );
      expect(
        graph
            .nodeForTerminal(TerminalId('src_n'))
            .terminalIds
            .map((TerminalId id) => id.value),
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

    test('AC3 four-wire source neutral may remain unused with a delta load', () {
      final CircuitState circuit = CircuitState(
        circuitId: CircuitId('ac3-delta-no-neutral'),
        revision: 0,
        mode: ElectricalMode.ac3,
        sources: <SourceInstance>[
          SourceInstance(
            id: SourceId('grid'),
            modelType: 'ac3_voltage_source',
            terminals: <Terminal>[
              Terminal(id: TerminalId('grid-l1'), name: 'L1', role: TerminalRole.phaseL1, phase: PhaseTag.l1),
              Terminal(id: TerminalId('grid-l2'), name: 'L2', role: TerminalRole.phaseL2, phase: PhaseTag.l2),
              Terminal(id: TerminalId('grid-l3'), name: 'L3', role: TerminalRole.phaseL3, phase: PhaseTag.l3),
              Terminal(id: TerminalId('grid-n'), name: 'N', role: TerminalRole.neutral, phase: PhaseTag.neutral),
            ],
            parameters: const <String, Object?>{'phaseVoltageRmsV': 230.0},
          ),
        ],
        components: <ComponentInstance>[
          ComponentInstance(
            id: ComponentId('delta'),
            modelType: 'load_delta_3p',
            terminals: <Terminal>[
              Terminal(id: TerminalId('d-l1'), name: 'L1', phase: PhaseTag.l1),
              Terminal(id: TerminalId('d-l2'), name: 'L2', phase: PhaseTag.l2),
              Terminal(id: TerminalId('d-l3'), name: 'L3', phase: PhaseTag.l3),
            ],
            parameters: const <String, Object?>{'resistanceOhm': 80.0, 'inductanceH': 0.0},
          ),
        ],
        connections: <Connection>[
          Connection(id: ConnectionId('l1'), fromTerminalId: TerminalId('grid-l1'), toTerminalId: TerminalId('d-l1')),
          Connection(id: ConnectionId('l2'), fromTerminalId: TerminalId('grid-l2'), toTerminalId: TerminalId('d-l2')),
          Connection(id: ConnectionId('l3'), fromTerminalId: TerminalId('grid-l3'), toTerminalId: TerminalId('d-l3')),
        ],
        settings: const <String, Object?>{'frequencyHz': 50.0},
      );

      final TopologyGraph graph = engine.compile(circuit);
      expect(
        graph.findings.where(
          (TopologyFinding finding) =>
              finding.code == TopologyFindingCode.floatingNode &&
              finding.terminalIds.contains(TerminalId('grid-n')),
        ),
        isEmpty,
      );
      expect(
        graph.findings.where(
          (TopologyFinding finding) =>
              finding.code == TopologyFindingCode.conflictingPhases,
        ),
        isEmpty,
      );
    });

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
      expect(
        graph.disabledConnectionIds.map((ConnectionId id) => id.value),
        <String>['c2'],
      );
      expect(
        graph.findings.where(
          (TopologyFinding f) =>
              f.code == TopologyFindingCode.disabledConnection,
        ),
        hasLength(1),
      );
      expect(
        graph.findings.where(
          (TopologyFinding f) => f.code == TopologyFindingCode.floatingNode,
        ),
        hasLength(2),
      );
    });

    test(
      'fully unwired component is isolated and its terminal nodes float',
      () {
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
          graph.findings.where(
            (TopologyFinding f) =>
                f.code == TopologyFindingCode.isolatedComponent,
          ),
          hasLength(1),
        );
        expect(
          graph.findings.where(
            (TopologyFinding f) => f.code == TopologyFindingCode.floatingNode,
          ),
          hasLength(2),
        );
      },
    );

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
      expect(finding.terminalIds.map((TerminalId id) => id.value), <String>[
        'load_l2',
        'src_l1',
      ]);
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
              Terminal(
                id: TerminalId('p'),
                name: '+',
                phase: PhaseTag.dcPositive,
              ),
              Terminal(
                id: TerminalId('n'),
                name: '-',
                phase: PhaseTag.dcNegative,
              ),
            ],
          ),
        ],
      );

      final TopologyGraph graph = engine.compile(circuit);
      expect(
        graph.findings.where(
          (TopologyFinding f) => f.code == TopologyFindingCode.isolatedSource,
        ),
        hasLength(1),
      );
    });
  });

  group('TopologyEngine component branch projection', () {
    test(
      'three-phase contactor projects three power poles and one coil without merging nodes',
      () {
        final ComponentInstance contactor = ComponentInstance(
          id: ComponentId('km1'),
          modelType: 'contactor_3p',
          terminals: <Terminal>[
            Terminal(
              id: TerminalId('km_l1'),
              name: 'L1',
              role: TerminalRole.lineL1,
              phase: PhaseTag.l1,
            ),
            Terminal(
              id: TerminalId('km_l2'),
              name: 'L2',
              role: TerminalRole.lineL2,
              phase: PhaseTag.l2,
            ),
            Terminal(
              id: TerminalId('km_l3'),
              name: 'L3',
              role: TerminalRole.lineL3,
              phase: PhaseTag.l3,
            ),
            Terminal(
              id: TerminalId('km_t1'),
              name: 'T1',
              role: TerminalRole.loadT1,
              phase: PhaseTag.l1,
            ),
            Terminal(
              id: TerminalId('km_t2'),
              name: 'T2',
              role: TerminalRole.loadT2,
              phase: PhaseTag.l2,
            ),
            Terminal(
              id: TerminalId('km_t3'),
              name: 'T3',
              role: TerminalRole.loadT3,
              phase: PhaseTag.l3,
            ),
            Terminal(
              id: TerminalId('km_a1'),
              name: 'A1',
              role: TerminalRole.coilA1,
            ),
            Terminal(
              id: TerminalId('km_a2'),
              name: 'A2',
              role: TerminalRole.coilA2,
            ),
          ],
        );
        final CircuitState circuit = CircuitState(
          circuitId: CircuitId('contactor-topology'),
          revision: 0,
          mode: ElectricalMode.ac3,
          components: <ComponentInstance>[contactor],
        );

        final TopologyGraph graph = engine.compile(circuit);
        final List<TopologyBranch> branches = graph.branchesForComponent(
          ComponentId('km1'),
        );

        expect(branches, hasLength(4));
        expect(
          branches.where(
            (TopologyBranch branch) =>
                branch.role == ElectricalBranchRole.powerPole,
          ),
          hasLength(3),
        );
        expect(
          branches.where(
            (TopologyBranch branch) =>
                branch.role == ElectricalBranchRole.controlCoil,
          ),
          hasLength(1),
        );
        expect(
          graph.nodeForTerminal(TerminalId('km_l1')).id,
          isNot(graph.nodeForTerminal(TerminalId('km_t1')).id),
          reason:
              'A structural component branch must not be collapsed into a conductor node.',
        );
        final TopologyBranch coil = branches.singleWhere(
          (TopologyBranch branch) =>
              branch.role == ElectricalBranchRole.controlCoil,
        );
        expect(coil.fromTerminalId, TerminalId('km_a1'));
        expect(coil.toTerminalId, TerminalId('km_a2'));
      },
    );

    test('three-pole breaker preserves independent phase paths', () {
      final CircuitState circuit = CircuitState(
        circuitId: CircuitId('breaker-topology'),
        revision: 0,
        mode: ElectricalMode.ac3,
        components: <ComponentInstance>[
          ComponentInstance(
            id: ComponentId('q1'),
            modelType: 'breaker_3p',
            terminals: <Terminal>[
              Terminal(id: TerminalId('q_l1'), name: 'L1'),
              Terminal(id: TerminalId('q_l2'), name: 'L2'),
              Terminal(id: TerminalId('q_l3'), name: 'L3'),
              Terminal(id: TerminalId('q_t1'), name: 'T1'),
              Terminal(id: TerminalId('q_t2'), name: 'T2'),
              Terminal(id: TerminalId('q_t3'), name: 'T3'),
            ],
          ),
        ],
      );

      final List<TopologyBranch> branches = engine
          .compile(circuit)
          .branchesForComponent(ComponentId('q1'));
      expect(branches, hasLength(3));
      expect(branches.map((TopologyBranch b) => b.poleIndex).toSet(), <int?>{
        0,
        1,
        2,
      });
      expect(
        branches
            .map(
              (TopologyBranch b) =>
                  '${b.fromTerminalId.value}>${b.toTerminalId.value}',
            )
            .toSet(),
        <String>{'q_l1>q_t1', 'q_l2>q_t2', 'q_l3>q_t3'},
      );
    });

    test(
      'contract mismatch is an explicit blocking finding instead of an index failure',
      () {
        final CircuitState circuit = CircuitState(
          circuitId: CircuitId('bad-contactor-shape'),
          revision: 0,
          mode: ElectricalMode.ac3,
          components: <ComponentInstance>[
            ComponentInstance(
              id: ComponentId('km-bad'),
              modelType: 'contactor_3p',
              terminals: <Terminal>[
                Terminal(id: TerminalId('only-a'), name: 'A'),
                Terminal(id: TerminalId('only-b'), name: 'B'),
              ],
            ),
          ],
        );

        final TopologyGraph graph = engine.compile(circuit);
        final TopologyFinding finding = graph.findings.singleWhere(
          (TopologyFinding f) =>
              f.code == TopologyFindingCode.componentContractMismatch,
        );
        expect(finding.severity, TopologyFindingSeverity.error);
        expect(graph.branchesForComponent(ComponentId('km-bad')), isEmpty);
      },
    );

    test(
      'canonical model used in the wrong electrical mode is reported explicitly',
      () {
        final CircuitState circuit = CircuitState(
          circuitId: CircuitId('wrong-mode'),
          revision: 0,
          mode: ElectricalMode.dc,
          components: <ComponentInstance>[
            ComponentInstance(
              id: ComponentId('q3'),
              modelType: 'breaker_3p',
              terminals: <Terminal>[
                for (var i = 0; i < 6; i++)
                  Terminal(id: TerminalId('q3_$i'), name: 'T$i'),
              ],
            ),
          ],
        );

        final TopologyGraph graph = engine.compile(circuit);
        expect(
          graph.findings.where(
            (TopologyFinding f) =>
                f.code == TopologyFindingCode.componentModeMismatch,
          ),
          hasLength(1),
        );
        expect(graph.branchesForComponent(ComponentId('q3')), hasLength(3));
      },
    );

    test(
      'custom registry can project a model without changing the topology engine',
      () {
        final ComponentModelRegistry registry = ComponentModelRegistry(
          <ComponentModelContract>[
            ComponentModelContract(
              modelType: 'custom_two_terminal',
              family: ComponentFamily.other,
              terminalCount: 2,
              supportedModes: <ElectricalMode>{ElectricalMode.dc},
              branches: <ComponentBranchDefinition>[
                ComponentBranchDefinition(
                  id: 'custom',
                  fromTerminalIndex: 0,
                  toTerminalIndex: 1,
                  role: ElectricalBranchRole.main,
                ),
              ],
            ),
          ],
        );
        final TopologyEngine customEngine = TopologyEngine(
          modelRegistry: registry,
        );
        final CircuitState circuit = CircuitState(
          circuitId: CircuitId('custom-contract'),
          revision: 0,
          mode: ElectricalMode.dc,
          components: <ComponentInstance>[
            ComponentInstance(
              id: ComponentId('x1'),
              modelType: 'custom_two_terminal',
              terminals: <Terminal>[
                Terminal(id: TerminalId('x_a'), name: 'A'),
                Terminal(id: TerminalId('x_b'), name: 'B'),
              ],
            ),
          ],
        );

        expect(
          customEngine.compile(circuit).branchesForComponent(ComponentId('x1')),
          hasLength(1),
        );
      },
    );
  });

  test('DC series-source junction may merge positive and negative terminals', () {
    final CircuitState circuit = CircuitState(
      circuitId: CircuitId('dc-series-source-junction'),
      revision: 0,
      mode: ElectricalMode.dc,
      connections: <Connection>[
        Connection(
          id: ConnectionId('series-link'),
          fromTerminalId: TerminalId('v1p'),
          toTerminalId: TerminalId('v2n'),
        ),
      ],
      sources: <SourceInstance>[
        SourceInstance(
          id: SourceId('v1'),
          modelType: 'dc_voltage_source',
          terminals: <Terminal>[
            Terminal(
              id: TerminalId('v1p'),
              name: '+',
              phase: PhaseTag.dcPositive,
            ),
            Terminal(
              id: TerminalId('v1n'),
              name: '-',
              phase: PhaseTag.dcNegative,
            ),
          ],
          parameters: const <String, Object?>{'voltageV': 24.0},
        ),
        SourceInstance(
          id: SourceId('v2'),
          modelType: 'dc_voltage_source',
          terminals: <Terminal>[
            Terminal(
              id: TerminalId('v2p'),
              name: '+',
              phase: PhaseTag.dcPositive,
            ),
            Terminal(
              id: TerminalId('v2n'),
              name: '-',
              phase: PhaseTag.dcNegative,
            ),
          ],
          parameters: const <String, Object?>{'voltageV': 12.0},
        ),
      ],
    );

    final TopologyGraph graph = const TopologyEngine().compile(circuit);
    expect(
      graph.findings.where(
        (TopologyFinding finding) =>
            finding.code == TopologyFindingCode.conflictingPhases,
      ),
      isEmpty,
    );
    expect(graph.nodeForTerminal(TerminalId('v1p')), graph.nodeForTerminal(TerminalId('v2n')));
  });

  test('zero-volt DC source on one node is redundant, not a topology error', () {
    final CircuitState circuit = CircuitState(
      circuitId: CircuitId('zero-volt-redundant-topology'),
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
          terminals: <Terminal>[
            Terminal(id: TerminalId('z1'), name: 'A'),
            Terminal(id: TerminalId('z2'), name: 'B'),
          ],
          parameters: const <String, Object?>{'voltageV': 0.0},
        ),
      ],
    );

    final TopologyGraph graph = const TopologyEngine().compile(circuit);
    expect(
      graph.findings.where(
        (TopologyFinding finding) =>
            finding.code == TopologyFindingCode.conflictingPhases,
      ),
      isEmpty,
    );
  });

  test(
    'current-limited DC source direct short is warning not topology error',
    () {
      final CircuitState circuit = CircuitState(
        circuitId: CircuitId('limited-direct-short-topology'),
        revision: 0,
        mode: ElectricalMode.dc,
        connections: <Connection>[
          Connection(
            id: ConnectionId('short'),
            fromTerminalId: TerminalId('vp'),
            toTerminalId: TerminalId('vn'),
          ),
        ],
        sources: <SourceInstance>[
          SourceInstance(
            id: SourceId('v1'),
            modelType: 'dc_voltage_source',
            terminals: <Terminal>[
              Terminal(
                id: TerminalId('vp'),
                name: '+',
                phase: PhaseTag.dcPositive,
              ),
              Terminal(
                id: TerminalId('vn'),
                name: '-',
                phase: PhaseTag.dcNegative,
              ),
            ],
            parameters: const <String, Object?>{
              'voltageV': 24.0,
              'currentLimitA': 5.0,
            },
          ),
        ],
      );

      final TopologyGraph graph = const TopologyEngine().compile(circuit);
      final Iterable<TopologyFinding> conflicts = graph.findings.where(
        (TopologyFinding finding) =>
            finding.code == TopologyFindingCode.conflictingPhases,
      );
      expect(conflicts, isNotEmpty);
      expect(
        conflicts.every(
          (TopologyFinding finding) =>
              finding.severity == TopologyFindingSeverity.warning,
        ),
        isTrue,
      );
    },
  );

  test('ideal DC source direct short remains a topology error', () {
    final CircuitState circuit = CircuitState(
      circuitId: CircuitId('ideal-direct-short-topology'),
      revision: 0,
      mode: ElectricalMode.dc,
      connections: <Connection>[
        Connection(
          id: ConnectionId('short'),
          fromTerminalId: TerminalId('vp'),
          toTerminalId: TerminalId('vn'),
        ),
      ],
      sources: <SourceInstance>[
        SourceInstance(
          id: SourceId('v1'),
          modelType: 'dc_voltage_source',
          terminals: <Terminal>[
            Terminal(
              id: TerminalId('vp'),
              name: '+',
              phase: PhaseTag.dcPositive,
            ),
            Terminal(
              id: TerminalId('vn'),
              name: '-',
              phase: PhaseTag.dcNegative,
            ),
          ],
          parameters: const <String, Object?>{'voltageV': 24.0},
        ),
      ],
    );

    final TopologyGraph graph = const TopologyEngine().compile(circuit);
    expect(
      graph.findings.any(
        (TopologyFinding finding) =>
            finding.code == TopologyFindingCode.conflictingPhases &&
            finding.severity == TopologyFindingSeverity.error,
      ),
      isTrue,
    );
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
  final String enabled = graph.enabledConnectionIds
      .map((ConnectionId id) => id.value)
      .join(',');
  final String findings = graph.findings
      .map(
        (TopologyFinding f) =>
            '${f.code.name}:${f.nodeId ?? ''}:${f.connectionId?.value ?? ''}',
      )
      .join('|');
  return '$nodes#$enabled#$findings';
}
