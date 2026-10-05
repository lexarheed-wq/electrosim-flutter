import 'dart:convert';

import 'package:electrosim_scenarios/electrosim_scenarios.dart';
import 'package:electrosim_tp/electrosim_tp.dart';

void main() {
  final scenarios = buildF11FaultScenarioRepository();
  final engine = TpEngine(faultScenarios: scenarios);
  final def = TpDefinition.troubleshooting(
    id: TpId('TP-RD-AUDIT'),
    title: 'F12 audit TP',
    scenarioId: FaultScenarioId('FAULT-DC-001'),
  );
  engine.createDraft(def);
  engine.publish(def.id);
  engine.start(def.id);
  final scenario = scenarios.findById(def.faultScenarioId!)!;
  engine.addDiagnosticEntry(
    def.id,
    const DiagnosticEntry(promptId: 'safety', answer: 'checked'),
  );
  engine.updateCircuit(
    def.id,
    scenario.teacherTruth.acceptableRepairs.first.apply(
      engine.get(def.id).studentCircuit,
    ),
  );
  final submitted = engine.submit(def.id);
  engine.evaluate(def.id);
  final closed = engine.close(def.id);
  final studentPayload = jsonEncode(closed.payloadFor(TpRole.student));
  final leak =
      studentPayload.contains('teacherTruth') ||
      studentPayload.contains('rootCauses') ||
      studentPayload.contains('acceptableRepairs');
  final out = {
    'phase': 'F12-R1',
    'lifecycle': closed.lifecycle.name,
    'readOnly': closed.readOnly,
    'score': submitted.evaluation?.score,
    'teacherTruthLeak': leak,
    'status': (!leak && closed.readOnly && submitted.evaluation?.score == 100)
        ? 'PASS'
        : 'FAIL',
  };
  print(const JsonEncoder.withIndent('  ').convert(out));
  if (out['status'] != 'PASS') throw StateError('F12 validation failed');
}
