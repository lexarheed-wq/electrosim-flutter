import 'domain_error.dart';
import 'electrical_types.dart';
import 'electrical_ratings.dart';
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
       parameters = freezeJsonMap(
         _normalizeLegacyProtectionRating(modelType, parameters),
       ),
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

  /// One canonical migration at the model boundary. Before PHYS-Q2 the
  /// 4P breaker and 3P overload relay palette emitted 'ratedCurrentA',
  /// although the AC3 solver consumes ProtectionRating.ratedCurrentKey.
  ///
  /// Normalize older archived/synchronized circuits without modifying
  /// unrelated models. A valid canonical value always takes precedence.
  static Map<String, Object?> _normalizeLegacyProtectionRating(
    String modelType,
    Map<String, Object?> parameters,
  ) {
    if ((modelType != 'breaker_4p' && modelType != 'thermal_overload_3p') ||
        parameters.containsKey(ProtectionRating.ratedCurrentKey)) {
      return parameters;
    }
    final Object? legacy = parameters['ratedCurrentA'];
    if (legacy is! num ||
        !legacy.toDouble().isFinite ||
        legacy.toDouble() <= 0) {
      return parameters;
    }
    return <String, Object?>{
      for (final MapEntry<String, Object?> entry in parameters.entries)
        if (entry.key != 'ratedCurrentA') entry.key: entry.value,
      ProtectionRating.ratedCurrentKey: legacy.toDouble(),
    };
  }

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
    'terminals': terminals
        .map<JsonMap>((Terminal item) => item.toJson())
        .toList(),
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
