import 'dart:io';

import 'package:electrosim_storage/electrosim_storage.dart';
import 'package:electrosim_tp/electrosim_tp.dart';
import 'package:electrosim_ui_kit/electrosim_ui_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:electrosim/main.dart';
import 'package:electrosim/runtime/electrosim_persistence_controller.dart';
import 'package:electrosim/runtime/electrosim_tp_session_controller.dart';

Future<void> _openTop(WidgetTester tester) async {
  final Finder region = find.byKey(electroSimTopRegionKey);
  if (region.evaluate().isEmpty ||
      tester.getRect(region).bottom <= 0) {
    await tester.tap(find.byKey(electroSimTopEdgeKey));
    await tester.pumpAndSettle();
  }
}

void main() {
  group('F17-R8 local persistence', () {
    late Directory temp;
    late ElectroSimPersistenceController persistence;

    setUp(() async {
      temp = await Directory.systemTemp.createTemp('electrosim-r8-');
      final LocalStorageRepository repository = LocalStorageRepository(temp);
      await repository.initialize();
      persistence = ElectroSimPersistenceController(repository);
    });

    tearDown(() async {
      if (await temp.exists()) {
        await temp.delete(recursive: true);
      }
    });

    test('restores circuit revision, workspace and TP lifecycle', () async {
      final ElectroSimTpSessionController source =
          ElectroSimTpSessionController();
      source.createDraft();
      source.publish();
      source.startStudent();
      source.addDiagnosticEntry(
        promptId: 'hypothesis',
        answer: 'Branche ouverte vérifiée au voltmètre.',
      );
      source.submitStudent();
      source.evaluateTeacher(score: 78);

      final savedCircuit = source.studentCircuit!;
      final saved = await persistence.saveWorkspace(
        circuit: savedCircuit,
        workspace: 'Supervision',
        tpController: source,
      );

      expect(saved.circuit.revision, savedCircuit.revision);

      final ElectroSimTpSessionController restoredTp =
          ElectroSimTpSessionController();
      final restored = await persistence.openLatest(
        tpController: restoredTp,
      );

      expect(restored, isNotNull);
      expect(restored!.workspace, 'Supervision');
      expect(restored.circuit, savedCircuit);
      expect(restored.circuit.revision, savedCircuit.revision);
      expect(restoredTp.lifecycle, TpLifecycle.evaluated);
      expect(restoredTp.evaluation?.score, 78);
      expect(
        restoredTp.session!.diagnosticSheet.entries.single.answer,
        'Branche ouverte vérifiée au voltmètre.',
      );
    });

    test('explicit update preserves original creation time', () async {
      final ElectroSimTpSessionController tp =
          ElectroSimTpSessionController();
      tp.createDraft();
      final first = await persistence.saveWorkspace(
        circuit: tp.studentCircuit!,
        workspace: 'Câblage',
        tpController: tp,
      );
      await Future<void>.delayed(const Duration(milliseconds: 2));
      final second = await persistence.saveWorkspace(
        circuit: first.circuit,
        workspace: 'Recherche de dérangement',
        tpController: tp,
      );

      expect(second.createdAtUtc, first.createdAtUtc);
      expect(second.updatedAtUtc.isBefore(first.updatedAtUtc), isFalse);
      expect((await persistence.listSaves()).length, 1);
    });

    testWidgets('workspace exposes explicit save and resume actions',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: F9WorkspaceDemoPage(
            persistenceController: persistence,
          ),
        ),
      );

      expect(
        find.byKey(const Key('workspace-more-actions')),
        findsOneWidget,
      );
      await _openTop(tester);
      await tester.tap(find.byKey(const Key('workspace-more-actions')));
      await tester.pumpAndSettle();

      final Finder saveAction =
          find.byKey(const Key('workspace-save-action'));
      final Finder openAction =
          find.byKey(const Key('workspace-open-action'));
      expect(saveAction, findsOneWidget);
      expect(openAction, findsOneWidget);
      expect(find.text('Sauvegarder'), findsOneWidget);
      expect(find.text('Reprendre'), findsOneWidget);
    });
  });
}
