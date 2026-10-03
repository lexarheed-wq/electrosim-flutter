import 'package:electrosim_domain/electrosim_domain.dart';

import 'topology_finding.dart';
import 'topology_graph.dart';

final class TopologyEngine {
  const TopologyEngine({ComponentModelRegistry? modelRegistry}) : _modelRegistry = modelRegistry;

  final ComponentModelRegistry? _modelRegistry;

  ComponentModelRegistry get _contracts => _modelRegistry ?? CoreComponentModelContracts.registry;

  TopologyGraph compile(CircuitState circuit) {
    final List<Terminal> terminals = <Terminal>[
      for (final ComponentInstance component in circuit.components) ...component.terminals,
      for (final SourceInstance source in circuit.sources) ...source.terminals,
    ]..sort((Terminal a, Terminal b) => a.id.value.compareTo(b.id.value));

    final Map<TerminalId, Terminal> terminalById = <TerminalId, Terminal>{
      for (final Terminal terminal in terminals) terminal.id: terminal,
    };
    final _UnionFind unionFind = _UnionFind(terminals.map((Terminal t) => t.id));

    final List<Connection> enabledConnections = circuit.connections
        .where((Connection connection) => connection.enabled)
        .toList(growable: false)
      ..sort((Connection a, Connection b) => a.id.value.compareTo(b.id.value));
    final List<Connection> disabledConnections = circuit.connections
        .where((Connection connection) => !connection.enabled)
        .toList(growable: false)
      ..sort((Connection a, Connection b) => a.id.value.compareTo(b.id.value));

    for (final Connection connection in enabledConnections) {
      unionFind.union(connection.fromTerminalId, connection.toTerminalId);
    }

    final Map<TerminalId, List<TerminalId>> groups = <TerminalId, List<TerminalId>>{};
    for (final Terminal terminal in terminals) {
      final TerminalId root = unionFind.find(terminal.id);
      groups.putIfAbsent(root, () => <TerminalId>[]).add(terminal.id);
    }

    final List<List<TerminalId>> canonicalGroups = groups.values.toList(growable: false)
      ..sort((List<TerminalId> a, List<TerminalId> b) {
        final String aFirst = _sortedTerminalIds(a).first.value;
        final String bFirst = _sortedTerminalIds(b).first.value;
        return aFirst.compareTo(bFirst);
      });

    final List<TopologyNode> nodes = <TopologyNode>[];
    final Map<TerminalId, String> terminalToNode = <TerminalId, String>{};
    for (final List<TerminalId> group in canonicalGroups) {
      final List<TerminalId> sorted = _sortedTerminalIds(group);
      final String nodeId = 'node:${sorted.first.value}';
      final TopologyNode node = TopologyNode(id: nodeId, terminalIds: sorted);
      nodes.add(node);
      for (final TerminalId terminalId in sorted) {
        terminalToNode[terminalId] = nodeId;
      }
    }

    final Map<TerminalId, int> enabledConnectionDegree = <TerminalId, int>{
      for (final Terminal terminal in terminals) terminal.id: 0,
    };
    for (final Connection connection in enabledConnections) {
      enabledConnectionDegree[connection.fromTerminalId] =
          enabledConnectionDegree[connection.fromTerminalId]! + 1;
      enabledConnectionDegree[connection.toTerminalId] =
          enabledConnectionDegree[connection.toTerminalId]! + 1;
    }

    final Map<ComponentId, List<String>> componentNodeIds = <ComponentId, List<String>>{};
    for (final ComponentInstance component in circuit.components) {
      componentNodeIds[component.id] = _ownerNodes(component.terminals, terminalToNode);
    }
    final Map<SourceId, List<String>> sourceNodeIds = <SourceId, List<String>>{};
    for (final SourceInstance source in circuit.sources) {
      sourceNodeIds[source.id] = _ownerNodes(source.terminals, terminalToNode);
    }

    final List<TopologyFinding> findings = <TopologyFinding>[];
    final List<TopologyBranch> componentBranches = <TopologyBranch>[];
    for (final ComponentInstance component in circuit.components) {
      final ComponentModelContract? contract = _contracts.resolve(component.modelType);
      if (contract == null) {
        continue;
      }
      if (!contract.supportsMode(circuit.mode)) {
        findings.add(
          TopologyFinding(
            code: TopologyFindingCode.componentModeMismatch,
            severity: TopologyFindingSeverity.error,
            message: 'Component ${component.id.value} (${component.modelType}) does not support '
                'electrical mode ${circuit.mode.name}.',
            componentId: component.id,
            terminalIds: component.terminals.map((Terminal t) => t.id).toList(growable: false),
          ),
        );
      }
      if (component.terminals.length != contract.terminalCount) {
        findings.add(
          TopologyFinding(
            code: TopologyFindingCode.componentContractMismatch,
            severity: TopologyFindingSeverity.error,
            message: 'Component ${component.id.value} (${component.modelType}) has '
                '${component.terminals.length} terminals but its canonical contract requires '
                '${contract.terminalCount}.',
            componentId: component.id,
            terminalIds: component.terminals.map((Terminal t) => t.id).toList(growable: false),
          ),
        );
        continue;
      }
      for (final ComponentBranchDefinition definition in contract.branches) {
        final Terminal fromTerminal = component.terminals[definition.fromTerminalIndex];
        final Terminal toTerminal = component.terminals[definition.toTerminalIndex];
        componentBranches.add(
          TopologyBranch(
            componentId: component.id,
            branchId: definition.id,
            role: definition.role,
            fromTerminalId: fromTerminal.id,
            toTerminalId: toTerminal.id,
            fromNodeId: terminalToNode[fromTerminal.id]!,
            toNodeId: terminalToNode[toTerminal.id]!,
            poleIndex: definition.poleIndex,
          ),
        );
      }
    }
    componentBranches.sort(_compareBranches);
    for (final Connection connection in disabledConnections) {
      findings.add(
        TopologyFinding(
          code: TopologyFindingCode.disabledConnection,
          severity: TopologyFindingSeverity.info,
          message: 'Connection ${connection.id.value} is disabled and does not merge nodes.',
          connectionId: connection.id,
          terminalIds: <TerminalId>[connection.fromTerminalId, connection.toTerminalId],
        ),
      );
    }

    for (final TopologyNode node in nodes) {
      final bool hasEnabledConductor = node.terminalIds.any(
        (TerminalId id) => enabledConnectionDegree[id]! > 0,
      );
      if (!hasEnabledConductor) {
        findings.add(
          TopologyFinding(
            code: TopologyFindingCode.floatingNode,
            severity: TopologyFindingSeverity.warning,
            message: 'Node ${node.id} is not connected by any enabled conductor.',
            nodeId: node.id,
            terminalIds: node.terminalIds,
          ),
        );
      }

      final Set<PhaseTag> phases = <PhaseTag>{
        for (final TerminalId id in node.terminalIds)
          if (terminalById[id]!.phase != PhaseTag.none) terminalById[id]!.phase,
      };
      if (_hasConflictingPhases(phases)) {
        final bool allowedLimitedDcShort = _isLimitedDcSourceShortNode(
          circuit,
          node,
        );
        findings.add(
          TopologyFinding(
            code: TopologyFindingCode.conflictingPhases,
            severity: allowedLimitedDcShort
                ? TopologyFindingSeverity.warning
                : TopologyFindingSeverity.error,
            message: allowedLimitedDcShort
                ? 'Node ${node.id} directly shorts a current-limited DC source; solver current limiting is required.'
                : 'Node ${node.id} merges incompatible phase/polarity tags.',
            nodeId: node.id,
            terminalIds: node.terminalIds,
          ),
        );
      }
    }

    for (final ComponentInstance component in circuit.components) {
      if (_ownerIsIsolated(component.terminals, enabledConnectionDegree)) {
        findings.add(
          TopologyFinding(
            code: TopologyFindingCode.isolatedComponent,
            severity: TopologyFindingSeverity.warning,
            message: 'Component ${component.id.value} has no terminal on an enabled conductor.',
            componentId: component.id,
            terminalIds: component.terminals.map((Terminal t) => t.id).toList(growable: false),
          ),
        );
      }
    }
    for (final SourceInstance source in circuit.sources) {
      if (_ownerIsIsolated(source.terminals, enabledConnectionDegree)) {
        findings.add(
          TopologyFinding(
            code: TopologyFindingCode.isolatedSource,
            severity: TopologyFindingSeverity.warning,
            message: 'Source ${source.id.value} has no terminal on an enabled conductor.',
            sourceId: source.id,
            terminalIds: source.terminals.map((Terminal t) => t.id).toList(growable: false),
          ),
        );
      }
    }

    findings.sort(_compareFindings);
    return TopologyGraph(
      circuitId: circuit.circuitId,
      circuitRevision: circuit.revision,
      mode: circuit.mode,
      nodes: nodes,
      terminalToNode: terminalToNode,
      enabledConnectionIds: enabledConnections.map((Connection c) => c.id),
      disabledConnectionIds: disabledConnections.map((Connection c) => c.id),
      componentNodeIds: componentNodeIds,
      sourceNodeIds: sourceNodeIds,
      componentBranches: componentBranches,
      findings: findings,
    );
  }
}

List<TerminalId> _sortedTerminalIds(Iterable<TerminalId> ids) => ids.toList(growable: false)
  ..sort((TerminalId a, TerminalId b) => a.value.compareTo(b.value));

List<String> _ownerNodes(
  Iterable<Terminal> terminals,
  Map<TerminalId, String> terminalToNode,
) {
  final Set<String> ids = <String>{
    for (final Terminal terminal in terminals) terminalToNode[terminal.id]!,
  };
  final List<String> result = ids.toList(growable: false)..sort();
  return result;
}

bool _ownerIsIsolated(
  Iterable<Terminal> terminals,
  Map<TerminalId, int> enabledConnectionDegree,
) => terminals.every((Terminal terminal) => enabledConnectionDegree[terminal.id] == 0);

bool _isLimitedDcSourceShortNode(
  CircuitState circuit,
  TopologyNode node,
) {
  if (circuit.mode != ElectricalMode.dc) {
    return false;
  }
  final Set<TerminalId> nodeTerminals = node.terminalIds.toSet();
  for (final SourceInstance source in circuit.sources) {
    if (!source.enabled ||
        (source.modelType != 'dc_voltage_source' &&
            source.modelType != 'voltage_source') ||
        source.terminals.length != 2) {
      continue;
    }
    final Object? rawLimit = source.parameters['currentLimitA'];
    if (rawLimit is! num ||
        !rawLimit.toDouble().isFinite ||
        rawLimit.toDouble() <= 0.0) {
      continue;
    }
    if (nodeTerminals.contains(source.terminals[0].id) &&
        nodeTerminals.contains(source.terminals[1].id)) {
      return true;
    }
  }
  return false;
}

bool _hasConflictingPhases(Set<PhaseTag> phases) {
  if (phases.length < 2) {
    return false;
  }
  final Set<PhaseTag> active = phases.difference(<PhaseTag>{PhaseTag.protectiveEarth});
  if (active.length < 2) {
    return false;
  }
  return true;
}

int _compareBranches(TopologyBranch a, TopologyBranch b) {
  final int component = a.componentId.value.compareTo(b.componentId.value);
  if (component != 0) {
    return component;
  }
  return a.branchId.compareTo(b.branchId);
}

int _compareFindings(TopologyFinding a, TopologyFinding b) {
  final int code = a.code.name.compareTo(b.code.name);
  if (code != 0) {
    return code;
  }
  final String aKey = a.nodeId ??
      a.connectionId?.value ??
      a.componentId?.value ??
      a.sourceId?.value ??
      '';
  final String bKey = b.nodeId ??
      b.connectionId?.value ??
      b.componentId?.value ??
      b.sourceId?.value ??
      '';
  return aKey.compareTo(bKey);
}

final class _UnionFind {
  _UnionFind(Iterable<TerminalId> ids)
    : _parent = <TerminalId, TerminalId>{for (final TerminalId id in ids) id: id};

  final Map<TerminalId, TerminalId> _parent;

  TerminalId find(TerminalId id) {
    final TerminalId parent = _parent[id]!;
    if (parent == id) {
      return id;
    }
    final TerminalId root = find(parent);
    _parent[id] = root;
    return root;
  }

  void union(TerminalId a, TerminalId b) {
    final TerminalId rootA = find(a);
    final TerminalId rootB = find(b);
    if (rootA == rootB) {
      return;
    }
    if (rootA.value.compareTo(rootB.value) <= 0) {
      _parent[rootB] = rootA;
    } else {
      _parent[rootA] = rootB;
    }
  }
}
