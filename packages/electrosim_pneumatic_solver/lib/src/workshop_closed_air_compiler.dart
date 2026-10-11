import 'dart:math' as math;

import 'package:electrosim_pneumatic_domain/electrosim_pneumatic_domain.dart';

import 'cylinder_physics.dart';
import 'dynamic_cylinder.dart';
import 'ideal_gas.dart';
import 'isothermal_network.dart';
import 'moving_cylinder_network.dart';

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

  /// R6/G: optional quasi-static ISO 1219 5/2 spool at an authored state.
  /// Every valve port is a finite dead volume. State changes require a new
  /// compiled topology AND explicit conservative snapshot reconciliation.
  /// This method models no moving spool, solenoid voltage or moving piston.
  IsothermalAirNetwork compileWithStaticValve52(PneumaticNetwork network) =>
      _compile(network, withIdealBoundaries: true, withStaticValve52: true);

  /// R6/K: opt-in calibrated 3/2 and 5/2 discrete direction valves.
  /// The 3/2 connects P->A when energized and A->R at rest, with no
  /// invented pressure source or common exhaust on a closed port.
  IsothermalAirNetwork compileWithStaticValves(PneumaticNetwork network) =>
      _compile(
        network,
        withIdealBoundaries: true,
        withStaticValve52: true,
        withStaticValve32: true,
      );

  /// R6/I experimental dynamic coupling for exactly one double-acting
  /// cylinder. It reuses the ISO 5/2 network and its signed gas ledger.
  CoupledMovingCylinderAirNetwork compileWithMovingCylinder(
    PneumaticNetwork network,
  ) {
    final List<PneumaticDevice> cylinders = network.devices
        .where(
          (PneumaticDevice d) =>
              d.kind == PneumaticDeviceKind.doubleActingCylinder,
        )
        .toList();
    if (cylinders.length != 1) {
      throw const PneumaticPhysicsException(
        'unsupported_cylinder_count',
        'R6/I requires exactly one calibrated double-acting cylinder.',
      );
    }
    final PneumaticDevice device = cylinders.single;
    final DoubleActingCylinderGeometry geometry = _cylinderGeometry(device);
    final Map<String, double> p = device.parametersSi;
    double required(String key) {
      final double? value = p[key];
      if (value == null) {
        throw PneumaticPhysicsException(
          'missing_cylinder_calibration',
          'Double-acting cylinder ${device.id} requires $key.',
        );
      }
      return value;
    }

    return CoupledMovingCylinderAirNetwork(
      airNetwork: _compile(
        network,
        withIdealBoundaries: true,
        withStaticValve52: true,
        withMovingCylinder: true,
      ),
      geometry: geometry,
      mechanics: CylinderMechanicalCalibration(
        movingMassKg: required('movingMassKg'),
        viscousNsPerM: p['viscousNsPerM'] ?? 0,
        coulombFrictionN: p['coulombFrictionN'] ?? 0,
        staticBreakawayFrictionN: p['staticBreakawayFrictionN'] ?? 0,
        externalLoadN: p['externalLoadN'] ?? 0,
      ),
      chamberAId: '${device.id}.A',
      chamberBId: '${device.id}.B',
      initialPositionM: required('initialPositionM'),
      initialVelocityMPerS: p['initialVelocityMPerS'] ?? 0,
    );
  }

  DoubleActingCylinderGeometry _cylinderGeometry(PneumaticDevice device) {
    final Map<String, double> p = device.parametersSi;
    double required(String key) {
      final double? value = p[key];
      if (value == null) {
        throw PneumaticPhysicsException(
          'missing_cylinder_calibration',
          'Double-acting cylinder ${device.id} requires $key.',
        );
      }
      return value;
    }

    return DoubleActingCylinderGeometry(
      pistonDiameterM: required('pistonDiameterM'),
      rodDiameterM: required('rodDiameterM'),
      strokeM: required('strokeM'),
      deadVolumeAM3: required('deadVolumeAM3'),
      deadVolumeBM3: required('deadVolumeBM3'),
    );
  }

  IsothermalAirNetwork _compile(
    PneumaticNetwork network, {
    required bool withIdealBoundaries,
    bool withStaticValve52 = false,
    bool withStaticValve32 = false,
    bool withMovingCylinder = false,
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
    final List<FixedPressureAirNode> boundaryNodes = <FixedPressureAirNode>[];
    final Map<String, PneumaticDeviceKind> kinds =
        <String, PneumaticDeviceKind>{};
    final List<AirPassage> valvePassages = <AirPassage>[];
    for (final PneumaticDevice device in network.devices) {
      final bool isFitting =
          device.kind == PneumaticDeviceKind.tee ||
          device.kind == PneumaticDeviceKind.manifold;
      final bool isExternal =
          device.kind == PneumaticDeviceKind.idealSource ||
          device.kind == PneumaticDeviceKind.silencer;
      final bool isValve =
          withStaticValve52 && device.kind == PneumaticDeviceKind.valve52;
      final bool isValve32 =
          withStaticValve32 && device.kind == PneumaticDeviceKind.valve32;
      final bool isCylinder =
          withMovingCylinder &&
          device.kind == PneumaticDeviceKind.doubleActingCylinder;
      if (!isFitting &&
          (!withIdealBoundaries || !isExternal) &&
          !isValve &&
          !isValve32 &&
          !isCylinder) {
        throw PneumaticPhysicsException(
          'unsupported_device',
          'The physical workshop compiler has no accepted dynamic model for '
              '${device.id} (${device.kind.name}). Do not infer its behavior.',
        );
      }
      kinds[device.id] = device.kind;
      if (isCylinder) {
        final DoubleActingCylinderGeometry geometry = _cylinderGeometry(device);
        final Map<String, double> p = device.parametersSi;
        double required(String key) {
          final double? value = p[key];
          if (value == null) {
            throw PneumaticPhysicsException(
              'missing_cylinder_calibration',
              'Double-acting cylinder ${device.id} requires $key.',
            );
          }
          return value;
        }

        final double initialPosition = required('initialPositionM');
        requireNonnegativeFinite(initialPosition, 'initialPositionM');
        final Map<String, PneumaticPort> cylinderPorts =
            <String, PneumaticPort>{};
        for (final PneumaticPort port in device.ports) {
          if (port.role != PneumaticPortRole.work ||
              !port.id.value.startsWith('${device.id}.')) {
            throw const PneumaticPhysicsException(
              'invalid_cylinder_ports',
              'A/B must be work ports owned by the double-acting cylinder.',
            );
          }
          final String name = port.id.value.substring('${device.id}.'.length);
          cylinderPorts[name] = port;
        }
        if (cylinderPorts.length != 2 ||
            !cylinderPorts.containsKey('A') ||
            !cylinderPorts.containsKey('B')) {
          throw const PneumaticPhysicsException(
            'invalid_cylinder_ports',
            'A double-acting cylinder requires exactly ports A and B.',
          );
        }
        final double aPressure = required('initialPressureAAbsPa');
        final double bPressure = required('initialPressureBAbsPa');
        chambers.add(
          FixedAirChamber.fromPressure(
            id: '${device.id}.A',
            volumeM3: geometry.volumeAM3(initialPosition),
            pressureAbsPa: aPressure,
          ),
        );
        chambers.add(
          FixedAirChamber.fromPressure(
            id: '${device.id}.B',
            volumeM3: geometry.volumeBM3(initialPosition),
            pressureAbsPa: bPressure,
          ),
        );
        chamberByPort[cylinderPorts['A']!.id] = '${device.id}.A';
        chamberByPort[cylinderPorts['B']!.id] = '${device.id}.B';
        continue;
      }
      if (isValve || isValve32) {
        final double? deadVolume = device.parametersSi['portDeadVolumeM3'];
        final double? initialPressure = device.parametersSi['pressureAbsPa'];
        final double? effectiveArea =
            device.parametersSi['valveEffectiveAreaM2'];
        final double? valveCd = device.parametersSi['valveCd'];
        final double? spoolPosition = device.parametersSi['energized'];
        if (deadVolume == null ||
            initialPressure == null ||
            effectiveArea == null ||
            valveCd == null ||
            spoolPosition == null) {
          throw PneumaticPhysicsException(
            'missing_valve_calibration',
            'A directional valve needs explicit dead volume, absolute pressure, '
                'effective area, discharge coefficient, and spool state: '
                '${device.id}.',
          );
        }
        requirePositiveFinite(deadVolume, 'portDeadVolumeM3');
        requirePositiveFinite(initialPressure, 'pressureAbsPa');
        requirePositiveFinite(effectiveArea, 'valveEffectiveAreaM2');
        requirePositiveFinite(valveCd, 'valveCd');
        if (valveCd > 1 || (spoolPosition != 0 && spoolPosition != 1)) {
          throw const PneumaticPhysicsException(
            'invalid_valve_calibration',
            'Valve Cd must be <=1 and energized must be exactly 0 or 1.',
          );
        }
        final Map<String, PneumaticPort> byName = <String, PneumaticPort>{};
        for (final PneumaticPort port in device.ports) {
          final String prefix = '${device.id}.';
          if (!port.id.value.startsWith(prefix)) {
            throw const PneumaticPhysicsException(
              'invalid_valve_ports',
              'Valve port IDs must use their physical owner prefix.',
            );
          }
          final String name = port.id.value.substring(prefix.length);
          if (byName.containsKey(name)) {
            throw const PneumaticPhysicsException(
              'invalid_valve_ports',
              'Valve port names must be unique.',
            );
          }
          byName[name] = port;
        }
        final Map<String, PneumaticPortRole> roles =
            <String, PneumaticPortRole>{
              'P': PneumaticPortRole.supply,
              'A': PneumaticPortRole.work,
              if (isValve) 'B': PneumaticPortRole.work,
              'R': PneumaticPortRole.exhaust,
              if (isValve) 'S': PneumaticPortRole.exhaust,
            };
        if (byName.length != roles.length ||
            roles.entries.any(
              (e) => byName[e.key] == null || byName[e.key]!.role != e.value,
            )) {
          throw PneumaticPhysicsException(
            'invalid_valve_ports',
            'Valve ${device.id} must expose exact ISO P/A/R'
                ' (plus B/S for 5/2) with correct roles.',
          );
        }
        for (final MapEntry<String, PneumaticPort> entry in byName.entries) {
          final String chamber = '${device.id}.${entry.key}';
          chambers.add(
            FixedAirChamber.fromPressure(
              id: chamber,
              volumeM3: deadVolume,
              pressureAbsPa: initialPressure,
            ),
          );
          chamberByPort[entry.value.id] = chamber;
        }
        final IsentropicOrifice internal = IsentropicOrifice(
          effectiveAreaM2: effectiveArea,
          dischargeCoefficient: valveCd,
        );
        final List<(String, String)> routes = isValve
            ? (spoolPosition == 1
                  ? <(String, String)>[('P', 'A'), ('B', 'S')]
                  : <(String, String)>[('P', 'B'), ('A', 'R')])
            : (spoolPosition == 1
                  ? <(String, String)>[('P', 'A')]
                  : <(String, String)>[('A', 'R')]);
        for (final (String first, String second) in routes) {
          valvePassages.add(
            AirPassage(
              id: '${device.id}.${first}to${second}',
              firstChamberId: '${device.id}.${first}',
              secondChamberId: '${device.id}.${second}',
              orifice: internal,
            ),
          );
        }
        continue;
      }
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

    final List<AirPassage> passages = <AirPassage>[...valvePassages];
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
