import 'dart:math' as math;

import 'ideal_gas.dart';
import 'open_boundary.dart';

/// A finite isothermal compressed-air receiver. Unlike an ideal supply,
/// tank pressure falls as mass leaves. Positive outlet flow consumes mass.
/// Compression heat, compressor duty cycle and regulator spool mechanics are
/// deliberately outside this R5/A physical model.
final class FiniteReceiverSnapshot {
  FiniteReceiverSnapshot({
    required this.timeS,
    required this.massKg,
    required this.integratedInletKg,
    required this.integratedOutletKg,
    required this.acceptedSubsteps,
  }) {
    requireNonnegativeFinite(timeS, 'timeS');
    requirePositiveFinite(massKg, 'massKg');
    if (!integratedInletKg.isFinite ||
        !integratedOutletKg.isFinite ||
        acceptedSubsteps < 0) {
      throw const PneumaticPhysicsException(
        'invalid_receiver_snapshot',
        'Receiver exchange ledger must be finite.',
      );
    }
  }

  final double timeS;
  final double massKg;
  final double integratedInletKg;
  final double integratedOutletKg;
  final int acceptedSubsteps;
}

/// Lumped finite reservoir supplied through an optional refill boundary and
/// discharging through a compressible orifice into a prescribed load pressure.
/// All boundary flows are evaluated from the same accepted tank pressure.
final class FiniteIsothermalAirReceiver {
  FiniteIsothermalAirReceiver({
    required this.volumeM3,
    required double initialPressureAbsPa,
    required this.outletOrifice,
    this.refill,
    this.temperatureK = DryAirReference.temperatureK,
  }) : initialSnapshot = FiniteReceiverSnapshot(
         timeS: 0,
         massKg: IsothermalAir.massKg(
           pressureAbsPa: initialPressureAbsPa,
           volumeM3: volumeM3,
           temperatureK: temperatureK,
         ),
         integratedInletKg: 0,
         integratedOutletKg: 0,
         acceptedSubsteps: 0,
       ) {
    requirePositiveFinite(volumeM3, 'volumeM3');
    requirePositiveFinite(temperatureK, 'temperatureK');
  }

  final double volumeM3;
  final double temperatureK;
  final IsentropicOrifice outletOrifice;
  final PneumaticPressureBoundary? refill;
  final FiniteReceiverSnapshot initialSnapshot;

  double pressureAbsPa(FiniteReceiverSnapshot snapshot) =>
      IsothermalAir.pressureAbsPa(
        massKg: snapshot.massKg,
        volumeM3: volumeM3,
        temperatureK: temperatureK,
      );

  /// m(t)-m(0) = integrated refill - integrated delivered gas.
  double massResidualKg(FiniteReceiverSnapshot snapshot) =>
      snapshot.massKg -
      initialSnapshot.massKg -
      snapshot.integratedInletKg +
      snapshot.integratedOutletKg;

  FiniteReceiverSnapshot advance(
    FiniteReceiverSnapshot before, {
    required double durationS,
    required double loadPressureAbsPa,
    bool outletOpen = true,
    bool allowLoadReturn = false,
    double maxStepS = .001,
    int maxSubsteps = 200000,
  }) {
    requireNonnegativeFinite(durationS, 'durationS');
    requirePositiveFinite(loadPressureAbsPa, 'loadPressureAbsPa');
    requirePositiveFinite(maxStepS, 'maxStepS');
    if (maxSubsteps <= 0 ||
        (durationS > 0 && before.timeS + durationS == before.timeS)) {
      throw const PneumaticPhysicsException(
        'invalid_receiver_step',
        'Receiver step must have a positive finite budget.',
      );
    }
    if (durationS == 0) return before;

    double remaining = durationS;
    double mass = before.massKg;
    double inletKg = before.integratedInletKg;
    double outletKg = before.integratedOutletKg;
    int steps = 0;
    final double tolerance = durationS * 1e-13;
    while (remaining > tolerance) {
      if (steps >= maxSubsteps) {
        throw const PneumaticPhysicsException(
          'receiver_substep_limit',
          'Finite receiver did not accept the requested time interval.',
        );
      }
      final double tankPressure = IsothermalAir.pressureAbsPa(
        massKg: mass,
        volumeM3: volumeM3,
        temperatureK: temperatureK,
      );
      double qOut = 0;
      if (outletOpen) {
        qOut = outletOrifice.massFlowKgPerS(
          fromPressureAbsPa: tankPressure,
          toPressureAbsPa: loadPressureAbsPa,
          temperatureK: temperatureK,
        );
        if (qOut < 0 && !allowLoadReturn) qOut = 0;
      }
      double qIn = 0;
      if (refill != null && refill!.enabled) {
        qIn = refill!.orifice.massFlowKgPerS(
          fromPressureAbsPa: refill!.pressureAbsPa,
          toPressureAbsPa: tankPressure,
          temperatureK: refill!.pressureAbsPa >= tankPressure
              ? refill!.temperatureK
              : temperatureK,
        );
        if (qIn < 0 && !refill!.allowReverseFlow) qIn = 0;
      }
      final double net = qIn - qOut;
      double dt = math.min(remaining, maxStepS);
      if (net < 0) dt = math.min(dt, .2 * mass / -net);
      if (!dt.isFinite || dt <= 0 || before.timeS + dt == before.timeS) {
        throw const PneumaticPhysicsException(
          'receiver_time_underflow',
          'Receiver cannot advance a finite positive step.',
        );
      }
      final double nextMass = mass + net * dt;
      if (!nextMass.isFinite || nextMass <= 0) {
        throw const PneumaticPhysicsException(
          'receiver_negative_mass',
          'Reservoir mass cannot become zero, negative or nonfinite.',
        );
      }
      mass = nextMass;
      inletKg += qIn * dt;
      outletKg += qOut * dt;
      remaining -= dt;
      steps++;
    }
    return FiniteReceiverSnapshot(
      timeS: before.timeS + durationS,
      massKg: mass,
      integratedInletKg: inletKg,
      integratedOutletKg: outletKg,
      acceptedSubsteps: before.acceptedSubsteps + steps,
    );
  }
}
