import 'dart:io';

import 'package:electrosim_scenarios/electrosim_scenarios.dart';
import 'package:electrosim_storage/electrosim_storage.dart';
import 'package:test/test.dart';

SavedCircuitDocument _document(String id, {String title = 'Circuit'}) {
  final DateTime timestamp = DateTime.utc(2026, 10, 8);
  return SavedCircuitDocument(
    saveId: id,
    title: title,
    createdAtUtc: timestamp,
    updatedAtUtc: timestamp,
    circuit: buildF10ExampleRepository().all.first.circuit,
    engineVersion: 'audit-r3',
  );
}

void main() {
  test('12 concurrent saves of one document do not collide', () async {
    final Directory root = await Directory.systemTemp.createTemp('es-audit-save-');
    addTearDown(() => root.delete(recursive: true));
    final LocalStorageRepository repository = LocalStorageRepository(root);
    await repository.save(_document('same', title: 'Before'));
    await Future.wait(<Future<void>>[
      for (int index = 0; index < 12; index++)
        repository.save(_document('same', title: 'Revision $index')),
    ]);
    expect((await repository.open('same')).title, 'Revision 11');
    expect(
      await File('${root.path}/same.electrosim.json.bak').exists(),
      isFalse,
    );
  });

  test('save, open, list and initialize are serialized', () async {
    final Directory root = await Directory.systemTemp.createTemp('es-audit-overlap-');
    addTearDown(() => root.delete(recursive: true));
    final LocalStorageRepository repository = LocalStorageRepository(root);
    await repository.save(_document('same', title: 'Before'));
    await Future.wait<Object>(<Future<Object>>[
      repository.save(_document('same', title: 'After')).then((_) => true),
      repository.listSaves(),
      repository.open('same'),
      repository.initialize().then((_) => true),
    ]);
    expect((await repository.open('same')).title, 'After');
  });

  test('damaged save does not block healthy saves or get overwritten', () async {
    final Directory root = await Directory.systemTemp.createTemp('es-audit-corrupt-');
    addTearDown(() => root.delete(recursive: true));
    final LocalStorageRepository repository = LocalStorageRepository(root);
    await repository.save(_document('healthy'));
    final File broken = File('${root.path}/broken.electrosim.json');
    await broken.writeAsString('{invalid');

    final List<SavedCircuitSummary> valid = await repository.listSaves();
    expect(valid.map((SavedCircuitSummary s) => s.saveId), contains('healthy'));
    expect(repository.unreadableSaves, hasLength(1));
    expect(repository.unreadableSaves.single.path, broken.path);

    await repository.save(_document('second'));
    await expectLater(
      repository.save(_document('broken')),
      throwsA(isA<FileSystemException>()),
    );
    expect(await broken.readAsString(), '{invalid');
  });
}
