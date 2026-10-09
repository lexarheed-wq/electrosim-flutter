import 'package:electrosim/runtime/electrosim_runtime_engine.dart';
import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('AC3 400/230 V energizes 230 V coil, closes 3 poles and feeds star motor', () {
    final circuit = _assembly(coilWired: true);
    final snapshot = const ElectroSimRuntimeEngine().evaluate(circuit);

    expect(snapshot.solverKind, ElectroSimRuntimeSolverKind.ac3);
    expect(snapshot.solved, isTrue,
        reason: 'A connected source/contactor/star-motor circuit must solve. Diagnostics: ' + (snapshot.ac3Result?.diagnostics.map((d) => d.message).join(' | ') ?? 'AC3 result missing'));
    expect(snapshot.controlIssues, isEmpty);
    expect(snapshot.contactorActuated(ComponentId('k1')), isTrue);
    final coil = snapshot.contactorStates[ComponentId('k1')]!;
    expect(coil.coilVoltageV, closeTo(230, 1e-5));
    for (final String pole in ['L1', 'L2', 'L3']) {
      final current = snapshot.ac3.branch('component:k1:power:$pole').current;
      expect(current, isNotNull);
      expect(current!.magnitude, greaterThan(0.01));
    }
    final motor = snapshot.ac3.branchResults
        .where((b) => b.id.startsWith('component:motor:')).toList();
    expect(motor, hasLength(3));
    for (final branch in motor) {
      expect(branch.current, isNotNull);
      expect(branch.current!.magnitude, greaterThan(0.01));
    }
  });

  test('without coil supply contactor stays released and motor remains isolated', () {
    final circuit = _assembly(coilWired: false);
    final snapshot = const ElectroSimRuntimeEngine().evaluate(circuit);
    expect(snapshot.solverKind, ElectroSimRuntimeSolverKind.ac3);
    expect(snapshot.solved, isTrue, reason: 'Released AC3 circuit: ' + (snapshot.ac3Result?.diagnostics.map((d) => d.message).join(' | ') ?? 'AC3 result missing'));
    expect(snapshot.contactorActuated(ComponentId('k1')), isFalse);
    for (final String pole in ['L1', 'L2', 'L3']) {
      final branch = snapshot.ac3.branch('component:k1:power:$pole');
      expect(branch.current?.magnitude ?? 0, closeTo(0, 1e-7));
    }
  });
}

CircuitState _assembly({required bool coilWired}) {
  final List<Connection> wires = [
    _w('in-1', 'grid-l1', 'k1-1'),
    _w('in-2', 'grid-l2', 'k1-3'),
    _w('in-3', 'grid-l3', 'k1-5'),
    _w('out-1', 'k1-2', 'm-u1'),
    _w('out-2', 'k1-4', 'm-v1'),
    _w('out-3', 'k1-6', 'm-w1'),
    _w('star-1', 'm-u2', 'm-v2'),
    _w('star-2', 'm-v2', 'm-w2'),
    _w('coil-n', 'k1-a2', 'grid-n'),
  ];
  if (coilWired) {
    wires.add(_w('coil-l', 'grid-l1', 'k1-a1'));
  }
  return CircuitState(
    circuitId: CircuitId(coilWired ? 'ac3-contactor-motor-on' : 'ac3-contactor-motor-off'),
    revision: 0,
    mode: ElectricalMode.ac3,
    sources: [
      SourceInstance(
        id: SourceId('grid'),
        modelType: 'ac3_voltage_source',
        terminals: [
          _t('grid-l1', 'L1', PhaseTag.l1, TerminalRole.phaseL1),
          _t('grid-l2', 'L2', PhaseTag.l2, TerminalRole.phaseL2),
          _t('grid-l3', 'L3', PhaseTag.l3, TerminalRole.phaseL3),
          _t('grid-n', 'N', PhaseTag.neutral, TerminalRole.neutral),
        ],
        parameters: const {'phaseVoltageRmsV': 230.0},
      ),
    ],
    components: [
      ComponentInstance(
        id: ComponentId('k1'),
        modelType: 'contactor_3p',
        terminals: [
          _t('k1-1', '1L1', PhaseTag.l1, TerminalRole.lineL1),
          _t('k1-3', '3L2', PhaseTag.l2, TerminalRole.lineL2),
          _t('k1-5', '5L3', PhaseTag.l3, TerminalRole.lineL3),
          _t('k1-2', '2T1', PhaseTag.l1, TerminalRole.loadT1),
          _t('k1-4', '4T2', PhaseTag.l2, TerminalRole.loadT2),
          _t('k1-6', '6T3', PhaseTag.l3, TerminalRole.loadT3),
          _t('k1-a1', 'A1', PhaseTag.l1, TerminalRole.coilA1),
          _t('k1-a2', 'A2', PhaseTag.neutral, TerminalRole.coilA2),
        ],
        parameters: const {
          'coilResistanceOhm': 1000.0,
          'coilInductanceH': 0.0,
          'coilPickupVoltageV': 180.0,
          'coilDropoutVoltageV': 100.0,
        },
        controlState: const {'actuated': false},
      ),
      ComponentInstance(
        id: ComponentId('motor'),
        modelType: 'motor_3p_6t',
        terminals: [
          _t('m-u1', 'U1', PhaseTag.l1, TerminalRole.lineL1),
          _t('m-v1', 'V1', PhaseTag.l2, TerminalRole.lineL2),
          _t('m-w1', 'W1', PhaseTag.l3, TerminalRole.lineL3),
          _t('m-u2', 'U2', PhaseTag.none, TerminalRole.loadT1),
          _t('m-v2', 'V2', PhaseTag.none, TerminalRole.loadT2),
          _t('m-w2', 'W2', PhaseTag.none, TerminalRole.loadT3),
        ],
        parameters: const {'resistanceOhm': 18.0, 'inductanceH': 0.035},
      ),
    ],
    connections: wires,
    settings: const {'frequencyHz': 50.0},
  );
}
Terminal _t(String id, String label, PhaseTag phase, TerminalRole role) =>
    Terminal(id: TerminalId(id), name: label, phase: phase, role: role);
Connection _w(String id, String start, String end) => Connection(
  id: ConnectionId(id),
  fromTerminalId: TerminalId(start),
  toTerminalId: TerminalId(end),
);
