import 'package:electrosim_domain/electrosim_domain.dart';

import 'topology_finding.dart';

final class TopologyNode {
  TopologyNode({required this.id, required Iterable<TerminalId> terminalIds})
    : terminalIds = List<TerminalId>.unmodifiable(
        terminalIds.toList(growable: false)
          ..sort((TerminalId a, TerminalId b) => a.value.compareTo(b.value)),
      );

  final String id;
  final List<TerminalId> terminalIds;
}

/// Structural internal branch projected from a canonical component model.
///
/// A topology branch is not a conductor node merge. The solver decides how the
/// branch behaves electrically from the component model, condition and state.
final class TopologyBranch {
  TopologyBranch({
    required this.componentId,
    required this.branchId,
    required this.role,
    required this.fromTerminalId,
    required this.toTerminalId,
    required this.fromNodeId,
    required this.toNodeId,
    this.poleIndex,
  });

  final ComponentId componentId;
  final String branchId;
  final ElectricalBranchRole role;
  final TerminalId fromTerminalId;
  final TerminalId toTerminalId;
  final String fromNodeId;
  final String toNodeId;
  final int? poleIndex;
}

final class TopologyGraph {
  TopologyGraph({
    required this.circuitId,
    required this.circuitRevision,
    required this.mode,
    required Iterable<TopologyNode> nodes,
    required Map<TerminalId, String> terminalToNode,
    required Iterable<ConnectionId> enabledConnectionIds,
    required Iterable<ConnectionId> disabledConnectionIds,
    required Map<ComponentId, List<String>> componentNodeIds,
    required Map<SourceId, List<String>> sourceNodeIds,
    Iterable<TopologyBranch> componentBranches = const <TopologyBranch>[],
    required Iterable<TopologyFinding> findings,
  }) : nodes = List<TopologyNode>.unmodifiable(nodes),
       terminalToNode = Map<TerminalId, String>.unmodifiable(terminalToNode),
       enabledConnectionIds = List<ConnectionId>.unmodifiable(
         enabledConnectionIds,
       ),
       disabledConnectionIds = List<ConnectionId>.unmodifiable(
         disabledConnectionIds,
       ),
       componentNodeIds = _freezeOwnerMap<ComponentId>(componentNodeIds),
       sourceNodeIds = _freezeOwnerMap<SourceId>(sourceNodeIds),
       componentBranches = List<TopologyBranch>.unmodifiable(componentBranches),
       findings = List<TopologyFinding>.unmodifiable(findings);

  final CircuitId circuitId;
  final int circuitRevision;
  final ElectricalMode mode;
  final List<TopologyNode> nodes;
  final Map<TerminalId, String> terminalToNode;
  final List<ConnectionId> enabledConnectionIds;
  final List<ConnectionId> disabledConnectionIds;
  final Map<ComponentId, List<String>> componentNodeIds;
  final Map<SourceId, List<String>> sourceNodeIds;
  final List<TopologyBranch> componentBranches;
  final List<TopologyFinding> findings;

  TopologyNode nodeForTerminal(TerminalId terminalId) {
    final String? nodeId = terminalToNode[terminalId];
    if (nodeId == null) {
      throw StateError(
        'Terminal ${terminalId.value} is not present in topology.',
      );
    }
    return nodes.firstWhere((TopologyNode node) => node.id == nodeId);
  }

  List<TopologyBranch> branchesForComponent(ComponentId componentId) =>
      List<TopologyBranch>.unmodifiable(
        componentBranches.where(
          (TopologyBranch branch) => branch.componentId == componentId,
        ),
      );
}

Map<K, List<String>> _freezeOwnerMap<K>(Map<K, List<String>> input) {
  final Map<K, List<String>> result = <K, List<String>>{};
  input.forEach((K key, List<String> value) {
    result[key] = List<String>.unmodifiable(value);
  });
  return Map<K, List<String>>.unmodifiable(result);
}
