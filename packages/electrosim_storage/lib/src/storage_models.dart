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
    this.appState = const <String, Object?>{},
  });

  static const int currentSchemaVersion = 2;

  final String saveId;
  final String title;
  final DateTime createdAtUtc;
  final DateTime updatedAtUtc;
  final CircuitState circuit;
  final String engineVersion;

  /// Opaque, JSON-compatible application state.
  ///
  /// The storage package deliberately does not interpret this payload. Runtime
  /// layers may use it to restore UI/session state without duplicating file I/O
  /// or making storage depend on TP/application packages.
  final Map<String, Object?> appState;

  Map<String, Object?> toJson() => <String, Object?>{
        'schemaVersion': currentSchemaVersion,
        'saveId': saveId,
        'title': title,
        'createdAtUtc': createdAtUtc.toUtc().toIso8601String(),
        'updatedAtUtc': updatedAtUtc.toUtc().toIso8601String(),
        'engineVersion': engineVersion,
        'circuit': circuit.toJson(),
        'appState': appState,
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
    if (schemaRaw == 1) {
      return _migrateV1(json);
    }
    if (schemaRaw != currentSchemaVersion) {
      throw FormatException('Unsupported saved circuit schemaVersion: $schemaRaw.');
    }
    return _parseV2(json);
  }

  static SavedCircuitDocument _parseV2(Map<String, dynamic> json) {
    final Object? circuitRaw = json['circuit'];
    if (circuitRaw is! Map<String, dynamic>) {
      throw const FormatException('Missing or invalid circuit payload.');
    }
    final Object? appStateRaw = json['appState'] ?? const <String, Object?>{};
    if (appStateRaw is! Map<String, dynamic>) {
      throw const FormatException('Missing or invalid appState payload.');
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
      appState: Map<String, Object?>.unmodifiable(
        appStateRaw.map(
          (String key, dynamic value) => MapEntry<String, Object?>(key, value),
        ),
      ),
    );
  }

  static SavedCircuitDocument _migrateV1(Map<String, dynamic> json) {
    final Map<String, dynamic> migrated = Map<String, dynamic>.from(json);
    migrated['schemaVersion'] = currentSchemaVersion;
    migrated['appState'] = const <String, Object?>{};
    return _parseV2(migrated);
  }

  static SavedCircuitDocument _migrateV0(Map<String, dynamic> json) {
    final Map<String, dynamic> migrated = Map<String, dynamic>.from(json);
    migrated['schemaVersion'] = currentSchemaVersion;
    migrated['title'] = migrated.remove('name') ?? 'Imported circuit';
    migrated['engineVersion'] = migrated['engineVersion'] ?? 'legacy-v0';
    migrated['appState'] = const <String, Object?>{};
    return _parseV2(migrated);
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
