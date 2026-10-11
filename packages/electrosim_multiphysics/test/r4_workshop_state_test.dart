import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:electrosim_multiphysics/electrosim_multiphysics.dart';
import 'package:electrosim_pneumatic_domain/electrosim_pneumatic_domain.dart';
import 'package:test/test.dart';

PneumaticDevice device(String id, PneumaticDeviceKind kind, List<String> names) =>
    PneumaticDevice(
      id: id,
      kind: kind,
      ports: <PneumaticPort>[
        for (final String name in names)
          PneumaticPort(
            id: PneumaticPortId('$id.$name'),
            deviceId: id,
            role: PneumaticPortRole.work,
          ),
      ],
    );

PneumaticWorkshopState fresh() => PneumaticWorkshopState(
  project: MultiphysicsProject(
    electricalCircuit: CircuitState(
      circuitId: CircuitId('r4-pneumatic-shared'),
      revision: 0,
      mode: ElectricalMode.dc,
    ),
  ),
);

void main() {
  test('R4: both views share device identity and independent poses', () {
    final PneumaticWorkshopState original = fresh();
    final PneumaticWorkshopState added = original.place(
      device: device('cylinder', PneumaticDeviceKind.doubleActingCylinder, <String>[
        'A',
        'B',
      ]),
      physicalPose: PhysicalViewPose(x: 10, y: 20),
      schematicPose: PhysicalViewPose(x: 100, y: 200),
    );
    expect(added.selectedPhysicalId, 'cylinder');
    expect(added.project.pneumaticNetwork.devices.length, 1);
    final PneumaticWorkshopState schematic =
        added.switchView(PneumaticWorkshopView.schematic).move(
          physicalId: 'cylinder',
          pose: PhysicalViewPose(x: 120, y: 220),
        );
    expect(schematic.selectedPhysicalId, 'cylinder');
    expect(schematic.project.schematicLayout['cylinder']!.x, 120);
    expect(schematic.project.physicalLayout['cylinder']!.x, 10);
    expect(schematic.project.pneumaticNetwork.devices.length, 1);
    expect(schematic.project.electricalCircuit.toJsonString(),
        original.project.electricalCircuit.toJsonString());

    final MultiphysicsProject restored = MultiphysicsProject.fromJsonString(
      schematic.project.toJsonString(),
    );
    expect(restored.physicalLayout['cylinder']!.y, 20);
    expect(restored.schematicLayout['cylinder']!.y, 220);
    expect(restored.devices.single.id, 'cylinder');
  });

  test('R4: air pipe has physical identity, no implicit branches', () {
    PneumaticWorkshopState state = fresh();
    for (final PneumaticDevice d in <PneumaticDevice>[
      device('source', PneumaticDeviceKind.idealSource, <String>['P']),
      device('cylinder', PneumaticDeviceKind.doubleActingCylinder, <String>[
        'A',
        'B',
      ]),
    ]) {
      state = state.place(
        device: d,
        physicalPose: PhysicalViewPose(x: 0, y: 0),
        schematicPose: PhysicalViewPose(x: 1, y: 1),
      );
    }
    final PneumaticPipe pipe = PneumaticPipe(
      id: 'hose01',
      fromPortId: PneumaticPortId('source.P'),
      toPortId: PneumaticPortId('cylinder.A'),
      lengthM: 1.2,
      innerDiameterM: .006,
    );
    final PneumaticWorkshopState connected = state.connect(pipe);
    expect(connected.project.pneumaticNetwork.pipes.single.id, 'hose01');
    expect(
      () => connected.connect(
        PneumaticPipe(
          id: 'hose02',
          fromPortId: PneumaticPortId('source.P'),
          toPortId: PneumaticPortId('cylinder.B'),
          lengthM: 1,
          innerDiameterM: .006,
        ),
      ),
      throwsA(isA<PneumaticContractException>()),
    );
    expect(state.project.pneumaticNetwork.pipes, isEmpty);
    final PneumaticWorkshopState deleted = connected.remove('source');
    expect(deleted.project.pneumaticNetwork.pipes, isEmpty);
    expect(deleted.project.pneumaticNetwork.devices.single.id, 'cylinder');
    expect(deleted.project.physicalLayout.containsKey('source'), isFalse);
    expect(deleted.project.schematicLayout.containsKey('source'), isFalse);
    expect(deleted.project.electricalCircuit.toJsonString(),
        fresh().project.electricalCircuit.toJsonString());
  });
}
