import 'package:electrosim/runtime/electrosim_runtime_engine.dart';
import 'package:electrosim/runtime/electrosim_simulation_controller.dart';
import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:flutter_test/flutter_test.dart';

CircuitState motorCircuit({double volts = 24.0, double resistance = 4.0}) {
  final Terminal plus = Terminal(id: TerminalId('source-positive'), name: '+');
  final Terminal minus = Terminal(id: TerminalId('source-negative'), name: '-');
  final Terminal a = Terminal(id: TerminalId('motor-positive'), name: '+');
  final Terminal b = Terminal(id: TerminalId('motor-negative'), name: '-');
  return CircuitState(
    circuitId: CircuitId('scientific-pmdc-motor'),
    revision: 0,
    mode: ElectricalMode.dc,
    sources: <SourceInstance>[
      SourceInstance(
        id: SourceId('s'),
        modelType: 'dc_voltage_source',
        terminals: <Terminal>[plus, minus],
        parameters: <String, Object?>{'voltageV': volts},
      ),
    ],
    components: <ComponentInstance>[
      ComponentInstance(
        id: ComponentId('m'),
        modelType: 'motor_dc',
        terminals: <Terminal>[a, b],
        parameters: <String, Object?>{
          ComponentParameterKeys.resistanceOhm: resistance,
          ComponentParameterKeys.motorBackEmfVPerRadS: 0.1,
          ComponentParameterKeys.motorTorqueNmPerA: 0.1,
          ComponentParameterKeys.motorInertiaKgM2: 0.01,
          ComponentParameterKeys.motorFrictionNmPerRadS: 0.002,
          ComponentParameterKeys.motorLoadTorqueNm: 0.0,
        },
      ),
    ],
    connections: <Connection>[
      Connection(
        id: ConnectionId('w-plus'),
        fromTerminalId: plus.id,
        toTerminalId: a.id,
      ),
      Connection(
        id: ConnectionId('w-minus'),
        fromTerminalId: b.id,
        toTerminalId: minus.id,
      ),
    ],
  );
}

void main() {
  test('PMDC: startup current is U/R; rotor starts at rest', () {
    final snapshot =
        const ElectroSimRuntimeEngine().evaluate(motorCircuit());
    expect(snapshot.solved, isTrue);
    expect(snapshot.dc.branch('component:m').currentA, closeTo(6.0, 1e-7));
    expect(snapshot.dc.branch('component:m').powerW, closeTo(144.0, 1e-6));
    expect(snapshot.motorAngularSpeedsRadS[ComponentId('m')], 0.0);
  });

  test('PMDC: current decreases as back-EMF and rotor speed increase', () {
    final controller = ElectroSimSimulationController(circuit: motorCircuit());
    addTearDown(controller.dispose);
    final ComponentId id = ComponentId('m');
    controller.advance(const Duration(seconds: 1));
    final double atOne = controller.snapshot.dc.branch('component:m').currentA!;
    final double rpmOne = controller.snapshot.motorAngularSpeedsRadS[id]!;
    expect(controller.snapshot.solved, isTrue);
    expect(atOne, closeTo(4.965517241, 0.005));
    expect(rpmOne, closeTo(41.37931, 0.1));
    for (var i = 0; i < 19; i++) {
      controller.advance(const Duration(seconds: 1));
    }
    final double atTwenty =
        controller.snapshot.dc.branch('component:m').currentA!;
    final double speedTwenty = controller.snapshot.motorAngularSpeedsRadS[id]!;
    expect(controller.snapshot.solved, isTrue);
    expect(speedTwenty, greaterThan(rpmOne));
    expect(speedTwenty, closeTo(133.33, 2.0));
    expect(atTwenty, lessThan(atOne));
    expect(atTwenty, closeTo(2.67, 0.3));
    expect(controller.simulatedTime, const Duration(seconds: 20));
    for (final double value in controller.snapshot.dc.kclResiduals.values) {
      expect(value.abs(), lessThan(1e-6));
    }
  });

  test('PMDC: pause/reset restores zero speed, no phantom motor energy', () {
    final controller = ElectroSimSimulationController(circuit: motorCircuit());
    addTearDown(controller.dispose);
    controller.advance(const Duration(seconds: 5));
    expect(controller.snapshot.motorAngularSpeedsRadS[ComponentId('m')]!, 
        greaterThan(0.0));
    controller.resetDynamics();
    expect(controller.snapshot.motorAngularSpeedsRadS[ComponentId('m')], 0.0);
    expect(controller.simulatedTime, Duration.zero);
    expect(controller.snapshot.dc.branch('component:m').currentA, 
        closeTo(6.0, 1e-7));
  });

  test('PMDC: invalid negative inertia is rejected by the solver', () {
    final CircuitState source = motorCircuit();
    final ComponentInstance original = source.components.single;
    final ComponentInstance invalid = ComponentInstance(
      id: original.id,
      modelType: original.modelType,
      terminals: original.terminals,
      parameters: <String, Object?>{
        ...original.parameters,
        ComponentParameterKeys.motorInertiaKgM2: -0.01,
      },
    );
    final CircuitState wrong = CircuitState(
      circuitId: source.circuitId,
      revision: 0,
      mode: source.mode,
      sources: source.sources,
      components: <ComponentInstance>[invalid],
      connections: source.connections,
    );
    final snapshot = const ElectroSimRuntimeEngine().evaluate(wrong);
    expect(snapshot.solved, isFalse);
  });
}
