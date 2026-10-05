import 'package:electrosim/runtime/electrosim_tp_session_controller.dart';
import 'package:electrosim_tp/electrosim_tp.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'F17-R6 controller executes publish student submit teacher grade close lifecycle',
    () {
      final ElectroSimTpSessionController controller =
          ElectroSimTpSessionController();

      expect(controller.session, isNull);
      expect(controller.createDraft().lifecycle, TpLifecycle.draft);
      expect(controller.publish().lifecycle, TpLifecycle.published);

      final TpSession started = controller.startTeacher();
      expect(started.lifecycle, TpLifecycle.started);
      expect(started.diagnosticSheetVisibleFor(TpRole.student), isTrue);

      final TpSession submitted = controller.submitStudent();
      expect(submitted.lifecycle, TpLifecycle.submitted);
      expect(submitted.readOnly, isTrue);
      expect(submitted.evaluation, isNotNull);

      final TpSession evaluated = controller.evaluateTeacher(score: 73);
      expect(evaluated.lifecycle, TpLifecycle.evaluated);
      expect(evaluated.evaluation!.score, 73);

      final TpSession closed = controller.closeTeacher();
      expect(closed.lifecycle, TpLifecycle.closed);
      expect(closed.readOnly, isTrue);
    },
  );

  test(
    'F17-R6 submitted student circuit cannot be mutated through controller',
    () {
      final ElectroSimTpSessionController controller =
          ElectroSimTpSessionController();
      controller.createDraft();
      controller.publish();
      final TpSession started = controller.startStudent();
      controller.submitStudent();

      expect(
        () => controller.updateStudentCircuit(started.studentCircuit),
        throwsStateError,
      );
    },
  );
  test(
    'M10 teacher can cancel a non-submitted TP and it becomes read-only',
    () {
      final ElectroSimTpSessionController controller =
          ElectroSimTpSessionController();
      controller.createDraft();
      controller.publish();
      controller.startTeacher();

      final TpSession cancelled = controller.cancelTeacher();
      expect(cancelled.lifecycle, TpLifecycle.closed);
      expect(cancelled.evaluation, isNull);
      expect(cancelled.readOnly, isTrue);
      expect(
        () => controller.updateStudentCircuit(cancelled.studentCircuit),
        throwsStateError,
      );
    },
  );
}
