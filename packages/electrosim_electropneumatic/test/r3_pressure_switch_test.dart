import 'package:electrosim_electropneumatic/electrosim_electropneumatic.dart';
import 'package:test/test.dart';

void main() {
  final PressureSwitchCalibration c = PressureSwitchCalibration(
    pickupPressureAbsPa: 501325,
    dropoutPressureAbsPa: 451325,
    responseDelayS: .01,
    normallyOpen: false,
  );
  const PressureSwitchSnapshot start = PressureSwitchSnapshot(
    timeS: 0,
    actuated: false,
  );

  test('R3/E: NC pressure switch opens only after pickup delay', () {
    final PressureSwitchContact sensor = PressureSwitchContact(c);
    expect(sensor.isContactClosed(start), isTrue);
    final PressureSwitchSnapshot pending = sensor.observe(
      start,
      timeS: .1,
      pressureAbsPa: 551325,
    );
    expect(pending.actuated, isFalse);
    expect(pending.transitionDueS, closeTo(.11, 1e-12));

    final PressureSwitchSnapshot engaged = sensor.observe(
      pending,
      timeS: .11,
      pressureAbsPa: 551325,
    );
    expect(engaged.actuated, isTrue);
    expect(sensor.isContactClosed(engaged), isFalse);

    final PressureSwitchSnapshot held = sensor.observe(
      engaged,
      timeS: .12,
      pressureAbsPa: 476325,
    );
    expect(held.actuated, isTrue);
    expect(held.transitionDueS, isNull);
  });

  test('R3/E: hysteretic dropout cancels a pending opposite transition', () {
    final PressureSwitchContact sensor = PressureSwitchContact(c);
    final PressureSwitchSnapshot pending = sensor.observe(
      start,
      timeS: 1,
      pressureAbsPa: 551325,
    );
    final PressureSwitchSnapshot cancelled = sensor.observe(
      pending,
      timeS: 1.005,
      pressureAbsPa: 401325,
    );
    expect(cancelled.actuated, isFalse);
    expect(cancelled.pendingActuated, isNull);
    expect(cancelled.transitionDueS, isNull);
    expect(sensor.isContactClosed(cancelled), isTrue);
  });

  test('R3/E: non-monotonic clock and invalid calibration are refused', () {
    final PressureSwitchContact sensor = PressureSwitchContact(c);
    expect(
      () => sensor.observe(
        const PressureSwitchSnapshot(timeS: 5, actuated: false),
        timeS: 4,
        pressureAbsPa: 551325,
      ),
      throwsA(isA<ElectropneumaticRuntimeException>()),
    );
    expect(
      () => PressureSwitchCalibration(
        pickupPressureAbsPa: 350000,
        dropoutPressureAbsPa: 400000,
      ),
      throwsA(isA<ElectropneumaticRuntimeException>()),
    );
  });
}
