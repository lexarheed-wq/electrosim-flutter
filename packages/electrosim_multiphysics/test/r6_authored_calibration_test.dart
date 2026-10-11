import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:electrosim_multiphysics/electrosim_multiphysics.dart';
import 'package:electrosim_pneumatic_domain/electrosim_pneumatic_domain.dart';
import 'package:test/test.dart';

PneumaticDevice node(String id, PneumaticDeviceKind kind) => PneumaticDevice(
  id: id,
  kind: kind,
  ports: <PneumaticPort>[
    PneumaticPort(
      id: PneumaticPortId('$id.1'),
      deviceId: id,
      role: kind == PneumaticDeviceKind.idealSource
          ? PneumaticPortRole.supply
          : PneumaticPortRole.work,
    ),
  ],
);

void main() {
  test('R6/F calibration preserves electrical identity and both poses', () {
    final MultiphysicsProject original = MultiphysicsProject(
      electricalCircuit: CircuitState(
        circuitId: CircuitId('r6f-calibration'),
        revision: 7,
        mode: ElectricalMode.dc,
      ),
      pneumaticNetwork: PneumaticNetwork(
        devices: <PneumaticDevice>[
          node('source', PneumaticDeviceKind.idealSource),
          node('tee', PneumaticDeviceKind.tee),
        ],
      ),
      devices: <PhysicalDeviceRecord>[
        PhysicalDeviceRecord(id: 'source', pneumaticDeviceId: 'source'),
        PhysicalDeviceRecord(id: 'tee', pneumaticDeviceId: 'tee'),
      ],
      physicalLayout: <String, PhysicalViewPose>{
        'source': PhysicalViewPose(x: 40, y: 70),
      },
      schematicLayout: <String, PhysicalViewPose>{
        'source': PhysicalViewPose(x: 150, y: 190),
      },
    );
    final PneumaticWorkshopState before = PneumaticWorkshopState(
      project: original,
      selectedPhysicalId: 'tee',
    );
    final PneumaticWorkshopState after = before.calibrate(
      physicalId: 'tee',
      parametersSi: <String, double>{'pressureAbsPa': 201325, 'volumeM3': .002},
    );
    expect(original.pneumaticNetwork.devices[1].parametersSi, isEmpty);
    expect(
      after.project.pneumaticNetwork.devices[1].parametersSi['volumeM3'],
      .002,
    );
    expect(after.project.electricalCircuit.revision, 7);
    expect(after.project.physicalLayout['source']!.x, 40);
    expect(after.project.schematicLayout['source']!.x, 150);
    expect(after.selectedPhysicalId, 'tee');
    expect(after.project.devices.length, 2);
    final MultiphysicsProject roundtrip = MultiphysicsProject.fromJsonString(
      after.project.toJsonString(),
    );
    expect(
      roundtrip.pneumaticNetwork.devices[1].parametersSi['pressureAbsPa'],
      201325,
    );
  });

  test('R6/F rejects missing, unphysical and unsupported calibration', () {
    final PneumaticWorkshopState state = PneumaticWorkshopState(
      project: MultiphysicsProject(
        electricalCircuit: CircuitState(
          circuitId: CircuitId('r6f-invalid'),
          revision: 0,
          mode: ElectricalMode.dc,
        ),
        pneumaticNetwork: PneumaticNetwork(
          devices: <PneumaticDevice>[
            node('source', PneumaticDeviceKind.idealSource),
            node('valve', PneumaticDeviceKind.valve52),
          ],
        ),
        devices: <PhysicalDeviceRecord>[
          PhysicalDeviceRecord(id: 'source', pneumaticDeviceId: 'source'),
          PhysicalDeviceRecord(id: 'valve', pneumaticDeviceId: 'valve'),
        ],
      ),
    );
    for (final Map<String, double> invalid in <Map<String, double>>[
      <String, double>{'pressureAbsPa': 0},
      <String, double>{'pressureAbsPa': -1},
      <String, double>{'volumeM3': .001},
      <String, double>{'pressureAbsPa': double.nan},
      <String, double>{'unknownField': 1},
    ]) {
      expect(
        () => state.calibrate(physicalId: 'source', parametersSi: invalid),
        throwsA(isA<MultiphysicsContractException>()),
      );
    }
    expect(
      () => state.calibrate(
        physicalId: 'valve',
        parametersSi: <String, double>{'pressureAbsPa': 101325},
      ),
      throwsA(
        isA<MultiphysicsContractException>().having(
          (e) => e.code,
          'code',
          'unsupported_calibration',
        ),
      ),
    );
    expect(
      () => state.calibrate(
        physicalId: 'ghost',
        parametersSi: <String, double>{'pressureAbsPa': 101325},
      ),
      throwsA(isA<MultiphysicsContractException>()),
    );
  });
}
