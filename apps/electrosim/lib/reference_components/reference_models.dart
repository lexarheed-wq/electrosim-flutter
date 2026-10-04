import 'dart:math' as math;

// Generic educational models, not manufacturer-certified devices.
// All currents passed to the thermal models are in amperes.
// Time advances only through explicit simulated durations.
double _positive(String name, double value) {
  if (!value.isFinite || value <= 0) {
    throw ArgumentError.value(value, name, 'Expected a finite positive value.');
  }
  return value;
}

double _seconds(Duration elapsed) {
  if (elapsed.isNegative) throw ArgumentError('Negative simulated duration.');
  return elapsed.inMicroseconds / Duration.microsecondsPerSecond;
}

enum SupplyMode { off, constantVoltage, constantCurrent }

final class SupplyReading {
  const SupplyReading(this.voltageV, this.currentA, this.mode);
  final double voltageV;
  final double currentA;
  final SupplyMode mode;
}

final class LabSupplyModel {
  LabSupplyModel({
    double voltageV = 24,
    double currentLimitA = 2,
    double internalResistanceOhm = .05,
    this.enabled = true,
  }) : _voltageV = _positive('voltageV', voltageV),
       _currentLimitA = _positive('currentLimitA', currentLimitA),
       internalResistanceOhm =
           _positive('internalResistanceOhm', internalResistanceOhm);

  double _voltageV;
  double _currentLimitA;
  final double internalResistanceOhm;
  bool enabled;
  double get voltageV => _voltageV;
  double get currentLimitA => _currentLimitA;
  set voltageV(double value) => _voltageV = _positive('voltageV', value);
  set currentLimitA(double value) =>
      _currentLimitA = _positive('currentLimitA', value);

  // Exact for a passive resistive load at this instant. In a general network,
  // stamp the source's series resistance and CV/CC equations into the solver.
  SupplyReading solveResistiveLoad(double loadResistanceOhm) {
    if (loadResistanceOhm.isNaN || loadResistanceOhm < 0) {
      throw ArgumentError('Load resistance must be non-negative.');
    }
    if (!enabled) return const SupplyReading(0, 0, SupplyMode.off);
    if (loadResistanceOhm == double.infinity) {
      return SupplyReading(voltageV, 0, SupplyMode.constantVoltage);
    }
    final requested = voltageV /
        (loadResistanceOhm + internalResistanceOhm);
    if (requested > currentLimitA) {
      return SupplyReading(
        currentLimitA * loadResistanceOhm,
        currentLimitA,
        SupplyMode.constantCurrent,
      );
    }
    return SupplyReading(
      requested * loadResistanceOhm,
      requested,
      SupplyMode.constantVoltage,
    );
  }
}

class SwitchModel {
  SwitchModel({double contactResistanceOhm = .02, this.closed = false})
      : contactResistanceOhm =
            _positive('contactResistanceOhm', contactResistanceOhm);
  final double contactResistanceOhm;
  bool closed;
  double get resistanceOhm =>
      closed ? contactResistanceOhm : double.infinity;
}

final class PushButtonModel extends SwitchModel {
  PushButtonModel({super.contactResistanceOhm});
  bool get pressed => closed;
  void press() => closed = true;
  void release() => closed = false;
}

enum TripCause { none, thermal, magnetic }

final class DcBreakerModel {
  DcBreakerModel({
    double ratedCurrentA = 1,
    double contactResistanceOhm = .03,
    double magneticMultiple = 8,
    double coolingTimeSeconds = 30,
    this.closed = true,
  }) : _ratedCurrentA = _positive('ratedCurrentA', ratedCurrentA),
       contactResistanceOhm =
           _positive('contactResistanceOhm', contactResistanceOhm),
       magneticMultiple = _positive('magneticMultiple', magneticMultiple),
       coolingTimeSeconds =
           _positive('coolingTimeSeconds', coolingTimeSeconds) {
    if (magneticMultiple <= 1) {
      throw ArgumentError('Magnetic multiple must exceed 1.');
    }
  }

  double _ratedCurrentA;
  final double contactResistanceOhm;
  final double magneticMultiple;
  final double coolingTimeSeconds;
  bool closed;
  bool _tripped = false;
  double _exposure = 0;
  TripCause _cause = TripCause.none;
  double get ratedCurrentA => _ratedCurrentA;
  set ratedCurrentA(double value) =>
      _ratedCurrentA = _positive('ratedCurrentA', value);
  bool get tripped => _tripped;
  double get exposure => _exposure;
  TripCause get cause => _cause;
  bool get conducting => closed && !tripped;
  double get resistanceOhm =>
      conducting ? contactResistanceOhm : double.infinity;
  bool get canRearm => tripped && exposure <= .2;

  void advance(double currentA, Duration elapsed) {
    if (!currentA.isFinite) throw ArgumentError('Invalid current.');
    final seconds = _seconds(elapsed);
    if (seconds == 0) return;
    if (!conducting) {
      _exposure *= math.exp(-seconds / coolingTimeSeconds);
      return;
    }
    final ratio = currentA.abs() / ratedCurrentA;
    if (ratio >= magneticMultiple) {
      _trip(TripCause.magnetic);
    } else if (ratio > 1) {
      // Nominal pedagogical time/current curve, not a certified B/C/D curve.
      _exposure = math.min(1.0, _exposure + seconds * (ratio * ratio - 1) / 20);
      if (_exposure >= 1) _trip(TripCause.thermal);
    } else {
      _exposure *= math.exp(-seconds / coolingTimeSeconds);
    }
  }

  void _trip(TripCause cause) {
    _tripped = true;
    closed = false;
    _cause = cause;
    _exposure = 1;
  }

  bool rearm() {
    if (!canRearm) return false;
    _tripped = false;
    _cause = TripCause.none;
    closed = true;
    return true;
  }
}

final class FilamentLampModel {
  FilamentLampModel({
    double ratedVoltageV = 24,
    double ratedPowerW = 10,
    double ambientK = 293.15,
    double nominalTemperatureK = 2700,
    double alphaPerK = .0045,
    double heatCapacityJPerK = .002,
    double maximumTemperatureK = 3200,
  }) : ratedVoltageV = _positive('ratedVoltageV', ratedVoltageV),
       ratedPowerW = _positive('ratedPowerW', ratedPowerW),
       ambientK = _positive('ambientK', ambientK),
       nominalTemperatureK =
           _positive('nominalTemperatureK', nominalTemperatureK),
       alphaPerK = _positive('alphaPerK', alphaPerK),
       heatCapacityJPerK = _positive('heatCapacityJPerK', heatCapacityJPerK),
       maximumTemperatureK =
           _positive('maximumTemperatureK', maximumTemperatureK),
       _temperatureK = ambientK {
    if (nominalTemperatureK <= ambientK ||
        maximumTemperatureK <= nominalTemperatureK) {
      throw ArgumentError('Invalid thermal temperature range.');
    }
  }

  final double ratedVoltageV;
  final double ratedPowerW;
  final double ambientK;
  final double nominalTemperatureK;
  final double alphaPerK;
  final double heatCapacityJPerK;
  final double maximumTemperatureK;
  double _temperatureK;
  double get temperatureK => _temperatureK;
  double get nominalResistanceOhm => ratedVoltageV * ratedVoltageV / ratedPowerW;
  double get coldResistanceOhm => nominalResistanceOhm /
      (1 + alphaPerK * (nominalTemperatureK - ambientK));
  double get resistanceOhm => coldResistanceOhm *
      (1 + alphaPerK * (temperatureK - ambientK));
  double get thermalConductanceWPerK =>
      ratedPowerW / (nominalTemperatureK - ambientK);
  double get brightness => math.pow(
    ((temperatureK - ambientK) / (nominalTemperatureK - ambientK))
        .clamp(0.0, 1.0), 4,
  ).toDouble();

  // Power is held constant during this small physical step. Re-solve the
  // network between steps; a single large step cannot model the inrush.
  void advance(double currentA, Duration elapsed) {
    if (!currentA.isFinite) throw ArgumentError('Invalid current.');
    final seconds = _seconds(elapsed);
    if (seconds == 0) return;
    if (seconds > .005) throw ArgumentError('Lamp step must be <= 5 ms.');
    final power = currentA * currentA * resistanceOhm;
    final conductance = thermalConductanceWPerK;
    final equilibrium = ambientK + power / conductance;
    final decay = math.exp(-conductance * seconds / heatCapacityJPerK);
    final next = equilibrium + (temperatureK - equilibrium) * decay;
    if (!next.isFinite || next < ambientK - 1e-9 ||
        next > maximumTemperatureK) {
      throw StateError('Lamp model outside its published temperature range.');
    }
    _temperatureK = math.max(ambientK, next);
  }

  void reset() => _temperatureK = ambientK;
}

// Demonstration network only: the five devices wired in series.
// For arbitrary ElectroSim circuits, integrate the models with its DC solver.
final class ReferenceSeriesCircuit {
  final supply = LabSupplyModel();
  final breaker = DcBreakerModel();
  final toggle = SwitchModel();
  final button = PushButtonModel();
  final lamp = FilamentLampModel();
  Duration simulatedTime = Duration.zero;

  SupplyReading get reading {
    if (!breaker.conducting || !toggle.closed || !button.pressed) {
      return supply.solveResistiveLoad(double.infinity);
    }
    return supply.solveResistiveLoad(
      breaker.resistanceOhm + toggle.resistanceOhm +
      button.resistanceOhm + lamp.resistanceOhm,
    );
  }

  void advance(Duration elapsed) {
    _seconds(elapsed);
    if (elapsed > const Duration(seconds: 60)) {
      throw ArgumentError('Advance at most 60 simulated seconds per call.');
    }
    var remaining = elapsed.inMicroseconds;
    while (remaining > 0) {
      final microseconds = remaining < 1000 ? remaining : 1000;
      final step = Duration(microseconds: microseconds);
      final before = reading;
      breaker.advance(before.currentA, step);
      // Once the breaker opens, the final network current is zero.
      lamp.advance(reading.currentA, step);
      simulatedTime += step;
      remaining -= microseconds;
    }
  }
}
