import 'dynamic_cylinder.dart';
import 'open_boundary.dart';

/// ISO 1219 port map for a 5/2 directional valve:
/// 1=P supply, 2=A work, 4=B work, 3=R exhaust, 5=S exhaust.
/// Energized: P->A and B->S. Rest: P->B and A->R.
/// This adapter switches boundaries without changing chamber gas mass.
final class Valve52CylinderRouting {
  const Valve52CylinderRouting({
    required this.supplyA,
    required this.supplyB,
    required this.exhaustA,
    required this.exhaustB,
  });

  final PneumaticPressureBoundary supplyA;
  final PneumaticPressureBoundary supplyB;
  final PneumaticPressureBoundary exhaustA;
  final PneumaticPressureBoundary exhaustB;

  MovingDoubleActingAirCylinder connect({
    required MovingDoubleActingAirCylinder cylinder,
    required MovingCylinderSnapshot snapshot,
    required bool energized,
  }) {
    if (snapshot.timeS < cylinder.initialSnapshot.timeS) {
      throw ArgumentError.value(
        snapshot.timeS,
        'snapshot.timeS',
        'Cannot route a snapshot before the initial time.',
      );
    }
    return MovingDoubleActingAirCylinder(
      geometry: cylinder.geometry,
      mechanics: cylinder.mechanics,
      initialSnapshot: cylinder.initialSnapshot,
      temperatureK: cylinder.temperatureK,
      aBoundaries: energized
          ? <PneumaticPressureBoundary>[supplyA]
          : <PneumaticPressureBoundary>[exhaustA],
      bBoundaries: energized
          ? <PneumaticPressureBoundary>[exhaustB]
          : <PneumaticPressureBoundary>[supplyB],
    );
  }
}
