import 'dart:math' as math;
import 'dart:ui';

import 'package:electrosim_canvas/electrosim_canvas.dart';
import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:electrosim_multiphysics/electrosim_multiphysics.dart';

/// Identifies an item on the shared, render-only board and its persisted owner.
final class MixedBoardOrigin {
  const MixedBoardOrigin(this.networkId, this.localId);

  final String networkId;
  final String localId;
}

/// Render-only combination of homogeneous solver circuits.
///
/// The projected [circuit] deliberately uses DC as a harmless canvas domain;
/// it must never be passed to an electrical solver. All electrical ownership
/// remains in [ElectricalProject.networks].
final class MixedBoardProjection {
  MixedBoardProjection._({
    required this.circuit,
    required this.componentOrigins,
    required this.sourceOrigins,
    required this.connectionOrigins,
    required this.terminalOrigins,
    required Map<String, MixedBoardOrigin> instrumentOrigins,
  }) : _instrumentOrigins = instrumentOrigins;

  static const String projectionMetadataKey = 'electrosim.renderOnlyMixedBoard';

  final CircuitState circuit;
  final Map<String, MixedBoardOrigin> componentOrigins;
  final Map<String, MixedBoardOrigin> sourceOrigins;
  final Map<String, MixedBoardOrigin> connectionOrigins;
  final Map<String, MixedBoardOrigin> terminalOrigins;
  final Map<String, MixedBoardOrigin> _instrumentOrigins;
  Map<String, MixedBoardOrigin> get instrumentOrigins => _instrumentOrigins;

  static ElectricalProject applyBoardEdit(
    ElectricalProject project,
    CircuitState editedBoard,
    String activeNetworkId,
  ) {
    final networkIndex = <String, int>{
      for (var i = 0; i < project.networks.length; i++) project.networks[i].id: i,
    };
    final old = fromProject(project);
    final terminalOwners = <String, String>{};
    for (final terminal in editedBoard.components.expand((c) => c.terminals)
        .followedBy(editedBoard.sources.expand((s) => s.terminals))) {
      final origin = old.terminalOrigins[terminal.id.value];
      final boardNetwork = _networkIndexFromBoardId(terminal.id.value);
      terminalOwners[terminal.id.value] = origin?.networkId ??
          (boardNetwork == null || boardNetwork >= project.networks.length
              ? activeNetworkId : project.networks[boardNetwork].id);
    }
    for (final connection in editedBoard.connections) {
      final from = terminalOwners[connection.fromTerminalId.value];
      final to = terminalOwners[connection.toTerminalId.value];
      if (from == null || to == null || from != to) {
        throw StateError('Un fil ne peut relier que des composants du même domaine électrique.');
      }
    }
    for (final probe in editedBoard.probes) {
      final instrumentNetwork = old._instrumentOrigins[probe.instrumentId.value]?.networkId ??
          _networkIdFromBoardId(project, probe.instrumentId.value) ?? activeNetworkId;
      final targetNetwork = probe.terminalId != null
          ? terminalOwners[probe.terminalId!.value]
          : old.connectionOrigins[probe.connectionId!.value]?.networkId ??
              _networkIdFromBoardId(project, probe.connectionId!.value);
      if (targetNetwork != null && targetNetwork != instrumentNetwork) {
        throw StateError('Une mesure doit rester dans le même domaine que son instrument.');
      }
    }
    final componentsByNetwork = <String, List<ComponentInstance>>{
      for (final network in project.networks) network.id: <ComponentInstance>[],
    };
    final sourcesByNetwork = <String, List<SourceInstance>>{
      for (final network in project.networks) network.id: <SourceInstance>[],
    };
    String localId(String boardId, String networkId) {
      final int index = networkIndex[networkId]!;
      final prefix = 'n$index--';
      return boardId.startsWith(prefix) ? boardId.substring(prefix.length) : boardId;
    }
    for (final component in editedBoard.components) {
      final networkId = old.componentOrigins[component.id.value]?.networkId ??
          _networkIdFromBoardId(project, component.id.value) ?? activeNetworkId;
      componentsByNetwork[networkId]!.add(ComponentInstance(
        id: ComponentId(old.componentOrigins[component.id.value]?.localId ??
            localId(component.id.value, networkId)),
        modelType: component.modelType,
        terminals: component.terminals.map((t) => Terminal(
          id: TerminalId(old.terminalOrigins[t.id.value]?.localId ??
              localId(t.id.value, networkId)), name: t.name,
          role: t.role, phase: t.phase, metadata: t.metadata,
        )).toList(growable: false),
        parameters: _mapReferences(component.parameters, (value) =>
          old.componentOrigins[value]?.localId ?? value),
        condition: component.condition,
        controlState: _mapReferences(component.controlState, (value) =>
          old.componentOrigins[value]?.localId ?? value),
      ));
    }
    for (final source in editedBoard.sources) {
      final networkId = old.sourceOrigins[source.id.value]?.networkId ??
          _networkIdFromBoardId(project, source.id.value) ?? activeNetworkId;
      sourcesByNetwork[networkId]!.add(SourceInstance(
        id: SourceId(old.sourceOrigins[source.id.value]?.localId ??
            localId(source.id.value, networkId)), modelType: source.modelType,
        terminals: source.terminals.map((t) => Terminal(
          id: TerminalId(old.terminalOrigins[t.id.value]?.localId ??
              localId(t.id.value, networkId)), name: t.name,
          role: t.role, phase: t.phase, metadata: t.metadata,
        )).toList(growable: false),
        parameters: source.parameters, enabled: source.enabled,
      ));
    }
    final connectionsByNetwork = <String, List<Connection>>{
      for (final network in project.networks) network.id: <Connection>[],
    };
    for (final connection in editedBoard.connections) {
      final networkId = terminalOwners[connection.fromTerminalId.value]!;
      connectionsByNetwork[networkId]!.add(Connection(
        id: ConnectionId(old.connectionOrigins[connection.id.value]?.localId ??
            localId(connection.id.value, networkId)),
        fromTerminalId: TerminalId(old.terminalOrigins[connection.fromTerminalId.value]?.localId ??
            localId(connection.fromTerminalId.value, networkId)),
        toTerminalId: TerminalId(old.terminalOrigins[connection.toTerminalId.value]?.localId ??
            localId(connection.toTerminalId.value, networkId)),
        conductorType: connection.conductorType, phase: connection.phase,
        enabled: connection.enabled, metadata: connection.metadata,
      ));
    }
    final updated = <ElectricalNetwork>[];
    for (final network in project.networks) {
      final original = network.circuit;
      final index = networkIndex[network.id]!;
      final instruments = <InstrumentInstance>[];
      final probes = <ProbeConnection>[];
      for (final item in editedBoard.instruments.where((i) =>
          _networkIndexFromBoardId(i.id.value) == index ||
          (_networkIndexFromBoardId(i.id.value) == null && network.id == activeNetworkId))) {
        final raw = item.toJson()..['id'] = oldInstrumentLocalId(old, item.id.value, network.id, localId);
        if (raw['cutConnectionId'] is String) {
          final connectionId = raw['cutConnectionId'] as String;
          raw['cutConnectionId'] = old.connectionOrigins[connectionId]?.localId ?? localId(connectionId, network.id);
        }
        instruments.add(InstrumentInstance.fromJson(raw));
      }
      for (final item in editedBoard.probes.where((p) =>
          _networkIndexFromBoardId(p.id.value) == index ||
          (_networkIndexFromBoardId(p.id.value) == null && network.id == activeNetworkId))) {
        final raw = item.toJson()
          ..['id'] = localId(item.id.value, network.id)
          ..['instrumentId'] = oldInstrumentLocalId(old, item.instrumentId.value, network.id, localId);
        if (raw['terminalId'] is String) {
          final terminalId = raw['terminalId'] as String;
          raw['terminalId'] = old.terminalOrigins[terminalId]?.localId ?? localId(terminalId, network.id);
        }
        if (raw['connectionId'] is String) {
          final connectionId = raw['connectionId'] as String;
          raw['connectionId'] = old.connectionOrigins[connectionId]?.localId ?? localId(connectionId, network.id);
        }
        probes.add(ProbeConnection.fromJson(raw));
      }
      updated.add(ElectricalNetwork(id: network.id, circuit: CircuitState(
        circuitId: original.circuitId, revision: original.revision + 1,
        mode: original.mode, components: componentsByNetwork[network.id]!,
        sources: sourcesByNetwork[network.id]!, connections: connectionsByNetwork[network.id]!,
        instruments: instruments, probes: probes, settings: original.settings, metadata: original.metadata,
      )));
    }
    bool hasComponent(String networkId, String componentId) => updated
        .where((network) => network.id == networkId)
        .first.circuit.components.any((component) => component.id.value == componentId);
    return ElectricalProject(
      networks: updated,
      relayLinks: project.relayLinks.where((link) =>
        hasComponent(link.plcNetworkId, link.plcComponentId) &&
        hasComponent(link.dcNetworkId, link.relayCoilId) &&
        hasComponent(link.ac3NetworkId, link.ac3ContactId)).toList(),
      signalLinks: project.signalLinks.where((link) =>
        hasComponent(link.dcNetworkId, link.plcComponentId) &&
        hasComponent(link.ac3NetworkId, link.auxiliaryContactId)).toList(),
      actuatorLinks: project.actuatorLinks.where((link) =>
        hasComponent(link.plcNetworkId, link.plcComponentId) &&
        hasComponent(link.targetNetworkId, link.contactorId)).toList(),
      converterLinks: project.converterLinks.where((link) =>
        hasComponent(link.inputNetworkId, link.converterComponentId) &&
        updated.where((network) => network.id == link.outputNetworkId).first.circuit
          .components.expand((component) => component.terminals).followedBy(
            updated.where((network) => network.id == link.outputNetworkId).first.circuit.sources
              .expand((source) => source.terminals))
          .any((terminal) => terminal.id.value == link.outputLineTerminalId) &&
        updated.where((network) => network.id == link.outputNetworkId).first.circuit
          .components.expand((component) => component.terminals).followedBy(
            updated.where((network) => network.id == link.outputNetworkId).first.circuit.sources
              .expand((source) => source.terminals))
          .any((terminal) => terminal.id.value == link.outputNeutralTerminalId)).toList(),
    );
  }

  static String oldInstrumentLocalId(
    MixedBoardProjection old, String boardId, String networkId,
    String Function(String, String) fallback,
  ) => old._instrumentOrigins[boardId]?.localId ?? fallback(boardId, networkId);

  static int? _networkIndexFromBoardId(String id) {
    final match = RegExp(r'^n(\d+)--').firstMatch(id);
    return match == null ? null : int.tryParse(match.group(1)!);
  }

  static String? _networkIdFromBoardId(ElectricalProject project, String id) {
    final index = _networkIndexFromBoardId(id);
    return index != null && index < project.networks.length ? project.networks[index].id : null;
  }

  static MixedBoardProjection fromProject(ElectricalProject project) {
    final components = <ComponentInstance>[];
    final sources = <SourceInstance>[];
    final connections = <Connection>[];
    final instruments = <InstrumentInstance>[];
    final probes = <ProbeConnection>[];
    final componentOrigins = <String, MixedBoardOrigin>{};
    final sourceOrigins = <String, MixedBoardOrigin>{};
    final connectionOrigins = <String, MixedBoardOrigin>{};
    final terminalOrigins = <String, MixedBoardOrigin>{};
    final instrumentOrigins = <String, MixedBoardOrigin>{};
    final terminalIds = <String, String>{};
    final connectionIds = <String, String>{};
    final instrumentIds = <String, String>{};

    String id(int networkIndex, String localId) => boardId(networkIndex, localId);
    final componentReferenceIds = <String, String>{
      for (var i = 0; i < project.networks.length; i++)
        for (final component in project.networks[i].circuit.components)
          '${project.networks[i].id}:${component.id.value}': id(i, component.id.value),
    };
    for (var networkIndex = 0; networkIndex < project.networks.length; networkIndex++) {
      final network = project.networks[networkIndex];
      final circuit = network.circuit;
      for (final component in circuit.components) {
        final boardId = id(networkIndex, component.id.value);
        componentOrigins[boardId] = MixedBoardOrigin(network.id, component.id.value);
        for (final terminal in component.terminals) {
          final boardTerminalId = id(networkIndex, terminal.id.value);
          terminalIds['${network.id}:${terminal.id.value}'] = boardTerminalId;
          terminalOrigins[boardTerminalId] = MixedBoardOrigin(network.id, terminal.id.value);
        }
        components.add(ComponentInstance(
          id: ComponentId(boardId), modelType: component.modelType,
          terminals: component.terminals.map((terminal) => Terminal(
            id: TerminalId(id(networkIndex, terminal.id.value)), name: terminal.name,
            role: terminal.role, phase: terminal.phase, metadata: terminal.metadata,
          )).toList(growable: false),
          parameters: _mapReferences(component.parameters,
            (value) => componentReferenceIds['${network.id}:$value'] ?? value),
          condition: component.condition,
          controlState: _mapReferences(component.controlState,
            (value) => componentReferenceIds['${network.id}:$value'] ?? value),
        ));
      }
      for (final source in circuit.sources) {
        final boardId = id(networkIndex, source.id.value);
        sourceOrigins[boardId] = MixedBoardOrigin(network.id, source.id.value);
        for (final terminal in source.terminals) {
          final boardTerminalId = id(networkIndex, terminal.id.value);
          terminalIds['${network.id}:${terminal.id.value}'] = boardTerminalId;
          terminalOrigins[boardTerminalId] = MixedBoardOrigin(network.id, terminal.id.value);
        }
        sources.add(SourceInstance(
          id: SourceId(boardId), modelType: source.modelType,
          terminals: source.terminals.map((terminal) => Terminal(
            id: TerminalId(id(networkIndex, terminal.id.value)), name: terminal.name,
            role: terminal.role, phase: terminal.phase, metadata: terminal.metadata,
          )).toList(growable: false),
          parameters: source.parameters, enabled: source.enabled,
        ));
      }
      for (final connection in circuit.connections) {
        final boardId = id(networkIndex, connection.id.value);
        connectionOrigins[boardId] = MixedBoardOrigin(network.id, connection.id.value);
        connectionIds['${network.id}:${connection.id.value}'] = boardId;
        connections.add(Connection(
          id: ConnectionId(boardId),
          fromTerminalId: TerminalId(terminalIds['${network.id}:${connection.fromTerminalId.value}']!),
          toTerminalId: TerminalId(terminalIds['${network.id}:${connection.toTerminalId.value}']!),
          conductorType: connection.conductorType, phase: connection.phase,
          enabled: connection.enabled, metadata: connection.metadata,
        ));
      }
      for (final instrument in circuit.instruments) {
        final boardId = id(networkIndex, instrument.id.value);
        instrumentIds['${network.id}:${instrument.id.value}'] = boardId;
        instrumentOrigins[boardId] = MixedBoardOrigin(network.id, instrument.id.value);
        instruments.add(InstrumentInstance(
          id: InstrumentId(boardId), kind: instrument.kind, mode: instrument.mode,
          inputImpedanceOhm: instrument.inputImpedanceOhm,
          burdenResistanceOhm: instrument.burdenResistanceOhm,
          maximumVoltageV: instrument.maximumVoltageV,
          maximumCurrentA: instrument.maximumCurrentA,
          fuseRatingA: instrument.fuseRatingA, fuseBlown: instrument.fuseBlown,
          poweredOn: instrument.poweredOn,
          cutConnectionId: instrument.cutConnectionId == null ? null : ConnectionId(
            connectionIds['${network.id}:${instrument.cutConnectionId!.value}']!),
          settings: instrument.settings,
        ));
      }
      for (final probe in circuit.probes) {
        probes.add(ProbeConnection(
          id: ProbeId(id(networkIndex, probe.id.value)),
          instrumentId: InstrumentId(instrumentIds['${network.id}:${probe.instrumentId.value}']!),
          port: probe.port,
          terminalId: probe.terminalId == null ? null : TerminalId(
            terminalIds['${network.id}:${probe.terminalId!.value}']!),
          connectionId: probe.connectionId == null ? null : ConnectionId(
            connectionIds['${network.id}:${probe.connectionId!.value}']!),
        ));
      }
    }
    return MixedBoardProjection._(
      circuit: CircuitState(
        circuitId: CircuitId('mixed-board-projection'), revision: 0,
        mode: ElectricalMode.dc, components: components, sources: sources,
        connections: connections, instruments: instruments, probes: probes,
        metadata: const <String, Object?>{projectionMetadataKey: true},
      ),
      componentOrigins: Map.unmodifiable(componentOrigins),
      sourceOrigins: Map.unmodifiable(sourceOrigins),
      connectionOrigins: Map.unmodifiable(connectionOrigins),
      terminalOrigins: Map.unmodifiable(terminalOrigins),
      instrumentOrigins: Map.unmodifiable(instrumentOrigins),
    );
  }

  static String boardId(int networkIndex, String localId) {
    final String part = localId.length <= 120
        ? localId
        : '${localId.substring(0, 100)}-${localId.hashCode.toRadixString(16)}';
    return 'n$networkIndex--$part';
  }

  static Map<String, Object?> _mapReferences(
    Map<String, Object?> input,
    String Function(String) mapId,
  ) => <String, Object?>{
    for (final entry in input.entries) entry.key: _mapReferenceValue(entry.value, mapId),
  };

  static Object? _mapReferenceValue(Object? value, String Function(String) mapId) {
    if (value is String) {
      return mapId(value);
    }
    if (value is List) {
      return value.map((item) => _mapReferenceValue(item, mapId)).toList(growable: false);
    }
    if (value is Map<String, Object?>) {
      return <String, Object?>{
        for (final entry in value.entries)
          entry.key: _mapReferenceValue(entry.value, mapId),
      };
    }
    return value;
  }

  static CircuitVisualLayout normalizeLayout(
    ElectricalProject project,
    CircuitVisualLayout layout,
    String activeNetworkId,
  ) {
    final int index = project.networks.indexWhere((network) => network.id == activeNetworkId);
    if (index < 0) return layout;
    String key(String value) => RegExp(r'^n\d+--').hasMatch(value)
        ? value
        : boardId(index, value);
    return CircuitVisualLayout(
      elementPositions: layout.elementPositions.map((id, value) => MapEntry(key(id), value)),
      elementSizes: layout.elementSizes.map((id, value) => MapEntry(key(id), value)),
      wireRoutes: layout.wireRoutes.map((id, value) => MapEntry(key(id), value)),
      elementQuarterTurns: layout.elementQuarterTurns.map((id, value) => MapEntry(key(id), value)),
      defaultElementSize: layout.defaultElementSize,
      cabinetLayout: CabinetLayout(
        layout.cabinetLayout.fixtures.map((fixture) => CabinetFixture(
          id: key(fixture.id), kind: fixture.kind, bounds: fixture.bounds,
        )),
        envelope: layout.cabinetLayout.envelope,
        mounts: <String, CabinetMount>{
          for (final entry in layout.cabinetLayout.mounts.entries)
            key(entry.key): CabinetMount(
              surface: entry.value.surface,
              railId: entry.value.railId == null ? null : key(entry.value.railId!),
              anchorOffset: entry.value.anchorOffset,
              depthMm: entry.value.depthMm,
            ),
        },
      ),
      terminalAnchorOffsets: layout.terminalAnchorOffsets.map((id, value) => MapEntry(key(id), value)),
    );
  }

  /// Merges legacy per-network layouts into one 2×2, namespaced layout.
  static CircuitVisualLayout combineLayouts(
    ElectricalProject project,
    Map<String, CircuitVisualLayout> layouts,
  ) {
    final positions = <String, Offset>{};
    final sizes = <String, Size>{};
    final routes = <String, List<Offset>>{};
    final turns = <String, int>{};
    final fixtures = <CabinetFixture>[];
    final mounts = <String, CabinetMount>{};
    final envelopes = <CabinetEnvelope>[];
    for (var index = 0; index < project.networks.length; index++) {
      final network = project.networks[index];
      final layout = layouts[network.id];
      final dx = (index % 2) * 1400.0;
      final dy = (index ~/ 2) * 1200.0;
      String boardKey(String local) => 'n$index--$local';
      final localIds = <String>[
        ...network.circuit.sources.map((source) => source.id.value),
        ...network.circuit.components.map((component) => component.id.value),
        ...network.circuit.instruments.map((instrument) => instrument.id.value),
      ];
      final savedPositions = layout?.elementPositions ?? const <String, Offset>{};
      double minX = savedPositions.values.isEmpty
          ? 0 : savedPositions.values.map((point) => point.dx).reduce((a, b) => a < b ? a : b);
      double minY = savedPositions.values.isEmpty
          ? 0 : savedPositions.values.map((point) => point.dy).reduce((a, b) => a < b ? a : b);
      final translate = Offset(dx + 96 - minX, dy + 96 - minY);
      for (final entry in savedPositions.entries) {
        positions[boardKey(entry.key)] = entry.value + translate;
      }
      for (var elementIndex = 0; elementIndex < localIds.length; elementIndex++) {
        final localId = localIds[elementIndex];
        positions.putIfAbsent(boardKey(localId), () => Offset(
          dx + 120 + (elementIndex % 3) * 280.0,
          dy + 120 + (elementIndex ~/ 3) * 180.0,
        ));
      }
      if (layout == null) continue;
      final envelope = layout.cabinetLayout.envelope;
      if (envelope != null) envelopes.add(envelope);
      for (final fixture in layout.cabinetLayout.fixtures) {
        fixtures.add(CabinetFixture(
          id: boardKey(fixture.id), kind: fixture.kind,
          bounds: fixture.bounds.shift(translate),
        ));
      }
      for (final entry in layout.cabinetLayout.mounts.entries) {
        final mount = entry.value;
        mounts[boardKey(entry.key)] = CabinetMount(
          surface: mount.surface,
          railId: mount.railId == null ? null : boardKey(mount.railId!),
          anchorOffset: mount.anchorOffset,
          depthMm: mount.depthMm,
        );
      }
      sizes.addAll(layout.elementSizes.map((key, value) => MapEntry(boardKey(key), value)));
      turns.addAll(layout.elementQuarterTurns.map((key, value) => MapEntry(boardKey(key), value)));
      routes.addAll(layout.wireRoutes.map((key, value) => MapEntry(
        boardKey(key), value.map((point) => point + translate).toList(growable: false),
      )));
    }
    final CabinetEnvelope? envelope = envelopes.isEmpty ? null : CabinetEnvelope(
      widthMm: math.max(3000, envelopes.map((item) => item.widthMm).reduce((a, b) => a > b ? a : b) * 2).toDouble(),
      heightMm: math.max(2600, envelopes.map((item) => item.heightMm).reduce((a, b) => a > b ? a : b) * 2).toDouble(),
      depthMm: envelopes.map((item) => item.depthMm).reduce((a, b) => a > b ? a : b),
      marginMm: envelopes.map((item) => item.marginMm).reduce((a, b) => a > b ? a : b),
      origin: Offset.zero,
    );
    return CircuitVisualLayout(
      elementPositions: positions, elementSizes: sizes, wireRoutes: routes,
      elementQuarterTurns: turns,
      cabinetLayout: CabinetLayout(fixtures, envelope: envelope, mounts: mounts),
    );
  }
}
