import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:electrosim_multiphysics/electrosim_multiphysics.dart';
import 'package:electrosim_pneumatic_domain/electrosim_pneumatic_domain.dart';
import 'package:electrosim_pneumatic_solver/electrosim_pneumatic_solver.dart';

import 'authored_network_self_hold_cycle.dart';
import 'dc_coil_meter.dart';
import 'self_hold_circuit.dart';
import 'solenoid_actuator.dart';

/// Strict R6 pilot resolver for an explicit single-valve/single-cylinder
/// canonical project. Never guess links from visual proximity or ID suffixes.
/// Ambiguous circuits and missing physical calibrations fail closed.
final class AuthoredSelfHoldCycleFactory {
  const AuthoredSelfHoldCycleFactory();

  AuthoredNetworkSelfHoldValve52Cycle create(
    MultiphysicsProject project, {
    required double hoseDischargeCoefficient,
  }) {
    if (project.electricalCircuit.mode != ElectricalMode.dc) {
      throw const ElectropneumaticRuntimeException(
        'unsupported_electrical_mode',
        'The reference electropneumatic control requires DC.',
      );
    }
    final List<ElectropneumaticLink> solenoids = project.links
        .where((l) => l.role == ElectropneumaticLinkRole.solenoidCoil)
        .toList();
    final List<ElectropneumaticLink> positions = project.links
        .where((l) => l.role == ElectropneumaticLinkRole.positionContact)
        .toList();
    if (solenoids.length != 1 || positions.length != 1) {
      throw const ElectropneumaticRuntimeException(
        'ambiguous_physical_coupling',
        'Exactly one Y1 coil link and one B1 position link are required.',
      );
    }
    final ElectropneumaticLink y1 = solenoids.single;
    final ElectropneumaticLink b1 = positions.single;
    final List<PneumaticDevice> valves = project.pneumaticNetwork.devices
        .where((d) =>
            d.kind == PneumaticDeviceKind.valve52 &&
            d.id == y1.pneumaticDeviceId)
        .toList();
    final List<PneumaticDevice> cylinders = project.pneumaticNetwork.devices
        .where((d) =>
            d.kind == PneumaticDeviceKind.doubleActingCylinder &&
            d.id == b1.pneumaticDeviceId)
        .toList();
    if (valves.length != 1 || cylinders.length != 1) {
      throw const ElectropneumaticRuntimeException(
        'invalid_physical_links',
        'Y1 must control one 5/2 and B1 must sense a double-acting cylinder.',
      );
    }

    final Map<String, List<ComponentInstance>> componentsByKind =
        <String, List<ComponentInstance>>{};
    for (final ComponentInstance c in project.electricalCircuit.components) {
      componentsByKind.putIfAbsent(c.modelType, () => <ComponentInstance>[])
          .add(c);
    }
    ComponentInstance exactlyOne(String kind) {
      final List<ComponentInstance> components =
          componentsByKind[kind] ?? const <ComponentInstance>[];
      if (components.length != 1) {
        throw ElectropneumaticRuntimeException(
          'ambiguous_control_component',
          'Pilot requires exactly one $kind component.',
        );
      }
      return components.single;
    }

    final ComponentInstance start = exactlyOne('switch');
    final ComponentInstance hold = exactlyOne('relay_contact_no');
    final ComponentInstance endContact = exactlyOne('relay_contact_nc');
    if (endContact.id.value != b1.electricalComponentId) {
      throw const ElectropneumaticRuntimeException(
        'b1_sensor_mismatch',
        'B1 contact must be the contact referenced by the position link.',
      );
    }
    final List<ComponentInstance> windings =
        componentsByKind['resistor'] ?? const <ComponentInstance>[];
    if (windings.length != 2 ||
        windings.where((c) => c.id.value == y1.electricalComponentId).length != 1) {
      throw const ElectropneumaticRuntimeException(
        'ambiguous_winding',
        'Pilot requires exactly K1 and the explicitly linked Y1 windings.',
      );
    }
    final ComponentInstance relayWinding = windings.singleWhere(
      (c) => c.id.value != y1.electricalComponentId,
    );
    final SelfHold24vElectricalCycle electrical = SelfHold24vElectricalCycle(
      project: project,
      binding: SelfHold24vBinding(
        startComponentId: start.id.value,
        holdContactComponentId: hold.id.value,
        endStopComponentId: endContact.id.value,
        relayWindingComponentId: relayWinding.id.value,
        valveSolenoidLink: y1,
      ),
    );

    double parameter(PneumaticDevice device, String name) {
      final double? value = device.parametersSi[name];
      if (value == null) {
        throw ElectropneumaticRuntimeException(
          'missing_pilot_calibration',
          'Device ' + device.id + ' requires SI parameter ' + name,
        );
      }
      return value;
    }

    final PneumaticDevice valve = valves.single;
    final PneumaticDevice cylinder = cylinders.single;
    final Solenoid24vCalibration calibration = Solenoid24vCalibration(
      nominalVoltageV: parameter(valve, 'coilNominalVoltageV'),
      pickupRatio: parameter(valve, 'coilPickupRatio'),
      dropRatio: parameter(valve, 'coilDropRatio'),
      pickupDelayS: parameter(valve, 'coilPickupDelayS'),
      releaseDelayS: parameter(valve, 'coilReleaseDelayS'),
    );
    final PositionEndContact endSensor = PositionEndContact(
      strokeM: parameter(cylinder, 'strokeM'),
      triggerPositionM: parameter(cylinder, 'sensorTriggerPositionM'),
      releasePositionM: parameter(cylinder, 'sensorReleasePositionM'),
      normallyOpen: false,
    );
    return AuthoredNetworkSelfHoldValve52Cycle(
      electrical: electrical,
      compiler: WorkshopClosedAirCompiler(
        dischargeCoefficient: hoseDischargeCoefficient,
      ),
      valveDeviceId: valve.id,
      cylinderDeviceId: cylinder.id,
      endSensor: endSensor,
      solenoid: Solenoid24vDynamics(calibration),
    );
  }
}
