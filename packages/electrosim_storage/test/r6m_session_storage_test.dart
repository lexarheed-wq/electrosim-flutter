import 'dart:convert';

import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:electrosim_multiphysics/electrosim_multiphysics.dart';
import 'package:electrosim_pneumatic_domain/electrosim_pneumatic_domain.dart';
import 'package:electrosim_storage/electrosim_storage.dart';
import 'package:test/test.dart';

void main() {
  test('R6/M v3 dual view roundtrip and canonical electric source', () {
    final CircuitState electric = CircuitState(
      circuitId: CircuitId('r6m-storage'),
      revision: 8,
      mode: ElectricalMode.dc,
    );
    final SavedCircuitDocument electrical = SavedCircuitDocument(
      saveId: 'session-1',
      title: 'R6/M mixed',
      createdAtUtc: DateTime.utc(2026, 10, 11),
      updatedAtUtc: DateTime.utc(2026, 10, 11),
      circuit: electric,
      engineVersion: 'g5-r6m',
    );
    final PneumaticWorkshopSession session = PneumaticWorkshopSession(
      MultiphysicsProject(electricalCircuit: electric),
    );
    session.apply((PneumaticWorkshopState s) => s.place(
      device: PneumaticDevice(
        id: 'air-device',
        kind: PneumaticDeviceKind.manometer,
        ports: <PneumaticPort>[
          PneumaticPort(
            id: PneumaticPortId('air-device.P'),
            deviceId: 'air-device',
            role: PneumaticPortRole.work,
          ),
        ],
      ),
      physicalPose: PhysicalViewPose(x: 10, y: 11),
      schematicPose: PhysicalViewPose(x: 20, y: 21),
    ));
    const MultiphysicsSessionStorage store = MultiphysicsSessionStorage();
    final String saved = store.exportProject(
      session: session, electricalDocument: electrical,
    );
    final PneumaticWorkshopSession imported = store.importProject(saved);
    expect(imported.state.project.toJsonString(),
        session.state.project.toJsonString());
    expect(store.sameDesign(saved, saved), isTrue);
    expect(
      () => store.exportProject(
        session: session,
        electricalDocument: SavedCircuitDocument(
          saveId: electrical.saveId,
          title: electrical.title,
          createdAtUtc: electrical.createdAtUtc,
          updatedAtUtc: electrical.updatedAtUtc,
          engineVersion: electrical.engineVersion,
          circuit: CircuitState(
            circuitId: CircuitId('foreign'),
            revision: 0,
            mode: ElectricalMode.dc,
          ),
        ),
      ),
      throwsFormatException,
    );
    final Map<String, dynamic> root =
        Map<String, dynamic>.from(jsonDecode(saved) as Map);
    expect(root['schemaVersion'], 3);
    expect(
      (root['pneumaticDesign'] as Map).containsKey('electricalCircuit'),
      isFalse,
    );
  });

  test('R6/M legacy migration v0/v1/v2 remains isolated from physics', () {
    final SavedCircuitDocument electrical = SavedCircuitDocument(
      saveId: 'e-old',
      title: 'Legacy reference',
      createdAtUtc: DateTime.utc(2026, 10, 11),
      updatedAtUtc: DateTime.utc(2026, 10, 11),
      engineVersion: 'g5',
      circuit: CircuitState(
        circuitId: CircuitId('legacy'),
        revision: 1,
        mode: ElectricalMode.ac1,
      ),
    );
    const MultiphysicsSessionStorage storage = MultiphysicsSessionStorage();
    for (final int version in <int>[0, 1, 2]) {
      final Map<String, Object?> old = electrical.toJson();
      old['schemaVersion'] = version;
      if (version == 0) {
        old['name'] = old.remove('title');
        old.remove('appState');
      } else if (version == 1) {
        old.remove('appState');
      }
      final PneumaticWorkshopSession restored = storage.importProject(
        jsonEncode(old),
      );
      expect(restored.state.project.electricalCircuit.mode, ElectricalMode.ac1);
      expect(restored.state.project.pneumaticNetwork.devices, isEmpty);
      expect(restored.canUndo, isFalse);
    }
  });

  test('R6/M corrupt or future project refuses import without side effects', () {
    const MultiphysicsSessionStorage storage = MultiphysicsSessionStorage();
    expect(() => storage.importProject('{"schemaVersion":99}'),
        throwsFormatException);
    expect(() => storage.importProject('invalid json'), throwsFormatException);
    expect(
      () => ProjectHistory<int>(0, capacity: 0),
      throwsArgumentError,
    );
  });
}
