import 'package:electrosim_electropneumatic/electrosim_electropneumatic.dart';
import 'package:electrosim_pneumatic_solver/electrosim_pneumatic_solver.dart';
import 'package:test/test.dart';

void main() {
  final IsentropicOrifice orifice = IsentropicOrifice(
    effectiveAreaM2: 1e-6,
    dischargeCoefficient: .8,
  );
  PneumaticPressureBoundary boundary(String id, double p) =>
      PneumaticPressureBoundary(
        id: id,
        pressureAbsPa: p,
        orifice: orifice,
      );
  final Valve52CylinderRouting routing = Valve52CylinderRouting(
    supplyA: boundary('sourceA', 701325),
    supplyB: boundary('sourceB', 701325),
    exhaustA: boundary('exhaustR', 101325),
    exhaustB: boundary('exhaustS', 101325),
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
        mechanics: CylinderMechanicalCalibration(movingMassKg: 1),
        initialPositionM: .05,
        initialPressureAAbsPa: 201325,
        initialPressureBAbsPa: 201325,
      );

  test('R5/B blocked exhaust preserves trapped chamber rather than venting', () {
    final Valve52FaultProfile fault = Valve52FaultProfile(
      blockedExhaustR: true,
      stuckSpoolAt: ValveSpoolSide.springSide,
    );
    final MovingDoubleActingAirCylinder routed = fault.connect(
      cylinder: cylinder,
      snapshot: cylinder.initialSnapshot,
      routing: routing,
      commandedSpool: ValveSpoolSide.coilSide,
      supplyEnabled: true,
    );
    expect(fault.effectiveSpool(ValveSpoolSide.coilSide),
        ValveSpoolSide.springSide);
    expect(routed.aBoundaries.single.id, 'exhaustR');
    expect(routed.aBoundaries.single.enabled, isFalse);
    expect(routed.bBoundaries.single.id, 'sourceB');
    final MovingCylinderSnapshot after = routed.advance(
      cylinder.initialSnapshot,
      durationS: .001,
    );
    expect(after.timeS, closeTo(.001, 1e-12));
    expect(routed.massResidualKg(after).abs(), lessThan(1e-11));
  });

  test('R5/B independent leakage adds an ambient gas path', () {
    final Valve52FaultProfile fault = Valve52FaultProfile(
      leakA: boundary('sealLeakA', 101325),
    );
    final MovingDoubleActingAirCylinder routed = fault.connect(
      cylinder: cylinder,
      snapshot: cylinder.initialSnapshot,
      routing: routing,
      commandedSpool: ValveSpoolSide.coilSide,
      supplyEnabled: true,
    );
    expect(routed.aBoundaries.map((b) => b.id),
        containsAll(<String>['sourceA', 'sealLeakA']));
    expect(routed.bBoundaries.single.id, 'exhaustS');
    final MovingCylinderSnapshot after = routed.advance(
      cylinder.initialSnapshot,
      durationS: .001,
    );
    expect(routed.massResidualKg(after).abs(), lessThan(1e-11));
  });

  test('R5/B supply isolation does not disable atmospheric leakage', () {
    final Valve52FaultProfile fault = Valve52FaultProfile(
      leakA: boundary('sealLeakA', 101325),
    );
    final MovingDoubleActingAirCylinder routed = fault.connect(
      cylinder: cylinder,
      snapshot: cylinder.initialSnapshot,
      routing: routing,
      commandedSpool: ValveSpoolSide.coilSide,
      supplyEnabled: false,
    );
    expect(routed.aBoundaries.first.enabled, isFalse);
    expect(routed.aBoundaries.last.enabled, isTrue);
    expect(routed.bBoundaries.single.enabled, isTrue);
  });
}
