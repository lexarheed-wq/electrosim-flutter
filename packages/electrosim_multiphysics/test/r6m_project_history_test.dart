import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:electrosim_multiphysics/electrosim_multiphysics.dart';
import 'package:electrosim_pneumatic_domain/electrosim_pneumatic_domain.dart';
import 'package:test/test.dart';

void main() {
  test('R6/M undo redo and canonical two-view identity', () {
    final MultiphysicsProject initial = MultiphysicsProject(
      electricalCircuit: CircuitState(
        circuitId: CircuitId('m-test'),
        revision: 0,
        mode: ElectricalMode.dc,
      ),
    );
    final PneumaticWorkshopSession session = PneumaticWorkshopSession(initial);
    session.apply((PneumaticWorkshopState state) => state.place(
      device: PneumaticDevice(
        id: 'p1',
        kind: PneumaticDeviceKind.manometer,
        ports: <PneumaticPort>[
          PneumaticPort(
            id: PneumaticPortId('p1.A'),
            deviceId: 'p1',
            role: PneumaticPortRole.work,
          ),
        ],
      ),
      physicalPose: PhysicalViewPose(x: 10, y: 20),
      schematicPose: PhysicalViewPose(x: 30, y: 40),
    ));
    expect(session.state.project.devices.single.id, 'p1');
    expect(session.state.project.physicalLayout['p1']!.x, 10);
    session.switchView(PneumaticWorkshopView.schematic);
    session.apply((PneumaticWorkshopState state) => state.move(
      physicalId: 'p1',
      pose: PhysicalViewPose(x: 35, y: 45),
    ));
    expect(session.state.project.schematicLayout['p1']!.x, 35);
    expect(session.state.project.physicalLayout['p1']!.x, 10);
    session.undo();
    expect(session.state.project.schematicLayout['p1']!.x, 30);
    session.undo();
    expect(session.state.project.devices, isEmpty);
    expect(session.state.selectedPhysicalId, isNull);
    session.redo();
    expect(session.state.project.devices.single.id, 'p1');
    session.apply((PneumaticWorkshopState state) => state.remove('p1'));
    expect(session.canRedo, isFalse);
  });

  test('R6/M rejected operation does not write history', () {
    final PneumaticWorkshopSession session = PneumaticWorkshopSession(
      MultiphysicsProject(
        electricalCircuit: CircuitState(
          circuitId: CircuitId('invalid'),
          revision: 0,
          mode: ElectricalMode.dc,
        ),
      ),
    );
    expect(
      () => session.apply(
        (PneumaticWorkshopState s) => s.move(
          physicalId: 'missing',
          pose: PhysicalViewPose(x: 1, y: 2),
        ),
      ),
      throwsA(isA<MultiphysicsContractException>()),
    );
    expect(session.canUndo, isFalse);
    expect(session.state.project.devices, isEmpty);
  });
}
