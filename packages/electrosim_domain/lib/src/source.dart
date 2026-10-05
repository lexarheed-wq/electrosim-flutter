import 'domain_error.dart';
import 'ids.dart';
import 'json_support.dart';
import 'terminal.dart';

final class SourceInstance {
  SourceInstance({
    required this.id,
    required String modelType,
    required List<Terminal> terminals,
    Map<String, Object?> parameters = const <String, Object?>{},
    this.enabled = true,
  }) : modelType = _validateModelType(modelType),
       terminals = List<Terminal>.unmodifiable(terminals),
       parameters = freezeJsonMap(parameters) {
    final Set<TerminalId> ids = <TerminalId>{};
    for (final Terminal terminal in this.terminals) {
      if (!ids.add(terminal.id)) {
        throw DomainException(
          code: DomainErrorCode.duplicateId,
          message: 'Duplicate terminal ID within source ${id.value}.',
          context: <String, Object?>{'terminalId': terminal.id.value},
        );
      }
    }
  }

  factory SourceInstance.fromJson(JsonMap json) => SourceInstance(
    id: SourceId(requireString(json, 'id')),
    modelType: requireString(json, 'modelType'),
    terminals: requireList(json, 'terminals')
        .map<Terminal>((Object? value) => Terminal.fromJson(value! as JsonMap))
        .toList(growable: false),
    parameters: requireMap(json, 'parameters'),
    enabled: requireBool(json, 'enabled'),
  );

  final SourceId id;
  final String modelType;
  final List<Terminal> terminals;
  final JsonMap parameters;
  final bool enabled;

  static String _validateModelType(String value) {
    if (value.isEmpty || value != value.trim()) {
      throw DomainException(
        code: DomainErrorCode.invalidValue,
        message: 'source modelType must be non-empty and trimmed.',
        context: <String, Object?>{'modelType': value},
      );
    }
    return value;
  }

  JsonMap toJson() => <String, Object?>{
    'id': id.value,
    'modelType': modelType,
    'terminals': terminals
        .map<JsonMap>((Terminal item) => item.toJson())
        .toList(),
    'parameters': parameters,
    'enabled': enabled,
  };

  @override
  bool operator ==(Object other) =>
      other is SourceInstance &&
      other.id == id &&
      other.modelType == modelType &&
      _terminalListEquals(other.terminals, terminals) &&
      deepJsonEquals(other.parameters, parameters) &&
      other.enabled == enabled;

  @override
  int get hashCode => Object.hash(
    id,
    modelType,
    Object.hashAll(terminals),
    deepJsonHash(parameters),
    enabled,
  );
}

bool _terminalListEquals(List<Terminal> a, List<Terminal> b) {
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
