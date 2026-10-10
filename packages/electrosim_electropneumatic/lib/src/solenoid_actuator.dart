import 'dc_coil_meter.dart';

/// Thresholds and timings must be calibrated, not inferred from symbol color.
final class Solenoid24vCalibration {
  Solenoid24vCalibration({
    this.nominalVoltageV = 24,
    this.pickupRatio = .8,
    this.dropRatio = .35,
    this.pickupDelayS = .02,
    this.releaseDelayS = .01,
  }) {
    if (!nominalVoltageV.isFinite ||
        nominalVoltageV <= 0 ||
        !pickupRatio.isFinite ||
        !dropRatio.isFinite ||
        pickupRatio <= dropRatio ||
        pickupRatio > 1 ||
        dropRatio < 0 ||
        !pickupDelayS.isFinite ||
        !releaseDelayS.isFinite ||
        pickupDelayS < 0 ||
        releaseDelayS < 0) {
      throw const ElectropneumaticRuntimeException(
        'invalid_coil_calibration',
        'Pickup/dropout voltage ratios and delays are invalid.',
      );
    }
  }

  final double nominalVoltageV;
  final double pickupRatio;
  final double dropRatio;
  final double pickupDelayS;
  final double releaseDelayS;

  double get pickupVoltageV => nominalVoltageV * pickupRatio;
  double get dropVoltageV => nominalVoltageV * dropRatio;
}

final class Solenoid24vSnapshot {
  const Solenoid24vSnapshot({
    required this.energized,
    required this.measuredVoltageV,
    this.pendingEnergized,
    this.transitionDueS,
  });

  final bool energized;
  final double measuredVoltageV;
  final bool? pendingEnergized;
  final double? transitionDueS;
}

/// 24 V pickup/dropout hysteresis and deterministic delays. No pressure
/// side-effects: removing coil voltage does not vent trapped compressed air.
final class Solenoid24vDynamics {
  const Solenoid24vDynamics(this.calibration);

  final Solenoid24vCalibration calibration;

  Solenoid24vSnapshot observe(
    Solenoid24vSnapshot previous, {
    required double nowS,
    required double measuredVoltageV,
  }) {
    if (!nowS.isFinite ||
        nowS < 0 ||
        !measuredVoltageV.isFinite ||
        measuredVoltageV < 0) {
      throw const ElectropneumaticRuntimeException(
        'invalid_observation',
        'Time and measured DC voltage must be finite and nonnegative.',
      );
    }
    final bool wantsEnergized = previous.energized
        ? measuredVoltageV > calibration.dropVoltageV
        : measuredVoltageV >= calibration.pickupVoltageV;
    if (wantsEnergized == previous.energized) {
      return Solenoid24vSnapshot(
        energized: previous.energized,
        measuredVoltageV: measuredVoltageV,
      );
    }
    final bool matchingPending = previous.pendingEnergized == wantsEnergized;
    final double dueS = matchingPending
        ? previous.transitionDueS!
        : nowS +
              (wantsEnergized
                  ? calibration.pickupDelayS
                  : calibration.releaseDelayS);
    if (nowS >= dueS) {
      return Solenoid24vSnapshot(
        energized: wantsEnergized,
        measuredVoltageV: measuredVoltageV,
      );
    }
    return Solenoid24vSnapshot(
      energized: previous.energized,
      measuredVoltageV: measuredVoltageV,
      pendingEnergized: wantsEnergized,
      transitionDueS: dueS,
    );
  }
}

/// Models the 5/2 spool's stable electrical actuation state only;
/// pneumatic port commutation and full spool mechanics belong to R3/B.
enum ValveSpoolSide { springSide, coilSide }

enum ValveReturnKind { monostableSpring, bistableMemory }

final class SingleCoilValveMemory {
  const SingleCoilValveMemory({required this.returnKind});

  final ValveReturnKind returnKind;

  ValveSpoolSide update({
    required ValveSpoolSide previous,
    required bool coilEnergized,
  }) {
    if (coilEnergized) return ValveSpoolSide.coilSide;
    return returnKind == ValveReturnKind.monostableSpring
        ? ValveSpoolSide.springSide
        : previous;
  }
}

/// A paired-coil bistable valve must not receive contradictory commands.
final class DualCoilBistableMemory {
  const DualCoilBistableMemory();

  ValveSpoolSide update({
    required ValveSpoolSide previous,
    required bool coilToSpring,
    required bool coilToActuated,
  }) {
    if (coilToSpring && coilToActuated) {
      throw const ElectropneumaticRuntimeException(
        'opposing_solenoids',
        'Two opposing 5/2 coils may not be energized simultaneously.',
      );
    }
    if (coilToSpring) return ValveSpoolSide.springSide;
    if (coilToActuated) return ValveSpoolSide.coilSide;
    return previous;
  }
}

/// A contact changes its electrical state only when mechanical position
/// crosses a real, hysteretic switching band.
final class PositionEndContact {
  PositionEndContact({
    required this.strokeM,
    required this.triggerPositionM,
    required this.releasePositionM,
    required this.normallyOpen,
  }) {
    if (!strokeM.isFinite ||
        strokeM <= 0 ||
        !triggerPositionM.isFinite ||
        !releasePositionM.isFinite ||
        releasePositionM < 0 ||
        triggerPositionM > strokeM ||
        triggerPositionM <= releasePositionM) {
      throw const ElectropneumaticRuntimeException(
        'invalid_sensor_calibration',
        'Position sensor hysteresis must be within the cylinder stroke.',
      );
    }
  }

  final double strokeM;
  final double triggerPositionM;
  final double releasePositionM;
  final bool normallyOpen;

  bool actuated({required bool previouslyActuated, required double positionM}) {
    if (!positionM.isFinite || positionM < 0 || positionM > strokeM) {
      throw const ElectropneumaticRuntimeException(
        'invalid_position',
        'Cylinder position must stay within its travel.',
      );
    }
    if (previouslyActuated) return positionM > releasePositionM;
    return positionM >= triggerPositionM;
  }

  bool closed(bool physicalActuation) =>
      normallyOpen ? physicalActuation : !physicalActuation;
}
