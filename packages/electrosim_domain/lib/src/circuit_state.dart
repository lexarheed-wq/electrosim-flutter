import 'dart:convert';

import 'component.dart';
import 'connection.dart';
import 'domain_error.dart';
import 'electrical_types.dart';
import 'ids.dart';
import 'instrument.dart';
import 'json_support.dart';
import 'source.dart';
import 'terminal.dart';

final class CircuitState {
  CircuitState({
    required this.circuitId,
    required this.revision,
    required this.mode,
    List<ComponentInstance> components = const <ComponentInstance>[],
    List<Connection> connections = const <Connection>[],
    List<SourceInstance> sources = const <SourceInstance>[],
    List<InstrumentInstance> instruments = const <InstrumentInstance>[],
    List<ProbeConnection> probes = const <ProbeConnection>[],
    Map<String, Object?> settings = const <String, Object?>{},
    Map<String, Object?> metadata = const <String, Object?>{},
  }) : components = List<ComponentInstance>.unmodifiable(components),
       connections = List<Connection>.unmodifiable(connections),
       sources = List<SourceInstance>.unmodifiable(sources),
       instruments = List<InstrumentInstance>.unmodifiable(instruments),
       probes = List<ProbeConnection>.unmodifiable(probes),
       settings = freezeJsonMap(settings),
       metadata = freezeJsonMap(metadata) {
    if (revision < 0) {
      throw DomainException(
        code: DomainErrorCode.invalidValue,
        message: 'Circuit revision must be zero or greater.',
        context: <String, Object?>{'revision': revision},
      );
    }
    _validateIdentityAndReferences();
  }

  factory CircuitState.fromJson(JsonMap json) {
    final int schemaVersion = requireInt(json, 'schemaVersion');
    if (schemaVersion != currentSchemaVersion) {
      throw DomainException(
        code: DomainErrorCode.invalidSchemaVersion,
        message: 'Unsupported CircuitState schemaVersion: $schemaVersion.',
        context: <String, Object?>{
          'supported': currentSchemaVersion,
          'actual': schemaVersion,
        },
      );
    }
    return CircuitState(
      circuitId: CircuitId(requireString(json, 'circuitId')),
      revision: requireInt(json, 'revision'),
      mode: enumByName<ElectricalMode>(
        ElectricalMode.values,
        requireString(json, 'mode'),
        'mode',
      ),
      components: requireList(json, 'components')
          .map<ComponentInstance>(
            (Object? value) => ComponentInstance.fromJson(value! as JsonMap),
          )
          .toList(growable: false),
      connections: requireList(json, 'connections')
          .map<Connection>(
            (Object? value) => Connection.fromJson(value! as JsonMap),
          )
          .toList(growable: false),
      sources: requireList(json, 'sources')
          .map<SourceInstance>(
            (Object? value) => SourceInstance.fromJson(value! as JsonMap),
          )
          .toList(growable: false),
      instruments: (json['instruments'] as List<Object?>? ?? const <Object?>[])
          .map<InstrumentInstance>((Object? value) =>
              InstrumentInstance.fromJson(value! as JsonMap))
          .toList(growable: false),
      probes: (json['probes'] as List<Object?>? ?? const <Object?>[])
          .map<ProbeConnection>((Object? value) =>
              ProbeConnection.fromJson(value! as JsonMap))
          .toList(growable: false),
      settings: requireMap(json, 'settings'),
      metadata: requireMap(json, 'metadata'),
    );
  }

  factory CircuitState.fromJsonString(String source) {
    final Object? decoded = jsonDecode(source);
    if (decoded is! JsonMap) {
      throw DomainException(
        code: DomainErrorCode.invalidJsonValue,
        message: 'CircuitState JSON root must be an object.',
      );
    }
    return CircuitState.fromJson(decoded);
  }

  static const int currentSchemaVersion = 1;

  final CircuitId circuitId;
  final int revision;
  final ElectricalMode mode;
  final List<ComponentInstance> components;
  final List<Connection> connections;
  final List<SourceInstance> sources;
  final List<InstrumentInstance> instruments;
  final List<ProbeConnection> probes;
  final JsonMap settings;
  final JsonMap metadata;

  JsonMap toJson() => <String, Object?>{
    'schemaVersion': currentSchemaVersion,
    'circuitId': circuitId.value,
    'revision': revision,
    'mode': mode.name,
    'components': components
        .map<JsonMap>((ComponentInstance item) => item.toJson())
        .toList(),
    'connections': connections
        .map<JsonMap>((Connection item) => item.toJson())
        .toList(),
    'sources': sources
        .map<JsonMap>((SourceInstance item) => item.toJson())
        .toList(),
    if (instruments.isNotEmpty) 'instruments': instruments.map<JsonMap>((item) => item.toJson()).toList(),
    if (probes.isNotEmpty) 'probes': probes.map<JsonMap>((item) => item.toJson()).toList(),
    'settings': settings,
    'metadata': metadata,
  };

  String toJsonString() => jsonEncode(toJson());

  void _validateIdentityAndReferences() {
    final Set<ComponentId> componentIds = <ComponentId>{};
    final Set<SourceId> sourceIds = <SourceId>{};
    final Set<ConnectionId> connectionIds = <ConnectionId>{};
    final Set<TerminalId> terminalIds = <TerminalId>{};
    final Set<InstrumentId> instrumentIds = <InstrumentId>{};
    final Set<ProbeId> probeIds = <ProbeId>{};
    final Set<String> occupiedPorts = <String>{};


    for (final ComponentInstance component in components) {
      if (!componentIds.add(component.id)) {
        _duplicate('component', component.id.value);
      }
      for (final Terminal terminal in component.terminals) {
        if (!terminalIds.add(terminal.id)) {
          _duplicate('terminal', terminal.id.value);
        }
      }
    }
    for (final SourceInstance source in sources) {
      if (!sourceIds.add(source.id)) {
        _duplicate('source', source.id.value);
      }
      for (final Terminal terminal in source.terminals) {
        if (!terminalIds.add(terminal.id)) {
          _duplicate('terminal', terminal.id.value);
        }
      }
    }
    for (final Connection connection in connections) {
      if (!connectionIds.add(connection.id)) {
        _duplicate('connection', connection.id.value);
      }
      if (!terminalIds.contains(connection.fromTerminalId) ||
          !terminalIds.contains(connection.toTerminalId)) {
        throw DomainException(
          code: DomainErrorCode.invalidTerminalReference,
          message:
              'Connection ${connection.id.value} references an unknown terminal.',
          context: <String, Object?>{
            'connectionId': connection.id.value,
            'fromTerminalId': connection.fromTerminalId.value,
            'toTerminalId': connection.toTerminalId.value,
          },
        );
      }
    }
    for (final InstrumentInstance instrument in instruments) {
      if (!instrumentIds.add(instrument.id)) {
        _duplicate('instrument', instrument.id.value);
      }
      if (instrument.cutConnectionId != null &&
          !connectionIds.contains(instrument.cutConnectionId)) {
        throw DomainException(
          code: DomainErrorCode.invalidValue,
          message: 'Instrument cutConnectionId does not reference a circuit wire.',
          context: <String, Object?>{'id': instrument.id.value},
        );
      }
    }
    for (final ProbeConnection probe in probes) {
      if (!probeIds.add(probe.id)) {
        _duplicate('probe', probe.id.value);
      }
      if (!instrumentIds.contains(probe.instrumentId)) {
        throw DomainException(
          code: DomainErrorCode.invalidValue,
          message: 'Probe references an unknown physical instrument.',
          context: <String, Object?>{'id': probe.id.value},
        );
      }
      if (probe.terminalId != null && !terminalIds.contains(probe.terminalId)) {
        throw DomainException(
          code: DomainErrorCode.invalidTerminalReference,
          message: 'Probe references an unknown terminal.',
          context: <String, Object?>{'id': probe.id.value},
        );
      }
      if (probe.connectionId != null &&
          !connectionIds.contains(probe.connectionId)) {
        throw DomainException(
          code: DomainErrorCode.invalidValue,
          message: 'Probe references an unknown wire.',
          context: <String, Object?>{'id': probe.id.value},
        );
      }
      final String occupied = '${probe.instrumentId.value}:${probe.port.name}';
      if (!occupiedPorts.add(occupied)) {
        throw DomainException(
          code: DomainErrorCode.invalidValue,
          message: 'Multiple probes occupy the same instrument port.',
          context: <String, Object?>{'port': occupied},
        );
      }
    }
  }

  Never _duplicate(String kind, String id) {
    throw DomainException(
      code: DomainErrorCode.duplicateId,
      message: 'Duplicate $kind ID in CircuitState: $id.',
      context: <String, Object?>{'kind': kind, 'id': id},
    );
  }

  @override
  bool operator ==(Object other) =>
      other is CircuitState &&
      other.circuitId == circuitId &&
      other.revision == revision &&
      other.mode == mode &&
      _listEquals(other.components, components) &&
      _listEquals(other.connections, connections) &&
      _listEquals(other.sources, sources) &&
      _listEquals(other.instruments, instruments) &&
      _listEquals(other.probes, probes) &&
      deepJsonEquals(other.settings, settings) &&
      deepJsonEquals(other.metadata, metadata);

  @override
  int get hashCode => Object.hash(
    circuitId,
    revision,
    mode,
    Object.hashAll(components),
    Object.hashAll(connections),
    Object.hashAll(sources),
    Object.hashAll(instruments),
    Object.hashAll(probes),
    deepJsonHash(settings),
    deepJsonHash(metadata),
  );
}

bool _listEquals<T>(List<T> a, List<T> b) {
  if (a.length != b.length) {
    return false;
  }
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) {
      return false;
    }
  }
  return true;
}
