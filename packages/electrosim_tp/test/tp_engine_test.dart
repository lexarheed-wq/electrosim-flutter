import 'dart:convert';

import 'package:electrosim_scenarios/electrosim_scenarios.dart';
import 'package:electrosim_tp/electrosim_tp.dart';
import 'package:test/test.dart';

void main() {
  group('F12 TP engine', () {
    final scenarios = buildF11FaultScenarioRepository();

    test('troubleshooting follows draft -> published -> started -> submitted -> evaluated -> closed', () {
      final engine = TpEngine(faultScenarios: scenarios);
      final def = TpDefinition.troubleshooting(
        id: TpId('TP-RD-001'), title: 'Recherche de dérangement 1',
        scenarioId: FaultScenarioId('FAULT-DC-001'));
      expect(engine.createDraft(def).lifecycle, TpLifecycle.draft);
      expect(engine.publish(def.id).lifecycle, TpLifecycle.published);
      expect(engine.start(def.id).lifecycle, TpLifecycle.started);
      final scenario = scenarios.findById(def.faultScenarioId!)!;
      final repaired = scenario.teacherTruth.acceptableRepairs.first.apply(engine.get(def.id).studentCircuit);
      engine.updateCircuit(def.id, repaired);
      final submitted = engine.submit(def.id);
      expect(submitted.lifecycle, TpLifecycle.submitted);
      expect(submitted.readOnly, isTrue);
      expect(submitted.evaluation!.score, 100);
      expect(engine.evaluate(def.id).lifecycle, TpLifecycle.evaluated);
      expect(engine.close(def.id).lifecycle, TpLifecycle.closed);
    });

    test('student diagnostic sheet exists only during student troubleshooting', () {
      final engine = TpEngine(faultScenarios: scenarios);
      final def = TpDefinition.troubleshooting(
        id: TpId('TP-RD-002'), title: 'RD diagnostic', scenarioId: FaultScenarioId('FAULT-DC-002'));
      engine.createDraft(def); engine.publish(def.id); final started = engine.start(def.id);
      expect(started.diagnosticSheetVisibleFor(TpRole.student), isTrue);
      expect(started.diagnosticSheetVisibleFor(TpRole.teacher), isFalse);
      engine.addDiagnosticEntry(def.id, const DiagnosticEntry(promptId:'safety',answer:'Source identified'));
      final studentPayload = jsonEncode(engine.get(def.id).payloadFor(TpRole.student));
      final teacherPayload = jsonEncode(engine.get(def.id).payloadFor(TpRole.teacher));
      expect(studentPayload, contains('diagnosticSheet'));
      expect(teacherPayload, isNot(contains('diagnosticSheet')));
      expect(studentPayload, isNot(contains('teacherTruth')));
      expect(studentPayload, isNot(contains('rootCauses')));
    });

    test('submitted TP is read only', () {
      final engine = TpEngine(faultScenarios: scenarios);
      final def = TpDefinition.troubleshooting(
        id: TpId('TP-RD-003'), title: 'RD readonly', scenarioId: FaultScenarioId('FAULT-DC-001'));
      engine.createDraft(def); engine.publish(def.id); engine.start(def.id);
      final scenario = scenarios.findById(def.faultScenarioId!)!;
      engine.updateCircuit(def.id, scenario.teacherTruth.acceptableRepairs.first.apply(engine.get(def.id).studentCircuit));
      final submitted = engine.submit(def.id);
      expect(() => engine.updateCircuit(def.id, submitted.studentCircuit), throwsStateError);
      expect(() => engine.addDiagnosticEntry(def.id, const DiagnosticEntry(promptId:'x',answer:'y')), throwsStateError);
    });

    test('wiring TP has no diagnostic sheet and generates a score on a healthy reference circuit', () {
      final engine = TpEngine(faultScenarios: scenarios);
      final reference = buildF10ExampleRepository().all.first.circuit;
      final def = TpDefinition.wiring(id: TpId('TP-CAB-001'), title: 'Câblage simple', referenceCircuit: reference);
      engine.createDraft(def); engine.publish(def.id); final started = engine.start(def.id);
      expect(started.diagnosticSheetVisibleFor(TpRole.student), isFalse);
      final submitted = engine.submit(def.id);
      expect(submitted.evaluation!.score, 100);
      expect(submitted.readOnly, isTrue);
    });

    test('only one TP can be active at once', () {
      final engine = TpEngine(faultScenarios: scenarios);
      final a = TpDefinition.troubleshooting(id: TpId('TP-RD-004'), title:'A', scenarioId: FaultScenarioId('FAULT-DC-001'));
      final b = TpDefinition.troubleshooting(id: TpId('TP-RD-005'), title:'B', scenarioId: FaultScenarioId('FAULT-DC-002'));
      engine.createDraft(a); engine.publish(a.id); engine.start(a.id);
      engine.createDraft(b); engine.publish(b.id);
      expect(() => engine.start(b.id), throwsStateError);
    });

    test('teacher receives generated score after submission without teacherTruth leaking to student', () {
      final engine = TpEngine(faultScenarios: scenarios);
      final def = TpDefinition.troubleshooting(id: TpId('TP-RD-006'), title:'Scored', scenarioId: FaultScenarioId('FAULT-DC-002'));
      engine.createDraft(def); engine.publish(def.id); engine.start(def.id);
      final scenario = scenarios.findById(def.faultScenarioId!)!;
      engine.updateCircuit(def.id, scenario.teacherTruth.acceptableRepairs.first.apply(engine.get(def.id).studentCircuit));
      engine.submit(def.id);
      final teacher = jsonEncode(engine.get(def.id).payloadFor(TpRole.teacher));
      final student = jsonEncode(engine.get(def.id).payloadFor(TpRole.student));
      expect(teacher, contains('"score":100'));
      expect(student, isNot(contains('teacherTruth')));
      expect(student, isNot(contains('acceptableRepairs')));
    });
    test('teacher can enter a bounded final score after submission', () {
      final engine = TpEngine(faultScenarios: scenarios);
      final def = TpDefinition.troubleshooting(
        id: TpId('TP-RD-007'),
        title: 'Teacher grade',
        scenarioId: FaultScenarioId('FAULT-DC-001'),
      );
      engine.createDraft(def);
      engine.publish(def.id);
      engine.start(def.id);
      final scenario = scenarios.findById(def.faultScenarioId!)!;
      engine.updateCircuit(
        def.id,
        scenario.teacherTruth.acceptableRepairs.first
            .apply(engine.get(def.id).studentCircuit),
      );
      engine.submit(def.id);

      final evaluated = engine.evaluate(def.id, teacherScore: 85);
      expect(evaluated.lifecycle, TpLifecycle.evaluated);
      expect(evaluated.evaluation!.score, 85);
      expect(evaluated.evaluation!.functional, isTrue);

      final engine2 = TpEngine(faultScenarios: scenarios);
      engine2.createDraft(def);
      engine2.publish(def.id);
      engine2.start(def.id);
      engine2.updateCircuit(
        def.id,
        scenario.teacherTruth.acceptableRepairs.first
            .apply(engine2.get(def.id).studentCircuit),
      );
      engine2.submit(def.id);
      expect(
        () => engine2.evaluate(def.id, teacherScore: 101),
        throwsRangeError,
      );
    });

    test('M10 cancellation closes a non-submitted activity without fabricating an evaluation', () {
      final TpEngine engine = TpEngine(faultScenarios: scenarios);
      final TpDefinition def = TpDefinition.troubleshooting(
        id: TpId('TP-RD-CANCEL'),
        title: 'Cancel',
        scenarioId: FaultScenarioId('FAULT-DC-001'),
      );
      engine.createDraft(def);
      engine.publish(def.id);
      engine.start(def.id);
      final TpSession cancelled = engine.cancel(def.id);
      expect(cancelled.lifecycle, TpLifecycle.closed);
      expect(cancelled.evaluation, isNull);
      expect(cancelled.readOnly, isTrue);
      expect(() => engine.submit(def.id), throwsStateError);
    });
  });
}
