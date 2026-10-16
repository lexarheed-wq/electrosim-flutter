import 'dart:convert';

import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:electrosim_multiphysics/electrosim_multiphysics.dart';

import 'storage_models.dart';

/// Lossless save envelope for a multi-network electrical project.
final class SavedElectricalProjectDocument {
  SavedElectricalProjectDocument({
    required this.saveId,
    required this.title,
    required DateTime createdAtUtc,
    required DateTime updatedAtUtc,
    required this.engineVersion,
    required this.project,
    Map<String, Object?> appState = const <String, Object?>{},
  }) : createdAtUtc = createdAtUtc.toUtc(),
       updatedAtUtc = updatedAtUtc.toUtc(),
       appState = Map<String, Object?>.unmodifiable(appState) {
    if (saveId.trim().isEmpty || title.trim().isEmpty || engineVersion.trim().isEmpty) {
      throw const FormatException('Save id, title and engine version are required.');
    }
    if (this.updatedAtUtc.isBefore(this.createdAtUtc)) {
      throw const FormatException('updatedAtUtc cannot precede createdAtUtc.');
    }
  }

  static const int currentSchemaVersion = 1;
  static const String formatName = 'electrosim-electrical-project';
  final String saveId;
  final String title;
  final DateTime createdAtUtc;
  final DateTime updatedAtUtc;
  final String engineVersion;
  final ElectricalProject project;
  final Map<String, Object?> appState;

  factory SavedElectricalProjectDocument.wrapLegacy(SavedCircuitDocument legacy) =>
      SavedElectricalProjectDocument(
        saveId: legacy.saveId,
        title: legacy.title,
        createdAtUtc: legacy.createdAtUtc,
        updatedAtUtc: legacy.updatedAtUtc,
        engineVersion: legacy.engineVersion,
        appState: legacy.appState,
        project: ElectricalProject.fromLegacyCircuit(legacy.circuit),
      );

  Map<String, Object?> toJson() => <String, Object?>{
    'schemaVersion': currentSchemaVersion,
    'format': formatName,
    'saveId': saveId,
    'title': title,
    'createdAtUtc': createdAtUtc.toIso8601String(),
    'updatedAtUtc': updatedAtUtc.toIso8601String(),
    'engineVersion': engineVersion,
    'appState': appState,
    'project': project.toJson(),
  };
  String toJsonString() => jsonEncode(toJson());

  factory SavedElectricalProjectDocument.fromJsonString(String source) {
    final Object? decoded = jsonDecode(source);
    if (decoded is! Map<String, dynamic>) throw const FormatException('Saved electrical project root must be an object.');
    return SavedElectricalProjectDocument.fromJson(decoded);
  }

  factory SavedElectricalProjectDocument.fromJson(Map<String, dynamic> json) {
    if (json['format'] != formatName) {
      // Delegate all old schemas and migrations to the unchanged legacy codec.
      return SavedElectricalProjectDocument.wrapLegacy(SavedCircuitDocument.fromJson(json));
    }
    final Object? version = json['schemaVersion'];
    if (version != currentSchemaVersion) {
      throw FormatException('Unsupported electrical project schemaVersion: $version.');
    }
    final Object? rawState = json['appState'] ?? const <String, Object?>{};
    if (rawState is! Map<String, dynamic>) throw const FormatException('Invalid appState payload.');
    final Object? rawProject = json['project'];
    if (rawProject is! Map<String, dynamic>) throw const FormatException('Invalid project payload.');
    return SavedElectricalProjectDocument(
      saveId: _requiredString(json, 'saveId'),
      title: _requiredString(json, 'title'),
      createdAtUtc: _requiredDate(json, 'createdAtUtc'),
      updatedAtUtc: _requiredDate(json, 'updatedAtUtc'),
      engineVersion: _requiredString(json, 'engineVersion'),
      appState: rawState,
      project: ElectricalProject.fromJson(rawProject),
    );
  }

  /// Refuses to discard any subnetwork or cross-network coupling.
  Map<String, Object?> toLegacyElectricalJson() {
    if (project.networks.length != 1 || project.relayLinks.isNotEmpty || project.signalLinks.isNotEmpty) {
      throw const FormatException('Cannot export multi-network electrical project: export would lose networks or cross-network links.');
    }
    return SavedCircuitDocument(
      saveId: saveId, title: title, createdAtUtc: createdAtUtc,
      updatedAtUtc: updatedAtUtc, engineVersion: engineVersion,
      circuit: project.networks.single.circuit, appState: appState,
    ).toJson();
  }
}

String _requiredString(Map<String, dynamic> json, String key) {
  final Object? value = json[key];
  if (value is! String || value.trim().isEmpty) throw FormatException('Missing or invalid $key.');
  return value;
}
DateTime _requiredDate(Map<String, dynamic> json, String key) {
  final DateTime? result = DateTime.tryParse(_requiredString(json, key));
  if (result == null) throw FormatException('Invalid $key.');
  return result.toUtc();
}
