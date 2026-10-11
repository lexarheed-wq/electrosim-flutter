import 'package:electrosim_electropneumatic/electrosim_electropneumatic.dart';
import 'package:electrosim_pneumatic_solver/electrosim_pneumatic_solver.dart';
import 'package:test/test.dart';

import 'r3_self_hold_test.dart' as dc;

SelfHoldValve52Cycle _buildCycle() {
  final IsentropicOrifice orifice = IsentropicOrifice(
    effectiveAreaM2: 3e-6,
    dischargeCoefficient: .8,
  );
  PneumaticPressureBoundary boundary(String name, double pressureAbsPa) =>
      PneumaticPressureBoundary(
        id: name,
        pressureAbsPa: pressureAbsPa,
        orifice: orifice,
      );
  const double stroke = .06;
  return SelfHoldValve52Cycle(
    electrical: dc.bench(),
    cylinder: MovingDoubleActingAirCylinder.fromPressure(
      geometry: DoubleActingCylinderGeometry(
        pistonDiameterM: .032,
        rodDiameterM: .008,
        strokeM: stroke,
        deadVolumeAM3: .0005,
        deadVolumeBM3: .0005,
      ),
      mechanics: CylinderMechanicalCalibration(
        movingMassKg: 1,
        staticBreakawayFrictionN: 3,
        coulombFrictionN: 2,
      ),
      initialPositionM: .005,
      initialPressureAAbsPa: 101325,
      initialPressureBAbsPa: 101325,
    ),
    routing: Valve52CylinderRouting(
      supplyA: boundary('P.to.A', 701325),
      supplyB: boundary('P.to.B', 701325),
      exhaustA: boundary('A.to.R', 101325),
      exhaustB: boundary('B.to.S', 101325),
    ),
    endSensor: PositionEndContact(
      strokeM: stroke,
      triggerPositionM: .059,
      releasePositionM: .055,
      normallyOpen: false,
    ),
    solenoid: Solenoid24vDynamics(Solenoid24vCalibration()),
    maxStepS: .00075,
  );
}

void main() {
  test('R6/CPL-01: actual 24V S1/K1/B1 drives 5/2 to sensor and drops hold', () {
    final SelfHoldValve52Cycle cycle = _buildCycle();
    final SelfHoldValve52Snapshot before = cycle.initial();
    final SelfHoldValve52Snapshot pressed = cycle.advance(
      before,
      durationS: 0,
      startPressed: true,
    );
    expect(pressed.electrical!.relay.energized, true);
    expect(pressed.electrical!.valveReading.voltageV, closeTo(24, 1e-9));
    expect(pressed.air.gasMassKg, before.air.gasMassKg);

    SelfHoldValve52Snapshot state = cycle.advance(
      pressed,
      durationS: .025,
      startPressed: false,
    );
    expect(state.electrical!.relay.energized, true);
    expect(state.spool, ValveSpoolSide.coilSide);

    bool trip = false;
    for (int i = 0; i < 130; i++) {
      final SelfHoldValve52Snapshot next = cycle.advance(
        state,
        durationS: .005,
        startPressed: false,
      );
      expect(next.timeS, greaterThan(state.timeS));
      expect(next.air.timeS, closeTo(next.timeS, 1e-8));
      expect(next.physical.pneumaticAdvances,
          greaterThan(state.physical.pneumaticAdvances));
      expect(cycle.massResidualKg(next).abs(), lessThan(1e-8));
      expect(next.air.positionM, inInclusiveRange(0, .06));
      state = next;
      if (state.endStopActuated) {
        trip = true;
        expect(state.electrical!.relay.energized, false);
        expect(state.electrical!.valveReading.voltageV, closeTo(0, 1e-8));
        break;
      }
    }

    expect(trip, true,
        reason: 'The real moving piston must trigger B1 NC before timeout.');
    final SelfHoldValve52Snapshot paused = cycle.advance(
      state,
      durationS: .05,
      startPressed: false,
      paused: true,
    );
    expect(identical(paused, state), true);
    expect(cycle.massResidualKg(state).abs(), lessThan(1e-8));
    expect(before.timeS, 0);
    expect(before.air.positionM, .005);
  });
}
