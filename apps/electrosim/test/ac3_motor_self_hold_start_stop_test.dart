import 'support/industrial_fixture.dart';
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
        final circuit = buildIndustrialSelfHoldCircuit(
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
    final circuit = buildIndustrialSelfHoldCircuit(
      startPressed: false,
      stopPressed: false,
    );
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
