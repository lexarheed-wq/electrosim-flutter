import 'package:electrosim_pneumatic_solver/electrosim_pneumatic_solver.dart';

import 'solenoid_actuator.dart';
import 'valve52_air_isolation.dart';

/// R5/B fault inputs have separate physical meanings.
/// An obstructed exhaust is not the same as an unpowered coil, and a stuck
/// spool does not falsify the electrical measurement of that coil.
final class Valve52FaultProfile {
  const Valve52FaultProfile({
    this.blockedExhaustR = false,
    this.blockedExhaustS = false,
    this.stuckSpoolAt,
    this.leakA,
    this.leakB,
  });

  final bool blockedExhaustR;
  final bool blockedExhaustS;
  final ValveSpoolSide? stuckSpoolAt;
  final PneumaticPressureBoundary? leakA;
  final PneumaticPressureBoundary? leakB;

  ValveSpoolSide effectiveSpool(ValveSpoolSide commanded) =>
      stuckSpoolAt ?? commanded;

  /// Boundaries are immutable; no mass or position is reset upon a fault.
  MovingDoubleActingAirCylinder connect({
    required MovingDoubleActingAirCylinder cylinder,
    required MovingCylinderSnapshot snapshot,
    required Valve52CylinderRouting routing,
    required ValveSpoolSide commandedSpool,
    required bool supplyEnabled,
  }) {
    final Valve52CylinderRouting upstream = Valve52AirIsolation(
      routing: routing,
    ).withSupplyEnabled(supplyEnabled);
    PneumaticPressureBoundary close(PneumaticPressureBoundary input) =>
        PneumaticPressureBoundary(
          id: input.id,
          pressureAbsPa: input.pressureAbsPa,
          orifice: input.orifice,
          temperatureK: input.temperatureK,
          enabled: false,
          allowReverseFlow: input.allowReverseFlow,
        );
    final Valve52CylinderRouting faulted = Valve52CylinderRouting(
      supplyA: upstream.supplyA,
      supplyB: upstream.supplyB,
      exhaustA: blockedExhaustR ? close(upstream.exhaustA) : upstream.exhaustA,
      exhaustB: blockedExhaustS ? close(upstream.exhaustB) : upstream.exhaustB,
    );
    final MovingDoubleActingAirCylinder base = faulted.connect(
      cylinder: cylinder,
      snapshot: snapshot,
      energized: effectiveSpool(commandedSpool) == ValveSpoolSide.coilSide,
    );
    if (leakA == null && leakB == null) return base;
    return MovingDoubleActingAirCylinder(
      geometry: base.geometry,
      mechanics: base.mechanics,
      temperatureK: base.temperatureK,
      initialSnapshot: base.initialSnapshot,
      aBoundaries: <PneumaticPressureBoundary>[
        ...base.aBoundaries,
        if (leakA != null) leakA!,
      ],
      bBoundaries: <PneumaticPressureBoundary>[
        ...base.bBoundaries,
        if (leakB != null) leakB!,
      ],
    );
  }
}
