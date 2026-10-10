import 'package:electrosim_electropneumatic/electrosim_electropneumatic.dart';
import 'package:electrosim_pneumatic_solver/electrosim_pneumatic_solver.dart';
import 'package:test/test.dart';

void main() {
  test('R4: physical telemetry samples exactly match accepted cylinder SI', () {
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
          initialPositionM: .02,
          initialPressureAAbsPa: 701325,
          initialPressureBAbsPa: 101325,
        );
    final MovingCylinderSnapshot state = cylinder.initialSnapshot;
    final SelfHoldValve52Snapshot accepted = SelfHoldValve52Snapshot(
      physical: CoupledRuntimeSnapshot<MovingCylinderSnapshot>(
        timeS: state.timeS,
        air: state,
        coil: const Solenoid24vSnapshot(
          energized: false,
          measuredVoltageV: 0,
        ),
        spool: ValveSpoolSide.springSide,
        endContactActuated: false,
        electricalSolves: 0,
        pneumaticAdvances: 0,
      ),
    );
    final PneumaticCylinderTelemetry sample = PneumaticTelemetryReader.cylinder(
      model: cylinder,
      accepted: accepted,
    );
    expect(sample.timeS, 0);
    expect(sample.pressureAAbsPa, closeTo(701325, 1e-8));
    expect(sample.pressureBAbsPa, closeTo(101325, 1e-8));
    expect(sample.pressureAGaugeBar, closeTo(6, 1e-10));
    expect(sample.positionMm, closeTo(20, 1e-12));
    expect(sample.forceN, closeTo(
      cylinder.geometry.theoreticalForceN(
        pressureAAbsPa: 701325,
        pressureBAbsPa: 101325,
      ), 1e-8,
    ));
    expect(sample.massResidualKg.abs(), lessThan(1e-12));
  });

  test('R4: telemetry history bounds memory and rejects time reversal', () {
    final PneumaticTelemetrySeries series = PneumaticTelemetrySeries(capacity: 2);
    PneumaticCylinderTelemetry sample(double t) => PneumaticCylinderTelemetry(
      timeS: t,
      pressureAAbsPa: 101325,
      pressureBAbsPa: 101325,
      positionM: 0,
      velocityMPerS: 0,
      forceN: 0,
      totalGasMassKg: .01,
      externalMassAddedKg: 0,
      massResidualKg: 0,
      commutedSpool: ValveSpoolSide.springSide,
      endStopActuated: false,
    );
    series.record(sample(0));
    series.record(sample(.1));
    series.record(sample(.1));
    expect(series.samples.length, 2);
    series.record(sample(.2));
    expect(series.samples.length, 2);
    expect(series.samples.first.timeS, .1);
    expect(series.samples.last.timeS, .2);
    expect(
      () => series.record(sample(.15)),
      throwsA(isA<ElectropneumaticRuntimeException>()),
    );
    series.reset();
    expect(series.samples, isEmpty);
  });
}
