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
            message: 'Operating state requires a result for the current circuit revision.',
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

    if (component.modelType == 'switch' || component.modelType == 'switch_spst') {
      final Object? rawClosed = component.controlState['closed'];
      if (rawClosed is bool) {
        return ComponentOperatingState(
          componentId: component.id,
          code: rawClosed ? ComponentOperatingCode.closed : ComponentOperatingCode.open,
          voltageV: branch.voltageV,
          currentA: branch.currentA,
          powerW: branch.powerW,
          warnings: branch.currentA == null
              ? const <OperatingWarning>[
                  OperatingWarning(
                    code: OperatingWarningCode.currentIndeterminate,
                    message: 'Switch current is indeterminate for this solved constraint.',
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
    final bool energized = branch.voltageV.abs() > zeroTolerance ||
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
    final List<OperatingWarning> warnings = <OperatingWarning>[];
    _checkLimit(
      component.parameters,
      'maxVoltageV',
      branch.voltageV.abs(),
      OperatingWarningCode.overVoltage,
      'Voltage exceeds maxVoltageV.',
      warnings,
    );
    if (branch.currentA != null) {
      _checkLimit(
        component.parameters,
        'maxCurrentA',
        branch.currentA!.abs(),
        OperatingWarningCode.overCurrent,
        'Current exceeds maxCurrentA.',
        warnings,
      );
    }
    if (branch.powerW != null) {
      _checkLimit(
        component.parameters,
        'maxPowerW',
        branch.powerW!.abs(),
        OperatingWarningCode.overPower,
        'Power exceeds maxPowerW.',
        warnings,
      );
    }
    return warnings;
  }

  void _checkLimit(
    Map<String, Object?> parameters,
    String key,
    double measured,
    OperatingWarningCode overCode,
    String overMessage,
    List<OperatingWarning> warnings,
  ) {
    if (!parameters.containsKey(key)) {
      return;
    }
    final Object? raw = parameters[key];
    if (raw is! num || !raw.toDouble().isFinite || raw.toDouble() <= zeroTolerance) {
      warnings.add(
        OperatingWarning(
          code: OperatingWarningCode.invalidNominalLimit,
          message: '$key must be finite and greater than zero.',
        ),
      );
      return;
    }
    if (measured > raw.toDouble() + zeroTolerance) {
      warnings.add(OperatingWarning(code: overCode, message: overMessage));
    }
  }
}
