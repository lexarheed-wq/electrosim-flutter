import 'package:electrosim_domain/electrosim_domain.dart';

enum TopologyFindingSeverity { info, warning, error }

enum TopologyFindingCode {
  disabledConnection,
  floatingNode,
  isolatedComponent,
  isolatedSource,
  conflictingPhases,
}

final class TopologyFinding {
  TopologyFinding({
    required this.code,
    required this.severity,
    required this.message,
    this.nodeId,
    this.connectionId,
    this.componentId,
    this.sourceId,
    List<TerminalId> terminalIds = const <TerminalId>[],
  }) : terminalIds = List<TerminalId>.unmodifiable(terminalIds);

  final TopologyFindingCode code;
  final TopologyFindingSeverity severity;
  final String message;
  final String? nodeId;
  final ConnectionId? connectionId;
  final ComponentId? componentId;
  final SourceId? sourceId;
  final List<TerminalId> terminalIds;
}
