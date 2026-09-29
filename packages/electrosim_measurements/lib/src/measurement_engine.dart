import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:electrosim_solver_dc/electrosim_solver_dc.dart';
import 'package:electrosim_topology/electrosim_topology.dart';

import 'measurement_models.dart';

final class MeasurementEngine {
  const MeasurementEngine({this.zeroTolerance = 1e-9});

  final double zeroTolerance;

  MeasurementResult measure({
    required MeasurementRequest request,
    required CircuitState circuit,
    required TopologyGraph topology,
    required DcSolveResult simulation,
  }) {
    final MeasurementResult? preflight = _preflight(
      request: request,
      circuit: circuit,
      topology: topology,
      simulation: simulation,
    );
    if (preflight != null) {
      return preflight;
    }

    switch (request.kind) {
      case MeasurementKind.voltageDc:
        return _measureVoltage(request, topology, simulation);
      case MeasurementKind.currentDc:
        return _measureCurrent(request, simulation);
      case MeasurementKind.resistance:
        return _measureResistance(request, circuit);
    }
  }

  MeasurementResult? _preflight({
    required MeasurementRequest request,
    required CircuitState circuit,
    required TopologyGraph topology,
    required DcSolveResult simulation,
  }) {
    if (circuit.mode != ElectricalMode.dc || topology.mode != ElectricalMode.dc) {
      return MeasurementResult.invalid(
        kind: request.kind,
        errorCode: MeasurementErrorCode.wrongElectricalMode,
        message: 'F4 MeasurementEngine supports DC measurements only.',
      );
    }
    if (topology.circuitId != circuit.circuitId ||
        topology.circuitRevision != circuit.revision ||
        simulation.circuitId != circuit.circuitId ||
        simulation.circuitRevision != circuit.revision) {
      return MeasurementResult.invalid(
        kind: request.kind,
        errorCode: MeasurementErrorCode.identityMismatch,
        message: 'CircuitState, TopologyGraph and DcSolveResult must share identity and revision.',
      );
    }
    if (!simulation.isSolved) {
      return MeasurementResult.invalid(
        kind: request.kind,
        errorCode: MeasurementErrorCode.simulationNotSolved,
        message: 'A measurement cannot be reported from an unsolved DC result.',
      );
    }
    return null;
  }

  MeasurementResult _measureVoltage(
    MeasurementRequest request,
    TopologyGraph topology,
    DcSolveResult simulation,
  ) {
    final TerminalId positive = request.positiveProbe!;
    final TerminalId negative = request.negativeProbe!;
    final String? positiveNode = topology.terminalToNode[positive];
    final String? negativeNode = topology.terminalToNode[negative];
    if (positiveNode == null || negativeNode == null) {
      return MeasurementResult.invalid(
        kind: request.kind,
        errorCode: MeasurementErrorCode.unknownTerminal,
        message: 'At least one voltage probe terminal is absent from the topology.',
      );
    }
    final double? positiveVoltage = simulation.nodeVoltages[positiveNode];
    final double? negativeVoltage = simulation.nodeVoltages[negativeNode];
    if (positiveVoltage == null || negativeVoltage == null) {
      return MeasurementResult.invalid(
        kind: request.kind,
        errorCode: MeasurementErrorCode.unknownTerminal,
        message: 'A probe node has no voltage in the solved result.',
      );
    }
    return MeasurementResult.valid(
      kind: request.kind,
      value: positiveVoltage - negativeVoltage,
      unit: ElectricalUnit.volt,
      evidenceIds: <String>['node:$positiveNode', 'node:$negativeNode'],
    );
  }

  MeasurementResult _measureCurrent(
    MeasurementRequest request,
    DcSolveResult simulation,
  ) {
    final String branchId = request.branchId!;
    DcBranchResult? branch;
    for (final DcBranchResult candidate in simulation.branchResults) {
      if (candidate.id == branchId) {
        branch = candidate;
        break;
      }
    }
    if (branch == null) {
      return MeasurementResult.invalid(
        kind: request.kind,
        errorCode: MeasurementErrorCode.unknownBranch,
        message: 'Current measurement branch does not exist in the solved result.',
      );
    }
    if (branch.currentA == null) {
      return MeasurementResult.invalid(
        kind: request.kind,
        errorCode: MeasurementErrorCode.branchCurrentUnavailable,
        message: 'Current is mathematically indeterminate for this branch.',
        evidenceIds: <String>['branch:$branchId'],
      );
    }
    return MeasurementResult.valid(
      kind: request.kind,
      value: branch.currentA!,
      unit: ElectricalUnit.ampere,
      evidenceIds: <String>['branch:$branchId'],
    );
  }

  MeasurementResult _measureResistance(
    MeasurementRequest request,
    CircuitState circuit,
  ) {
    if (_hasEnabledSource(circuit)) {
      return MeasurementResult.invalid(
        kind: request.kind,
        errorCode: MeasurementErrorCode.energizedResistanceMeasurement,
        message: 'Resistance measurement is permitted only on a de-energized circuit.',
      );
    }
    final ComponentId target = request.componentId!;
    ComponentInstance? component;
    for (final ComponentInstance candidate in circuit.components) {
      if (candidate.id == target) {
        component = candidate;
        break;
      }
    }
    if (component == null) {
      return MeasurementResult.invalid(
        kind: request.kind,
        errorCode: MeasurementErrorCode.unknownComponent,
        message: 'Resistance target component does not exist.',
      );
    }
    if (component.modelType != 'resistor' || component.condition != ComponentCondition.normal) {
      return MeasurementResult.invalid(
        kind: request.kind,
        errorCode: MeasurementErrorCode.unsupportedResistanceTarget,
        message: 'F4 resistance mode supports normal resistor components only.',
        evidenceIds: <String>['component:${target.value}'],
      );
    }
    final double? resistance = _positiveFinite(component.parameters['resistanceOhm']);
    if (resistance == null) {
      return MeasurementResult.invalid(
        kind: request.kind,
        errorCode: MeasurementErrorCode.invalidResistanceParameter,
        message: 'Resistor resistanceOhm must be finite and greater than zero.',
        evidenceIds: <String>['component:${target.value}'],
      );
    }
    return MeasurementResult.valid(
      kind: request.kind,
      value: resistance,
      unit: ElectricalUnit.ohm,
      evidenceIds: <String>['component:${target.value}'],
    );
  }

  bool _hasEnabledSource(CircuitState circuit) =>
      circuit.sources.any((SourceInstance source) => source.enabled);

  double? _positiveFinite(Object? raw) {
    if (raw is! num) {
      return null;
    }
    final double value = raw.toDouble();
    if (!value.isFinite || value <= zeroTolerance) {
      return null;
    }
    return value;
  }
}
