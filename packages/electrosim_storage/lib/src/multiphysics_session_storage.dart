import 'dart:convert';

import 'package:electrosim_multiphysics/electrosim_multiphysics.dart';

import 'multiphysics_storage.dart';
import 'storage_models.dart';

/// Saves a design transaction with exactly one canonical electric circuit.
/// Runtime gas/coil state intentionally remains separate from design history.
final class MultiphysicsSessionStorage {
  const MultiphysicsSessionStorage();

  String exportProject({
    required PneumaticWorkshopSession session,
    required SavedCircuitDocument electricalDocument,
  }) {
    final MultiphysicsProject project = session.state.project;
    if (electricalDocument.circuit.toJsonString() !=
        project.electricalCircuit.toJsonString()) {
      throw const FormatException(
        'Cannot save an editor revision with a different electrical circuit.',
      );
    }
    final SavedMultiphysicsDocument document = SavedMultiphysicsDocument(
      electricalDocument: electricalDocument,
      project: project,
    );
    return document.toJsonString();
  }

  /// Imports v0/v1/v2 electrical files or v3 mixed designs with no lossy
  /// fallback. Every input is parsed before an existing session is replaced.
  PneumaticWorkshopSession importProject(
    String source, {
    int historyCapacity = 100,
  }) {
    final SavedMultiphysicsDocument restored =
        SavedMultiphysicsDocument.fromJsonString(source);
    return PneumaticWorkshopSession(
      restored.project,
      historyCapacity: historyCapacity,
    );
  }

  /// Computes lossless normalized JSON for round-trip verification. This is
  /// intentionally not a way to coerce invalid or unsupported future formats.
  bool sameDesign(String first, String second) {
    final SavedMultiphysicsDocument a =
        SavedMultiphysicsDocument.fromJsonString(first);
    final SavedMultiphysicsDocument b =
        SavedMultiphysicsDocument.fromJsonString(second);
    return jsonEncode(a.toJson()) == jsonEncode(b.toJson());
  }
}
