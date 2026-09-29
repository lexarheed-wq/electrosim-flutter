import 'domain_error.dart';
import 'electrical_types.dart';
import 'ids.dart';
import 'json_support.dart';

final class Connection {
  Connection({
    required this.id,
    required this.fromTerminalId,
    required this.toTerminalId,
    this.conductorType = ConductorType.wire,
    this.phase = PhaseTag.none,
    this.enabled = true,
    Map<String, Object?> metadata = const <String, Object?>{},
  }) : metadata = freezeJsonMap(metadata) {
    if (fromTerminalId == toTerminalId) {
      throw DomainException(
        code: DomainErrorCode.invalidTerminalReference,
        message: 'A connection cannot join a terminal to itself.',
        context: <String, Object?>{'terminalId': fromTerminalId.value},
      );
    }
  }

  factory Connection.fromJson(JsonMap json) => Connection(
    id: ConnectionId(requireString(json, 'id')),
    fromTerminalId: TerminalId(requireString(json, 'fromTerminalId')),
    toTerminalId: TerminalId(requireString(json, 'toTerminalId')),
    conductorType: enumByName<ConductorType>(
      ConductorType.values,
      requireString(json, 'conductorType'),
      'conductorType',
    ),
    phase: enumByName<PhaseTag>(
      PhaseTag.values,
      requireString(json, 'phase'),
      'phase',
    ),
    enabled: requireBool(json, 'enabled'),
    metadata: requireMap(json, 'metadata'),
  );

  final ConnectionId id;
  final TerminalId fromTerminalId;
  final TerminalId toTerminalId;
  final ConductorType conductorType;
  final PhaseTag phase;
  final bool enabled;
  final JsonMap metadata;

  JsonMap toJson() => <String, Object?>{
    'id': id.value,
    'fromTerminalId': fromTerminalId.value,
    'toTerminalId': toTerminalId.value,
    'conductorType': conductorType.name,
    'phase': phase.name,
    'enabled': enabled,
    'metadata': metadata,
  };

  @override
  bool operator ==(Object other) =>
      other is Connection &&
      other.id == id &&
      other.fromTerminalId == fromTerminalId &&
      other.toTerminalId == toTerminalId &&
      other.conductorType == conductorType &&
      other.phase == phase &&
      other.enabled == enabled &&
      deepJsonEquals(other.metadata, metadata);

  @override
  int get hashCode => Object.hash(
    id,
    fromTerminalId,
    toTerminalId,
    conductorType,
    phase,
    enabled,
    deepJsonHash(metadata),
  );
}
