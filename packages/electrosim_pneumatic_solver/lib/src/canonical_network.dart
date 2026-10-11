import 'package:electrosim_pneumatic_domain/electrosim_pneumatic_domain.dart';

import 'ideal_gas.dart';
import 'isothermal_network.dart';

/// Explicit physical properties for one rigid pneumatic fitting.
///
/// This early R2/B bridge only supports a tee or a manifold treated as a
/// finite-volume isothermal chamber. Valves, cylinders, reservoirs, vents,
/// sensors and regulators require their own validated physical models.
final class RigidFittingCalibration {
  RigidFittingCalibration({
    required this.volumeM3,
    required this.initialPressureAbsPa,
    this.temperatureK = DryAirReference.temperatureK,
  }) {
    requirePositiveFinite(volumeM3, 'volumeM3');
    requirePositiveFinite(initialPressureAbsPa, 'initialPressureAbsPa');
    requirePositiveFinite(temperatureK, 'temperatureK');
  }

  final double volumeM3;
  final double initialPressureAbsPa;
  final double temperatureK;
}

/// A hose is a *volume*, with independently calibrated inlet/outlet orifices.
/// Pipe bore area is never silently substituted for an effective nozzle area.
final class HoseVolumeCalibration {
  HoseVolumeCalibration({
    required this.firstEndOrifice,
    required this.secondEndOrifice,
    required this.initialPressureAbsPa,
    this.temperatureK = DryAirReference.temperatureK,
  }) {
    requirePositiveFinite(initialPressureAbsPa, 'initialPressureAbsPa');
    requirePositiveFinite(temperatureK, 'temperatureK');
  }

  final IsentropicOrifice firstEndOrifice;
  final IsentropicOrifice secondEndOrifice;
  final double initialPressureAbsPa;
  final double temperatureK;
}

/// Provenance explicitly associates every solver chamber with physical
/// (not graphical) IDs from R1. No copied or guessed electrical terminal IDs.
final class CanonicalClosedNetwork {
  CanonicalClosedNetwork({
    required this.solver,
    required Map<PneumaticPortId, String> portToChamberId,
    required Map<String, String> hoseToChamberId,
  }) : portToChamberId = Map<PneumaticPortId, String>.unmodifiable(
         portToChamberId,
       ),
       hoseToChamberId = Map<String, String>.unmodifiable(hoseToChamberId);

  final IsothermalAirNetwork solver;
  final Map<PneumaticPortId, String> portToChamberId;
  final Map<String, String> hoseToChamberId;
}

/// Fail-closed compiler for the *supported* subset of the R1 physical graph.
///
/// No geometry, fake infinite supply, lossless tee crossing or inferred
/// physical parameter is introduced here. Unsupported components and
/// uncalibrated hoses fail visibly instead of being simulated inaccurately.
abstract final class ClosedPneumaticNetworkCompiler {
  static CanonicalClosedNetwork compile({
    required PneumaticNetwork network,
    required Map<String, RigidFittingCalibration> fittings,
    required Map<String, HoseVolumeCalibration> hoses,
  }) {
    final Set<String> deviceIds = <String>{
      for (final PneumaticDevice device in network.devices) device.id,
    };
    final Set<String> hoseIds = <String>{
      for (final PneumaticPipe pipe in network.pipes) pipe.id,
    };
    if (fittings.keys.toSet().difference(deviceIds).isNotEmpty ||
        deviceIds.difference(fittings.keys.toSet()).isNotEmpty) {
      throw const PneumaticPhysicsException(
        'missing_fitting_calibration',
        'Every fitting must have exactly one physical calibration.',
      );
    }
    if (hoses.keys.toSet().difference(hoseIds).isNotEmpty ||
        hoseIds.difference(hoses.keys.toSet()).isNotEmpty) {
      throw const PneumaticPhysicsException(
        'missing_hose_calibration',
        'Every hose must have exactly one physical calibration.',
      );
    }

    final List<FixedAirChamber> chambers = <FixedAirChamber>[];
    final List<AirPassage> passages = <AirPassage>[];
    final Map<PneumaticPortId, String> portOwners = <PneumaticPortId, String>{};
    final Map<String, String> hoseChambers = <String, String>{};
    final Set<String> chamberIds = <String>{};

    for (final PneumaticDevice device in network.devices) {
      if (device.kind != PneumaticDeviceKind.tee &&
          device.kind != PneumaticDeviceKind.manifold) {
        throw PneumaticPhysicsException(
          'unsupported_r2b_device',
          'No qualified rigid-volume model for ${device.kind.name} (${device.id}).',
        );
      }
      final RigidFittingCalibration physical = fittings[device.id]!;
      if (!chamberIds.add(device.id)) {
        throw const PneumaticPhysicsException(
          'chamber_id_collision',
          'Duplicate solver chamber ID.',
        );
      }
      chambers.add(
        FixedAirChamber.fromPressure(
          id: device.id,
          volumeM3: physical.volumeM3,
          pressureAbsPa: physical.initialPressureAbsPa,
          temperatureK: physical.temperatureK,
        ),
      );
      for (final PneumaticPort port in device.ports) {
        portOwners[port.id] = device.id;
      }
    }

    for (final PneumaticPipe pipe in network.pipes) {
      if (pipe.lossModel != PneumaticPipeLossModel.effectiveOrifice ||
          pipe.fault != PneumaticPipeFault.none) {
        throw PneumaticPhysicsException(
          'unsupported_r2b_hose',
          'Hose ${pipe.id} requests unqualified loss/fault physics.',
        );
      }
      if (pipe.lossCoefficient != 0) {
        throw PneumaticPhysicsException(
          'unsupported_loss_coefficient',
          'R2/B uses explicit calibrated orifices, not implicit loss coefficients.',
        );
      }
      final HoseVolumeCalibration calibration = hoses[pipe.id]!;
      final String id = 'pipe.${pipe.id}';
      if (!chamberIds.add(id)) {
        throw PneumaticPhysicsException(
          'chamber_id_collision',
          'Hose ${pipe.id} collides with an existing physical node ID.',
        );
      }
      final String? first = portOwners[pipe.fromPortId];
      final String? second = portOwners[pipe.toPortId];
      if (first == null || second == null) {
        throw PneumaticPhysicsException(
          'unknown_r2b_port',
          'Hose ${pipe.id} does not connect modeled fitting ports.',
        );
      }
      chambers.add(
        FixedAirChamber.fromPressure(
          id: id,
          volumeM3: pipe.internalVolumeM3,
          pressureAbsPa: calibration.initialPressureAbsPa,
          temperatureK: calibration.temperatureK,
        ),
      );
      hoseChambers[pipe.id] = id;
      passages.add(
        AirPassage(
          id: '${id}.start',
          firstChamberId: first,
          secondChamberId: id,
          orifice: calibration.firstEndOrifice,
        ),
      );
      passages.add(
        AirPassage(
          id: '${id}.end',
          firstChamberId: id,
          secondChamberId: second,
          orifice: calibration.secondEndOrifice,
        ),
      );
    }
    return CanonicalClosedNetwork(
      solver: IsothermalAirNetwork(chambers: chambers, passages: passages),
      portToChamberId: portOwners,
      hoseToChamberId: hoseChambers,
    );
  }
}
