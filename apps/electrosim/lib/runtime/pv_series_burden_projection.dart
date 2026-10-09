import 'dart:math' as math;

import 'package:electrosim_domain/electrosim_domain.dart';

import 'electrosim_runtime_engine.dart';

/// Solves the instrument burden on one PV branch with explicit branch
/// equations, using power, voltage and current constraints produced by the
/// authoritative PV solver. This intentionally does not fabricate a nodal
/// reading for arbitrary conductors in the aggregate PV model.
///
/// The original circuit and its conductor are never mutated. Only one
/// topologically unambiguous series placement can be measured.
final class PvSeriesBurdenResult {
  const PvSeriesBurdenResult({
    this.currentA,
    this.voltageDropV = 0,
    this.lossW = 0,
    this.evidence = '',
    this.issue,
  });
  final double? currentA;
  final double voltageDropV;
  final double lossW;
  final String evidence;
  final String? issue;
  bool get valid => currentA != null && issue == null;
}

abstract final class PvSeriesBurdenProjection {
  static PvSeriesBurdenResult solve({
    required ElectroSimRuntimeSnapshot snapshot,
    required Connection wire,
    required InstrumentInstance meter,
    ElectroSimRuntimeEngine engine = const ElectroSimRuntimeEngine(),
  }) {
    final pv = snapshot.pvResult;
    if (pv == null || !pv.isSolved) {
      return const PvSeriesBurdenResult(
        issue: 'PV circuit is not solved; series current is unavailable.',
      );
    }

    final circuit = snapshot.circuit;
    // The original wire is cut by this measurement. A second parallel path
    // bypassing either device port makes this 1-D branch model inapplicable.
    bool singleWire(TerminalId terminal) => circuit.connections.where(
      (c) => c.enabled &&
          (c.fromTerminalId == terminal || c.toTerminalId == terminal),
    ).length == 1;

    final burdenOhm = meter.burdenResistanceOhm;
    if (!burdenOhm.isFinite || burdenOhm <= 0) {
      return const PvSeriesBurdenResult(issue: 'Invalid ammeter burden.');
    }

    // The PV array is a controlled voltage/power source in SolverPV. Its DC
    // feeder is a constant-power transfer. The series meter obeys:
    // P_load = I*(V_source - I*R_burden), P_loss = I^2*R_burden.
    if (meter.mode == InstrumentMode.currentDc) {
      for (final source in circuit.sources.where(
          (s) => s.enabled && s.modelType == 'pv_array')) {
        for (final terminal in source.terminals.where(
            (t) => t.phase == PhaseTag.dcPositive ||
                t.phase == PhaseTag.dcNegative)) {
          if (!_touches(wire, terminal.id) || !singleWire(terminal.id)) {
            continue;
          }
          return _constantPowerBranch(
            sourceVoltageV: pv.pvOperatingVoltageV,
            loadPowerW: pv.pvDrawnPowerW,
            burdenOhm: burdenOhm,
            maximumAvailableCurrentA: pv.pvAvailableCurrentA,
            evidence: 'pv-source:${source.id.value}',
          );
        }
      }
      if (pv.batteryPresent) {
        for (final battery in circuit.components.where(
            (c) => c.modelType == 'pv_battery')) {
          for (final terminal in battery.terminals.where(
              (t) => t.phase == PhaseTag.dcPositive ||
                  t.phase == PhaseTag.dcNegative)) {
            if (!_touches(wire, terminal.id) || !singleWire(terminal.id)) {
              continue;
            }
            final power = pv.batteryPowerW.abs();
            final Object? maxI = battery.parameters[
                pv.batteryPowerW >= 0
                    ? 'maxDischargeCurrentA' : 'maxChargeCurrentA'];
            return _constantPowerBranch(
              sourceVoltageV: pv.batteryVoltageV,
              loadPowerW: power,
              burdenOhm: burdenOhm,
              maximumAvailableCurrentA: maxI is num
                  ? maxI.toDouble() : double.infinity,
              evidence: 'pv-battery:${battery.id.value}',
            );
          }
        }
      }
      // Inverter DC feed current is not necessarily equal to the total PV
      // array current in storage architectures; use inverter power evidence.
      for (final inverter in circuit.components.where(
          (c) => c.modelType == 'pv_inverter')) {
        for (final terminal in inverter.terminals.where(
            (t) => t.phase == PhaseTag.dcPositive ||
                t.phase == PhaseTag.dcNegative)) {
          if (!_touches(wire, terminal.id) || !singleWire(terminal.id)) {
            continue;
          }
          final busVoltage = pv.batteryPresent
              ? pv.batteryVoltageV : pv.pvOperatingVoltageV;
          final dcPower = pv.inverterEfficiency > 0
              ? pv.inverterOutputPowerW / pv.inverterEfficiency
              : 0.0;
          return _constantPowerBranch(
            sourceVoltageV: busVoltage,
            loadPowerW: dcPower,
            burdenOhm: burdenOhm,
            maximumAvailableCurrentA: double.infinity,
            evidence: 'pv-inverter-dc:${inverter.id.value}',
          );
        }
      }
    }

    // On the inverter's AC load side, SolverPV models resistive loads.
    // Solve the *actual* series connection R_load + R_burden, rather than
    // returning the unloaded aggregate inverter current.
    if (meter.mode == InstrumentMode.currentAcRms) {
      for (final inverter in circuit.components.where(
          (c) => c.modelType == 'pv_inverter')) {
        for (final terminal in inverter.terminals.where(
            (t) => t.phase == PhaseTag.l1 ||
                t.phase == PhaseTag.neutral)) {
          if (!_touches(wire, terminal.id) || !singleWire(terminal.id)) {
            continue;
          }
          final receiverTerminal = wire.fromTerminalId == terminal.id
              ? wire.toTerminalId : wire.fromTerminalId;
          final receivers = circuit.components.where((c) =>
              c.terminals.any((t) => t.id == receiverTerminal) &&
              pv.loadResults.any((load) => load.componentId == c.id)).toList();
          if (receivers.length != 1) {
            return const PvSeriesBurdenResult(
              issue: 'PV AC series meter must feed one physically '
                  'identified resistive receiver.',
            );
          }
          final receiver = receivers.single;
          final load = pv.load(receiver.id);
          if (!(load.resistanceOhm.isFinite && load.resistanceOhm > 0)) {
            return const PvSeriesBurdenResult(
              issue: 'PV AC receiver impedance is unavailable.',
            );
          }
          final withBurden = ComponentInstance(
            id: receiver.id,
            modelType: receiver.modelType,
            terminals: receiver.terminals,
            condition: receiver.condition,
            controlState: receiver.controlState,
            parameters: {
              ...receiver.parameters,
              'resistanceOhm': load.resistanceOhm + burdenOhm,
            },
          );
          // Re-evaluate the actual PV solver, including any inverter power
          // limitation, with the meter burden added to the load resistance.
          // The authored circuit is untouched, and inverter output power,
          // voltage and current are recomputed instead of guessed.
          final loaded = CircuitState(
            circuitId: circuit.circuitId,
            revision: circuit.revision,
            mode: circuit.mode,
            sources: circuit.sources,
            components: [
              for (final c in circuit.components)
                if (c.id == receiver.id) withBurden else c,
            ],
            connections: circuit.connections,
            instruments: circuit.instruments,
            probes: circuit.probes,
            settings: circuit.settings,
            metadata: circuit.metadata,
          );
          final solved = engine.evaluate(loaded);
          if (solved.pvResult == null || !solved.pvResult!.isSolved) {
            return const PvSeriesBurdenResult(
              issue: 'PV inverter output with ammeter burden is unsolved.',
            );
          }
          final updated = solved.pvResult!.load(receiver.id);
          return _result(updated.currentRmsA.abs(), burdenOhm,
              'pv-inverter-ac:${inverter.id.value}:load:${receiver.id.value}');
        }
      }
    }
    return const PvSeriesBurdenResult(
      issue: 'Series PV measurement is not mapped to a unique array, '
          'battery, inverter input, or inverter output conductor.',
    );
  }

  static bool _touches(Connection wire, TerminalId terminal) =>
      wire.fromTerminalId == terminal || wire.toTerminalId == terminal;

  static PvSeriesBurdenResult _constantPowerBranch({
    required double sourceVoltageV,
    required double loadPowerW,
    required double burdenOhm,
    required double maximumAvailableCurrentA,
    required String evidence,
  }) {
    if (!sourceVoltageV.isFinite || !loadPowerW.isFinite ||
        sourceVoltageV <= 0 || loadPowerW < 0) {
      return const PvSeriesBurdenResult(
        issue: 'PV bus voltage or power is not valid.',
      );
    }
    if (loadPowerW == 0) return _result(0, burdenOhm, evidence);
    // Stable low-current solution of R I^2 - V I + P = 0, expressed
    // without catastrophic cancellation near zero meter burden.
    final discriminant = sourceVoltageV * sourceVoltageV -
        4 * burdenOhm * loadPowerW;
    if (!discriminant.isFinite || discriminant < 0) {
      return const PvSeriesBurdenResult(
        issue: 'Meter burden exceeds the available PV bus power margin.',
      );
    }
    final i = 2 * loadPowerW /
        (sourceVoltageV + math.sqrt(discriminant));
    if (!i.isFinite || i < 0) {
      return const PvSeriesBurdenResult(
        issue: 'No finite PV series current solution.',
      );
    }
    // If the solver's current limit is reached, the delivered load power
    // must fall rather than allowing a nonphysical excess source current.
    final limited = math.min(i, maximumAvailableCurrentA);
    return _result(limited, burdenOhm, evidence);
  }

  static PvSeriesBurdenResult _result(
      double currentA, double burdenOhm, String evidence) {
    if (!currentA.isFinite || currentA < 0) {
      return const PvSeriesBurdenResult(
        issue: 'Nonfinite series ammeter current.',
      );
    }
    return PvSeriesBurdenResult(
      currentA: currentA,
      voltageDropV: currentA * burdenOhm,
      lossW: currentA * currentA * burdenOhm,
      evidence: evidence,
    );
  }
}
