import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:electrosim_multiphysics/electrosim_multiphysics.dart';
import 'package:electrosim_pneumatic_domain/electrosim_pneumatic_domain.dart';
import 'package:electrosim_storage/electrosim_storage.dart';
import 'package:test/test.dart';

SavedCircuitDocument _oldCircuit() {
  final DateTime now = DateTime.utc(2026, 10, 10);
  return SavedCircuitDocument(
    saveId: 'baseline',
    title: 'My electrical circuit',
    createdAtUtc: now,
    updatedAtUtc: now,
    engineVersion: 'electrosim-g5',
    circuit: CircuitState(
      circuitId: CircuitId('electric-001'),
      revision: 8,
      mode: ElectricalMode.dc,
    ),
    appState: const <String, Object?>{
      'layout': <String, Object?>{'view': 'plate'},
      'studentState': 'preserved',
    },
  );
}

void main() {
  group('R1: lossless electrical/multiphysics persistence envelope', () {
    test('R1-M01: preserve v2 electrical IDs, geometry and appState', () {
      final SavedCircuitDocument old = _oldCircuit();
      final SavedMultiphysicsDocument imported =
          SavedMultiphysicsDocument.fromJson(old.toJson());
      expect(imported.electricalDocument.toJson(), equals(old.toJson()));
      expect(imported.project.electricalCircuit.toJson(), equals(old.circuit.toJson()));
      expect(imported.project.pneumaticNetwork.devices, isEmpty);
      expect(imported.project.links, isEmpty);
      expect(imported.toLegacyElectricalJson(), equals(old.toJson()));
    });

    test('R1-M01B: v1 migration delegates to historic parser', () {
      final Map<String, Object?> v1 = _oldCircuit().toJson();
      v1['schemaVersion'] = 1;
      v1.remove('appState');
      final SavedMultiphysicsDocument imported =
          SavedMultiphysicsDocument.fromJson(v1);
      expect(imported.electricalDocument.title, 'My electrical circuit');
      expect(imported.electricalDocument.appState, isEmpty);
      expect(imported.project.electricalCircuit.revision, 8);
    });

    test('R1-M01C: v0 migration preserves electrical topology', () {
      final Map<String, Object?> v0 = _oldCircuit().toJson();
      v0['schemaVersion'] = 0;
      v0['name'] = v0.remove('title');
      v0.remove('appState');
      final SavedMultiphysicsDocument imported =
          SavedMultiphysicsDocument.fromJson(v0);
      expect(imported.electricalDocument.title, 'My electrical circuit');
      expect(imported.project.electricalCircuit.circuitId.value, 'electric-001');
    });

    test('R1-M02: new v3 file roundtrips and has one electrical source', () {
      final SavedCircuitDocument old = _oldCircuit();
      final PneumaticNetwork air = PneumaticNetwork(
        devices: <PneumaticDevice>[
          PneumaticDevice(
            id: 'cylinder1',
            kind: PneumaticDeviceKind.doubleActingCylinder,
            ports: <PneumaticPort>[
              PneumaticPort(
                id: PneumaticPortId('cyl-A'),
                deviceId: 'cylinder1',
                role: PneumaticPortRole.work,
              ),
            ],
          ),
        ],
      );
      final MultiphysicsProject project = MultiphysicsProject(
        electricalCircuit: old.circuit,
        pneumaticNetwork: air,
        devices: <PhysicalDeviceRecord>[
          PhysicalDeviceRecord(
            id: 'CYL1',
            pneumaticDeviceId: 'cylinder1',
          ),
        ],
        physicalLayout: <String, PhysicalViewPose>{
          'CYL1': PhysicalViewPose(x: 50, y: 35),
        },
        schematicLayout: <String, PhysicalViewPose>{
          'CYL1': PhysicalViewPose(x: 100, y: 65),
        },
      );
      final SavedMultiphysicsDocument mixed = SavedMultiphysicsDocument(
        electricalDocument: old, project: project,
      );
      final Map<String, Object?> root = mixed.toJson();
      expect(root['schemaVersion'], 3);
      final Map<String, Object?> design =
          root['pneumaticDesign']! as Map<String, Object?>;
      expect(design.containsKey('electricalCircuit'), isFalse);
      final SavedMultiphysicsDocument restored =
          SavedMultiphysicsDocument.fromJsonString(mixed.toJsonString());
      expect(restored.toJson(), equals(root));
      expect(restored.electricalDocument.appState['studentState'], 'preserved');
      expect(restored.project.pneumaticNetwork.devices.single.id, 'cylinder1');
    });

    test('R1-M03: reject future version and duplicate conflicting roots', () {
      expect(
        () => SavedMultiphysicsDocument.fromJson(<String, dynamic>{
          'schemaVersion': 4,
        }),
        throwsA(isA<FormatException>()),
      );
      final SavedMultiphysicsDocument doc =
          SavedMultiphysicsDocument.wrapElectrical(_oldCircuit());
      final Map<String, Object?> invalid = doc.toJson();
      final Map<String, Object?> design =
          invalid['pneumaticDesign']! as Map<String, Object?>;
      design['electricalCircuit'] = _oldCircuit().circuit.toJson();
      expect(
        () => SavedMultiphysicsDocument.fromJson(invalid),
        throwsA(isA<FormatException>()),
      );
    });

    test('R1-M04: legacy export never drops mixed air data', () {
      final SavedCircuitDocument old = _oldCircuit();
      final SavedMultiphysicsDocument mixed = SavedMultiphysicsDocument(
        electricalDocument: old,
        project: MultiphysicsProject(
          electricalCircuit: old.circuit,
          pneumaticNetwork: PneumaticNetwork(
            devices: <PneumaticDevice>[
              PneumaticDevice(
                id: 'air1',
                kind: PneumaticDeviceKind.manometer,
                ports: <PneumaticPort>[
                  PneumaticPort(
                    id: PneumaticPortId('air1-P'),
                    deviceId: 'air1',
                    role: PneumaticPortRole.work,
                  ),
                ],
              ),
            ],
          ),
        ),
      );
      expect(
        () => mixed.toLegacyElectricalJson(),
        throwsA(isA<FormatException>()),
      );
      // The existing v2 decoder remains unchanged and intentionally refuses v3.
      expect(
        () => SavedCircuitDocument.fromJson(mixed.toJson()),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
