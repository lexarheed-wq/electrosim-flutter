import 'package:electrosim/pneumatics/pneumatic_workshop_page.dart';
import 'package:electrosim_domain/electrosim_domain.dart';
import 'package:electrosim_multiphysics/electrosim_multiphysics.dart';
import 'package:electrosim_pneumatic_domain/electrosim_pneumatic_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('R6: 5/2 terminal numbers and IDs persist across both views', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1500, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final PneumaticDevice valve = PneumaticDevice(
      id: 'v52',
      kind: PneumaticDeviceKind.valve52,
      ports: <PneumaticPort>[
        for (final (String name, PneumaticPortRole role)
            in <(String, PneumaticPortRole)>[
              ('P', PneumaticPortRole.supply),
              ('A', PneumaticPortRole.work),
              ('B', PneumaticPortRole.work),
              ('R', PneumaticPortRole.exhaust),
              ('S', PneumaticPortRole.exhaust),
            ])
          PneumaticPort(
            id: PneumaticPortId('v52.$name'),
            deviceId: 'v52',
            role: role,
          ),
      ],
    );
    final MultiphysicsProject project = MultiphysicsProject(
      electricalCircuit: CircuitState(
        circuitId: CircuitId('r6-iso-ports'),
        revision: 0,
        mode: ElectricalMode.dc,
      ),
      pneumaticNetwork: PneumaticNetwork(devices: <PneumaticDevice>[valve]),
      devices: <PhysicalDeviceRecord>[
        PhysicalDeviceRecord(id: 'v52', pneumaticDeviceId: 'v52'),
      ],
      physicalLayout: <String, PhysicalViewPose>{
        'v52': PhysicalViewPose(x: 60, y: 80),
      },
      schematicLayout: <String, PhysicalViewPose>{
        'v52': PhysicalViewPose(x: 100, y: 120),
      },
    );
    await tester.pumpWidget(
      MaterialApp(home: PneumaticWorkshopPage(initialProject: project)),
    );
    await tester.pump();
    for (final String label in <String>['1/P', '2/A', '4/B', '3/R', '5/S']) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.byKey(const Key('port-v52.P')), findsOneWidget);
    expect(find.byKey(const Key('port-v52.B')), findsOneWidget);
    await tester.tap(find.text('Schéma'));
    await tester.pump();
    for (final String label in <String>['1/P', '2/A', '4/B', '3/R', '5/S']) {
      expect(find.text(label), findsOneWidget);
    }
    expect(project.pneumaticNetwork.devices.single.id, 'v52');
    expect(project.electricalCircuit.revision, 0);
  });
}
