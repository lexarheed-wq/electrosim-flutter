import 'electrical_types.dart';
import 'ids.dart';
import 'json_support.dart';

final class Terminal {
  Terminal({
    required this.id,
    required this.name,
    this.role = TerminalRole.generic,
    this.phase = PhaseTag.none,
    Map<String, Object?> metadata = const <String, Object?>{},
  }) : metadata = freezeJsonMap(metadata);

  factory Terminal.fromJson(JsonMap json) => Terminal(
    id: TerminalId(requireString(json, 'id')),
    name: requireString(json, 'name'),
    role: enumByName<TerminalRole>(
      TerminalRole.values,
      requireString(json, 'role'),
      'role',
    ),
    phase: enumByName<PhaseTag>(
      PhaseTag.values,
      requireString(json, 'phase'),
      'phase',
    ),
    metadata: requireMap(json, 'metadata'),
  );

  final TerminalId id;
  final String name;
  final TerminalRole role;
  final PhaseTag phase;
  final JsonMap metadata;

  JsonMap toJson() => <String, Object?>{
    'id': id.value,
    'name': name,
    'role': role.name,
    'phase': phase.name,
    'metadata': metadata,
  };

  @override
  bool operator ==(Object other) =>
      other is Terminal &&
      other.id == id &&
      other.name == name &&
      other.role == role &&
      other.phase == phase &&
      deepJsonEquals(other.metadata, metadata);

  @override
  int get hashCode => Object.hash(id, name, role, phase, deepJsonHash(metadata));
}
