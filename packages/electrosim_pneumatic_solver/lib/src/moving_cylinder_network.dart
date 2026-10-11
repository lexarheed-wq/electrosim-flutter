import 'dart:math' as math;

import 'cylinder_physics.dart';
import 'dynamic_cylinder.dart';
import 'ideal_gas.dart';
import 'isothermal_network.dart';

/// One atomic accepted physical state: the two moving chamber masses are
/// stored IN the network, never copied into a second independent integrator.
final class CoupledCylinderNetworkSnapshot {
  CoupledCylinderNetworkSnapshot({
    required this.air,
    required this.positionM,
    required this.velocityMPerS,
    required this.mechanicalSubsteps,
    required List<CylinderStopEvent> stopEvents,
  }) : stopEvents = List<CylinderStopEvent>.unmodifiable(stopEvents) {
    if (!positionM.isFinite ||
        !velocityMPerS.isFinite ||
        mechanicalSubsteps < 0) {
      throw const PneumaticPhysicsException(
        'invalid_coupled_snapshot',
        'Nonfinite piston state or invalid accepted mechanical step count.',
      );
    }
  }

  final IsothermalAirSnapshot air;
  final double positionM;
  final double velocityMPerS;
  final int mechanicalSubsteps;
  final List<CylinderStopEvent> stopEvents;

  double get timeS => air.timeS;
}

/// Same-clock conservative coupling of an authored pneumatic hose/valve
/// network to one double-acting moving cylinder.
///
/// The network owns every gas mass (including both piston chambers).
/// A physical substep exchanges gas once, then advances the mechanical
/// state and updates two geometric volumes without creating/removing mass.
/// Forces are derived from accepted chamber pressures. Uses an isothermal
/// first-order operator split, so convergence must be checked by step
/// halving; this is NOT a general implicit stiff-system solver.
///
/// Not modeled: rod compressibility, heat flow, valve actuation time,
/// bounce/restitution, multiple cylinders, hydraulic shock or manufacturer
/// safety certification.
final class CoupledMovingCylinderAirNetwork {
  CoupledMovingCylinderAirNetwork({
    required this.airNetwork,
    required this.geometry,
    required this.mechanics,
    required this.chamberAId,
    required this.chamberBId,
    required double initialPositionM,
    double initialVelocityMPerS = 0,
  }) {
    _validatePosition(initialPositionM);
    if (!initialVelocityMPerS.isFinite || chamberAId == chamberBId) {
      throw const PneumaticPhysicsException(
        'invalid_coupled_cylinder',
        'Cylinder velocities and distinct chamber IDs are required.',
      );
    }
    final FixedAirChamber? a = airNetwork.initialSnapshot.chambers[chamberAId];
    final FixedAirChamber? b = airNetwork.initialSnapshot.chambers[chamberBId];
    if (a == null || b == null) {
      throw const PneumaticPhysicsException(
        'missing_cylinder_chambers',
        'Both moving gas chambers must be in the physical network.',
      );
    }
    if (!_nearVolume(a.volumeM3, geometry.volumeAM3(initialPositionM)) ||
        !_nearVolume(b.volumeM3, geometry.volumeBM3(initialPositionM))) {
      throw const PneumaticPhysicsException(
        'cylinder_volume_mismatch',
        'Gas volumes must agree with the physically declared piston position.',
      );
    }
    initialSnapshot = CoupledCylinderNetworkSnapshot(
      air: airNetwork.initialSnapshot,
      positionM: initialPositionM,
      velocityMPerS: initialVelocityMPerS,
      mechanicalSubsteps: 0,
      stopEvents: const <CylinderStopEvent>[],
    );
  }

  final IsothermalAirNetwork airNetwork;
  final DoubleActingCylinderGeometry geometry;
  final CylinderMechanicalCalibration mechanics;
  final String chamberAId;
  final String chamberBId;
  late final CoupledCylinderNetworkSnapshot initialSnapshot;

  bool _nearVolume(double a, double b) =>
      (a - b).abs() <= 1e-10 * math.max(a.abs(), b.abs());

  void _validatePosition(double x) {
    if (!x.isFinite || x < 0 || x > geometry.strokeM) {
      throw const PneumaticPhysicsException(
        'cylinder_position_out_of_range',
        'Moving cylinder must remain within its physical stroke.',
      );
    }
  }

  double massBalanceResidualKg(CoupledCylinderNetworkSnapshot s) =>
      airNetwork.massBalanceResidualKg(s.air);

  double pressureAAbsPa(CoupledCylinderNetworkSnapshot s) =>
      s.air.chambers[chamberAId]!.pressureAbsPa;

  double pressureBAbsPa(CoupledCylinderNetworkSnapshot s) =>
      s.air.chambers[chamberBId]!.pressureAbsPa;

  double resultantForceN(CoupledCylinderNetworkSnapshot s) {
    final double drive = geometry.theoreticalForceN(
          pressureAAbsPa: pressureAAbsPa(s),
          pressureBAbsPa: pressureBAbsPa(s),
        ) -
        mechanics.externalLoadN;
    final double v = s.velocityMPerS;
    if (v.abs() <= 1e-12) {
      if (drive.abs() <= mechanics.staticBreakawayFrictionN) return 0;
      return drive -
          mechanics.coulombFrictionN * (drive.isNegative ? -1 : 1);
    }
    return drive -
        mechanics.viscousNsPerM * v -
        mechanics.coulombFrictionN * (v.isNegative ? -1 : 1);
  }

  double _impactDt({
    required double x,
    required double v,
    required double acceleration,
    required double dt,
    required double limit,
  }) {
    double lo = 0;
    double hi = dt;
    final bool extending = limit > x;
    for (int i = 0; i < 56; i++) {
      final double mid = (lo + hi) / 2;
      final double projected = x + v * mid + .5 * acceleration * mid * mid;
      if ((projected >= limit) == extending) {
        hi = mid;
      } else {
        lo = mid;
      }
    }
    return hi;
  }

  CoupledCylinderNetworkSnapshot advance(
    CoupledCylinderNetworkSnapshot before, {
    required double durationS,
    double maxStepS = .0001,
    int maxSubsteps = 200000,
    bool stopAtFirstImpact = false,
  }) {
    requireNonnegativeFinite(durationS, 'durationS');
    requirePositiveFinite(maxStepS, 'maxStepS');
    _validatePosition(before.positionM);
    if (maxSubsteps <= 0) {
      throw const PneumaticPhysicsException(
        'invalid_coupled_step',
        'Mechanical substep budget must be positive.',
      );
    }
    if (durationS == 0) return before;
    if (before.timeS + durationS == before.timeS) {
      throw const PneumaticPhysicsException(
        'step_underflow',
        'Requested time cannot advance.',
      );
    }
    final FixedAirChamber? first = before.air.chambers[chamberAId];
    final FixedAirChamber? second = before.air.chambers[chamberBId];
    if (first == null ||
        second == null ||
        !_nearVolume(first.volumeM3, geometry.volumeAM3(before.positionM)) ||
        !_nearVolume(second.volumeM3, geometry.volumeBM3(before.positionM))) {
      throw const PneumaticPhysicsException(
        'cylinder_volume_mismatch',
        'Moving snapshot and gas geometry disagree.',
      );
    }

    CoupledCylinderNetworkSnapshot current = before;
    final double end = before.timeS + durationS;
    final double tolerance = durationS * 1e-13;
    int accepted = 0;
    while (end - current.timeS > tolerance) {
      if (accepted >= maxSubsteps) {
        throw const PneumaticPhysicsException(
          'substep_limit',
          'Coupled network exceeded bounded mechanical substeps.',
        );
      }
      final double x = current.positionM;
      double v = current.velocityMPerS;
      double acceleration = resultantForceN(current) / mechanics.movingMassKg;
      if ((x <= 0 && v <= 0 && acceleration <= 0) ||
          (x >= geometry.strokeM && v >= 0 && acceleration >= 0)) {
        v = 0;
        acceleration = 0;
      }
      double dt = math.min(maxStepS, end - current.timeS);
      final double proposed = x + v * dt + .5 * acceleration * dt * dt;
      CylinderStop? stop;
      if (proposed < 0) {
        stop = CylinderStop.retracted;
      } else if (proposed > geometry.strokeM) {
        stop = CylinderStop.extended;
      }
      if (stop != null) {
        dt = _impactDt(
          x: x,
          v: v,
          acceleration: acceleration,
          dt: dt,
          limit: stop == CylinderStop.extended ? geometry.strokeM : 0,
        );
      }
      if (!dt.isFinite || dt <= 0 || current.timeS + dt == current.timeS) {
        throw const PneumaticPhysicsException(
          'step_underflow',
          'Impact/gas timestep cannot advance on the shared clock.',
        );
      }

      // Exactly one air solve for each accepted time interval.
      final IsothermalAirSnapshot flowed = airNetwork.advance(
        current.air,
        durationS: dt,
        maxStepS: dt,
      );
      final double nextX = stop == CylinderStop.retracted
          ? 0
          : stop == CylinderStop.extended
              ? geometry.strokeM
              : x + v * dt + .5 * acceleration * dt * dt;
      final double nextV = stop == null ? v + acceleration * dt : 0;
      final Map<String, FixedAirChamber> resized =
          Map<String, FixedAirChamber>.from(flowed.chambers);
      final FixedAirChamber a = resized[chamberAId]!;
      final FixedAirChamber b = resized[chamberBId]!;
      resized[chamberAId] = FixedAirChamber(
        id: a.id,
        volumeM3: geometry.volumeAM3(nextX),
        massKg: a.massKg,
        temperatureK: a.temperatureK,
      );
      resized[chamberBId] = FixedAirChamber(
        id: b.id,
        volumeM3: geometry.volumeBM3(nextX),
        massKg: b.massKg,
        temperatureK: b.temperatureK,
      );
      final IsothermalAirSnapshot air = IsothermalAirSnapshot(
        timeS: flowed.timeS,
        chambers: resized,
        passageMassFlowKgPerS: flowed.passageMassFlowKgPerS,
        acceptedSubsteps: flowed.acceptedSubsteps,
        externalMassAddedKg: flowed.externalMassAddedKg,
      );
      current = CoupledCylinderNetworkSnapshot(
        air: air,
        positionM: nextX,
        velocityMPerS: nextV,
        mechanicalSubsteps: before.mechanicalSubsteps + accepted + 1,
        stopEvents: <CylinderStopEvent>[
          ...current.stopEvents,
          if (stop != null)
            CylinderStopEvent(timeS: flowed.timeS, stop: stop),
        ],
      );
      accepted++;
      if (stop != null && stopAtFirstImpact) break;
    }
    return current;
  }
}
