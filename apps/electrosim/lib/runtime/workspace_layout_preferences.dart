import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Independent native UI preferences, never a circuit document.
final class WorkspaceLayoutPreferences {
  WorkspaceLayoutPreferences(this.file);
  final File file;
  static final Map<String, Future<void>> _pending = {};
  static int _temporaryId = 0;

  static Future<WorkspaceLayoutPreferences> createDefault() async {
    final root = await getApplicationSupportDirectory();
    return WorkspaceLayoutPreferences(
      File(
        '${root.path}${Platform.pathSeparator}ElectroSim${Platform.pathSeparator}workspace-layout-v1.json',
      ),
    );
  }

  Future<Map<String, Object?>?> load() async {
    try {
      final data = jsonDecode(await file.readAsString());
      return data is Map<String, dynamic>
          ? Map<String, Object?>.from(data)
          : null;
    } on FileSystemException {
      return null;
    } on FormatException {
      return null;
    }
  }

  Future<void> save(Map<String, Object?> state) {
    // Snapshot now, before callers can mutate the data during another write.
    final encoded = jsonEncode(state);
    final key = file.absolute.path;
    final previous = _pending[key] ?? Future<void>.value();
    final write = previous.then((_) async {
      final temp = File('$key.tmp-${++_temporaryId}');
      try {
        await file.parent.create(recursive: true);
        await temp.writeAsString(encoded, flush: true);
        await temp.rename(key);
      } finally {
        if (await temp.exists()) await temp.delete();
      }
    });
    final tail = write.then<void>(
      (_) {},
      onError: (Object error, StackTrace stack) {},
    );
    _pending[key] = tail;
    tail.then((_) {
      if (identical(_pending[key], tail)) _pending.remove(key);
    });
    return write;
  }
}
