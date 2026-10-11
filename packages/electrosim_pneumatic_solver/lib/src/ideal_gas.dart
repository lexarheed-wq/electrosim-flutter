import 'dart:math' as math;

/// R2-A: generic, quasi-steady isentropic nozzle, NOT ISO 6358 certification.
/// All pressures are absolute Pa, areas m², temperatures K, flows kg/s.
final class PneumaticPhysicsException implements Exception {
  const PneumaticPhysicsException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => 'PneumaticPhysicsException($code): $message';
}

void requirePositiveFinite(double value, String name) {
  if (!value.isFinite || value <= 0) {
    throw PneumaticPhysicsException(
      'invalid_physical_value',
      '$name must be finite and greater than zero.',
    );
  }
}

void requireNonnegativeFinite(double value, String name) {
  if (!value.isFinite || value < 0) {
    throw PneumaticPhysicsException(
      'invalid_physical_value',
      '$name must be finite and nonnegative.',
    );
  }
}

abstract final class DryAirReference {
  static const double specificGasConstantJPerKgK = 287.05;
  static const double gamma = 1.4;
  static const double temperatureK = 293.15;
  static const double atmosphericPressurePa = 101325;
  static const double normalizedTemperatureK = 273.15;
  static const double normalizedPressurePa = 101325;
}

/// Reversible orifice. Positive flow moves from first port to second.
/// The donor's temperature is used in both flow directions.
final class IsentropicOrifice {
  IsentropicOrifice({
    required this.effectiveAreaM2,
    required this.dischargeCoefficient,
    this.gamma = DryAirReference.gamma,
    this.gasConstantJPerKgK = DryAirReference.specificGasConstantJPerKgK,
  }) {
    requirePositiveFinite(effectiveAreaM2, 'effectiveAreaM2');
    requirePositiveFinite(dischargeCoefficient, 'dischargeCoefficient');
    if (dischargeCoefficient > 1) {
      throw const PneumaticPhysicsException(
        'invalid_discharge_coefficient',
        'Discharge coefficient Cd must not exceed one.',
      );
    }
    requirePositiveFinite(gasConstantJPerKgK, 'gasConstantJPerKgK');
    if (!gamma.isFinite || gamma <= 1) {
      throw const PneumaticPhysicsException(
        'invalid_gamma',
        'Isentropic exponent gamma must be finite and greater than one.',
      );
    }
  }

  final double effectiveAreaM2;
  final double dischargeCoefficient;
  final double gamma;
  final double gasConstantJPerKgK;

  double get criticalDownstreamUpstreamRatio =>
      math.pow(2 / (gamma + 1), gamma / (gamma - 1)).toDouble();

  double massFlowKgPerS({
    required double fromPressureAbsPa,
    required double toPressureAbsPa,
    double temperatureK = DryAirReference.temperatureK,
  }) {
    requirePositiveFinite(fromPressureAbsPa, 'fromPressureAbsPa');
    requirePositiveFinite(toPressureAbsPa, 'toPressureAbsPa');
    requirePositiveFinite(temperatureK, 'temperatureK');
    if (fromPressureAbsPa == toPressureAbsPa) return 0;

    final bool forward = fromPressureAbsPa > toPressureAbsPa;
    final double upstream = forward ? fromPressureAbsPa : toPressureAbsPa;
    final double downstream = forward ? toPressureAbsPa : fromPressureAbsPa;
    final double ratio = downstream / upstream;
    final double critical = criticalDownstreamUpstreamRatio;

    final double velocityFactor;
    if (ratio <= critical) {
      velocityFactor =
          math.sqrt(gamma / (gasConstantJPerKgK * temperatureK)) *
          math.pow(2 / (gamma + 1), (gamma + 1) / (2 * (gamma - 1))).toDouble();
    } else {
      final double exponents =
          math.pow(ratio, 2 / gamma).toDouble() -
          math.pow(ratio, (gamma + 1) / gamma).toDouble();
      if (exponents < 0) {
        throw const PneumaticPhysicsException(
          'unphysical_mass_flow',
          'Negative isentropic flow discriminant.',
        );
      }
      velocityFactor = math.sqrt(
        2 *
            gamma *
            exponents /
            (gasConstantJPerKgK * temperatureK * (gamma - 1)),
      );
    }

    final double result =
        dischargeCoefficient * effectiveAreaM2 * upstream * velocityFactor;
    if (!result.isFinite || result < 0) {
      throw const PneumaticPhysicsException(
        'nonfinite_mass_flow',
        'Computed flow is non-finite or negative.',
      );
    }
    return forward ? result : -result;
  }

  double normalizedLitresPerMinute(double massFlowKgPerS) {
    if (!massFlowKgPerS.isFinite) {
      throw const PneumaticPhysicsException(
        'nonfinite_mass_flow',
        'Mass flow must be finite.',
      );
    }
    return massFlowKgPerS *
        gasConstantJPerKgK *
        DryAirReference.normalizedTemperatureK /
        DryAirReference.normalizedPressurePa *
        60000;
  }
}

/// Isothermal ideal-gas law P*V=m*R*T (P absolute).
abstract final class IsothermalAir {
  static double massKg({
    required double pressureAbsPa,
    required double volumeM3,
    double temperatureK = DryAirReference.temperatureK,
  }) {
    requirePositiveFinite(pressureAbsPa, 'pressureAbsPa');
    requirePositiveFinite(volumeM3, 'volumeM3');
    requirePositiveFinite(temperatureK, 'temperatureK');
    return pressureAbsPa *
        volumeM3 /
        (DryAirReference.specificGasConstantJPerKgK * temperatureK);
  }

  static double pressureAbsPa({
    required double massKg,
    required double volumeM3,
    double temperatureK = DryAirReference.temperatureK,
  }) {
    requirePositiveFinite(massKg, 'massKg');
    requirePositiveFinite(volumeM3, 'volumeM3');
    requirePositiveFinite(temperatureK, 'temperatureK');
    return massKg *
        DryAirReference.specificGasConstantJPerKgK *
        temperatureK /
        volumeM3;
  }

  static double pressureGaugePa(double pressureAbsPa) {
    requirePositiveFinite(pressureAbsPa, 'pressureAbsPa');
    return pressureAbsPa - DryAirReference.atmosphericPressurePa;
  }
}
