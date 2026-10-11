import 'package:electrosim_pneumatic_solver/electrosim_pneumatic_solver.dart';

import 'coupled_clock.dart';
import 'solenoid_actuator.dart';
import 'valve52_fault_profile.dart';

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
    this.faults = const Valve52FaultProfile(),
  });

  final MovingDoubleActingAirCylinder cylinder;
  final Valve52CylinderRouting routing;
  final SolveCoilAt<MovingCylinderSnapshot> solveElectrical;
  final Solenoid24vDynamics solenoid;
  final SingleCoilValveMemory valveMemory;
  final PositionEndContact? endSensor;
  final double maxStepS;
  final Valve52FaultProfile faults;

  /// Actual mechanical spool can differ from the electrical command when jammed.
  ValveSpoolSide effectiveSpool(ValveSpoolSide commanded) =>
      faults.effectiveSpool(commanded);
  bool _supplyEnabled = true;

  /// Closing the upstream valve preserves chamber mass and does not vent air.
  void setAirSupply(bool enabled) => _supplyEnabled = enabled;

  late final ElectropneumaticEventClock<MovingCylinderSnapshot> _clock =
      ElectropneumaticEventClock<MovingCylinderSnapshot>(
        solenoid: solenoid,
        valveMemory: valveMemory,
        solveElectrical: solveElectrical,
        airTime: (MovingCylinderSnapshot s) => s.timeS,
        cylinderPosition: endSensor == null
            ? null
            : (MovingCylinderSnapshot s) => s.positionM,
        positionSensor: endSensor,
        maxStepS: maxStepS,
        advanceAir:
            (MovingCylinderSnapshot before, double dt, ValveSpoolSide spool) {
              final MovingDoubleActingAirCylinder routed = faults.connect(
                cylinder: cylinder,
                snapshot: before,
                routing: routing,
                commandedSpool: spool,
                supplyEnabled: _supplyEnabled,
              );
              return routed.advance(
                before,
                durationS: dt,
                stopAtFirstImpact: true,
              );
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
