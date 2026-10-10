import 'package:electrosim_pneumatic_solver/electrosim_pneumatic_solver.dart';

import 'coupled_clock.dart';
import 'self_hold_circuit.dart';
import 'solenoid_actuator.dart';
import 'valve52_physical_cycle.dart';
import 'dc_coil_meter.dart';

/// Accepted state of the real DC self-hold and the dynamic two-chamber plant.
/// The relay state is stored in the snapshot, never in a UI callback.
final class SelfHoldValve52Snapshot {
  const SelfHoldValve52Snapshot({
    required this.physical,
    this.electrical,
  });

  final CoupledRuntimeSnapshot<MovingCylinderSnapshot> physical;
  final SelfHold24vSnapshot? electrical;

  double get timeS => physical.timeS;
  MovingCylinderSnapshot get air => physical.air;
  ValveSpoolSide get spool => physical.spool;
  bool get endStopActuated => physical.endContactActuated;
}

/// S1 -> real 24 V nodal solve -> K1 latch/Y1 -> 5/2 -> moving cylinder
/// -> physical B1 NC contact -> real 24 V nodal re-solve.
///
/// The previous relay state is carried by SelfHoldValve52Snapshot. An advance
/// uses a local, discardable relay variable; an exception cannot modify the
/// last accepted state. Each callback can settle DC more than once at one
/// timestamp, but only the common clock advances the gas and mechanics.
final class SelfHoldValve52Cycle {
  SelfHoldValve52Cycle({
    required this.electrical,
    required this.cylinder,
    required this.routing,
    required this.endSensor,
    required this.solenoid,
    this.maxStepS = .001,
    this.valveMemory = const SingleCoilValveMemory(
      returnKind: ValveReturnKind.monostableSpring,
    ),
  }) {
    if (endSensor.normallyOpen ||
        (endSensor.strokeM - cylinder.geometry.strokeM).abs() > 1e-9) {
      throw const ElectropneumaticRuntimeException(
        'invalid_endstop_binding',
        'B1 uses a normally-closed contact on this cylinder stroke.',
      );
    }
  }

  final SelfHold24vElectricalCycle electrical;
  final MovingDoubleActingAirCylinder cylinder;
  final Valve52CylinderRouting routing;
  final PositionEndContact endSensor;
  final Solenoid24vDynamics solenoid;
  final SingleCoilValveMemory valveMemory;
  final double maxStepS;

  SelfHoldValve52Snapshot initial() => SelfHoldValve52Snapshot(
    physical: _newPhysical(
      solve: (air, spool, sensorClosed) => const CoilElectricalReading(
        linkId: '',
        voltageV: 0,
        currentA: 0,
        powerW: 0,
      ),
    ).initial(),
  );

  Valve52PhysicalCycle _newPhysical({
    required SolveCoilAt<MovingCylinderSnapshot> solve,
  }) => Valve52PhysicalCycle(
    cylinder: cylinder,
    routing: routing,
    solveElectrical: solve,
    solenoid: solenoid,
    valveMemory: valveMemory,
    endSensor: endSensor,
    maxStepS: maxStepS,
  );

  /// A paused step returns the accepted state unchanged. Closing air supply
  /// removes only the upstream supply paths, not the exhaust paths.
  SelfHoldValve52Snapshot advance(
    SelfHoldValve52Snapshot before, {
    required double durationS,
    required bool startPressed,
    bool airSupplyEnabled = true,
    bool paused = false,
  }) {
    if (paused) return before;
    Solenoid24vSnapshot relay =
        before.electrical?.relay ??
        const Solenoid24vSnapshot(
          energized: false,
          measuredVoltageV: 0,
        );
    SelfHold24vSnapshot? feedback = before.electrical;

    final Valve52PhysicalCycle plant = _newPhysical(
      solve: (air, spool, sensorClosed) {
        // The event clock derives physical actuation using hysteresis.
        // A normally-closed B1 opens only when the end stop is actuated.
        feedback = electrical.settle(
          timeS: air.timeS,
          startPressed: startPressed,
          endStopActuated: !sensorClosed,
          previousRelay: relay,
        );
        relay = feedback!.relay;
        return feedback!.valveReading;
      },
    );
    plant.setAirSupply(airSupplyEnabled);
    final CoupledRuntimeSnapshot<MovingCylinderSnapshot> accepted =
        plant.advance(before.physical, durationS: durationS);
    return SelfHoldValve52Snapshot(
      physical: accepted,
      electrical: feedback,
    );
  }

  double massResidualKg(SelfHoldValve52Snapshot state) =>
      cylinder.massResidualKg(state.air);
}
