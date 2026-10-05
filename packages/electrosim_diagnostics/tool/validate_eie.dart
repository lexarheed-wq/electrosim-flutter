import 'dart:convert';

import 'package:electrosim_diagnostics/electrosim_diagnostics.dart';
import 'package:electrosim_scenarios/electrosim_scenarios.dart';
import 'package:electrosim_solver_dc/electrosim_solver_dc.dart';
import 'package:electrosim_topology/electrosim_topology.dart';

void main() {
  final repository = buildF11FaultScenarioRepository();
  final topologyEngine = const TopologyEngine();
  final solver = const SolverDC();
  final diagnosticEngine = const DiagnosticEngine();
  final rows = <Map<String, Object?>>[];
  var failures = 0;
  for (final scenario in repository.all) {
    final topology = topologyEngine.compile(scenario.faultyCircuit);
    final simulation = solver.solve(scenario.faultyCircuit, topology);
    final report = diagnosticEngine.analyze(
      topology: topology,
      simulation: simulation,
    );
    final evidenceIds = report.evidence.map((item) => item.id).toSet();
    final traceable = report.advice.every(
      (item) =>
          item.evidenceIds.isNotEmpty &&
          item.evidenceIds.every(evidenceIds.contains),
    );
    if (!traceable) failures++;
    rows.add(<String, Object?>{
      'scenarioId': scenario.id.value,
      'status': report.status.name,
      'evidenceCount': report.evidence.length,
      'adviceCount': report.advice.length,
      'traceable': traceable,
    });
  }
  print(
    const JsonEncoder.withIndent('  ').convert(<String, Object?>{
      'phase': 'F13-R1',
      'status': failures == 0 ? 'PASS' : 'FAIL',
      'teacherTruthReferenced': false,
      'scenarios': rows,
    }),
  );
  if (failures != 0) throw StateError('$failures EIE traceability failure(s).');
}
