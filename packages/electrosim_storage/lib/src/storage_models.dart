import 'dart:convert';

import 'package:electrosim_domain/electrosim_domain.dart';

final class SavedCircuitDocument {
  const SavedCircuitDocument({
    required this.saveId,
    required this.title,
    required this.createdAtUtc,
    required this.updatedAtUtc,
    required this.circuit,
    required this.engineVersion,
  });

  static const int currentSchemaVersion = 1;

  final String saveId;
  final String title;
  final DateTime createdAtUtc;
  final DateTime updatedAtUtc;
  final CircuitState circuit;
  final String engineVersion;

  Map<String, Object?> toJson() => <String, Object?>{
        'schemaVersion': currentSchemaVersion,
        'saveId': saveId,
        'title': title,
        'createdAtUtc': createdAtUtc.toUtc().toIso8601String(),
        'updatedAtUtc': updatedAtUtc.toUtc().toIso8601String(),
        'engineVersion': engineVersion,
        'circuit': circuit.toJson(),
      };

  String toJsonString() => jsonEncode(toJson());

  factory SavedCircuitDocument.fromJsonString(String source) {
    final Object? decoded = jsonDecode(source);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Saved circuit root must be an object.');
    }
    return SavedCircuitDocument.fromJson(decoded);
  }

  factory SavedCircuitDocument.fromJson(Map<String, dynamic> json) {
    final Object? schemaRaw = json['schemaVersion'];
    if (schemaRaw is! int) {
      throw const FormatException('Missing or invalid schemaVersion.');
    }
    if (schemaRaw == 0) {
      return _migrateV0(json);
    }
    if (schemaRaw != currentSchemaVersion) {
      throw FormatException('Unsupported saved circuit schemaVersion: $schemaRaw.');
    }
    return _parseV1(json);
  }

  static SavedCircuitDocument _parseV1(Map<String, dynamic> json) {
    final Object? circuitRaw = json['circuit'];
    if (circuitRaw is! Map<String, dynamic>) {
      throw const FormatException('Missing or invalid circuit payload.');
    }
    final String saveId = _requiredString(json, 'saveId');
    final String title = _requiredString(json, 'title');
    final String engineVersion = _requiredString(json, 'engineVersion');
    final DateTime created = _requiredUtcDate(json, 'createdAtUtc');
    final DateTime updated = _requiredUtcDate(json, 'updatedAtUtc');
    if (updated.isBefore(created)) {
      throw const FormatException('updatedAtUtc cannot precede createdAtUtc.');
    }
    return SavedCircuitDocument(
      saveId: saveId,
      title: title,
      createdAtUtc: created,
      updatedAtUtc: updated,
      engineVersion: engineVersion,
      circuit: CircuitState.fromJson(circuitRaw),
    );
  }

  static SavedCircuitDocument _migrateV0(Map<String, dynamic> json) {
    final Map<String, dynamic> migrated = Map<String, dynamic>.from(json);
    migrated['schemaVersion'] = currentSchemaVersion;
    migrated['title'] = migrated.remove('name') ?? 'Imported circuit';
    migrated['engineVersion'] = migrated['engineVersion'] ?? 'legacy-v0';
    return _parseV1(migrated);
  }

  static String _requiredString(Map<String, dynamic> json, String key) {
    final Object? value = json[key];
    if (value is! String || value.trim().isEmpty) {
      throw FormatException('Missing or invalid $key.');
    }
    return value;
  }

  static DateTime _requiredUtcDate(Map<String, dynamic> json, String key) {
    final String value = _requiredString(json, key);
    final DateTime? parsed = DateTime.tryParse(value);
    if (parsed == null) {
      throw FormatException('Invalid $key.');
    }
    return parsed.toUtc();
  }
}

final class SavedCircuitSummary {
  const SavedCircuitSummary({
    required this.saveId,
    required this.title,
    required this.updatedAtUtc,
    required this.circuitRevision,
  });

  final String saveId;
  final String title;
  final DateTime updatedAtUtc;
  final int circuitRevision;
}
