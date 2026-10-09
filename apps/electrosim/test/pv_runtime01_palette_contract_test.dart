import 'package:electrosim/f9_component_palette.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('PV-RUNTIME01 default 48 V storage chain components are compatible', () {
    F9PaletteDefinition item(String key) => f9PaletteCatalog.singleWhere(
      (F9PaletteDefinition value) => value.keyName == key,
    );

    final F9PaletteDefinition array = item('pv-array');
    final F9PaletteDefinition mppt = item('pv-controller-mppt');
    final F9PaletteDefinition pwm = item('pv-controller-pwm');
    final F9PaletteDefinition battery = item('pv-battery');
    final F9PaletteDefinition inverter = item('pv-inverter');

    expect(array.defaultParameters['mppVoltageV'], 360.0);
    expect(mppt.defaultParameters['controllerType'], 'mppt');
    expect(
      mppt.defaultParameters['maxPvInputVoltageV'],
      greaterThanOrEqualTo(360.0),
    );
    expect(mppt.defaultParameters['outputVoltageV'], 48.0);
    expect(battery.defaultParameters['nominalVoltageV'], 48.0);
    expect(
      inverter.defaultParameters['minDcVoltageV'],
      lessThanOrEqualTo(48.0),
    );
    expect(
      inverter.defaultParameters['maxDcVoltageV'],
      greaterThanOrEqualTo(48.0),
    );

    expect(pwm.defaultParameters['controllerType'], 'pwm');
    expect(pwm.defaultParameters['maxPvInputVoltageV'], lessThan(360.0));
  });
}
