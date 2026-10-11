import 'dart:convert';

import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:electrosim_multiphysics/electrosim_multiphysics.dart';
import 'package:electrosim_pneumatic_domain/electrosim_pneumatic_domain.dart';
import 'package:test/test.dart';

/// R6 workshop *model* scale, not a frame-rate or rendered-widget test.
void main() {
  for (final int n in <int>[30, 100, 200, 400]) {
    test('R6 two-view canonical workshop preserves $n device identities', () {
      final CircuitState baseElectrical = CircuitState(
        circuitId: CircuitId('r6-workshop-baseline'),
        revision: 0,
        mode: ElectricalMode.dc,
      );
      PneumaticWorkshopState state = PneumaticWorkshopState(
        project: MultiphysicsProject(electricalCircuit: baseElectrical),
      );
      final Stopwatch stopwatch = Stopwatch()..start();
      for (int i = 0; i < n; i++) {
        final String id = 'manifold.$i';
        state = state.place(
          device: PneumaticDevice(
            id: id,
            kind: PneumaticDeviceKind.manifold,
            ports: <PneumaticPort>[
              PneumaticPort(
                id: PneumaticPortId('$id.A'),
                deviceId: id,
                role: PneumaticPortRole.work,
              ),
              PneumaticPort(
                id: PneumaticPortId('$id.B'),
                deviceId: id,
                role: PneumaticPortRole.work,
              ),
            ],
          ),
          physicalPose: PhysicalViewPose(x: i * 20.0, y: 30),
          schematicPose: PhysicalViewPose(x: i * 5.0, y: 50),
        );
      }
      stopwatch.stop();
      expect(state.project.pneumaticNetwork.devices, hasLength(n));
      expect(state.project.devices, hasLength(n));
      expect(state.project.physicalLayout.keys, hasLength(n));
      expect(state.project.schematicLayout.keys, hasLength(n));
      expect(state.selectedPhysicalId, 'manifold.${n - 1}');

      final PneumaticWorkshopState diagram = state
          .switchView(PneumaticWorkshopView.schematic)
          .move(
            physicalId: 'manifold.0',
            pose: PhysicalViewPose(x: 999, y: 777),
          );
      expect(diagram.project.physicalLayout['manifold.0']!.x, 0);
      expect(diagram.project.schematicLayout['manifold.0']!.x, 999);
      expect(diagram.project.pneumaticNetwork.devices, hasLength(n));
      expect(
        diagram.project.electricalCircuit.toJsonString(),
        baseElectrical.toJsonString(),
      );

      final MultiphysicsProject restored = MultiphysicsProject.fromJsonString(
        diagram.project.toJsonString(),
      );
      expect(restored.pneumaticNetwork.devices, hasLength(n));
      expect(restored.devices.map((d) => d.id).toSet(), hasLength(n));
      expect(restored.schematicLayout['manifold.0']!.x, 999);
      expect(restored.physicalLayout['manifold.0']!.x, 0);
      expect(restored.links, isEmpty);

      // Removal affects both layouts and only the identified physical device.
      final PneumaticWorkshopState removed = diagram.remove('manifold.0');
      expect(removed.project.pneumaticNetwork.devices, hasLength(n - 1));
      expect(removed.project.physicalLayout.containsKey('manifold.0'), false);
      expect(removed.project.schematicLayout.containsKey('manifold.0'), false);
      expect(state.project.pneumaticNetwork.devices, hasLength(n));

      print(jsonEncode(<String, Object>{
        'schema': 'electrosim.pneumatic.r6.workshop.v1',
        'kind': 'unrendered_canonical_two_view_model',
        'deviceCount': n,
        'createTimeUs': stopwatch.elapsedMicroseconds,
        'identitiesPreserved': true,
        'serializable': true,
        'electricalInvariant': true,
      }));
    });
  }
}
