import 'dart:math' as math;

import 'package:electrosim_pneumatic_domain/electrosim_pneumatic_domain.dart';

import 'ideal_gas.dart';
import 'isothermal_network.dart';

/// An intentionally narrow first bridge from physically connected workshop
/// ports to the *actual* conservative, isothermal solver.
///
/// Only explicit finite-volume tees and manifolds are currently supported.
/// Every volume/pressure must be authored in SI units by the circuit, and
/// every active pipe must use the calibrated effective-orifice loss model.
/// Sources, drains, 3/2, 5/2 and cylinders require boundary/moving-volume
/// equations that are NOT implemented here: compilation FAILS CLOSED instead
/// of showing invented flows or pretending the entire editor is simulated.
///
/// One chamber per junction is a generic lumped-gas approximation; each hose
/// is a zero-storage orifice. This does not resolve wave propagation, volume
/// inside the hoses, Darcy friction, leakage, thermal transients or hardware
/// manufacturer performance.
final class WorkshopClosedAirCompiler {
  const WorkshopClosedAirCompiler({required this.dischargeCoefficient});

  /// An explicit generic effective-orifice coefficient, 0 < Cd <= 1.
  final double dischargeCoefficient;

  /// Closed R6/D remains the strict default. Existing callers are unchanged.
  IsothermalAirNetwork compile(PneumaticNetwork network) =>
      _compile(network, withIdealBoundaries: false);

  /// R6/E opt-in: an ideal source and an atmosphere outlet are explicitly
  /// prescribed constant-pressure boundary conditions, not finite tanks,
  /// regulators, compressors, valves or cylinders. Their signed mass exchange
  /// is available in IsothermalAirSnapshot.externalMassAddedKg.
  IsothermalAirNetwork compileWithIdealBoundaries(PneumaticNetwork network) =>
      _compile(network, withIdealBoundaries: true);

  IsothermalAirNetwork _compile(
    PneumaticNetwork network, {
    required bool withIdealBoundaries,
  }) {
    requirePositiveFinite(dischargeCoefficient, 'dischargeCoefficient');
    if (dischargeCoefficient > 1) {
      throw const PneumaticPhysicsException(
        'invalid_discharge_coefficient',
        'Workshop effective-orifice discharge coefficient exceeds one.',
      );
    }
    if (network.devices.isEmpty) {
      throw const PneumaticPhysicsException(
        'empty_workshop',
        'There are no junction volumes to simulate.',
      );
    }

    final Map<PneumaticPortId, String> chamberByPort =
        <PneumaticPortId, String>{};
    final List<FixedAirChamber> chambers = <FixedAirChamber>[];
    final List<FixedPressureAirNode> boundaryNodes =
        <FixedPressureAirNode>[];
    final Map<String, PneumaticDeviceKind> kinds =
        <String, PneumaticDeviceKind>{};
    for (final PneumaticDevice device in network.devices) {
      final bool isFitting = device.kind == PneumaticDeviceKind.tee ||
          device.kind == PneumaticDeviceKind.manifold;
      final bool isExternal = device.kind == PneumaticDeviceKind.idealSource ||
          device.kind == PneumaticDeviceKind.silencer;
      if (!isFitting && (!withIdealBoundaries || !isExternal)) {
        throw PneumaticPhysicsException(
          'unsupported_device',
          'The physical workshop compiler has no accepted dynamic model for '
              '${device.id} (${device.kind.name}). Do not infer its behavior.',
        );
      }
      kinds[device.id] = device.kind;
      if (isExternal) {
        final double? pressure = device.parametersSi['pressureAbsPa'];
        if (pressure == null) {
          throw PneumaticPhysicsException(
            'missing_physical_calibration',
            'An explicit absolute boundary pressure is required for '
                '${device.id}.',
          );
        }
        final PneumaticPortRole requiredRole =
            device.kind == PneumaticDeviceKind.idealSource
            ? PneumaticPortRole.supply
            : PneumaticPortRole.exhaust;
        for (final PneumaticPort port in device.ports) {
          if (port.role != requiredRole) {
            throw PneumaticPhysicsException(
              'unsupported_port_role',
              'The ${device.kind.name} boundary requires '
                  '${requiredRole.name} ports.',
            );
          }
          chamberByPort[port.id] = device.id;
        }
        boundaryNodes.add(
          FixedPressureAirNode(
            id: device.id,
            pressureAbsPa: pressure,
            temperatureK:
                device.parametersSi['temperatureK'] ??
                DryAirReference.temperatureK,
          ),
        );
        continue;
      }
      final double? volume = device.parametersSi['volumeM3'];
      final double? pressure = device.parametersSi['pressureAbsPa'];
      if (volume == null || pressure == null) {
        throw PneumaticPhysicsException(
          'missing_physical_calibration',
          'Volume and initial absolute pressure in SI are required for '
              '${device.id}.',
        );
      }
      chambers.add(
        FixedAirChamber.fromPressure(
          id: device.id,
          volumeM3: volume,
          pressureAbsPa: pressure,
        ),
      );
      for (final PneumaticPort port in device.ports) {
        if (port.role != PneumaticPortRole.work) {
          throw PneumaticPhysicsException(
            'unsupported_port_role',
            'Closed finite-volume network requires work ports, '
                'not ${port.role.name}.',
          );
        }
        chamberByPort[port.id] = device.id;
      }
    }

    final List<AirPassage> passages = <AirPassage>[];
    for (final PneumaticPipe pipe in network.pipes) {
      if (pipe.fault == PneumaticPipeFault.blocked) {
        continue; // A blocked pipe has no mass flow or hidden vent.
      }
      if (pipe.fault != PneumaticPipeFault.none) {
        throw PneumaticPhysicsException(
          'unsupported_pipe_fault',
          'The ${pipe.fault.name} pipe fault needs an explicit '
              'atmospheric boundary or open disconnect.',
        );
      }
      if (pipe.lossModel != PneumaticPipeLossModel.effectiveOrifice) {
        throw PneumaticPhysicsException(
          'unsupported_loss_model',
          'Only calibrated effective-orifice hoses are implemented; '
              'neither an ideal wire nor Darcy losses are inferred.',
        );
      }
      final String first = chamberByPort[pipe.fromPortId]!;
      final String second = chamberByPort[pipe.toPortId]!;
      if (first == second) {
        throw PneumaticPhysicsException(
          'same_junction_pipe',
          'Connecting a junction to itself does not create a passage.',
        );
      }

      final bool firstIsBoundary =
          kinds[first] == PneumaticDeviceKind.idealSource ||
          kinds[first] == PneumaticDeviceKind.silencer;
      final bool secondIsBoundary =
          kinds[second] == PneumaticDeviceKind.idealSource ||
          kinds[second] == PneumaticDeviceKind.silencer;
      if (firstIsBoundary && secondIsBoundary) {
        throw const PneumaticPhysicsException(
          'unsupported_boundary_connection',
          'Ideal pressure boundaries cannot be connected directly without '
              'a finite gas volume.',
        );
      }

      // This is the standard lumped effective-area K correction, not a
      // detailed length-dependent Darcy friction calculation.
      final double boreArea = math.pi * math.pow(pipe.innerDiameterM, 2) / 4;
      final double area = boreArea / math.sqrt(1 + pipe.lossCoefficient);
      passages.add(
        AirPassage(
          id: pipe.id,
          firstChamberId: first,
          secondChamberId: second,
          orifice: IsentropicOrifice(
            effectiveAreaM2: area,
            dischargeCoefficient: dischargeCoefficient,
          ),
        ),
      );
    }
    if (chambers.isEmpty) {
      throw const PneumaticPhysicsException(
        'missing_finite_volume',
        'An ideal pressure boundary needs a connected finite gas volume.',
      );
    }
    return IsothermalAirNetwork(
      chambers: chambers,
      passages: passages,
      boundaries: boundaryNodes,
    );
  }
}
