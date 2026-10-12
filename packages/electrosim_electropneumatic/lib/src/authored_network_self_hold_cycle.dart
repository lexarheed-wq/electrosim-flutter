import 'package:electrosim_multiphysics/electrosim_multiphysics.dart';
import 'package:electrosim_pneumatic_domain/electrosim_pneumatic_domain.dart';
import 'package:electrosim_pneumatic_solver/electrosim_pneumatic_solver.dart';

import 'coupled_clock.dart';
import 'dc_coil_meter.dart';
import 'self_hold_circuit.dart';
import 'solenoid_actuator.dart';

/// Atomic, physically accepted gas plus real DC reading from one project.
final class AuthoredNetworkSelfHoldSnapshot {
  const AuthoredNetworkSelfHoldSnapshot({
    required this.physical,
    required this.electrical,
  });

  final CoupledRuntimeSnapshot<CoupledCylinderNetworkSnapshot> physical;
  final SelfHold24vSnapshot? electrical;
  double get timeS => physical.timeS;
  CoupledCylinderNetworkSnapshot get air => physical.air;
  ValveSpoolSide get spool => physical.spool;
  bool get endStopActuated => physical.endContactActuated;
}

/// R6/J: real 24V S1/K1/Y1/B1 circuit operates a physically wired 5/2,
/// hoses, source, vents and moving double-acting piston on one event clock.
/// Fixed-point DC feedback consumes zero physical time. Each positive step
/// updates gas once and never replaces previously accepted gas mass.
final class AuthoredNetworkSelfHoldValve52Cycle {
  AuthoredNetworkSelfHoldValve52Cycle({
    required this.electrical,
    required this.compiler,
    required this.valveDeviceId,
    required this.cylinderDeviceId,
    required this.endSensor,
    required this.solenoid,
    this.maxStepS = .0005,
    this.mechanicalStepS = .00005,
    this.valveMemory = const SingleCoilValveMemory(
      returnKind: ValveReturnKind.monostableSpring,
    ),
  }) {
    if (endSensor.normallyOpen ||
        !maxStepS.isFinite ||
        maxStepS <= 0 ||
        !mechanicalStepS.isFinite ||
        mechanicalStepS <= 0) {
      throw const ElectropneumaticRuntimeException(
        'invalid_network_coupling',
        'A B1 NC sensor and positive shared step budgets are required.',
      );
    }
    final PneumaticNetwork network = electrical.project.pneumaticNetwork;
    final int valves = network.devices
        .where(
          (d) => d.id == valveDeviceId && d.kind == PneumaticDeviceKind.valve52,
        )
        .length;
    final int cylinders = network.devices
        .where(
          (d) =>
              d.id == cylinderDeviceId &&
              d.kind == PneumaticDeviceKind.doubleActingCylinder,
        )
        .length;
    if (valves != 1 ||
        cylinders != 1 ||
        electrical.binding.valveSolenoidLink.pneumaticDeviceId !=
            valveDeviceId ||
        !electrical.project.links.any(
          (ElectropneumaticLink link) =>
              link.pneumaticDeviceId == cylinderDeviceId &&
              link.role == ElectropneumaticLinkRole.positionContact &&
              link.electricalComponentId ==
                  electrical.binding.endStopComponentId,
        )) {
      throw const ElectropneumaticRuntimeException(
        'missing_canonical_links',
        'Y1 and B1 must link to real project physical devices.',
      );
    }
    final CoupledMovingCylinderAirNetwork initial = _compilerAt(
      ValveSpoolSide.springSide,
    );
    if ((initial.geometry.strokeM - endSensor.strokeM).abs() > 1e-9) {
      throw const ElectropneumaticRuntimeException(
        'inconsistent_stroke',
        'B1 and moving piston must share the same physical stroke.',
      );
    }
    _initial = initial.initialSnapshot;
  }

  final SelfHold24vElectricalCycle electrical;
  final WorkshopClosedAirCompiler compiler;
  final String valveDeviceId;
  final String cylinderDeviceId;
  final PositionEndContact endSensor;
  final Solenoid24vDynamics solenoid;
  final SingleCoilValveMemory valveMemory;
  final double maxStepS;
  final double mechanicalStepS;
  late final CoupledCylinderNetworkSnapshot _initial;

  CoupledMovingCylinderAirNetwork _compilerAt(
    ValveSpoolSide spool, {
    bool airSupplyEnabled = true,
  }) {
    final List<PneumaticDevice> devices = <PneumaticDevice>[];
    for (final PneumaticDevice device
        in electrical.project.pneumaticNetwork.devices) {
      if (device.id != valveDeviceId) {
        devices.add(device);
        continue;
      }
      devices.add(
        PneumaticDevice(
          id: device.id,
          kind: device.kind,
          ports: device.ports,
          parametersSi: <String, double>{
            ...device.parametersSi,
            'energized': spool == ValveSpoolSide.coilSide ? 1 : 0,
          },
        ),
      );
    }
    final Set<PneumaticPortId> sourcePorts = <PneumaticPortId>{
      for (final PneumaticDevice device in devices)
        if (device.kind == PneumaticDeviceKind.idealSource)
          for (final PneumaticPort port in device.ports) port.id,
    };
    return compiler.compileWithMovingCylinder(
      PneumaticNetwork(
        devices: devices,
        pipes: <PneumaticPipe>[
          for (final PneumaticPipe pipe
              in electrical.project.pneumaticNetwork.pipes)
            if (airSupplyEnabled ||
                (!sourcePorts.contains(pipe.fromPortId) &&
                    !sourcePorts.contains(pipe.toPortId)))
              pipe,
        ],
      ),
    );
  }

  ElectropneumaticEventClock<CoupledCylinderNetworkSnapshot> _clock(
    SolveCoilAt<CoupledCylinderNetworkSnapshot> solve, {
    bool airSupplyEnabled = true,
  }) => ElectropneumaticEventClock<CoupledCylinderNetworkSnapshot>(
    solenoid: solenoid,
    valveMemory: valveMemory,
    solveElectrical: solve,
    airTime: (CoupledCylinderNetworkSnapshot s) => s.timeS,
    cylinderPosition: (CoupledCylinderNetworkSnapshot s) => s.positionM,
    positionSensor: endSensor,
    maxStepS: maxStepS,
    advanceAir:
        (
          CoupledCylinderNetworkSnapshot before,
          double dt,
          ValveSpoolSide position,
        ) {
          final CoupledMovingCylinderAirNetwork routed = _compilerAt(
            position,
            airSupplyEnabled: airSupplyEnabled,
          );
          // Only the passage connectivity changes. Supply all previous gas
          // masses, piston position/velocity, time and exchange ledger unchanged.
          return routed.advance(
            before,
            durationS: dt,
            maxStepS: mechanicalStepS,
            stopAtFirstImpact: true,
          );
        },
  );

  AuthoredNetworkSelfHoldSnapshot initial() {
    final ElectropneumaticEventClock<CoupledCylinderNetworkSnapshot> clock =
        _clock(
          (air, spool, closed) => const CoilElectricalReading(
            linkId: '',
            voltageV: 0,
            currentA: 0,
            powerW: 0,
          ),
        );
    return AuthoredNetworkSelfHoldSnapshot(
      physical: clock.initial(_initial),
      electrical: null,
    );
  }

  AuthoredNetworkSelfHoldSnapshot advance(
    AuthoredNetworkSelfHoldSnapshot before, {
    required double durationS,
    required bool startPressed,
    bool paused = false,
    bool powerEnabled = true,
    bool airSupplyEnabled = true,
  }) {
    if (paused) return before;
    Solenoid24vSnapshot relay =
        before.electrical?.relay ??
        const Solenoid24vSnapshot(energized: false, measuredVoltageV: 0);
    SelfHold24vSnapshot? feedback = before.electrical;
    final ElectropneumaticEventClock<CoupledCylinderNetworkSnapshot> clock =
        _clock((air, spool, sensorClosed) {
          feedback = electrical.settle(
            timeS: air.timeS,
            startPressed: startPressed,
            endStopActuated: !sensorClosed,
            previousRelay: relay,
            powerEnabled: powerEnabled,
          );
          relay = feedback!.relay;
          return feedback!.valveReading;
        }, airSupplyEnabled: airSupplyEnabled);
    final CoupledRuntimeSnapshot<CoupledCylinderNetworkSnapshot> accepted =
        clock.advance(before.physical, durationS: durationS);
    return AuthoredNetworkSelfHoldSnapshot(
      physical: accepted,
      electrical: feedback,
    );
  }

  double massBalanceResidualKg(AuthoredNetworkSelfHoldSnapshot s) =>
      s.air.air.totalMassKg -
      _initial.air.totalMassKg -
      s.air.air.externalMassAddedKg;
}
