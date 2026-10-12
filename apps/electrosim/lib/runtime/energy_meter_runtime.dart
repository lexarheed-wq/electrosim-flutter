import 'dart:math' as math;
import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:electrosim_pv/electrosim_pv.dart';
import 'package:electrosim_solver_ac/electrosim_solver_ac.dart';
import 'electrosim_runtime_engine.dart';

/// Direction is relative to the authored input -> output meter terminals.
/// E+ and E- are separate monotonic registers, not a net value or VA-hours.
final class MeterEnergyReading {
  const MeterEnergyReading({
    this.powerW = 0,
    this.importWh = 0,
    this.exportWh = 0,
    this.available = false,
  });
  final double powerW, importWh, exportWh;
  final bool available;
  double get importKwh => importWh / 1000;
  double get exportKwh => exportWh / 1000;
}

abstract final class EnergyMeterRuntime {
  static bool matches(ComponentInstance c) =>
      c.modelType == 'energy_meter_ac1' || c.modelType == 'energy_meter_ac3';
  static String feedId(ComponentInstance c, int pole) =>
      'energy-meter-feed:${c.id.value}:$pole';

  /// The reduced PV solver consumes connected buses rather than AC MNA
  /// feed-through branches. Project only these ideal poles as explicit runtime
  /// wires; authored components, port IDs and connections are untouched.
  static CircuitState projectPvPoles(CircuitState circuit) {
    if (circuit.mode != ElectricalMode.pv) return circuit;
    final meters = circuit.components.where(matches).toList();
    if (meters.isEmpty) return circuit;
    final wires = [...circuit.connections];
    final ids = wires.map((w) => w.id.value).toSet();
    for (final c in meters) {
      if (c.modelType != 'energy_meter_ac1' || c.terminals.length != 4) {
        throw ArgumentError('PV AC-output meter requires four terminals.');
      }
      if (c.condition == ComponentCondition.disabled ||
          c.condition == ComponentCondition.openCircuit) {
        continue;
      }
      for (var i = 0; i < 2; i++) {
        final id = feedId(c, i);
        if (!ids.add(id)) {
          throw ArgumentError('Reserved energy-meter wire ID: $id');
        }
        wires.add(
          Connection(
            id: ConnectionId(id),
            fromTerminalId: c.terminals[i].id,
            toTerminalId: c.terminals[i + 2].id,
            phase: c.terminals[i].phase,
          ),
        );
      }
    }
    // Keep authored meter owners and contracts; PV conduction uses these wires.
    final j = circuit.toJson();
    j['connections'] = wires.map((w) => w.toJson()).toList();
    return CircuitState.fromJson(j);
  }

  static Map<ComponentId, MeterEnergyReading> advance(
    ElectroSimRuntimeSnapshot s,
    Map<ComponentId, MeterEnergyReading> previous,
    Duration elapsed,
  ) {
    if (elapsed.isNegative) {
      throw ArgumentError('Negative meter integration time');
    }
    final hours = elapsed.inMicroseconds / 3600000000.0;
    final result = <ComponentId, MeterEnergyReading>{};
    for (final c in s.circuit.components.where(matches)) {
      double seed(String key) {
        final v = c.parameters[key];
        if (v == null) return 0;
        if (v is! num || !v.isFinite || v < 0) {
          throw ArgumentError('Invalid meter register $key');
        }
        return v.toDouble();
      }

      final base =
          previous[c.id] ??
          MeterEnergyReading(
            importWh: seed('meterImportWh'),
            exportWh: seed('meterExportWh'),
          );
      final power = _power(s, c);
      result[c.id] = MeterEnergyReading(
        powerW: power ?? 0,
        available: power != null,
        importWh:
            base.importWh + (power == null ? 0 : math.max(0, power) * hours),
        exportWh:
            base.exportWh + (power == null ? 0 : math.max(0, -power) * hours),
      );
    }
    return Map.unmodifiable(result);
  }

  static double? _power(ElectroSimRuntimeSnapshot s, ComponentInstance c) {
    if (!s.solved ||
        c.condition == ComponentCondition.disabled ||
        c.condition == ComponentCondition.openCircuit) {
      return null;
    }
    if (s.pvResult != null) {
      final wires = s.effectiveCircuit.connections.where(
        (w) => w.id.value == feedId(c, 0),
      );
      if (wires.length != 1) return null;
      final reading = PvNodalWireSolver.solve(
        circuit: s.effectiveCircuit,
        pv: s.pv,
        cutWire: wires.single,
        burdenOhm: 1e-5,
      );
      final p = reading?.signedCurrentA == null
          ? null
          : reading!.signedCurrentA! * s.pv.inverterOutputVoltageRmsV;
      return p != null && p.isFinite ? p : null;
    }
    final poles = c.modelType == 'energy_meter_ac3' ? 4 : 2;
    if (c.terminals.length != poles * 2) return null;
    final neutral = s.topology.terminalToNode[c.terminals[poles - 1].id];
    final nodes = s.ac1Result?.nodeVoltages ?? s.ac3Result?.nodeVoltages;
    if (nodes == null || neutral == null || !nodes.containsKey(neutral)) {
      return null;
    }
    var power = 0.0;
    for (var i = 0; i < poles - 1; i++) {
      final id = 'component:${c.id.value}:pole:$i';
      AcComplex? current;
      if (s.ac1Result != null) {
        final b = s.ac1.branchResults.where((b) => b.id == id);
        if (b.length != 1) return null;
        current = b.single.current;
      } else {
        final b = s.ac3.branchResults.where((b) => b.id == id);
        if (b.length != 1) return null;
        current = b.single.current;
      }
      final node = s.topology.terminalToNode[c.terminals[i].id];
      final voltage = nodes[node];
      if (voltage == null || current == null) return null;
      power += ((voltage - nodes[neutral]!) * current.conjugate).real;
    }
    return power.isFinite ? power : null;
  }

  static CircuitState persist(
    CircuitState c,
    Map<ComponentId, MeterEnergyReading> readings,
  ) {
    if (readings.isEmpty) return c;
    final j = c.toJson();
    j['components'] = [
      for (final x in c.components)
        if (!matches(x) || !readings.containsKey(x.id))
          x.toJson()
        else
          {
            ...x.toJson(),
            'parameters': {
              ...x.parameters,
              'meterImportWh': readings[x.id]!.importWh,
              'meterExportWh': readings[x.id]!.exportWh,
            },
          },
    ];
    return CircuitState.fromJson(j);
  }
}
