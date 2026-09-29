import 'dart:io';

import 'package:electrosim/runtime/electrosim_persistence_controller.dart';
import 'package:electrosim/runtime/electrosim_tp_session_controller.dart';
import 'package:electrosim_storage/electrosim_storage.dart';
import 'package:electrosim_tp/electrosim_tp.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('F17-R8 local persistence', () {
    late Directory temp;
    late ElectroSimPersistenceController persistence;

    setUp(() async {
      temp = await Directory.systemTemp.createTemp('electrosim-f17-r8-');
      final repository = LocalStorageRepository(temp);
      await repository.initialize();
      persistence = ElectroSimPersistenceController(repository);
    });

    tearDown(() async {
      if (await temp.exists()) {
        await temp.delete(recursive: true);
      }
    });

    test('saves and restores circuit workspace and started TP diagnostics',
        () async {
      final originalTp = ElectroSimTpSessionController();
      originalTp.createDraft();
      originalTp.publish();
      final TpSession started = originalTp.startStudent();
      originalTp.addDiagnosticEntry(
        promptId: 'symptom',
        answer: 'La lampe reste éteinte.',
      );

      await persistence.saveWorkspace(
        circuit: started.studentCircuit,
        workspace: 'Recherche de dérangement',
        tpController: originalTp,
      );

      final restoredTp = ElectroSimTpSessionController();
      final restored = await persistence.openLatest(
        tpController: restoredTp,
      );

      expect(restored, isNotNull);
      expect(restored!.workspace, 'Recherche de dérangement');
      expect(restored.circuit, started.studentCircuit);
      expect(restoredTp.lifecycle, TpLifecycle.started);
      expect(restoredTp.studentCircuit, started.studentCircuit);
      expect(
        restoredTp.session!.diagnosticSheet.entries.single.answer,
        'La lampe reste éteinte.',
      );
      expect(restoredTp.readOnly, isFalse);
    });

    test('restores teacher score and read-only evaluated lifecycle', () async {
      final originalTp = ElectroSimTpSessionController();
      originalTp.createDraft();
      originalTp.publish();
      originalTp.startStudent();
      originalTp.submitStudent();
      originalTp.evaluateTeacher(score: 82);

      await persistence.saveWorkspace(
        circuit: originalTp.studentCircuit!,
        workspace: 'Supervision',
        tpController: originalTp,
      );

      final restoredTp = ElectroSimTpSessionController();
      final restored = await persistence.openLatest(
        tpController: restoredTp,
      );

      expect(restored, isNotNull);
      expect(restored!.workspace, 'Supervision');
      expect(restoredTp.lifecycle, TpLifecycle.evaluated);
      expect(restoredTp.evaluation!.score, 82);
      expect(restoredTp.readOnly, isTrue);
    });

    test('new save keeps original creation timestamp on replacement', () async {
      final tp = ElectroSimTpSessionController();
      final first = await persistence.saveWorkspace(
        circuit: tp.createDraft().studentCircuit,
        workspace: 'Câblage',
        tpController: tp,
      );
      await Future<void>.delayed(const Duration(milliseconds: 2));
      final second = await persistence.saveWorkspace(
        circuit: first.circuit,
        workspace: 'Supervision',
        tpController: tp,
      );

      expect(second.createdAtUtc, first.createdAtUtc);
      expect(second.updatedAtUtc.isBefore(first.updatedAtUtc), isFalse);
    });
  });
}
