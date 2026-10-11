import 'dart:math' as math;

import 'package:electrosim_pneumatic_solver/electrosim_pneumatic_solver.dart';

/// An independently generated, fully connected, calibrated closed-air graph.
/// Every requested fitting is one physical gas volume, and every neighboring
/// pair is linked by an explicit calibrated passage. This benchmark does NOT
/// represent a 400-widget Flutter interaction or a complete 5/2 workshop.
final class R6PhysicalScaleCase {
  R6PhysicalScaleCase(this.fittingCount) : solver = _create(fittingCount) {
    if (fittingCount < 2 || fittingCount > 10000) {
      throw ArgumentError.value(
        fittingCount,
        'fittingCount',
        'The R6 fixture supports 2 to 10000 physical volumes.',
      );
    }
  }

  final int fittingCount;
  final IsothermalAirNetwork solver;

  int get passageCount => fittingCount - 1;

  static IsothermalAirNetwork _create(int count) {
    if (count < 2 || count > 10000) {
      throw ArgumentError.value(
        count,
        'fittingCount',
        'The R6 fixture supports 2 to 10000 physical volumes.',
      );
    }
    final IsentropicOrifice calibratedOrifice = IsentropicOrifice(
      effectiveAreaM2: 1e-7,
      dischargeCoefficient: .8,
    );
    return IsothermalAirNetwork(
      chambers: <FixedAirChamber>[
        for (int i = 0; i < count; i++)
          FixedAirChamber.fromPressure(
            id: 'fitting.$i',
            volumeM3: .002,
            pressureAbsPa: 200000 + 25000 * (i % 5),
          ),
      ],
      passages: <AirPassage>[
        for (int i = 1; i < count; i++)
          AirPassage(
            id: 'passage.$i',
            firstChamberId: 'fitting.${i - 1}',
            secondChamberId: 'fitting.$i',
            orifice: calibratedOrifice,
          ),
      ],
    );
  }

  /// Pure deterministic physics verification. No wall-clock time is used here.
  IsothermalAirSnapshot simulate({
    double durationS = .04,
    double maxStepS = .004,
  }) {
    final IsothermalAirSnapshot initial = solver.initialSnapshot;
    final IsothermalAirSnapshot accepted = solver.advance(
      initial,
      durationS: durationS,
      maxStepS: maxStepS,
    );
    if (accepted.chambers.length != fittingCount ||
        accepted.passageMassFlowKgPerS.length != passageCount ||
        accepted.timeS != durationS ||
        accepted.acceptedSubsteps < 1) {
      throw StateError('R6 scale case did not accept a complete gas snapshot');
    }
    final double total = initial.totalMassKg;
    final double residual = (accepted.totalMassKg - total).abs();
    final double tolerance = math.max(1e-11, total * 1e-9);
    if (!accepted.totalMassKg.isFinite || residual > tolerance) {
      throw StateError(
        'R6 closed gas mass is not conserved: residual=$residual '
        'tolerance=$tolerance',
      );
    }
    for (final FixedAirChamber chamber in accepted.chambers.values) {
      if (!chamber.massKg.isFinite ||
          chamber.massKg <= 0 ||
          !chamber.pressureAbsPa.isFinite) {
        throw StateError('R6 physical element became nonfinite');
      }
    }
    if (initial.timeS != 0) {
      throw StateError('R6 benchmark mutated its input snapshot');
    }
    return accepted;
  }
}
