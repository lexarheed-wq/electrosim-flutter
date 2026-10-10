import 'dart:math' as math;
import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:electrosim_solver_ac/electrosim_solver_ac.dart';
import 'electrosim_runtime_engine.dart';

/// Continuous angle: changing speed changes its derivative, never its position.
final class RotorPhase {
  double _turns = 0;
  double? _seconds;
  double advance(double seconds, double radiansPerSecond) {
    if (!seconds.isFinite || !radiansPerSecond.isFinite) return _turns;
    final previous = _seconds;
    _seconds = seconds;
    if (previous != null && seconds >= previous) {
      _turns =
          (_turns + (seconds - previous) * radiansPerSecond / (2 * math.pi)) %
          1;
    }
    return _turns;
  }
}

/// Compress high RPM for legibility at display refresh rates, preserving sign,
/// standstill and monotonic speed. This is not a second mechanical solver.
double visibleRotorSpeed(double physicalRadiansPerSecond) {
  if (!physicalRadiansPerSecond.isFinite) return 0;
  const maximum = 6 * math.pi;
  return maximum *
      physicalRadiansPerSecond /
      (maximum + physicalRadiansPerSecond.abs());
}

double? rotorVelocity(
  ElectroSimRuntimeSnapshot? snapshot,
  ComponentInstance component, {
  required bool running,
  required bool energized,
  required double voltageV,
  required double ratedVoltageV,
}) {
  final type = component.modelType;
  if (!{'motor_dc', 'motor_3p_6t', 'fan_dc'}.contains(type)) return null;
  if (!running || snapshot == null || !snapshot.solved) return 0;
  if (type == 'motor_dc') {
    return visibleRotorSpeed(
      snapshot.motorAngularSpeedsRadS[component.id] ?? 0,
    );
  }
  if (!energized) return 0;
  if (type == 'fan_dc') {
    // Legacy resistive fan has no mechanical speed state; retain its voltage
    // response as a qualitative animation, never report it as measured RPM.
    final fraction = ratedVoltageV > 0
        ? (voltageV.abs() / ratedVoltageV).clamp(0.0, 1.0)
        : 0;
    return 2 * math.pi * 3 * fraction;
  }
  final ac = snapshot.ac3Result;
  final frequency = ac?.frequencyHz;
  if (ac == null ||
      frequency == null ||
      !frequency.isFinite ||
      frequency <= 0) {
    return 0;
  }
  final observations = ac.phaseOrderObservations.where(
    (o) => o.componentId == component.id,
  );
  final sequence = observations.isEmpty
      ? Ac3PhaseSequence.indeterminate
      : observations.first.sequence;
  if (sequence == Ac3PhaseSequence.indeterminate) return 0;
  final rawPoles = component.parameters['motorPoles'];
  final poles =
      rawPoles is num && rawPoles.isFinite && rawPoles >= 2 && rawPoles % 2 == 0
      ? rawPoles.toDouble()
      : 4.0;
  // AC3 currently solves winding impedance, not shaft inertia/slip. This is
  // synchronous-field direction/frequency indication, not actual shaft RPM.
  return visibleRotorSpeed(
    (sequence == Ac3PhaseSequence.negative ? -1 : 1) *
        4 *
        math.pi *
        frequency /
        poles,
  );
}
