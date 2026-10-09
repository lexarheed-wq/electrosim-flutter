import 'dart:math' as math;

import 'package:electrosim_domain/electrosim_domain.dart';

import 'pv_result.dart';

/// Physical current in a named PV conductor after replacing that conductor
/// with an ammeter of finite series resistance. The authored circuit is never
/// mutated. Every solved wire has its own branch current, including parallel
/// and meshed return conductors.
final class PvNodalWireReading {
  const PvNodalWireReading({
    required this.currentA,
    required this.voltageDropV,
    required this.lossW,
    required this.evidence,
  });
  final double currentA;
  final double voltageDropV;
  final double lossW;
  final String evidence;
}

/// Resistive conductor-network solver coupled to the authoritative PV power
/// solution. An explicitly defined wire resistance can be supplied through
/// Connection.metadata['resistanceOhm']; absent metadata represents an ideal
/// conductor. The selected cut wire gains the ammeter's actual burden.
///
/// AC networks are solved from the inverter bus and individual resistive load
/// branches, including meshes, parallel cables and power-limited inverters.
/// Direct array->inverter DC paths use a constant-power sink and both outgoing
/// and return meshes. Unsupported device laws are not approximated.
abstract final class PvNodalWireSolver {
  static PvNodalWireReading? solve({
    required CircuitState circuit,
    required PvSolveResult pv,
    required Connection cutWire,
    required double burdenOhm,
  }) {
    if (!pv.isSolved || !burdenOhm.isFinite || burdenOhm <= 0 ||
        !cutWire.enabled || !circuit.connections.any((c) => c.id == cutWire.id)) {
      return null;
    }
    final terminals = <TerminalId, Terminal>{
      for (final source in circuit.sources)
        for (final terminal in source.terminals) terminal.id: terminal,
      for (final component in circuit.components)
        for (final terminal in component.terminals) terminal.id: terminal,
    };
    final first = terminals[cutWire.fromTerminalId];
    final second = terminals[cutWire.toTerminalId];
    if (first == null || second == null ||
        first.phase != second.phase) return null;
    switch (first.phase) {
      case PhaseTag.l1:
      case PhaseTag.neutral:
        return _solveAc(circuit, pv, cutWire, burdenOhm, terminals);
      case PhaseTag.dcPositive:
      case PhaseTag.dcNegative:
        return _solveDc(circuit, pv, cutWire, burdenOhm, terminals);
      default:
        return null;
    }
  }

  static PvNodalWireReading? _solveAc(
    CircuitState circuit, PvSolveResult pv,
    Connection cutWire, double burdenOhm,
    Map<TerminalId, Terminal> terminals,
  ) {
    final inverters = circuit.components.where(
      (c) => c.modelType == 'pv_inverter',
    ).toList();
    if (inverters.length != 1) return null;
    final inverter = inverters.single;
    final line = _port(inverter.terminals, PhaseTag.l1);
    final neutral = _port(inverter.terminals, PhaseTag.neutral);
    if (line == null || neutral == null) return null;
    final network = _WireNetwork(circuit, cutWire, burdenOhm, terminals,
      const {PhaseTag.l1, PhaseTag.neutral});
    if (!network.valid) return null;

    // Passive receiver branches form a genuine multi-load nodal network.
    for (final result in pv.loadResults) {
      final models = circuit.components.where(
        (c) => c.id == result.componentId,
      ).toList();
      if (models.length != 1 || !result.resistanceOhm.isFinite ||
          result.resistanceOhm <= 0) return null;
      final receiver = models.single;
      final a = _port(receiver.terminals, PhaseTag.l1);
      final b = _port(receiver.terminals, PhaseTag.neutral);
      if (a == null && b == null) continue; // DC loads belong to another island.
      if (a == null || b == null ||
          !network.addResistance(a, b, result.resistanceOhm)) return null;
    }
    final solution = network.voltageSolve(line, neutral);
    if (solution == null) return null;
    final conductance = solution.sourceCurrentA;
    if (!conductance.isFinite || conductance < -1e-8) return null;
    final baseVoltage = pv.inverterOutputVoltageRmsV;
    if (baseVoltage < 0 || !baseVoltage.isFinite) return null;
    double voltage = baseVoltage;
    if (pv.inverterState == PvInverterState.powerLimited &&
        conductance > 1e-14) {
      // P available is fixed by the PV/inverter model; the nodal admittance
      // changes under meter burden, so the output voltage must be recomputed.
      final nominal = inverter.parameters['nominalAcVoltageV'];
      if (nominal is! num || !nominal.toDouble().isFinite ||
          nominal.toDouble() <= 0) return null;
      voltage = math.min(nominal.toDouble(),
        math.sqrt(pv.inverterOutputPowerW / conductance));
    }
    return network.reading(solution, voltage, cutWire, burdenOhm, 'pv-nodal-ac');
  }

  static PvNodalWireReading? _solveDc(
    CircuitState circuit, PvSolveResult pv,
    Connection cutWire, double burdenOhm,
    Map<TerminalId, Terminal> terminals,
  ) {
    // The existing aggregate PV model provides the DC input power of a
    // single inverter. This model covers *arbitrarily many parallel/meshed*
    // source conductors, without inventing missing PV controller state.
    final arrays = circuit.sources.where(
      (s) => s.enabled && s.modelType == 'pv_array',
    ).toList();
    final inverters = circuit.components.where(
      (c) => c.modelType == 'pv_inverter',
    ).toList();
    if (pv.controllerPresent || pv.batteryPresent) {
      return _solveStorageDc(
        circuit, pv, cutWire, burdenOhm, terminals,
      );
    }
    if (arrays.length != 1 || inverters.length != 1) return null;

    final sourceP = _port(arrays.single.terminals, PhaseTag.dcPositive);
    final sourceN = _port(arrays.single.terminals, PhaseTag.dcNegative);
    final loadP = _port(inverters.single.terminals, PhaseTag.dcPositive);
    final loadN = _port(inverters.single.terminals, PhaseTag.dcNegative);
    if (sourceP == null || sourceN == null || loadP == null || loadN == null) {
      return null;
    }
    final network = _WireNetwork(circuit, cutWire, burdenOhm, terminals,
      const {PhaseTag.dcPositive, PhaseTag.dcNegative});
    if (!network.valid) return null;
    final solution = network.currentSolve({
      sourceP: 1, loadP: -1, sourceN: -1, loadN: 1,
    });
    if (solution == null) return null;
    final resistance = solution.voltage(sourceP) -
        solution.voltage(loadP) +
        solution.voltage(loadN) - solution.voltage(sourceN);
    if (!resistance.isFinite || resistance < -1e-8) return null;
    final voltage = pv.pvOperatingVoltageV;
    final power = pv.pvDrawnPowerW;
    if (!voltage.isFinite || voltage <= 0 ||
        !power.isFinite || power < 0) return null;
    double current = 0;
    if (power > 0) {
      final disc = voltage * voltage - 4 * resistance * power;
      if (disc < 0 || !disc.isFinite) return null;
      current = 2 * power / (voltage + math.sqrt(disc));
    }
    if (!current.isFinite || current < 0 ||
        current > pv.pvAvailableCurrentA + 1e-6) return null;
    return network.reading(solution, current, cutWire, burdenOhm,
      'pv-nodal-dc-power');
  }

  /// KCL current distribution for converter/storage PV topologies.
  /// Port currents are derived from the PV solver's energy balance, not
  /// inferred from a nearby conductor. A port-island with unmatched current
  /// or an excessively large meter loss is rejected instead of faked.
  static PvNodalWireReading? _solveStorageDc(
    CircuitState circuit, PvSolveResult pv,
    Connection cutWire, double burdenOhm,
    Map<TerminalId, Terminal> terminals,
  ) {
    if (!pv.batteryPresent || !pv.controllerPresent ||
        pv.batteryVoltageV <= 0 || pv.pvOperatingVoltageV <= 0) return null;
    final arrays = circuit.sources.where(
      (s) => s.enabled && s.modelType == 'pv_array',
    ).toList();
    final controllers = circuit.components.where(
      (c) => c.modelType == 'pv_controller',
    ).toList();
    final batteries = circuit.components.where(
      (c) => c.modelType == 'pv_battery',
    ).toList();
    final inverters = circuit.components.where(
      (c) => c.modelType == 'pv_inverter',
    ).toList();
    if (arrays.length != 1 || controllers.length != 1 ||
        batteries.length != 1 || inverters.length > 1) return null;
    final circuitNetwork = _WireNetwork(
      circuit, cutWire, burdenOhm, terminals,
      const {PhaseTag.dcPositive, PhaseTag.dcNegative},
    );
    if (!circuitNetwork.valid) return null;
    final currents = <TerminalId, double>{};
    void pair(TerminalId? p, TerminalId? n, double amps) {
      if (p == null || n == null) return;
      currents.update(p, (v) => v + amps, ifAbsent: () => amps);
      currents.update(n, (v) => v - amps, ifAbsent: () => -amps);
    }
    final source = arrays.single;
    final ip = pv.pvDrawnCurrentA;
    pair(_port(source.terminals, PhaseTag.dcPositive),
        _port(source.terminals, PhaseTag.dcNegative), ip);
    final controller = controllers.single;
    TerminalId? cPort(String group, PhaseTag phase) {
      final found = controller.terminals.where((t) =>
          t.phase == phase && t.name.toUpperCase().startsWith(group)).toList();
      return found.length == 1 ? found.single.id : null;
    }
    final cp = cPort('PV', PhaseTag.dcPositive);
    final cn = cPort('PV', PhaseTag.dcNegative);
    final bp = cPort('BAT', PhaseTag.dcPositive);
    final bn = cPort('BAT', PhaseTag.dcNegative);
    if ([cp, cn, bp, bn].any((x) => x == null)) return null;
    pair(cp, cn, -ip);
    final controllerBusPower =
        pv.pvDrawnPowerW - pv.controllerConversionLossW;
    pair(bp, bn, controllerBusPower / pv.batteryVoltageV);
    final battery = batteries.single;
    pair(_port(battery.terminals, PhaseTag.dcPositive),
        _port(battery.terminals, PhaseTag.dcNegative),
        pv.batteryPowerW / pv.batteryVoltageV);
    if (inverters.isNotEmpty) {
      final inverter = inverters.single;
      if (pv.inverterEfficiency <= 0 &&
          pv.inverterOutputPowerW > 1e-8) return null;
      final inverterPower = pv.inverterEfficiency > 0
          ? pv.inverterOutputPowerW / pv.inverterEfficiency : 0.0;
      pair(_port(inverter.terminals, PhaseTag.dcPositive),
          _port(inverter.terminals, PhaseTag.dcNegative),
          -inverterPower / pv.batteryVoltageV);
    }
    for (final load in pv.loadResults) {
      final models = circuit.components.where(
        (c) => c.id == load.componentId,
      ).toList();
      if (models.length != 1) return null;
      final component = models.single;
      final p = _port(component.terminals, PhaseTag.dcPositive);
      final n = _port(component.terminals, PhaseTag.dcNegative);
      if (p == null && n == null) continue;
      if (p == null || n == null) return null;
      pair(p, n, -load.currentRmsA);
    }
    final solved = circuitNetwork.currentSolve(currents);
    if (solved == null) return null;
    final battery = batteries.single;
    final batteryWire = battery.terminals.any((t) =>
        t.id == cutWire.fromTerminalId || t.id == cutWire.toTerminalId);
    final evidence = batteryWire
        ? 'pv-nodal-storage-kcl:pv-battery:${battery.id.value}'
        : 'pv-nodal-storage-kcl';
    final reading = circuitNetwork.reading(
        solved, 1.0, cutWire, burdenOhm, evidence);
    if (reading == null) return null;
    // This is a fixed operating-point projection of aggregate PV power.
    // Significant additional meter power would alter the controller/battery
    // operating point and must not be displayed as an exact measurement.
    final energyScale = math.max(
      1.0, pv.pvDrawnPowerW + math.max(0, pv.batteryPowerW));
    if (reading.lossW > energyScale * 0.02) return null;
    return reading;
  }

  static TerminalId? _port(List<Terminal> terminals, PhaseTag phase) {
    final found = terminals.where((t) => t.phase == phase).toList();
    return found.length == 1 ? found.single.id : null;
  }
}

final class _Edge {
  const _Edge(this.a, this.b, this.resistanceOhm, {this.wire});
  final TerminalId a, b;
  final double resistanceOhm;
  final ConnectionId? wire;
}

final class _WireNetwork {
  _WireNetwork(
    CircuitState circuit, Connection meterWire, double burdenOhm,
    Map<TerminalId, Terminal> terminals, Set<PhaseTag> phases,
  ) {
    for (final t in terminals.values.where((t) => phases.contains(t.phase))) {
      _parents[t.id] = t.id;
    }
    for (final wire in circuit.connections.where((c) => c.enabled)) {
      if (!_parents.containsKey(wire.fromTerminalId) ||
          !_parents.containsKey(wire.toTerminalId)) continue;
      final a = terminals[wire.fromTerminalId]!;
      final b = terminals[wire.toTerminalId]!;
      if (a.phase != b.phase) {
        valid = false;
        return;
      }
      final raw = wire.metadata['resistanceOhm'];
      if (raw != null && (raw is! num || !raw.toDouble().isFinite ||
          raw.toDouble() < 0)) {
        valid = false;
        return;
      }
      final resistance = (raw is num ? raw.toDouble() : 0.0) +
          (wire.id == meterWire.id ? burdenOhm : 0);
      if (resistance == 0) {
        _union(wire.fromTerminalId, wire.toTerminalId);
      } else {
        _edges.add(_Edge(wire.fromTerminalId,
            wire.toTerminalId, resistance, wire: wire.id));
      }
    }
    if (!_edges.any((e) => e.wire == meterWire.id)) valid = false;
  }
  bool valid = true;
  final Map<TerminalId, TerminalId> _parents = {};
  final List<_Edge> _edges = [];

  TerminalId _root(TerminalId id) {
    final p = _parents[id]!;
    if (p == id) return id;
    return _parents[id] = _root(p);
  }
  void _union(TerminalId a, TerminalId b) {
    final ra = _root(a), rb = _root(b);
    if (ra != rb) _parents[rb] = ra;
  }

  bool addResistance(TerminalId a, TerminalId b, double resistanceOhm) {
    if (!_parents.containsKey(a) || !_parents.containsKey(b) ||
        !resistanceOhm.isFinite || resistanceOhm <= 0) return false;
    _edges.add(_Edge(a, b, resistanceOhm));
    return true;
  }

  _NodalSolution? currentSolve(Map<TerminalId, double> injected) =>
      _solve(injected: injected);

  _NodalSolution? voltageSolve(TerminalId high, TerminalId low) =>
      _solve(fixed: {high: 1.0, low: 0.0}, input: high);

  _NodalSolution? _solve({
    Map<TerminalId, double> injected = const {},
    Map<TerminalId, double> fixed = const {},
    TerminalId? input,
  }) {
    if (!valid || _parents.length > 256 ||
        injected.keys.any((id) => !_parents.containsKey(id)) ||
        fixed.keys.any((id) => !_parents.containsKey(id))) return null;
    final roots = _parents.keys.map(_root).toSet().toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    final normalized = <TerminalId, double>{};
    for (final entry in fixed.entries) {
      final root = _root(entry.key);
      if (normalized.containsKey(root) &&
          (normalized[root]! - entry.value).abs() > 1e-10) return null;
      normalized[root] = entry.value;
    }
    final connects = <TerminalId, Set<TerminalId>>{
      for (final root in roots) root: {},
    };
    for (final edge in _edges) {
      final a = _root(edge.a), b = _root(edge.b);
      if (a == b) continue;
      connects[a]!.add(b);
      connects[b]!.add(a);
    }
    final comps = <Set<TerminalId>>[];
    final visited = <TerminalId>{};
    for (final root in roots) {
      if (!visited.add(root)) continue;
      final group = <TerminalId>{root}, pending = <TerminalId>[root];
      for (var i = 0; i < pending.length; i++) {
        for (final next in connects[pending[i]]!) {
          if (visited.add(next)) {
            group.add(next);
            pending.add(next);
          }
        }
      }
      comps.add(group);
    }

    final rhs = <TerminalId, double>{};
    for (final entry in injected.entries) {
      rhs.update(_root(entry.key), (v) => v + entry.value,
          ifAbsent: () => entry.value);
    }
    // No unreferenced island may carry unbalanced injected current.
    for (final component in comps) {
      if (!component.any(normalized.containsKey)) {
        final net = component.fold<double>(0,
            (sum, id) => sum + (rhs[id] ?? 0));
        if (net.abs() > 1e-8) return null;
        normalized[component.first] = 0;
      }
    }
    final unknown = roots.where((r) => !normalized.containsKey(r)).toList();
    final index = <TerminalId, int>{
      for (var i = 0; i < unknown.length; i++) unknown[i]: i,
    };
    final count = unknown.length;
    final m = List.generate(count, (_) => List<double>.filled(count + 1, 0));
    for (final entry in rhs.entries) {
      final i = index[entry.key];
      if (i != null) m[i][count] += entry.value;
    }
    for (final edge in _edges) {
      final a = _root(edge.a), b = _root(edge.b);
      if (a == b) continue;
      final g = 1 / edge.resistanceOhm;
      if (!g.isFinite || g <= 0) return null;
      final ia = index[a], ib = index[b];
      if (ia != null) {
        m[ia][ia] += g;
        if (ib != null) {
          m[ia][ib] -= g;
        } else {
          m[ia][count] += g * normalized[b]!;
        }
      }
      if (ib != null) {
        m[ib][ib] += g;
        if (ia != null) {
          m[ib][ia] -= g;
        } else {
          m[ib][count] += g * normalized[a]!;
        }
      }
    }
    for (var p = 0; p < count; p++) {
      var pivot = p;
      for (var i = p + 1; i < count; i++) {
        if (m[i][p].abs() > m[pivot][p].abs()) pivot = i;
      }
      if (m[pivot][p].abs() < 1e-15) return null;
      if (pivot != p) {
        final tmp = m[p]; m[p] = m[pivot]; m[pivot] = tmp;
      }
      final value = m[p][p];
      for (var j = p; j <= count; j++) m[p][j] /= value;
      for (var i = 0; i < count; i++) {
        if (i == p) continue;
        final factor = m[i][p];
        for (var j = p; j <= count; j++) m[i][j] -= factor * m[p][j];
      }
    }
    final volts = <TerminalId, double>{...normalized};
    for (var i = 0; i < count; i++) volts[unknown[i]] = m[i][count];
    if (volts.values.any((v) => !v.isFinite)) return null;
    double inputCurrent = 0;
    if (input != null) {
      final root = _root(input);
      for (final edge in _edges) {
        final a = _root(edge.a), b = _root(edge.b);
        if (a == b) continue;
        if (a == root) inputCurrent += (volts[a]! - volts[b]!) / edge.resistanceOhm;
        if (b == root) inputCurrent += (volts[b]! - volts[a]!) / edge.resistanceOhm;
      }
    }
    return _NodalSolution(_root, volts, inputCurrent);
  }

  PvNodalWireReading? reading(
    _NodalSolution solution, double scale, Connection meterWire,
    double burdenOhm, String evidence,
  ) {
    if (!scale.isFinite || scale < 0) return null;
    final candidates = _edges.where((e) => e.wire == meterWire.id).toList();
    if (candidates.length != 1) return null;
    final edge = candidates.single;
    final currentA = ((solution.voltage(edge.a) -
            solution.voltage(edge.b)) / edge.resistanceOhm * scale).abs();
    if (!currentA.isFinite) return null;
    return PvNodalWireReading(
      currentA: currentA,
      voltageDropV: currentA * burdenOhm,
      lossW: currentA * currentA * burdenOhm,
      evidence: '$evidence:wire:${meterWire.id.value}',
    );
  }
}

final class _NodalSolution {
  const _NodalSolution(this.root, this.potentials, this.sourceCurrentA);
  final TerminalId Function(TerminalId) root;
  final Map<TerminalId, double> potentials;
  final double sourceCurrentA;
  double voltage(TerminalId id) => potentials[root(id)]!;
}
