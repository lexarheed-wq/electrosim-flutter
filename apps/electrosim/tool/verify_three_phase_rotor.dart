import 'dart:io';
import 'package:electrosim/runtime/electrosim_runtime_engine.dart';
import 'package:electrosim/runtime/rotor_motion.dart';
import 'package:electrosim_domain/electrosim_domain.dart';

// Pure Dart regression check: no Flutter socket or rendered widget required.
void main() {
  CircuitState circuit({
    required bool delta,
    required bool reverse,
    required bool supplied,
    double frequency = 50,
  }) {
    Terminal t(String id) => Terminal(id: TerminalId(id), name: id);
    Connection w(String id, String a, String b) => Connection(
      id: ConnectionId(id),
      fromTerminalId: TerminalId(a),
      toTerminalId: TerminalId(b),
    );
    return CircuitState(
      circuitId: CircuitId('rotor-check'),
      revision: 0,
      mode: ElectricalMode.ac3,
      sources: [
        SourceInstance(
          id: SourceId('grid'),
          modelType: 'ac3_voltage_source',
          terminals: [
            for (final e in {
              'L1': PhaseTag.l1,
              'L2': PhaseTag.l2,
              'L3': PhaseTag.l3,
              'N': PhaseTag.neutral,
            }.entries)
              Terminal(id: TerminalId(e.key), name: e.key, phase: e.value),
          ],
          parameters: {'phaseVoltageRmsV': 230.0},
        ),
      ],
      components: [
        ComponentInstance(
          id: ComponentId('motor'),
          modelType: 'earthed_machine_3p_7t',
          terminals: [
            for (final id in ['U1', 'V1', 'W1', 'U2', 'V2', 'W2', 'PE']) t(id),
          ],
          parameters: {'resistanceOhm': 12.0, 'inductanceH': .045},
        ),
      ],
      connections: [
        if (supplied) ...[
          w('a', 'L1', 'U1'),
          w('b', reverse ? 'L3' : 'L2', 'V1'),
          w('c', reverse ? 'L2' : 'L3', 'W1'),
        ],
        if (delta) ...[
          w('d1', 'U1', 'W2'),
          w('d2', 'V1', 'U2'),
          w('d3', 'W1', 'V2'),
        ] else ...[
          w('s1', 'U2', 'V2'),
          w('s2', 'V2', 'W2'),
        ],
        w('pe', 'N', 'PE'),
      ],
      settings: {'frequencyHz': frequency},
    );
  }

  double speed(CircuitState c, {bool running = true}) {
    final s = const ElectroSimRuntimeEngine().advance(
      c,
      elapsed: Duration.zero,
    );
    if (!s.solved) throw StateError('Fixture does not solve: ${c.toJson()}');
    return rotorVelocity(
      s,
      c.components.single,
      running: running,
      energized: true,
      voltageV: 400,
      ratedVoltageV: 400,
    )!;
  }

  void check(bool condition, String name) {
    if (!condition) throw StateError(name);
    stdout.writeln('PASS: $name');
  }

  for (final delta in [false, true]) {
    final forward = circuit(delta: delta, reverse: false, supplied: true);
    final reverse = circuit(delta: delta, reverse: true, supplied: true);
    final positive = speed(forward), negative = speed(reverse);
    check(
      positive > 0 && negative < 0 && (positive + negative).abs() < 1e-9,
      '${delta ? "delta" : "star"}: actual winding voltages determine direction without probes',
    );
    check(speed(forward, running: false) == 0, 'pause stops rotor');
    check(
      speed(
            circuit(
              delta: delta,
              reverse: false,
              supplied: true,
              frequency: 25,
            ),
          ) <
          positive,
      'lower electrical frequency lowers visible field speed',
    );
  }
  final phase = RotorPhase();
  phase.advance(0, 6.283185307179586);
  check(
    (phase.advance(.25, 6.283185307179586) - .25).abs() < 1e-9,
    'continuous quarter turn',
  );
  check(
    (phase.advance(1.5, 6.283185307179586) - .5).abs() < 1e-9,
    'full revolution crosses zero',
  );
}
