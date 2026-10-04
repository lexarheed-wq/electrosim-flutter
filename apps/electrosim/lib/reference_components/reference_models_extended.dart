import 'dart:math' as math;


double _finitePositive(String name, double value) {
  if (!value.isFinite || value <= 0) {
    throw ArgumentError.value(value, name, 'Expected a finite positive value.');
  }
  return value;
}

double _elapsedSeconds(Duration elapsed) {
  if (elapsed.isNegative) throw ArgumentError('Negative simulated duration.');
  return elapsed.inMicroseconds / Duration.microsecondsPerSecond;
}

/// Generic educational fixed resistor.
final class FixedResistorModel {
  FixedResistorModel({double resistanceOhm = 100})
      : resistanceOhm = _finitePositive('resistanceOhm', resistanceOhm);

  final double resistanceOhm;

  double voltageDrop(double currentA) {
    if (!currentA.isFinite) throw ArgumentError('Invalid current.');
    return currentA * resistanceOhm;
  }

  double powerLoss(double currentA) {
    if (!currentA.isFinite) throw ArgumentError('Invalid current.');
    return currentA * currentA * resistanceOhm;
  }
}

/// Normally closed momentary push-button.
final class NormallyClosedPushButtonModel {
  NormallyClosedPushButtonModel({double contactResistanceOhm = .02})
      : contactResistanceOhm =
            _finitePositive('contactResistanceOhm', contactResistanceOhm);

  final double contactResistanceOhm;
  bool pressed = false;

  bool get conducting => !pressed;
  double get resistanceOhm =>
      conducting ? contactResistanceOhm : double.infinity;

  void press() => pressed = true;
  void release() => pressed = false;
}

/// Simple resistive 24 V buzzer model for pedagogical DC circuits.
final class BuzzerModel {
  BuzzerModel({
    double ratedVoltageV = 24,
    double ratedPowerW = 2,
  })  : ratedVoltageV = _finitePositive('ratedVoltageV', ratedVoltageV),
        ratedPowerW = _finitePositive('ratedPowerW', ratedPowerW);

  final double ratedVoltageV;
  final double ratedPowerW;

  double get resistanceOhm => ratedVoltageV * ratedVoltageV / ratedPowerW;

  double activityForVoltage(double voltageV) {
    if (!voltageV.isFinite) throw ArgumentError('Invalid voltage.');
    return (voltageV.abs() / ratedVoltageV).clamp(0.0, 1.0).toDouble();
  }
}

/// Generic educational cartridge fuse. The I²t law below is intentionally
/// simple and is not a manufacturer-certified time/current curve.
final class CartridgeFuseModel {
  CartridgeFuseModel({
    double ratedCurrentA = 1,
    double coldResistanceOhm = .05,
    double blowI2tA2s = 2,
  })  : ratedCurrentA = _finitePositive('ratedCurrentA', ratedCurrentA),
        coldResistanceOhm =
            _finitePositive('coldResistanceOhm', coldResistanceOhm),
        blowI2tA2s = _finitePositive('blowI2tA2s', blowI2tA2s);

  final double ratedCurrentA;
  final double coldResistanceOhm;
  final double blowI2tA2s;

  bool blown = false;
  double accumulatedI2t = 0;

  double get resistanceOhm =>
      blown ? double.infinity : coldResistanceOhm;

  void advance(double currentA, Duration elapsed) {
    if (!currentA.isFinite) throw ArgumentError('Invalid current.');
    final seconds = _elapsedSeconds(elapsed);
    if (seconds == 0 || blown) return;

    final absCurrent = currentA.abs();
    if (absCurrent <= ratedCurrentA) {
      accumulatedI2t = math.max(
        0,
        accumulatedI2t - seconds * ratedCurrentA * ratedCurrentA * .2,
      );
      return;
    }

    accumulatedI2t += absCurrent * absCurrent * seconds;
    if (accumulatedI2t >= blowI2tA2s) {
      blown = true;
    }
  }

  void replace() {
    blown = false;
    accumulatedI2t = 0;
  }
}

/// Simplified silicon diode parameters for solver integration.
final class SiliconDiodeModel {
  SiliconDiodeModel({
    double forwardVoltageV = .7,
    double onResistanceOhm = .05,
  })  : forwardVoltageV = _finitePositive('forwardVoltageV', forwardVoltageV),
        onResistanceOhm =
            _finitePositive('onResistanceOhm', onResistanceOhm);

  final double forwardVoltageV;
  final double onResistanceOhm;

  bool isForwardBiased(double anodeMinusCathodeV) {
    if (!anodeMinusCathodeV.isFinite) {
      throw ArgumentError('Invalid diode voltage.');
    }
    return anodeMinusCathodeV >= forwardVoltageV;
  }
}

/// Generic 24 V DC fan with first-order rotor inertia.
final class DcFanModel {
  DcFanModel({
    double ratedVoltageV = 24,
    double ratedPowerW = 5,
    double timeConstantSeconds = .25,
  })  : ratedVoltageV = _finitePositive('ratedVoltageV', ratedVoltageV),
        ratedPowerW = _finitePositive('ratedPowerW', ratedPowerW),
        timeConstantSeconds =
            _finitePositive('timeConstantSeconds', timeConstantSeconds);

  final double ratedVoltageV;
  final double ratedPowerW;
  final double timeConstantSeconds;
  double speedFraction = 0;

  double get runningResistanceOhm =>
      ratedVoltageV * ratedVoltageV / ratedPowerW;

  void advance(double voltageV, Duration elapsed) {
    if (!voltageV.isFinite) throw ArgumentError('Invalid voltage.');
    final seconds = _elapsedSeconds(elapsed);
    if (seconds == 0) return;
    final target =
        (voltageV.abs() / ratedVoltageV).clamp(0.0, 1.0).toDouble();
    final decay = math.exp(-seconds / timeConstantSeconds);
    speedFraction = target + (speedFraction - target) * decay;
  }

  void reset() => speedFraction = 0;
}

/// Generic brushed 24 V DC motor with visual rotor-speed state.
/// Electrical integration should be performed by ElectroSim's solver.
final class DcMotorReferenceModel {
  DcMotorReferenceModel({
    double ratedVoltageV = 24,
    double windingResistanceOhm = 6,
    double noLoadSpeedRpm = 3000,
    double mechanicalTimeConstantSeconds = .35,
  })  : ratedVoltageV = _finitePositive('ratedVoltageV', ratedVoltageV),
        windingResistanceOhm =
            _finitePositive('windingResistanceOhm', windingResistanceOhm),
        noLoadSpeedRpm =
            _finitePositive('noLoadSpeedRpm', noLoadSpeedRpm),
        mechanicalTimeConstantSeconds = _finitePositive(
          'mechanicalTimeConstantSeconds',
          mechanicalTimeConstantSeconds,
        );

  final double ratedVoltageV;
  final double windingResistanceOhm;
  final double noLoadSpeedRpm;
  final double mechanicalTimeConstantSeconds;
  double speedRpm = 0;

  void advance(double voltageV, Duration elapsed) {
    if (!voltageV.isFinite) throw ArgumentError('Invalid voltage.');
    final seconds = _elapsedSeconds(elapsed);
    if (seconds == 0) return;
    final target = (voltageV / ratedVoltageV)
        .clamp(-1.0, 1.0)
        .toDouble() * noLoadSpeedRpm;
    final decay = math.exp(-seconds / mechanicalTimeConstantSeconds);
    speedRpm = target + (speedRpm - target) * decay;
  }

  void reset() => speedRpm = 0;
}

/// Generic 24 V relay coil with pickup/release hysteresis.
final class RelayCoilModel {
  RelayCoilModel({
    double ratedVoltageV = 24,
    double coilResistanceOhm = 720,
    double pickupRatio = .75,
    double releaseRatio = .30,
  })  : ratedVoltageV = _finitePositive('ratedVoltageV', ratedVoltageV),
        coilResistanceOhm =
            _finitePositive('coilResistanceOhm', coilResistanceOhm),
        pickupRatio = _finitePositive('pickupRatio', pickupRatio),
        releaseRatio = _finitePositive('releaseRatio', releaseRatio) {
    if (pickupRatio <= releaseRatio || pickupRatio > 1 || releaseRatio >= 1) {
      throw ArgumentError('Invalid relay pickup/release ratios.');
    }
  }

  final double ratedVoltageV;
  final double coilResistanceOhm;
  final double pickupRatio;
  final double releaseRatio;
  bool energized = false;

  void updateVoltage(double voltageV) {
    if (!voltageV.isFinite) throw ArgumentError('Invalid voltage.');
    final ratio = voltageV.abs() / ratedVoltageV;
    if (!energized && ratio >= pickupRatio) {
      energized = true;
    } else if (energized && ratio <= releaseRatio) {
      energized = false;
    }
  }
}
