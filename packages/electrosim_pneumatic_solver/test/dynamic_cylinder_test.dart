import 'package:electrosim_pneumatic_solver/electrosim_pneumatic_solver.dart';
import 'package:test/test.dart';

DoubleActingCylinderGeometry geometry({
  double stroke = .1,
  double deadVolume = .0005,
}) => DoubleActingCylinderGeometry(
  pistonDiameterM: .032,
  rodDiameterM: .008,
  strokeM: stroke,
  deadVolumeAM3: deadVolume,
  deadVolumeBM3: deadVolume,
);

CylinderMechanicalCalibration mechanics({
  double massKg = 1,
  double loadN = 0,
  double kineticFrictionN = 0,
  double breakawayN = 0,
}) => CylinderMechanicalCalibration(
  movingMassKg: massKg,
  externalLoadN: loadN,
  coulombFrictionN: kineticFrictionN,
  staticBreakawayFrictionN: breakawayN,
);

void main() {
  group('R2/D physically moving two-chamber cylinder', () {
    test(
      'PHY-06: fixed gas masses; pressure responds to real changing volume',
      () {
        final MovingDoubleActingAirCylinder sim =
            MovingDoubleActingAirCylinder.fromPressure(
              geometry: geometry(),
              mechanics: mechanics(),
              initialPositionM: .02,
              initialPressureAAbsPa: 701325,
              initialPressureBAbsPa: 101325,
            );
        final MovingCylinderSnapshot start = sim.initialSnapshot;
        expect(sim.mechanicalResultantN(start), closeTo(482.5486315913922, .6));
        final MovingCylinderSnapshot next = sim.advance(start, durationS: .001);
        expect(next.timeS, closeTo(.001, 1e-12));
        expect(next.positionM, greaterThan(start.positionM));
        expect(next.massAKg, start.massAKg);
        expect(next.massBKg, start.massBKg);
        expect(sim.pressureAAbsPa(next), lessThan(sim.pressureAAbsPa(start)));
        expect(
          sim.pressureBAbsPa(next),
          greaterThan(sim.pressureBAbsPa(start)),
        );
        expect(sim.massResidualKg(next).abs(), lessThan(1e-12));
        expect(start.positionM, .02);
      },
    );

    test('PHY-07: physical end-stop is timestamped, never overrun', () {
      final MovingDoubleActingAirCylinder sim =
          MovingDoubleActingAirCylinder.fromPressure(
            geometry: geometry(deadVolume: .01),
            mechanics: mechanics(loadN: -200),
            initialPositionM: 0,
            initialPressureAAbsPa: 101325,
            initialPressureBAbsPa: 101325,
          );
      final MovingCylinderSnapshot end = sim.advance(
        sim.initialSnapshot,
        durationS: .07,
      );
      expect(end.positionM, closeTo(.1, 1e-10));
      expect(end.velocityMPerS, 0);
      expect(end.stopEvents, hasLength(1));
      expect(end.stopEvents.single.stop, CylinderStop.extended);
      expect(end.stopEvents.single.timeS, greaterThan(0));
      expect(end.stopEvents.single.timeS, lessThan(.07));
      expect(end.timeS, closeTo(.07, 1e-12));
      expect(sim.massResidualKg(end).abs(), lessThan(1e-12));
      final MovingCylinderSnapshot held = sim.advance(end, durationS: .05);
      expect(held.positionM, .1);
      expect(held.velocityMPerS, 0);
      expect(held.stopEvents, hasLength(1));
    });

    test(
      'PHY-06: opening A and venting B conserves the external mass ledger',
      () {
        final IsentropicOrifice orifice = IsentropicOrifice(
          effectiveAreaM2: 1e-6,
          dischargeCoefficient: .8,
        );
        final MovingDoubleActingAirCylinder sim =
            MovingDoubleActingAirCylinder.fromPressure(
              geometry: geometry(),
              mechanics: mechanics(massKg: 2),
              initialPositionM: .04,
              initialPressureAAbsPa: 201325,
              initialPressureBAbsPa: 201325,
              aBoundaries: <PneumaticPressureBoundary>[
                PneumaticPressureBoundary(
                  id: 'supplyA',
                  pressureAbsPa: 701325,
                  orifice: orifice,
                  allowReverseFlow: false,
                ),
              ],
              bBoundaries: <PneumaticPressureBoundary>[
                PneumaticPressureBoundary(
                  id: 'exhaustB',
                  pressureAbsPa: 101325,
                  orifice: orifice,
                ),
              ],
            );
        final MovingCylinderSnapshot after = sim.advance(
          sim.initialSnapshot,
          durationS: .03,
        );
        expect(after.timeS, closeTo(.03, 1e-12));
        expect(after.externalMassAddedAKg, greaterThan(0));
        expect(after.externalMassAddedBKg, lessThan(0));
        expect(sim.massResidualKg(after).abs(), lessThan(1e-10));
        expect(after.positionM, inInclusiveRange(0, .1));
        expect(after.acceptedSubsteps, greaterThan(1));
      },
    );

    test('PHY-06: static friction prevents phantom actuator movement', () {
      final MovingDoubleActingAirCylinder sim =
          MovingDoubleActingAirCylinder.fromPressure(
            geometry: geometry(),
            mechanics: mechanics(kineticFrictionN: 10, breakawayN: 20),
            initialPositionM: .02,
            initialPressureAAbsPa: 101325,
            initialPressureBAbsPa: 101325,
          );
      final MovingCylinderSnapshot after = sim.advance(
        sim.initialSnapshot,
        durationS: .1,
      );
      expect(after.positionM, .02);
      expect(after.velocityMPerS, 0);
      expect(after.gasMassKg, sim.initialSnapshot.gasMassKg);
    });

    test('ERR: malformed friction, parameters and bounded step reject', () {
      expect(
        () => mechanics(kineticFrictionN: 20, breakawayN: 10),
        throwsA(isA<PneumaticPhysicsException>()),
      );
      final MovingDoubleActingAirCylinder sim =
          MovingDoubleActingAirCylinder.fromPressure(
            geometry: geometry(),
            mechanics: mechanics(),
            initialPositionM: .01,
            initialPressureAAbsPa: 701325,
            initialPressureBAbsPa: 101325,
          );
      expect(
        () => sim.advance(sim.initialSnapshot, durationS: 1, maxSubsteps: 1),
        throwsA(
          isA<PneumaticPhysicsException>().having(
            (e) => e.code,
            'code',
            'substep_limit',
          ),
        ),
      );
      expect(sim.initialSnapshot.positionM, .01);
      expect(sim.initialSnapshot.acceptedSubsteps, 0);
    });

    test(
      'PHY-07: identical fixed solver inputs give identical stop chronology',
      () {
        final MovingDoubleActingAirCylinder sim =
            MovingDoubleActingAirCylinder.fromPressure(
              geometry: geometry(deadVolume: .01),
              mechanics: mechanics(loadN: -200),
              initialPositionM: 0,
              initialPressureAAbsPa: 101325,
              initialPressureBAbsPa: 101325,
            );
        final a = sim.advance(sim.initialSnapshot, durationS: .06);
        final b = sim.advance(sim.initialSnapshot, durationS: .06);
        expect(a.positionM, b.positionM);
        expect(a.velocityMPerS, b.velocityMPerS);
        expect(a.massAKg, b.massAKg);
        expect(a.massBKg, b.massBKg);
        expect(a.stopEvents.single.timeS, b.stopEvents.single.timeS);
        expect(a.stopEvents.single.stop, b.stopEvents.single.stop);
      },
    );
  });
}
