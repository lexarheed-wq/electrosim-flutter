import 'package:electrosim_pneumatic_solver/electrosim_pneumatic_solver.dart';

/// Non-ideal supply shutoff does not vent either cylinder chamber.
/// Pressure is absolute; disabling supply retains exhaust pathways.
final class Valve52AirIsolation {
  const Valve52AirIsolation({required this.routing});

  final Valve52CylinderRouting routing;

  Valve52CylinderRouting withSupplyEnabled(bool enabled) {
    PneumaticPressureBoundary controlled(PneumaticPressureBoundary b) =>
        PneumaticPressureBoundary(
          id: b.id,
          pressureAbsPa: b.pressureAbsPa,
          orifice: b.orifice,
          temperatureK: b.temperatureK,
          enabled: enabled && b.enabled,
          allowReverseFlow: b.allowReverseFlow,
        );
    return Valve52CylinderRouting(
      supplyA: controlled(routing.supplyA),
      supplyB: controlled(routing.supplyB),
      exhaustA: routing.exhaustA,
      exhaustB: routing.exhaustB,
    );
  }
}
