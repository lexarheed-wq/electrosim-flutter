import 'dart:math' as math;

import 'ideal_gas.dart';
import 'isothermal_network.dart';

/// Ideal external supply or exhaust. Pressure is absolute; the source is
/// inexhaustible and may be disabled without changing trapped chamber mass.
/// This is an explicit boundary condition, not a compressor model.
final class PneumaticPressureBoundary {
  PneumaticPressureBoundary({
    required this.id,
    required this.pressureAbsPa,
    required this.orifice,
    this.temperatureK = DryAirReference.temperatureK,
    this.enabled = true,
    this.allowReverseFlow = true,
  }) {
    if (!RegExp(r'^[A-Za-z0-9][A-Za-z0-9.:-]{0,127}$').hasMatch(id)) {
      throw const PneumaticPhysicsException(
        'invalid_boundary_id',
        'Invalid external boundary identity.',
      );
    }
    requirePositiveFinite(pressureAbsPa, 'pressureAbsPa');
    requirePositiveFinite(temperatureK, 'temperatureK');
  }

  final String id;
  final double pressureAbsPa;
  final IsentropicOrifice orifice;
  final double temperatureK;
  final bool enabled;
  final bool allowReverseFlow;
}

/// Positive integrated source mass means air entered the chamber from outside.
/// It is a ledger of reservoir exchange, not a claim about finite tank pressure.
final class OpenAirSnapshot {
  OpenAirSnapshot({
    required this.timeS,
    required this.chamber,
    required this.externalMassAddedKg,
    required this.acceptedSubsteps,
    required Map<String, double> signedBoundaryFlowsKgPerS,
  }) : signedBoundaryFlowsKgPerS = Map<String, double>.unmodifiable(
         signedBoundaryFlowsKgPerS,
       ) {
    requireNonnegativeFinite(timeS, 'timeS');
    if (!externalMassAddedKg.isFinite || acceptedSubsteps < 0) {
      throw const PneumaticPhysicsException(
        'invalid_snapshot',
        'Non-finite mass ledger or negative step count.',
      );
    }
  }

  final double timeS;
  final FixedAirChamber chamber;
  final double externalMassAddedKg;
  final int acceptedSubsteps;
  final Map<String, double> signedBoundaryFlowsKgPerS;
}

/// Single finite-volume ideal-gas chamber supplied and/or vented through
/// calibrated external orifices. All fluxes share a timestamp and are applied
/// simultaneously. This explicitly supports PHY-03 single-node mass ledger.
///
/// It does NOT yet couple moving cylinder chambers or a multi-island graph.
final class OpenIsothermalAirChamber {
  OpenIsothermalAirChamber({
    required FixedAirChamber initialChamber,
    required List<PneumaticPressureBoundary> boundaries,
  }) : _chamberId = initialChamber.id,
       boundaries = List<PneumaticPressureBoundary>.unmodifiable(boundaries),
       initialSnapshot = OpenAirSnapshot(
         timeS: 0,
         chamber: initialChamber,
         externalMassAddedKg: 0,
         acceptedSubsteps: 0,
         signedBoundaryFlowsKgPerS: <String, double>{
           for (final PneumaticPressureBoundary b in boundaries) b.id: 0,
         },
       ) {
    final Set<String> ids = <String>{};
    for (final PneumaticPressureBoundary b in boundaries) {
      if (!ids.add(b.id)) {
        throw const PneumaticPhysicsException(
          'duplicate_boundary',
          'External boundary IDs must be unique.',
        );
      }
    }
  }

  final String _chamberId;
  final List<PneumaticPressureBoundary> boundaries;
  final OpenAirSnapshot initialSnapshot;

  OpenAirSnapshot advance(
    OpenAirSnapshot before, {
    required double durationS,
    double maxStepS = .005,
    int maxSubsteps = 500000,
  }) {
    requireNonnegativeFinite(durationS, 'durationS');
    requirePositiveFinite(maxStepS, 'maxStepS');
    if (maxSubsteps <= 0) {
      throw const PneumaticPhysicsException(
        'invalid_solver_options',
        'maxSubsteps must be positive.',
      );
    }
    if (before.chamber.id != _chamberId) {
      throw const PneumaticPhysicsException(
        'topology_mismatch',
        'Input snapshot has a foreign chamber ID.',
      );
    }
    if (durationS == 0) return before;
    if (before.timeS + durationS == before.timeS) {
      throw const PneumaticPhysicsException(
        'step_underflow',
        'Time cannot advance at the supplied precision.',
      );
    }
    double remaining = durationS;
    double mass = before.chamber.massKg;
    double externalMass = before.externalMassAddedKg;
    int count = 0;
    Map<String, double> flows = <String, double>{
      for (final PneumaticPressureBoundary b in boundaries) b.id: 0,
    };
    final double tolerance = durationS * 1e-13;

    while (remaining > tolerance) {
      if (count >= maxSubsteps) {
        throw const PneumaticPhysicsException(
          'substep_limit',
          'No accepted snapshot after bounded solver failure.',
        );
      }
      final FixedAirChamber chamber = before.chamber.withMass(mass);
      final double p = chamber.pressureAbsPa;
      final Map<String, double> instantaneous = <String, double>{};
      double outflow = 0;
      double netFlow = 0;

      for (final PneumaticPressureBoundary boundary in boundaries) {
        double q = 0;
        if (boundary.enabled) {
          q = boundary.orifice.massFlowKgPerS(
            fromPressureAbsPa: boundary.pressureAbsPa,
            toPressureAbsPa: p,
            temperatureK: boundary.pressureAbsPa >= p
                ? boundary.temperatureK
                : chamber.temperatureK,
          );
          if (!boundary.allowReverseFlow && q < 0) q = 0;
        }
        instantaneous[boundary.id] = q;
        netFlow += q;
        if (q < 0) outflow -= q;
      }

      double dt = math.min(remaining, maxStepS);
      if (outflow > 0) {
        dt = math.min(dt, .2 * mass / outflow);
      }
      if (!dt.isFinite || dt <= 0) {
        throw const PneumaticPhysicsException(
          'step_underflow',
          'The pressure-flow system cannot advance safely.',
        );
      }
      final double delta = netFlow * dt;
      final double nextMass = mass + delta;
      if (!nextMass.isFinite || nextMass <= 0) {
        throw const PneumaticPhysicsException(
          'negative_or_nonfinite_mass',
          'Solver rejected an invalid air mass.',
        );
      }
      mass = nextMass;
      externalMass += delta;
      flows = instantaneous;
      remaining -= dt;
      count++;
    }
    return OpenAirSnapshot(
      timeS: before.timeS + durationS,
      chamber: before.chamber.withMass(mass),
      externalMassAddedKg: externalMass,
      acceptedSubsteps: before.acceptedSubsteps + count,
      signedBoundaryFlowsKgPerS: flows,
    );
  }

  /// Closed+open accounting: m(t)-m(0) must equal integrated external flow.
  double massBalanceResidualKg(OpenAirSnapshot snapshot) =>
      snapshot.chamber.massKg -
      initialSnapshot.chamber.massKg -
      snapshot.externalMassAddedKg;
}
