import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:electrosim_multiphysics/electrosim_multiphysics.dart';
import 'package:electrosim_pneumatic_domain/electrosim_pneumatic_domain.dart';
import 'package:test/test.dart';

CircuitState _electric(ElectricalMode mode) => CircuitState(
  circuitId: CircuitId('fixture'),
  revision: 7,
  mode: mode,
  components: <ComponentInstance>[
    ComponentInstance(
      id: ComponentId('y1'),
      modelType: 'resistor',
      terminals: <Terminal>[
        Terminal(id: TerminalId('y1-a'), name: 'A'),
        Terminal(id: TerminalId('y1-b'), name: 'B'),
      ],
      parameters: const <String, Object?>{'resistanceOhm': 240.0},
    ),
  ],
);

PneumaticNetwork _air() => PneumaticNetwork(
  devices: <PneumaticDevice>[
    PneumaticDevice(
      id: 'v52',
      kind: PneumaticDeviceKind.valve52,
      ports: <PneumaticPort>[
        PneumaticPort(
          id: PneumaticPortId('valve-A'),
          deviceId: 'v52',
          role: PneumaticPortRole.work,
        ),
      ],
    ),
  ],
);

PhysicalDeviceRecord _owner() => PhysicalDeviceRecord(
  id: 'Y1',
  pneumaticDeviceId: 'v52',
  electricalComponentIds: <String>['y1'],
);

ElectropneumaticLink _link() => ElectropneumaticLink(
  id: 'link-Y1',
  electricalComponentId: 'y1',
  pneumaticDeviceId: 'v52',
  role: ElectropneumaticLinkRole.solenoidCoil,
);

void main() {
  group('R1 physical identity and causal links', () {
    test('R1-I01: one valve and its electric coil share one physical ID', () {
      final MultiphysicsProject project = MultiphysicsProject(
        electricalCircuit: _electric(ElectricalMode.dc),
        pneumaticNetwork: _air(),
        devices: <PhysicalDeviceRecord>[_owner()],
        links: <ElectropneumaticLink>[_link()],
      );
      expect(project.devices.single.id, 'Y1');
      expect(project.links.single.pneumaticDeviceId, 'v52');
      expect(project.electricalCircuit.mode, ElectricalMode.dc);
    });

    test('R1-I02: dangling contact and orphan valve are rejected', () {
      expect(
        () => MultiphysicsProject(
          electricalCircuit: _electric(ElectricalMode.dc),
          pneumaticNetwork: _air(),
          links: <ElectropneumaticLink>[_link()],
        ),
        throwsA(
          isA<MultiphysicsContractException>().having(
            (e) => e.code, 'code', 'identity_mismatch',
          ),
        ),
      );
      expect(
        () => MultiphysicsProject(
          electricalCircuit: _electric(ElectricalMode.dc),
          pneumaticNetwork: _air(),
          devices: <PhysicalDeviceRecord>[
            PhysicalDeviceRecord(
              id: 'bad',
              pneumaticDeviceId: 'missing',
              electricalComponentIds: <String>['y1'],
            ),
          ],
        ),
        throwsA(isA<MultiphysicsContractException>()),
      );
    });

    test('R1-I03: existing AC1 cannot silently act as 24V DC coil', () {
      expect(
        () => MultiphysicsProject(
          electricalCircuit: _electric(ElectricalMode.ac1),
          pneumaticNetwork: _air(),
          devices: <PhysicalDeviceRecord>[_owner()],
          links: <ElectropneumaticLink>[_link()],
        ),
        throwsA(isA<MultiphysicsContractException>().having(
          (e) => e.code, 'code', 'unsupported_coupling_mode',
        )),
      );
    });

    test('R1-I04: dual layouts have independent poses but stable device ID', () {
      final MultiphysicsProject project = MultiphysicsProject(
        electricalCircuit: _electric(ElectricalMode.dc),
        pneumaticNetwork: _air(),
        devices: <PhysicalDeviceRecord>[_owner()],
        physicalLayout: <String, PhysicalViewPose>{
          'Y1': PhysicalViewPose(x: 24, y: 12, rotationRad: .5),
        },
        schematicLayout: <String, PhysicalViewPose>{
          'Y1': PhysicalViewPose(x: 100, y: 44),
        },
      );
      expect(project.physicalLayout['Y1']!.x, 24);
      expect(project.schematicLayout['Y1']!.x, 100);
      expect(
        () => MultiphysicsProject(
          electricalCircuit: _electric(ElectricalMode.dc),
          pneumaticNetwork: _air(),
          devices: <PhysicalDeviceRecord>[_owner()],
          physicalLayout: <String, PhysicalViewPose>{
            'absent': PhysicalViewPose(x: 0, y: 0),
          },
        ),
        throwsA(isA<MultiphysicsContractException>()),
      );
    });

    test('R1-M02: JSON does not mutate CircuitState or alter its schema', () {
      final CircuitState circuit = _electric(ElectricalMode.dc);
      final MultiphysicsProject project = MultiphysicsProject(
        electricalCircuit: circuit,
        pneumaticNetwork: _air(),
        devices: <PhysicalDeviceRecord>[_owner()],
        links: <ElectropneumaticLink>[_link()],
        physicalLayout: <String, PhysicalViewPose>{
          'Y1': PhysicalViewPose(x: 50, y: 70),
        },
      );
      final MultiphysicsProject restored =
          MultiphysicsProject.fromJsonString(project.toJsonString());
      expect(restored.toJson(), equals(project.toJson()));
      expect(circuit.toJson()['schemaVersion'], CircuitState.currentSchemaVersion);
      expect(restored.electricalCircuit.toJson(), equals(circuit.toJson()));
    });

    test('R1-M03: reject future project schemas without fallback', () {
      expect(
        () => MultiphysicsProject.fromJson(<String, dynamic>{
          'schemaVersion': 200,
        }),
        throwsA(isA<MultiphysicsContractException>().having(
          (e) => e.code, 'code', 'unsupported_schema',
        )),
      );
    });

    test('R1-G01: all electrical modes remain possible with pneumatics disabled', () {
      for (final ElectricalMode mode in ElectricalMode.values) {
        final MultiphysicsProject p = MultiphysicsProject(
          electricalCircuit: _electric(mode),
        );
        expect(p.links, isEmpty);
        expect(p.pneumaticNetwork.devices, isEmpty);
        expect(p.electricalCircuit.mode, mode);
      }
    });
  });
}
