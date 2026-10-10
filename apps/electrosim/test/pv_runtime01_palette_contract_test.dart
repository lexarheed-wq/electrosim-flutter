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

    final F9PaletteDefinition highVoltage = item('pv-array-high-voltage');
    expect(array.defaultParameters['mppVoltageV'], 54.0);
    expect(highVoltage.defaultParameters['mppVoltageV'], 360.0);
    expect(mppt.defaultParameters['controllerType'], 'mppt');
    expect(
      mppt.defaultParameters['maxPvInputVoltageV'],
      greaterThanOrEqualTo(
        highVoltage.defaultParameters['mppVoltageV'] as num,
      ),
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
    expect(
      pwm.defaultParameters['maxPvInputVoltageV'],
      greaterThanOrEqualTo(array.defaultParameters['mppVoltageV'] as num),
    );
    expect(
      pwm.defaultParameters['maxPvInputVoltageV'],
      lessThan(highVoltage.defaultParameters['mppVoltageV'] as num),
    );
    expect(
      inverter.defaultParameters['maxDcVoltageV'],
      greaterThanOrEqualTo(array.defaultParameters['mppVoltageV'] as num),
    );
    expect(
      inverter.defaultParameters['maxDcVoltageV'],
      lessThan(highVoltage.defaultParameters['mppVoltageV'] as num),
    );
  });
}
