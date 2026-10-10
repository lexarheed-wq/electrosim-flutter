import 'dart:convert';

import 'package:electrosim/runtime/electrosim_tp_session_controller.dart';
import 'package:electrosim_scenarios/electrosim_scenarios.dart';
import 'package:electrosim_tp/electrosim_tp.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('P0 published wiring TP never exposes the teacher reference to student',
      () {
    final teacher = ElectroSimTpSessionController();
    final circuit = buildV2ProductExampleRepository().all.first.circuit;
    teacher.createDraft(
      mode: TpMode.wiring,
      wiringReferenceCircuit: circuit,
    );
    teacher.publish();
    addTearDown(teacher.dispose);

    expect(teacher.session!.definition.referenceCircuit, isNotNull);
    expect(teacher.session!.studentCircuit.components, isEmpty);
    expect(teacher.session!.studentCircuit.connections, isEmpty);
    final publicState = teacher.toStudentPersistenceJson();
    expect(publicState.containsKey('referenceCircuit'), isFalse);
    expect(jsonEncode(publicState), isNot(contains('referenceCircuit')));
    expect(publicState.containsKey('teacherScore'), isFalse);

    final student = ElectroSimTpSessionController();
    addTearDown(student.dispose);
    student.restoreFromPersistenceJson(publicState);
    expect(student.session!.definition.referenceCircuit, isNull);
    expect(student.session!.studentCircuit.components, isEmpty);
    expect(student.session!.studentCircuit.connections, isEmpty);
    expect(student.lifecycle, TpLifecycle.published);
  });

  test('P1 default TP scenarios are native V2, not F16 bootstrap fixtures', () {
    final controller = ElectroSimTpSessionController();
    addTearDown(controller.dispose);
    expect(controller.availableFaultScenarios, isNotEmpty);
    expect(
      controller.availableFaultScenarios
          .every((scenario) => scenario.faultyCircuit.metadata['origin'] ==
              'v2-native'),
      isTrue,
    );
    controller.createDraft(mode: TpMode.troubleshooting);
    expect(
      controller.session!.definition.faultScenarioId!.value,
      startsWith('V2-FAULT-'),
    );
  });
}
