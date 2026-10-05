import 'dart:collection';

import 'domain_error.dart';

typedef JsonMap = Map<String, Object?>;

Object? freezeJson(Object? value) {
  if (value == null || value is bool || value is String) {
    return value;
  }
  if (value is num) {
    if (value is double && !value.isFinite) {
      throw DomainException(
        code: DomainErrorCode.invalidJsonValue,
        message: 'JSON numbers must be finite.',
        context: <String, Object?>{'value': value.toString()},
      );
    }
    return value;
  }
  if (value is List<Object?>) {
    return List<Object?>.unmodifiable(value.map<Object?>(freezeJson));
  }
  if (value is Map<String, Object?>) {
    final SplayTreeMap<String, Object?> sorted =
        SplayTreeMap<String, Object?>();
    for (final MapEntry<String, Object?> entry in value.entries) {
      sorted[entry.key] = freezeJson(entry.value);
    }
    return Map<String, Object?>.unmodifiable(sorted);
  }
  throw DomainException(
    code: DomainErrorCode.invalidJsonValue,
    message: 'Unsupported JSON value type: ${value.runtimeType}',
    context: <String, Object?>{'runtimeType': value.runtimeType.toString()},
  );
}

JsonMap freezeJsonMap(Map<String, Object?> value) =>
    freezeJson(value)! as JsonMap;

bool deepJsonEquals(Object? a, Object? b) {
  if (identical(a, b)) {
    return true;
  }
  if (a is List<Object?> && b is List<Object?>) {
    if (a.length != b.length) {
      return false;
    }
    for (var i = 0; i < a.length; i++) {
      if (!deepJsonEquals(a[i], b[i])) {
        return false;
      }
    }
    return true;
  }
  if (a is Map<String, Object?> && b is Map<String, Object?>) {
    if (a.length != b.length || !a.keys.toSet().containsAll(b.keys)) {
      return false;
    }
    for (final String key in a.keys) {
      if (!deepJsonEquals(a[key], b[key])) {
        return false;
      }
    }
    return true;
  }
  return a == b;
}

int deepJsonHash(Object? value) {
  if (value is List<Object?>) {
    return Object.hashAll(value.map<int>(deepJsonHash));
  }
  if (value is Map<String, Object?>) {
    return Object.hashAll(
      value.entries.map<int>(
        (MapEntry<String, Object?> entry) =>
            Object.hash(entry.key, deepJsonHash(entry.value)),
      ),
    );
  }
  return value.hashCode;
}

String requireString(JsonMap json, String field) {
  final Object? value = json[field];
  if (value is! String) {
    return missingField(field, json);
  }
  return value;
}

int requireInt(JsonMap json, String field) {
  final Object? value = json[field];
  if (value is! int) {
    return missingField(field, json);
  }
  return value;
}

bool requireBool(JsonMap json, String field) {
  final Object? value = json[field];
  if (value is! bool) {
    return missingField(field, json);
  }
  return value;
}

JsonMap requireMap(JsonMap json, String field) {
  final Object? value = json[field];
  if (value is! Map<String, Object?>) {
    return missingField(field, json);
  }
  return value;
}

List<Object?> requireList(JsonMap json, String field) {
  final Object? value = json[field];
  if (value is! List<Object?>) {
    return missingField(field, json);
  }
  return value;
}
