import 'package:electrosim_diagnostics/electrosim_diagnostics.dart';
import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:electrosim_measurements/electrosim_measurements.dart';
import 'package:electrosim_solver_dc/electrosim_solver_dc.dart';
import 'package:electrosim_topology/electrosim_topology.dart';

final class ElectroSimRuntimeSnapshot {
  const ElectroSimRuntimeSnapshot({
    required this.circuit,
    required this.topology,
    required this.dc,
    required this.diagnostics,
    this.measurementEngine = const MeasurementEngine(),
  });

  final CircuitState circuit;
  final TopologyGraph topology;
  final DcSolveResult dc;
  final DiagnosticReport diagnostics;
  final MeasurementEngine measurementEngine;

  bool get solved => dc.isSolved;

  MeasurementResult measureVoltage({
    required TerminalId positiveProbe,
    required TerminalId negativeProbe,
  }) => measurementEngine.measure(
    request: MeasurementRequest.voltage(
      positiveProbe: positiveProbe,
      negativeProbe: negativeProbe,
    ),
    circuit: circuit,
    topology: topology,
    simulation: dc,
  );

  MeasurementResult measureCurrent({required String branchId}) =>
      measurementEngine.measure(
        request: MeasurementRequest.current(branchId: branchId),
        circuit: circuit,
        topology: topology,
        simulation: dc,
      );

  MeasurementResult measureResistance({required ComponentId componentId}) =>
      measurementEngine.measure(
        request: MeasurementRequest.resistance(componentId: componentId),
        circuit: circuit,
        topology: topology,
        simulation: dc,
      );
}

final class ElectroSimRuntimeEngine {
  const ElectroSimRuntimeEngine({
    this.topologyEngine = const TopologyEngine(),
    this.solverDC = const SolverDC(),
    this.diagnosticEngine = const DiagnosticEngine(),
    this.measurementEngine = const MeasurementEngine(),
  });

  final TopologyEngine topologyEngine;
  final SolverDC solverDC;
  final DiagnosticEngine diagnosticEngine;
  final MeasurementEngine measurementEngine;

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
      measurementEngine: measurementEngine,
    );
  }
}
