import 'dart:math' as math;

import 'ideal_gas.dart';

/// Double-acting cylinder geometry. Calculations use piston-front area and
/// rod-side annular area; motion and damping are separate R2/B responsibilities.
final class DoubleActingCylinderGeometry {
  DoubleActingCylinderGeometry({
    required this.pistonDiameterM,
    required this.rodDiameterM,
    required this.strokeM,
    required this.deadVolumeAM3,
    required this.deadVolumeBM3,
  }) {
    requirePositiveFinite(pistonDiameterM, 'pistonDiameterM');
    requireNonnegativeFinite(rodDiameterM, 'rodDiameterM');
    if (rodDiameterM >= pistonDiameterM) {
      throw const PneumaticPhysicsException(
        'invalid_cylinder_geometry',
        'Rod diameter must be smaller than piston diameter.',
      );
    }
    requirePositiveFinite(strokeM, 'strokeM');
    requirePositiveFinite(deadVolumeAM3, 'deadVolumeAM3');
    requirePositiveFinite(deadVolumeBM3, 'deadVolumeBM3');
  }

  final double pistonDiameterM;
  final double rodDiameterM;
  final double strokeM;
  final double deadVolumeAM3;
  final double deadVolumeBM3;

  double get pistonAreaM2 => math.pi * pistonDiameterM * pistonDiameterM / 4;

  double get rodSideAreaM2 =>
      math.pi *
      (pistonDiameterM * pistonDiameterM - rodDiameterM * rodDiameterM) /
      4;

  void _validatePosition(double positionM) {
    requireNonnegativeFinite(positionM, 'positionM');
    if (positionM > strokeM) {
      throw const PneumaticPhysicsException(
        'cylinder_position_out_of_range',
        'Cylinder position must remain between physical end stops.',
      );
    }
  }

  double volumeAM3(double positionM) {
    _validatePosition(positionM);
    return deadVolumeAM3 + pistonAreaM2 * positionM;
  }

  double volumeBM3(double positionM) {
    _validatePosition(positionM);
    return deadVolumeBM3 + rodSideAreaM2 * (strokeM - positionM);
  }

  /// Positive force extends the rod. Both pressures are absolute.
  double theoreticalForceN({
    required double pressureAAbsPa,
    required double pressureBAbsPa,
    double ambientPressureAbsPa = DryAirReference.atmosphericPressurePa,
  }) {
    requirePositiveFinite(pressureAAbsPa, 'pressureAAbsPa');
    requirePositiveFinite(pressureBAbsPa, 'pressureBAbsPa');
    requirePositiveFinite(ambientPressureAbsPa, 'ambientPressureAbsPa');
    return (pressureAAbsPa - ambientPressureAbsPa) * pistonAreaM2 -
        (pressureBAbsPa - ambientPressureAbsPa) * rodSideAreaM2;
  }
}
