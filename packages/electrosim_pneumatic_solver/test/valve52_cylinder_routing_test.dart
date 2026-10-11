import 'package:electrosim_pneumatic_solver/electrosim_pneumatic_solver.dart';
import 'package:test/test.dart';

void main() {
  test(
    'R3/C: 5/2 valve switches supply/exhaust without resetting gas mass',
    () {
      final orifice = IsentropicOrifice(
        effectiveAreaM2: 1e-6,
        dischargeCoefficient: .8,
      );
      PneumaticPressureBoundary boundary(String id, double pressure) =>
          PneumaticPressureBoundary(
            id: id,
            pressureAbsPa: pressure,
            orifice: orifice,
          );
      final routing = Valve52CylinderRouting(
        supplyA: boundary('supplyA', 701325),
        supplyB: boundary('supplyB', 701325),
        exhaustA: boundary('exhaustA', 101325),
        exhaustB: boundary('exhaustB', 101325),
      );
      final cylinder = MovingDoubleActingAirCylinder.fromPressure(
        geometry: DoubleActingCylinderGeometry(
          pistonDiameterM: .032,
          rodDiameterM: .008,
          strokeM: .1,
          deadVolumeAM3: .0005,
          deadVolumeBM3: .0005,
        ),
        mechanics: CylinderMechanicalCalibration(movingMassKg: 1),
        initialPositionM: .05,
        initialPressureAAbsPa: 201325,
        initialPressureBAbsPa: 201325,
      );
      final start = cylinder.initialSnapshot;
      final extended = routing.connect(
        cylinder: cylinder,
        snapshot: start,
        energized: true,
      );
      expect(extended.aBoundaries.single.id, 'supplyA');
      expect(extended.bBoundaries.single.id, 'exhaustB');
      expect(extended.initialSnapshot.massAKg, start.massAKg);
      expect(extended.initialSnapshot.massBKg, start.massBKg);
      final advanced = extended.advance(start, durationS: .001);
      expect(advanced.timeS, closeTo(.001, 1e-12));
      expect(extended.massResidualKg(advanced).abs(), lessThan(1e-12));
      final retracted = routing.connect(
        cylinder: extended,
        snapshot: advanced,
        energized: false,
      );
      expect(retracted.aBoundaries.single.id, 'exhaustA');
      expect(retracted.bBoundaries.single.id, 'supplyB');
      expect(retracted.initialSnapshot.positionM, start.positionM);
      expect(retracted.initialSnapshot.massAKg, start.massAKg);
      expect(retracted.initialSnapshot.massBKg, start.massBKg);
      final reversed = retracted.advance(advanced, durationS: .001);
      expect(reversed.timeS, closeTo(.002, 1e-12));
      expect(retracted.massResidualKg(reversed).abs(), lessThan(1e-12));
    },
  );
}
