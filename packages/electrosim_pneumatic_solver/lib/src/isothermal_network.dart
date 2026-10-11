import 'dart:collection';
import 'dart:math' as math;

import 'ideal_gas.dart';

String _checkedChamberId(String value) {
  if (!RegExp(r'^[A-Za-z0-9][A-Za-z0-9.:-]{0,127}$').hasMatch(value)) {
    throw PneumaticPhysicsException('invalid_id', 'Invalid chamber ID: $value');
  }
  return value;
}

/// A spatially lumped rigid chamber. Valid only for uniform isothermal gas.
final class FixedAirChamber {
  FixedAirChamber({
    required String id,
    required this.volumeM3,
    required this.massKg,
    this.temperatureK = DryAirReference.temperatureK,
  }) : id = _checkedChamberId(id) {
    requirePositiveFinite(volumeM3, 'volumeM3');
    requirePositiveFinite(massKg, 'massKg');
    requirePositiveFinite(temperatureK, 'temperatureK');
  }

  factory FixedAirChamber.fromPressure({
    required String id,
    required double volumeM3,
    required double pressureAbsPa,
    double temperatureK = DryAirReference.temperatureK,
  }) => FixedAirChamber(
    id: id,
    volumeM3: volumeM3,
    massKg: IsothermalAir.massKg(
      volumeM3: volumeM3,
      pressureAbsPa: pressureAbsPa,
      temperatureK: temperatureK,
    ),
    temperatureK: temperatureK,
  );

  final String id;
  final double volumeM3;
  final double massKg;
  final double temperatureK;

  double get pressureAbsPa => IsothermalAir.pressureAbsPa(
    massKg: massKg,
    volumeM3: volumeM3,
    temperatureK: temperatureK,
  );

  FixedAirChamber withMass(double mass) => FixedAirChamber(
    id: id,
    volumeM3: volumeM3,
    massKg: mass,
    temperatureK: temperatureK,
  );
}

final class AirPassage {
  AirPassage({
    required String id,
    required String firstChamberId,
    required String secondChamberId,
    required this.orifice,
    this.reverseFlowAllowed = true,
  }) : id = _checkedChamberId(id),
       firstChamberId = _checkedChamberId(firstChamberId),
       secondChamberId = _checkedChamberId(secondChamberId) {
    if (firstChamberId == secondChamberId) {
      throw const PneumaticPhysicsException(
        'self_connection',
        'Passage must connect different chambers.',
      );
    }
  }

  final String id;
  final String firstChamberId;
  final String secondChamberId;
  final IsentropicOrifice orifice;
  final bool reverseFlowAllowed;
}

/// Snapshot is immutable; simulation does not mutate its input.
final class IsothermalAirSnapshot {
  IsothermalAirSnapshot({
    required this.timeS,
    required Map<String, FixedAirChamber> chambers,
    required Map<String, double> passageMassFlowKgPerS,
    required this.acceptedSubsteps,
  }) : chambers = UnmodifiableMapView<String, FixedAirChamber>(
         Map<String, FixedAirChamber>.from(chambers),
       ),
       passageMassFlowKgPerS = UnmodifiableMapView<String, double>(
         Map<String, double>.from(passageMassFlowKgPerS),
       ) {
    requireNonnegativeFinite(timeS, 'timeS');
  }

  final double timeS;
  final Map<String, FixedAirChamber> chambers;
  final Map<String, double> passageMassFlowKgPerS;
  final int acceptedSubsteps;

  double get totalMassKg => chambers.values.fold<double>(
    0,
    (double a, FixedAirChamber b) => a + b.massKg,
  );
}

/// Conservative Euler flux exchange across closed, fixed-volume compartments.
///
/// All connections are evaluated from the same current state per substep.
/// A rejected step does not publish a partially mutated snapshot.
/// No outside sources/sinks, cylinder motion, thermal changes or pressure
/// regulators are claimed at this R2-A stage.
final class IsothermalAirNetwork {
  IsothermalAirNetwork({
    required List<FixedAirChamber> chambers,
    required List<AirPassage> passages,
  }) : passages = List<AirPassage>.unmodifiable(passages) {
    final Map<String, FixedAirChamber> byId = <String, FixedAirChamber>{};
    for (final FixedAirChamber chamber in chambers) {
      if (byId.containsKey(chamber.id)) {
        throw PneumaticPhysicsException(
          'duplicate_chamber',
          'Duplicate chamber: ${chamber.id}',
        );
      }
      byId[chamber.id] = chamber;
    }
    final Set<String> passageIds = <String>{};
    for (final AirPassage passage in passages) {
      if (!passageIds.add(passage.id)) {
        throw PneumaticPhysicsException(
          'duplicate_passage',
          'Duplicate passage: ${passage.id}',
        );
      }
      if (!byId.containsKey(passage.firstChamberId) ||
          !byId.containsKey(passage.secondChamberId)) {
        throw PneumaticPhysicsException(
          'unknown_chamber',
          'Passage ${passage.id} refers to absent chamber.',
        );
      }
    }
    initialSnapshot = IsothermalAirSnapshot(
      timeS: 0,
      chambers: byId,
      passageMassFlowKgPerS: <String, double>{
        for (final AirPassage passage in passages) passage.id: 0,
      },
      acceptedSubsteps: 0,
    );
  }

  final List<AirPassage> passages;
  late final IsothermalAirSnapshot initialSnapshot;

  IsothermalAirSnapshot advance(
    IsothermalAirSnapshot before, {
    required double durationS,
    double maxStepS = 0.005,
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
    final Set<String> inputIds = before.chambers.keys.toSet();
    if (!inputIds.containsAll(initialSnapshot.chambers.keys) ||
        inputIds.length != initialSnapshot.chambers.length) {
      throw const PneumaticPhysicsException(
        'topology_mismatch',
        'Snapshot chamber identities do not match network.',
      );
    }
    if (durationS == 0) return before;

    Map<String, FixedAirChamber> current = Map<String, FixedAirChamber>.from(
      before.chambers,
    );
    Map<String, double> lastFlow = <String, double>{
      for (final AirPassage passage in passages) passage.id: 0,
    };
    double remaining = durationS;
    int accepted = 0;
    final double toleranceS = durationS * 1e-13;

    while (remaining > toleranceS) {
      if (accepted >= maxSubsteps) {
        throw const PneumaticPhysicsException(
          'substep_limit',
          'Solver exceeded bounded substeps; last accepted snapshot unchanged.',
        );
      }
      final Map<String, double> outgoing = <String, double>{
        for (final String id in current.keys) id: 0,
      };
      final Map<String, double> flow = <String, double>{};
      for (final AirPassage passage in passages) {
        final FixedAirChamber first = current[passage.firstChamberId]!;
        final FixedAirChamber second = current[passage.secondChamberId]!;
        double q = passage.orifice.massFlowKgPerS(
          fromPressureAbsPa: first.pressureAbsPa,
          toPressureAbsPa: second.pressureAbsPa,
          temperatureK: first.pressureAbsPa >= second.pressureAbsPa
              ? first.temperatureK
              : second.temperatureK,
        );
        if (!passage.reverseFlowAllowed && q < 0) q = 0;
        flow[passage.id] = q;
        if (q > 0) {
          outgoing[passage.firstChamberId] =
              outgoing[passage.firstChamberId]! + q;
        } else {
          outgoing[passage.secondChamberId] =
              outgoing[passage.secondChamberId]! - q;
        }
      }
      double dt = math.min(remaining, maxStepS);
      for (final FixedAirChamber chamber in current.values) {
        final double rate = outgoing[chamber.id]!;
        if (rate > 0) {
          dt = math.min(dt, 0.2 * chamber.massKg / rate);
        }
      }
      if (!dt.isFinite || dt <= 0 || before.timeS + durationS == before.timeS) {
        throw const PneumaticPhysicsException(
          'step_underflow',
          'Step underflow or invalid step.',
        );
      }
      final Map<String, double> nextMass = <String, double>{
        for (final FixedAirChamber chamber in current.values)
          chamber.id: chamber.massKg,
      };
      for (final AirPassage passage in passages) {
        final double exchange = flow[passage.id]! * dt;
        nextMass[passage.firstChamberId] =
            nextMass[passage.firstChamberId]! - exchange;
        nextMass[passage.secondChamberId] =
            nextMass[passage.secondChamberId]! + exchange;
      }
      final Map<String, FixedAirChamber> next = <String, FixedAirChamber>{
        for (final FixedAirChamber chamber in current.values)
          chamber.id: chamber.withMass(nextMass[chamber.id]!),
      };
      current = next;
      lastFlow = flow;
      remaining -= dt;
      accepted++;
    }

    return IsothermalAirSnapshot(
      timeS: before.timeS + durationS,
      chambers: current,
      passageMassFlowKgPerS: lastFlow,
      acceptedSubsteps: before.acceptedSubsteps + accepted,
    );
  }
}
