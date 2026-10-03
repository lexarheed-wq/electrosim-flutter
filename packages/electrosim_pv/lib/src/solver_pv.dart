import 'dart:math' as math;

import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:electrosim_topology/electrosim_topology.dart';

import 'pv_diagnostic.dart';
import 'pv_result.dart';
import 'pv_solver_options.dart';

final class SolverPV {
  const SolverPV({this.options = const PvSolverOptions()});

  static const String engineVersion = 'solver-pv/0.1.0';

  final PvSolverOptions options;

  PvSolveResult solve(CircuitState circuit, TopologyGraph topology) {
    final List<PvSolverDiagnostic> diagnostics = <PvSolverDiagnostic>[];
    if (circuit.mode != ElectricalMode.pv || topology.mode != ElectricalMode.pv) {
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
          message: 'TopologyGraph does not match the CircuitState identity/revision.',
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
        .where((ComponentInstance component) => component.modelType == 'pv_inverter')
        .toList(growable: false);
    if (inverters.isEmpty) {
      diagnostics.add(
        const PvSolverDiagnostic(
          code: PvDiagnosticCode.missingInverter,
          severity: PvDiagnosticSeverity.error,
          message: 'PV circuit must contain one pv_inverter component.',
        ),
      );
      return _failure(circuit, diagnostics);
    }
    if (inverters.length != 1) {
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
    final ComponentInstance inverter = inverters.single;
    final _PvArrayParameters? arrayParameters = _arrayParameters(array, diagnostics);
    final _InverterParameters? inverterParameters = _inverterParameters(
      inverter,
      diagnostics,
    );
    if (arrayParameters == null || inverterParameters == null) {
      return _failure(circuit, diagnostics);
    }

    final _PvTerminalContract? arrayTerminals = _pvArrayTerminals(array, diagnostics);
    final _InverterTerminalContract? inverterTerminals = _inverterTerminals(
      inverter,
      diagnostics,
    );
    if (arrayTerminals == null || inverterTerminals == null) {
      return _failure(circuit, diagnostics);
    }

    final String arrayPositiveNode = topology
        .nodeForTerminal(arrayTerminals.positive.id)
        .id;
    final String arrayNegativeNode = topology
        .nodeForTerminal(arrayTerminals.negative.id)
        .id;
    final String inverterPositiveNode = topology
        .nodeForTerminal(inverterTerminals.dcPositive.id)
        .id;
    final String inverterNegativeNode = topology
        .nodeForTerminal(inverterTerminals.dcNegative.id)
        .id;
    if (arrayPositiveNode != inverterPositiveNode ||
        arrayNegativeNode != inverterNegativeNode) {
      diagnostics.add(
        PvSolverDiagnostic(
          code: PvDiagnosticCode.dcInputDisconnected,
          severity: PvDiagnosticSeverity.error,
          message: 'pv_array DC terminals are not connected to the matching inverter DC input.',
          componentId: inverter.id,
          sourceId: array.id,
        ),
      );
      return _failure(circuit, diagnostics);
    }

    final List<ComponentInstance> loads = circuit.components
        .where((ComponentInstance component) => component.modelType == 'pv_resistive_load')
        .toList(growable: false)
      ..sort(
        (ComponentInstance a, ComponentInstance b) =>
            a.id.value.compareTo(b.id.value),
      );
    final List<_LoadParameters> loadParameters = <_LoadParameters>[];
    final String inverterLineNode = topology
        .nodeForTerminal(inverterTerminals.acLine.id)
        .id;
    final String inverterNeutralNode = topology
        .nodeForTerminal(inverterTerminals.acNeutral.id)
        .id;
    for (final ComponentInstance load in loads) {
      final _LoadParameters? parameters = _loadParameters(load, diagnostics);
      final _LoadTerminalContract? terminals = _loadTerminals(load, diagnostics);
      if (parameters == null || terminals == null) {
        continue;
      }
      final String lineNode = topology.nodeForTerminal(terminals.line.id).id;
      final String neutralNode = topology.nodeForTerminal(terminals.neutral.id).id;
      if (lineNode != inverterLineNode || neutralNode != inverterNeutralNode) {
        diagnostics.add(
          PvSolverDiagnostic(
            code: PvDiagnosticCode.acOutputDisconnected,
            severity: PvDiagnosticSeverity.error,
            message: 'PV load ${load.id.value} is not connected to the inverter AC output bus.',
            componentId: load.id,
          ),
        );
        continue;
      }
      loadParameters.add(parameters);
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
    final double irradianceWm2 =
        rawIrradianceWm2 * (1.0 - shadingPct / 100.0);
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
      1.0 + arrayParameters.voltageTemperatureCoefficientPerC * temperatureDelta,
    );
    final double powerTemperatureFactor = math.max(
      0.0,
      1.0 + arrayParameters.powerTemperatureCoefficientPerC * temperatureDelta,
    );
    final double operatingVoltageV = arrayParameters.mppVoltageV * voltageFactor;
    final double availablePowerW =
        arrayParameters.mppVoltageV *
        arrayParameters.mppCurrentA *
        irradianceFactor *
        powerTemperatureFactor;
    final double availableCurrentA = operatingVoltageV <= options.numericTolerance
        ? 0.0
        : availablePowerW / operatingVoltageV;

    final _InverterAvailability availability = _inverterAvailability(
      inverter,
      inverterParameters,
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
      } else if (nominalLoadPowerW <= availableAcPowerW + options.numericTolerance) {
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
            message: 'Inverter output is power-limited by PV availability or inverter rating.',
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
    final double curtailedPowerW = math.max(0.0, availablePowerW - dcDrawnPowerW);

    final List<PvLoadResult> loadResults = <PvLoadResult>[
      for (final _LoadParameters load in loadParameters)
        PvLoadResult(
          componentId: load.componentId,
          resistanceOhm: load.resistanceOhm,
          voltageRmsV: outputVoltageV,
          currentRmsA: outputVoltageV / load.resistanceOhm,
          activePowerW:
              outputVoltageV * outputVoltageV / load.resistanceOhm,
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
          message: 'pv_array requires positive mppVoltageV/mppCurrentA and finite temperature coefficients.',
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
    final double? efficiency = _positiveNumber(inverter.parameters, 'efficiency');
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
          message: 'pv_inverter requires valid DC limits, nominal AC voltage, rating and efficiency in (0,1].',
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
    final double? resistance = _positiveNumber(load.parameters, 'resistanceOhm');
    if (resistance == null) {
      diagnostics.add(
        PvSolverDiagnostic(
          code: PvDiagnosticCode.invalidLoadParameter,
          severity: PvDiagnosticSeverity.error,
          message: 'pv_resistive_load requires positive resistanceOhm.',
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
    final Terminal? positive = _terminalForPhase(source.terminals, PhaseTag.dcPositive);
    final Terminal? negative = _terminalForPhase(source.terminals, PhaseTag.dcNegative);
    if (positive == null || negative == null) {
      diagnostics.add(
        PvSolverDiagnostic(
          code: PvDiagnosticCode.invalidTerminalContract,
          severity: PvDiagnosticSeverity.error,
          message: 'pv_array requires explicit dcPositive and dcNegative terminals.',
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
    if (positive == null || negative == null || line == null || neutral == null) {
      diagnostics.add(
        PvSolverDiagnostic(
          code: PvDiagnosticCode.invalidTerminalContract,
          severity: PvDiagnosticSeverity.error,
          message: 'pv_inverter requires dcPositive, dcNegative, l1 and neutral terminals.',
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
    List<PvSolverDiagnostic> diagnostics,
  ) {
    final Terminal? line = _terminalForPhase(load.terminals, PhaseTag.l1);
    final Terminal? neutral = _terminalForPhase(load.terminals, PhaseTag.neutral);
    if (line == null || neutral == null) {
      diagnostics.add(
        PvSolverDiagnostic(
          code: PvDiagnosticCode.invalidTerminalContract,
          severity: PvDiagnosticSeverity.error,
          message: 'pv_resistive_load requires explicit l1 and neutral terminals.',
          componentId: load.id,
        ),
      );
      return null;
    }
    return _LoadTerminalContract(line: line, neutral: neutral);
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
            message: 'Inverter output rating is reduced by explicit deratingFactor.',
            componentId: inverter.id,
          ),
        );
        if (!_inputVoltageInRange(inputVoltageV, parameters)) {
          diagnostics.add(
            PvSolverDiagnostic(
              code: PvDiagnosticCode.inputVoltageOutOfRange,
              severity: PvDiagnosticSeverity.warning,
              message: 'PV operating voltage is outside inverter DC input limits.',
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
            message: 'Inverter condition ${inverter.condition.name} disables AC output.',
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
          message: 'PV operating voltage is outside inverter DC input limits.',
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
  ) =>
      PvSolveResult(
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
