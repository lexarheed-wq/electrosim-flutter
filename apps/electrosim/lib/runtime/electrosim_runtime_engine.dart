import 'package:electrosim_diagnostics/electrosim_diagnostics.dart';
import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:electrosim_solver_dc/electrosim_solver_dc.dart';
import 'package:electrosim_topology/electrosim_topology.dart';

final class ElectroSimRuntimeSnapshot {
  const ElectroSimRuntimeSnapshot({
    required this.circuit,
    required this.topology,
    required this.dc,
    required this.diagnostics,
  });

  final CircuitState circuit;
  final TopologyGraph topology;
  final DcSolveResult dc;
  final DiagnosticReport diagnostics;

  bool get solved => dc.isSolved;
}

final class ElectroSimRuntimeEngine {
  const ElectroSimRuntimeEngine({
    this.topologyEngine = const TopologyEngine(),
    this.solverDC = const SolverDC(),
    this.diagnosticEngine = const DiagnosticEngine(),
  });

  final TopologyEngine topologyEngine;
  final SolverDC solverDC;
  final DiagnosticEngine diagnosticEngine;

  ElectroSimRuntimeSnapshot evaluate(CircuitState circuit) {
    final TopologyGraph topology = topologyEngine.compile(circuit);
    final DcSolveResult dc = solverDC.solve(circuit, topology);
    final DiagnosticReport diagnostics = diagnosticEngine.analyze(
      topology: topology,
      simulation: dc,
    );
    return ElectroSimRuntimeSnapshot(
      circuit: circuit,
      topology: topology,
      dc: dc,
      diagnostics: diagnostics,
    );
  }
}
