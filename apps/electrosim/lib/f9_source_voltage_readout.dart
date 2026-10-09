import 'dart:math' as math;

import 'package:electrosim_domain/electrosim_domain.dart';

import 'runtime/electrosim_runtime_engine.dart';

/// Resolves the voltage shown on a physical source artwork.
///
/// The AC1 ideal voltage source is specified by its RMS voltage independently
/// of load current. An open downstream protective device must never cause
/// a spurious 0 V readout. Other source families still use solver evidence.
abstract final class F9SourceVoltageReadout {
  static double voltageV(
    ElectroSimRuntimeSnapshot? runtime,
    SourceInstance source, {
    required bool simulationRunning,
  }) {
    if (runtime == null || !source.enabled) return 0;
    final String target = 'source:${source.id.value}';

    final dc = runtime.dcResult;
    if (dc != null && dc.isSolved) {
      for (final branch in dc.branchResults) {
        if (branch.id == target && branch.voltageV.isFinite) {
          return branch.voltageV.abs();
        }
      }
    }

    final ac1 = runtime.ac1Result;
    if (ac1 != null && ac1.isSolved) {
      double value = 0;
      for (final branch in ac1.branchResults) {
        if (branch.id != target && !branch.id.startsWith('$target:')) continue;
        if (branch.voltage.magnitude.isFinite) {
          value = math.max(value, branch.voltage.magnitude);
        }
      }
      if (value > 0) return value;
    }

    // AC1 ideal voltage sources retain their declared RMS voltage even when
    // the downstream branch is open or the solver has no source-branch
    // measurement. This fallback is *not* applied to current sources, PV,
    // disabled sources, paused simulation or other physical source models.
    if (simulationRunning &&
        runtime.solverKind == ElectroSimRuntimeSolverKind.ac1 &&
        source.modelType == 'ac_voltage_source') {
      final Object? configured = source.parameters['voltageRmsV'];
      if (configured is num &&
          configured.isFinite &&
          configured >= 0) {
        return configured.toDouble();
      }
    }

    final ac3 = runtime.ac3Result;
    if (ac3 != null && ac3.isSolved) {
      double value = 0;
      for (final branch in ac3.branchResults) {
        if (branch.id != target && !branch.id.startsWith('$target:')) continue;
        if (branch.voltage.magnitude.isFinite) {
          value = math.max(value, branch.voltage.magnitude);
        }
      }
      if (value > 0) return value;
    }
    final pv = runtime.pvResult;
    if (pv != null && pv.isSolved && source.modelType == 'pv_array') {
      return pv.pvOperatingVoltageV;
    }
    return 0;
  }
}
