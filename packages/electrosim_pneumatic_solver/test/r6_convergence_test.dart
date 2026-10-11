import 'package:electrosim_pneumatic_solver/electrosim_pneumatic_solver.dart';
import 'package:test/test.dart';

/// PHY-07 R6 step-halving check with physically connected 5/2 actuation.
/// The tolerance is normalized to full stroke or upstream absolute pressure;
/// it must not be relaxed merely to satisfy a regression.
void main() {
  test('PHY-07: halving max physical step changes state by at most 1%', () {
    final IsentropicOrifice orifice = IsentropicOrifice(
      effectiveAreaM2: 1e-6,
      dischargeCoefficient: .8,
    );
    final MovingDoubleActingAirCylinder cylinder =
        MovingDoubleActingAirCylinder.fromPressure(
          geometry: DoubleActingCylinderGeometry(
            pistonDiameterM: .032,
            rodDiameterM: .008,
            strokeM: .1,
            deadVolumeAM3: .0005,
            deadVolumeBM3: .0005,
          ),
          mechanics: CylinderMechanicalCalibration(
            movingMassKg: 1,
            externalLoadN: 5,
            viscousNsPerM: 2,
            coulombFrictionN: 1,
            staticBreakawayFrictionN: 2,
          ),
          initialPositionM: .03,
          initialPressureAAbsPa: 201325,
          initialPressureBAbsPa: 201325,
        );
    final Valve52CylinderRouting routing = Valve52CylinderRouting(
      supplyA: PneumaticPressureBoundary(
        id: 'P.A',
        pressureAbsPa: 701325,
        orifice: orifice,
      ),
      supplyB: PneumaticPressureBoundary(
        id: 'P.B',
        pressureAbsPa: 701325,
        orifice: orifice,
      ),
      exhaustA: PneumaticPressureBoundary(
        id: 'A.R',
        pressureAbsPa: 101325,
        orifice: orifice,
      ),
      exhaustB: PneumaticPressureBoundary(
        id: 'B.S',
        pressureAbsPa: 101325,
        orifice: orifice,
      ),
    );
    final MovingDoubleActingAirCylinder extended = routing.connect(
      cylinder: cylinder,
      snapshot: cylinder.initialSnapshot,
      energized: true,
    );
    const double durationS = .02;
    final MovingCylinderSnapshot coarse = extended.advance(
      cylinder.initialSnapshot,
      durationS: durationS,
      maxStepS: .001,
    );
    final MovingCylinderSnapshot fine = extended.advance(
      cylinder.initialSnapshot,
      durationS: durationS,
      maxStepS: .0005,
    );
    expect(coarse.acceptedSubsteps, lessThan(fine.acceptedSubsteps));
    expect(coarse.timeS, closeTo(durationS, 1e-10));
    expect(fine.timeS, closeTo(durationS, 1e-10));
    expect(
      (fine.positionM - coarse.positionM).abs() / cylinder.geometry.strokeM,
      lessThanOrEqualTo(.01),
    );
    expect(
      (extended.pressureAAbsPa(fine) - extended.pressureAAbsPa(coarse)).abs() /
          701325,
      lessThanOrEqualTo(.01),
    );
    expect(
      (extended.pressureBAbsPa(fine) - extended.pressureBAbsPa(coarse)).abs() /
          701325,
      lessThanOrEqualTo(.01),
    );
    expect(extended.massResidualKg(coarse).abs(), lessThan(1e-9));
    expect(extended.massResidualKg(fine).abs(), lessThan(1e-9));
    expect(cylinder.initialSnapshot.timeS, 0);
    expect(cylinder.initialSnapshot.positionM, .03);
  });
}
