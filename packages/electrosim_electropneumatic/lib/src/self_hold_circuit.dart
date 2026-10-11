import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:electrosim_multiphysics/electrosim_multiphysics.dart';
import 'package:electrosim_solver_dc/electrosim_solver_dc.dart';
import 'package:electrosim_topology/electrosim_topology.dart';

import 'dc_coil_meter.dart';
import 'solenoid_actuator.dart';

/// A pure electrical self-hold bench bound to the canonical DC circuit.
///
/// S1 (start NO) in parallel with K1 (relay NO); B1 (endstop NC) is
/// in series with the parallel K1 and Y1 winding branches.
/// This object does not invent contacts or overwrite any circuit wiring.
final class SelfHold24vBinding {
  const SelfHold24vBinding({
    required this.startComponentId,
    required this.holdContactComponentId,
    required this.endStopComponentId,
    required this.relayWindingComponentId,
    required this.valveSolenoidLink,
  });

  final String startComponentId;
  final String holdContactComponentId;
  final String endStopComponentId;
  final String relayWindingComponentId;
  final ElectropneumaticLink valveSolenoidLink;
}

/// Read-only result of an electrical fixed point at one physical timestamp.
final class SelfHold24vSnapshot {
  const SelfHold24vSnapshot({
    required this.timeS,
    required this.relay,
    required this.valveReading,
    required this.relayVoltageV,
    required this.electricalResult,
    required this.electricalIterations,
    required this.startPressed,
    required this.endStopActuated,
  });

  final double timeS;
  final Solenoid24vSnapshot relay;
  final CoilElectricalReading valveReading;
  final double relayVoltageV;
  final DcSolveResult electricalResult;
  final int electricalIterations;
  final bool startPressed;
  final bool endStopActuated;
}

/// Integrates real SolverDC branches into the K1 holding contact feedback.
/// Every solve is at zero physical elapsed time; this class never calls a gas
/// solver, so it cannot multiply pneumatic time or erase compressed air.
/// Delayed relay/coil pickup belongs to the global event clock (R3/C).
final class SelfHold24vElectricalCycle {
  SelfHold24vElectricalCycle({
    required this.project,
    required this.binding,
    Solenoid24vCalibration? relayCalibration,
    this.maxIterations = 12,
  }) : relayDrive = Solenoid24vDynamics(
         relayCalibration ??
             Solenoid24vCalibration(pickupDelayS: 0, releaseDelayS: 0),
       ) {
    if (maxIterations <= 0 ||
        project.electricalCircuit.mode != ElectricalMode.dc) {
      throw const ElectropneumaticRuntimeException(
        'invalid_self_hold_options',
        'Self holding control must use a bounded DC circuit.',
      );
    }
    final Map<String, String> requirements = <String, String>{
      binding.startComponentId: 'switch',
      binding.holdContactComponentId: 'relay_contact_no',
      binding.endStopComponentId: 'relay_contact_nc',
      binding.relayWindingComponentId: 'resistor',
      binding.valveSolenoidLink.electricalComponentId: 'resistor',
    };
    if (requirements.length != 5) {
      throw const ElectropneumaticRuntimeException(
        'duplicate_self_hold_component',
        'S1, K1-NO, B1-NC, K1-winding and Y1 must be distinct.',
      );
    }
    for (final MapEntry<String, String> need in requirements.entries) {
      final bool matched = project.electricalCircuit.components.any(
        (ComponentInstance part) =>
            part.id.value == need.key && part.modelType == need.value,
      );
      if (!matched) {
        throw ElectropneumaticRuntimeException(
          'wrong_contact_model',
          'Missing required DC component ${need.key} (${need.value}).',
        );
      }
    }
    if (binding.valveSolenoidLink.role !=
            ElectropneumaticLinkRole.solenoidCoil ||
        !project.links.any(
          (ElectropneumaticLink existing) =>
              existing.id == binding.valveSolenoidLink.id &&
              existing.electricalComponentId ==
                  binding.valveSolenoidLink.electricalComponentId,
        )) {
      throw const ElectropneumaticRuntimeException(
        'invalid_coil_link',
        'Y1 must reference a validated R1 solenoid link.',
      );
    }
  }

  final MultiphysicsProject project;
  final SelfHold24vBinding binding;
  final Solenoid24vDynamics relayDrive;
  final int maxIterations;

  CircuitState _controlledCircuit({
    required int revision,
    required bool pressed,
    required bool holding,
    required bool endStopActuated,
  }) {
    final CircuitState original = project.electricalCircuit;
    final List<ComponentInstance> parts = <ComponentInstance>[
      for (final ComponentInstance c in original.components)
        if (c.id.value == binding.startComponentId ||
            c.id.value == binding.holdContactComponentId ||
            c.id.value == binding.endStopComponentId)
          ComponentInstance(
            id: c.id,
            modelType: c.modelType,
            terminals: c.terminals,
            parameters: c.parameters,
            condition: c.condition,
            controlState: <String, Object?>{
              ...c.controlState,
              if (c.id.value == binding.startComponentId) 'closed': pressed,
              if (c.id.value == binding.holdContactComponentId)
                'actuated': holding,
              if (c.id.value == binding.endStopComponentId)
                'actuated': endStopActuated,
            },
          )
        else
          c,
    ];
    return CircuitState(
      circuitId: original.circuitId,
      revision: revision,
      mode: original.mode,
      components: parts,
      connections: original.connections,
      sources: original.sources,
      instruments: original.instruments,
      probes: original.probes,
      settings: original.settings,
      metadata: original.metadata,
    );
  }

  MultiphysicsProject _projectAt(CircuitState circuit) => MultiphysicsProject(
    electricalCircuit: circuit,
    pneumaticNetwork: project.pneumaticNetwork,
    devices: project.devices,
    links: project.links,
    physicalLayout: project.physicalLayout,
    schematicLayout: project.schematicLayout,
  );

  SelfHold24vSnapshot settle({
    required double timeS,
    required bool startPressed,
    required bool endStopActuated,
    Solenoid24vSnapshot previousRelay = const Solenoid24vSnapshot(
      energized: false,
      measuredVoltageV: 0,
    ),
  }) {
    if (!timeS.isFinite || timeS < 0) {
      throw const ElectropneumaticRuntimeException(
        'invalid_time',
        'Self holding cycle requires a nonnegative physical time.',
      );
    }
    Solenoid24vSnapshot relay = previousRelay;
    for (int iteration = 0; iteration < maxIterations; iteration++) {
      final CircuitState circuit = _controlledCircuit(
        revision: project.electricalCircuit.revision + iteration + 1,
        pressed: startPressed,
        holding: relay.energized,
        endStopActuated: endStopActuated,
      );
      final DcSolveResult solved = const SolverDC().solve(
        circuit,
        const TopologyEngine().compile(circuit),
      );
      if (!solved.isSolved) {
        throw const ElectropneumaticRuntimeException(
          'self_hold_dc_invalid',
          'K1/S1/B1 winding circuit must be solved by the canonical DC solver.',
        );
      }
      final MultiphysicsProject at = _projectAt(circuit);
      final CoilElectricalReading y1 = DcCoilMeter.read(
        project: at,
        link: binding.valveSolenoidLink,
        result: solved,
      );
      DcBranchResult? k1;
      for (final DcBranchResult branch in solved.branchResults) {
        if (branch.id == 'component:${binding.relayWindingComponentId}') {
          k1 = branch;
          break;
        }
      }
      if (k1 == null ||
          k1.kind != DcBranchKind.resistor ||
          k1.currentA == null ||
          !k1.voltageV.isFinite ||
          !k1.currentA!.isFinite) {
        throw const ElectropneumaticRuntimeException(
          'invalid_relay_winding',
          'Relay K1 needs a valid resistive winding branch in the DC solver.',
        );
      }
      final double measured = k1.voltageV.abs();
      final Solenoid24vSnapshot next = relayDrive.observe(
        relay,
        nowS: timeS,
        measuredVoltageV: measured,
      );
      if (next.energized == relay.energized) {
        return SelfHold24vSnapshot(
          timeS: timeS,
          relay: next,
          valveReading: y1,
          relayVoltageV: measured,
          electricalResult: solved,
          electricalIterations: iteration + 1,
          startPressed: startPressed,
          endStopActuated: endStopActuated,
        );
      }
      relay = next;
    }
    throw const ElectropneumaticRuntimeException(
      'relay_zero_time_nonconvergence',
      'Self-holding contact feedback did not converge at one timestamp.',
    );
  }
}
