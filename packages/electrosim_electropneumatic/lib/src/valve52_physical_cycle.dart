import 'package:electrosim_pneumatic_solver/electrosim_pneumatic_solver.dart';

import 'coupled_clock.dart';
import 'dc_coil_meter.dart';
import 'solenoid_actuator.dart';

/// Concrete adapter: a single accepted physical cylinder snapshot and a
/// single clock are shared by the DC control and the pneumatic solver.
final class Valve52PhysicalCycle {
  Valve52PhysicalCycle({
    required this.cylinder,
    required this.routing,
    required this.solveElectrical,
    required this.solenoid,
    required this.valveMemory,
    this.endSensor,
    this.maxStepS = .001,
  });

  final MovingDoubleActingAirCylinder cylinder;
  final Valve52CylinderRouting routing;
  final SolveCoilAt<MovingCylinderSnapshot> solveElectrical;
  final Solenoid24vDynamics solenoid;
  final SingleCoilValveMemory valveMemory;
  final PositionEndContact? endSensor;
  final double maxStepS;

  late final ElectropneumaticEventClock<MovingCylinderSnapshot> _clock =
      ElectropneumaticEventClock<MovingCylinderSnapshot>(
        solenoid: solenoid,
        valveMemory: valveMemory,
        solveElectrical: solveElectrical,
        airTime: (MovingCylinderSnapshot s) => s.timeS,
        cylinderPosition: endSensor == null ? null : (MovingCylinderSnapshot s) => s.positionM,
        positionSensor: endSensor,
        maxStepS: maxStepS,
        advanceAir: (MovingCylinderSnapshot before, double dt, ValveSpoolSide spool) {
          final MovingDoubleActingAirCylinder routed = routing.connect(
            cylinder: cylinder,
            snapshot: before,
            energized: spool == ValveSpoolSide.coilSide,
          );
          return routed.advance(before, durationS: dt, stopAtFirstImpact: true);
        },
      );

  CoupledRuntimeSnapshot<MovingCylinderSnapshot> initial() =>
      _clock.initial(cylinder.initialSnapshot);

  CoupledRuntimeSnapshot<MovingCylinderSnapshot> advance(
    CoupledRuntimeSnapshot<MovingCylinderSnapshot> before, {
    required double durationS,
  }) => _clock.advance(before, durationS: durationS);

  double massResidualKg(MovingCylinderSnapshot state) =>
      cylinder.massResidualKg(state);
}
