import 'dart:convert';
import 'dart:io';

import 'package:electrosim_scenarios/electrosim_scenarios.dart';
import 'package:electrosim_storage/electrosim_storage.dart';
import 'package:test/test.dart';

SavedCircuitDocument _document({
  String saveId = 'save-001',
  String title = 'Circuit de test',
  DateTime? updated,
}) {
  final circuit = buildF10ExampleRepository().all.first.circuit;
  final DateTime created = DateTime.utc(2026, 9, 29, 12);
  return SavedCircuitDocument(
    saveId: saveId,
    title: title,
    createdAtUtc: created,
    updatedAtUtc: updated ?? created,
    circuit: circuit,
    engineVersion: 'F14-test-engine',
  );
}

void main() {
  group('F14 SavedCircuitDocument', () {
    test('round-trip preserves circuit and metadata', () {
      final SavedCircuitDocument original = _document();
      final SavedCircuitDocument decoded =
          SavedCircuitDocument.fromJsonString(original.toJsonString());
      expect(decoded.saveId, original.saveId);
      expect(decoded.title, original.title);
      expect(decoded.createdAtUtc, original.createdAtUtc);
      expect(decoded.updatedAtUtc, original.updatedAtUtc);
      expect(decoded.engineVersion, original.engineVersion);
      expect(decoded.circuit, original.circuit);
    });

    test('schema v0 migrates explicitly to current schema', () {
      final Map<String, dynamic> json = jsonDecode(_document().toJsonString());
      json['schemaVersion'] = 0;
      json['name'] = json.remove('title');
      json.remove('engineVersion');
      final SavedCircuitDocument migrated = SavedCircuitDocument.fromJson(json);
      expect(migrated.title, 'Circuit de test');
      expect(migrated.engineVersion, 'legacy-v0');
    });

    test('unsupported schema is rejected', () {
      final Map<String, dynamic> json = jsonDecode(_document().toJsonString());
      json['schemaVersion'] = 999;
      expect(() => SavedCircuitDocument.fromJson(json), throwsFormatException);
    });
  });

  group('F14 LocalStorageRepository', () {
    late Directory temp;
    late LocalStorageRepository repository;

    setUp(() async {
      temp = await Directory.systemTemp.createTemp('electrosim-storage-test-');
      repository = LocalStorageRepository(temp);
      await repository.initialize();
    });

    tearDown(() async {
      if (await temp.exists()) await temp.delete(recursive: true);
    });

    test('supports multiple explicit saves and explicit open', () async {
      await repository.save(_document(saveId: 'alpha', title: 'Alpha'));
      await repository.save(_document(
        saveId: 'beta',
        title: 'Beta',
        updated: DateTime.utc(2026, 9, 29, 13),
      ));
      final List<SavedCircuitSummary> saves = await repository.listSaves();
      expect(saves.map((SavedCircuitSummary e) => e.saveId), <String>['beta', 'alpha']);
      expect((await repository.open('alpha')).title, 'Alpha');
      expect((await repository.open('beta')).title, 'Beta');
    });

    test('save updates an existing save atomically', () async {
      await repository.save(_document(saveId: 'same', title: 'Before'));
      await repository.save(_document(
        saveId: 'same',
        title: 'After',
        updated: DateTime.utc(2026, 9, 29, 14),
      ));
      expect((await repository.open('same')).title, 'After');
      expect(await File('${temp.path}/same.electrosim.json.bak').exists(), isFalse);
      expect(await File('${temp.path}/same.electrosim.json.tmp').exists(), isFalse);
    });

    test('recovers a valid backup after an interrupted replacement', () async {
      final File backup = File('${temp.path}/recover.electrosim.json.bak');
      await backup.writeAsString(_document(saveId: 'recover').toJsonString());
      await repository.initialize();
      expect((await repository.open('recover')).saveId, 'recover');
      expect(await backup.exists(), isFalse);
    });

    test('removes abandoned temp files without treating them as saves', () async {
      final File abandoned = File('${temp.path}/ghost.electrosim.json.tmp');
      await abandoned.writeAsString('partial');
      await repository.initialize();
      expect(await abandoned.exists(), isFalse);
      expect(await repository.listSaves(), isEmpty);
    });

    test('import does not overwrite silently', () async {
      final String source = _document(saveId: 'imported').toJsonString();
      await repository.importJson(source);
      await expectLater(repository.importJson(source), throwsA(isA<FileSystemException>()));
      await repository.importJson(
        _document(saveId: 'imported', title: 'Replacement').toJsonString(),
        overwrite: true,
      );
      expect((await repository.open('imported')).title, 'Replacement');
    });

    test('unsafe save IDs cannot escape the save directory', () async {
      await expectLater(repository.open('../escape'), throwsArgumentError);
      await expectLater(repository.save(_document(saveId: '../escape')), throwsArgumentError);
    });
  });

  group('F14 ExportService', () {
    const ExportService exports = ExportService();

    test('CSV is a separate explicit export', () {
      final String csv = exports.toCsv(_document());
      expect(csv, contains('"saveId","save-001"'));
      expect(csv, contains('"revision"'));
    });

    test('PDF export produces a standalone PDF document', () {
      final List<int> pdf = exports.toPdf(_document());
      expect(utf8.decode(pdf.take(8).toList()), startsWith('%PDF-1.4'));
      expect(utf8.decode(pdf, allowMalformed: true), contains('ElectroSim - Saved circuit'));
      expect(utf8.decode(pdf, allowMalformed: true), endsWith('%%EOF\n'));
    });
  });
}
