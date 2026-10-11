import 'dart:convert';

import 'package:electrosim_multiphysics/electrosim_multiphysics.dart';
import 'package:electrosim_pneumatic_domain/electrosim_pneumatic_domain.dart';

import 'storage_models.dart';

/// A separate document envelope. Legacy SavedCircuitDocument (schema v2)
/// is NOT modified and cannot silently discard new pneumatic information.
final class SavedMultiphysicsDocument {
  SavedMultiphysicsDocument({
    required this.electricalDocument,
    required this.project,
  }) {
    if (electricalDocument.circuit.toJsonString() !=
        project.electricalCircuit.toJsonString()) {
      throw const FormatException(
        'Electrical circuit in multiphysics project differs from saved circuit.',
      );
    }
  }

  /// Project envelope version, not CircuitState or PneumaticNetwork version.
  static const int currentSchemaVersion = 3;
  static const String formatName = 'electrosim-multiphysics';

  final SavedCircuitDocument electricalDocument;
  final MultiphysicsProject project;

  factory SavedMultiphysicsDocument.wrapElectrical(
    SavedCircuitDocument electrical,
  ) => SavedMultiphysicsDocument(
    electricalDocument: electrical,
    project: MultiphysicsProject(electricalCircuit: electrical.circuit),
  );

  Map<String, Object?> toJson() {
    final Map<String, Object?> fullProject = project.toJson();
    // Never serialize CircuitState twice: one canonical electrical document.
    fullProject.remove('electricalCircuit');
    return <String, Object?>{
      'schemaVersion': currentSchemaVersion,
      'format': formatName,
      'electricalDocument': electricalDocument.toJson(),
      'pneumaticDesign': fullProject,
    };
  }

  String toJsonString() => jsonEncode(toJson());

  factory SavedMultiphysicsDocument.fromJsonString(String source) =>
      SavedMultiphysicsDocument.fromJson(_map(jsonDecode(source)));

  factory SavedMultiphysicsDocument.fromJson(Map<String, dynamic> json) {
    final Object? rawVersion = json['schemaVersion'];
    if (rawVersion is! int) {
      throw const FormatException('Missing multiphysics schemaVersion.');
    }
    // Old documents are delegated to the existing, unchanged decoder.
    if (rawVersion >= 0 && rawVersion <=
        SavedCircuitDocument.currentSchemaVersion) {
      return SavedMultiphysicsDocument.wrapElectrical(
        SavedCircuitDocument.fromJson(json),
      );
    }
    if (rawVersion != currentSchemaVersion) {
      throw FormatException(
        'Unsupported future multiphysics schemaVersion: $rawVersion.',
      );
    }
    if (json['format'] != formatName) {
      throw const FormatException('Unknown multiphysics document format.');
    }
    final SavedCircuitDocument legacy = SavedCircuitDocument.fromJson(
      _map(json['electricalDocument']),
    );
    final Map<String, dynamic> air = _map(json['pneumaticDesign']);
    if (air.containsKey('electricalCircuit')) {
      throw const FormatException(
        'Ambiguous duplicate electrical source in pneumatic design.',
      );
    }
    final Map<String, dynamic> complete = <String, dynamic>{
      ...air,
      'electricalCircuit': legacy.circuit.toJson(),
    };
    final MultiphysicsProject project = MultiphysicsProject.fromJson(complete);
    return SavedMultiphysicsDocument(
      electricalDocument: legacy,
      project: project,
    );
  }

  /// Legacy export is explicitly forbidden if it would drop a pneumatic
  /// device, hose, link, physical device identity or view layout.
  Map<String, Object?> toLegacyElectricalJson() {
    final PneumaticNetwork pneumatic = project.pneumaticNetwork;
    if (pneumatic.devices.isNotEmpty ||
        pneumatic.pipes.isNotEmpty ||
        project.links.isNotEmpty ||
        project.devices.isNotEmpty ||
        project.physicalLayout.isNotEmpty ||
        project.schematicLayout.isNotEmpty) {
      throw const FormatException(
        'Cannot export a mixed project as legacy electrical-only data.',
      );
    }
    return electricalDocument.toJson();
  }
}

Map<String, dynamic> _map(Object? value) {
  if (value is Map<String, dynamic>) return value;
  throw const FormatException('Expected a JSON object.');
}
