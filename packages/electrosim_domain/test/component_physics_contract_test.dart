import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:test/test.dart';

void main() {
  test('every structural component model has one canonical physics contract', () {
    expect(CoreComponentPhysicsContracts.missingPhysicsContracts(), isEmpty);
  });

  test('lamp and breaker semantics are centralized', () {
    expect(
      CoreComponentPhysicsContracts.resolve('lamp')!.electricalLaw,
      ComponentElectricalLaw.resistive,
    );
    expect(
      CoreComponentPhysicsContracts.resolve('breaker_dc')!.controlLaw,
      ComponentControlLaw.protection,
    );
  });

  test('operating envelope derives bounded limits from nominal receiver data', () {
    final ComponentInstance lamp = ComponentInstance(
      id: ComponentId('lamp-1'),
      modelType: 'lamp',
      terminals: <Terminal>[
        Terminal(id: TerminalId('lamp-1-a'), name: 'A'),
        Terminal(id: TerminalId('lamp-1-b'), name: 'B'),
      ],
      parameters: <String, Object?>{
        ReceiverNominalRating.voltageKey: 24.0,
        ReceiverNominalRating.currentKey: 1.0,
        ReceiverNominalRating.powerKey: 24.0,
      },
    );
    final ComponentOperatingEnvelope envelope =
        ComponentOperatingEnvelope.fromComponent(lamp);
    expect(envelope.effectiveMaxVoltageV, closeTo(26.4, 1e-9));
    expect(envelope.effectiveMaxCurrentA, closeTo(1.25, 1e-9));
    expect(envelope.effectiveMaxPowerW, closeTo(30.0, 1e-9));
  });
}
