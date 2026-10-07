import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:electrosim_measurements/electrosim_measurements.dart';
import 'package:test/test.dart';

void main() {
  test('generic receiver stress fails severe 24 V lamp overvoltage open', () {
    final ComponentInstance lamp = ComponentInstance(
      id: ComponentId('lamp-1'),
      modelType: 'lamp',
      terminals: <Terminal>[
        Terminal(id: TerminalId('lamp-a'), name: 'A'),
        Terminal(id: TerminalId('lamp-b'), name: 'B'),
      ],
      parameters: <String, Object?>{
        'resistanceOhm': 24.0,
        ReceiverNominalRating.voltageKey: 24.0,
        ReceiverNominalRating.currentKey: 1.0,
        ReceiverNominalRating.powerKey: 24.0,
        ComponentParameterKeys.thermalWithstandSeconds: 0.5,
      },
    );
    final ComponentOperatingState operating = ComponentOperatingState(
      componentId: lamp.id,
      code: ComponentOperatingCode.overloaded,
      voltageV: 216.0,
      currentA: 9.0,
      powerW: 1944.0,
      warnings: const <OperatingWarning>[],
      evidenceIds: const <String>[],
    );

    final ComponentHealthState state = const ComponentHealthEngine().advance(
      component: lamp,
      operatingState: operating,
      elapsed: const Duration(milliseconds: 100),
    );

    expect(state.failedOpen, isTrue);
  });


  test('generic thermal exposure reports degraded state before destruction', () {
    final ComponentInstance receiver = ComponentInstance(
      id: ComponentId('receiver-degraded'),
      modelType: 'lamp',
      terminals: <Terminal>[
        Terminal(id: TerminalId('rd-a'), name: 'A'),
        Terminal(id: TerminalId('rd-b'), name: 'B'),
      ],
      parameters: <String, Object?>{
        'resistanceOhm': 24.0,
        ReceiverNominalRating.voltageKey: 24.0,
        ReceiverNominalRating.currentKey: 1.0,
        ReceiverNominalRating.powerKey: 24.0,
        ComponentParameterKeys.thermalWithstandSeconds: 1.0,
      },
    );
    final ComponentOperatingState operating = ComponentOperatingState(
      componentId: receiver.id,
      code: ComponentOperatingCode.overloaded,
      voltageV: 30.0,
      currentA: 1.25,
      powerW: 37.5,
      warnings: const <OperatingWarning>[],
      evidenceIds: const <String>[],
    );

    const ComponentHealthEngine engine = ComponentHealthEngine();
    final ComponentHealthState state = engine.advance(
      component: receiver,
      operatingState: operating,
      elapsed: const Duration(milliseconds: 400),
      previous: const ComponentHealthState(
        code: ComponentHealthCode.stressed,
        thermalExposure: 0.45,
        stressRatio: 1.25,
      ),
    );

    expect(state.code, ComponentHealthCode.degraded);
    expect(state.failedOpen, isFalse);
    expect(state.thermalExposure, greaterThanOrEqualTo(0.55));
  });
}
