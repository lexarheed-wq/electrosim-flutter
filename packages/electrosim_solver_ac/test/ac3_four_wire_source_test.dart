import 'dart:math' as math;

import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:electrosim_solver_ac/electrosim_solver_ac.dart';
import 'package:electrosim_topology/electrosim_topology.dart';
import 'package:test/test.dart';

void main() {
  const TopologyEngine topologyEngine = TopologyEngine();
  const SolverAC3 solver = SolverAC3();

  test('four-wire AC3 source produces positive 400/230 V sequence', () {
    final CircuitState circuit = _balancedWyeCircuit();
    final Ac3SolveResult result =
        solver.solve(circuit, topologyEngine.compile(circuit));

    expect(result.status, Ac3SolveStatus.solved);
    expect(result.sourceSequence, Ac3PhaseSequence.positive);
    expect(result.voltageBalanced, isTrue);
    expect(result.currentBalanced, isTrue);
    expect(result.neutralConnected, isTrue);

    for (final PhaseTag phase
        in <PhaseTag>[PhaseTag.l1, PhaseTag.l2, PhaseTag.l3]) {
      expect(result.phaseVoltage(phase)?.magnitude, closeTo(230.0, 1e-8));
      expect(result.lineCurrent(phase).magnitude, closeTo(10.0, 1e-8));
    }

    final double expectedLineLine = 230.0 * math.sqrt(3.0);
    expect(
      result.lineToLineVoltages['L1-L2']?.magnitude,
      closeTo(expectedLineLine, 1e-8),
    );
    expect(
      result.lineToLineVoltages['L2-L3']?.magnitude,
      closeTo(expectedLineLine, 1e-8),
    );
    expect(
      result.lineToLineVoltages['L3-L1']?.magnitude,
      closeTo(expectedLineLine, 1e-8),
    );

    expect(
      result.branch('source:grid:l1').voltage.magnitude,
      closeTo(230.0, 1e-8),
    );
    expect(
      result.branch('source:grid:l2').voltage.magnitude,
      closeTo(230.0, 1e-8),
    );
    expect(
      result.branch('source:grid:l3').voltage.magnitude,
      closeTo(230.0, 1e-8),
    );
  });
}

CircuitState _balancedWyeCircuit() {
  return CircuitState(
    circuitId: CircuitId('ac3-four-wire-source'),
    revision: 0,
    mode: ElectricalMode.ac3,
    sources: <SourceInstance>[
      SourceInstance(
        id: SourceId('grid'),
        modelType: 'ac3_voltage_source',
        terminals: <Terminal>[
          _t('grid-l1', 'L1', PhaseTag.l1, TerminalRole.phaseL1),
          _t('grid-l2', 'L2', PhaseTag.l2, TerminalRole.phaseL2),
          _t('grid-l3', 'L3', PhaseTag.l3, TerminalRole.phaseL3),
          _t('grid-n', 'N', PhaseTag.neutral, TerminalRole.neutral),
        ],
        parameters: const <String, Object?>{
          'phaseVoltageRmsV': 230.0,
        },
      ),
    ],
    components: <ComponentInstance>[
      ComponentInstance(
        id: ComponentId('load'),
        modelType: 'load_wye_3p',
        terminals: <Terminal>[
          _t('load-l1', 'L1', PhaseTag.l1, TerminalRole.lineL1),
          _t('load-l2', 'L2', PhaseTag.l2, TerminalRole.lineL2),
          _t('load-l3', 'L3', PhaseTag.l3, TerminalRole.lineL3),
          _t('load-n', 'N', PhaseTag.neutral, TerminalRole.neutral),
        ],
        parameters: const <String, Object?>{
          'resistanceOhm': 23.0,
          'inductanceH': 0.0,
        },
      ),
    ],
    connections: <Connection>[
      _w('l1', 'grid-l1', 'load-l1', PhaseTag.l1),
      _w('l2', 'grid-l2', 'load-l2', PhaseTag.l2),
      _w('l3', 'grid-l3', 'load-l3', PhaseTag.l3),
      _w('n', 'grid-n', 'load-n', PhaseTag.neutral),
    ],
    settings: const <String, Object?>{'frequencyHz': 50.0},
  );
}

Terminal _t(
  String id,
  String name,
  PhaseTag phase,
  TerminalRole role,
) =>
    Terminal(
      id: TerminalId(id),
      name: name,
      phase: phase,
      role: role,
    );

Connection _w(String id, String from, String to, PhaseTag phase) =>
    Connection(
      id: ConnectionId(id),
      fromTerminalId: TerminalId(from),
      toTerminalId: TerminalId(to),
      phase: phase,
    );
