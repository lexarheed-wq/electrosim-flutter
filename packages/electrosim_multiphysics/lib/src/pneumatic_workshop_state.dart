import 'package:electrosim_pneumatic_domain/electrosim_pneumatic_domain.dart';

import 'multiphysics_project.dart';

/// R4 design-time view; neither layout can modify pneumatic physics.
enum PneumaticWorkshopView { physical, schematic }

/// Immutable editor operations on the ONE canonical multiphysics project.
/// A selection is a physical-device ID, independent of the selected view.
/// Electrical circuits and explicit electrical/pneumatic links are preserved.
final class PneumaticWorkshopState {
  const PneumaticWorkshopState({
    required this.project,
    this.view = PneumaticWorkshopView.physical,
    this.selectedPhysicalId,
  });

  final MultiphysicsProject project;
  final PneumaticWorkshopView view;
  final String? selectedPhysicalId;

  PneumaticWorkshopState switchView(PneumaticWorkshopView next) =>
      PneumaticWorkshopState(
        project: project,
        view: next,
        selectedPhysicalId: selectedPhysicalId,
      );

  PneumaticWorkshopState select(String? physicalId) {
    if (physicalId != null &&
        !project.devices.any((PhysicalDeviceRecord d) => d.id == physicalId)) {
      throw const MultiphysicsContractException(
        'selection_not_found',
        'Cannot select an absent physical device.',
      );
    }
    return PneumaticWorkshopState(
      project: project,
      view: view,
      selectedPhysicalId: physicalId,
    );
  }

  MultiphysicsProject _rebuild({
    PneumaticNetwork? air,
    List<PhysicalDeviceRecord>? devices,
    Map<String, PhysicalViewPose>? physical,
    Map<String, PhysicalViewPose>? schematic,
  }) => MultiphysicsProject(
    electricalCircuit: project.electricalCircuit,
    pneumaticNetwork: air ?? project.pneumaticNetwork,
    devices: devices ?? project.devices,
    links: project.links,
    physicalLayout: physical ?? project.physicalLayout,
    schematicLayout: schematic ?? project.schematicLayout,
  );

  /// One canonical ID: placing on the plate also creates the schematic
  /// representation; no extra solver device is instantiated.
  PneumaticWorkshopState place({
    required PneumaticDevice device,
    required PhysicalViewPose physicalPose,
    required PhysicalViewPose schematicPose,
  }) {
    if (project.devices.any((PhysicalDeviceRecord d) => d.id == device.id)) {
      throw const MultiphysicsContractException(
        'device_already_placed',
        'Physical device identity is already used.',
      );
    }
    final MultiphysicsProject updated = _rebuild(
      air: PneumaticNetwork(
        devices: <PneumaticDevice>[
          ...project.pneumaticNetwork.devices,
          device,
        ],
        pipes: project.pneumaticNetwork.pipes,
      ),
      devices: <PhysicalDeviceRecord>[
        ...project.devices,
        PhysicalDeviceRecord(id: device.id, pneumaticDeviceId: device.id),
      ],
      physical: <String, PhysicalViewPose>{
        ...project.physicalLayout,
        device.id: physicalPose,
      },
      schematic: <String, PhysicalViewPose>{
        ...project.schematicLayout,
        device.id: schematicPose,
      },
    );
    return PneumaticWorkshopState(
      project: updated,
      view: view,
      selectedPhysicalId: device.id,
    );
  }

  PneumaticWorkshopState move({
    required String physicalId,
    required PhysicalViewPose pose,
  }) {
    if (!project.devices.any((PhysicalDeviceRecord d) => d.id == physicalId)) {
      throw const MultiphysicsContractException(
        'move_not_found',
        'Cannot move an absent physical device.',
      );
    }
    final bool onPlate = view == PneumaticWorkshopView.physical;
    final MultiphysicsProject updated = _rebuild(
      physical: onPlate
          ? <String, PhysicalViewPose>{
              ...project.physicalLayout,
              physicalId: pose,
            }
          : null,
      schematic: onPlate
          ? null
          : <String, PhysicalViewPose>{
              ...project.schematicLayout,
              physicalId: pose,
            },
    );
    return PneumaticWorkshopState(
      project: updated,
      view: view,
      selectedPhysicalId: physicalId,
    );
  }

  /// R1 validates pipe ports, exclusive occupancy, lengths and fault types.
  /// A crossing in either drawing cannot create a physical tee.
  PneumaticWorkshopState connect(PneumaticPipe pipe) {
    final MultiphysicsProject updated = _rebuild(
      air: PneumaticNetwork(
        devices: project.pneumaticNetwork.devices,
        pipes: <PneumaticPipe>[...project.pneumaticNetwork.pipes, pipe],
      ),
    );
    return PneumaticWorkshopState(
      project: updated,
      view: view,
      selectedPhysicalId: selectedPhysicalId,
    );
  }

  PneumaticWorkshopState disconnect(String pipeId) {
    if (!project.pneumaticNetwork.pipes.any(
      (PneumaticPipe pipe) => pipe.id == pipeId,
    )) {
      throw const MultiphysicsContractException(
        'pipe_not_found',
        'Cannot disconnect an absent air pipe.',
      );
    }
    final MultiphysicsProject updated = _rebuild(
      air: PneumaticNetwork(
        devices: project.pneumaticNetwork.devices,
        pipes: project.pneumaticNetwork.pipes
            .where((PneumaticPipe p) => p.id != pipeId)
            .toList(),
      ),
    );
    return PneumaticWorkshopState(
      project: updated,
      view: view,
      selectedPhysicalId: selectedPhysicalId,
    );
  }

  /// Linked electropneumatic components cannot be silently erased. Pure
  /// pneumatic devices can be removed along with their incident hoses.
  PneumaticWorkshopState remove(String physicalId) {
    PhysicalDeviceRecord? record;
    for (final PhysicalDeviceRecord d in project.devices) {
      if (d.id == physicalId) record = d;
    }
    if (record == null) {
      throw const MultiphysicsContractException(
        'device_not_found',
        'Cannot delete an absent physical device.',
      );
    }
    final String? airId = record.pneumaticDeviceId;
    if (record.electricalComponentIds.isNotEmpty ||
        (airId != null &&
            project.links.any(
              (ElectropneumaticLink link) => link.pneumaticDeviceId == airId,
            ))) {
      throw const MultiphysicsContractException(
        'linked_device',
        'Linked devices require an explicit unlink workflow before deletion.',
      );
    }
    final Set<PneumaticPortId> ports = <PneumaticPortId>{
      for (final PneumaticDevice d in project.pneumaticNetwork.devices)
        if (d.id == airId)
          for (final PneumaticPort port in d.ports) port.id,
    };
    final Map<String, PhysicalViewPose> plate =
        Map<String, PhysicalViewPose>.from(project.physicalLayout)
          ..remove(physicalId);
    final Map<String, PhysicalViewPose> diagram =
        Map<String, PhysicalViewPose>.from(project.schematicLayout)
          ..remove(physicalId);
    final MultiphysicsProject updated = _rebuild(
      air: PneumaticNetwork(
        devices: project.pneumaticNetwork.devices
            .where((PneumaticDevice d) => d.id != airId)
            .toList(),
        pipes: project.pneumaticNetwork.pipes
            .where(
              (PneumaticPipe p) =>
                  !ports.contains(p.fromPortId) &&
                  !ports.contains(p.toPortId),
            )
            .toList(),
      ),
      devices: project.devices
          .where((PhysicalDeviceRecord d) => d.id != physicalId)
          .toList(),
      physical: plate,
      schematic: diagram,
    );
    return PneumaticWorkshopState(
      project: updated,
      view: view,
      selectedPhysicalId:
          selectedPhysicalId == physicalId ? null : selectedPhysicalId,
    );
  }
}
