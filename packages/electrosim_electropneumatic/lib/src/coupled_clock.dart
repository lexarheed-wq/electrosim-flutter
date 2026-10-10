import 'dart:math' as math;

import 'dc_coil_meter.dart';
import 'solenoid_actuator.dart';

/// Used for both workshops; snapshot values are always computed, never
/// interpolated from the visual position of a component.
final class CoupledRuntimeSnapshot<T> {
  const CoupledRuntimeSnapshot({
    required this.timeS,
    required this.air,
    required this.coil,
    required this.spool,
    required this.endContactActuated,
    required this.electricalSolves,
    required this.pneumaticAdvances,
  });

  final double timeS;
  final T air;
  final Solenoid24vSnapshot coil;
  final ValveSpoolSide spool;
  final bool endContactActuated;
  final int electricalSolves;
  final int pneumaticAdvances;
}

/// The adapter MUST perform a real DC solve for the same project revision;
/// see DcCoilMeter.read(). No property-pane switch or nominal 24 V shortcut.
typedef SolveCoilAt<T> =
    CoilElectricalReading Function(
      T air,
      ValveSpoolSide spool,
      bool sensorContactClosed,
    );

/// Physical advance is invoked **once only** for each accepted positive dt.
typedef AdvanceAir<T> =
    T Function(T before, double durationS, ValveSpoolSide valveSpool);

typedef AirTime<T> = double Function(T air);
typedef CylinderPosition<T> = double Function(T air);

/// R3/A proof of a common-clock coupling: finite time steps, delayed coil
/// transitions at exact timestamps, bounded zero-time re-solves and no
/// second gas integration when a contact or coil changes.
///
/// This does not claim a complete 5/2 valve model. AirAdvance's concrete
/// pneumatic implementation and the sensor-to-contact circuit binding are
/// independently qualified in follow-up R3/B.
final class ElectropneumaticEventClock<T> {
  ElectropneumaticEventClock({
    required this.solenoid,
    required this.valveMemory,
    required this.solveElectrical,
    required this.advanceAir,
    required this.airTime,
    this.positionSensor,
    this.cylinderPosition,
    this.maxStepS = .005,
    this.maxSteps = 100000,
    this.maxZeroTimeSolves = 12,
  }) {
    if (!maxStepS.isFinite ||
        maxStepS <= 0 ||
        maxSteps <= 0 ||
        maxZeroTimeSolves <= 0 ||
        (positionSensor == null) != (cylinderPosition == null)) {
      throw const ElectropneumaticRuntimeException(
        'invalid_clock_configuration',
        'Invalid event clock step bounds or missing position adapter.',
      );
    }
  }

  final Solenoid24vDynamics solenoid;
  final SingleCoilValveMemory valveMemory;
  final SolveCoilAt<T> solveElectrical;
  final AdvanceAir<T> advanceAir;
  final AirTime<T> airTime;
  final PositionEndContact? positionSensor;
  final CylinderPosition<T>? cylinderPosition;
  final double maxStepS;
  final int maxSteps;
  final int maxZeroTimeSolves;

  CoupledRuntimeSnapshot<T> initial(
    T initialAir, {
    ValveSpoolSide initialSpool = ValveSpoolSide.springSide,
  }) {
    final double t = airTime(initialAir);
    if (!t.isFinite || t < 0) {
      throw const ElectropneumaticRuntimeException(
        'invalid_initial_time',
        'Air snapshot must have an accepted nonnegative time.',
      );
    }
    return CoupledRuntimeSnapshot<T>(
      timeS: t,
      air: initialAir,
      coil: const Solenoid24vSnapshot(energized: false, measuredVoltageV: 0),
      spool: initialSpool,
      endContactActuated: false,
      electricalSolves: 0,
      pneumaticAdvances: 0,
    );
  }

  CoupledRuntimeSnapshot<T> advance(
    CoupledRuntimeSnapshot<T> before, {
    required double durationS,
  }) {
    if (!durationS.isFinite || durationS < 0) {
      throw const ElectropneumaticRuntimeException(
        'invalid_duration',
        'Requested simulation time must be finite and nonnegative.',
      );
    }
    if ((airTime(before.air) - before.timeS).abs() > 1e-9) {
      throw const ElectropneumaticRuntimeException(
        'clock_desynchronization',
        'Electrical and gas timestamps are not equal at entry.',
      );
    }

    T air = before.air;
    double now = before.timeS;
    final double end = before.timeS + durationS;
    if (!end.isFinite || (durationS > 0 && end <= now)) {
      throw const ElectropneumaticRuntimeException(
        'time_underflow',
        'Requested timestamp cannot advance.',
      );
    }
    Solenoid24vSnapshot coil = before.coil;
    ValveSpoolSide spool = before.spool;
    bool actuated = before.endContactActuated;
    int electricalSolves = before.electricalSolves;
    int pneumaticAdvances = before.pneumaticAdvances;

    void settleElectrical() {
      for (int cycle = 0; cycle < maxZeroTimeSolves; cycle++) {
        if (positionSensor != null) {
          actuated = positionSensor!.actuated(
            previouslyActuated: actuated,
            positionM: cylinderPosition!(air),
          );
        }
        final bool closed = positionSensor?.closed(actuated) ?? false;
        final CoilElectricalReading measurement = solveElectrical(
          air,
          spool,
          closed,
        );
        electricalSolves++;
        if (!measurement.voltageV.isFinite ||
            measurement.voltageV < 0 ||
            !measurement.currentA.isFinite ||
            measurement.currentA < 0) {
          throw const ElectropneumaticRuntimeException(
            'invalid_dc_feedback',
            'Electrical callback returned an invalid measurement.',
          );
        }
        final Solenoid24vSnapshot next = solenoid.observe(
          coil,
          nowS: now,
          measuredVoltageV: measurement.voltageV,
        );
        final ValveSpoolSide nextSpool = valveMemory.update(
          previous: spool,
          coilEnergized: next.energized,
        );
        final bool changed =
            nextSpool != spool || next.energized != coil.energized;
        coil = next;
        spool = nextSpool;
        if (!changed) return;
      }
      throw const ElectropneumaticRuntimeException(
        'zero_time_nonconvergence',
        'Bounded electrical feedback failed; no new snapshot was accepted.',
      );
    }

    settleElectrical();
    int steps = 0;
    while (now < end) {
      if (steps++ >= maxSteps) {
        throw const ElectropneumaticRuntimeException(
          'max_physics_steps',
          'Global step budget exceeded before accepting a new snapshot.',
        );
      }
      double next = math.min(end, now + maxStepS);
      final double? transition = coil.transitionDueS;
      if (transition != null && transition > now) {
        next = math.min(next, transition);
      }
      if (!(next > now)) {
        throw const ElectropneumaticRuntimeException(
          'time_underflow',
          'Physical step is zero or non-monotonic.',
        );
      }
      final double dt = next - now;
      final T updatedAir = advanceAir(air, dt, spool);
      final double accepted = airTime(updatedAir);
      // A cylinder can reach its physical end-stop *before* the requested
      // interval ends. Accept the earlier event timestamp, re-solve B1/K1/Y1
      // immediately, then integrate only the remaining interval.
      // A duplicate/non-monotonic physical time is always rejected.
      final double clockTolerance = 1e-10 * math.max(1, next.abs());
      if (!accepted.isFinite ||
          accepted <= now ||
          accepted > next + clockTolerance) {
        throw const ElectropneumaticRuntimeException(
          'pneumatic_clock_mismatch',
          'Air solver returned an invalid or non-monotonic event timestamp.',
        );
      }
      air = updatedAir;
      now = accepted;
      pneumaticAdvances++;
      // Re-solving electrical feedback at the exact accepted time
      // never calls the pneumatic solver a second time.
      settleElectrical();
    }

    return CoupledRuntimeSnapshot<T>(
      timeS: now,
      air: air,
      coil: coil,
      spool: spool,
      endContactActuated: actuated,
      electricalSolves: electricalSolves,
      pneumaticAdvances: pneumaticAdvances,
    );
  }
}
