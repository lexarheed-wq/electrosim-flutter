import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:electrosim_solver_dc/electrosim_solver_dc.dart';

import 'operating_state.dart';

final class DeviceStateEngine {
  const DeviceStateEngine({this.zeroTolerance = 1e-9});

  final double zeroTolerance;

  List<ComponentOperatingState> evaluateAll({
    required CircuitState circuit,
    required DcSolveResult simulation,
  }) => List<ComponentOperatingState>.unmodifiable(
    circuit.components.map<ComponentOperatingState>(
      (ComponentInstance component) => evaluate(
        component: component,
        circuit: circuit,
        simulation: simulation,
      ),
    ),
  );

  ComponentOperatingState evaluate({
    required ComponentInstance component,
    required CircuitState circuit,
    required DcSolveResult simulation,
  }) {
    if (simulation.circuitId != circuit.circuitId ||
        simulation.circuitRevision != circuit.revision) {
      return ComponentOperatingState(
        componentId: component.id,
        code: ComponentOperatingCode.undetermined,
        voltageV: null,
        currentA: null,
        powerW: null,
        warnings: const <OperatingWarning>[
          OperatingWarning(
            code: OperatingWarningCode.simulationNotSolved,
            message:
                'Operating state requires a result for the current circuit revision.',
          ),
        ],
        evidenceIds: const <String>[],
      );
    }

    if (component.condition == ComponentCondition.disabled) {
      return _conditionState(component, ComponentOperatingCode.disabled);
    }
    if (component.condition != ComponentCondition.normal) {
      return _conditionState(component, ComponentOperatingCode.faulted);
    }
    if (!simulation.isSolved) {
      return ComponentOperatingState(
        componentId: component.id,
        code: ComponentOperatingCode.undetermined,
        voltageV: null,
        currentA: null,
        powerW: null,
        warnings: const <OperatingWarning>[
          OperatingWarning(
            code: OperatingWarningCode.simulationNotSolved,
            message: 'Operating state requires a solved electrical result.',
          ),
        ],
        evidenceIds: const <String>[],
      );
    }

    final String branchId = 'component:${component.id.value}';
    final DcBranchResult? branch = _findBranch(simulation, branchId);
    if (branch == null) {
      return ComponentOperatingState(
        componentId: component.id,
        code: ComponentOperatingCode.undetermined,
        voltageV: null,
        currentA: null,
        powerW: null,
        warnings: const <OperatingWarning>[
          OperatingWarning(
            code: OperatingWarningCode.missingBranchResult,
            message: 'No electrical branch result exists for this component.',
          ),
        ],
        evidenceIds: <String>['component:${component.id.value}'],
      );
    }

    final ComponentPhysicsContract physics =
        CoreComponentPhysicsContracts.resolveComponent(component);
    if (physics.isSwitching) {
      final Object? rawClosed = component.controlState['closed'];
      if (rawClosed is bool) {
        return ComponentOperatingState(
          componentId: component.id,
          code: rawClosed
              ? ComponentOperatingCode.closed
              : ComponentOperatingCode.open,
          voltageV: branch.voltageV,
          currentA: branch.currentA,
          powerW: branch.powerW,
          warnings: branch.currentA == null
              ? const <OperatingWarning>[
                  OperatingWarning(
                    code: OperatingWarningCode.currentIndeterminate,
                    message:
                        'Switch current is indeterminate for this solved constraint.',
                  ),
                ]
              : const <OperatingWarning>[],
          evidenceIds: <String>['branch:$branchId'],
        );
      }
    }

    final List<OperatingWarning> warnings = _limitWarnings(component, branch);
    if (branch.currentA == null) {
      warnings.add(
        const OperatingWarning(
          code: OperatingWarningCode.currentIndeterminate,
          message: 'Branch current is indeterminate.',
        ),
      );
    }
    final bool overloaded = warnings.any(
      (OperatingWarning warning) =>
          warning.code == OperatingWarningCode.overVoltage ||
          warning.code == OperatingWarningCode.overCurrent ||
          warning.code == OperatingWarningCode.overPower,
    );
    final bool energized =
        branch.voltageV.abs() > zeroTolerance ||
        (branch.currentA?.abs() ?? 0.0) > zeroTolerance ||
        (branch.powerW?.abs() ?? 0.0) > zeroTolerance;

    return ComponentOperatingState(
      componentId: component.id,
      code: overloaded
          ? ComponentOperatingCode.overloaded
          : energized
          ? ComponentOperatingCode.energized
          : ComponentOperatingCode.deenergized,
      voltageV: branch.voltageV,
      currentA: branch.currentA,
      powerW: branch.powerW,
      warnings: warnings,
      evidenceIds: <String>['branch:$branchId'],
    );
  }

  ComponentOperatingState _conditionState(
    ComponentInstance component,
    ComponentOperatingCode code,
  ) => ComponentOperatingState(
    componentId: component.id,
    code: code,
    voltageV: null,
    currentA: null,
    powerW: null,
    warnings: const <OperatingWarning>[],
    evidenceIds: <String>['component-condition:${component.id.value}'],
  );

  DcBranchResult? _findBranch(DcSolveResult simulation, String branchId) {
    for (final DcBranchResult branch in simulation.branchResults) {
      if (branch.id == branchId) {
        return branch;
      }
    }
    return null;
  }

  List<OperatingWarning> _limitWarnings(
    ComponentInstance component,
    DcBranchResult branch,
  ) {
    final ComponentOperatingEnvelope envelope =
        ComponentOperatingEnvelope.fromComponent(component);
    final List<OperatingWarning> warnings = <OperatingWarning>[];
    _checkLimitValue(
      limit: envelope.effectiveMaxVoltageV,
      measured: branch.voltageV.abs(),
      overCode: OperatingWarningCode.overVoltage,
      label: 'tension',
      warnings: warnings,
    );
    _checkLimitValue(
      limit: envelope.effectiveMaxCurrentA,
      measured: branch.currentA?.abs(),
      overCode: OperatingWarningCode.overCurrent,
      label: 'courant',
      warnings: warnings,
    );
    _checkLimitValue(
      limit: envelope.effectiveMaxPowerW,
      measured: branch.powerW?.abs(),
      overCode: OperatingWarningCode.overPower,
      label: 'puissance',
      warnings: warnings,
    );
    return warnings;
  }

  void _checkLimitValue({
    required double? limit,
    required double? measured,
    required OperatingWarningCode overCode,
    required String label,
    required List<OperatingWarning> warnings,
  }) {
    if (limit == null || measured == null) return;
    if (!limit.isFinite || limit <= zeroTolerance) {
      warnings.add(
        OperatingWarning(
          code: OperatingWarningCode.invalidNominalLimit,
          message: 'La limite de $label doit être finie et strictement positive.',
        ),
      );
      return;
    }
    if (measured > limit + zeroTolerance) {
      warnings.add(
        OperatingWarning(
          code: overCode,
          message: 'La $label calculée dépasse l’enveloppe physique admissible.',
        ),
      );
    }
  }

}
