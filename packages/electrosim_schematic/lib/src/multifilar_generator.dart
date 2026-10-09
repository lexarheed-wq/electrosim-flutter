import 'dart:convert';

import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:electrosim_topology/electrosim_topology.dart';

/// P3/R1: a read-only projection, NOT a new electrical model or an IEC renderer.
///
/// TopologyEngine alone decides which terminals belong to each electrical net.
/// Canonical branches remain branches, and are NEVER treated as wires.
final class MultifilarGenerator {
  const MultifilarGenerator({TopologyEngine topology = const TopologyEngine()})
    : _topology = topology;

  final TopologyEngine _topology;

  MultifilarDocument generate(CircuitState circuit) {
    final TopologyGraph graph = _topology.compile(circuit);

    final List<MultifilarDevice> devices = <MultifilarDevice>[
      for (final ComponentInstance component in circuit.components)
        MultifilarDevice(
          key: 'component:${component.id.value}',
          ownerId: component.id.value,
          category: 'component',
          modelType: component.modelType,
          reference: _reference(component.parameters, component.id.value),
          referenceProvisional: !_hasReference(component.parameters),
          terminals: _terminals(component.terminals, graph),
        ),
      for (final SourceInstance source in circuit.sources)
        MultifilarDevice(
          key: 'source:${source.id.value}',
          ownerId: source.id.value,
          category: 'source',
          modelType: source.modelType,
          reference: _reference(source.parameters, source.id.value),
          referenceProvisional: !_hasReference(source.parameters),
          terminals: _terminals(source.terminals, graph),
        ),
    ]..sort((MultifilarDevice a, MultifilarDevice b) =>
        a.key.compareTo(b.key));

    final List<MultifilarNet> nets = <MultifilarNet>[
      for (final TopologyNode node in graph.nodes)
        MultifilarNet(
          id: node.id,
          terminalIds: <String>[
            for (final TerminalId id in node.terminalIds) id.value,
          ],
        ),
    ]..sort((MultifilarNet a, MultifilarNet b) =>
        a.id.compareTo(b.id));

    // No renderer may infer conductor connectivity from the geometry.
    // Disabled connections are retained for display, but are not part of nets.
    final List<MultifilarConductor> conductors = <MultifilarConductor>[
      for (final Connection wire in circuit.connections)
        MultifilarConductor(
          id: wire.id.value,
          firstTerminalId:
              wire.fromTerminalId.value.compareTo(wire.toTerminalId.value) <= 0
              ? wire.fromTerminalId.value
              : wire.toTerminalId.value,
          secondTerminalId:
              wire.fromTerminalId.value.compareTo(wire.toTerminalId.value) <= 0
              ? wire.toTerminalId.value
              : wire.fromTerminalId.value,
          enabled: wire.enabled,
          conductorType: wire.conductorType.name,
          phase: wire.phase.name,
        ),
    ]..sort((MultifilarConductor a, MultifilarConductor b) =>
        a.id.compareTo(b.id));

    // A 3-pole contactor yields 3 power branches + 1 coil, not a
    // fictitious 4-terminal conducting node. Identity is shared with plate.
    final List<MultifilarBranch> branches = <MultifilarBranch>[
      for (final TopologyBranch branch in graph.componentBranches)
        MultifilarBranch(
          key: 'component:${branch.componentId.value}/${branch.branchId}',
          deviceKey: 'component:${branch.componentId.value}',
          role: branch.role.name,
          fromTerminalId: branch.fromTerminalId.value,
          toTerminalId: branch.toTerminalId.value,
          fromNetId: branch.fromNodeId,
          toNetId: branch.toNodeId,
          poleIndex: branch.poleIndex,
        ),
    ]..sort((MultifilarBranch a, MultifilarBranch b) =>
        a.key.compareTo(b.key));

    final List<MultifilarFinding> findings = <MultifilarFinding>[
      for (final TopologyFinding finding in graph.findings)
        MultifilarFinding(
          code: finding.code.name,
          severity: finding.severity.name,
          message: finding.message,
          subjectId: finding.connectionId?.value ??
              finding.componentId?.value ??
              finding.sourceId?.value ??
              finding.nodeId ??
              '',
        ),
    ]..sort((MultifilarFinding a, MultifilarFinding b) {
      final int byCode = a.code.compareTo(b.code);
      return byCode != 0 ? byCode : a.subjectId.compareTo(b.subjectId);
    });

    return MultifilarDocument(
      circuitId: circuit.circuitId.value,
      revision: circuit.revision,
      electricalMode: circuit.mode.name,
      devices: devices,
      nets: nets,
      conductors: conductors,
      branches: branches,
      findings: findings,
      unprojectedInstrumentIds: <String>[
        for (final InstrumentInstance instrument in circuit.instruments)
          instrument.id.value,
      ]..sort(),
    );
  }

  static List<MultifilarTerminal> _terminals(
    List<Terminal> terminals,
    TopologyGraph topology,
  ) => <MultifilarTerminal>[
    for (final Terminal terminal in terminals)
      MultifilarTerminal(
        id: terminal.id.value,
        label: terminal.name,
        role: terminal.role.name,
        phase: terminal.phase.name,
        netId: topology.terminalToNode[terminal.id]!,
      ),
  ]..sort((MultifilarTerminal a, MultifilarTerminal b) =>
      a.id.compareTo(b.id));

  static bool _hasReference(Map<String, Object?> values) =>
      values['reference'] is String &&
      (values['reference'] as String).trim().isNotEmpty;

  static String _reference(Map<String, Object?> values, String fallback) =>
      _hasReference(values)
          ? (values['reference'] as String).trim()
          : fallback;
}

final class MultifilarDocument {
  MultifilarDocument({
    required this.circuitId,
    required this.revision,
    required this.electricalMode,
    required List<MultifilarDevice> devices,
    required List<MultifilarNet> nets,
    required List<MultifilarConductor> conductors,
    required List<MultifilarBranch> branches,
    required List<MultifilarFinding> findings,
    required List<String> unprojectedInstrumentIds,
  }) : devices = List.unmodifiable(devices),
       nets = List.unmodifiable(nets),
       conductors = List.unmodifiable(conductors),
       branches = List.unmodifiable(branches),
       findings = List.unmodifiable(findings),
       unprojectedInstrumentIds = List.unmodifiable(unprojectedInstrumentIds);

  final String circuitId;
  final int revision;
  final String electricalMode;
  final List<MultifilarDevice> devices;
  final List<MultifilarNet> nets;
  final List<MultifilarConductor> conductors;
  final List<MultifilarBranch> branches;
  final List<MultifilarFinding> findings;

  /// Physical measurement instruments need a separately validated symbol/
  /// measurement-port projection. They are NEVER silently turned into wires.
  final List<String> unprojectedInstrumentIds;

  Map<String, Object?> toJson() => <String, Object?>{
    'schemaVersion': 1,
    'circuitId': circuitId,
    'revision': revision,
    'electricalMode': electricalMode,
    'devices': [for (final item in devices) item.toJson()],
    'nets': [for (final item in nets) item.toJson()],
    'conductors': [for (final item in conductors) item.toJson()],
    'branches': [for (final item in branches) item.toJson()],
    'findings': [for (final item in findings) item.toJson()],
    'unprojectedInstrumentIds': unprojectedInstrumentIds,
  };

  String canonicalJson() => jsonEncode(toJson());

  /// A stable content signature, not a cryptographic hash.
  String get signature => canonicalJson();
}

final class MultifilarTerminal {
  const MultifilarTerminal({
    required this.id,
    required this.label,
    required this.role,
    required this.phase,
    required this.netId,
  });

  final String id;
  final String label;
  final String role;
  final String phase;
  final String netId;

  Map<String, Object?> toJson() => {
    'id': id,
    'label': label,
    'role': role,
    'phase': phase,
    'netId': netId,
  };
}

final class MultifilarDevice {
  MultifilarDevice({
    required this.key,
    required this.ownerId,
    required this.category,
    required this.modelType,
    required this.reference,
    required this.referenceProvisional,
    required List<MultifilarTerminal> terminals,
  }) : terminals = List.unmodifiable(terminals);

  final String key;
  final String ownerId;
  final String category;
  final String modelType;
  final String reference;
  final bool referenceProvisional;
  final List<MultifilarTerminal> terminals;

  Map<String, Object?> toJson() => {
    'key': key,
    'ownerId': ownerId,
    'category': category,
    'modelType': modelType,
    'reference': reference,
    'referenceProvisional': referenceProvisional,
    'terminals': [for (final item in terminals) item.toJson()],
  };
}

final class MultifilarNet {
  MultifilarNet({required this.id, required List<String> terminalIds})
    : terminalIds = List.unmodifiable(terminalIds);

  final String id;
  final List<String> terminalIds;

  Map<String, Object?> toJson() => {
    'id': id,
    'terminalIds': terminalIds,
  };
}

final class MultifilarConductor {
  const MultifilarConductor({
    required this.id,
    required this.firstTerminalId,
    required this.secondTerminalId,
    required this.enabled,
    required this.conductorType,
    required this.phase,
  });

  final String id;
  final String firstTerminalId;
  final String secondTerminalId;
  final bool enabled;
  final String conductorType;
  final String phase;

  Map<String, Object?> toJson() => {
    'id': id,
    'firstTerminalId': firstTerminalId,
    'secondTerminalId': secondTerminalId,
    'enabled': enabled,
    'conductorType': conductorType,
    'phase': phase,
  };
}

final class MultifilarBranch {
  const MultifilarBranch({
    required this.key,
    required this.deviceKey,
    required this.role,
    required this.fromTerminalId,
    required this.toTerminalId,
    required this.fromNetId,
    required this.toNetId,
    required this.poleIndex,
  });

  final String key;
  final String deviceKey;
  final String role;
  final String fromTerminalId;
  final String toTerminalId;
  final String fromNetId;
  final String toNetId;
  final int? poleIndex;

  Map<String, Object?> toJson() => {
    'key': key,
    'deviceKey': deviceKey,
    'role': role,
    'fromTerminalId': fromTerminalId,
    'toTerminalId': toTerminalId,
    'fromNetId': fromNetId,
    'toNetId': toNetId,
    'poleIndex': poleIndex,
  };
}

final class MultifilarFinding {
  const MultifilarFinding({
    required this.code,
    required this.severity,
    required this.message,
    required this.subjectId,
  });

  final String code;
  final String severity;
  final String message;
  final String subjectId;

  Map<String, Object?> toJson() => {
    'code': code,
    'severity': severity,
    'message': message,
    'subjectId': subjectId,
  };
}
