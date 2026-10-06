import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:electrosim_measurements/electrosim_measurements.dart';

import 'f9_element_editor.dart';
import 'runtime/electrosim_runtime_engine.dart';

final class F18G7PropertyRow {
  const F18G7PropertyRow({required this.label, required this.value});

  final String label;
  final String value;
}

final class F18G7PropertySnapshot {
  F18G7PropertySnapshot({
    required this.domainLabel,
    required this.solverLabel,
    required this.declaredStateLabel,
    required this.runtimeStateLabel,
    required Iterable<F18G7PropertyRow> parameters,
    required Iterable<F18G7PropertyRow> runtimeValues,
    required Iterable<String> evidenceIds,
  }) : parameters = List<F18G7PropertyRow>.unmodifiable(parameters),
       runtimeValues = List<F18G7PropertyRow>.unmodifiable(runtimeValues),
       evidenceIds = List<String>.unmodifiable(evidenceIds);

  final String domainLabel;
  final String solverLabel;
  final String declaredStateLabel;
  final String? runtimeStateLabel;
  final List<F18G7PropertyRow> parameters;
  final List<F18G7PropertyRow> runtimeValues;
  final List<String> evidenceIds;
}

/// Presentation-only adapter for the properties panel.
///
/// Every runtime number comes from [ElectroSimRuntimeSnapshot] / solver evidence.
/// The presenter does not calculate substitute electrical values when evidence is
/// absent; unavailable values are simply omitted.
abstract final class F18G7PropertyPresenter {
  static F18G7PropertySnapshot describe({
    required F9ElementDetails details,
    required ElectroSimRuntimeSnapshot runtimeSnapshot,
  }) {
    final List<F18G7PropertyRow> runtimeValues = <F18G7PropertyRow>[];
    final List<String> evidenceIds = <String>[];
    String? runtimeStateLabel;

    if (details.kind == F9ElementKind.component) {
      final ComponentOperatingState? state = runtimeSnapshot
          .componentOperatingState(ComponentId(details.id));
      if (state != null) {
        runtimeStateLabel = _operatingStateLabel(state.code);
        _addRuntimeQuantity(
          runtimeValues,
          'Tension',
          state.voltageV,
          'V',
        );
        _addRuntimeQuantity(
          runtimeValues,
          'Courant',
          state.currentA,
          'A',
        );
        _addRuntimeQuantity(
          runtimeValues,
          'Puissance',
          state.powerW,
          'W',
        );
        evidenceIds.addAll(state.evidenceIds);
        for (final OperatingWarning warning in state.warnings) {
          runtimeValues.add(
            F18G7PropertyRow(
              label: 'Alerte',
              value: _warningLabel(warning.code),
            ),
          );
        }
      }
    } else if (details.kind == F9ElementKind.source) {
      final SourceInstance? source = _sourceById(
        runtimeSnapshot.circuit,
        details.id,
      );
      if (source != null &&
          runtimeSnapshot.solverKind == ElectroSimRuntimeSolverKind.pv &&
          source.modelType == 'pv_array' &&
          runtimeSnapshot.pvResult?.isSolved == true) {
        final pv = runtimeSnapshot.pv;
        _addRuntimeQuantity(
          runtimeValues,
          'Tension PV',
          pv.pvOperatingVoltageV,
          'V',
        );
        _addRuntimeQuantity(
          runtimeValues,
          'Courant PV',
          pv.pvDrawnCurrentA,
          'A',
        );
        _addRuntimeQuantity(
          runtimeValues,
          'Puissance PV',
          pv.pvDrawnPowerW,
          'W',
        );
        evidenceIds.add('pv:array-operating-point');
      } else if (source != null && source.terminals.length == 2) {
        final MeasurementResult voltage = switch (runtimeSnapshot.solverKind) {
          ElectroSimRuntimeSolverKind.dc => runtimeSnapshot.measureVoltage(
            positiveProbe: source.terminals[0].id,
            negativeProbe: source.terminals[1].id,
          ),
          ElectroSimRuntimeSolverKind.ac1 ||
          ElectroSimRuntimeSolverKind.ac3 => runtimeSnapshot.measureAcVoltage(
            positiveProbe: source.terminals[0].id,
            negativeProbe: source.terminals[1].id,
          ),
          ElectroSimRuntimeSolverKind.pv => MeasurementResult.invalid(
            kind: MeasurementKind.voltageDc,
            errorCode: MeasurementErrorCode.wrongElectricalMode,
            message: 'No generic source probe exists for the PV solver.',
          ),
        };
        _addMeasurement(runtimeValues, 'Tension mesurée', voltage);
        evidenceIds.addAll(voltage.evidenceIds);
      }
    }

    return F18G7PropertySnapshot(
      domainLabel: _domainLabel(runtimeSnapshot.circuit.mode),
      solverLabel: runtimeSnapshot.solved ? 'Résolu' : 'Non résolu',
      declaredStateLabel: details.stateLabel,
      runtimeStateLabel: runtimeStateLabel,
      parameters: details.parameters.entries
          .map(
            (MapEntry<String, Object?> entry) => F18G7PropertyRow(
              label: _parameterLabel(entry.key),
              value: _parameterValue(entry.key, entry.value),
            ),
          )
          .toList(growable: false),
      runtimeValues: runtimeValues,
      evidenceIds: evidenceIds.toSet(),
    );
  }

  static void _addRuntimeQuantity(
    List<F18G7PropertyRow> rows,
    String label,
    double? value,
    String unit,
  ) {
    if (value == null || !value.isFinite) return;
    final double normalized = value.abs() < 1e-12 ? 0.0 : value;
    rows.add(
      F18G7PropertyRow(
        label: label,
        value: '${normalized.toStringAsFixed(3)} $unit',
      ),
    );
  }

  static void _addMeasurement(
    List<F18G7PropertyRow> rows,
    String label,
    MeasurementResult result,
  ) {
    final ElectricalQuantity? reading = result.reading;
    if (!result.isValid || reading == null) return;
    rows.add(
      F18G7PropertyRow(
        label: label,
        value: '${reading.value.toStringAsFixed(3)} ${reading.unit.symbol}',
      ),
    );
  }

  static SourceInstance? _sourceById(CircuitState circuit, String id) {
    for (final SourceInstance source in circuit.sources) {
      if (source.id.value == id) return source;
    }
    return null;
  }

  static String _domainLabel(ElectricalMode mode) => switch (mode) {
    ElectricalMode.dc => 'CC',
    ElectricalMode.ac1 => 'AC monophasé',
    ElectricalMode.ac3 => 'AC triphasé',
    ElectricalMode.pv => 'Photovoltaïque',
  };

  static String _operatingStateLabel(ComponentOperatingCode code) =>
      switch (code) {
        ComponentOperatingCode.deenergized => 'Inactif électriquement',
        ComponentOperatingCode.energized => 'Alimenté',
        ComponentOperatingCode.open => 'Ouvert',
        ComponentOperatingCode.closed => 'Fermé',
        ComponentOperatingCode.disabled => 'Désactivé',
        ComponentOperatingCode.faulted => 'En défaut',
        ComponentOperatingCode.overloaded => 'Surcharge',
        ComponentOperatingCode.undetermined => 'Indéterminé',
      };

  static String _warningLabel(OperatingWarningCode code) => switch (code) {
    OperatingWarningCode.simulationNotSolved => 'Simulation non résolue',
    OperatingWarningCode.missingBranchResult => 'Résultat de branche absent',
    OperatingWarningCode.currentIndeterminate => 'Courant indéterminé',
    OperatingWarningCode.invalidNominalLimit => 'Limite nominale invalide',
    OperatingWarningCode.overVoltage => 'Surtension',
    OperatingWarningCode.overCurrent => 'Surintensité',
    OperatingWarningCode.overPower => 'Surpuissance',
  };

  static const Map<String, String> _labels = <String, String>{
    'voltageV': 'Tension',
    'voltageRmsV': 'Tension efficace',
    'phaseVoltageRmsV': 'Tension phase-neutre',
    'currentA': 'Courant',
    'currentRmsA': 'Courant efficace',
    'resistanceOhm': 'Résistance',
    'coilResistanceOhm': 'Résistance bobine',
    'impedanceOhm': 'Impédance',
    ProtectionRating.ratedCurrentKey: 'Calibre',
    ReceiverNominalRating.voltageKey: 'Tension nominale',
    ReceiverNominalRating.currentKey: 'Courant nominal',
    ReceiverNominalRating.powerKey: 'Puissance nominale',
    'nominalCurrentA': 'Courant nominal',
    'maxVoltageV': 'Tension maximale',
    'maxCurrentA': 'Courant maximal',
    'maxPowerW': 'Puissance maximale',
    'powerW': 'Puissance',
    'frequencyHz': 'Fréquence',
    'phaseDeg': 'Phase',
    'capacitanceF': 'Capacité',
    'inductanceH': 'Inductance',
    'forwardVoltageV': 'Tension directe',
    'reverseBreakdownVoltageV': 'Tension de claquage',
    'coilPickupVoltageV': 'Tension d’enclenchement',
    'coilDropoutVoltageV': 'Tension de retombée',
    'irradianceWm2': 'Irradiance',
    'cellTemperatureC': 'Température cellule',
    'shadingPct': 'Ombrage',
    'batteryCapacityWh': 'Capacité batterie',
    'efficiency': 'Rendement',
  };

  static String _parameterLabel(String key) {
    final String? known = _labels[key];
    if (known != null) return known;
    final String spaced = key.replaceAllMapped(
      RegExp(r'([a-z0-9])([A-Z])'),
      (Match match) => '${match.group(1)} ${match.group(2)}',
    );
    return spaced.isEmpty
        ? key
        : '${spaced[0].toUpperCase()}${spaced.substring(1)}';
  }

  static String _parameterValue(String key, Object? value) {
    if (value is bool) return value ? 'Oui' : 'Non';
    if (value is! num) return '$value';
    final double number = value.toDouble();
    final String unit = switch (key) {
      'voltageV' ||
      'voltageRmsV' ||
      'phaseVoltageRmsV' ||
      ReceiverNominalRating.voltageKey ||
      'maxVoltageV' ||
      'forwardVoltageV' ||
      'reverseBreakdownVoltageV' ||
      'coilPickupVoltageV' ||
      'coilDropoutVoltageV' => ' V',
      'currentA' ||
      'currentRmsA' ||
      ProtectionRating.ratedCurrentKey ||
      ReceiverNominalRating.currentKey ||
      'nominalCurrentA' ||
      'maxCurrentA' => ' A',
      'resistanceOhm' || 'coilResistanceOhm' || 'impedanceOhm' => ' Ω',
      ReceiverNominalRating.powerKey || 'maxPowerW' || 'powerW' => ' W',
      'frequencyHz' => ' Hz',
      'phaseDeg' => ' °',
      'capacitanceF' => ' F',
      'inductanceH' => ' H',
      'irradianceWm2' => ' W/m²',
      'cellTemperatureC' => ' °C',
      'shadingPct' => ' %',
      'batteryCapacityWh' => ' Wh',
      'efficiency' => ' %',
      _ => '',
    };
    final double displayed = key == 'efficiency' && number.abs() <= 1.0
        ? number * 100.0
        : number;
    final String text = displayed == displayed.roundToDouble()
        ? displayed.toStringAsFixed(0)
        : displayed
              .toStringAsFixed(3)
              .replaceFirst(RegExp(r'0+$'), '')
              .replaceFirst(RegExp(r'\.$'), '');
    return '$text$unit';
  }
}
