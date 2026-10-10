import 'dart:collection';
import 'dart:math' as math;

import 'cylinder_physics.dart';
import 'ideal_gas.dart';
import 'open_boundary.dart';

/// Signed external load resists extension when positive.
final class CylinderMechanicalCalibration {
  CylinderMechanicalCalibration({
    required this.movingMassKg,
    this.viscousNsPerM = 0,
    this.coulombFrictionN = 0,
    this.staticBreakawayFrictionN = 0,
    this.externalLoadN = 0,
  }) {
    requirePositiveFinite(movingMassKg, 'movingMassKg');
    requireNonnegativeFinite(viscousNsPerM, 'viscousNsPerM');
    requireNonnegativeFinite(coulombFrictionN, 'coulombFrictionN');
    requireNonnegativeFinite(
      staticBreakawayFrictionN,
      'staticBreakawayFrictionN',
    );
    if (staticBreakawayFrictionN < coulombFrictionN ||
        !externalLoadN.isFinite) {
      throw const PneumaticPhysicsException(
        'invalid_friction_or_load',
        'Breakaway friction cannot be below kinetic friction; load must be finite.',
      );
    }
  }

  final double movingMassKg;
  final double viscousNsPerM;
  final double coulombFrictionN;
  final double staticBreakawayFrictionN;
  final double externalLoadN;
}

enum CylinderStop { retracted, extended }

final class CylinderStopEvent {
  const CylinderStopEvent({required this.timeS, required this.stop});

  final double timeS;
  final CylinderStop stop;
}

/// One accepted mechanical/thermodynamic snapshot. Two chamber masses are
/// independent state variables; neither pressure nor gas volume is cached.
/// Cumulative signed mass from external boundaries is kept for full auditing.
final class MovingCylinderSnapshot {
  MovingCylinderSnapshot({
    required this.timeS,
    required this.positionM,
    required this.velocityMPerS,
    required this.massAKg,
    required this.massBKg,
    required this.externalMassAddedAKg,
    required this.externalMassAddedBKg,
    required this.acceptedSubsteps,
    required List<CylinderStopEvent> stopEvents,
  }) : stopEvents = List<CylinderStopEvent>.unmodifiable(stopEvents) {
    requireNonnegativeFinite(timeS, 'timeS');
    requireNonnegativeFinite(positionM, 'positionM');
    requirePositiveFinite(massAKg, 'massAKg');
    requirePositiveFinite(massBKg, 'massBKg');
    if (!velocityMPerS.isFinite ||
        !externalMassAddedAKg.isFinite ||
        !externalMassAddedBKg.isFinite ||
        acceptedSubsteps < 0) {
      throw const PneumaticPhysicsException(
        'invalid_cylinder_snapshot',
        'Cylinder velocity, mass ledgers and accepted step count must be finite.',
      );
    }
  }

  final double timeS;
  final double positionM;
  final double velocityMPerS;
  final double massAKg;
  final double massBKg;
  final double externalMassAddedAKg;
  final double externalMassAddedBKg;
  final int acceptedSubsteps;
  final List<CylinderStopEvent> stopEvents;

  double get gasMassKg => massAKg + massBKg;
  double get externalMassAddedKg => externalMassAddedAKg + externalMassAddedBKg;
}

/// A conservative, isothermal, lumped two-chamber cylinder with a moving
/// mechanical mass. Reservoir/orifice boundaries are explicitly supplied.
/// Both mass fluxes and mechanics are evaluated from the same accepted time.
///
/// Model limits: no heat exchange, oil compressibility, rod elasticity,
/// variable spool conductance, pressure-wave propagation or bouncing end stops.
/// These require later independently qualified physical models.
final class MovingDoubleActingAirCylinder {
  MovingDoubleActingAirCylinder({
    required this.geometry,
    required this.mechanics,
    required this.initialSnapshot,
    List<PneumaticPressureBoundary> aBoundaries =
        const <PneumaticPressureBoundary>[],
    List<PneumaticPressureBoundary> bBoundaries =
        const <PneumaticPressureBoundary>[],
    this.temperatureK = DryAirReference.temperatureK,
  }) : aBoundaries = List<PneumaticPressureBoundary>.unmodifiable(aBoundaries),
       bBoundaries = List<PneumaticPressureBoundary>.unmodifiable(bBoundaries) {
    requirePositiveFinite(temperatureK, 'temperatureK');
    _validatePosition(initialSnapshot.positionM);
    final Set<String> unique = <String>{};
    for (final PneumaticPressureBoundary b in <PneumaticPressureBoundary>[
      ...aBoundaries,
      ...bBoundaries,
    ]) {
      if (!unique.add(b.id)) {
        throw const PneumaticPhysicsException(
          'duplicate_boundary',
          'Cylinder gas boundaries must have unique IDs in both chambers.',
        );
      }
    }
  }

  factory MovingDoubleActingAirCylinder.fromPressure({
    required DoubleActingCylinderGeometry geometry,
    required CylinderMechanicalCalibration mechanics,
    required double initialPositionM,
    required double initialPressureAAbsPa,
    required double initialPressureBAbsPa,
    double initialVelocityMPerS = 0,
    double temperatureK = DryAirReference.temperatureK,
    List<PneumaticPressureBoundary> aBoundaries =
        const <PneumaticPressureBoundary>[],
    List<PneumaticPressureBoundary> bBoundaries =
        const <PneumaticPressureBoundary>[],
  }) {
    return MovingDoubleActingAirCylinder(
      geometry: geometry,
      mechanics: mechanics,
      temperatureK: temperatureK,
      aBoundaries: aBoundaries,
      bBoundaries: bBoundaries,
      initialSnapshot: MovingCylinderSnapshot(
        timeS: 0,
        positionM: initialPositionM,
        velocityMPerS: initialVelocityMPerS,
        massAKg: IsothermalAir.massKg(
          pressureAbsPa: initialPressureAAbsPa,
          volumeM3: geometry.volumeAM3(initialPositionM),
          temperatureK: temperatureK,
        ),
        massBKg: IsothermalAir.massKg(
          pressureAbsPa: initialPressureBAbsPa,
          volumeM3: geometry.volumeBM3(initialPositionM),
          temperatureK: temperatureK,
        ),
        externalMassAddedAKg: 0,
        externalMassAddedBKg: 0,
        acceptedSubsteps: 0,
        stopEvents: const <CylinderStopEvent>[],
      ),
    );
  }

  final DoubleActingCylinderGeometry geometry;
  final CylinderMechanicalCalibration mechanics;
  final MovingCylinderSnapshot initialSnapshot;
  final List<PneumaticPressureBoundary> aBoundaries;
  final List<PneumaticPressureBoundary> bBoundaries;
  final double temperatureK;

  void _validatePosition(double x) {
    if (!x.isFinite || x < 0 || x > geometry.strokeM) {
      throw const PneumaticPhysicsException(
        'cylinder_position_out_of_range',
        'The piston must lie within both physical end stops.',
      );
    }
  }

  double pressureAAbsPa(MovingCylinderSnapshot s) =>
      IsothermalAir.pressureAbsPa(
        massKg: s.massAKg,
        volumeM3: geometry.volumeAM3(s.positionM),
        temperatureK: temperatureK,
      );

  double pressureBAbsPa(MovingCylinderSnapshot s) =>
      IsothermalAir.pressureAbsPa(
        massKg: s.massBKg,
        volumeM3: geometry.volumeBM3(s.positionM),
        temperatureK: temperatureK,
      );

  /// In any accepted state the net mass change equals the integrated
  /// external boundary flows. Both chambers count; no fictitious source.
  double massResidualKg(MovingCylinderSnapshot s) =>
      s.gasMassKg - initialSnapshot.gasMassKg - s.externalMassAddedKg;

  double mechanicalResultantN(MovingCylinderSnapshot s) {
    final double drive =
        geometry.theoreticalForceN(
          pressureAAbsPa: pressureAAbsPa(s),
          pressureBAbsPa: pressureBAbsPa(s),
        ) -
        mechanics.externalLoadN;
    final double v = s.velocityMPerS;
    final double viscous = mechanics.viscousNsPerM * v;
    if (v.abs() <= 1e-12) {
      if (drive.abs() <= mechanics.staticBreakawayFrictionN) return 0;
      return drive - mechanics.coulombFrictionN * (drive.isNegative ? -1 : 1);
    }
    return drive -
        viscous -
        mechanics.coulombFrictionN * (v.isNegative ? -1 : 1);
  }

  double _boundaryFlow(
    double chamberPressure,
    List<PneumaticPressureBoundary> boundaries,
  ) {
    double sum = 0;
    for (final PneumaticPressureBoundary b in boundaries) {
      if (!b.enabled) continue;
      double q = b.orifice.massFlowKgPerS(
        fromPressureAbsPa: b.pressureAbsPa,
        toPressureAbsPa: chamberPressure,
        temperatureK: b.pressureAbsPa >= chamberPressure
            ? b.temperatureK
            : temperatureK,
      );
      if (q < 0 && !b.allowReverseFlow) q = 0;
      sum += q;
    }
    if (!sum.isFinite) {
      throw const PneumaticPhysicsException(
        'nonfinite_mass_flow',
        'Integrated cylinder boundary flow was nonfinite.',
      );
    }
    return sum;
  }

  /// Exact crossing of a constant-acceleration kinematic substep.
  /// Re-evaluate all gas pressures after the reduced impact interval.
  double _impactTime({
    required double x,
    required double v,
    required double a,
    required double dt,
    required double stop,
  }) {
    double lo = 0;
    double hi = dt;
    final bool crossingUp = stop > x;
    for (int i = 0; i < 56; i++) {
      final double mid = (lo + hi) / 2;
      final double candidate = x + v * mid + .5 * a * mid * mid;
      if ((candidate >= stop) == crossingUp) {
        hi = mid;
      } else {
        lo = mid;
      }
    }
    return hi;
  }

  MovingCylinderSnapshot advance(
    MovingCylinderSnapshot before, {
    required double durationS,
    double maxStepS = .0005,
    int maxSubsteps = 200000,
    bool stopAtFirstImpact = false,
  }) {
    requireNonnegativeFinite(durationS, 'durationS');
    requirePositiveFinite(maxStepS, 'maxStepS');
    _validatePosition(before.positionM);
    if (maxSubsteps <= 0 ||
        before.timeS + durationS == before.timeS && durationS > 0) {
      throw const PneumaticPhysicsException(
        'invalid_cylinder_step',
        'Cylinder step budget or timeline is invalid.',
      );
    }
    if (durationS == 0) return before;
    double now = before.timeS;
    final double end = now + durationS;
    double x = before.positionM;
    double v = before.velocityMPerS;
    double mA = before.massAKg;
    double mB = before.massBKg;
    double addedA = before.externalMassAddedAKg;
    double addedB = before.externalMassAddedBKg;
    int count = 0;
    final List<CylinderStopEvent> events = List<CylinderStopEvent>.from(
      before.stopEvents,
    );
    final double tolerance = durationS * 1e-13;

    while (end - now > tolerance) {
      if (count >= maxSubsteps) {
        throw const PneumaticPhysicsException(
          'substep_limit',
          'Moving cylinder exceeded its bounded substep budget.',
        );
      }
      final MovingCylinderSnapshot at = MovingCylinderSnapshot(
        timeS: now,
        positionM: x,
        velocityMPerS: v,
        massAKg: mA,
        massBKg: mB,
        externalMassAddedAKg: addedA,
        externalMassAddedBKg: addedB,
        acceptedSubsteps: before.acceptedSubsteps + count,
        stopEvents: events,
      );
      final double qA = _boundaryFlow(pressureAAbsPa(at), aBoundaries);
      final double qB = _boundaryFlow(pressureBAbsPa(at), bBoundaries);
      final double forceN = mechanicalResultantN(at);
      double acceleration = forceN / mechanics.movingMassKg;
      if ((x <= 0 && v <= 0 && acceleration <= 0) ||
          (x >= geometry.strokeM && v >= 0 && acceleration >= 0)) {
        v = 0;
        acceleration = 0;
      }

      double dt = math.min(maxStepS, end - now);
      if (qA < 0) dt = math.min(dt, .2 * mA / -qA);
      if (qB < 0) dt = math.min(dt, .2 * mB / -qB);
      if (!dt.isFinite || dt <= 0 || now + dt == now) {
        throw const PneumaticPhysicsException(
          'step_underflow',
          'Moving cylinder physical timestep cannot advance.',
        );
      }

      final double trialX = x + v * dt + .5 * acceleration * dt * dt;
      CylinderStop? stop;
      if (trialX < 0) {
        stop = CylinderStop.retracted;
      } else if (trialX > geometry.strokeM) {
        stop = CylinderStop.extended;
      }
      if (stop != null) {
        final double stopX = stop == CylinderStop.retracted
            ? 0
            : geometry.strokeM;
        dt = _impactTime(x: x, v: v, a: acceleration, dt: dt, stop: stopX);
        if (dt <= 0 || now + dt == now) {
          throw const PneumaticPhysicsException(
            'impact_time_underflow',
            'Cannot locate the piston end-stop event on the shared clock.',
          );
        }
      }

      final double nextA = mA + qA * dt;
      final double nextB = mB + qB * dt;
      if (!nextA.isFinite || !nextB.isFinite || nextA <= 0 || nextB <= 0) {
        throw const PneumaticPhysicsException(
          'invalid_chamber_mass',
          'A dynamic step tried to create an invalid gas mass.',
        );
      }
      final double nextX = stop == CylinderStop.retracted
          ? 0
          : stop == CylinderStop.extended
          ? geometry.strokeM
          : x + v * dt + .5 * acceleration * dt * dt;
      final double nextV = stop == null ? v + acceleration * dt : 0;
      if (stop != null) {
        events.add(CylinderStopEvent(timeS: now + dt, stop: stop));
      }
      x = nextX;
      v = nextV;
      mA = nextA;
      mB = nextB;
      addedA += qA * dt;
      addedB += qB * dt;
      now += dt;
      count++;
      // An electropneumatic scheduler can stop the gas solver at the exact
      // first physical impact, then solve B1/K1/Y1 before advancing air again.
      // No speculative step or second air integration is needed.
      if (stop != null && stopAtFirstImpact) break;
    }

    // Avoid displaying a floating-point remnant as a physical time drift.
    final double acceptedTime = (end - now).abs() <= tolerance ? end : now;
    return MovingCylinderSnapshot(
      timeS: acceptedTime,
      positionM: x,
      velocityMPerS: v,
      massAKg: mA,
      massBKg: mB,
      externalMassAddedAKg: addedA,
      externalMassAddedBKg: addedB,
      acceptedSubsteps: before.acceptedSubsteps + count,
      stopEvents: UnmodifiableListView<CylinderStopEvent>(events),
    );
  }
}
