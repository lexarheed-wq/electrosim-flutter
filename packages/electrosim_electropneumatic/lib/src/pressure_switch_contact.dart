import 'dc_coil_meter.dart';

/// R3 pressure-operated NO/NC contact with absolute-pressure thresholds,
/// mechanical hysteresis and optional response delay. No gauge pressure is
/// silently substituted for an absolute pressure.
final class PressureSwitchCalibration {
  PressureSwitchCalibration({
    required this.pickupPressureAbsPa,
    required this.dropoutPressureAbsPa,
    this.responseDelayS = 0,
    this.normallyOpen = true,
  }) {
    if (!pickupPressureAbsPa.isFinite ||
        !dropoutPressureAbsPa.isFinite ||
        !responseDelayS.isFinite ||
        dropoutPressureAbsPa <= 0 ||
        pickupPressureAbsPa <= dropoutPressureAbsPa ||
        responseDelayS < 0) {
      throw const ElectropneumaticRuntimeException(
        'invalid_pressure_contact_calibration',
        'Pressure switch needs valid rising/falling absolute pressure thresholds.',
      );
    }
  }

  final double pickupPressureAbsPa;
  final double dropoutPressureAbsPa;
  final double responseDelayS;
  final bool normallyOpen;
}

final class PressureSwitchSnapshot {
  const PressureSwitchSnapshot({
    required this.timeS,
    required this.actuated,
    this.pendingActuated,
    this.transitionDueS,
  });

  final double timeS;
  final bool actuated;
  final bool? pendingActuated;
  final double? transitionDueS;
}

/// Pure sensor state; the owning electrical circuit must still include and
/// solve a real NO or NC contact. A widget must never close it directly.
final class PressureSwitchContact {
  const PressureSwitchContact(this.calibration);

  final PressureSwitchCalibration calibration;

  PressureSwitchSnapshot observe(
    PressureSwitchSnapshot previous, {
    required double timeS,
    required double pressureAbsPa,
  }) {
    if (!timeS.isFinite ||
        timeS < previous.timeS ||
        !pressureAbsPa.isFinite ||
        pressureAbsPa <= 0) {
      throw const ElectropneumaticRuntimeException(
        'invalid_pressure_contact_observation',
        'Pressure and timestamp must be finite and time-monotonic.',
      );
    }
    final bool requested = previous.actuated
        ? pressureAbsPa > calibration.dropoutPressureAbsPa
        : pressureAbsPa >= calibration.pickupPressureAbsPa;
    if (requested == previous.actuated) {
      return PressureSwitchSnapshot(
        timeS: timeS,
        actuated: previous.actuated,
      );
    }
    final bool pending = previous.pendingActuated == requested;
    final double due = pending
        ? previous.transitionDueS!
        : timeS + calibration.responseDelayS;
    if (timeS >= due) {
      return PressureSwitchSnapshot(
        timeS: timeS,
        actuated: requested,
      );
    }
    return PressureSwitchSnapshot(
      timeS: timeS,
      actuated: previous.actuated,
      pendingActuated: requested,
      transitionDueS: due,
    );
  }

  bool isContactClosed(PressureSwitchSnapshot snapshot) =>
      calibration.normallyOpen ? snapshot.actuated : !snapshot.actuated;
}
