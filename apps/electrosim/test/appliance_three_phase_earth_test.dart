import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:electrosim/runtime/electrosim_runtime_engine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'industrial machine retains six windings, adds PE and solves phase-earth fault',
    () {
      Terminal t(String id, String name, PhaseTag phase) =>
          Terminal(id: TerminalId(id), name: name, phase: phase);
      Connection w(String id, String a, String b) => Connection(
        id: ConnectionId(id),
        fromTerminalId: TerminalId(a),
        toTerminalId: TerminalId(b),
      );
      final old = CircuitState(
        circuitId: CircuitId('machine-earth'),
        revision: 0,
        mode: ElectricalMode.ac3,
        sources: [
          SourceInstance(
            id: SourceId('grid'),
            modelType: 'ac3_voltage_source',
            terminals: [
              t('l1', 'L1', PhaseTag.l1),
              t('l2', 'L2', PhaseTag.l2),
              t('l3', 'L3', PhaseTag.l3),
              t('n', 'N', PhaseTag.neutral),
            ],
            parameters: {'phaseVoltageRmsV': 230.0},
          ),
        ],
        components: [
          ComponentInstance(
            id: ComponentId('machine'),
            modelType: 'motor_3p_6t',
            terminals: [
              for (final name in ['U1', 'V1', 'W1', 'U2', 'V2', 'W2'])
                t(name, name, PhaseTag.none),
            ],
            parameters: {
              '_visualModelType': 'catalog_motor_driven_6t',
              '_visualVariant': 'compressor',
              'resistanceOhm': 18.0,
              'inductanceH': .035,
            },
          ),
        ],
        connections: [
          w('l1-u', 'l1', 'U1'),
          w('l2-v', 'l2', 'V1'),
          w('l3-w', 'l3', 'W1'),
          w('star-u-v', 'U2', 'V2'),
          w('star-v-w', 'V2', 'W2'),
        ],
        settings: {'frequencyHz': 50.0},
      );
      final upgraded = AppliancePowerConnection.addProtectiveEarth(old);
      expect(
        upgraded.components.single.terminals.take(6),
        old.components.single.terminals,
      );
      expect(upgraded.components.single.terminals.length, 7);
      final data = upgraded.toJson();
      data['connections'] = [
        ...upgraded.connections.map((x) => x.toJson()),
        w('earth-bond', 'n', 'machine:chassis-pe').toJson(),
      ];
      final grounded = CircuitState.fromJson(data);
      const engine = ElectroSimRuntimeEngine();
      final before = engine.evaluate(old);
      final after = engine.evaluate(grounded);
      expect(
        after.solved,
        isTrue,
        reason: after.ac3Result?.diagnostics.map((d) => d.message).join(' | '),
      );
      expect(
        MotorThreePhaseCouplingEvaluator.evaluate(
          grounded,
          grounded.components.single,
        ).isValid,
        isTrue,
      );
      final deltaData = grounded.toJson();
      deltaData['connections'] = [
        ...grounded.connections
            .where((x) => !x.id.value.startsWith('star-'))
            .map((x) => x.toJson()),
        w('delta-u-w', 'U1', 'W2').toJson(),
        w('delta-v-u', 'V1', 'U2').toJson(),
        w('delta-w-v', 'W1', 'V2').toJson(),
      ];
      final deltaCircuit = CircuitState.fromJson(deltaData);
      expect(
        MotorThreePhaseCouplingEvaluator.evaluate(
          deltaCircuit,
          deltaCircuit.components.single,
        ).isValid,
        isTrue,
      );
      for (final phase in ['U', 'V', 'W']) {
        final id = 'component:machine:winding:$phase';
        expect(
          after.ac3.branch(id).current!.magnitude,
          closeTo(before.ac3.branch(id).current!.magnitude, 1e-8),
        );
      }
      final fault = engine.evaluate(
        AppliancePowerConnection.setInsulationFault(grounded, 'machine', true),
      );
      expect(fault.solved, isTrue);
      expect(
        fault.ac3.branch('component:earth-fault:machine').current!.magnitude,
        closeTo(.23, 1e-8),
      );
    },
  );
}
