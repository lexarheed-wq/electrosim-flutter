import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:electrosim_pv/electrosim_pv.dart';
import 'package:electrosim_solver_ac/electrosim_solver_ac.dart';

import 'device_state_engine.dart';
import 'operating_state.dart';

/// Solver-domain adapters for [DeviceStateEngine].
///
/// The validated DC implementation remains untouched. These adapters consume
/// AC1, AC3 and PV solver evidence without inventing unavailable quantities.
extension DeviceStateDomainExtensions on DeviceStateEngine {
  ComponentOperatingState evaluateAc1({
    required ComponentInstance component,
    required CircuitState circuit,
    required Ac1SolveResult simulation,
  }) {
    final ComponentOperatingState? invalid = _preflight(
      component: component,
      circuit: circuit,
      resultCircuitId: simulation.circuitId,
      resultRevision: simulation.circuitRevision,
      solved: simulation.isSolved,
    );
    if (invalid != null) return invalid;
    final List<Ac1BranchResult> branches = simulation.branchResults
        .where((Ac1BranchResult item) => _belongsTo(component.id, item.id))
        .toList(growable: false);
    if (branches.isEmpty) return _missingBranch(component);
    return _fromAcBranches(
      component: component,
      voltages: branches.map((Ac1BranchResult item) => item.voltage.magnitude),
      currents: branches.map((Ac1BranchResult item) => item.current?.magnitude),
      powers: branches.map((Ac1BranchResult item) => item.activePowerW),
      evidenceIds: branches.map((Ac1BranchResult item) => 'branch:${item.id}'),
    );
  }

  ComponentOperatingState evaluateAc3({
    required ComponentInstance component,
    required CircuitState circuit,
    required Ac3SolveResult simulation,
  }) {
    final ComponentOperatingState? invalid = _preflight(
      component: component,
      circuit: circuit,
      resultCircuitId: simulation.circuitId,
      resultRevision: simulation.circuitRevision,
      solved: simulation.isSolved,
    );
    if (invalid != null) return invalid;
    final List<Ac3BranchResult> branches = simulation.branchResults
        .where((Ac3BranchResult item) => _belongsTo(component.id, item.id))
        .toList(growable: false);
    if (branches.isEmpty) return _missingBranch(component);
    if (component.modelType == 'motor_3p_6t') {
      final MotorThreePhaseCouplingAssessment coupling =
          MotorThreePhaseCouplingEvaluator.evaluate(circuit, component);
      if (!coupling.isValid) {
        return ComponentOperatingState(
          componentId: component.id,
          code: ComponentOperatingCode.faulted,
          voltageV: null,
          currentA: null,
          powerW: null,
          warnings: <OperatingWarning>[
            OperatingWarning(
              code: OperatingWarningCode.invalidMotorCoupling,
              message: coupling.message,
            ),
          ],
          evidenceIds: <String>[
            for (final Ac3BranchResult branch in branches) 'branch:${branch.id}',
          ],
        );
      }
    }
    final ComponentOperatingState operating = _fromAcBranches(
      component: component,
      voltages: branches.map((Ac3BranchResult item) => item.voltage.magnitude),
      currents: branches.map((Ac3BranchResult item) => item.current?.magnitude),
      powers: branches.map((Ac3BranchResult item) => item.activePowerW),
      evidenceIds: branches.map((Ac3BranchResult item) => 'branch:${item.id}'),
    );
    if (component.modelType != 'motor_3p_6t') return operating;

    // Every winding has the same permissible voltage whether the external
    // links are star or delta. A 230Δ/400Y motor on a 400 V line must NOT
    // be treated as nominal in delta. Compare actual solved RMS winding
    // voltages to the winding's delta nameplate value.
    final Object? rawWindingRating =
        component.parameters['ratedDeltaVoltageV'];
    if (rawWindingRating is! num ||
        !rawWindingRating.toDouble().isFinite ||
        rawWindingRating.toDouble() <= 0) {
      return operating;
    }
    final double ratedWindingV = rawWindingRating.toDouble();
    final double maxWindingV = branches.fold<double>(
      0,
      (double maximum, Ac3BranchResult branch) =>
          branch.voltage.magnitude > maximum
              ? branch.voltage.magnitude
              : maximum,
    );
    if (!maxWindingV.isFinite || maxWindingV <= ratedWindingV * 1.10) {
      return operating;
    }
    return ComponentOperatingState(
      componentId: component.id,
      code: ComponentOperatingCode.overloaded,
      voltageV: operating.voltageV,
      currentA: operating.currentA,
      powerW: operating.powerW,
      warnings: <OperatingWarning>[
        ...operating.warnings,
        OperatingWarning(
          code: OperatingWarningCode.overVoltage,
          message:
              'Motor winding overvoltage: ${maxWindingV.toStringAsFixed(1)} V RMS '
              'against ${ratedWindingV.toStringAsFixed(1)} V rated winding voltage. '
              'Check external star/delta coupling and motor nameplate.',
        ),
      ],
      evidenceIds: operating.evidenceIds,
    );
  }

  ComponentOperatingState evaluatePv({
    required ComponentInstance component,
    required CircuitState circuit,
    required PvSolveResult simulation,
  }) {
    final ComponentOperatingState? invalid = _preflight(
      component: component,
      circuit: circuit,
      resultCircuitId: simulation.circuitId,
      resultRevision: simulation.circuitRevision,
      solved: simulation.isSolved,
    );
    if (invalid != null) return invalid;

    final ComponentPhysicsContract physics =
        CoreComponentPhysicsContracts.resolveComponent(component);
    switch (physics.functionalRole) {
      case ComponentFunctionalRole.pvController:
        if (!simulation.controllerPresent) return _missingBranch(component);
        final bool energized =
            simulation.pvDrawnPowerW.abs() > zeroTolerance ||
            simulation.controllerConversionLossW.abs() > zeroTolerance;
        return ComponentOperatingState(
          componentId: component.id,
          code: energized
              ? ComponentOperatingCode.energized
              : ComponentOperatingCode.deenergized,
          voltageV: null,
          currentA: null,
          powerW: null,
          warnings: const <OperatingWarning>[],
          evidenceIds: const <String>['pv:controller'],
        );
      case ComponentFunctionalRole.pvBattery:
        if (!simulation.batteryPresent) return _missingBranch(component);
        return _fromExactValues(
          component: component,
          voltageV: simulation.batteryVoltageV,
          currentA: null,
          powerW: simulation.batteryPowerW,
          evidenceId: 'pv:battery',
        );
      case ComponentFunctionalRole.pvInverter:
        final ComponentOperatingCode code = switch (simulation.inverterState) {
          PvInverterState.faulted ||
          PvInverterState.inputOutOfRange => ComponentOperatingCode.faulted,
          PvInverterState.idle => ComponentOperatingCode.deenergized,
          PvInverterState.running ||
          PvInverterState.powerLimited => ComponentOperatingCode.energized,
        };
        return ComponentOperatingState(
          componentId: component.id,
          code: code,
          voltageV: simulation.inverterOutputVoltageRmsV,
          currentA: simulation.inverterOutputCurrentRmsA,
          powerW: simulation.inverterOutputPowerW,
          warnings: const <OperatingWarning>[],
          evidenceIds: <String>['pv:inverter:${simulation.inverterState.name}'],
        );
      case ComponentFunctionalRole.pvLoad:
        final PvLoadResult? load = _pvLoad(simulation, component.id);
        if (load == null) return _missingBranch(component);
        return _fromExactValues(
          component: component,
          voltageV: load.voltageRmsV,
          currentA: load.currentRmsA,
          powerW: load.activePowerW,
          evidenceId: 'pv:load:${component.id.value}',
        );
      case ComponentFunctionalRole.generic:
        final PvLoadResult? load = _pvLoad(simulation, component.id);
        if (load != null) {
          return _fromExactValues(
            component: component,
            voltageV: load.voltageRmsV,
            currentA: load.currentRmsA,
            powerW: load.activePowerW,
            evidenceId: 'pv:load:${component.id.value}',
          );
        }
        return ComponentOperatingState(
          componentId: component.id,
          code: ComponentOperatingCode.undetermined,
          voltageV: null,
          currentA: null,
          powerW: null,
          warnings: const <OperatingWarning>[
            OperatingWarning(
              code: OperatingWarningCode.missingBranchResult,
              message:
                  'No PV operating-state evidence exists for this component.',
            ),
          ],
          evidenceIds: <String>['component:${component.id.value}'],
        );
    }
  }

  ComponentOperatingState _fromAcBranches({
    required ComponentInstance component,
    required Iterable<double> voltages,
    required Iterable<double?> currents,
    required Iterable<double?> powers,
    required Iterable<String> evidenceIds,
  }) {
    final List<double> voltageList = voltages.toList(growable: false);
    final List<double?> currentList = currents.toList(growable: false);
    final List<double?> powerList = powers.toList(growable: false);
    final List<String> evidenceList = evidenceIds.toList(growable: false);
    final ComponentOperatingCode? directState = _directControlState(component);

    if (voltageList.length == 1) {
      final double voltageV = voltageList.single;
      final double? currentA = currentList.single;
      final double? powerW = powerList.single;
      final List<OperatingWarning> warnings = _limitWarnings(
        component,
        voltageV: voltageV.abs(),
        currentA: currentA?.abs(),
        powerW: powerW?.abs(),
      );
      if (currentA == null) {
        warnings.add(
          const OperatingWarning(
            code: OperatingWarningCode.currentIndeterminate,
            message: 'Branch current is indeterminate.',
          ),
        );
      }
      final bool energized =
          voltageV.abs() > zeroTolerance ||
          (currentA?.abs() ?? 0.0) > zeroTolerance ||
          (powerW?.abs() ?? 0.0) > zeroTolerance;
      return ComponentOperatingState(
        componentId: component.id,
        code:
            directState ??
            _stateFromEvidence(energized: energized, warnings: warnings),
        voltageV: voltageV,
        currentA: currentA,
        powerW: powerW,
        warnings: warnings,
        evidenceIds: evidenceList,
      );
    }

    final bool energized =
        voltageList.any((double value) => value.abs() > zeroTolerance) ||
        currentList.any(
          (double? value) => (value?.abs() ?? 0.0) > zeroTolerance,
        ) ||
        powerList.any((double? value) => (value?.abs() ?? 0.0) > zeroTolerance);
    return ComponentOperatingState(
      componentId: component.id,
      code:
          directState ??
          (energized
              ? ComponentOperatingCode.energized
              : ComponentOperatingCode.deenergized),
      voltageV: null,
      currentA: null,
      powerW: null,
      warnings: const <OperatingWarning>[],
      evidenceIds: evidenceList,
    );
  }

  ComponentOperatingState _fromExactValues({
    required ComponentInstance component,
    required double? voltageV,
    required double? currentA,
    required double? powerW,
    required String evidenceId,
  }) {
    final List<OperatingWarning> warnings = _limitWarnings(
      component,
      voltageV: voltageV?.abs(),
      currentA: currentA?.abs(),
      powerW: powerW?.abs(),
    );
    final bool energized =
        (voltageV?.abs() ?? 0.0) > zeroTolerance ||
        (currentA?.abs() ?? 0.0) > zeroTolerance ||
        (powerW?.abs() ?? 0.0) > zeroTolerance;
    return ComponentOperatingState(
      componentId: component.id,
      code: _stateFromEvidence(energized: energized, warnings: warnings),
      voltageV: voltageV,
      currentA: currentA,
      powerW: powerW,
      warnings: warnings,
      evidenceIds: <String>[evidenceId],
    );
  }

  ComponentOperatingState? _preflight({
    required ComponentInstance component,
    required CircuitState circuit,
    required CircuitId resultCircuitId,
    required int resultRevision,
    required bool solved,
  }) {
    if (resultCircuitId != circuit.circuitId ||
        resultRevision != circuit.revision ||
        !solved) {
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
                'Operating state requires a solved result for this circuit revision.',
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
    return null;
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

  ComponentOperatingState _missingBranch(ComponentInstance component) =>
      ComponentOperatingState(
        componentId: component.id,
        code: ComponentOperatingCode.undetermined,
        voltageV: null,
        currentA: null,
        powerW: null,
        warnings: const <OperatingWarning>[
          OperatingWarning(
            code: OperatingWarningCode.missingBranchResult,
            message: 'No electrical result exists for this component.',
          ),
        ],
        evidenceIds: <String>['component:${component.id.value}'],
      );

  ComponentOperatingCode? _directControlState(ComponentInstance component) {
    final ComponentPhysicsContract physics =
        CoreComponentPhysicsContracts.resolveComponent(component);
    if (!physics.isSwitching) return null;
    final Object? rawClosed = component.controlState['closed'];
    if (rawClosed is bool) {
      return rawClosed
          ? ComponentOperatingCode.closed
          : ComponentOperatingCode.open;
    }
    return null;
  }

  ComponentOperatingCode _stateFromEvidence({
    required bool energized,
    required List<OperatingWarning> warnings,
  }) {
    final bool overloaded = warnings.any(
      (OperatingWarning warning) =>
          warning.code == OperatingWarningCode.overVoltage ||
          warning.code == OperatingWarningCode.overCurrent ||
          warning.code == OperatingWarningCode.overPower,
    );
    if (overloaded) return ComponentOperatingCode.overloaded;
    return energized
        ? ComponentOperatingCode.energized
        : ComponentOperatingCode.deenergized;
  }

  List<OperatingWarning> _limitWarnings(
    ComponentInstance component, {
    required double? voltageV,
    required double? currentA,
    required double? powerW,
  }) {
    final ComponentOperatingEnvelope envelope =
        ComponentOperatingEnvelope.fromComponent(component);
    final List<OperatingWarning> warnings = <OperatingWarning>[];
    _checkLimitValue(
      limit: envelope.effectiveMaxVoltageV,
      invalid: envelope.invalidMaxVoltage,
      measured: voltageV,
      overCode: OperatingWarningCode.overVoltage,
      label: 'tension',
      warnings: warnings,
    );
    _checkLimitValue(
      limit: envelope.effectiveMaxCurrentA,
      invalid: envelope.invalidMaxCurrent,
      measured: currentA,
      overCode: OperatingWarningCode.overCurrent,
      label: 'courant',
      warnings: warnings,
    );
    _checkLimitValue(
      limit: envelope.effectiveMaxPowerW,
      invalid: envelope.invalidMaxPower,
      measured: powerW,
      overCode: OperatingWarningCode.overPower,
      label: 'puissance',
      warnings: warnings,
    );
    return warnings;
  }

  void _checkLimitValue({
    required double? limit,
    required bool invalid,
    required double? measured,
    required OperatingWarningCode overCode,
    required String label,
    required List<OperatingWarning> warnings,
  }) {
    if (invalid) {
      warnings.add(
        OperatingWarning(
          code: OperatingWarningCode.invalidNominalLimit,
          message: 'La limite de $label doit être finie et strictement positive.',
        ),
      );
      return;
    }
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

  bool _belongsTo(ComponentId id, String branchId) {
    final String prefix = 'component:${id.value}';
    return branchId == prefix || branchId.startsWith('$prefix:');
  }

  PvLoadResult? _pvLoad(PvSolveResult simulation, ComponentId id) {
    for (final PvLoadResult result in simulation.loadResults) {
      if (result.componentId == id) return result;
    }
    return null;
  }
}
