import 'dart:io';

import 'storage_models.dart';

final class LocalStorageRepository {
  LocalStorageRepository(Directory rootDirectory) : _rootDirectory = rootDirectory;

  final Directory _rootDirectory;

  Future<void> initialize() async {
    await _rootDirectory.create(recursive: true);
    await _recoverBackups();
    await _removeAbandonedTemps();
  }

  Future<List<SavedCircuitSummary>> listSaves() async {
    await initialize();
    final List<SavedCircuitSummary> result = <SavedCircuitSummary>[];
    await for (final FileSystemEntity entity in _rootDirectory.list(followLinks: false)) {
      if (entity is! File || !entity.path.endsWith('.electrosim.json')) {
        continue;
      }
      final SavedCircuitDocument document = await _readDocument(entity);
      result.add(SavedCircuitSummary(
        saveId: document.saveId,
        title: document.title,
        updatedAtUtc: document.updatedAtUtc,
        circuitRevision: document.circuit.revision,
      ));
    }
    result.sort((SavedCircuitSummary a, SavedCircuitSummary b) =>
        b.updatedAtUtc.compareTo(a.updatedAtUtc));
    return List<SavedCircuitSummary>.unmodifiable(result);
  }

  Future<SavedCircuitDocument> open(String saveId) async {
    await initialize();
    final File file = _fileFor(saveId);
    if (!await file.exists()) {
      throw FileSystemException('Saved circuit not found.', file.path);
    }
    return _readDocument(file);
  }

  Future<void> save(SavedCircuitDocument document) async {
    await initialize();
    _validateSaveId(document.saveId);
    final File target = _fileFor(document.saveId);
    final File temp = File('${target.path}.tmp');
    final File backup = File('${target.path}.bak');

    await temp.writeAsString(document.toJsonString(), flush: true);
    // Validate bytes before they can replace the current save.
    SavedCircuitDocument.fromJsonString(await temp.readAsString());

    if (await backup.exists()) {
      await backup.delete();
    }
    if (await target.exists()) {
      await target.rename(backup.path);
    }
    try {
      await temp.rename(target.path);
      if (await backup.exists()) {
        await backup.delete();
      }
    } catch (_) {
      if (await target.exists()) {
        await target.delete();
      }
      if (await backup.exists()) {
        await backup.rename(target.path);
      }
      if (await temp.exists()) {
        await temp.delete();
      }
      rethrow;
    }
  }

  Future<void> delete(String saveId) async {
    await initialize();
    final File file = _fileFor(saveId);
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<String> exportJson(String saveId) async => (await open(saveId)).toJsonString();

  Future<void> importJson(String source, {bool overwrite = false}) async {
    final SavedCircuitDocument document = SavedCircuitDocument.fromJsonString(source);
    final File target = _fileFor(document.saveId);
    if (!overwrite && await target.exists()) {
      throw FileSystemException('A save with this ID already exists.', target.path);
    }
    await save(document);
  }

  File _fileFor(String saveId) {
    _validateSaveId(saveId);
    return File('${_rootDirectory.path}/$saveId.electrosim.json');
  }

  static void _validateSaveId(String saveId) {
    final RegExp valid = RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]{0,79}$');
    if (!valid.hasMatch(saveId)) {
      throw ArgumentError.value(saveId, 'saveId', 'Unsafe save identifier.');
    }
  }

  Future<SavedCircuitDocument> _readDocument(File file) async {
    try {
      return SavedCircuitDocument.fromJsonString(await file.readAsString());
    } on FormatException catch (error) {
      throw FileSystemException('Corrupt ElectroSim save: $error', file.path);
    }
  }

  Future<void> _recoverBackups() async {
    await for (final FileSystemEntity entity in _rootDirectory.list(followLinks: false)) {
      if (entity is! File || !entity.path.endsWith('.electrosim.json.bak')) {
        continue;
      }
      final String targetPath = entity.path.substring(0, entity.path.length - 4);
      final File target = File(targetPath);
      if (!await target.exists()) {
        // Recovery is allowed only after the backup itself parses successfully.
        await _readDocument(entity);
        await entity.rename(targetPath);
      } else {
        await entity.delete();
      }
    }
  }

  Future<void> _removeAbandonedTemps() async {
    await for (final FileSystemEntity entity in _rootDirectory.list(followLinks: false)) {
      if (entity is File && entity.path.endsWith('.electrosim.json.tmp')) {
        await entity.delete();
      }
    }
  }
}
