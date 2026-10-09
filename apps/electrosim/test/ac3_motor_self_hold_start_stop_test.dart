import 'package:electrosim/runtime/electrosim_runtime_engine.dart';
import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:electrosim_controls/electrosim_controls.dart';
import 'package:electrosim_topology/electrosim_topology.dart';
import 'package:flutter_test/flutter_test.dart';

const _engine = ElectroSimRuntimeEngine();
final _contactorId = ComponentId('k1');

void main() {
  test(
    'AC3 self-hold: idle, START, release START, STOP, release STOP, restart',
    () {
      var priorClosed = false;
      ElectroSimRuntimeSnapshot step({
        required bool start,
        required bool stop,
        required bool expectRunning,
        required String label,
      }) {
        final circuit = _selfHoldAssembly(
          startPressed: start,
          stopPressed: stop,
        );
        final snapshot = _engine.advance(
          circuit,
          elapsed: Duration.zero,
          previousContactorStates: {_contactorId: priorClosed},
        );
        expect(
          snapshot.solverKind,
          ElectroSimRuntimeSolverKind.ac3,
          reason: label,
        );
        expect(
          snapshot.solved,
          isTrue,
          reason:
              '$label: ${snapshot.ac3Result?.diagnostics.map((d) => d.message).join(" / ")}',
        );
        expect(snapshot.controlIssues, isEmpty, reason: label);
        expect(
          snapshot.contactorActuated(_contactorId),
          expectRunning,
          reason: label,
        );
        final state = snapshot.contactorStates[_contactorId]!;
        expect(
          state.coilVoltageV,
          closeTo(expectRunning ? 230.0 : 0.0, .1),
          reason: '$label: coil A1/A2',
        );
        final controlResult = const ElectromechanicalControlEngine().solveAc3(
          circuit: circuit,
          topology: const TopologyEngine().compile(circuit),
          previousStates: {_contactorId: priorClosed},
        );
        expect(controlResult.converged, isTrue, reason: label);
        expect(controlResult.issues, isEmpty, reason: label);
        expect(
          controlResult.effectiveCircuit.components
              .singleWhere((c) => c.id == ComponentId('aux'))
              .controlState['actuated'],
          expectRunning,
          reason: '$label: auxiliary 13/14',
        );
        for (final pole in ['L1', 'L2', 'L3']) {
          final amps =
              snapshot.ac3
                  .branch('component:k1:power:$pole')
                  .current
                  ?.magnitude ??
              0.0;
          if (expectRunning) {
            expect(amps, greaterThan(.01), reason: '$label: pole $pole');
          } else {
            expect(amps, closeTo(0.0, 1e-7), reason: '$label: pole $pole');
          }
        }
        final motorBranches = snapshot.ac3.branchResults
            .where((b) => b.id.startsWith('component:motor:'))
            .toList();
        expect(motorBranches, hasLength(3), reason: label);
        for (final branch in motorBranches) {
          final amps = branch.current?.magnitude ?? 0.0;
          if (expectRunning) {
            expect(amps, greaterThan(.01), reason: '$label: ${branch.id}');
          } else {
            expect(amps, closeTo(0.0, 1e-7), reason: '$label: ${branch.id}');
          }
        }
        priorClosed = expectRunning;
        return snapshot;
      }

      step(start: false, stop: false, expectRunning: false, label: 'idle');
      step(
        start: true,
        stop: false,
        expectRunning: true,
        label: 'START pressed',
      );
      step(
        start: false,
        stop: false,
        expectRunning: true,
        label: 'START released: holding contact closes',
      );
      step(
        start: false,
        stop: true,
        expectRunning: false,
        label: 'STOP pressed: NC opens',
      );
      step(
        start: false,
        stop: false,
        expectRunning: false,
        label: 'STOP released: no unwanted restart',
      );
      step(start: true, stop: false, expectRunning: true, label: 'restart');
      step(
        start: true,
        stop: true,
        expectRunning: false,
        label: 'STOP wins even when START is held',
      );
      step(
        start: false,
        stop: false,
        expectRunning: false,
        label: 'remains stopped',
      );
    },
  );

  test('wrong link cannot falsely energize the auxiliary contact', () {
    final circuit = _selfHoldAssembly(startPressed: false, stopPressed: false);
    final modified = CircuitState(
      circuitId: circuit.circuitId,
      revision: circuit.revision,
      mode: circuit.mode,
      sources: circuit.sources,
      connections: circuit.connections,
      components: [
        for (final c in circuit.components)
          if (c.id == ComponentId('aux'))
            ComponentInstance(
              id: c.id,
              modelType: c.modelType,
              terminals: c.terminals,
              parameters: const {'linkedContactorId': 'missing-k2'},
            )
          else
            c,
      ],
      settings: circuit.settings,
    );
    final snapshot = _engine.evaluate(modified);
    expect(
      snapshot.controlIssues.map((e) => e.message).join(' / '),
      contains('does not reference a known coil device'),
    );
    expect(snapshot.contactorActuated(_contactorId), isFalse);
  });
}

CircuitState _selfHoldAssembly({
  required bool startPressed,
  required bool stopPressed,
  double phaseVoltageV = 230.0,
}) {
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
  wires.addAll([
    _w('control-stop-supply', 'grid-l1', 'stop-in'),
    _w('stop-to-start', 'stop-out', 'start-in'),
    _w('stop-to-aux', 'stop-out', 'aux-in'),
    _w('start-to-coil', 'start-out', 'k1-a1'),
    _w('aux-to-coil', 'aux-out', 'k1-a1'),
  ]);
  return CircuitState(
    circuitId: CircuitId('ac3-motor-self-hold'),
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
        parameters: {'phaseVoltageRmsV': phaseVoltageV},
      ),
    ],
    components: [
      ComponentInstance(
        id: ComponentId('stop'),
        modelType: 'push_button_nc',
        terminals: [
          _t('stop-in', '21', PhaseTag.l1, TerminalRole.generic),
          _t('stop-out', '22', PhaseTag.l1, TerminalRole.generic),
        ],
        controlState: {'pressed': stopPressed},
      ),
      ComponentInstance(
        id: ComponentId('start'),
        modelType: 'push_button_no',
        terminals: [
          _t('start-in', '13', PhaseTag.l1, TerminalRole.generic),
          _t('start-out', '14', PhaseTag.l1, TerminalRole.generic),
        ],
        controlState: {'pressed': startPressed},
      ),
      ComponentInstance(
        id: ComponentId('aux'),
        modelType: 'contactor_aux_no',
        terminals: [
          _t('aux-in', '13', PhaseTag.l1, TerminalRole.generic),
          _t('aux-out', '14', PhaseTag.l1, TerminalRole.generic),
        ],
        parameters: const {'linkedContactorId': 'k1'},
      ),
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
