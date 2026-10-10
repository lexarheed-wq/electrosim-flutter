import 'dart:convert';

import 'package:electrosim/runtime/electrosim_tp_session_controller.dart';
import 'package:electrosim_scenarios/electrosim_scenarios.dart';
import 'package:electrosim_tp/electrosim_tp.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('P2 sequential TP identities and archive persist without recursion', () {
    final controller = ElectroSimTpSessionController();
    addTearDown(controller.dispose);
    controller.createDraft();
    final firstId = controller.tpId.value;
    controller.publish();
    controller.cancelTeacher();
    controller.deleteTeacherActivity();
    expect(controller.hasSession, false);
    expect(controller.teacherArchive.length, 1);
    expect(controller.teacherArchive.first['tpId'], firstId);

    controller.createDraft(
      mode: TpMode.wiring,
      wiringReferenceCircuit: buildV2ProductExampleRepository().all.first.circuit,
    );
    final secondId = controller.tpId.value;
    expect(secondId, isNot(firstId));
    expect(secondId, startsWith(firstId));
    final json = controller.toPersistenceJson();
    expect(() => jsonEncode(json), returnsNormally);
    expect(json['archive'], isA<List>());

    final recovered = ElectroSimTpSessionController();
    addTearDown(recovered.dispose);
    recovered.restoreFromPersistenceJson(json);
    expect(recovered.tpId.value, secondId);
    expect(recovered.session!.definition.mode, TpMode.wiring);
    expect(recovered.teacherArchive.length, 1);
    recovered.deleteArchivedActivity(firstId);
    expect(recovered.teacherArchive, isEmpty);
    expect(recovered.session, isNotNull);
  });

  test('P2 archive and internal reference never enter student LAN snapshot', () {
    final controller = ElectroSimTpSessionController();
    addTearDown(controller.dispose);
    controller.createDraft();
    controller.publish();
    controller.cancelTeacher();
    controller.deleteTeacherActivity();
    controller.createDraft(
      mode: TpMode.wiring,
      wiringReferenceCircuit: buildV2ProductExampleRepository().all.first.circuit,
    );
    controller.publish();
    final public = controller.toStudentPersistenceJson();
    expect(public, isNot(containsPair('referenceCircuit', anything)));
    expect(public.containsKey('archive'), false);
    expect(public.containsKey('nextActivityOrdinal'), false);
    expect(public['tpId'], controller.tpId.value);
  });
}
