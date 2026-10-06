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
}
