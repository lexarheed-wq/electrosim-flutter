import 'package:electrosim_electropneumatic/electrosim_electropneumatic.dart';
import 'package:electrosim_pneumatic_solver/electrosim_pneumatic_solver.dart';
import 'package:test/test.dart';

import 'r3_self_hold_test.dart' as fixture;

void main() {
  test('R3/D: accepted relay, coil, spool and air share one timestamp', () {
    final IsentropicOrifice orifice = IsentropicOrifice(
      effectiveAreaM2: 1e-6,
      dischargeCoefficient: .8,
    );
    PneumaticPressureBoundary boundary(String id, double pressure) =>
        PneumaticPressureBoundary(
          id: id,
          pressureAbsPa: pressure,
          orifice: orifice,
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
          initialPositionM: .01,
          initialPressureAAbsPa: 101325,
          initialPressureBAbsPa: 101325,
        );
    final SelfHoldValve52Cycle cycle = SelfHoldValve52Cycle(
      electrical: fixture.bench(),
      cylinder: cylinder,
      routing: Valve52CylinderRouting(
        supplyA: boundary('supplyA', 701325),
        supplyB: boundary('supplyB', 701325),
        exhaustA: boundary('exhaustA', 101325),
        exhaustB: boundary('exhaustB', 101325),
      ),
      endSensor: PositionEndContact(
        strokeM: .1,
        triggerPositionM: .099,
        releasePositionM: .095,
        normallyOpen: false,
      ),
      solenoid: Solenoid24vDynamics(Solenoid24vCalibration()),
    );

    final SelfHoldValve52Snapshot initial = cycle.initial();
    final SelfHoldValve52Snapshot pressed = cycle.advance(
      initial,
      durationS: 0,
      startPressed: true,
    );
    expect(pressed.timeS, 0);
    expect(pressed.electrical!.relay.energized, isTrue);
    expect(pressed.electrical!.valveReading.voltageV, closeTo(24, 1e-9));
    expect(pressed.physical.pneumaticAdvances, 0);
    expect(pressed.air.gasMassKg, initial.air.gasMassKg);

    final SelfHoldValve52Snapshot latched = cycle.advance(
      pressed,
      durationS: .025,
      startPressed: false,
    );
    expect(latched.timeS, closeTo(.025, 1e-10));
    expect(latched.physical.air.timeS, latched.timeS);
    expect(latched.electrical!.relay.energized, isTrue);
    expect(latched.physical.coil.energized, isTrue);
    expect(latched.spool, ValveSpoolSide.coilSide);
    expect(latched.physical.pneumaticAdvances, greaterThan(0));
    expect(cycle.massResidualKg(latched).abs(), lessThan(1e-9));

    final SelfHoldValve52Snapshot paused = cycle.advance(
      latched,
      durationS: .1,
      startPressed: false,
      paused: true,
    );
    expect(identical(paused, latched), isTrue);

    final SelfHoldValve52Snapshot isolated = cycle.advance(
      latched,
      durationS: .005,
      startPressed: false,
      airSupplyEnabled: false,
    );
    expect(isolated.timeS, closeTo(.03, 1e-10));
    expect(isolated.physical.air.timeS, isolated.timeS);
    expect(isolated.electrical!.relay.energized, isTrue);
    expect(cycle.massResidualKg(isolated).abs(), lessThan(1e-9));
    expect(initial.timeS, 0);
    expect(initial.air.gasMassKg, cylinder.initialSnapshot.gasMassKg);
  });
}
