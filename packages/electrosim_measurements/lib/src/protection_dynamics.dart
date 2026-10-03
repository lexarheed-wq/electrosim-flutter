import 'dart:math' as math;

import 'package:electrosim_domain/electrosim_domain.dart';

enum ProtectionCurveFamily { breaker, fuse, thermal, motor }
enum ProtectionTripCurve { b, c, d, fuse, thermal, motor }
enum ProtectionZone { normal, thermalTimed, magneticFast, magneticInstantaneous }

final class ProtectionProfile {
  const ProtectionProfile({
    required this.family,
    required this.curve,
    required this.magneticLowMultiple,
    required this.magneticHighMultiple,
  });

  final ProtectionCurveFamily family;
  final ProtectionTripCurve curve;
  final double magneticLowMultiple;
  final double magneticHighMultiple;
}

final class ProtectionExposureState {
  const ProtectionExposureState({
    required this.exposure,
    required this.ratio,
    required this.tripTimeSeconds,
    required this.zone,
  });

  const ProtectionExposureState.zero()
      : exposure = 0.0,
        ratio = 0.0,
        tripTimeSeconds = double.infinity,
        zone = ProtectionZone.normal;

  final double exposure;
  final double ratio;
  final double tripTimeSeconds;
  final ProtectionZone zone;

  bool get shouldTrip => exposure >= 1.0;
}

/// Pure protection dynamics. It never mutates CircuitState.
///
/// The time-current approximation mirrors the validated pedagogical V1
/// behavior while using canonical V2 ratings and immutable state.
final class ProtectionDynamicsEngine {
  const ProtectionDynamicsEngine();

  ProtectionProfile profile(ComponentInstance component) {
    final String model = component.modelType.toLowerCase();
    if (model.contains('thermal_overload')) {
      return const ProtectionProfile(
        family: ProtectionCurveFamily.thermal,
        curve: ProtectionTripCurve.thermal,
        magneticLowMultiple: double.infinity,
        magneticHighMultiple: double.infinity,
      );
    }
    if (model.contains('fuse')) {
      return const ProtectionProfile(
        family: ProtectionCurveFamily.fuse,
        curve: ProtectionTripCurve.fuse,
        magneticLowMultiple: 5.0,
        magneticHighMultiple: 10.0,
      );
    }
    if (model.contains('motor_protection')) {
      final double high = _positive(
            component.parameters['magneticMultiple'],
          ) ??
          10.0;
      return ProtectionProfile(
        family: ProtectionCurveFamily.motor,
        curve: ProtectionTripCurve.motor,
        magneticLowMultiple: math.max(5.0, high * 0.75),
        magneticHighMultiple: math.max(6.0, high),
      );
    }

    final String rawCurve =
        (component.parameters['tripCurve'] as String? ?? 'C').toUpperCase();
    return switch (rawCurve) {
      'B' => const ProtectionProfile(
          family: ProtectionCurveFamily.breaker,
          curve: ProtectionTripCurve.b,
          magneticLowMultiple: 3.0,
          magneticHighMultiple: 5.0,
        ),
      'D' => const ProtectionProfile(
          family: ProtectionCurveFamily.breaker,
          curve: ProtectionTripCurve.d,
          magneticLowMultiple: 10.0,
          magneticHighMultiple: 20.0,
        ),
      _ => const ProtectionProfile(
          family: ProtectionCurveFamily.breaker,
          curve: ProtectionTripCurve.c,
          magneticLowMultiple: 5.0,
          magneticHighMultiple: 10.0,
        ),
    };
  }

  double? ratedCurrentA(ComponentInstance component) {
    final Object? raw = component.parameters[ProtectionRating.ratedCurrentKey];
    return raw is num && raw.toDouble().isFinite && raw.toDouble() > 0
        ? raw.toDouble()
        : null;
  }

  double tripTimeSeconds(ComponentInstance component, double currentA) {
    final double? rated = ratedCurrentA(component);
    if (rated == null || !currentA.isFinite) return double.infinity;
    final double ratio = currentA.abs() / rated;
    return tripTimeForRatio(profile(component), ratio);
  }

  double tripTimeForRatio(ProtectionProfile profile, double rawRatio) {
    final double ratio = math.max(0.0, rawRatio.isFinite ? rawRatio : 0.0);
    if (profile.curve == ProtectionTripCurve.thermal) {
      if (ratio < 1.05) return double.infinity;
      if (ratio < 1.2) return _logInterp(ratio, 1.05, 14400, 1.2, 7200);
      if (ratio < 1.5) return _logInterp(ratio, 1.2, 7200, 1.5, 600);
      if (ratio < 2) return _logInterp(ratio, 1.5, 600, 2, 120);
      if (ratio < 4) return _logInterp(ratio, 2, 120, 4, 20);
      if (ratio < 7.2) return _logInterp(ratio, 4, 20, 7.2, 8);
      return math.max(2.0, 8.0 * (7.2 / math.max(7.2, ratio)));
    }
    if (profile.curve == ProtectionTripCurve.fuse) {
      if (ratio < 1.10) return double.infinity;
      if (ratio < 1.25) return _logInterp(ratio, 1.10, 7200, 1.25, 3600);
      if (ratio < 1.6) return _logInterp(ratio, 1.25, 3600, 1.6, 600);
      if (ratio < 2) return _logInterp(ratio, 1.6, 600, 2, 60);
      if (ratio < 5) return _logInterp(ratio, 2, 60, 5, 1);
      if (ratio < 10) return _logInterp(ratio, 5, 1, 10, 0.1);
      return 0.02;
    }

    if (ratio < 1.13) return double.infinity;
    if (ratio < 1.45) return _logInterp(ratio, 1.13, 7200, 1.45, 3600);
    if (ratio < 2.55) return _logInterp(ratio, 1.45, 3600, 2.55, 60);
    if (ratio < profile.magneticLowMultiple) {
      return _logInterp(
        ratio,
        2.55,
        60,
        profile.magneticLowMultiple,
        2,
      );
    }
    if (ratio < profile.magneticHighMultiple) return 0.10;
    return 0.02;
  }

  ProtectionZone zone(ComponentInstance component, double currentA) {
    final double? rated = ratedCurrentA(component);
    if (rated == null || !currentA.isFinite) return ProtectionZone.normal;
    final double ratio = currentA.abs() / rated;
    final ProtectionProfile p = profile(component);
    final double tripTime = tripTimeForRatio(p, ratio);
    if (ratio < 1.05 || !tripTime.isFinite) return ProtectionZone.normal;
    if (p.magneticLowMultiple.isFinite && ratio >= p.magneticLowMultiple) {
      return ratio >= p.magneticHighMultiple
          ? ProtectionZone.magneticInstantaneous
          : ProtectionZone.magneticFast;
    }
    return ProtectionZone.thermalTimed;
  }

  bool shouldOpenInstantaneously(
    ComponentInstance component,
    double currentA,
  ) {
    final double? rated = ratedCurrentA(component);
    if (rated == null || !currentA.isFinite) return false;
    final ProtectionProfile p = profile(component);
    if (!p.magneticHighMultiple.isFinite) return false;
    return currentA.abs() >= rated * p.magneticHighMultiple - 1e-9;
  }

  ProtectionExposureState advance({
    required ComponentInstance component,
    required double currentA,
    required Duration elapsed,
    ProtectionExposureState previous = const ProtectionExposureState.zero(),
  }) {
    final double? rated = ratedCurrentA(component);
    if (rated == null || !currentA.isFinite || elapsed.isNegative) {
      return previous;
    }
    final double ratio = currentA.abs() / rated;
    final ProtectionProfile p = profile(component);
    final double tripTime = tripTimeForRatio(p, ratio);
    final ProtectionZone z = zone(component, currentA);
    final double seconds = elapsed.inMicroseconds / Duration.microsecondsPerSecond;
    double exposure = previous.exposure;

    if (tripTime.isFinite && tripTime > 0) {
      exposure = math.min(1.0, exposure + seconds / tripTime);
    } else {
      final double coolSeconds =
          p.curve == ProtectionTripCurve.thermal ? 900.0 : 300.0;
      exposure = math.max(0.0, exposure - seconds / coolSeconds);
    }

    return ProtectionExposureState(
      exposure: exposure,
      ratio: ratio,
      tripTimeSeconds: tripTime,
      zone: z,
    );
  }
}

double _logInterp(
  double x,
  double x1,
  double y1,
  double x2,
  double y2,
) {
  if (x <= x1) return y1;
  if (x >= x2) return y2;
  final double t = (x - x1) / (x2 - x1);
  return math.exp(math.log(y1) + (math.log(y2) - math.log(y1)) * t);
}

double? _positive(Object? raw) {
  if (raw is! num) return null;
  final double value = raw.toDouble();
  return value.isFinite && value > 0 ? value : null;
}
