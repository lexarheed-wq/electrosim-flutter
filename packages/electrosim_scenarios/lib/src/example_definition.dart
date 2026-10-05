import 'dart:convert';

import 'package:electrosim_domain/electrosim_domain.dart';

typedef ExampleMetadata = Map<String, Object?>;

final class CircuitTemplateId {
  CircuitTemplateId(String raw) : value = _validate(raw);
  final String value;

  static String _validate(String raw) {
    final String value = raw.trim();
    if (value.isEmpty || !RegExp(r'^[A-Z0-9][A-Z0-9_-]{2,63}$').hasMatch(value)) {
      throw ArgumentError.value(raw, 'raw', 'Invalid CircuitTemplateId.');
    }
    return value;
  }

  @override
  bool operator ==(Object other) => other is CircuitTemplateId && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}

final class ExampleValidationStamp {
  const ExampleValidationStamp({
    required this.validatorVersion,
    required this.circuitSchemaVersion,
    required this.contentDigestFnv1a64,
  });

  final String validatorVersion;
  final int circuitSchemaVersion;
  final String contentDigestFnv1a64;
}

final class ExampleDefinition {
  ExampleDefinition({
    required this.id,
    required String title,
    required String description,
    required this.circuit,
    ExampleMetadata metadata = const <String, Object?>{},
    this.validationStamp,
  }) : title = _cleanText(title, 'title'),
       description = _cleanText(description, 'description'),
       metadata = Map<String, Object?>.unmodifiable(metadata);

  final CircuitTemplateId id;
  final String title;
  final String description;
  final CircuitState circuit;
  final ExampleMetadata metadata;
  final ExampleValidationStamp? validationStamp;

  ExampleDefinition withValidationStamp(ExampleValidationStamp stamp) => ExampleDefinition(
    id: id,
    title: title,
    description: description,
    circuit: circuit,
    metadata: metadata,
    validationStamp: stamp,
  );

  String canonicalPayload() {
    final Map<String, Object?> payload = <String, Object?>{
      'id': id.value,
      'title': title,
      'description': description,
      'circuit': circuit.toJson(),
      'metadata': metadata,
    };
    return jsonEncode(payload);
  }

  static String _cleanText(String value, String field) {
    final String clean = value.trim();
    if (clean.isEmpty) {
      throw ArgumentError.value(value, field, '$field must not be empty.');
    }
    return clean;
  }
}
