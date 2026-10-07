import 'dart:math' as math;

import 'package:electrosim_domain/electrosim_domain.dart';

import 'operating_state.dart';

enum ComponentHealthCode { normal, stressed, degraded, failedOpen }

final class ComponentHealthState {
  const ComponentHealthState({
    required this.code,
    required this.thermalExposure,
    required this.stressRatio,
  });

  const ComponentHealthState.normal()
    : code = ComponentHealthCode.normal,
      thermalExposure = 0.0,
      stressRatio = 0.0;

  final ComponentHealthCode code;
  final double thermalExposure;
  final double stressRatio;

  bool get failedOpen => code == ComponentHealthCode.failedOpen;
}

/// Generic bounded physical-stress engine shared by receiver families.
///
/// It does not contain lamp/motor/fan-specific branches. A component opts into
/// thermal stress through its canonical [ComponentPhysicsContract] and declares
/// its operating envelope through canonical rating keys.
final class ComponentHealthEngine {
  const ComponentHealthEngine({this.defaultThermalWithstandSeconds = 5.0});

  final double defaultThermalWithstandSeconds;

  ComponentHealthState advance({
    required ComponentInstance component,
    required ComponentOperatingState operatingState,
    required Duration elapsed,
    ComponentHealthState previous = const ComponentHealthState.normal(),
  }) {
    if (previous.failedOpen) return previous;
    if (elapsed.isNegative) {
      throw ArgumentError.value(elapsed, 'elapsed', 'Elapsed time cannot be negative.');
    }

    final ComponentPhysicsContract physics =
        CoreComponentPhysicsContracts.resolveComponent(component);
    if (!physics.canAccumulateThermalStress) {
      return const ComponentHealthState.normal();
    }

    final ComponentOperatingEnvelope envelope =
        ComponentOperatingEnvelope.fromComponent(component);
    final double stress = _stressRatio(envelope, operatingState);
    final double seconds =
        elapsed.inMicroseconds / Duration.microsecondsPerSecond;
    final double withstand =
        envelope.thermalWithstandSeconds ?? defaultThermalWithstandSeconds;

    double exposure = previous.thermalExposure;
    if (stress > 1.0) {
      // I²t-like growth: severe overvoltage/overcurrent destroys quickly while
      // small overloads remain time-dependent.
      final double heating = stress * stress - 1.0;
      exposure = math.min(1.0, exposure + seconds * heating / withstand);
    } else if (seconds > 0) {
      // Generic cooling is intentionally slower than heating.
      exposure = math.max(0.0, exposure - seconds / (withstand * 8.0));
    }

    if (exposure >= 1.0) {
      return ComponentHealthState(
        code: ComponentHealthCode.failedOpen,
        thermalExposure: 1.0,
        stressRatio: stress,
      );
    }
    return ComponentHealthState(
      code: exposure >= 0.55
          ? ComponentHealthCode.degraded
          : exposure > 0.0 || stress > 1.0
          ? ComponentHealthCode.stressed
          : ComponentHealthCode.normal,
      thermalExposure: exposure,
      stressRatio: stress,
    );
  }

  double _stressRatio(
    ComponentOperatingEnvelope envelope,
    ComponentOperatingState state,
  ) {
    double ratio = 0.0;
    final double? maxV = envelope.effectiveMaxVoltageV;
    final double? maxI = envelope.effectiveMaxCurrentA;
    final double? maxP = envelope.effectiveMaxPowerW;
    if (maxV != null && state.voltageV != null && state.voltageV!.isFinite) {
      ratio = math.max(ratio, state.voltageV!.abs() / maxV);
    }
    if (maxI != null && state.currentA != null && state.currentA!.isFinite) {
      ratio = math.max(ratio, state.currentA!.abs() / maxI);
    }
    if (maxP != null && state.powerW != null && state.powerW!.isFinite) {
      ratio = math.max(ratio, state.powerW!.abs() / maxP);
    }
    return ratio.isFinite ? ratio : 0.0;
  }
}
