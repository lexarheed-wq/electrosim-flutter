import 'dart:convert';
import 'dart:io';

import 'package:electrosim_scenarios/electrosim_scenarios.dart';
import 'package:electrosim_storage/electrosim_storage.dart';

Future<void> main() async {
  final Directory temp = await Directory.systemTemp.createTemp(
    'electrosim-f14-validator-',
  );
  try {
    final LocalStorageRepository repository = LocalStorageRepository(temp);
    final circuit = buildF10ExampleRepository().all.first.circuit;
    final SavedCircuitDocument document = SavedCircuitDocument(
      saveId: 'validator-save',
      title: 'F14 validator',
      createdAtUtc: DateTime.utc(2026, 9, 29),
      updatedAtUtc: DateTime.utc(2026, 9, 29),
      circuit: circuit,
      engineVersion: 'validator',
    );
    await repository.save(document);
    final SavedCircuitDocument reopened = await repository.open(
      document.saveId,
    );
    final ExportService exports = const ExportService();
    final Map<String, Object?> report = <String, Object?>{
      'phase': 'F14-R1',
      'roundTrip': reopened.circuit == document.circuit,
      'saveCount': (await repository.listSaves()).length,
      'csvBytes': utf8.encode(exports.toCsv(reopened)).length,
      'pdfBytes': exports.toPdf(reopened).length,
      'schemaVersion': SavedCircuitDocument.currentSchemaVersion,
    };
    if (report['roundTrip'] != true || report['saveCount'] != 1) {
      stderr.writeln(jsonEncode(report));
      exitCode = 1;
      return;
    }
    stdout.writeln(const JsonEncoder.withIndent('  ').convert(report));
  } finally {
    await temp.delete(recursive: true);
  }
}
