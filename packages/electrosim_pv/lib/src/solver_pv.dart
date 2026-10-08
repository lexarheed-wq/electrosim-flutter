import 'dart:math' as math;

import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:electrosim_topology/electrosim_topology.dart';

import 'pv_diagnostic.dart';
import 'pv_result.dart';
import 'pv_solver_options.dart';

final class SolverPV {
  const SolverPV({this.options = const PvSolverOptions()});

  static const String engineVersion = 'solver-pv/0.2.0';

  final PvSolverOptions options;

  PvSolveResult solve(
    CircuitState circuit,
    TopologyGraph topology, {
    double? previousBatterySoc,
    Duration elapsed = Duration.zero,
  }) {
    final List<PvSolverDiagnostic> diagnostics = <PvSolverDiagnostic>[];
    if (circuit.mode != ElectricalMode.pv ||
        topology.mode != ElectricalMode.pv) {
      diagnostics.add(
        const PvSolverDiagnostic(
          code: PvDiagnosticCode.wrongElectricalMode,
          severity: PvDiagnosticSeverity.error,
          message: 'SolverPV accepts PV circuits only.',
        ),
      );
      return _failure(circuit, diagnostics);
    }
    if (circuit.circuitId != topology.circuitId ||
        circuit.revision != topology.circuitRevision) {
      diagnostics.add(
        const PvSolverDiagnostic(
          code: PvDiagnosticCode.topologyIdentityMismatch,
          severity: PvDiagnosticSeverity.error,
          message:
              'TopologyGraph does not match the CircuitState identity/revision.',
        ),
      );
      return _failure(circuit, diagnostics);
    }
    for (final TopologyFinding finding in topology.findings) {
      if (finding.severity == TopologyFindingSeverity.error) {
        diagnostics.add(
          PvSolverDiagnostic(
            code: PvDiagnosticCode.topologyError,
            severity: PvDiagnosticSeverity.error,
            message: finding.message,
            componentId: finding.componentId,
            sourceId: finding.sourceId,
          ),
        );
      }
    }
    if (_hasErrors(diagnostics)) {
      return _failure(circuit, diagnostics);
    }

    final List<SourceInstance> arrays = circuit.sources
        .where((SourceInstance source) => source.modelType == 'pv_array')
        .toList(growable: false);
    if (arrays.isEmpty) {
      diagnostics.add(
        const PvSolverDiagnostic(
          code: PvDiagnosticCode.missingPvArray,
          severity: PvDiagnosticSeverity.error,
          message: 'PV circuit must contain one pv_array source.',
        ),
      );
      return _failure(circuit, diagnostics);
    }
    if (arrays.length != 1) {
      diagnostics.add(
        const PvSolverDiagnostic(
          code: PvDiagnosticCode.multiplePvArrays,
          severity: PvDiagnosticSeverity.error,
          message: 'F7 PV model supports exactly one pv_array source.',
        ),
      );
      return _failure(circuit, diagnostics);
    }

    final List<ComponentInstance> inverters = circuit.components
        .where(
          (ComponentInstance component) =>
              _hasFunctionalRole(component, ComponentFunctionalRole.pvInverter),
        )
        .toList(growable: false);
    if (inverters.length > 1) {
      diagnostics.add(
        const PvSolverDiagnostic(
          code: PvDiagnosticCode.multipleInverters,
          severity: PvDiagnosticSeverity.error,
          message: 'F7 PV model supports exactly one pv_inverter component.',
        ),
      );
      return _failure(circuit, diagnostics);
    }

    final SourceInstance array = arrays.single;
    final ComponentInstance? inverter = inverters.isEmpty ? null : inverters.single;
    final List<ComponentInstance> controllers = circuit.components
        .where(
          (ComponentInstance component) =>
              _hasFunctionalRole(component, ComponentFunctionalRole.pvController),
        )
        .toList(growable: false);
    final List<ComponentInstance> batteries = circuit.components
        .where(
          (ComponentInstance component) =>
              _hasFunctionalRole(component, ComponentFunctionalRole.pvBattery),
        )
        .toList(growable: false);
    if (controllers.length > 1 || batteries.length > 1) {
      diagnostics.add(
        const PvSolverDiagnostic(
          code: PvDiagnosticCode.storageTopologyInvalid,
          severity: PvDiagnosticSeverity.error,
          message:
              'PV storage supports at most one controller and one battery.',
        ),
      );
      return _failure(circuit, diagnostics);
    }
    if (controllers.isEmpty != batteries.isEmpty) {
      diagnostics.add(
        const PvSolverDiagnostic(
          code: PvDiagnosticCode.storageTopologyInvalid,
          severity: PvDiagnosticSeverity.error,
          message:
              'A PV controller and battery must be used together in the storage chain.',
        ),
      );
      return _failure(circuit, diagnostics);
    }

    final ComponentInstance? controller = controllers.isEmpty
        ? null
        : controllers.single;
    final ComponentInstance? battery = batteries.isEmpty
        ? null
        : batteries.single;

    final _PvArrayParameters? arrayParameters = _arrayParameters(
      array,
      diagnostics,
    );
    final _InverterParameters? inverterParameters = inverter == null
        ? null
        : _inverterParameters(inverter, diagnostics);
    final _ControllerParameters? controllerParameters = controller == null
        ? null
        : _controllerParameters(controller, diagnostics);
    final _BatteryParameters? batteryParameters = battery == null
        ? null
        : _batteryParameters(battery, diagnostics);
    if (arrayParameters == null ||
        (inverter != null && inverterParameters == null) ||
        (controller != null && controllerParameters == null) ||
        (battery != null && batteryParameters == null)) {
      return _failure(circuit, diagnostics);
    }

    final _PvTerminalContract? arrayTerminals = _pvArrayTerminals(
      array,
      diagnostics,
    );
    final _InverterTerminalContract? inverterTerminals = inverter == null
        ? null
        : _inverterTerminals(inverter, diagnostics);
    if (arrayTerminals == null ||
        (inverter != null && inverterTerminals == null)) {
      return _failure(circuit, diagnostics);
    }

    final String arrayPositiveNode = topology
        .nodeForTerminal(arrayTerminals.positive.id)
        .id;
    final String arrayNegativeNode = topology
        .nodeForTerminal(arrayTerminals.negative.id)
        .id;
    final String? inverterPositiveNode = inverterTerminals == null
        ? null
        : topology.nodeForTerminal(inverterTerminals.dcPositive.id).id;
    final String? inverterNegativeNode = inverterTerminals == null
        ? null
        : topology.nodeForTerminal(inverterTerminals.dcNegative.id).id;

    if (controller == null) {
      if (inverter == null || inverterTerminals == null) {
        diagnostics.add(
          const PvSolverDiagnostic(
            code: PvDiagnosticCode.missingInverter,
            severity: PvDiagnosticSeverity.error,
            message:
                'A direct PV-to-AC circuit requires one pv_inverter component.',
          ),
        );
        return _failure(circuit, diagnostics);
      }
      if (arrayPositiveNode != inverterPositiveNode ||
          arrayNegativeNode != inverterNegativeNode) {
        diagnostics.add(
          PvSolverDiagnostic(
            code: PvDiagnosticCode.dcInputDisconnected,
            severity: PvDiagnosticSeverity.error,
            message:
                'pv_array DC terminals are not connected to the matching inverter DC input.',
            componentId: inverter.id,
            sourceId: array.id,
          ),
        );
        return _failure(circuit, diagnostics);
      }
    } else {
      final _ControllerTerminalContract? controllerTerminals =
          _controllerTerminals(controller, diagnostics);
      final _BatteryTerminalContract? batteryTerminals = _batteryTerminals(
        battery!,
        diagnostics,
      );
      if (controllerTerminals == null || batteryTerminals == null) {
        return _failure(circuit, diagnostics);
      }
      final String controllerPvPositiveNode = topology
          .nodeForTerminal(controllerTerminals.pvPositive.id)
          .id;
      final String controllerPvNegativeNode = topology
          .nodeForTerminal(controllerTerminals.pvNegative.id)
          .id;
      final String controllerBusPositiveNode = topology
          .nodeForTerminal(controllerTerminals.busPositive.id)
          .id;
      final String controllerBusNegativeNode = topology
          .nodeForTerminal(controllerTerminals.busNegative.id)
          .id;
      final String batteryPositiveNode = topology
          .nodeForTerminal(batteryTerminals.positive.id)
          .id;
      final String batteryNegativeNode = topology
          .nodeForTerminal(batteryTerminals.negative.id)
          .id;
      if (arrayPositiveNode != controllerPvPositiveNode ||
          arrayNegativeNode != controllerPvNegativeNode ||
          batteryPositiveNode != controllerBusPositiveNode ||
          batteryNegativeNode != controllerBusNegativeNode) {
        diagnostics.add(
          PvSolverDiagnostic(
            code: PvDiagnosticCode.storageTopologyInvalid,
            severity: PvDiagnosticSeverity.error,
            message:
                'PV storage requires array → controller → battery on the controller DC output bus.',
            componentId: controller.id,
            sourceId: array.id,
          ),
        );
        return _failure(circuit, diagnostics);
      }
      final bool inverterDcConnected =
          inverter != null &&
          inverterPositiveNode == controllerBusPositiveNode &&
          inverterNegativeNode == controllerBusNegativeNode;
      if (inverter != null && !inverterDcConnected) {
        diagnostics.add(
          PvSolverDiagnostic(
            code: PvDiagnosticCode.dcInputDisconnected,
            severity: PvDiagnosticSeverity.warning,
            message:
                'Inverter DC input is disconnected from the storage bus; PV charging remains available.',
            componentId: inverter.id,
          ),
        );
      }
    }

    final bool inverterDcConnected = controller == null
        ? inverter != null
        : inverter != null &&
              inverterPositiveNode != null &&
              inverterNegativeNode != null &&
              battery != null &&
              topology.nodeForTerminal(battery.terminals[0].id).id ==
                  inverterPositiveNode &&
              topology.nodeForTerminal(battery.terminals[1].id).id ==
                  inverterNegativeNode;

    final List<ComponentInstance> loadCandidates =
        circuit.components
            .where((ComponentInstance component) {
              final ComponentPhysicsContract physics =
                  CoreComponentPhysicsContracts.resolveComponent(component);
              return physics.functionalRole == ComponentFunctionalRole.pvLoad ||
                  (physics.electricalLaw == ComponentElectricalLaw.resistive &&
                      component.terminals.length == 2);
            })
            .toList(growable: false)
          ..sort(
            (ComponentInstance a, ComponentInstance b) =>
                a.id.value.compareTo(b.id.value),
          );
    final List<_LoadParameters> loadParameters = <_LoadParameters>[];
    final String? inverterLineNode = inverterTerminals == null
        ? null
        : topology.nodeForTerminal(inverterTerminals.acLine.id).id;
    final String? inverterNeutralNode = inverterTerminals == null
        ? null
        : topology.nodeForTerminal(inverterTerminals.acNeutral.id).id;
    for (final ComponentInstance load in loadCandidates) {
      final ComponentPhysicsContract physics =
          CoreComponentPhysicsContracts.resolveComponent(load);
      final bool explicitPvLoad =
          physics.functionalRole == ComponentFunctionalRole.pvLoad;
      if (inverter == null || inverterLineNode == null || inverterNeutralNode == null) {
        if (explicitPvLoad) {
          diagnostics.add(
            PvSolverDiagnostic(
              code: PvDiagnosticCode.missingInverter,
              severity: PvDiagnosticSeverity.error,
              message: 'PV AC load ${load.id.value} requires a pv_inverter component.',
              componentId: load.id,
            ),
          );
        }
        continue;
      }

      final _LoadTerminalContract? terminals = _loadTerminals(
        load,
        diagnostics,
        allowGenericPair: !explicitPvLoad,
      );
      if (terminals == null) continue;
      final String firstNode = topology.nodeForTerminal(terminals.line.id).id;
      final String secondNode = topology.nodeForTerminal(terminals.neutral.id).id;
      final bool connectedToAcBus =
          (firstNode == inverterLineNode && secondNode == inverterNeutralNode) ||
          (firstNode == inverterNeutralNode && secondNode == inverterLineNode);
      if (!connectedToAcBus) {
        if (explicitPvLoad) {
          diagnostics.add(
            PvSolverDiagnostic(
              code: PvDiagnosticCode.acOutputDisconnected,
              severity: PvDiagnosticSeverity.error,
              message:
                  'PV load ${load.id.value} is not connected to the inverter AC output bus.',
              componentId: load.id,
            ),
          );
        }
        continue;
      }

      final _LoadParameters? parameters = _loadParameters(load, diagnostics);
      if (parameters != null) loadParameters.add(parameters);
    }
    if (_hasErrors(diagnostics)) {
      return _failure(circuit, diagnostics);
    }

    final double rawIrradianceWm2 = _nonNegativeSetting(
      circuit,
      'irradianceWm2',
      options.referenceIrradianceWm2,
      diagnostics,
    );
    final double shadingPct = _boundedPercentageSetting(
      circuit,
      'shadingPct',
      0.0,
      diagnostics,
    );
    final double irradianceWm2 = rawIrradianceWm2 * (1.0 - shadingPct / 100.0);
    final double cellTemperatureC = _finiteSetting(
      circuit,
      'cellTemperatureC',
      options.referenceCellTemperatureC,
      diagnostics,
    );
    if (_hasErrors(diagnostics)) {
      return _failure(circuit, diagnostics);
    }

    final double irradianceFactor = options.referenceIrradianceWm2 <= 0.0
        ? 0.0
        : irradianceWm2 / options.referenceIrradianceWm2;
    final double temperatureDelta =
        cellTemperatureC - options.referenceCellTemperatureC;
    final double voltageFactor = math.max(
      0.0,
      1.0 +
          arrayParameters.voltageTemperatureCoefficientPerC * temperatureDelta,
    );
    final double powerTemperatureFactor = math.max(
      0.0,
      1.0 + arrayParameters.powerTemperatureCoefficientPerC * temperatureDelta,
    );
    final double operatingVoltageV =
        arrayParameters.mppVoltageV * voltageFactor;
    final double availablePowerW =
        arrayParameters.mppVoltageV *
        arrayParameters.mppCurrentA *
        irradianceFactor *
        powerTemperatureFactor;
    final double availableCurrentA =
        operatingVoltageV <= options.numericTolerance
        ? 0.0
        : availablePowerW / operatingVoltageV;

    if (controller != null && controllerParameters != null &&
        operatingVoltageV >
            controllerParameters.maxPvInputVoltageV + options.numericTolerance) {
      diagnostics.add(
        PvSolverDiagnostic(
          code: PvDiagnosticCode.controllerInputVoltageOutOfRange,
          severity: PvDiagnosticSeverity.error,
          message:
              '${controllerParameters.controllerType.toUpperCase()} controller PV input '
              '${operatingVoltageV.toStringAsFixed(0)} V exceeds its '
              '${controllerParameters.maxPvInputVoltageV.toStringAsFixed(0)} V limit.',
          componentId: controller.id,
          sourceId: array.id,
        ),
      );
      return _failure(circuit, diagnostics);
    }

    if (controller != null && battery != null) {
      if (inverter == null) {
        return _solveStorageOnlyChain(
          circuit: circuit,
          array: array,
          controller: controller,
          battery: battery,
          controllerParameters: controllerParameters!,
          batteryParameters: batteryParameters!,
          diagnostics: diagnostics,
          irradianceWm2: irradianceWm2,
          cellTemperatureC: cellTemperatureC,
          operatingVoltageV: operatingVoltageV,
          availableCurrentA: availableCurrentA,
          availablePowerW: availablePowerW,
          previousBatterySoc: previousBatterySoc,
          elapsed: elapsed,
        );
      }
      return _solveStorageChain(
        circuit: circuit,
        array: array,
        inverter: inverter,
        controller: controller,
        battery: battery,
        inverterParameters: inverterParameters!,
        controllerParameters: controllerParameters!,
        batteryParameters: batteryParameters!,
        loadParameters: loadParameters,
        diagnostics: diagnostics,
        irradianceWm2: irradianceWm2,
        cellTemperatureC: cellTemperatureC,
        operatingVoltageV: operatingVoltageV,
        availableCurrentA: availableCurrentA,
        availablePowerW: availablePowerW,
        inverterDcConnected: inverterDcConnected,
        previousBatterySoc: previousBatterySoc,
        elapsed: elapsed,
      );
    }

    final _InverterAvailability availability = _inverterAvailability(
      inverter!,
      inverterParameters!,
      operatingVoltageV,
      diagnostics,
    );
    if (_hasErrors(diagnostics)) {
      return _failure(circuit, diagnostics);
    }

    final double totalConductance = loadParameters.fold<double>(
      0.0,
      (double sum, _LoadParameters load) => sum + (1.0 / load.resistanceOhm),
    );
    final double nominalLoadPowerW =
        inverterParameters.nominalAcVoltageV *
        inverterParameters.nominalAcVoltageV *
        totalConductance;

    double outputPowerW = 0.0;
    double outputVoltageV = 0.0;
    double outputCurrentA = 0.0;
    double dcDrawnPowerW = 0.0;
    PvInverterState inverterState = availability.state;

    if (availability.canOperate) {
      final double ratedPowerW =
          inverterParameters.ratedAcPowerW * availability.deratingFactor;
      final double maxOutputFromPvW =
          availablePowerW * inverterParameters.efficiency;
      final double availableAcPowerW = math.min(ratedPowerW, maxOutputFromPvW);
      outputPowerW = math.min(nominalLoadPowerW, availableAcPowerW);
      if (totalConductance <= options.numericTolerance) {
        outputVoltageV = inverterParameters.nominalAcVoltageV;
        outputCurrentA = 0.0;
        inverterState = PvInverterState.idle;
      } else if (nominalLoadPowerW <=
          availableAcPowerW + options.numericTolerance) {
        outputVoltageV = inverterParameters.nominalAcVoltageV;
        outputCurrentA = outputVoltageV * totalConductance;
        inverterState = PvInverterState.running;
      } else {
        outputVoltageV = outputPowerW <= options.numericTolerance
            ? 0.0
            : math.sqrt(outputPowerW / totalConductance);
        outputCurrentA = outputVoltageV * totalConductance;
        inverterState = PvInverterState.powerLimited;
        diagnostics.add(
          PvSolverDiagnostic(
            code: PvDiagnosticCode.powerLimited,
            severity: PvDiagnosticSeverity.warning,
            message:
                'Inverter output is power-limited by PV availability or inverter rating.',
            componentId: inverter.id,
          ),
        );
      }
      dcDrawnPowerW = outputPowerW <= options.numericTolerance
          ? 0.0
          : outputPowerW / inverterParameters.efficiency;
    }

    dcDrawnPowerW = math.min(dcDrawnPowerW, availablePowerW);
    final double drawnCurrentA = operatingVoltageV <= options.numericTolerance
        ? 0.0
        : dcDrawnPowerW / operatingVoltageV;
    final double conversionLossW = math.max(0.0, dcDrawnPowerW - outputPowerW);
    final double curtailedPowerW = math.max(
      0.0,
      availablePowerW - dcDrawnPowerW,
    );

    final List<PvLoadResult> loadResults = <PvLoadResult>[
      for (final _LoadParameters load in loadParameters)
        PvLoadResult(
          componentId: load.componentId,
          resistanceOhm: load.resistanceOhm,
          voltageRmsV: outputVoltageV,
          currentRmsA: outputVoltageV / load.resistanceOhm,
          activePowerW: outputVoltageV * outputVoltageV / load.resistanceOhm,
        ),
    ];

    return PvSolveResult(
      circuitId: circuit.circuitId,
      circuitRevision: circuit.revision,
      engineVersion: engineVersion,
      status: PvSolveStatus.solved,
      irradianceWm2: irradianceWm2,
      cellTemperatureC: cellTemperatureC,
      pvOperatingVoltageV: operatingVoltageV,
      pvAvailableCurrentA: availableCurrentA,
      pvAvailablePowerW: availablePowerW,
      pvDrawnCurrentA: drawnCurrentA,
      pvDrawnPowerW: dcDrawnPowerW,
      curtailedPowerW: curtailedPowerW,
      inverterState: inverterState,
      inverterEfficiency: inverterParameters.efficiency,
      inverterOutputVoltageRmsV: outputVoltageV,
      inverterOutputCurrentRmsA: outputCurrentA,
      inverterOutputPowerW: outputPowerW,
      inverterConversionLossW: conversionLossW,
      loadResults: loadResults,
      diagnostics: diagnostics,
    );
  }

  PvSolveResult _solveStorageOnlyChain({
    required CircuitState circuit,
    required SourceInstance array,
    required ComponentInstance controller,
    required ComponentInstance battery,
    required _ControllerParameters controllerParameters,
    required _BatteryParameters batteryParameters,
    required List<PvSolverDiagnostic> diagnostics,
    required double irradianceWm2,
    required double cellTemperatureC,
    required double operatingVoltageV,
    required double availableCurrentA,
    required double availablePowerW,
    required double? previousBatterySoc,
    required Duration elapsed,
  }) {
    if ((controllerParameters.outputVoltageV -
                batteryParameters.nominalVoltageV)
            .abs() >
        options.numericTolerance) {
      diagnostics.add(
        PvSolverDiagnostic(
          code: PvDiagnosticCode.invalidControllerParameter,
          severity: PvDiagnosticSeverity.error,
          message:
              'pv_controller outputVoltageV must match pv_battery nominalVoltageV.',
          componentId: controller.id,
        ),
      );
      return _failure(circuit, diagnostics);
    }

    final bool controllerOperational =
        controller.condition == ComponentCondition.normal ||
        controller.condition == ComponentCondition.degraded;
    double controllerDerating = 1.0;
    if (controller.condition == ComponentCondition.degraded) {
      final double? raw = _finiteOptionalNumber(
        controller.parameters,
        'deratingFactor',
        0.75,
      );
      if (raw == null || raw <= 0.0 || raw > 1.0) {
        diagnostics.add(
          PvSolverDiagnostic(
            code: PvDiagnosticCode.invalidControllerParameter,
            severity: PvDiagnosticSeverity.error,
            message: 'Degraded pv_controller requires deratingFactor in (0,1].',
            componentId: controller.id,
          ),
        );
        return _failure(circuit, diagnostics);
      }
      controllerDerating = raw;
    } else if (!controllerOperational) {
      diagnostics.add(
        PvSolverDiagnostic(
          code: PvDiagnosticCode.controllerFaulted,
          severity: PvDiagnosticSeverity.warning,
          message:
              'PV controller condition disables transfer from the array to the DC bus.',
          componentId: controller.id,
        ),
      );
    }

    final double busVoltageV = controllerParameters.outputVoltageV;
    final double controllerOutputLimitW =
        busVoltageV *
        controllerParameters.maxOutputCurrentA *
        controllerDerating;
    final double pvBusAvailablePowerW = controllerOperational
        ? math.min(
            availablePowerW * controllerParameters.efficiency,
            controllerOutputLimitW,
          )
        : 0.0;

    final double capacityWh =
        batteryParameters.nominalVoltageV * batteryParameters.capacityAh;
    final double initialSoc =
        (previousBatterySoc ?? batteryParameters.initialSoc)
            .clamp(batteryParameters.minSoc, batteryParameters.maxSoc)
            .toDouble();
    final double elapsedHours = elapsed.inMicroseconds / 3600000000.0;
    final double batteryHeadroomWh = math.max(
      0.0,
      (batteryParameters.maxSoc - initialSoc) * capacityWh,
    );
    double maxChargeInputW = busVoltageV * batteryParameters.maxChargeCurrentA;
    if (elapsedHours > 0.0) {
      maxChargeInputW = math.min(
        maxChargeInputW,
        batteryHeadroomWh / (elapsedHours * batteryParameters.chargeEfficiency),
      );
    }

    final double batteryChargeInputW = math.min(
      pvBusAvailablePowerW,
      maxChargeInputW,
    );
    final double batteryStoredChargeW =
        batteryChargeInputW * batteryParameters.chargeEfficiency;
    final double deltaEnergyWh = elapsedHours <= 0.0
        ? 0.0
        : batteryStoredChargeW * elapsedHours;
    final double finalStoredEnergyWh = (initialSoc * capacityWh + deltaEnergyWh)
        .clamp(
          batteryParameters.minSoc * capacityWh,
          batteryParameters.maxSoc * capacityWh,
        )
        .toDouble();
    final double finalSoc = capacityWh <= options.numericTolerance
        ? initialSoc
        : finalStoredEnergyWh / capacityWh;

    if (pvBusAvailablePowerW >
            batteryChargeInputW + options.numericTolerance &&
        initialSoc >= batteryParameters.maxSoc - options.numericTolerance) {
      diagnostics.add(
        PvSolverDiagnostic(
          code: PvDiagnosticCode.batteryFull,
          severity: PvDiagnosticSeverity.info,
          message: 'Battery reached its maximum state of charge.',
          componentId: battery.id,
        ),
      );
    }

    final double arrayDrawnPowerW = controllerOperational
        ? math.min(
            availablePowerW,
            batteryChargeInputW / controllerParameters.efficiency,
          )
        : 0.0;
    final double drawnCurrentA = operatingVoltageV <= options.numericTolerance
        ? 0.0
        : arrayDrawnPowerW / operatingVoltageV;
    final double controllerLossW = math.max(
      0.0,
      arrayDrawnPowerW - batteryChargeInputW,
    );
    final double batteryLossW = math.max(
      0.0,
      batteryChargeInputW - batteryStoredChargeW,
    );

    return PvSolveResult(
      circuitId: circuit.circuitId,
      circuitRevision: circuit.revision,
      engineVersion: engineVersion,
      status: PvSolveStatus.solved,
      irradianceWm2: irradianceWm2,
      cellTemperatureC: cellTemperatureC,
      pvOperatingVoltageV: operatingVoltageV,
      pvAvailableCurrentA: availableCurrentA,
      pvAvailablePowerW: availablePowerW,
      pvDrawnCurrentA: drawnCurrentA,
      pvDrawnPowerW: arrayDrawnPowerW,
      curtailedPowerW: math.max(0.0, availablePowerW - arrayDrawnPowerW),
      inverterState: PvInverterState.idle,
      inverterEfficiency: 0.0,
      inverterOutputVoltageRmsV: 0.0,
      inverterOutputCurrentRmsA: 0.0,
      inverterOutputPowerW: 0.0,
      inverterConversionLossW: 0.0,
      controllerPresent: true,
      controllerEfficiency: controllerParameters.efficiency,
      controllerConversionLossW: controllerLossW,
      batteryPresent: true,
      batteryVoltageV: busVoltageV,
      batterySoc: finalSoc,
      batteryStoredEnergyWh: finalStoredEnergyWh,
      batteryPowerW: -batteryChargeInputW,
      batteryConversionLossW: batteryLossW,
      loadResults: const <PvLoadResult>[],
      diagnostics: diagnostics,
    );
  }

  PvSolveResult _solveStorageChain({
    required CircuitState circuit,
    required SourceInstance array,
    required ComponentInstance inverter,
    required ComponentInstance controller,
    required ComponentInstance battery,
    required _InverterParameters inverterParameters,
    required _ControllerParameters controllerParameters,
    required _BatteryParameters batteryParameters,
    required List<_LoadParameters> loadParameters,
    required List<PvSolverDiagnostic> diagnostics,
    required double irradianceWm2,
    required double cellTemperatureC,
    required double operatingVoltageV,
    required double availableCurrentA,
    required double availablePowerW,
    required bool inverterDcConnected,
    required double? previousBatterySoc,
    required Duration elapsed,
  }) {
    if ((controllerParameters.outputVoltageV -
                batteryParameters.nominalVoltageV)
            .abs() >
        options.numericTolerance) {
      diagnostics.add(
        PvSolverDiagnostic(
          code: PvDiagnosticCode.invalidControllerParameter,
          severity: PvDiagnosticSeverity.error,
          message:
              'pv_controller outputVoltageV must match pv_battery nominalVoltageV.',
          componentId: controller.id,
        ),
      );
      return _failure(circuit, diagnostics);
    }

    final double capacityWh =
        batteryParameters.nominalVoltageV * batteryParameters.capacityAh;
    final double initialSoc =
        (previousBatterySoc ?? batteryParameters.initialSoc)
            .clamp(batteryParameters.minSoc, batteryParameters.maxSoc)
            .toDouble();
    final double elapsedHours = elapsed.inMicroseconds / 3600000000.0;

    final bool controllerOperational =
        controller.condition == ComponentCondition.normal ||
        controller.condition == ComponentCondition.degraded;
    double controllerDerating = 1.0;
    if (controller.condition == ComponentCondition.degraded) {
      final double? raw = _finiteOptionalNumber(
        controller.parameters,
        'deratingFactor',
        0.75,
      );
      if (raw == null || raw <= 0.0 || raw > 1.0) {
        diagnostics.add(
          PvSolverDiagnostic(
            code: PvDiagnosticCode.invalidControllerParameter,
            severity: PvDiagnosticSeverity.error,
            message: 'Degraded pv_controller requires deratingFactor in (0,1].',
            componentId: controller.id,
          ),
        );
        return _failure(circuit, diagnostics);
      }
      controllerDerating = raw;
    } else if (!controllerOperational) {
      diagnostics.add(
        PvSolverDiagnostic(
          code: PvDiagnosticCode.controllerFaulted,
          severity: PvDiagnosticSeverity.warning,
          message:
              'PV controller condition disables transfer from the array to the DC bus.',
          componentId: controller.id,
        ),
      );
    }

    final double busVoltageV = controllerParameters.outputVoltageV;
    final double controllerOutputLimitW =
        busVoltageV *
        controllerParameters.maxOutputCurrentA *
        controllerDerating;
    final double pvBusAvailablePowerW = controllerOperational
        ? math.min(
            availablePowerW * controllerParameters.efficiency,
            controllerOutputLimitW,
          )
        : 0.0;

    final _InverterAvailability availability = inverterDcConnected
        ? _inverterAvailability(
            inverter,
            inverterParameters,
            busVoltageV,
            diagnostics,
          )
        : const _InverterAvailability(
            canOperate: false,
            state: PvInverterState.idle,
            deratingFactor: 0.0,
          );
    if (_hasErrors(diagnostics)) {
      return _failure(circuit, diagnostics);
    }

    final double totalConductance = loadParameters.fold<double>(
      0.0,
      (double sum, _LoadParameters load) => sum + (1.0 / load.resistanceOhm),
    );
    final double nominalLoadPowerW =
        inverterParameters.nominalAcVoltageV *
        inverterParameters.nominalAcVoltageV *
        totalConductance;

    final double ratedAcPowerW =
        inverterParameters.ratedAcPowerW * availability.deratingFactor;
    final double desiredAcPowerW = availability.canOperate
        ? math.min(nominalLoadPowerW, ratedAcPowerW)
        : 0.0;
    final double requiredDcPowerW = desiredAcPowerW <= options.numericTolerance
        ? 0.0
        : desiredAcPowerW / inverterParameters.efficiency;

    final double pvToInverterW = math.min(
      pvBusAvailablePowerW,
      requiredDcPowerW,
    );
    final double dcDeficitW = math.max(0.0, requiredDcPowerW - pvToInverterW);

    final double availableBatteryEnergyWh = math.max(
      0.0,
      (initialSoc - batteryParameters.minSoc) * capacityWh,
    );
    double maxBatteryRawDischargeW =
        busVoltageV * batteryParameters.maxDischargeCurrentA;
    if (elapsedHours > 0.0) {
      maxBatteryRawDischargeW = math.min(
        maxBatteryRawDischargeW,
        availableBatteryEnergyWh / elapsedHours,
      );
    }
    final double rawBatteryDischargeW = math.min(
      maxBatteryRawDischargeW,
      dcDeficitW / batteryParameters.dischargeEfficiency,
    );
    final double batteryBusDischargeW =
        rawBatteryDischargeW * batteryParameters.dischargeEfficiency;

    final double inverterDcAvailableW = pvToInverterW + batteryBusDischargeW;
    final double availableAcPowerW =
        inverterDcAvailableW * inverterParameters.efficiency;
    final double outputPowerW = math.min(desiredAcPowerW, availableAcPowerW);

    double outputVoltageV = 0.0;
    double outputCurrentA = 0.0;
    PvInverterState inverterState = availability.state;
    if (availability.canOperate) {
      if (totalConductance <= options.numericTolerance) {
        outputVoltageV = inverterParameters.nominalAcVoltageV;
        inverterState = PvInverterState.idle;
      } else if (outputPowerW + options.numericTolerance >= nominalLoadPowerW) {
        outputVoltageV = inverterParameters.nominalAcVoltageV;
        outputCurrentA = outputVoltageV * totalConductance;
        inverterState = PvInverterState.running;
      } else {
        outputVoltageV = outputPowerW <= options.numericTolerance
            ? 0.0
            : math.sqrt(outputPowerW / totalConductance);
        outputCurrentA = outputVoltageV * totalConductance;
        inverterState = PvInverterState.powerLimited;
        diagnostics.add(
          PvSolverDiagnostic(
            code: PvDiagnosticCode.powerLimited,
            severity: PvDiagnosticSeverity.warning,
            message:
                'Inverter output is limited by PV + battery availability or inverter rating.',
            componentId: inverter.id,
          ),
        );
      }
    }

    final double actualInverterDcW = outputPowerW <= options.numericTolerance
        ? 0.0
        : outputPowerW / inverterParameters.efficiency;
    final double actualPvToInverterW = math.min(
      pvBusAvailablePowerW,
      actualInverterDcW,
    );
    final double actualBatteryBusDischargeW = math.max(
      0.0,
      actualInverterDcW - actualPvToInverterW,
    );
    final double actualRawBatteryDischargeW =
        actualBatteryBusDischargeW <= options.numericTolerance
        ? 0.0
        : actualBatteryBusDischargeW / batteryParameters.dischargeEfficiency;

    final double pvBusSurplusW = math.max(
      0.0,
      pvBusAvailablePowerW - actualPvToInverterW,
    );
    final double batteryHeadroomWh = math.max(
      0.0,
      (batteryParameters.maxSoc - initialSoc) * capacityWh,
    );
    double maxChargeInputW = busVoltageV * batteryParameters.maxChargeCurrentA;
    if (elapsedHours > 0.0) {
      maxChargeInputW = math.min(
        maxChargeInputW,
        batteryHeadroomWh / (elapsedHours * batteryParameters.chargeEfficiency),
      );
    }
    final double batteryChargeInputW = math.min(pvBusSurplusW, maxChargeInputW);
    final double batteryStoredChargeW =
        batteryChargeInputW * batteryParameters.chargeEfficiency;

    final double deltaEnergyWh = elapsedHours <= 0.0
        ? 0.0
        : (batteryStoredChargeW - actualRawBatteryDischargeW) * elapsedHours;
    final double finalStoredEnergyWh = (initialSoc * capacityWh + deltaEnergyWh)
        .clamp(
          batteryParameters.minSoc * capacityWh,
          batteryParameters.maxSoc * capacityWh,
        )
        .toDouble();
    final double finalSoc = capacityWh <= options.numericTolerance
        ? initialSoc
        : finalStoredEnergyWh / capacityWh;

    if (dcDeficitW > batteryBusDischargeW + options.numericTolerance &&
        initialSoc <= batteryParameters.minSoc + options.numericTolerance) {
      diagnostics.add(
        PvSolverDiagnostic(
          code: PvDiagnosticCode.batteryEmpty,
          severity: PvDiagnosticSeverity.warning,
          message: 'Battery reached its minimum state of charge.',
          componentId: battery.id,
        ),
      );
    }
    if (pvBusSurplusW > batteryChargeInputW + options.numericTolerance &&
        initialSoc >= batteryParameters.maxSoc - options.numericTolerance) {
      diagnostics.add(
        PvSolverDiagnostic(
          code: PvDiagnosticCode.batteryFull,
          severity: PvDiagnosticSeverity.info,
          message: 'Battery reached its maximum state of charge.',
          componentId: battery.id,
        ),
      );
    }

    final double pvBusUsedW = actualPvToInverterW + batteryChargeInputW;
    final double arrayDrawnPowerW = controllerOperational
        ? math.min(
            availablePowerW,
            pvBusUsedW / controllerParameters.efficiency,
          )
        : 0.0;
    final double drawnCurrentA = operatingVoltageV <= options.numericTolerance
        ? 0.0
        : arrayDrawnPowerW / operatingVoltageV;
    final double controllerLossW = math.max(0.0, arrayDrawnPowerW - pvBusUsedW);
    final double inverterLossW = math.max(
      0.0,
      actualInverterDcW - outputPowerW,
    );
    final double batteryLossW = math.max(
      0.0,
      (actualRawBatteryDischargeW - actualBatteryBusDischargeW) +
          (batteryChargeInputW - batteryStoredChargeW),
    );
    final double curtailedPowerW = math.max(
      0.0,
      availablePowerW - arrayDrawnPowerW,
    );

    final List<PvLoadResult> loadResults = <PvLoadResult>[
      for (final _LoadParameters load in loadParameters)
        PvLoadResult(
          componentId: load.componentId,
          resistanceOhm: load.resistanceOhm,
          voltageRmsV: outputVoltageV,
          currentRmsA: outputVoltageV / load.resistanceOhm,
          activePowerW: outputVoltageV * outputVoltageV / load.resistanceOhm,
        ),
    ];

    return PvSolveResult(
      circuitId: circuit.circuitId,
      circuitRevision: circuit.revision,
      engineVersion: engineVersion,
      status: PvSolveStatus.solved,
      irradianceWm2: irradianceWm2,
      cellTemperatureC: cellTemperatureC,
      pvOperatingVoltageV: operatingVoltageV,
      pvAvailableCurrentA: availableCurrentA,
      pvAvailablePowerW: availablePowerW,
      pvDrawnCurrentA: drawnCurrentA,
      pvDrawnPowerW: arrayDrawnPowerW,
      curtailedPowerW: curtailedPowerW,
      inverterState: inverterState,
      inverterEfficiency: inverterParameters.efficiency,
      inverterOutputVoltageRmsV: outputVoltageV,
      inverterOutputCurrentRmsA: outputCurrentA,
      inverterOutputPowerW: outputPowerW,
      inverterConversionLossW: inverterLossW,
      controllerPresent: true,
      controllerEfficiency: controllerParameters.efficiency,
      controllerConversionLossW: controllerLossW,
      batteryPresent: true,
      batteryVoltageV: busVoltageV,
      batterySoc: finalSoc,
      batteryStoredEnergyWh: finalStoredEnergyWh,
      batteryPowerW: actualBatteryBusDischargeW > options.numericTolerance
          ? actualBatteryBusDischargeW
          : -batteryChargeInputW,
      batteryConversionLossW: batteryLossW,
      loadResults: loadResults,
      diagnostics: diagnostics,
    );
  }

  _ControllerParameters? _controllerParameters(
    ComponentInstance controller,
    List<PvSolverDiagnostic> diagnostics,
  ) {
    final double? outputVoltage = _positiveNumber(
      controller.parameters,
      'outputVoltageV',
    );
    final double? maxCurrent = _positiveNumber(
      controller.parameters,
      'maxOutputCurrentA',
    );
    final double? efficiency = _positiveNumber(
      controller.parameters,
      'efficiency',
    );
    final Object? rawControllerType = controller.parameters['controllerType'];
    final String controllerType = rawControllerType is String
        ? rawControllerType.toLowerCase()
        : 'mppt';
    final Object? rawMaxPvInput = controller.parameters['maxPvInputVoltageV'];
    final double? maxPvInputVoltageV = rawMaxPvInput == null
        ? (controllerType == 'pwm'
              ? (outputVoltage == null ? null : outputVoltage * 1.25)
              : 450.0)
        : rawMaxPvInput is num &&
              rawMaxPvInput.toDouble().isFinite &&
              rawMaxPvInput.toDouble() > 0.0
        ? rawMaxPvInput.toDouble()
        : null;
    if (outputVoltage == null ||
        maxCurrent == null ||
        efficiency == null ||
        efficiency > 1.0 ||
        (controllerType != 'mppt' && controllerType != 'pwm') ||
        maxPvInputVoltageV == null) {
      diagnostics.add(
        PvSolverDiagnostic(
          code: PvDiagnosticCode.invalidControllerParameter,
          severity: PvDiagnosticSeverity.error,
          message:
              'pv_controller requires outputVoltageV/maxOutputCurrentA > 0 and efficiency in (0,1].',
          componentId: controller.id,
        ),
      );
      return null;
    }
    return _ControllerParameters(
      outputVoltageV: outputVoltage,
      maxOutputCurrentA: maxCurrent,
      efficiency: efficiency,
      controllerType: controllerType,
      maxPvInputVoltageV: maxPvInputVoltageV,
    );
  }

  _BatteryParameters? _batteryParameters(
    ComponentInstance battery,
    List<PvSolverDiagnostic> diagnostics,
  ) {
    final double? voltage = _positiveNumber(
      battery.parameters,
      'nominalVoltageV',
    );
    final double? capacity = _positiveNumber(battery.parameters, 'capacityAh');
    final double? maxCharge = _positiveNumber(
      battery.parameters,
      'maxChargeCurrentA',
    );
    final double? maxDischarge = _positiveNumber(
      battery.parameters,
      'maxDischargeCurrentA',
    );
    final double? chargeEfficiency = _positiveNumber(
      battery.parameters,
      'chargeEfficiency',
    );
    final double? dischargeEfficiency = _positiveNumber(
      battery.parameters,
      'dischargeEfficiency',
    );
    final double? initialSoc = _finiteOptionalNumber(
      battery.parameters,
      'initialSoc',
      0.5,
    );
    final double? minSoc = _finiteOptionalNumber(
      battery.parameters,
      'minSoc',
      0.1,
    );
    final double? maxSoc = _finiteOptionalNumber(
      battery.parameters,
      'maxSoc',
      1.0,
    );
    if (voltage == null ||
        capacity == null ||
        maxCharge == null ||
        maxDischarge == null ||
        chargeEfficiency == null ||
        chargeEfficiency > 1.0 ||
        dischargeEfficiency == null ||
        dischargeEfficiency > 1.0 ||
        initialSoc == null ||
        minSoc == null ||
        maxSoc == null ||
        minSoc < 0.0 ||
        maxSoc > 1.0 ||
        minSoc >= maxSoc ||
        initialSoc < minSoc ||
        initialSoc > maxSoc) {
      diagnostics.add(
        PvSolverDiagnostic(
          code: PvDiagnosticCode.invalidBatteryParameter,
          severity: PvDiagnosticSeverity.error,
          message:
              'pv_battery requires valid voltage/capacity/current limits, efficiencies in (0,1], and minSoc <= initialSoc <= maxSoc.',
          componentId: battery.id,
        ),
      );
      return null;
    }
    return _BatteryParameters(
      nominalVoltageV: voltage,
      capacityAh: capacity,
      initialSoc: initialSoc,
      minSoc: minSoc,
      maxSoc: maxSoc,
      maxChargeCurrentA: maxCharge,
      maxDischargeCurrentA: maxDischarge,
      chargeEfficiency: chargeEfficiency,
      dischargeEfficiency: dischargeEfficiency,
    );
  }

  _ControllerTerminalContract? _controllerTerminals(
    ComponentInstance controller,
    List<PvSolverDiagnostic> diagnostics,
  ) {
    if (controller.terminals.length != 4) {
      diagnostics.add(
        PvSolverDiagnostic(
          code: PvDiagnosticCode.invalidTerminalContract,
          severity: PvDiagnosticSeverity.error,
          message: 'pv_controller requires four ordered DC terminals.',
          componentId: controller.id,
        ),
      );
      return null;
    }
    return _ControllerTerminalContract(
      pvPositive: controller.terminals[0],
      pvNegative: controller.terminals[1],
      busPositive: controller.terminals[2],
      busNegative: controller.terminals[3],
    );
  }

  _BatteryTerminalContract? _batteryTerminals(
    ComponentInstance battery,
    List<PvSolverDiagnostic> diagnostics,
  ) {
    if (battery.terminals.length != 2 ||
        battery.terminals[0].phase != PhaseTag.dcPositive ||
        battery.terminals[1].phase != PhaseTag.dcNegative) {
      diagnostics.add(
        PvSolverDiagnostic(
          code: PvDiagnosticCode.invalidTerminalContract,
          severity: PvDiagnosticSeverity.error,
          message:
              'pv_battery requires ordered dcPositive/dcNegative terminals.',
          componentId: battery.id,
        ),
      );
      return null;
    }
    return _BatteryTerminalContract(
      positive: battery.terminals[0],
      negative: battery.terminals[1],
    );
  }

  _PvArrayParameters? _arrayParameters(
    SourceInstance source,
    List<PvSolverDiagnostic> diagnostics,
  ) {
    final double? voltage = _positiveNumber(source.parameters, 'mppVoltageV');
    final double? current = _positiveNumber(source.parameters, 'mppCurrentA');
    final double? powerCoefficient = _finiteOptionalNumber(
      source.parameters,
      'powerTemperatureCoefficientPerC',
      0.0,
    );
    final double? voltageCoefficient = _finiteOptionalNumber(
      source.parameters,
      'voltageTemperatureCoefficientPerC',
      0.0,
    );
    if (voltage == null ||
        current == null ||
        powerCoefficient == null ||
        voltageCoefficient == null) {
      diagnostics.add(
        PvSolverDiagnostic(
          code: PvDiagnosticCode.invalidPvParameter,
          severity: PvDiagnosticSeverity.error,
          message:
              'pv_array requires positive mppVoltageV/mppCurrentA and finite temperature coefficients.',
          sourceId: source.id,
        ),
      );
      return null;
    }
    return _PvArrayParameters(
      mppVoltageV: voltage,
      mppCurrentA: current,
      powerTemperatureCoefficientPerC: powerCoefficient,
      voltageTemperatureCoefficientPerC: voltageCoefficient,
    );
  }

  _InverterParameters? _inverterParameters(
    ComponentInstance inverter,
    List<PvSolverDiagnostic> diagnostics,
  ) {
    final double? minDc = _positiveNumber(inverter.parameters, 'minDcVoltageV');
    final double? maxDc = _positiveNumber(inverter.parameters, 'maxDcVoltageV');
    final double? acVoltage = _positiveNumber(
      inverter.parameters,
      'nominalAcVoltageV',
    );
    final double? ratedPower = _positiveNumber(
      inverter.parameters,
      'ratedAcPowerW',
    );
    final double? efficiency = _positiveNumber(
      inverter.parameters,
      'efficiency',
    );
    if (minDc == null ||
        maxDc == null ||
        maxDc < minDc ||
        acVoltage == null ||
        ratedPower == null ||
        efficiency == null ||
        efficiency > 1.0) {
      diagnostics.add(
        PvSolverDiagnostic(
          code: PvDiagnosticCode.invalidInverterParameter,
          severity: PvDiagnosticSeverity.error,
          message:
              'pv_inverter requires valid DC limits, nominal AC voltage, rating and efficiency in (0,1].',
          componentId: inverter.id,
        ),
      );
      return null;
    }
    return _InverterParameters(
      minDcVoltageV: minDc,
      maxDcVoltageV: maxDc,
      nominalAcVoltageV: acVoltage,
      ratedAcPowerW: ratedPower,
      efficiency: efficiency,
    );
  }

  _LoadParameters? _loadParameters(
    ComponentInstance load,
    List<PvSolverDiagnostic> diagnostics,
  ) {
    final double? resistance = _positiveNumber(
      load.parameters,
      'resistanceOhm',
    );
    if (resistance == null) {
      diagnostics.add(
        PvSolverDiagnostic(
          code: PvDiagnosticCode.invalidLoadParameter,
          severity: PvDiagnosticSeverity.error,
          message: 'PV resistive receiver requires positive resistanceOhm.',
          componentId: load.id,
        ),
      );
      return null;
    }
    return _LoadParameters(componentId: load.id, resistanceOhm: resistance);
  }

  _PvTerminalContract? _pvArrayTerminals(
    SourceInstance source,
    List<PvSolverDiagnostic> diagnostics,
  ) {
    final Terminal? positive = _terminalForPhase(
      source.terminals,
      PhaseTag.dcPositive,
    );
    final Terminal? negative = _terminalForPhase(
      source.terminals,
      PhaseTag.dcNegative,
    );
    if (positive == null || negative == null) {
      diagnostics.add(
        PvSolverDiagnostic(
          code: PvDiagnosticCode.invalidTerminalContract,
          severity: PvDiagnosticSeverity.error,
          message:
              'pv_array requires explicit dcPositive and dcNegative terminals.',
          sourceId: source.id,
        ),
      );
      return null;
    }
    return _PvTerminalContract(positive: positive, negative: negative);
  }

  _InverterTerminalContract? _inverterTerminals(
    ComponentInstance inverter,
    List<PvSolverDiagnostic> diagnostics,
  ) {
    final Terminal? positive = _terminalForPhase(
      inverter.terminals,
      PhaseTag.dcPositive,
    );
    final Terminal? negative = _terminalForPhase(
      inverter.terminals,
      PhaseTag.dcNegative,
    );
    final Terminal? line = _terminalForPhase(inverter.terminals, PhaseTag.l1);
    final Terminal? neutral = _terminalForPhase(
      inverter.terminals,
      PhaseTag.neutral,
    );
    if (positive == null ||
        negative == null ||
        line == null ||
        neutral == null) {
      diagnostics.add(
        PvSolverDiagnostic(
          code: PvDiagnosticCode.invalidTerminalContract,
          severity: PvDiagnosticSeverity.error,
          message:
              'pv_inverter requires dcPositive, dcNegative, l1 and neutral terminals.',
          componentId: inverter.id,
        ),
      );
      return null;
    }
    return _InverterTerminalContract(
      dcPositive: positive,
      dcNegative: negative,
      acLine: line,
      acNeutral: neutral,
    );
  }

  _LoadTerminalContract? _loadTerminals(
    ComponentInstance load,
    List<PvSolverDiagnostic> diagnostics, {
    bool allowGenericPair = false,
  }) {
    final Terminal? line = _terminalForPhase(load.terminals, PhaseTag.l1);
    final Terminal? neutral = _terminalForPhase(
      load.terminals,
      PhaseTag.neutral,
    );
    if (line != null && neutral != null) {
      return _LoadTerminalContract(line: line, neutral: neutral);
    }
    if (allowGenericPair && load.terminals.length == 2) {
      return _LoadTerminalContract(
        line: load.terminals[0],
        neutral: load.terminals[1],
      );
    }
    diagnostics.add(
      PvSolverDiagnostic(
        code: PvDiagnosticCode.invalidTerminalContract,
        severity: PvDiagnosticSeverity.error,
        message:
            'PV AC load requires two terminals connected across inverter L-N.',
        componentId: load.id,
      ),
    );
    return null;
  }

  _InverterAvailability _inverterAvailability(
    ComponentInstance inverter,
    _InverterParameters parameters,
    double inputVoltageV,
    List<PvSolverDiagnostic> diagnostics,
  ) {
    switch (inverter.condition) {
      case ComponentCondition.normal:
        break;
      case ComponentCondition.degraded:
        final double? factor = _positiveNumber(
          inverter.parameters,
          'deratingFactor',
        );
        if (factor == null || factor > 1.0) {
          diagnostics.add(
            PvSolverDiagnostic(
              code: PvDiagnosticCode.invalidInverterParameter,
              severity: PvDiagnosticSeverity.error,
              message: 'Degraded inverter requires deratingFactor in (0,1].',
              componentId: inverter.id,
            ),
          );
          return const _InverterAvailability(
            canOperate: false,
            state: PvInverterState.faulted,
            deratingFactor: 0.0,
          );
        }
        diagnostics.add(
          PvSolverDiagnostic(
            code: PvDiagnosticCode.inverterDerated,
            severity: PvDiagnosticSeverity.warning,
            message:
                'Inverter output rating is reduced by explicit deratingFactor.',
            componentId: inverter.id,
          ),
        );
        if (!_inputVoltageInRange(inputVoltageV, parameters)) {
          diagnostics.add(
            PvSolverDiagnostic(
              code: PvDiagnosticCode.inputVoltageOutOfRange,
              severity: PvDiagnosticSeverity.warning,
              message:
                  'DC input voltage is outside inverter DC input limits.',
              componentId: inverter.id,
            ),
          );
          return const _InverterAvailability(
            canOperate: false,
            state: PvInverterState.inputOutOfRange,
            deratingFactor: 0.0,
          );
        }
        return _InverterAvailability(
          canOperate: true,
          state: PvInverterState.running,
          deratingFactor: factor,
        );
      case ComponentCondition.openCircuit:
      case ComponentCondition.shortCircuit:
      case ComponentCondition.disabled:
        diagnostics.add(
          PvSolverDiagnostic(
            code: PvDiagnosticCode.inverterFaulted,
            severity: PvDiagnosticSeverity.warning,
            message:
                'Inverter condition ${inverter.condition.name} disables AC output.',
            componentId: inverter.id,
          ),
        );
        return const _InverterAvailability(
          canOperate: false,
          state: PvInverterState.faulted,
          deratingFactor: 0.0,
        );
    }
    if (!_inputVoltageInRange(inputVoltageV, parameters)) {
      diagnostics.add(
        PvSolverDiagnostic(
          code: PvDiagnosticCode.inputVoltageOutOfRange,
          severity: PvDiagnosticSeverity.warning,
          message: 'DC input voltage is outside inverter DC input limits.',
          componentId: inverter.id,
        ),
      );
      return const _InverterAvailability(
        canOperate: false,
        state: PvInverterState.inputOutOfRange,
        deratingFactor: 0.0,
      );
    }
    return const _InverterAvailability(
      canOperate: true,
      state: PvInverterState.running,
      deratingFactor: 1.0,
    );
  }

  bool _inputVoltageInRange(
    double inputVoltageV,
    _InverterParameters parameters,
  ) =>
      inputVoltageV + options.numericTolerance >= parameters.minDcVoltageV &&
      inputVoltageV - options.numericTolerance <= parameters.maxDcVoltageV;

  double _nonNegativeSetting(
    CircuitState circuit,
    String key,
    double fallback,
    List<PvSolverDiagnostic> diagnostics,
  ) {
    final Object? raw = circuit.settings[key];
    if (raw == null) {
      return fallback;
    }
    if (raw is! num || !raw.toDouble().isFinite || raw.toDouble() < 0.0) {
      diagnostics.add(
        PvSolverDiagnostic(
          code: PvDiagnosticCode.invalidPvParameter,
          severity: PvDiagnosticSeverity.error,
          message: '$key must be a finite non-negative number.',
        ),
      );
      return 0.0;
    }
    return raw.toDouble();
  }

  double _boundedPercentageSetting(
    CircuitState circuit,
    String key,
    double fallback,
    List<PvSolverDiagnostic> diagnostics,
  ) {
    final Object? raw = circuit.settings[key];
    if (raw == null) return fallback;
    if (raw is! num) {
      diagnostics.add(
        PvSolverDiagnostic(
          code: PvDiagnosticCode.invalidPvParameter,
          severity: PvDiagnosticSeverity.error,
          message: '$key must be numeric.',
        ),
      );
      return fallback;
    }
    final double value = raw.toDouble();
    if (!value.isFinite || value < 0.0 || value > 100.0) {
      diagnostics.add(
        PvSolverDiagnostic(
          code: PvDiagnosticCode.invalidPvParameter,
          severity: PvDiagnosticSeverity.error,
          message: '$key must be finite and between 0 and 100.',
        ),
      );
      return fallback;
    }
    return value;
  }

  double _finiteSetting(
    CircuitState circuit,
    String key,
    double fallback,
    List<PvSolverDiagnostic> diagnostics,
  ) {
    final Object? raw = circuit.settings[key];
    if (raw == null) {
      return fallback;
    }
    if (raw is! num || !raw.toDouble().isFinite) {
      diagnostics.add(
        PvSolverDiagnostic(
          code: PvDiagnosticCode.invalidPvParameter,
          severity: PvDiagnosticSeverity.error,
          message: '$key must be finite.',
        ),
      );
      return fallback;
    }
    return raw.toDouble();
  }

  PvSolveResult _failure(
    CircuitState circuit,
    List<PvSolverDiagnostic> diagnostics,
  ) => PvSolveResult(
    circuitId: circuit.circuitId,
    circuitRevision: circuit.revision,
    engineVersion: engineVersion,
    status: PvSolveStatus.invalid,
    irradianceWm2: 0.0,
    cellTemperatureC: 0.0,
    pvOperatingVoltageV: 0.0,
    pvAvailableCurrentA: 0.0,
    pvAvailablePowerW: 0.0,
    pvDrawnCurrentA: 0.0,
    pvDrawnPowerW: 0.0,
    curtailedPowerW: 0.0,
    inverterState: PvInverterState.faulted,
    inverterEfficiency: 0.0,
    inverterOutputVoltageRmsV: 0.0,
    inverterOutputCurrentRmsA: 0.0,
    inverterOutputPowerW: 0.0,
    inverterConversionLossW: 0.0,
    loadResults: const <PvLoadResult>[],
    diagnostics: diagnostics,
  );
}

bool _hasErrors(List<PvSolverDiagnostic> diagnostics) => diagnostics.any(
  (PvSolverDiagnostic diagnostic) =>
      diagnostic.severity == PvDiagnosticSeverity.error,
);

double? _positiveNumber(Map<String, Object?> parameters, String key) {
  final Object? raw = parameters[key];
  if (raw is! num) {
    return null;
  }
  final double value = raw.toDouble();
  return value.isFinite && value > 0.0 ? value : null;
}

double? _finiteOptionalNumber(
  Map<String, Object?> parameters,
  String key,
  double fallback,
) {
  final Object? raw = parameters[key];
  if (raw == null) {
    return fallback;
  }
  if (raw is! num) {
    return null;
  }
  final double value = raw.toDouble();
  return value.isFinite ? value : null;
}

Terminal? _terminalForPhase(List<Terminal> terminals, PhaseTag phase) {
  final List<Terminal> matches = terminals
      .where((Terminal terminal) => terminal.phase == phase)
      .toList(growable: false);
  return matches.length == 1 ? matches.single : null;
}

final class _ControllerParameters {
  const _ControllerParameters({
    required this.outputVoltageV,
    required this.maxOutputCurrentA,
    required this.efficiency,
    required this.controllerType,
    required this.maxPvInputVoltageV,
  });

  final double outputVoltageV;
  final double maxOutputCurrentA;
  final double efficiency;
  final String controllerType;
  final double maxPvInputVoltageV;
}

final class _BatteryParameters {
  const _BatteryParameters({
    required this.nominalVoltageV,
    required this.capacityAh,
    required this.initialSoc,
    required this.minSoc,
    required this.maxSoc,
    required this.maxChargeCurrentA,
    required this.maxDischargeCurrentA,
    required this.chargeEfficiency,
    required this.dischargeEfficiency,
  });

  final double nominalVoltageV;
  final double capacityAh;
  final double initialSoc;
  final double minSoc;
  final double maxSoc;
  final double maxChargeCurrentA;
  final double maxDischargeCurrentA;
  final double chargeEfficiency;
  final double dischargeEfficiency;
}

final class _ControllerTerminalContract {
  const _ControllerTerminalContract({
    required this.pvPositive,
    required this.pvNegative,
    required this.busPositive,
    required this.busNegative,
  });

  final Terminal pvPositive;
  final Terminal pvNegative;
  final Terminal busPositive;
  final Terminal busNegative;
}

final class _BatteryTerminalContract {
  const _BatteryTerminalContract({
    required this.positive,
    required this.negative,
  });

  final Terminal positive;
  final Terminal negative;
}

final class _PvArrayParameters {
  const _PvArrayParameters({
    required this.mppVoltageV,
    required this.mppCurrentA,
    required this.powerTemperatureCoefficientPerC,
    required this.voltageTemperatureCoefficientPerC,
  });

  final double mppVoltageV;
  final double mppCurrentA;
  final double powerTemperatureCoefficientPerC;
  final double voltageTemperatureCoefficientPerC;
}

final class _InverterParameters {
  const _InverterParameters({
    required this.minDcVoltageV,
    required this.maxDcVoltageV,
    required this.nominalAcVoltageV,
    required this.ratedAcPowerW,
    required this.efficiency,
  });

  final double minDcVoltageV;
  final double maxDcVoltageV;
  final double nominalAcVoltageV;
  final double ratedAcPowerW;
  final double efficiency;
}

final class _LoadParameters {
  const _LoadParameters({
    required this.componentId,
    required this.resistanceOhm,
  });

  final ComponentId componentId;
  final double resistanceOhm;
}

final class _PvTerminalContract {
  const _PvTerminalContract({required this.positive, required this.negative});

  final Terminal positive;
  final Terminal negative;
}

final class _InverterTerminalContract {
  const _InverterTerminalContract({
    required this.dcPositive,
    required this.dcNegative,
    required this.acLine,
    required this.acNeutral,
  });

  final Terminal dcPositive;
  final Terminal dcNegative;
  final Terminal acLine;
  final Terminal acNeutral;
}

final class _LoadTerminalContract {
  const _LoadTerminalContract({required this.line, required this.neutral});

  final Terminal line;
  final Terminal neutral;
}

final class _InverterAvailability {
  const _InverterAvailability({
    required this.canOperate,
    required this.state,
    required this.deratingFactor,
  });

  final bool canOperate;
  final PvInverterState state;
  final double deratingFactor;
}


bool _hasFunctionalRole(
  ComponentInstance component,
  ComponentFunctionalRole role,
) =>
    CoreComponentPhysicsContracts.resolveComponent(component).functionalRole ==
    role;
