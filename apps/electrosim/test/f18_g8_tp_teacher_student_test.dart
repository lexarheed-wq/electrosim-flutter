import 'package:electrosim/runtime/electrosim_tp_session_controller.dart';
import 'package:electrosim_scenarios/electrosim_scenarios.dart';
import 'package:electrosim_tp/electrosim_tp.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'F18 G8 full troubleshooting lifecycle includes diagnosis repair submit grade close and read-only',
    () {
      final QualifiedCatalog catalog = buildF16QualifiedCatalog();
      final ElectroSimTpSessionController teacher =
          ElectroSimTpSessionController(catalog: catalog);
      addTearDown(teacher.dispose);

      expect(teacher.createDraft().lifecycle, TpLifecycle.draft);
      expect(teacher.publish().lifecycle, TpLifecycle.published);

      final TpSession started = teacher.startTeacher();
      expect(started.lifecycle, TpLifecycle.started);
      expect(started.diagnosticSheetVisibleFor(TpRole.student), isTrue);
      expect(started.diagnosticSheetVisibleFor(TpRole.teacher), isFalse);

      teacher.addDiagnosticEntry(
        promptId: 'symptom',
        answer: 'Le récepteur ne fonctionne pas.',
      );
      teacher.addDiagnosticEntry(
        promptId: 'hypothesis',
        answer: 'Une liaison du circuit est absente.',
      );

      final FaultScenarioDefinition scenario = catalog.faultScenarios
          .firstWhere(
            (FaultScenarioDefinition item) =>
                item.id == const FaultScenarioId('FAULT-DC-003'),
          );
      final repaired = scenario.teacherTruth.acceptableRepairs.first.apply(
        teacher.session!.studentCircuit,
      );
      final TpSession repairedSession = teacher.updateStudentCircuit(repaired);
      expect(repairedSession.lifecycle, TpLifecycle.started);

      final TpSession submitted = teacher.submitStudent();
      expect(submitted.lifecycle, TpLifecycle.submitted);
      expect(submitted.readOnly, isTrue);
      expect(submitted.evaluation, isNotNull);

      expect(
        () => teacher.updateStudentCircuit(submitted.studentCircuit),
        throwsStateError,
      );
      expect(
        () => teacher.addDiagnosticEntry(promptId: 'late', answer: 'forbidden'),
        throwsStateError,
      );

      final TpSession evaluated = teacher.evaluateTeacher(score: 91);
      expect(evaluated.lifecycle, TpLifecycle.evaluated);
      expect(evaluated.evaluation!.score, 91);
      expect(evaluated.readOnly, isTrue);

      final TpSession closed = teacher.closeTeacher();
      expect(closed.lifecycle, TpLifecycle.closed);
      expect(closed.evaluation!.score, 91);
      expect(closed.readOnly, isTrue);
    },
  );
}
