import 'package:flutter_test/flutter_test.dart';

import 'package:electrosim/reference_components/reference_models_extended.dart';
import 'package:electrosim/reference_components/reference_widgets_extended.dart';

void main() {
  test('eight extended devices keep distinct visual identities', () {
    final sizes = ExtendedReferenceDevice.values
        .map(ExtendedReferenceGeometry.designSizeFor)
        .toList(growable: false);
    expect(sizes.toSet().length, greaterThanOrEqualTo(7));
    expect(
      ExtendedReferenceGeometry.designSizeFor(
        ExtendedReferenceDevice.resistor,
      ).width,
      greaterThan(
        ExtendedReferenceGeometry.designSizeFor(
          ExtendedReferenceDevice.resistor,
        ).height,
      ),
    );
    expect(
      ExtendedReferenceGeometry.designSizeFor(
        ExtendedReferenceDevice.relayCoil,
      ).height,
      greaterThan(
        ExtendedReferenceGeometry.designSizeFor(
          ExtendedReferenceDevice.relayCoil,
        ).width,
      ),
    );
  });

  test('normally closed push button opens while pressed', () {
    final model = NormallyClosedPushButtonModel();
    expect(model.conducting, isTrue);
    model.press();
    expect(model.conducting, isFalse);
    model.release();
    expect(model.conducting, isTrue);
  });

  test('fuse can blow from accumulated I2t', () {
    final model = CartridgeFuseModel(ratedCurrentA: 1, blowI2tA2s: .02);
    model.advance(2, const Duration(milliseconds: 10));
    expect(model.blown, isTrue);
  });

  test('fan and motor evolve only with explicit simulated time', () {
    final fan = DcFanModel();
    final motor = DcMotorReferenceModel();
    fan.advance(24, Duration.zero);
    motor.advance(24, Duration.zero);
    expect(fan.speedFraction, 0);
    expect(motor.speedRpm, 0);
    fan.advance(24, const Duration(milliseconds: 250));
    motor.advance(24, const Duration(milliseconds: 350));
    expect(fan.speedFraction, greaterThan(0));
    expect(motor.speedRpm, greaterThan(0));
  });

  test('relay coil keeps pickup/release hysteresis', () {
    final model = RelayCoilModel();
    model.updateVoltage(19);
    expect(model.energized, isTrue);
    model.updateVoltage(10);
    expect(model.energized, isTrue);
    model.updateVoltage(6);
    expect(model.energized, isFalse);
  });
}
