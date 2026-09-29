import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:electrosim_storage/electrosim_storage.dart';
import 'package:path_provider/path_provider.dart';

import 'electrosim_tp_session_controller.dart';

final class ElectroSimRestoredWorkspace {
  const ElectroSimRestoredWorkspace({
    required this.saveId,
    required this.title,
    required this.circuit,
    required this.workspace,
    required this.updatedAtUtc,
  });

  final String saveId;
  final String title;
  final CircuitState circuit;
  final String workspace;
  final DateTime updatedAtUtc;
}

final class ElectroSimPersistenceController {
  ElectroSimPersistenceController(this._repository);

  static const String engineVersion = 'ELECTROSIM2-F17-R8';
  static const String defaultSaveId = 'last-workspace';

  final LocalStorageRepository _repository;

  static Future<ElectroSimPersistenceController> createDefault() async {
    final Directory documents = await getApplicationDocumentsDirectory();
    final Directory root = Directory(
      '${documents.path}${Platform.pathSeparator}ElectroSim${Platform.pathSeparator}saves',
    );
    final LocalStorageRepository repository = LocalStorageRepository(root);
    await repository.initialize();
    return ElectroSimPersistenceController(repository);
  }

  Future<List<SavedCircuitSummary>> listSaves() => _repository.listSaves();

  Future<SavedCircuitDocument> saveWorkspace({
    required CircuitState circuit,
    required String workspace,
    required ElectroSimTpSessionController tpController,
    String saveId = defaultSaveId,
    String title = 'Dernière session ElectroSim',
  }) async {
    final DateTime now = DateTime.now().toUtc();
    DateTime createdAt = now;
    final List<SavedCircuitSummary> existing = await _repository.listSaves();
    final bool alreadyExists =
        existing.any((SavedCircuitSummary item) => item.saveId == saveId);
    if (alreadyExists) {
      // If the existing document is corrupt, propagate the read failure rather
      // than silently replacing data the user may still be able to recover.
      createdAt = (await _repository.open(saveId)).createdAtUtc;
    }

    final SavedCircuitDocument document = SavedCircuitDocument(
      saveId: saveId,
      title: title,
      createdAtUtc: createdAt,
      updatedAtUtc: now,
      circuit: circuit,
      engineVersion: engineVersion,
      appState: <String, Object?>{
        'workspace': workspace,
        'tp': tpController.toPersistenceJson(),
      },
    );
    await _repository.save(document);
    return document;
  }

  Future<ElectroSimRestoredWorkspace> openWorkspace(
    String saveId, {
    required ElectroSimTpSessionController tpController,
  }) async {
    final SavedCircuitDocument document = await _repository.open(saveId);
    final Object? workspaceRaw = document.appState['workspace'];
    final String workspace =
        workspaceRaw is String && workspaceRaw.trim().isNotEmpty
            ? workspaceRaw
            : 'Câblage';

    final Object? tpRaw = document.appState['tp'];
    if (tpRaw is Map<String, dynamic>) {
      tpController.restoreFromPersistenceJson(
        tpRaw.map(
          (String key, dynamic value) => MapEntry<String, Object?>(key, value),
        ),
      );
    } else if (tpRaw is Map<String, Object?>) {
      tpController.restoreFromPersistenceJson(tpRaw);
    } else {
      tpController.restoreFromPersistenceJson(
        const <String, Object?>{'hasSession': false},
      );
    }

    return ElectroSimRestoredWorkspace(
      saveId: document.saveId,
      title: document.title,
      circuit: document.circuit,
      workspace: workspace,
      updatedAtUtc: document.updatedAtUtc,
    );
  }

  Future<ElectroSimRestoredWorkspace?> openLatest({
    required ElectroSimTpSessionController tpController,
  }) async {
    final List<SavedCircuitSummary> saves = await _repository.listSaves();
    if (saves.isEmpty) {
      return null;
    }
    return openWorkspace(saves.first.saveId, tpController: tpController);
  }
}
