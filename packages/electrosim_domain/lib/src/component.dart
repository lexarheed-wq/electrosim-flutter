import 'domain_error.dart';
import 'electrical_types.dart';
import 'ids.dart';
import 'json_support.dart';
import 'terminal.dart';

final class ComponentInstance {
  ComponentInstance({
    required this.id,
    required String modelType,
    required List<Terminal> terminals,
    Map<String, Object?> parameters = const <String, Object?>{},
    this.condition = ComponentCondition.normal,
    Map<String, Object?> controlState = const <String, Object?>{},
  }) : modelType = _validateModelType(modelType),
       terminals = List<Terminal>.unmodifiable(terminals),
       parameters = freezeJsonMap(parameters),
       controlState = freezeJsonMap(controlState) {
    final Set<TerminalId> ids = <TerminalId>{};
    for (final Terminal terminal in this.terminals) {
      if (!ids.add(terminal.id)) {
        throw DomainException(
          code: DomainErrorCode.duplicateId,
          message: 'Duplicate terminal ID within component ${id.value}.',
          context: <String, Object?>{'terminalId': terminal.id.value},
        );
      }
    }
  }

  factory ComponentInstance.fromJson(JsonMap json) => ComponentInstance(
    id: ComponentId(requireString(json, 'id')),
    modelType: requireString(json, 'modelType'),
    terminals: requireList(json, 'terminals')
        .map<Terminal>((Object? value) => Terminal.fromJson(value! as JsonMap))
        .toList(growable: false),
    parameters: requireMap(json, 'parameters'),
    condition: enumByName<ComponentCondition>(
      ComponentCondition.values,
      requireString(json, 'condition'),
      'condition',
    ),
    controlState: requireMap(json, 'controlState'),
  );

  final ComponentId id;
  final String modelType;
  final List<Terminal> terminals;
  final JsonMap parameters;
  final ComponentCondition condition;
  final JsonMap controlState;

  static String _validateModelType(String value) {
    if (value.isEmpty || value != value.trim()) {
      throw DomainException(
        code: DomainErrorCode.invalidValue,
        message: 'modelType must be non-empty and trimmed.',
        context: <String, Object?>{'modelType': value},
      );
    }
    return value;
  }

  JsonMap toJson() => <String, Object?>{
    'id': id.value,
    'modelType': modelType,
    'terminals': terminals.map<JsonMap>((Terminal item) => item.toJson()).toList(),
    'parameters': parameters,
    'condition': condition.name,
    'controlState': controlState,
  };

  @override
  bool operator ==(Object other) =>
      other is ComponentInstance &&
      other.id == id &&
      other.modelType == modelType &&
      _terminalListEquals(other.terminals, terminals) &&
      deepJsonEquals(other.parameters, parameters) &&
      other.condition == condition &&
      deepJsonEquals(other.controlState, controlState);

  @override
  int get hashCode => Object.hash(
    id,
    modelType,
    Object.hashAll(terminals),
    deepJsonHash(parameters),
    condition,
    deepJsonHash(controlState),
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
