import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:electrosim_solver_ac/electrosim_solver_ac.dart';
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
      case MeasurementKind.voltageAcRms:
      case MeasurementKind.currentAcRms:
      case MeasurementKind.frequency:
        return MeasurementResult.invalid(
          kind: request.kind,
          errorCode: MeasurementErrorCode.wrongElectricalMode,
          message: 'Use measureAc1 or measureAc3 for AC measurements.',
        );
    }
  }

  MeasurementResult measureAc1({
    required MeasurementRequest request,
    required CircuitState circuit,
    required TopologyGraph topology,
    required Ac1SolveResult simulation,
  }) {
    final MeasurementResult? invalid = _preflightAc(
      request: request,
      circuit: circuit,
      topology: topology,
      solved: simulation.isSolved,
      resultCircuitId: simulation.circuitId,
      resultRevision: simulation.circuitRevision,
      expectedMode: ElectricalMode.ac1,
    );
    if (invalid != null) return invalid;
    switch (request.kind) {
      case MeasurementKind.voltageAcRms:
        return _measureAcVoltage(
          request: request,
          topology: topology,
          nodeVoltages: simulation.nodeVoltages,
        );
      case MeasurementKind.currentAcRms:
        Ac1BranchResult? branch;
        for (final Ac1BranchResult candidate in simulation.branchResults) {
          if (candidate.id == request.branchId) {
            branch = candidate;
            break;
          }
        }
        return _acCurrentResult(request, branch?.current?.magnitude, branch != null);
      case MeasurementKind.frequency:
        return _frequencyResult(request, simulation.frequencyHz);
      case MeasurementKind.voltageDc:
      case MeasurementKind.currentDc:
      case MeasurementKind.resistance:
        return MeasurementResult.invalid(
          kind: request.kind,
          errorCode: MeasurementErrorCode.wrongElectricalMode,
          message: 'This request is not an AC1 measurement.',
        );
    }
  }

  MeasurementResult measureAc3({
    required MeasurementRequest request,
    required CircuitState circuit,
    required TopologyGraph topology,
    required Ac3SolveResult simulation,
  }) {
    final MeasurementResult? invalid = _preflightAc(
      request: request,
      circuit: circuit,
      topology: topology,
      solved: simulation.isSolved,
      resultCircuitId: simulation.circuitId,
      resultRevision: simulation.circuitRevision,
      expectedMode: ElectricalMode.ac3,
    );
    if (invalid != null) return invalid;
    switch (request.kind) {
      case MeasurementKind.voltageAcRms:
        return _measureAcVoltage(
          request: request,
          topology: topology,
          nodeVoltages: simulation.nodeVoltages,
        );
      case MeasurementKind.currentAcRms:
        Ac3BranchResult? branch;
        for (final Ac3BranchResult candidate in simulation.branchResults) {
          if (candidate.id == request.branchId) {
            branch = candidate;
            break;
          }
        }
        return _acCurrentResult(request, branch?.current?.magnitude, branch != null);
      case MeasurementKind.frequency:
        return _frequencyResult(request, simulation.frequencyHz);
      case MeasurementKind.voltageDc:
      case MeasurementKind.currentDc:
      case MeasurementKind.resistance:
        return MeasurementResult.invalid(
          kind: request.kind,
          errorCode: MeasurementErrorCode.wrongElectricalMode,
          message: 'This request is not an AC3 measurement.',
        );
    }
  }

  MeasurementResult? _preflightAc({
    required MeasurementRequest request,
    required CircuitState circuit,
    required TopologyGraph topology,
    required bool solved,
    required CircuitId resultCircuitId,
    required int resultRevision,
    required ElectricalMode expectedMode,
  }) {
    if (circuit.mode != expectedMode || topology.mode != expectedMode) {
      return MeasurementResult.invalid(
        kind: request.kind,
        errorCode: MeasurementErrorCode.wrongElectricalMode,
        message: 'AC measurement mode does not match CircuitState/TopologyGraph.',
      );
    }
    if (topology.circuitId != circuit.circuitId ||
        topology.circuitRevision != circuit.revision ||
        resultCircuitId != circuit.circuitId ||
        resultRevision != circuit.revision) {
      return MeasurementResult.invalid(
        kind: request.kind,
        errorCode: MeasurementErrorCode.identityMismatch,
        message: 'CircuitState, TopologyGraph and AC solve result must share identity and revision.',
      );
    }
    if (!solved) {
      return MeasurementResult.invalid(
        kind: request.kind,
        errorCode: MeasurementErrorCode.simulationNotSolved,
        message: 'An AC measurement cannot be reported from an unsolved result.',
      );
    }
    return null;
  }

  MeasurementResult _measureAcVoltage({
    required MeasurementRequest request,
    required TopologyGraph topology,
    required Map<String, AcComplex> nodeVoltages,
  }) {
    final TerminalId positive = request.positiveProbe!;
    final TerminalId negative = request.negativeProbe!;
    final String? positiveNode = topology.terminalToNode[positive];
    final String? negativeNode = topology.terminalToNode[negative];
    if (positiveNode == null || negativeNode == null) {
      return MeasurementResult.invalid(
        kind: request.kind,
        errorCode: MeasurementErrorCode.unknownTerminal,
        message: 'At least one AC voltage probe terminal is absent from the topology.',
      );
    }
    final AcComplex? positiveVoltage = nodeVoltages[positiveNode];
    final AcComplex? negativeVoltage = nodeVoltages[negativeNode];
    if (positiveVoltage == null || negativeVoltage == null) {
      return MeasurementResult.invalid(
        kind: request.kind,
        errorCode: MeasurementErrorCode.unknownTerminal,
        message: 'A probe node has no phasor voltage in the solved result.',
      );
    }
    return MeasurementResult.valid(
      kind: request.kind,
      value: (positiveVoltage - negativeVoltage).magnitude,
      unit: ElectricalUnit.volt,
      evidenceIds: <String>['node:' + positiveNode, 'node:' + negativeNode],
    );
  }

  MeasurementResult _acCurrentResult(
    MeasurementRequest request,
    double? currentA,
    bool branchExists,
  ) {
    if (!branchExists) {
      return MeasurementResult.invalid(
        kind: request.kind,
        errorCode: MeasurementErrorCode.unknownBranch,
        message: 'AC current measurement branch does not exist in the solved result.',
      );
    }
    if (currentA == null) {
      return MeasurementResult.invalid(
        kind: request.kind,
        errorCode: MeasurementErrorCode.branchCurrentUnavailable,
        message: 'AC branch current is mathematically indeterminate.',
        evidenceIds: <String>['branch:' + request.branchId!],
      );
    }
    return MeasurementResult.valid(
      kind: request.kind,
      value: currentA,
      unit: ElectricalUnit.ampere,
      evidenceIds: <String>['branch:' + request.branchId!],
    );
  }

  MeasurementResult _frequencyResult(
    MeasurementRequest request,
    double? frequencyHz,
  ) {
    if (frequencyHz == null || !frequencyHz.isFinite || frequencyHz <= 0) {
      return MeasurementResult.invalid(
        kind: request.kind,
        errorCode: MeasurementErrorCode.simulationNotSolved,
        message: 'Solved AC result does not expose a valid frequency.',
      );
    }
    return MeasurementResult.valid(
      kind: request.kind,
      value: frequencyHz,
      unit: ElectricalUnit.hertz,
      evidenceIds: const <String>['solver:frequency'],
    );
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
