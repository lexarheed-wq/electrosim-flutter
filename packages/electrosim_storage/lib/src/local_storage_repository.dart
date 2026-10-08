import 'dart:async';
import 'dart:io';

import 'storage_models.dart';

/// An unreadable save is reported, not deleted or allowed to hide healthy saves.
final class UnreadableSavedCircuit {
  const UnreadableSavedCircuit({
    required this.path,
    required this.reason,
  });

  final String path;
  final String reason;
}

final class LocalStorageRepository {
  LocalStorageRepository(Directory rootDirectory)
    : _rootDirectory = rootDirectory;

  final Directory _rootDirectory;
  // Serialize operations even between repository instances in the same isolate.
  static final Map<String, Future<void>> _directoryOperations =
      <String, Future<void>>{};
  bool _initialized = false;
  int _nextTempId = 0;
  List<UnreadableSavedCircuit> _unreadableSaves =
      const <UnreadableSavedCircuit>[];

  List<UnreadableSavedCircuit> get unreadableSaves => _unreadableSaves;

  Future<T> _exclusive<T>(Future<T> Function() action) async {
    final String path = _rootDirectory.absolute.path;
    final Future<void> previous =
        _directoryOperations[path] ?? Future<void>.value();
    final Completer<void> completed = Completer<void>();
    final Future<void> current = completed.future;
    _directoryOperations[path] = current;
    try {
      await previous;
      return await action();
    } finally {
      completed.complete();
      if (identical(_directoryOperations[path], current)) {
        _directoryOperations.remove(path);
      }
    }
  }

  Future<void> _initializeUnlocked() async {
    await _rootDirectory.create(recursive: true);
    await _recoverBackups();
    await _removeAbandonedTemps();
    _initialized = true;
  }

  Future<void> _ensureInitializedUnlocked() async {
    if (!_initialized) await _initializeUnlocked();
  }

  Future<void> initialize() async {
    await _exclusive(_initializeUnlocked);
  }

  Future<List<SavedCircuitSummary>> listSaves() => _exclusive(() async {
    await _ensureInitializedUnlocked();
    final List<SavedCircuitSummary> result = <SavedCircuitSummary>[];
    final List<UnreadableSavedCircuit> unreadable = <UnreadableSavedCircuit>[];
    await for (final FileSystemEntity entity in _rootDirectory.list(
      followLinks: false,
    )) {
      if (entity is! File || !entity.path.endsWith('.electrosim.json')) {
        continue;
      }
      try {
        final SavedCircuitDocument document = await _readDocument(entity);
        result.add(
          SavedCircuitSummary(
            saveId: document.saveId,
            title: document.title,
            updatedAtUtc: document.updatedAtUtc,
            circuitRevision: document.circuit.revision,
          ),
        );
      } on FileSystemException catch (error) {
        unreadable.add(
          UnreadableSavedCircuit(path: entity.path, reason: error.message),
        );
      }
    }
    _unreadableSaves = List<UnreadableSavedCircuit>.unmodifiable(unreadable);
    result.sort(
      (SavedCircuitSummary a, SavedCircuitSummary b) =>
          b.updatedAtUtc.compareTo(a.updatedAtUtc),
    );
    return List<SavedCircuitSummary>.unmodifiable(result);
  });

  Future<SavedCircuitDocument> open(String saveId) => _exclusive(() async {
    await _ensureInitializedUnlocked();
    final File file = _fileFor(saveId);
    if (!await file.exists()) {
      throw FileSystemException('Saved circuit not found.', file.path);
    }
    return _readDocument(file);
  });

  Future<void> save(SavedCircuitDocument document) => _exclusive(() async {
    await _ensureInitializedUnlocked();
    await _saveUnlocked(document);
  });

  Future<void> _saveUnlocked(SavedCircuitDocument document) async {
    _validateSaveId(document.saveId);
    final File target = _fileFor(document.saveId);
    // Never silently overwrite malformed saves: require explicit recovery.
    if (await target.exists()) await _readDocument(target);
    final File temp = File(
      '${target.path}.tmp-${DateTime.now().microsecondsSinceEpoch}-${_nextTempId++}',
    );
    final File backup = File('${target.path}.bak');
    bool movedOriginalToBackup = false;

    try {
      await temp.writeAsString(document.toJsonString(), flush: true);
      SavedCircuitDocument.fromJsonString(await temp.readAsString());
      if (await backup.exists()) await backup.delete();
      if (await target.exists()) {
        await target.rename(backup.path);
        movedOriginalToBackup = true;
      }
      await temp.rename(target.path);
      if (await backup.exists()) await backup.delete();
    } catch (_) {
      // Keep the original if writing failed before the rename.
      if (movedOriginalToBackup && await backup.exists()) {
        if (await target.exists()) await target.delete();
        await backup.rename(target.path);
      }
      rethrow;
    } finally {
      if (await temp.exists()) await temp.delete();
    }
  }

  Future<void> delete(String saveId) => _exclusive(() async {
    await _ensureInitializedUnlocked();
    final File file = _fileFor(saveId);
    if (await file.exists()) await file.delete();
  });

  Future<String> exportJson(String saveId) async =>
      (await open(saveId)).toJsonString();

  Future<void> importJson(String source, {bool overwrite = false}) =>
      _exclusive(() async {
        await _ensureInitializedUnlocked();
        final SavedCircuitDocument document = SavedCircuitDocument.fromJsonString(
          source,
        );
        final File target = _fileFor(document.saveId);
        if (!overwrite && await target.exists()) {
          throw FileSystemException(
            'A save with this ID already exists.',
            target.path,
          );
        }
        await _saveUnlocked(document);
      });

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
    await for (final FileSystemEntity entity in _rootDirectory.list(
      followLinks: false,
    )) {
      if (entity is! File || !entity.path.endsWith('.electrosim.json.bak')) {
        continue;
      }
      final String targetPath = entity.path.substring(
        0,
        entity.path.length - 4,
      );
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
    await for (final FileSystemEntity entity in _rootDirectory.list(
      followLinks: false,
    )) {
      if (entity is File &&
          (entity.path.endsWith('.electrosim.json.tmp') ||
           entity.path.contains('.electrosim.json.tmp-'))) {
        await entity.delete();
      }
    }
  }
}
